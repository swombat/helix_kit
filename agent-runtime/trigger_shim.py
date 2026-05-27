#!/usr/bin/env python3
"""
trigger_shim.py — the HTTP-to-chaos-exec bridge.

Runs inside each chaos-agent container. Listens on port 4000.
HelixKit POSTs a trigger payload here; we shell out to `chaos exec`.

This is intentionally dumb: no business logic, no state, no decision-making.
If it grows past ~200 lines, you've built the wrong thing.

Endpoints:
    GET  /health          — liveness check (no auth)
    POST /trigger         — invoke chaos with a prompt (bearer-token auth)

Trigger payload (HelixKit ChaosTriggerClient shape):
    {
      "session_id": "<agent-uuid>-<chat-id>",     # arbitrary string, future chaos session resume
      "request": "HelixKit received a request...",# the prompt text fed to `chaos exec`
      "conversation_id": "WYNWQe",                # optional, for logs only
      "requested_by": "user@example.com",         # optional, for logs only
      "model": "claude-sonnet-4-5"                # optional; falls back to AGENT_DEFAULT_MODEL env
    }

`prompt` is accepted as a backwards-compatible alias for `request`.

Env vars (read at startup):
    AGENT_ID                  stable identifier for this agent
    AGENT_SLUG                optional human-readable identifier for logs
    TRIGGER_BEARER_TOKEN      required; the bearer token HelixKit must send on /trigger
    AGENT_DEFAULT_MODEL       default model name (e.g. "claude-haiku-4-5")
    AGENT_PROVIDER            chaos provider override (e.g. "anthropic")
    AGENT_REPO_PATH           agent repo path (default /home/agent/repo)
    AGENT_IDENTITY_PATH       identity path (default /home/agent/identity)
    SHIM_PORT                 port to listen on (default 4000)
    CHAOS_BIN                 path to chaos binary (default /usr/local/bin/chaos)
    CHAOS_TIMEOUT_SECS        max seconds for a single chaos exec call (default 600)
"""

import os
import subprocess
import logging
from pathlib import Path
from flask import Flask, request, jsonify, abort

# ----- config -----
AGENT_ID = os.environ.get("AGENT_ID", "unknown")
AGENT_LOG_LABEL = os.environ.get("AGENT_SLUG") or AGENT_ID
TRIGGER_BEARER_TOKEN = os.environ.get("TRIGGER_BEARER_TOKEN", "")
AGENT_DEFAULT_MODEL = os.environ.get("AGENT_DEFAULT_MODEL", "claude-haiku-4-5")
AGENT_PROVIDER = os.environ.get("AGENT_PROVIDER", "anthropic")
AGENT_REPO_PATH = Path(os.environ.get("AGENT_REPO_PATH", "/home/agent/repo"))
AGENT_IDENTITY_PATH = Path(os.environ.get("AGENT_IDENTITY_PATH", "/home/agent/identity"))
SHIM_PORT = int(os.environ.get("SHIM_PORT", "4000"))
CHAOS_BIN = os.environ.get("CHAOS_BIN", "/usr/local/bin/chaos")
CHAOS_TIMEOUT_SECS = int(os.environ.get("CHAOS_TIMEOUT_SECS", "600"))
IDENTITY_FILE_LIMIT = 80_000

logging.basicConfig(
    level=logging.INFO,
    format=f"%(asctime)s [{AGENT_LOG_LABEL}] %(levelname)s %(message)s",
)
log = logging.getLogger(AGENT_LOG_LABEL)

if not TRIGGER_BEARER_TOKEN:
    log.error("TRIGGER_BEARER_TOKEN not set; shim will reject all /trigger calls. Refusing to start.")
    raise SystemExit(2)

app = Flask(__name__)


# ----- routes -----
@app.get("/health")
def health():
    return jsonify({"status": "ok", "agent_id": AGENT_ID, "version": _chaos_version()})


@app.post("/trigger")
def trigger():
    auth = request.headers.get("Authorization", "")
    if auth != f"Bearer {TRIGGER_BEARER_TOKEN}":
        log.warning("rejected /trigger: bad auth")
        abort(401)

    payload = request.get_json(silent=True) or {}
    session_id = payload.get("session_id")
    # `request` is the canonical field name (HelixKit ChaosTriggerClient). `prompt`
    # is accepted as a backwards-compatible alias for hand-rolled clients.
    prompt = payload.get("request") or payload.get("prompt")
    model = payload.get("model", AGENT_DEFAULT_MODEL)
    conversation_id = payload.get("conversation_id")
    requested_by = payload.get("requested_by")

    if not session_id or not prompt:
        return jsonify({"error": "session_id and `request` (or `prompt`) are required"}), 400

    log.info(
        f"trigger session_id={session_id} conversation_id={conversation_id} "
        f"requested_by={requested_by} model={model} prompt_len={len(prompt)}"
    )

    full_prompt = build_prompt(prompt)
    cwd = AGENT_REPO_PATH if AGENT_REPO_PATH.exists() else Path.home()

    try:
        result = subprocess.run(
            [
                CHAOS_BIN, "exec",
                "--provider", AGENT_PROVIDER,
                "-C", str(cwd),
                "--skip-git-repo-check",
                "-m", model,
                # Docker is the sandbox boundary for hosted agents. Inside that
                # boundary the agent must be able to use Bash, write its mounted
                # identity/state folders, and call HelixKit's API back.
                "--dangerously-bypass-approvals-and-sandbox",
                "-c", "shell_environment_policy.inherit=\"all\"",
                # NOTE: --resume <session_id> only works for an existing session.
                # For the first turn we omit it; subsequent turns pass it. The shim
                # does not currently track first-vs-subsequent — chaos will create
                # a new session on the first call. Caller can persist the
                # returned session_id from chaos's stdout if needed.
                # TODO: implement session-id persistence properly once we know the
                # chaos session-id format from real runs.
                # Read the full prompt from stdin so identity injection is not
                # constrained by shell argv limits and is not exposed in ps args.
                "-",
            ],
            input=full_prompt,
            capture_output=True,
            text=True,
            timeout=CHAOS_TIMEOUT_SECS,
        )
    except subprocess.TimeoutExpired:
        log.error(f"chaos exec timed out after {CHAOS_TIMEOUT_SECS}s")
        return jsonify({"status": "timeout", "session_id": session_id}), 504

    response = {
        "status": "ok" if result.returncode == 0 else "error",
        "session_id": session_id,
        "returncode": result.returncode,
        "stdout": _tail(result.stdout, 4000),
        "stderr": _tail(result.stderr, 4000),
    }
    log.info(f"trigger done session_id={session_id} rc={result.returncode}")
    return jsonify(response), (200 if result.returncode == 0 else 500)


# ----- helpers -----
def _tail(s: str, n: int) -> str:
    """Trim long stdout/stderr so HelixKit doesn't choke on huge payloads."""
    if not s:
        return ""
    if len(s) <= n:
        return s
    return f"...[truncated {len(s) - n} chars]...\n{s[-n:]}"


def build_prompt(request_text: str) -> str:
    """Attach the agent's identity bundle to every Chaos turn."""
    return "\n\n".join(part for part in [identity_context(), request_text] if part)


def identity_context() -> str:
    """Return the identity context exported by HelixKit."""
    sections = []

    # Keep soul.md first. This is the agent's own chosen/exported identity text,
    # and should be the first thing the model sees before runtime scaffolding.
    soul = read_identity_file("soul.md")
    if soul:
        sections.append(soul)

    for filename, label in [
        ("runtime-instructions.md", "Hosted runtime instructions"),
        ("self-narrative.md", "Self-narrative"),
        ("bootstrap.md", "Bootstrap notes"),
    ]:
        content = read_identity_file(filename)
        if content:
            sections.append(f"## {label}: identity/{filename}\n\n{content}")

    return "\n\n".join(sections)


def read_identity_file(filename: str) -> str:
    path = AGENT_IDENTITY_PATH / filename
    try:
        content = path.read_text()
    except FileNotFoundError:
        return ""
    except Exception as e:
        return f"_Could not read {path}: {e}_"

    if len(content) <= IDENTITY_FILE_LIMIT:
        return content
    return content[:IDENTITY_FILE_LIMIT] + f"\n\n_[truncated {len(content) - IDENTITY_FILE_LIMIT} chars]_"


def _chaos_version() -> str:
    try:
        out = subprocess.run([CHAOS_BIN, "--version"], capture_output=True, text=True, timeout=5)
        return out.stdout.strip() or "unknown"
    except Exception as e:
        return f"error: {e}"


if __name__ == "__main__":
    log.info(f"chaos-agent shim starting: port={SHIM_PORT}, chaos={_chaos_version()}")
    # 0.0.0.0 because we're inside a container; the daemon binds to all interfaces
    # and Docker handles which are externally exposed.
    app.run(host="0.0.0.0", port=SHIM_PORT, debug=False)

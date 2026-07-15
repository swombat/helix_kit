#!/usr/bin/env python3
"""
trigger_shim.py — the HTTP-to-chaos-exec bridge.

Runs inside each chaos-agent container. Listens on port 4000.
HelixKit POSTs a trigger payload here; we shell out to `chaos exec`.

This is intentionally dumb: no business logic, no decision-making beyond
"fresh session or resume". The only state it keeps is a sidecar cache mapping
HelixKit session ids to chaos process ids — losable at any moment with zero
correctness impact (loss means one fresh session, i.e. today's behaviour).

Endpoints:
    GET  /health          — liveness check (no auth)
    POST /trigger         — invoke chaos with a prompt (bearer-token auth)

Trigger payload (HelixKit ChaosTriggerClient shape):
    {
      "session_id": "<agent-uuid>-<chat-id>",     # HelixKit's stable session key
      "request": "HelixKit received a request...",# full prompt (always present)
      "request_delta": "...",                     # optional slim prompt, used only on resume
      "persistent_session": true,                 # optional; enables resume behaviour
      "conversation_id": "WYNWQe",                # optional, for logs only
      "requested_by": "user@example.com",         # optional, for logs only
      "model": "claude-sonnet-4-5"                # optional; falls back to AGENT_DEFAULT_MODEL env
    }

`prompt` is accepted as a backwards-compatible alias for `request`.

Persistent-session behaviour (when `persistent_session` is true):
    - First trigger for a session_id runs `chaos exec --json` with the full
      identity-wrapped prompt, captures chaos's process_id from the
      `process.started` event, and stores the mapping in a sidecar file under
      `$CHAOS_HOME/helixkit-sessions/`.
    - Subsequent triggers run `chaos exec --json ... resume <process_id> -`
      with `request_delta` (falling back to `request`) — no identity
      re-injection, no journal re-read.
    - The session rolls (fresh start) on: model change, identity-file change,
      context-size ceiling, or any resume failure. Failure mode is always
      "one full fresh turn", never a contextless agent.
    - The response gains `chaos_session_id`, `session_resumed`,
      `fresh_fallback`, `session_roll_reason`, and `usage`
      {input_tokens, cached_input_tokens, output_tokens}.

Without `persistent_session`, behaviour is byte-identical to the legacy shim:
one fresh non-persisted-mapping `chaos exec` per trigger.

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
    CHAOS_HOME                chaos state dir (default ~/.chaos); sidecar session
                              map lives under $CHAOS_HOME/helixkit-sessions/
    CHAOS_TIMEOUT_SECS        max seconds for a single chaos exec call (default 600)
    SESSION_MAX_CONTEXT_TOKENS  roll a resumed session once its last-seen context
                                (input + cached input tokens of the final turn)
                                exceeds this (default 150000)
"""

import hashlib
import json
import os
import re
import subprocess
import threading
import logging
from datetime import datetime, timezone
from pathlib import Path
try:
    from flask import Flask, request, jsonify, abort
except ModuleNotFoundError:  # Allows prompt-building tests without Flask installed.
    Flask = None
    request = None

    def jsonify(*_args, **_kwargs):
        raise RuntimeError("Flask is required to serve trigger_shim.py")

    def abort(*_args, **_kwargs):
        raise RuntimeError("Flask is required to serve trigger_shim.py")

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
CHAOS_HOME = Path(os.environ.get("CHAOS_HOME", str(Path.home() / ".chaos")))
CHAOS_TIMEOUT_SECS = int(os.environ.get("CHAOS_TIMEOUT_SECS", "600"))
SESSION_MAP_DIR = CHAOS_HOME / "helixkit-sessions"
SESSION_MAX_CONTEXT_TOKENS = int(os.environ.get("SESSION_MAX_CONTEXT_TOKENS", "150000"))
IDENTITY_FINGERPRINT_FILES = [
    "soul.md",
    "runtime-instructions.md",
    "self-narrative.md",
    "bootstrap.md",
]
IDENTITY_FILE_LIMIT = 80_000
JOURNAL_MOST_RECENT_LIMIT = 12_000
JOURNAL_MOST_RECENT_TAIL = 10_000
JOURNAL_TOTAL_LIMIT = 16_000

logging.basicConfig(
    level=logging.INFO,
    format=f"%(asctime)s [{AGENT_LOG_LABEL}] %(levelname)s %(message)s",
)
log = logging.getLogger(AGENT_LOG_LABEL)

if not TRIGGER_BEARER_TOKEN:
    log.error("TRIGGER_BEARER_TOKEN not set; shim will reject all /trigger calls. Refusing to start.")
    raise SystemExit(2)

app = Flask(__name__) if Flask else None

# Per-session locks: two triggers for the same session_id must never resume the
# same chaos process concurrently. Flask's default server is single-threaded,
# so this is a safety net for anyone who later turns threading on.
_session_locks = {}
_session_locks_guard = threading.Lock()


# ----- routes -----
def health():
    return jsonify({"status": "ok", "agent_id": AGENT_ID, "version": _chaos_version()})


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
    request_delta = payload.get("request_delta")
    persistent_session = bool(payload.get("persistent_session"))
    model = payload.get("model", AGENT_DEFAULT_MODEL)
    timeout_secs = int(payload.get("timeout_secs") or CHAOS_TIMEOUT_SECS)
    conversation_id = payload.get("conversation_id")
    requested_by = payload.get("requested_by")

    if not session_id or not prompt:
        return jsonify({"error": "session_id and `request` (or `prompt`) are required"}), 400

    log.info(
        f"trigger session_id={session_id} conversation_id={conversation_id} "
        f"requested_by={requested_by} model={model} timeout_secs={timeout_secs} "
        f"prompt_len={len(prompt)} persistent={persistent_session} "
        f"delta_len={len(request_delta) if request_delta else 0}"
    )

    if persistent_session:
        return persistent_trigger(session_id, prompt, request_delta, model, timeout_secs)
    return legacy_trigger(session_id, prompt, model, timeout_secs)


def legacy_trigger(session_id, prompt, model, timeout_secs):
    """One fresh chaos exec per trigger — the original shim behaviour, unchanged."""
    full_prompt = build_prompt(prompt)

    try:
        result = run_chaos(model, timeout_secs, full_prompt, json_output=False)
    except subprocess.TimeoutExpired:
        log.error(f"chaos exec timed out after {timeout_secs}s")
        return jsonify({"status": "timeout", "session_id": session_id, "timeout_secs": timeout_secs}), 504

    response = {
        "status": "ok" if result.returncode == 0 else "error",
        "session_id": session_id,
        "returncode": result.returncode,
        "stdout": _tail(result.stdout, 4000),
        "stderr": _tail(result.stderr, 4000),
        "full_invocation_text": full_prompt,
    }
    log.info(f"trigger done session_id={session_id} rc={result.returncode}")
    return jsonify(response), (200 if result.returncode == 0 else 500)


def persistent_trigger(session_id, prompt, request_delta, model, timeout_secs):
    """Resume the session mapped to session_id, or start (and record) a fresh one.

    Guarantees: a resume that fails in any detectable way is retried once as a
    full fresh turn. The delta prompt is only ever sent into a session that
    actually resumed (stale-marker guard) — never into a fresh contextless one.
    """
    lock = _lock_for(session_id)
    if not lock.acquire(blocking=False):
        log.warning(f"session busy session_id={session_id}")
        return jsonify({"status": "already_running", "session_id": session_id}), 409

    try:
        record = load_session_record(session_id)
        roll = roll_reason(record, model) if record else None
        if record and roll:
            log.info(f"rolling session session_id={session_id} reason={roll}")
            retire_session_record(session_id, reason=roll)
            record = None

        if record:
            resume_prompt = request_delta or prompt
            try:
                result = run_chaos(
                    model, timeout_secs, resume_prompt,
                    json_output=True, resume_id=record["chaos_process_id"],
                )
            except subprocess.TimeoutExpired:
                # Chaos may have made partial progress; keep the mapping —
                # the next trigger resumes whatever state was persisted.
                log.error(f"chaos resume timed out after {timeout_secs}s session_id={session_id}")
                return jsonify({"status": "timeout", "session_id": session_id, "timeout_secs": timeout_secs}), 504

            events = parse_events(result.stdout)
            stale = events["process_id"] != record["chaos_process_id"]
            if result.returncode == 0 and not stale:
                update_session_record(session_id, record, events)
                return persistent_response(
                    session_id, result, events, resume_prompt,
                    resumed=True, fresh_fallback=False, roll=None,
                )

            log.warning(
                f"resume failed session_id={session_id} rc={result.returncode} "
                f"stale={stale} mapped={record['chaos_process_id']} got={events['process_id']}"
            )
            retire_session_record(session_id, reason="resume-failed")
            roll = roll or "resume-failed"

        # Fresh path: full identity-wrapped prompt, new session, new mapping.
        full_prompt = build_prompt(prompt)
        try:
            result = run_chaos(model, timeout_secs, full_prompt, json_output=True)
        except subprocess.TimeoutExpired:
            log.error(f"chaos exec timed out after {timeout_secs}s session_id={session_id}")
            return jsonify({"status": "timeout", "session_id": session_id, "timeout_secs": timeout_secs}), 504

        events = parse_events(result.stdout)
        if result.returncode == 0 and events["process_id"]:
            save_session_record(session_id, model, events)
        return persistent_response(
            session_id, result, events, full_prompt,
            resumed=False, fresh_fallback=(roll == "resume-failed"), roll=roll,
        )
    finally:
        lock.release()


if app:
    app.get("/health")(health)
    app.post("/trigger")(trigger)


# ----- chaos invocation -----
def run_chaos(model, timeout_secs, prompt_text, json_output, resume_id=None):
    args = [CHAOS_BIN, "exec"]
    if json_output:
        # Machine-readable JSONL: process.started carries the process_id we
        # map for resume; turn.completed carries token usage.
        args.append("--json")
    cwd = AGENT_REPO_PATH if AGENT_REPO_PATH.exists() else Path.home()
    args += [
        "--provider", AGENT_PROVIDER,
        "-C", str(cwd),
        "--skip-git-repo-check",
        "-m", model,
        # Docker is the sandbox boundary for hosted agents. Inside that
        # boundary the agent must be able to use Bash, write its mounted
        # identity/state folders, and call HelixKit's API back.
        "--dangerously-bypass-approvals-and-sandbox",
        "-c", "shell_environment_policy.inherit=\"all\"",
    ]
    if resume_id:
        # `resume` is an exec subcommand; root exec flags stay before it.
        args += ["resume", resume_id]
    # Read the full prompt from stdin so identity injection is not
    # constrained by shell argv limits and is not exposed in ps args.
    args.append("-")

    return subprocess.run(
        args,
        input=prompt_text,
        capture_output=True,
        text=True,
        timeout=timeout_secs,
    )


def parse_events(stdout):
    """Parse `chaos exec --json` JSONL output.

    Returns process_id, summed token usage across turns, and the agent's
    final message texts (for human-readable diagnostics).
    """
    parsed = {
        "process_id": None,
        "input_tokens": 0,
        "cached_input_tokens": 0,
        "output_tokens": 0,
        "agent_messages": [],
        "errors": [],
    }
    for line in (stdout or "").splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        kind = event.get("type")
        if kind == "process.started":
            parsed["process_id"] = event.get("process_id")
        elif kind == "turn.completed":
            usage = event.get("usage") or {}
            parsed["input_tokens"] += int(usage.get("input_tokens") or 0)
            parsed["cached_input_tokens"] += int(usage.get("cached_input_tokens") or 0)
            parsed["output_tokens"] += int(usage.get("output_tokens") or 0)
        elif kind == "item.completed":
            item = event.get("item") or {}
            if item.get("type") == "agent_message" and item.get("text"):
                parsed["agent_messages"].append(item["text"])
        elif kind in ("error", "turn.failed"):
            parsed["errors"].append(json.dumps(event))
    return parsed


def persistent_response(session_id, result, events, invocation_text, resumed, fresh_fallback, roll):
    # Prefer the agent's own message texts as diagnostics; fall back to raw
    # JSONL tail so failures stay debuggable.
    if events["agent_messages"]:
        stdout_text = "\n\n".join(events["agent_messages"])
    else:
        stdout_text = result.stdout
    if events["errors"]:
        stdout_text += "\n\n[events] " + "\n".join(events["errors"])

    response = {
        "status": "ok" if result.returncode == 0 else "error",
        "session_id": session_id,
        "returncode": result.returncode,
        "stdout": _tail(stdout_text, 4000),
        "stderr": _tail(result.stderr, 4000),
        "full_invocation_text": invocation_text,
        "chaos_session_id": events["process_id"],
        "session_resumed": resumed,
        "fresh_fallback": fresh_fallback,
        "usage": {
            "input_tokens": events["input_tokens"],
            "cached_input_tokens": events["cached_input_tokens"],
            "output_tokens": events["output_tokens"],
        },
    }
    if roll:
        response["session_roll_reason"] = roll
    log.info(
        f"trigger done session_id={session_id} rc={result.returncode} resumed={resumed} "
        f"chaos_session={events['process_id']} "
        f"usage=i{events['input_tokens']}/c{events['cached_input_tokens']}/o{events['output_tokens']}"
    )
    return jsonify(response), (200 if result.returncode == 0 else 500)


# ----- session sidecar records -----
def session_record_path(session_id):
    # Session ids are caller-supplied; never place them raw into a path.
    safe = re.sub(r"[^A-Za-z0-9._-]", "_", session_id)[:80]
    digest = hashlib.sha256(session_id.encode()).hexdigest()[:12]
    return SESSION_MAP_DIR / f"{safe}-{digest}.json"


def load_session_record(session_id):
    path = session_record_path(session_id)
    try:
        record = json.loads(path.read_text())
    except FileNotFoundError:
        return None
    except Exception as e:
        log.warning(f"unreadable session record {path}: {e}")
        return None
    if not record.get("chaos_process_id"):
        return None
    return record


def save_session_record(session_id, model, events):
    now = _utcnow_iso()
    record = {
        "helixkit_session_id": session_id,
        "chaos_process_id": events["process_id"],
        "model": model,
        "created_at": now,
        "last_finished_at": now,
        "last_context_tokens": events["input_tokens"] + events["cached_input_tokens"],
        "identity_fingerprint": identity_fingerprint(),
    }
    _atomic_write(session_record_path(session_id), record)


def update_session_record(session_id, record, events):
    record["last_finished_at"] = _utcnow_iso()
    # The final turn's input+cached is the best available proxy for the
    # session's accumulated context size.
    record["last_context_tokens"] = events["input_tokens"] + events["cached_input_tokens"]
    _atomic_write(session_record_path(session_id), record)


def retire_session_record(session_id, reason):
    path = session_record_path(session_id)
    try:
        path.rename(path.with_suffix(f".retired-{reason}.json"))
    except FileNotFoundError:
        pass
    except Exception as e:
        log.warning(f"could not retire session record {path}: {e}")
        try:
            path.unlink()
        except Exception:
            pass


def roll_reason(record, model):
    """Reasons to abandon a mapped session and start fresh. None = resume."""
    if record.get("model") != model:
        return "model-changed"
    if record.get("identity_fingerprint") != identity_fingerprint():
        return "identity-changed"
    if int(record.get("last_context_tokens") or 0) > SESSION_MAX_CONTEXT_TOKENS:
        return "context-ceiling"
    return None


def identity_fingerprint():
    """mtimes of the injected identity files; a change rolls the session so
    identity edits propagate at the next turn instead of never."""
    fingerprint = {}
    for filename in IDENTITY_FINGERPRINT_FILES:
        path = AGENT_IDENTITY_PATH / filename
        try:
            fingerprint[filename] = path.stat().st_mtime_ns
        except OSError:
            fingerprint[filename] = None
    return fingerprint


def _atomic_write(path, record):
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(record, indent=2))
        tmp.replace(path)
    except Exception as e:
        # Sidecar loss is safe (next trigger goes fresh); never fail the run.
        log.warning(f"could not write session record {path}: {e}")


def _lock_for(session_id):
    with _session_locks_guard:
        if session_id not in _session_locks:
            _session_locks[session_id] = threading.Lock()
        return _session_locks[session_id]


def _utcnow_iso():
    return datetime.now(timezone.utc).isoformat()


# ----- helpers -----
def _tail(s: str, n: int) -> str:
    """Trim long stdout/stderr so HelixKit doesn't choke on huge payloads."""
    if not s:
        return ""
    if len(s) <= n:
        return s
    return f"...[truncated {len(s) - n} chars]...\n{s[-n:]}"


def build_prompt(request_text: str) -> str:
    """Attach identity, the live request, and memory to every Chaos turn.

    Keep stable identity first, but place the current HelixKit trigger before
    diarized memory. The live request/transcript is ground truth for the current
    conversation; journals are continuity context and must not look like adjacent
    transcript.
    """
    return "\n\n".join(part for part in [identity_context(), request_text, memory_context()] if part)


def identity_context() -> str:
    """Return the stable identity context exported by HelixKit."""
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


def memory_context() -> str:
    """Return clearly labeled continuity context that is not live transcript."""
    journals = recent_journal_context()
    if not journals:
        return ""

    return "\n\n".join([
        "## Memory context — not current chat transcript",
        (
            "The following recent journals are diarized memory and continuity context. "
            "They are not current HelixKit chat messages, not trigger payload, and not "
            "the live transcript. If this turn includes a LIVE HELIXKIT TRANSCRIPT "
            "section, treat that section as the ground truth for the current conversation."
        ),
        journals,
    ])


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


def recent_journal_context() -> str:
    """Read back recent diarized memory from the identity volume.

    This is memory, not instruction: the most recent daily journal is included
    verbatim (modulo tail truncation), and the previous two days show headings
    only as a cheap index for deeper filesystem reads.
    """
    journal_dir = AGENT_IDENTITY_PATH / "memory" / "daily-journals"
    try:
        files = sorted(journal_dir.glob("????-??-??.md"), reverse=True)
    except Exception as e:
        return f"## Your recent journal entries\n\n_Could not list {journal_dir}: {e}_"

    if not files:
        return ""

    sections = [
        "## Your recent journal entries",
        (
            "Diarized memory you wrote on earlier turns. The most recent day is "
            "shown in full; earlier days show entry titles only — read the full "
            "file under `memory/daily-journals/` if a title is relevant."
        ),
    ]

    remaining = JOURNAL_TOTAL_LIMIT
    latest = render_latest_journal(files[0])
    if latest:
        latest = cap_text(latest, remaining)
        sections.append(latest)
        remaining -= len(latest)

    for path in files[1:3]:
        if remaining <= 0:
            break
        headings = render_journal_headings(path)
        if headings:
            headings = cap_text(headings, remaining)
            sections.append(headings)
            remaining -= len(headings)

    return "\n\n".join(sections)


def render_latest_journal(path: Path) -> str:
    try:
        content = path.read_text()
    except Exception as e:
        return f"### {path.name}\n\n_Could not read {path}: {e}_"

    if len(content) > JOURNAL_MOST_RECENT_LIMIT:
        first_line = content.splitlines()[0] if content.splitlines() else f"# {path.name}"
        omitted = len(content) - JOURNAL_MOST_RECENT_TAIL
        content = f"{first_line}\n\n_[older content truncated: {omitted} chars]_\n\n{content[-JOURNAL_MOST_RECENT_TAIL:]}"

    return f"### {path.name} — full recent day\n\n{content}"


def render_journal_headings(path: Path) -> str:
    try:
        headings = [line.rstrip() for line in path.read_text().splitlines() if line.startswith("## ")]
    except Exception as e:
        return f"### {path.name} — headings only\n\n_Could not read {path}: {e}_"

    if not headings:
        return f"### {path.name} — headings only\n\n_No entry headings found._"

    return f"### {path.name} — headings only\n\n" + "\n".join(headings)


def cap_text(text: str, limit: int) -> str:
    if len(text) <= limit:
        return text
    if limit <= 200:
        return text[:limit]
    return text[: limit - 80] + f"\n\n_[journal section truncated to fit {JOURNAL_TOTAL_LIMIT} chars]_"


def _chaos_version() -> str:
    try:
        out = subprocess.run([CHAOS_BIN, "--version"], capture_output=True, text=True, timeout=5)
        return out.stdout.strip() or "unknown"
    except Exception as e:
        return f"error: {e}"


if __name__ == "__main__":
    if app is None:
        raise SystemExit("Flask is required to serve trigger_shim.py")

    log.info(f"chaos-agent shim starting: port={SHIM_PORT}, chaos={_chaos_version()}")
    # 0.0.0.0 because we're inside a container; the daemon binds to all interfaces
    # and Docker handles which are externally exposed.
    app.run(host="0.0.0.0", port=SHIM_PORT, debug=False)

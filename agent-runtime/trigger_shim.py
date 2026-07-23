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
       "provider": "anthropic",                    # optional; falls back to AGENT_PROVIDER env
       "model": "claude-sonnet-4-5",               # optional; falls back to AGENT_DEFAULT_MODEL env
       "channel": "telegram",                      # optional channel-specific metadata
       "sender": {"name": "...", "email": "...", "telegram_username": "..."},
       "text": "incoming direct message",
       "thread_id": "stable-thread-id",
       "history_cursor": "latest-message-id"
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
    - The session rolls (fresh start) on: provider/model change,
      identity-file change, or any resume failure.
    - The response gains a versioned `telemetry` object describing the runtime,
      session decision, prompt sizes, and invocation-local usage. Existing
      top-level session and usage fields remain during migration.

Without `persistent_session`, each trigger still runs one fresh Chaos process
without a sidecar mapping, but JSON output is enabled so usage is observable.

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
CHAOS_ANTHROPIC_CACHE_TTL = os.environ.get("CHAOS_ANTHROPIC_CACHE_TTL")
SESSION_MAP_DIR = CHAOS_HOME / "helixkit-sessions"
SHIM_TELEMETRY_SCHEMA_VERSION = 1
SIDECAR_SCHEMA_VERSION = 2
SUPPORTED_CHAOS_TELEMETRY_SCHEMA_VERSION = 1
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
USAGE_FIELDS = (
    "input_tokens",
    "uncached_input_tokens",
    "cache_creation_input_tokens",
    "cache_read_input_tokens",
    "output_tokens",
    "reasoning_output_tokens",
    "provider_request_count",
)

logging.basicConfig(
    level=logging.INFO,
    format=f"%(asctime)s [{AGENT_LOG_LABEL}] %(levelname)s %(message)s",
)
log = logging.getLogger(AGENT_LOG_LABEL)

if not TRIGGER_BEARER_TOKEN:
    log.error("TRIGGER_BEARER_TOKEN not set; shim will reject all /trigger calls. Refusing to start.")
    raise SystemExit(2)

app = Flask(__name__) if Flask else None

# One agent-wide lock prevents independent sessions from running Chaos
# concurrently against the same writable identity and repository volumes.
# Per-session locks additionally protect persistent-session sidecar state.
_agent_invocation_lock = threading.Lock()
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
    provider = payload.get("provider", AGENT_PROVIDER)
    model = payload.get("model", AGENT_DEFAULT_MODEL)
    timeout_secs = int(payload.get("timeout_secs") or CHAOS_TIMEOUT_SECS)
    conversation_id = payload.get("conversation_id")
    requested_by = payload.get("requested_by")

    if not session_id or not prompt:
        return jsonify({"error": "session_id and `request` (or `prompt`) are required"}), 400

    log.info(
        f"trigger session_id={session_id} conversation_id={conversation_id} "
        f"requested_by={requested_by} provider={provider} model={model} timeout_secs={timeout_secs} "
        f"prompt_len={len(prompt)} persistent={persistent_session} "
        f"delta_len={len(request_delta) if request_delta else 0}"
    )

    with _agent_invocation_lock:
        if persistent_session:
            return persistent_trigger(session_id, prompt, request_delta, model, timeout_secs, provider=provider)
        return legacy_trigger(session_id, prompt, model, timeout_secs, provider=provider)


def legacy_trigger(session_id, prompt, model, timeout_secs, provider=None):
    """Run a fresh, unmapped Chaos process while still capturing JSON telemetry."""
    provider = provider or AGENT_PROVIDER
    full_prompt, prompt_components = build_prompt_with_components(prompt)
    prompt_info = prompt_telemetry(
        full_prompt=full_prompt,
        delta_prompt=None,
        selected_prompt=full_prompt,
        mode="full",
        components=prompt_components,
    )

    try:
        result = run_chaos(model, timeout_secs, full_prompt, json_output=True, provider=provider)
    except subprocess.TimeoutExpired as error:
        log.error(f"chaos exec timed out after {timeout_secs}s")
        return timeout_response(
            session_id=session_id,
            timeout_secs=timeout_secs,
            runtime=runtime_telemetry(provider, model, timeout_secs),
            session=session_telemetry(
                session_id=session_id,
                mapping_found=False,
                resume_attempted=False,
                outcome="failed",
                roll_reason=None,
                changed_identity_files=[],
                prior_process_id=None,
                process_id=None,
                record=None,
                trigger_sequence=1,
                persistent_requested=False,
            ),
            prompt=prompt_info,
            timeout_error=error,
            invocation_text=full_prompt,
            resumed=False,
            fresh_fallback=False,
        )

    events = parse_events(result.stdout)
    usage = invocation_usage(None, events)
    outcome = "legacy_fresh" if result.returncode == 0 else "failed"
    return instrumented_response(
        session_id,
        result,
        events,
        full_prompt,
        usage=usage,
        runtime=runtime_telemetry(provider, model, timeout_secs, events),
        session=session_telemetry(
            session_id=session_id,
            mapping_found=False,
            resume_attempted=False,
            outcome=outcome,
            roll_reason=None,
            changed_identity_files=[],
            prior_process_id=None,
            process_id=events["process_id"],
            record=None,
            trigger_sequence=1,
            persistent_requested=False,
        ),
        prompt=prompt_info,
        resumed=False,
        fresh_fallback=False,
        roll=None,
    )


def persistent_trigger(session_id, prompt, request_delta, model, timeout_secs, provider=None):
    """Resume the session mapped to session_id, or start (and record) a fresh one.

    A resume that fails in any detectable way is retried once as a full fresh
    turn. Chaos reveals a stale id only after the attempted run, so the retry
    repairs future context but cannot undo side effects from that rare attempt.
    """
    lock = _lock_for(session_id)
    if not lock.acquire(blocking=False):
        log.warning(f"session busy session_id={session_id}")
        return jsonify({
            "status": "already_running",
            "session_id": session_id,
            "telemetry": build_telemetry(
                runtime=runtime_telemetry(provider or AGENT_PROVIDER, model, timeout_secs),
                session={
                    "logical_session_id": session_id,
                    "persistent_requested": True,
                    "mapping_found": None,
                    "resume_attempted": False,
                    "outcome": "already_running",
                    "roll_reason": None,
                    "changed_identity_files": [],
                    "prior_chaos_process_id": None,
                    "chaos_process_id": None,
                    "trigger_sequence": None,
                    "session_age_seconds": None,
                },
                prompt=None,
                usage=None,
            ),
        }), 409

    try:
        provider = provider or AGENT_PROVIDER
        prior_attempt = None
        record = load_session_record(session_id)
        mapping_found = record is not None
        prior_process_id = record.get("chaos_process_id") if record else None
        roll, changed_identity_files = roll_decision(record, model, provider) if record else (None, [])
        if record and roll:
            log.info(f"rolling session session_id={session_id} reason={roll}")
            retire_session_record(session_id, reason=roll)
            record = None

        if record:
            resume_prompt = request_delta or prompt
            prompt_info = prompt_telemetry(
                full_prompt=None,
                delta_prompt=request_delta,
                selected_prompt=resume_prompt,
                mode="delta",
                components=None,
            )
            try:
                result = run_chaos(
                    model, timeout_secs, resume_prompt,
                    json_output=True, resume_id=record["chaos_process_id"], provider=provider,
                )
            except subprocess.TimeoutExpired as error:
                # The subprocess is killed on timeout, so the persisted session
                # may contain only part of this turn. Retire the ambiguous
                # mapping: the next trigger will use the full prompt instead of
                # replaying the same delta into a possibly half-written turn.
                log.error(f"chaos resume timed out after {timeout_secs}s session_id={session_id}")
                retire_session_record(session_id, reason="resume-timeout")
                return timeout_response(
                    session_id=session_id,
                    timeout_secs=timeout_secs,
                    runtime=runtime_telemetry(provider, model, timeout_secs),
                    session=session_telemetry(
                        session_id=session_id,
                        mapping_found=True,
                        resume_attempted=True,
                        outcome="resume_timeout",
                        roll_reason="resume-timeout",
                        changed_identity_files=[],
                        prior_process_id=prior_process_id,
                        process_id=prior_process_id,
                        record=record,
                    ),
                    prompt=prompt_info,
                    timeout_error=error,
                    usage_record=record,
                    invocation_text=resume_prompt,
                    resumed=False,
                    fresh_fallback=False,
                )

            events = parse_events(result.stdout)
            stale = events["process_id"] != record["chaos_process_id"]
            if result.returncode == 0 and not stale:
                usage = invocation_usage(record, events)
                next_sequence = next_trigger_sequence(record)
                update_session_record(session_id, record, events)
                return instrumented_response(
                    session_id, result, events, resume_prompt,
                    usage=usage,
                    runtime=runtime_telemetry(provider, model, timeout_secs, events),
                    session=session_telemetry(
                        session_id=session_id,
                        mapping_found=True,
                        resume_attempted=True,
                        outcome="resumed",
                        roll_reason=None,
                        changed_identity_files=[],
                        prior_process_id=prior_process_id,
                        process_id=events["process_id"],
                        record=record,
                        trigger_sequence=next_sequence,
                    ),
                    prompt=prompt_info,
                    resumed=True,
                    fresh_fallback=False,
                    roll=None,
                )

            log.warning(
                f"resume failed session_id={session_id} rc={result.returncode} "
                f"stale={stale} mapped={record['chaos_process_id']} got={events['process_id']}"
            )
            retire_session_record(session_id, reason="resume-failed")
            prior_attempt = {
                "usage": invocation_usage(record, events),
                "detailed": events["telemetry_status"] == "detailed",
            }
            if prior_attempt["detailed"] and result.returncode != 0:
                prior_attempt["usage"] = dict(prior_attempt["usage"] or {})
                prior_attempt["usage"]["complete"] = False
            roll = roll or "resume-failed"
            changed_identity_files = []

        # Fresh path: full identity-wrapped prompt, new session, new mapping.
        # Build this only after deciding not to resume. Reading journals on a
        # successful resume is unnecessary work and can make an append appear
        # to affect a turn whose actual prompt contains only the delta.
        full_prompt, prompt_components = build_prompt_with_components(prompt)
        prompt_info = prompt_telemetry(
            full_prompt=full_prompt,
            delta_prompt=request_delta,
            selected_prompt=full_prompt,
            mode="full",
            components=prompt_components,
        )
        try:
            result = run_chaos(model, timeout_secs, full_prompt, json_output=True, provider=provider)
        except subprocess.TimeoutExpired as error:
            log.error(f"chaos exec timed out after {timeout_secs}s session_id={session_id}")
            outcome = "fresh_fallback" if roll == "resume-failed" else ("rolled" if mapping_found else "failed")
            return timeout_response(
                session_id=session_id,
                timeout_secs=timeout_secs,
                runtime=runtime_telemetry(provider, model, timeout_secs),
                session=session_telemetry(
                    session_id=session_id,
                    mapping_found=mapping_found,
                    resume_attempted=(roll == "resume-failed"),
                    outcome=outcome,
                    roll_reason=roll,
                    changed_identity_files=changed_identity_files,
                    prior_process_id=prior_process_id,
                    process_id=None,
                    record=None,
                    trigger_sequence=1,
                ),
                prompt=prompt_info,
                timeout_error=error,
                invocation_text=full_prompt,
                resumed=False,
                fresh_fallback=(roll == "resume-failed"),
                roll=roll,
                prior_attempt=prior_attempt,
            )

        events = parse_events(result.stdout)
        usage = invocation_usage(None, events)
        if result.returncode == 0 and events["process_id"]:
            save_session_record(session_id, model, events, provider=provider)
        if result.returncode != 0:
            outcome = "failed"
        elif roll == "resume-failed":
            outcome = "fresh_fallback"
        elif mapping_found:
            outcome = "rolled"
        else:
            outcome = "fresh"
        return instrumented_response(
            session_id, result, events, full_prompt,
            usage=usage,
            runtime=runtime_telemetry(provider, model, timeout_secs, events),
            session=session_telemetry(
                session_id=session_id,
                mapping_found=mapping_found,
                resume_attempted=(roll == "resume-failed"),
                outcome=outcome,
                roll_reason=roll,
                changed_identity_files=changed_identity_files,
                prior_process_id=prior_process_id,
                process_id=events["process_id"],
                record=None,
                trigger_sequence=1,
            ),
            prompt=prompt_info,
            resumed=False,
            fresh_fallback=(roll == "resume-failed"),
            roll=roll,
            prior_attempt=prior_attempt,
        )
    finally:
        lock.release()


if app:
    app.get("/health")(health)
    app.post("/trigger")(trigger)


# ----- chaos invocation -----
def run_chaos(model, timeout_secs, prompt_text, json_output, resume_id=None, provider=None):
    args = [CHAOS_BIN, "exec"]
    if json_output:
        # Machine-readable JSONL: process.started carries the process_id we
        # map for resume; turn.completed carries token usage.
        args.append("--json")
    cwd = AGENT_REPO_PATH if AGENT_REPO_PATH.exists() else Path.home()
    args += [
        "--provider", provider or AGENT_PROVIDER,
        "-C", str(cwd),
        "--skip-git-repo-check",
        "-m", model,
        # Docker is the sandbox boundary for hosted agents. Inside that
        # boundary the agent must be able to use Bash, write its mounted
        # identity/state folders, and call HelixKit's API back.
        "--headless",
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

    Version-1 Chaos telemetry is invocation-local and safe to persist directly.
    Older events are retained as explicitly legacy cumulative counters so they
    cannot accidentally populate the new detailed usage fields.
    """
    parsed = {
        "process_id": None,
        "telemetry_schema_version": None,
        "telemetry_status": "missing",
        "usage": None,
        "session_usage": None,
        "unsupported_telemetry_schema_version": None,
        "legacy_cumulative_usage": None,
        # Compatibility aliases for the old cumulative subtraction path.
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
        elif kind in ("turn.completed", "invocation.completed"):
            _parse_completion_event(parsed, event)
        elif kind == "item.completed":
            item = event.get("item") or {}
            if item.get("type") == "agent_message" and item.get("text"):
                parsed["agent_messages"].append(item["text"])
        elif kind in ("error", "turn.failed"):
            parsed["errors"].append(json.dumps(event))
    return parsed


def _parse_completion_event(parsed, event):
    usage = event.get("usage") or {}
    schema_version = _optional_int(event.get("telemetry_schema_version"))
    parsed.update({
        "telemetry_schema_version": schema_version,
        "telemetry_status": "missing",
        "usage": None,
        "session_usage": None,
        "unsupported_telemetry_schema_version": None,
        "legacy_cumulative_usage": None,
        "input_tokens": 0,
        "cached_input_tokens": 0,
        "output_tokens": 0,
    })

    if schema_version is None:
        legacy = {
            "input_tokens": _int_or_zero(usage.get("input_tokens")),
            "cached_input_tokens": _int_or_zero(usage.get("cached_input_tokens")),
            "output_tokens": _int_or_zero(usage.get("output_tokens")),
        }
        if _has_additive_legacy_usage(usage):
            cache_read = (
                usage.get("cache_read_input_tokens")
                if "cache_read_input_tokens" in usage
                else usage.get("cached_input_tokens")
            )
            legacy.update({
                "uncached_input_tokens": _optional_int(usage.get("uncached_input_tokens")),
                "cache_creation_input_tokens": _optional_int(usage.get("cache_creation_input_tokens")),
                "cache_read_input_tokens": _optional_int(cache_read),
                "reasoning_output_tokens": _optional_int(usage.get("reasoning_output_tokens")),
                "provider_request_count": _optional_int(usage.get("provider_request_count")),
            })
        parsed["telemetry_status"] = "legacy"
        parsed["legacy_cumulative_usage"] = legacy
        parsed.update(legacy)
        return

    if schema_version != SUPPORTED_CHAOS_TELEMETRY_SCHEMA_VERSION:
        parsed["telemetry_status"] = "unsupported"
        parsed["unsupported_telemetry_schema_version"] = schema_version
        return

    if usage.get("scope") != "invocation":
        parsed["telemetry_status"] = "invalid_scope"
        return

    parsed["telemetry_status"] = "detailed"
    parsed["usage"] = normalize_usage(usage)
    session_usage = event.get("session_usage")
    if isinstance(session_usage, dict) and session_usage.get("scope") == "process_cumulative":
        parsed["session_usage"] = normalize_usage(session_usage)


def normalize_usage(usage):
    normalized = {"scope": usage.get("scope")}
    for field in USAGE_FIELDS:
        value = usage.get(field)
        if field == "cache_read_input_tokens" and field not in usage:
            value = usage.get("cached_input_tokens")
        normalized[field] = _optional_int(value)
    if "complete" in usage:
        normalized["complete"] = usage["complete"] if isinstance(usage["complete"], bool) else None
    return normalized


def invocation_usage(record, events):
    """Return new invocation-local usage, or a coarse old-runtime fallback."""
    if events["telemetry_status"] == "detailed":
        return events["usage"]
    if events["telemetry_status"] == "legacy":
        return usage_since(record, events)
    return None


def usage_since(record, events):
    """Compatibility only: subtract old Chaos process-cumulative counters."""
    record = record or {}
    usage = {}
    cumulative_usage = events.get("legacy_cumulative_usage") or {
        key: events.get(key)
        for key in ("input_tokens", "cached_input_tokens", "output_tokens")
    }
    for key, current_value in cumulative_usage.items():
        if current_value is None:
            usage[key] = None
            continue
        previous = int(record.get(f"cumulative_{key}") or 0)
        current = int(current_value)
        # A future Chaos compaction or accounting change may reset a cumulative
        # counter. Treat the new value as this trigger's usage rather than
        # incorrectly reporting zero forever after the reset.
        usage[key] = current - previous if current >= previous else current
    return usage


def instrumented_response(
    session_id,
    result,
    events,
    invocation_text,
    usage,
    runtime,
    session,
    prompt,
    resumed,
    fresh_fallback,
    roll,
    prior_attempt=None,
):
    # Prefer the agent's own message texts as diagnostics; fall back to raw
    # JSONL tail so failures stay debuggable.
    if events["agent_messages"]:
        stdout_text = "\n\n".join(events["agent_messages"])
    else:
        stdout_text = result.stdout
    if events["errors"]:
        stdout_text += "\n\n[events] " + "\n".join(events["errors"])

    telemetry_usage = response_invocation_usage(events, result.returncode)
    compatibility_usage = compatibility_usage_fields(telemetry_usage or usage)
    chaos_telemetry_status = events["telemetry_status"]
    if prior_attempt:
        compatibility_usage = aggregate_attempt_usage(
            compatibility_usage_fields(prior_attempt.get("usage")),
            compatibility_usage,
        )
        compatibility_usage = compatibility_usage_fields(compatibility_usage)
        if prior_attempt.get("detailed") and telemetry_usage is not None:
            telemetry_usage = aggregate_attempt_usage(prior_attempt.get("usage"), telemetry_usage)
        else:
            telemetry_usage = None
            chaos_telemetry_status = "mixed"
    if result.returncode != 0:
        compatibility_usage = dict(compatibility_usage)
        compatibility_usage["complete"] = False
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
        "usage": compatibility_usage,
        "telemetry": build_telemetry(
            runtime=runtime,
            session=session,
            prompt=prompt,
            usage=telemetry_usage,
            session_usage=events["session_usage"],
            chaos_telemetry_status=chaos_telemetry_status,
            unsupported_chaos_schema=events["unsupported_telemetry_schema_version"],
        ),
    }
    if roll:
        response["session_roll_reason"] = roll
    log.info(
        f"trigger done session_id={session_id} rc={result.returncode} resumed={resumed} "
        f"chaos_session={events['process_id']} "
        f"telemetry={events['telemetry_status']} "
        f"usage=i{compatibility_usage.get('input_tokens')}/"
        f"c{compatibility_usage.get('cached_input_tokens')}/"
        f"o{compatibility_usage.get('output_tokens')}"
    )
    return jsonify(response), (200 if result.returncode == 0 else 500)


def response_invocation_usage(events, returncode):
    """Return detailed usage, marking failed shim invocations incomplete."""
    if events["telemetry_status"] != "detailed":
        return None
    usage = dict(events["usage"])
    if returncode != 0:
        usage["complete"] = False
    return usage


def compatibility_usage_fields(usage):
    if not usage:
        return {}
    if "cache_read_input_tokens" in usage:
        return {
            **usage,
            "cached_input_tokens": usage.get("cache_read_input_tokens"),
        }
    return usage


def aggregate_attempt_usage(first, second):
    """Aggregate all Chaos invocations caused by one HelixKit trigger."""
    if not first:
        return second or {}
    if not second:
        return first or {}

    aggregate = {"scope": "trigger"}
    for field in USAGE_FIELDS:
        left = first.get(field)
        if field == "cache_read_input_tokens" and left is None:
            left = first.get("cached_input_tokens")
        right = second.get(field)
        if field == "cache_read_input_tokens" and right is None:
            right = second.get("cached_input_tokens")
        aggregate[field] = left + right if left is not None and right is not None else None

    complete_values = [usage.get("complete") for usage in (first, second)]
    aggregate["complete"] = all(value is not False for value in complete_values)
    return aggregate


def build_telemetry(
    runtime,
    session,
    prompt,
    usage,
    session_usage=None,
    chaos_telemetry_status=None,
    unsupported_chaos_schema=None,
):
    telemetry = {
        "schema_version": SHIM_TELEMETRY_SCHEMA_VERSION,
        "runtime": runtime,
        "session": session,
        "prompt": prompt,
        "usage": usage,
    }
    if session_usage is not None:
        telemetry["session_usage"] = session_usage
    if chaos_telemetry_status:
        telemetry["chaos_telemetry_status"] = chaos_telemetry_status
    if unsupported_chaos_schema is not None:
        telemetry["unsupported_chaos_telemetry_schema_version"] = unsupported_chaos_schema
    return telemetry


def runtime_telemetry(provider, model, timeout_secs, events=None):
    return {
        "chaos_version": _chaos_version(),
        "provider": provider,
        "model": model,
        "cache_ttl": effective_cache_ttl(provider),
        "timeout_seconds": timeout_secs,
        "chaos_telemetry_schema_version": (
            events.get("telemetry_schema_version") if events else None
        ),
    }


def effective_cache_ttl(provider):
    if provider != "anthropic":
        return "unknown"
    value = (CHAOS_ANTHROPIC_CACHE_TTL or "").strip().lower()
    return value if value in ("off", "5m", "1h") else "unknown"


def session_telemetry(
    session_id,
    mapping_found,
    resume_attempted,
    outcome,
    roll_reason,
    changed_identity_files,
    prior_process_id,
    process_id,
    record,
    trigger_sequence=None,
    persistent_requested=True,
):
    return {
        "logical_session_id": session_id,
        "persistent_requested": persistent_requested,
        "mapping_found": mapping_found,
        "resume_attempted": resume_attempted,
        "outcome": outcome,
        "roll_reason": roll_reason,
        "changed_identity_files": changed_identity_files,
        "prior_chaos_process_id": prior_process_id,
        "chaos_process_id": process_id,
        "sidecar_created_at": record.get("created_at") if record else None,
        "sidecar_last_finished_at": record.get("last_finished_at") if record else None,
        "session_age_seconds": _session_age_seconds(record),
        "trigger_sequence": trigger_sequence,
    }


def timeout_response(
    session_id,
    timeout_secs,
    runtime,
    session,
    prompt,
    timeout_error=None,
    usage_record=None,
    invocation_text=None,
    resumed=False,
    fresh_fallback=False,
    roll=None,
    prior_attempt=None,
):
    stdout = _timeout_stream(timeout_error, "stdout")
    stderr = _timeout_stream(timeout_error, "stderr")
    events = parse_events(stdout)
    usage = invocation_usage(usage_record, events)
    telemetry_usage = response_invocation_usage(events, returncode=1)
    compatibility_usage = compatibility_usage_fields(telemetry_usage or usage)
    chaos_telemetry_status = "incomplete"
    if prior_attempt:
        compatibility_usage = aggregate_attempt_usage(
            compatibility_usage_fields(prior_attempt.get("usage")),
            compatibility_usage,
        )
        compatibility_usage = compatibility_usage_fields(compatibility_usage)
        if prior_attempt.get("detailed") and telemetry_usage is not None:
            telemetry_usage = aggregate_attempt_usage(prior_attempt.get("usage"), telemetry_usage)
        else:
            telemetry_usage = None
            chaos_telemetry_status = "mixed_incomplete"
    compatibility_usage["complete"] = False

    runtime = dict(runtime)
    runtime["chaos_telemetry_schema_version"] = events["telemetry_schema_version"]
    session = dict(session)
    if not session.get("chaos_process_id") and events["process_id"]:
        session["chaos_process_id"] = events["process_id"]

    response = {
        "status": "timeout",
        "session_id": session_id,
        "timeout_secs": timeout_secs,
        "returncode": None,
        "stdout": _tail(stdout, 4000),
        "stderr": _tail(stderr, 4000),
        "full_invocation_text": invocation_text,
        "chaos_session_id": session.get("chaos_process_id"),
        "session_resumed": resumed,
        "fresh_fallback": fresh_fallback,
        "usage": compatibility_usage,
        "telemetry": build_telemetry(
            runtime=runtime,
            session=session,
            prompt=prompt,
            usage=telemetry_usage,
            session_usage=events["session_usage"],
            chaos_telemetry_status=chaos_telemetry_status,
            unsupported_chaos_schema=events["unsupported_telemetry_schema_version"],
        ),
    }
    if roll:
        response["session_roll_reason"] = roll
    return jsonify(response), 504


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


def save_session_record(session_id, model, events, provider=None):
    now = _utcnow_iso()
    record = {
        "schema_version": SIDECAR_SCHEMA_VERSION,
        "helixkit_session_id": session_id,
        "chaos_process_id": events["process_id"],
        "provider": provider or AGENT_PROVIDER,
        "model": model,
        "created_at": now,
        "last_finished_at": now,
        "trigger_sequence": 1,
        "identity_fingerprint": identity_fingerprint(),
    }
    _store_legacy_cumulative_usage(record, events)
    _atomic_write(session_record_path(session_id), record)


def update_session_record(session_id, record, events):
    record["schema_version"] = SIDECAR_SCHEMA_VERSION
    record["last_finished_at"] = _utcnow_iso()
    record["trigger_sequence"] = next_trigger_sequence(record)
    record["identity_fingerprint"] = identity_fingerprint()
    _store_legacy_cumulative_usage(record, events)
    _atomic_write(session_record_path(session_id), record)


def _store_legacy_cumulative_usage(record, events):
    legacy = events.get("legacy_cumulative_usage")
    if not legacy:
        return
    for key, value in legacy.items():
        if value is not None:
            record[f"cumulative_{key}"] = value


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


def roll_decision(record, model, provider=None):
    """Return (reason, changed identity files); reason None means resume."""
    schema_version = _optional_int(record.get("schema_version", 1))
    if schema_version is None or schema_version > SIDECAR_SCHEMA_VERSION:
        return "sidecar-schema-unsupported", []
    if record.get("provider", AGENT_PROVIDER) != (provider or AGENT_PROVIDER):
        return "provider-changed", []
    if record.get("model") != model:
        return "model-changed", []
    changed_files = changed_identity_files(record.get("identity_fingerprint") or {})
    if changed_files:
        return "identity-changed", changed_files
    return None, []


def roll_reason(record, model, provider=None):
    """Compatibility wrapper for callers that only need the reason."""
    reason, _changed_files = roll_decision(record, model, provider)
    return reason


def identity_fingerprint():
    """Content fingerprints for identity files that require a session roll."""
    fingerprint = {}
    for filename in IDENTITY_FINGERPRINT_FILES:
        path = AGENT_IDENTITY_PATH / filename
        try:
            content = path.read_bytes()
            fingerprint[filename] = {
                "sha256": hashlib.sha256(content).hexdigest(),
                "bytes": len(content),
            }
        except OSError:
            fingerprint[filename] = None
    return fingerprint


def changed_identity_files(previous_fingerprint):
    current = identity_fingerprint()
    changed = []
    for filename in IDENTITY_FINGERPRINT_FILES:
        previous = previous_fingerprint.get(filename)
        if isinstance(previous, int):
            # Schema-v1 sidecars stored mtimes. They can safely resume while the
            # mtime is unchanged; the next successful write upgrades to hashes.
            try:
                unchanged = AGENT_IDENTITY_PATH.joinpath(filename).stat().st_mtime_ns == previous
            except OSError:
                unchanged = previous is None
        else:
            unchanged = previous == current.get(filename)
        if not unchanged:
            changed.append(filename)
    return changed


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


def _session_age_seconds(record):
    if not record or not record.get("created_at"):
        return 0 if record is None else None
    try:
        created_at = datetime.fromisoformat(record["created_at"])
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)
        return max(0, int((datetime.now(timezone.utc) - created_at).total_seconds()))
    except (TypeError, ValueError):
        return None


def next_trigger_sequence(record):
    """Increment old, missing, or malformed sidecar sequence values safely."""
    current = _optional_int((record or {}).get("trigger_sequence"))
    return max(0, current or 0) + 1


def _has_additive_legacy_usage(usage):
    return any(
        field in usage
        for field in (
            "uncached_input_tokens",
            "cache_creation_input_tokens",
            "cache_read_input_tokens",
            "reasoning_output_tokens",
            "provider_request_count",
        )
    )


def _timeout_stream(error, name):
    value = getattr(error, name, None) if error else None
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value or ""


def _optional_int(value):
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _int_or_zero(value):
    parsed = _optional_int(value)
    return parsed if parsed is not None else 0


def _byte_length(text):
    if text is None:
        return None
    return len(text.encode("utf-8"))


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
    prompt, _components = build_prompt_with_components(request_text)
    return prompt


def build_prompt_with_components(request_text):
    """Build a fresh prompt and return byte sizes without retaining its contents twice."""
    identity = identity_context()
    journals = memory_context()
    parts = [part for part in (identity, request_text, journals) if part]
    prompt = "\n\n".join(parts)
    return prompt, {
        "identity": _byte_length(identity),
        "request": _byte_length(request_text),
        "journal": _byte_length(journals),
    }


def prompt_telemetry(full_prompt, delta_prompt, selected_prompt, mode, components):
    return {
        "mode": mode,
        "full_prompt_bytes": _byte_length(full_prompt),
        "delta_prompt_bytes": _byte_length(delta_prompt),
        "selected_prompt_bytes": _byte_length(selected_prompt),
        "components": components or {},
    }


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

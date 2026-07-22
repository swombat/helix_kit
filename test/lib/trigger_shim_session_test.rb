require "test_helper"
require "tmpdir"

# Exercises trigger_shim.py's persistent-session machinery (sidecar records,
# JSONL event parsing, resume-or-fresh decision, stale-marker guard) by
# driving the Python module directly, with CHAOS_BIN pointed at a fake chaos
# script. Mirrors the harness style of trigger_shim_prompt_test.rb.
class TriggerShimSessionTest < ActiveSupport::TestCase

  test "runtime image includes the journald companion required for resume" do
    dockerfile = Rails.root.join("agent-runtime/Dockerfile").read

    assert_includes dockerfile, "cargo build --release --bin chaos_journald"
    assert_includes dockerfile, "COPY --from=builder /usr/local/bin/chaos_journald /usr/local/bin/chaos_journald"
  end

  test "runtime config installs RubyLLM providers not bundled by Chaos" do
    entrypoint = Rails.root.join("agent-runtime/entrypoint.sh").read

    Agents::Sandbox::CHAOS_RUNTIME_PROVIDER_IDS.each do |provider|
      assert_includes entrypoint, "[model_providers.#{provider}]"
    end

    assert_includes entrypoint, "https://generativelanguage.googleapis.com/v1beta/openai"
    assert_includes entrypoint, "https://openrouter.ai/api/v1"
  end

  test "parse_events keeps old cumulative usage explicitly legacy" do
    out = run_shim_python(<<~PY)
      events = "\\n".join([
        '{"type":"process.started","process_id":"pid-123"}',
        'garbage line',
        '{"type":"turn.completed","usage":{"input_tokens":100,"cached_input_tokens":40,"output_tokens":7}}',
        '{"type":"item.completed","item":{"id":"1","type":"agent_message","text":"hello"}}',
        '{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":140,"output_tokens":3}}',
      ])
      parsed = mod.parse_events(events)
      print(json.dumps(parsed))
    PY

    parsed = JSON.parse(out)
    assert_equal "pid-123", parsed["process_id"]
    assert_equal 10, parsed["input_tokens"]
    assert_equal 140, parsed["cached_input_tokens"]
    assert_equal 3, parsed["output_tokens"]
    assert_equal "legacy", parsed["telemetry_status"]
    assert_nil parsed["usage"]
    assert_equal [ "hello" ], parsed["agent_messages"]
  end

  test "parse_events preserves versioned invocation usage and unknown values" do
    out = run_shim_python(<<~PY)
      events = "\\n".join([
        '{"type":"process.started","process_id":"pid-123"}',
        '{"type":"turn.completed","telemetry_schema_version":1,"usage":' +
          '{"scope":"invocation","input_tokens":100,"uncached_input_tokens":10,' +
          '"cache_creation_input_tokens":20,"cache_read_input_tokens":70,' +
          '"output_tokens":7,"provider_request_count":2}}',
      ])
      print(json.dumps(mod.parse_events(events)))
    PY

    parsed = JSON.parse(out)
    assert_equal "detailed", parsed["telemetry_status"]
    assert_equal 1, parsed["telemetry_schema_version"]
    assert_equal "invocation", parsed.dig("usage", "scope")
    assert_equal 20, parsed.dig("usage", "cache_creation_input_tokens")
    assert_equal 70, parsed.dig("usage", "cache_read_input_tokens")
    assert_equal 2, parsed.dig("usage", "provider_request_count")
    assert_nil parsed.dig("usage", "reasoning_output_tokens")
  end

  test "unversioned additive Chaos counters remain available for compatibility subtraction" do
    out = run_shim_python(<<~PY)
      events = mod.parse_events(
        '{"type":"turn.completed","usage":' +
        '{"input_tokens":1000,"cache_creation_input_tokens":40,"cached_input_tokens":700,' +
        '"output_tokens":20,"reasoning_output_tokens":4,"provider_request_count":5}}'
      )
      record = {
        "cumulative_input_tokens": 900,
        "cumulative_cache_creation_input_tokens": 25,
        "cumulative_cached_input_tokens": 650,
        "cumulative_cache_read_input_tokens": 650,
        "cumulative_output_tokens": 18,
        "cumulative_reasoning_output_tokens": 3,
        "cumulative_provider_request_count": 4,
      }
      print(json.dumps({
        "parsed": events["legacy_cumulative_usage"],
        "invocation": mod.usage_since(record, events),
      }))
    PY

    result = JSON.parse(out)
    assert_equal 40, result.dig("parsed", "cache_creation_input_tokens")
    assert_equal 700, result.dig("parsed", "cache_read_input_tokens")
    assert_nil result.dig("parsed", "uncached_input_tokens")
    assert_equal 15, result.dig("invocation", "cache_creation_input_tokens")
    assert_equal 50, result.dig("invocation", "cache_read_input_tokens")
    assert_equal 1, result.dig("invocation", "provider_request_count")
    assert_equal 1, result.dig("invocation", "reasoning_output_tokens")
  end

  test "parse_events selects the final versioned completion and keeps cumulative diagnostics separate" do
    out = run_shim_python(<<~PY)
      events = "\\n".join([
        '{"type":"turn.completed","telemetry_schema_version":1,"usage":' +
          '{"scope":"invocation","input_tokens":10,"output_tokens":1}}',
        '{"type":"invocation.completed","telemetry_schema_version":1,"usage":' +
          '{"scope":"invocation","input_tokens":20,"uncached_input_tokens":0,' +
          '"cache_creation_input_tokens":5,"cache_read_input_tokens":15,"output_tokens":2,' +
          '"provider_request_count":3},"session_usage":' +
          '{"scope":"process_cumulative","input_tokens":200,"output_tokens":20}}',
      ])
      print(json.dumps(mod.parse_events(events)))
    PY

    parsed = JSON.parse(out)
    assert_equal 20, parsed.dig("usage", "input_tokens")
    assert_equal 0, parsed.dig("usage", "uncached_input_tokens")
    assert_equal 3, parsed.dig("usage", "provider_request_count")
    assert_equal "process_cumulative", parsed.dig("session_usage", "scope")
    assert_equal 200, parsed.dig("session_usage", "input_tokens")
  end

  test "parse_events rejects unsupported telemetry versions without inventing usage" do
    out = run_shim_python(<<~PY)
      event = '{"type":"turn.completed","telemetry_schema_version":99,"usage":' + \
        '{"scope":"invocation","input_tokens":100}}'
      print(json.dumps(mod.parse_events(event)))
    PY

    parsed = JSON.parse(out)
    assert_equal "unsupported", parsed["telemetry_status"]
    assert_equal 99, parsed["unsupported_telemetry_schema_version"]
    assert_nil parsed["usage"]
  end

  test "the final completion event replaces earlier detailed telemetry" do
    out = run_shim_python(<<~PY)
      events = "\\n".join([
        '{"type":"turn.completed","telemetry_schema_version":1,"usage":' +
          '{"scope":"invocation","input_tokens":100}}',
        '{"type":"invocation.completed","telemetry_schema_version":99,"usage":' +
          '{"scope":"invocation","input_tokens":200}}',
      ])
      print(json.dumps(mod.parse_events(events)))
    PY

    parsed = JSON.parse(out)
    assert_equal "unsupported", parsed["telemetry_status"]
    assert_equal 99, parsed["telemetry_schema_version"]
    assert_equal 99, parsed["unsupported_telemetry_schema_version"]
    assert_nil parsed["usage"]
    assert_nil parsed["session_usage"]
  end

  test "failed versioned invocations are explicitly incomplete" do
    out = run_shim_python(<<~PY)
      events = mod.parse_events(
        '{"type":"turn.completed","telemetry_schema_version":1,"usage":' +
        '{"scope":"invocation","input_tokens":100,"complete":true}}'
      )
      print(json.dumps({
        "parsed": events["usage"],
        "successful": mod.response_invocation_usage(events, 0),
        "failed": mod.response_invocation_usage(events, 1),
      }))
    PY

    result = JSON.parse(out)
    assert_equal true, result.dig("parsed", "complete")
    assert_equal true, result.dig("successful", "complete")
    assert_equal false, result.dig("failed", "complete")
  end

  test "session records use content hashes and name changed identity files" do
    out = run_shim_python(<<~PY)
      events = mod.parse_events('{"type":"process.started","process_id":"pid-abc"}\\n' +
        '{"type":"turn.completed","usage":{"input_tokens":50,"cached_input_tokens":0,"output_tokens":5}}')
      mod.save_session_record("sess-1", "claude-opus-4-7", events, provider="anthropic")
      record = mod.load_session_record("sess-1")
      checks = {
        "loaded_pid": record["chaos_process_id"],
        "schema_version": record["schema_version"],
        "cumulative_input_tokens": record["cumulative_input_tokens"],
        "soul_fingerprint": record["identity_fingerprint"]["soul.md"],
        "same_model": mod.roll_reason(record, "claude-opus-4-7", "anthropic"),
        "other_model": mod.roll_reason(record, "claude-haiku-4-5", "anthropic"),
        "other_provider": mod.roll_reason(record, "claude-opus-4-7", "openrouter"),
      }

      # A same-content touch must not roll a live session.
      import os
      soul = mod.AGENT_IDENTITY_PATH / "soul.md"
      os.utime(soul, ns=(soul.stat().st_atime_ns, soul.stat().st_mtime_ns + 1_000_000))
      checks["same_content_touch"] = mod.roll_reason(record, "claude-opus-4-7", "anthropic")
      soul.write_text("SOUL CHANGED\\n")
      checks["identity_changed"], checks["changed_files"] = mod.roll_decision(
          record, "claude-opus-4-7", "anthropic"
      )

      mod.retire_session_record("sess-1", reason="test")
      checks["after_retire"] = mod.load_session_record("sess-1")
      print(json.dumps(checks))
    PY

    checks = JSON.parse(out)
    assert_equal "pid-abc", checks["loaded_pid"]
    assert_equal 2, checks["schema_version"]
    assert_equal 50, checks["cumulative_input_tokens"]
    assert_equal "SOUL FIRST\n".bytesize, checks.dig("soul_fingerprint", "bytes")
    assert_match(/\A[0-9a-f]{64}\z/, checks.dig("soul_fingerprint", "sha256"))
    assert_nil checks["same_model"]
    assert_equal "model-changed", checks["other_model"]
    assert_equal "provider-changed", checks["other_provider"]
    assert_nil checks["same_content_touch"]
    assert_equal "identity-changed", checks["identity_changed"]
    assert_equal [ "soul.md" ], checks["changed_files"]
    assert_nil checks["after_retire"]
  end

  test "sidecar schema and trigger sequence upgrades are forward compatible" do
    out = run_shim_python(<<~PY)
      current_fingerprint = mod.identity_fingerprint()
      version_one = {
        "schema_version": 1,
        "provider": "anthropic",
        "model": "claude-opus-4-7",
        "identity_fingerprint": current_fingerprint,
      }
      future = {**version_one, "schema_version": 99}
      malformed = {**version_one, "schema_version": "future"}
      print(json.dumps({
        "version_one_roll": mod.roll_reason(version_one, "claude-opus-4-7", "anthropic"),
        "future_roll": mod.roll_reason(future, "claude-opus-4-7", "anthropic"),
        "malformed_roll": mod.roll_reason(malformed, "claude-opus-4-7", "anthropic"),
        "missing_sequence": mod.next_trigger_sequence(version_one),
        "malformed_sequence": mod.next_trigger_sequence({"trigger_sequence": "unknown"}),
        "existing_sequence": mod.next_trigger_sequence({"trigger_sequence": 7}),
      }))
    PY

    result = JSON.parse(out)
    assert_nil result["version_one_roll"]
    assert_equal "sidecar-schema-unsupported", result["future_roll"]
    assert_equal "sidecar-schema-unsupported", result["malformed_roll"]
    assert_equal 1, result["missing_sequence"]
    assert_equal 1, result["malformed_sequence"]
    assert_equal 8, result["existing_sequence"]
  end

  test "usage_since handles cumulative counter resets" do
    out = run_shim_python(<<~PY)
      record = {
        "cumulative_input_tokens": 500,
        "cumulative_cached_input_tokens": 200,
        "cumulative_output_tokens": 50,
      }
      events = {"input_tokens": 80, "cached_input_tokens": 30, "output_tokens": 9}
      print(json.dumps(mod.usage_since(record, events)))
    PY

    assert_equal(
      { "input_tokens" => 80, "cached_input_tokens" => 30, "output_tokens" => 9 },
      JSON.parse(out)
    )
  end

  test "run_chaos uses the current headless execution flag" do
    out = run_shim_python(<<~PY)
      captured = {}
      def fake_run(args, **kwargs):
          captured["args"] = args
          return mod.subprocess.CompletedProcess(args, 0, "", "")
      mod.subprocess.run = fake_run
      mod.run_chaos("gpt-5.2", 30, "REQUEST", True, provider="openai")
      print(json.dumps(captured))
    PY

    args = JSON.parse(out).fetch("args")
    assert_includes args, "--headless"
    assert_equal "openai", args[args.index("--provider") + 1]
    assert_equal "gpt-5.2", args[args.index("-m") + 1]
    assert_not_includes args, "--dangerously-bypass-approvals-and-sandbox"
  end

  test "non-persistent triggers use JSON output and record a legacy fresh lifecycle" do
    out = run_shim_python(<<~PY, fake_chaos: :echo_resumed_pid)
      captured = {}
      original_run_chaos = mod.run_chaos
      def capture_run(model, timeout_secs, prompt_text, json_output, resume_id=None, provider=None):
          captured["json_output"] = json_output
          return original_run_chaos(
              model, timeout_secs, prompt_text, json_output,
              resume_id=resume_id, provider=provider
          )
      mod.run_chaos = capture_run
      response, code = mod.legacy_trigger(
          "legacy-session", "REQUEST FULL", "claude-opus-4-7", 30
      )
      print(json.dumps({"response": response, "code": code, "captured": captured}))
    PY

    result = JSON.parse(out)
    response = result["response"]
    assert_equal 200, result["code"]
    assert_equal true, result.dig("captured", "json_output")
    assert_equal "legacy_fresh", response.dig("telemetry", "session", "outcome")
    assert_equal false, response.dig("telemetry", "session", "persistent_requested")
    assert_equal false, response.dig("telemetry", "session", "mapping_found")
    assert_equal "full", response.dig("telemetry", "prompt", "mode")
    assert_equal 120, response.dig("telemetry", "usage", "input_tokens")
    assert response["chaos_session_id"].present?
  end

  test "first persistent trigger goes fresh, second resumes the mapped session" do
    out = run_shim_python(<<~PY, fake_chaos: :echo_resumed_pid)
      first, code1 = mod.persistent_trigger("sess-2", "REQUEST FULL", None, "claude-opus-4-7", 30)
      second, code2 = mod.persistent_trigger("sess-2", "REQUEST FULL 2", "DELTA ONLY", "claude-opus-4-7", 30)
      print(json.dumps({"first": first, "code1": code1, "second": second, "code2": code2}))
    PY

    result = JSON.parse(out)
    first, second = result["first"], result["second"]

    assert_equal 200, result["code1"]
    assert_equal false, first["session_resumed"]
    assert first["chaos_session_id"].present?
    assert_includes first["full_invocation_text"], "SOUL FIRST", "fresh turn must carry identity"
    assert_includes first["full_invocation_text"], "REQUEST FULL"
    assert_equal 1, first.dig("telemetry", "schema_version")
    assert_equal "fake-chaos 0.0.1", first.dig("telemetry", "runtime", "chaos_version")
    assert_equal "anthropic", first.dig("telemetry", "runtime", "provider")
    assert_equal "claude-opus-4-7", first.dig("telemetry", "runtime", "model")
    assert_equal "1h", first.dig("telemetry", "runtime", "cache_ttl")
    assert_equal "fresh", first.dig("telemetry", "session", "outcome")
    assert_equal "full", first.dig("telemetry", "prompt", "mode")
    assert_operator first.dig("telemetry", "prompt", "full_prompt_bytes"), :>, 0
    assert_equal 120, first.dig("telemetry", "usage", "input_tokens")
    assert_equal 30, first.dig("telemetry", "usage", "cache_read_input_tokens")
    assert_equal 1, first.dig("telemetry", "usage", "provider_request_count")
    assert_equal "process_cumulative", first.dig("telemetry", "session_usage", "scope")

    assert_equal 200, result["code2"]
    assert_equal true, second["session_resumed"], "second trigger should resume"
    assert_equal first["chaos_session_id"], second["chaos_session_id"]
    assert_equal "DELTA ONLY", second["full_invocation_text"], "resumed turn sends the delta, unwrapped"
    assert_equal first["usage"], second["usage"], "Chaos reports each invocation directly"
    assert_equal "resumed", second.dig("telemetry", "session", "outcome")
    assert_equal true, second.dig("telemetry", "session", "mapping_found")
    assert_equal true, second.dig("telemetry", "session", "resume_attempted")
    assert_equal 2, second.dig("telemetry", "session", "trigger_sequence")
    assert_equal "delta", second.dig("telemetry", "prompt", "mode")
    assert_equal "DELTA ONLY".bytesize, second.dig("telemetry", "prompt", "selected_prompt_bytes")
    assert_nil second.dig("telemetry", "prompt", "full_prompt_bytes")
    assert_equal({}, second.dig("telemetry", "prompt", "components"))
  end

  test "successful resume does not rebuild the full prompt or reread journals" do
    out = run_shim_python(<<~PY, fake_chaos: :echo_resumed_pid)
      first, _ = mod.persistent_trigger("sess-no-reread", "REQUEST ONE", None, "claude-opus-4-7", 30)

      def fail_if_journals_are_read():
          raise AssertionError("successful resume rebuilt memory context")
      mod.memory_context = fail_if_journals_are_read

      second, code = mod.persistent_trigger(
          "sess-no-reread", "REQUEST TWO", "DELTA ONLY", "claude-opus-4-7", 30
      )
      print(json.dumps({"first": first, "second": second, "code": code}))
    PY

    result = JSON.parse(out)
    assert_equal 200, result["code"]
    assert_equal true, result.dig("second", "session_resumed")
    assert_equal "DELTA ONLY", result.dig("second", "full_invocation_text")
    assert_nil result.dig("second", "telemetry", "prompt", "full_prompt_bytes")
  end

  test "stale resume falls back to one fresh full-identity retry" do
    out = run_shim_python(<<~PY, fake_chaos: :always_fresh_pid)
      first, _ = mod.persistent_trigger("sess-3", "REQUEST ONE", None, "claude-opus-4-7", 30)
      # Fake chaos mints a NEW pid on resume too, so the shim must detect the
      # stale marker and retry fresh with full identity.
      second, code2 = mod.persistent_trigger("sess-3", "REQUEST TWO", "DELTA ONLY", "claude-opus-4-7", 30)
      print(json.dumps({"first": first, "second": second, "code2": code2}))
    PY

    result = JSON.parse(out)
    second = result["second"]

    assert_equal 200, result["code2"]
    assert_equal false, second["session_resumed"]
    assert_equal true, second["fresh_fallback"]
    assert_equal "resume-failed", second["session_roll_reason"]
    assert_equal "fresh_fallback", second.dig("telemetry", "session", "outcome")
    assert_equal "trigger", second.dig("telemetry", "usage", "scope")
    assert_equal 240, second.dig("telemetry", "usage", "input_tokens")
    assert_equal 2, second.dig("telemetry", "usage", "provider_request_count")
    assert_includes second["full_invocation_text"], "SOUL FIRST", "fallback must re-inject identity"
    assert_includes second["full_invocation_text"], "REQUEST TWO"
    assert_not_includes second["full_invocation_text"], "DELTA ONLY", "the fallback retry must use the full prompt"
  end

  test "resume timeout retires the ambiguous session mapping" do
    out = run_shim_python(<<~PY)
      events = mod.parse_events('{"type":"process.started","process_id":"pid-timeout"}\\n' +
        '{"type":"turn.completed","usage":{"input_tokens":50,"cached_input_tokens":0,"output_tokens":5}}')
      mod.save_session_record("sess-timeout", "claude-opus-4-7", events)

      def time_out(*args, **kwargs):
          raise mod.subprocess.TimeoutExpired(cmd="chaos", timeout=30)
      mod.run_chaos = time_out

      response, code = mod.persistent_trigger(
          "sess-timeout", "REQUEST FULL", "DELTA ONLY", "claude-opus-4-7", 30
      )
      print(json.dumps({
          "response": response,
          "code": code,
          "record": mod.load_session_record("sess-timeout"),
      }))
    PY

    result = JSON.parse(out)
    assert_equal 504, result["code"]
    assert_equal "timeout", result.dig("response", "status")
    assert_equal "resume_timeout", result.dig("response", "telemetry", "session", "outcome")
    assert_equal "incomplete", result.dig("response", "telemetry", "chaos_telemetry_status")
    assert_nil result["record"]
  end

  test "timeout salvages partial versioned usage and marks it incomplete" do
    out = run_shim_python(<<~PY)
      initial = mod.parse_events(
        '{"type":"process.started","process_id":"pid-partial"}\\n' +
        '{"type":"turn.completed","usage":{"input_tokens":50,"cached_input_tokens":0,"output_tokens":5}}'
      )
      mod.save_session_record("sess-partial", "claude-opus-4-7", initial)
      partial = "\\n".join([
        '{"type":"process.started","process_id":"pid-partial"}',
        '{"type":"invocation.completed","telemetry_schema_version":1,"usage":' +
          '{"scope":"invocation","input_tokens":90,"uncached_input_tokens":10,' +
          '"cache_creation_input_tokens":20,"cache_read_input_tokens":60,' +
          '"output_tokens":8,"provider_request_count":2}}',
      ])

      def time_out(*args, **kwargs):
          raise mod.subprocess.TimeoutExpired(
              cmd="chaos", timeout=30, output=partial, stderr="partial stderr"
          )
      mod.run_chaos = time_out

      response, code = mod.persistent_trigger(
          "sess-partial", "REQUEST FULL", "DELTA ONLY", "claude-opus-4-7", 30
      )
      print(json.dumps({
          "response": response,
          "code": code,
          "record": mod.load_session_record("sess-partial"),
      }))
    PY

    result = JSON.parse(out)
    response = result["response"]
    assert_equal 504, result["code"]
    assert_equal false, response["session_resumed"]
    assert_equal 90, response.dig("telemetry", "usage", "input_tokens")
    assert_equal 20, response.dig("telemetry", "usage", "cache_creation_input_tokens")
    assert_equal false, response.dig("telemetry", "usage", "complete")
    assert_equal false, response.dig("usage", "complete")
    assert_equal "partial stderr", response["stderr"]
    assert_equal "incomplete", response.dig("telemetry", "chaos_telemetry_status")
    assert_nil result["record"]
  end

  test "model change rolls the session instead of resuming" do
    out = run_shim_python(<<~PY, fake_chaos: :echo_resumed_pid)
      first, _ = mod.persistent_trigger("sess-4", "REQUEST ONE", None, "claude-opus-4-7", 30)
      second, _ = mod.persistent_trigger("sess-4", "REQUEST TWO", "DELTA ONLY", "claude-haiku-4-5", 30)
      print(json.dumps({"first": first, "second": second}))
    PY

    result = JSON.parse(out)
    second = result["second"]
    assert_equal false, second["session_resumed"]
    assert_equal "model-changed", second["session_roll_reason"]
    assert_equal "rolled", second.dig("telemetry", "session", "outcome")
    assert_equal true, second.dig("telemetry", "session", "mapping_found")
    assert_equal false, second.dig("telemetry", "session", "resume_attempted")
    assert_includes second["full_invocation_text"], "SOUL FIRST"
    assert_not_equal result.dig("first", "chaos_session_id"), second["chaos_session_id"]
  end

  private

  # Runs a Python snippet with trigger_shim.py loaded as `mod`, an isolated
  # identity dir + chaos home, jsonify stubbed to identity (no Flask needed),
  # and CHAOS_BIN pointing at a fake chaos script.
  def run_shim_python(snippet, fake_chaos: nil)
    Dir.mktmpdir do |dir|
      dir = Pathname.new(dir)
      identity = dir / "identity"
      (identity / "memory" / "daily-journals").mkpath
      (identity / "soul.md").write("SOUL FIRST\n")
      chaos_home = dir / "chaos-home"
      chaos_home.mkpath

      chaos_bin = dir / "fake-chaos"
      chaos_bin.write(fake_chaos_script(fake_chaos))
      chaos_bin.chmod(0o755)

      script = Rails.root.join("agent-runtime/trigger_shim.py")
      command = <<~PY
        import importlib.util, json
        spec = importlib.util.spec_from_file_location("trigger_shim", #{script.to_s.inspect})
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        mod.jsonify = lambda payload: payload
        #{snippet}
      PY
      env = {
        "TRIGGER_BEARER_TOKEN" => "tr_test",
        "AGENT_IDENTITY_PATH" => identity.to_s,
        "AGENT_REPO_PATH" => dir.to_s,
        "CHAOS_HOME" => chaos_home.to_s,
        "CHAOS_BIN" => chaos_bin.to_s,
        "CHAOS_ANTHROPIC_CACHE_TTL" => "1h"
      }
      stdout, stderr, status = Open3.capture3(env, "python3", "-c", command)
      assert status.success?, stderr
      stdout.lines.last.to_s
    end
  end

  # A fake `chaos` that consumes stdin and emits the JSONL events the shim
  # parses. :echo_resumed_pid honours `resume <pid>` (well-behaved chaos);
  # :always_fresh_pid mints a new pid every run (stale-marker scenario).
  def fake_chaos_script(mode)
    honour_resume = (mode != :always_fresh_pid)
    <<~PYTHON
      #!/usr/bin/env python3
      import json, sys, uuid

      args = sys.argv[1:]
      if args and args[0] == "--version":
          print("fake-chaos 0.0.1")
          sys.exit(0)
      sys.stdin.read()

      pid = None
      if #{honour_resume ? 'True' : 'False'} and "resume" in args:
          pid = args[args.index("resume") + 1]
      if pid is None:
          pid = f"pid-{uuid.uuid4()}"

      print(json.dumps({"type": "process.started", "process_id": pid}))
      print(json.dumps({"type": "item.completed", "item": {"id": "1", "type": "agent_message", "text": "fake reply"}}))
      print(json.dumps({
        "type": "turn.completed",
        "telemetry_schema_version": 1,
        "usage": {
          "scope": "invocation",
          "input_tokens": 120,
          "uncached_input_tokens": 80,
          "cache_creation_input_tokens": 10,
          "cache_read_input_tokens": 30,
          "output_tokens": 9,
          "provider_request_count": 1,
        },
        "session_usage": {
          "scope": "process_cumulative",
          "input_tokens": 120,
          "output_tokens": 9,
          "provider_request_count": 1,
        },
      }))
    PYTHON
  end

end

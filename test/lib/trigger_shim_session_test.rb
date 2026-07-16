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

  test "parse_events extracts process id, latest cumulative usage, and agent messages" do
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
    assert_equal [ "hello" ], parsed["agent_messages"]
  end

  test "session records round-trip and roll on model and identity changes" do
    out = run_shim_python(<<~PY)
      events = {"process_id": "pid-abc", "input_tokens": 50, "cached_input_tokens": 0, "output_tokens": 5}
      usage = mod.usage_since(None, events)
      mod.save_session_record("sess-1", "claude-opus-4-7", events, usage)
      record = mod.load_session_record("sess-1")
      checks = {
        "loaded_pid": record["chaos_process_id"],
        "cumulative_input_tokens": record["cumulative_input_tokens"],
        "same_model": mod.roll_reason(record, "claude-opus-4-7"),
        "other_model": mod.roll_reason(record, "claude-haiku-4-5"),
      }

      # Identity change: touch soul.md after record creation.
      import os, time
      soul = mod.AGENT_IDENTITY_PATH / "soul.md"
      os.utime(soul, ns=(soul.stat().st_atime_ns, soul.stat().st_mtime_ns + 1_000_000))
      checks["identity_changed"] = mod.roll_reason(record, "claude-opus-4-7")

      mod.retire_session_record("sess-1", reason="test")
      checks["after_retire"] = mod.load_session_record("sess-1")
      print(json.dumps(checks))
    PY

    checks = JSON.parse(out)
    assert_equal "pid-abc", checks["loaded_pid"]
    assert_equal 50, checks["cumulative_input_tokens"]
    assert_nil checks["same_model"]
    assert_equal "model-changed", checks["other_model"]
    assert_equal "identity-changed", checks["identity_changed"]
    assert_nil checks["after_retire"]
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
      mod.run_chaos("claude-opus-4-7", 30, "REQUEST", True)
      print(json.dumps(captured))
    PY

    args = JSON.parse(out).fetch("args")
    assert_includes args, "--headless"
    assert_not_includes args, "--dangerously-bypass-approvals-and-sandbox"
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

    assert_equal 200, result["code2"]
    assert_equal true, second["session_resumed"], "second trigger should resume"
    assert_equal first["chaos_session_id"], second["chaos_session_id"]
    assert_equal "DELTA ONLY", second["full_invocation_text"], "resumed turn sends the delta, unwrapped"
    assert_equal first["usage"], second["usage"], "cumulative Chaos counters must be converted to a per-trigger delta"
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
    assert_includes second["full_invocation_text"], "SOUL FIRST", "fallback must re-inject identity"
    assert_includes second["full_invocation_text"], "REQUEST TWO"
    assert_not_includes second["full_invocation_text"], "DELTA ONLY", "the fallback retry must use the full prompt"
  end

  test "resume timeout retires the ambiguous session mapping" do
    out = run_shim_python(<<~PY)
      events = {"process_id": "pid-timeout", "input_tokens": 50, "cached_input_tokens": 0, "output_tokens": 5}
      usage = mod.usage_since(None, events)
      mod.save_session_record("sess-timeout", "claude-opus-4-7", events, usage)

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
        "CHAOS_BIN" => chaos_bin.to_s
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

      resumed = "resume" in args and #{honour_resume ? 'True' : 'False'}
      multiplier = 2 if resumed else 1
      print(json.dumps({"type": "process.started", "process_id": pid}))
      print(json.dumps({"type": "item.completed", "item": {"id": "1", "type": "agent_message", "text": "fake reply"}}))
      print(json.dumps({"type": "turn.completed", "usage": {
          "input_tokens": 120 * multiplier,
          "cached_input_tokens": 30 * multiplier,
          "output_tokens": 9 * multiplier,
      }}))
    PYTHON
  end

end

#!/bin/sh
# entrypoint.sh — runs as root inside the container; fixes permissions on
# docker-managed volumes, then drops to the `agent` user (uid 1000) before
# exec'ing the shim.

set -e

AGENT_HOME=/home/agent
AGENT_REPO_PATH="${AGENT_REPO_PATH:-$AGENT_HOME/repo}"

# Docker-managed volumes are root-owned when first created. The agent user needs
# write access to both canonical identity/memory and chaos session state.
for path in "$AGENT_HOME/identity" "$AGENT_HOME/.chaos" "$AGENT_REPO_PATH"; do
    if [ -d "$path" ]; then
        chown -R 1000:1000 "$path" || true
    fi
done

# Install the default hosted-agent Stop hook and journaling scaffold. The hook
# blocks once after each Chaos turn, asking the agent to append a daily journal
# entry or explicitly answer "no shape". The hook script lives in identity so it
# is visible in the hosting filesystem browser. hooks.json is installed into the
# active repo's .chaos directory, where Chaos discovers project hooks.
mkdir -p "$AGENT_HOME/identity/automation" \
         "$AGENT_HOME/identity/memory/daily-journals" \
         "$AGENT_HOME/identity/memory/automation/state" \
         "$AGENT_HOME/.chaos" \
         "$AGENT_REPO_PATH/.chaos"
# Platform-managed helper: refresh on every boot so runtime improvements reach
# existing hosted agents. The journal files it invites are agent-owned; the hook
# script itself is runtime infrastructure.
cp /usr/local/share/helixkit-agent/stop_journal_reflex.py "$AGENT_HOME/identity/automation/stop_journal_reflex.py" || true
chmod 0755 "$AGENT_HOME/identity/automation/stop_journal_reflex.py" || true
write_hooks_json() {
    target="$1"
    cat > "$target" <<'HOOKS'
{
  "_helixkit_managed": "hosted-agent-stop-journal-reflex:v1",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 /home/agent/identity/automation/stop_journal_reflex.py",
            "timeout": 60,
            "statusMessage": "Inviting hosted agent journal reflex"
          }
        ]
      }
    ]
  }
}
HOOKS
}
install_hooks_json() {
    target="$1"
    if [ ! -f "$target" ]; then
        write_hooks_json "$target"
    elif grep -q "hosted-agent-stop-journal-reflex:" "$target"; then
        write_hooks_json "$target"
    elif grep -q "/home/agent/identity/automation/stop_journal_reflex.py" "$target"; then
        # Older generated hooks had no marker. Refresh the known generated shape.
        write_hooks_json "$target"
    fi
}
# Chaos reads hooks from both global and project config. Install the Stop hook
# only into the active project (`-C`) so it fires once per turn. If an earlier
# HelixKit image wrote the same managed hook into ~/.chaos/hooks.json, remove it.
install_hooks_json "$AGENT_REPO_PATH/.chaos/hooks.json"
if [ -f "$AGENT_HOME/.chaos/hooks.json" ] && grep -q "hosted-agent-stop-journal-reflex:" "$AGENT_HOME/.chaos/hooks.json"; then
    rm -f "$AGENT_HOME/.chaos/hooks.json"
fi
cat > "$AGENT_HOME/.chaos/helixkit-hooks.md" <<'HOOKS_NOTE'
# HelixKit hosted-agent hooks

The active hosted-agent Stop hook is installed at:

`/home/agent/repo/.chaos/hooks.json`

Chaos may read both global (`~/.chaos`) and project (`-C .../.chaos`) hooks, so
HelixKit does not install a second copy here. Keeping only one active hook avoids
duplicate journal-reflex invitations after a turn.
HOOKS_NOTE
RUNTIME_INSTRUCTIONS="$AGENT_HOME/identity/runtime-instructions.md"
RUNTIME_INSTRUCTIONS_NEW="$AGENT_HOME/identity/runtime-instructions.md.new"
write_runtime_instructions() {
    target="$1"
    cat > "$target" <<'RUNTIME'
<!-- helixkit-managed-runtime-instructions:v2 -->

# Hosted runtime instructions

You are running as a hosted HelixKit agent inside an external Chaos runtime.
These instructions describe the runtime context around your identity; they do
not replace `soul.md`.

## Identity and prompt order

On each trigger, the runtime places `soul.md` first in your prompt context.
Treat `soul.md` as your defining text. After that, use this file,
`self-narrative.md`, `bootstrap.md`, and the memory files for operational
context.

## HelixKit access

Use `helixkit-api.md` for the REST API manual. Conversation transcripts remain
in HelixKit; read them through the API when you're considering a conversation,
e.g. after a trigger arrives. `HELIXKIT_APP_URL` and `HELIXKIT_BEARER_TOKEN`
are present in your shell environment.

## Legacy memories

HelixKit memory records exported at promotion live under `memory/` as dated
Markdown files named like `YYYY-MM-DD-journal-123.md` or
`YYYY-MM-DD-core-123.md`. `self-narrative.md` may also include a short memory
outline. Treat those files as legacy memory source material; preserve them
unless Daniel explicitly asks you to edit or consolidate them.

## Diarized memory

A Chaos Stop hook may invite you after each turn to append a daily journal entry
under `memory/daily-journals/`, or to answer `no shape` when nothing should be
kept. These journals are raw diarized memory and future summary source
material. When writing a journal, preserve existing entries and append a new
`## HH:MM — ...` section; never overwrite or truncate an existing daily journal
file. You can use `helixkit-append-journal "Title"` and pipe the entry body into
it to append safely.

## Repository stewardship

If you improve your own repository or identity files, prefer small, reviewable
commits. Commit with a clear message explaining what you changed and why so
Daniel can review the GitHub history.
RUNTIME
}
if [ ! -f "$RUNTIME_INSTRUCTIONS" ]; then
    write_runtime_instructions "$RUNTIME_INSTRUCTIONS"
elif grep -q "helixkit-managed-runtime-instructions:" "$RUNTIME_INSTRUCTIONS"; then
    write_runtime_instructions "$RUNTIME_INSTRUCTIONS"
elif grep -q "^# Hosted runtime instructions$" "$RUNTIME_INSTRUCTIONS" && grep -q "hosted HelixKit agent inside an external Chaos runtime" "$RUNTIME_INSTRUCTIONS"; then
    # Older generated runtime-instructions had no version marker. Treat the
    # known generated shape as platform-managed and refresh it.
    write_runtime_instructions "$RUNTIME_INSTRUCTIONS"
else
    # The agent appears to have edited/replaced this file. Preserve it and leave
    # the updated platform copy nearby for manual review.
    write_runtime_instructions "$RUNTIME_INSTRUCTIONS_NEW"
fi
if [ ! -f "$AGENT_HOME/identity/memory/daily-journals/README.md" ]; then
    cat > "$AGENT_HOME/identity/memory/daily-journals/README.md" <<'README'
# Daily journals

This folder holds diarized memory for the hosted agent. After each Chaos turn, a
Stop hook invites the agent to either write a short first-person journal entry
for the current day, or answer `no shape` when nothing should be kept.

Daily files are named `YYYY-MM-DD.md`. Each entry uses:

```markdown
## HH:MM — <title naming the shape, not the topic>
```

These journals are source material for future daily, weekly, and monthly memory
summaries. Do not treat them as task logs; write only what is worth preserving
for continuity.

When adding an entry to an existing daily file, append a new section. Do not
overwrite or truncate existing entries; with shell redirection, use >> rather
than > for an existing journal.
README
fi
chown -R 1000:1000 "$AGENT_REPO_PATH" "$AGENT_HOME/identity/automation" "$AGENT_HOME/identity/memory" "$RUNTIME_INSTRUCTIONS" "$RUNTIME_INSTRUCTIONS_NEW" "$AGENT_HOME/.chaos/helixkit-hooks.md" 2>/dev/null || true

# Some chaos providers read API keys directly from the environment (Anthropic),
# while others require a provider account entry under the agent user's ~/.chaos.
# Seed those account entries opportunistically from host-supplied env vars on
# every boot. This writes into the persisted chaos-home volume and is idempotent;
# never echo the key.
register_provider_key() {
    provider="$1"
    key="$2"
    if [ -n "$key" ]; then
        printf '%s' "$key" | gosu agent chaos accounts --provider "$provider" --with-api-key >/dev/null 2>&1 || true
    fi
}

register_provider_key anthropic "$ANTHROPIC_API_KEY"
register_provider_key openai "$OPENAI_API_KEY"

# Optional local guardrail if the identity volume is itself a git working tree.
# The hosted path does not require git, but agents may initialize it for local
# history. Protect soul.md from accidental commits unless explicitly allowed.
if [ -d "$AGENT_HOME/identity/.git/hooks" ]; then
    cat > "$AGENT_HOME/identity/.git/hooks/pre-commit" <<'HOOK'
#!/bin/sh
set -e

if [ "${ALLOW_PROTECTED_IDENTITY_CHANGE:-}" = "1" ]; then
    exit 0
fi

protected='soul.md'
if git diff --cached --name-only -- "$protected" | grep -qx "$protected"; then
    cat >&2 <<'MSG'
Refusing to commit soul.md.

That file is the agent's defining system prompt and is protected. If Daniel has
explicitly reviewed and approved this change, rerun the commit with:

  ALLOW_PROTECTED_IDENTITY_CHANGE=1 git commit ...
MSG
    exit 1
fi
HOOK
    chmod 0755 "$AGENT_HOME/identity/.git/hooks/pre-commit" || true
    chown 1000:1000 "$AGENT_HOME/identity/.git/hooks/pre-commit" || true
fi

exec gosu agent "$@"

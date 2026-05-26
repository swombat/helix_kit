#!/bin/sh
# entrypoint.sh — runs as root inside the container; fixes permissions on
# docker-managed volumes, then drops to the `agent` user (uid 1000) before
# exec'ing the shim.

set -e

AGENT_HOME=/home/agent

# Docker-managed volumes are root-owned when first created. The agent user needs
# write access to both canonical identity/memory and chaos session state.
for path in "$AGENT_HOME/identity" "$AGENT_HOME/.chaos"; do
    if [ -d "$path" ]; then
        chown -R 1000:1000 "$path" || true
    fi
done

# Install the default hosted-agent Stop hook and journaling scaffold. The hook
# blocks once after each Chaos turn, asking the agent to append a daily journal
# entry or explicitly answer "no shape". The hook script lives in identity so it
# is visible in the hosting filesystem browser; hooks.json lives in the
# persisted Chaos home because that is where Chaos discovers runtime hooks for
# this container.
mkdir -p "$AGENT_HOME/identity/automation" \
         "$AGENT_HOME/identity/memory/daily-journals" \
         "$AGENT_HOME/identity/memory/automation/state" \
         "$AGENT_HOME/.chaos"
if [ ! -f "$AGENT_HOME/identity/automation/stop_journal_reflex.py" ]; then
    cp /usr/local/share/helixkit-agent/stop_journal_reflex.py "$AGENT_HOME/identity/automation/stop_journal_reflex.py" || true
fi
chmod 0755 "$AGENT_HOME/identity/automation/stop_journal_reflex.py" || true
if [ ! -f "$AGENT_HOME/.chaos/hooks.json" ]; then
    cat > "$AGENT_HOME/.chaos/hooks.json" <<'HOOKS'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 /home/agent/identity/automation/stop_journal_reflex.py",
            "timeout": 5,
            "statusMessage": "Inviting hosted agent journal reflex"
          }
        ]
      }
    ]
  }
}
HOOKS
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
README
fi
chown -R 1000:1000 "$AGENT_HOME/identity/automation" "$AGENT_HOME/identity/memory" "$AGENT_HOME/.chaos/hooks.json" || true

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

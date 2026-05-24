# HelixKit Agent Runtime

This directory contains the Docker image source for HelixKit-hosted sandbox agents.

It replaces the old primary role of the separate `helix-kit-agents` repository. That repository is intentionally left intact as a historical/self-host fallback, but HelixKit-managed agents should build and run this in-repo runtime.

## Local build

```bash
docker build -t helixkit-agent-runtime:local agent-runtime
```

Local Rails development defaults should point at that tag:

```bash
HELIXKIT_AGENT_IMAGE_DEFAULT=helixkit-agent-runtime:local
HELIXKIT_AGENT_INTERNAL_URL=http://host.docker.internal:3000
HELIXKIT_SANDBOX_HOST=local-docker-desktop
HELIXKIT_AGENT_PUBLISH_PORTS=1
HELIXKIT_AGENT_BACKUPS_ENABLED=false
```

## Runtime contract

HelixKit starts one container per hosted agent. The container listens on port `4000` and exposes:

- `GET /health` — unauthenticated liveness check
- `POST /trigger` — bearer-authenticated trigger endpoint

HelixKit mounts two Docker volumes:

- `/home/agent/identity` — canonical identity and memory, backed up by HelixKit/restic
- `/home/agent/.chaos` — chaos CLI session/config state, preserved across restarts but not backed up in v1

HelixKit passes these env vars:

- `AGENT_ID` — stable UUID identity
- `AGENT_SLUG` — human-readable logging label
- `AGENT_PROVIDER`
- `AGENT_DEFAULT_MODEL`
- `TRIGGER_BEARER_TOKEN`
- `HELIXKIT_BEARER_TOKEN`
- `HELIXKIT_APP_URL`
- provider keys such as `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`

The shim uses `AGENT_SLUG || AGENT_ID` for log labels, but reports `AGENT_ID` in `/health`.

## Production image tags

Production should use immutable tags, for example:

```bash
docker build -t registry.example.com/helixkit-agent-runtime:<git-sha> agent-runtime
```

Then set:

```bash
HELIXKIT_AGENT_IMAGE_DEFAULT=registry.example.com/helixkit-agent-runtime:<git-sha>
```

Each promoted agent stores the exact image tag in `agents.container_image`, so upgrades are explicit.

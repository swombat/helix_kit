# HelixKit agent runtime image.
#
# This image is built from the HelixKit monorepo and run by HelixKit's hosted
# sandbox promotion flow. It contains chaos plus trigger_shim.py; per-agent
# identity and state arrive through Docker volumes and environment variables.
#
# Local build:
#   docker build -t helixkit-agent-runtime:local agent-runtime

# =============================================================================
# Stage 1 — pull and build chaos. Source tree is discarded after the binary copies.
# =============================================================================
FROM rust:1.97-bookworm AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        protobuf-compiler \
        clang \
        pkg-config \
        libdbus-1-dev \
        ca-certificates \
        git \
    && rm -rf /var/lib/apt/lists/*

# Pin merged subscription-auth, clamp telemetry, and headless clamp support so
# hosted runtime rebuilds do not depend on movement of a branch ref.
# Pin bumps must re-verify both provider auth ceremony parsers and the Claude
# clamp-worker process pattern in trigger_shim.py.
ARG CHAOS_REPO=https://github.com/seuros/chaos.git
ARG CHAOS_REF=c33317f9c0e67b518d3024cfddf1d524e2920ef1

WORKDIR /build
RUN git clone --filter=blob:none ${CHAOS_REPO} chaos \
    && cd chaos \
    && git checkout ${CHAOS_REF}

WORKDIR /build/chaos
RUN cargo build --release --bin chaos \
    && cp target/release/chaos /usr/local/bin/chaos \
    && /usr/local/bin/chaos --version
RUN cargo build --release --bin chaos_journald \
    && cp target/release/chaos_journald /usr/local/bin/chaos_journald

# =============================================================================
# Stage 2 — runtime
# =============================================================================
FROM node:22-bookworm-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        python3 \
        python3-flask \
        git \
        curl \
        tini \
        gosu \
        procps \
        libdbus-1-3 \
    && rm -rf /var/lib/apt/lists/*

# The official Node image already reserves UID/GID 1000 for `node`. Hosted
# volume ownership depends on 1000, so rename that account rather than creating
# a second user with a different identity.
RUN groupmod --new-name agent node \
    && usermod --login agent --home /home/agent --move-home --shell /bin/bash node

# Clamp speaks Claude Code's documented stream-json protocol. Keep this pin
# beside CHAOS_REF: the Anthropic login ceremony parser is tested against it.
ARG CLAUDE_CODE_VERSION=2.1.220
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && claude --version

COPY --from=builder /usr/local/bin/chaos /usr/local/bin/chaos
COPY --from=builder /usr/local/bin/chaos_journald /usr/local/bin/chaos_journald
RUN mkdir -p /usr/local/share/helixkit-agent
COPY --chown=agent:agent trigger_shim.py /home/agent/trigger_shim.py
COPY docs/runtime-instructions.md /usr/local/share/helixkit-agent/runtime-instructions.md
COPY docs/helixkit-api.md /usr/local/share/helixkit-agent/helixkit-api.md
COPY stop_journal_reflex.py /usr/local/share/helixkit-agent/stop_journal_reflex.py
COPY helixkit-post-message /usr/local/bin/helixkit-post-message
COPY helixkit-send-telegram /usr/local/bin/helixkit-send-telegram
COPY helixkit-append-journal /usr/local/bin/helixkit-append-journal
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/helixkit-post-message /usr/local/bin/helixkit-send-telegram /usr/local/bin/helixkit-append-journal \
    && chmod 0644 /usr/local/share/helixkit-agent/*.md /usr/local/share/helixkit-agent/stop_journal_reflex.py

# Canonical mounted volumes for hosted agents. /home/agent/state is deliberately
# outside every HelixKit-facing filesystem root and holds vendor credentials.
VOLUME ["/home/agent/identity", "/home/agent/.chaos", "/home/agent/repo", "/home/agent/work", "/home/agent/state"]

WORKDIR /home/agent
ENV SHIM_PORT=4000
# Anthropic prompt-cache TTL for chaos (PR seuros/chaos#13). Hosted agents are
# triggered on ~hourly wake cadence and bursty conversations; the 1-hour TTL
# keeps the cache chained across wakes (5m dies in the inter-wake gap and its
# writes become pure loss).
ENV CHAOS_ANTHROPIC_CACHE_TTL=1h
EXPOSE 4000

ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["python3", "/home/agent/trigger_shim.py"]

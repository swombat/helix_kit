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
FROM rust:1.95-bookworm AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        protobuf-compiler \
        clang \
        pkg-config \
        libdbus-1-dev \
        ca-certificates \
        git \
    && rm -rf /var/lib/apt/lists/*

# Pin to a specific chaos commit SHA for reproducibility.
ARG CHAOS_REPO=https://github.com/seuros/chaos.git
ARG CHAOS_REF=d3bb3e9418cef11c64b83326f8bb9559daf9ec2b

WORKDIR /build
RUN git clone --filter=blob:none ${CHAOS_REPO} chaos \
    && cd chaos \
    && git checkout ${CHAOS_REF}

WORKDIR /build/chaos
RUN cargo build --release --bin chaos \
    && cp target/release/chaos /usr/local/bin/chaos \
    && /usr/local/bin/chaos --version

# =============================================================================
# Stage 2 — runtime
# =============================================================================
FROM debian:bookworm-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        python3 \
        python3-flask \
        git \
        curl \
        tini \
        gosu \
        libdbus-1-3 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash --uid 1000 agent

COPY --from=builder /usr/local/bin/chaos /usr/local/bin/chaos
RUN mkdir -p /usr/local/share/helixkit-agent
COPY --chown=agent:agent trigger_shim.py /home/agent/trigger_shim.py
COPY stop_journal_reflex.py /usr/local/share/helixkit-agent/stop_journal_reflex.py
COPY helixkit-post-message /usr/local/bin/helixkit-post-message
COPY helixkit-send-telegram /usr/local/bin/helixkit-send-telegram
COPY helixkit-append-journal /usr/local/bin/helixkit-append-journal
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/helixkit-post-message /usr/local/bin/helixkit-send-telegram /usr/local/bin/helixkit-append-journal \
    && chmod 0644 /usr/local/share/helixkit-agent/stop_journal_reflex.py

# Canonical mounted volumes for hosted agents.
VOLUME ["/home/agent/identity", "/home/agent/.chaos", "/home/agent/repo"]

WORKDIR /home/agent
ENV SHIM_PORT=4000
EXPOSE 4000

ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["python3", "/home/agent/trigger_shim.py"]

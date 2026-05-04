# Plan: Agent Promotion UX — promoting a HelixKit agent to an externally-hosted runtime

**Date:** 2026-05-04
**Branch:** `agent-promotion-ux` (new)
**Estimated scope:** Multi-day. ~6–10 files in `helix_kit`; the wizard UI.
**Depends on:** `2026-05-03-action-mcp.md` (ActionMCP server + `PostMessageTool` already implemented in `helix_kit`).

---

## 0. Implementation status (read this first)

This spec covers two halves: (1) the HelixKit Rails side (codex's job) and (2) the `helix-kit-agents` Docker runtime template (Lume's job, **already done**).

**Already implemented and live (helix-kit-agents side):**

- **Public repo:** [`github.com/swombat/helix-kit-agents`](https://github.com/swombat/helix-kit-agents) — Apache-2.0, two commits as of 2026-05-04.
- **Dockerfile:** multi-stage; builds chaos from `seuros/chaos@d3bb3e9418cef11c64b83326f8bb9559daf9ec2b` (master tip — chaos has no published binary releases or workspace-tags as of 2026-05-04, so we pin to a SHA on master). Final image is debian:bookworm-slim with chaos + Python + Flask + cryptography + tini + gosu, ~376MB.
- **`trigger_shim.py`:** Flask service on port 4000. `GET /health` (no auth), `POST /trigger` (bearer auth → subprocess `chaos exec`).
- **`entrypoint.sh`:** runs as root, chowns the chaos-home docker volume to uid 1000, drops privs via gosu before exec'ing the shim. Solves the chaos-can't-write-its-DB issue.
- **`bin/deploy`:** rsync + ssh + docker compose + health poll + chaos mcp config + announce. Supports `--local` (local docker daemon) and `--host HOSTNAME` (remote ssh).
- **`bin/generate-env`:** AES-256-GCM decryption of `credentials.yml.enc` using `master.key`; composes `.env` for docker compose.
- **`bin/announce` / `bin/undeploy` / `bin/update`:** lifecycle scripts.
- **Docs:** `README.md`, `docs/deploy.md`, `docs/secrets.md`, `docs/identity-bootstrap.md`.

**Smoke-tested green end-to-end (2026-05-04):**

- Local Docker (`bin/deploy --local`): build, encrypt/decrypt round-trip, container up, /health 200, /trigger no-auth 401, /trigger with bearer → chaos calls Anthropic → returns "PONG\n", 8,962 tokens.
- Remote (`bin/deploy --host misc` against misc.granttree.co.uk = 95.217.118.47:12222 swombat user): same end-to-end, plus rsync, remote `bin/generate-env` execution, remote `docker compose up -d`, idempotent `chaos mcp add`, clean `bin/undeploy`.

**NOT yet exercisable (depends on codex's HelixKit work):**

- The `/api/v1/agents/<uuid>/announce` POST — requires the route to exist in HelixKit
- The full promotion wizard flow
- A real promotion of an existing inline HelixKit agent

**Format contracts codex MUST match:**

The Python decryption code in `bin/generate-env` is already running and tested. Codex's Ruby `AgentCredentialsEncryptor` (§6d.bis) MUST produce output that this Python decrypter accepts. The format spec is in §4d. A reference implementation in Ruby producing decryptable output is in `~/dev/helix-kit-agents/test_credentials_roundtrip.rb` (also reproduced as the §6d.bis sample code below).

The plaintext credentials YAML structure (the inside of `credentials.yml.enc` after decryption) MUST have the exact keys: `agent_id`, `agent_uuid`, `helix_kit.mcp_url`, `helix_kit.bearer_token`, `trigger.bearer_token`. Anything else is ignored. Missing required keys causes `bin/generate-env` to fail loudly.

The announce endpoint POST body MUST be `{"endpoint_url": "..."}`, with `Authorization: Bearer <tr_token>`, returning `{"status": "ok", "endpoint_url": "..."}` on success. The deploy script depends on this contract.

**Discoveries from the helix-kit-agents smoke test that affect this spec (already incorporated):**

1. chaos's `mcp add` CLI uses `--url` only (no `--transport` flag at the pinned SHA). The `bin/deploy` script handles this.
2. Users without passwordless sudo on the deploy host can use user-owned paths via optional `host_repo_path` / `master_key_path` / `host_env_path` keys in `deploy.yml`. The wizard's "save the master key on your host" step (§5 Step 4) should mention this option for users who need it.
3. The chaos system prompt is ~9k tokens per call — relevant for cost estimation in HelixKit's pricing model.
4. `chaos mcp add` is idempotent (refuses to add a duplicate, which is what we want). The deploy script tolerates this with `|| true`.

---

## 1. Goal

HelixKit hosts AI agents. By default each agent's LLM calls happen inside HelixKit's puma process (the `inline` runtime). This plan adds a second runtime (`external`) and the UX to move an agent from one to the other.

When an agent is `external`, its LLM-calling work runs in a separate Docker container — somewhere on the internet that has Docker + SSH access — running [seuros/chaos](https://github.com/seuros/chaos) as its harness. HelixKit only routes triggers to that container's HTTP endpoint via MCP. The agent's *identity* (soul.md, journals, memory) lives in the agent's *own* git repo, not in HelixKit's.

**Promotion is a transfer, not an authoring event.** The agent already exists in HelixKit when promotion begins. Its current system prompt, conversation history, and any structured memory are exported and become the initial contents of the agent's new repo. The user is never asked to author identity from a blank file — they receive their agent, in file form, ready to commit.

The deliverables:

1. A new public template repo, **`helix-kit-agents`**, that *uses* chaos as a runtime dependency (it is not a chaos fork). Contains the Dockerfile, trigger shim, and deploy scripts. Users clone it, drop in their agent's identity bundle, customize the deploy config, deploy.
2. A wizard UI in HelixKit that walks an agent's owner through the promotion: clone the template, drop in the identity bundle generated by HelixKit, drop in encrypted credentials generated by HelixKit, deploy.
3. Backend support in HelixKit for the `external` runtime state and the announce + health-check + routing it requires.

---

## 2. Design principles

These shape several decisions below; flagging them upfront.

- **The agent's body lives in the agent's repo.** Identity files (soul.md, self-narrative.md, journals, memory) are owned by the agent, version-controlled in *the agent's* git history, not HelixKit's. HelixKit holds conversation state and registration metadata; it does not hold the agent's defining text.
- **`helix-kit-agents` *uses* chaos, it is not chaos.** The repo is markdown + folders + rules + Dockerfile + scripts. chaos is a runtime dependency pulled at image-build time. The repo carries no chaos source.
- **HelixKit is substrate-agnostic.** The contract between HelixKit and an external agent is "speak MCP outbound, accept HTTP triggers inbound." The agent's internal harness is its own concern. The first implementation uses chaos; the design does not preclude others.
- **Secure by default.** The bearer tokens generated during promotion are encrypted with a master key (analogous to a Rails master key) before they cross the wire to the user's repo. Plaintext credentials never sit on disk in the user's clone, never sit in a git commit, and never traverse pastes through a browser tab. The user receives one master key (shown once) plus an encrypted credentials file (committable to a private repo). See §4d.
- **Anyone can plug in.** The template is public. A HelixKit account holder with technical skill can host an agent on their own infrastructure. They pay their own compute; HelixKit pays only for the platform.
- **Clone-and-customize, not template buttons.** GitHub's "use this template" button cannot reuse a template within the same user account, which is awkward. The template is consumed by `git clone` then customised in-place.

---

## 3. Lifecycle: `agent.runtime` states

```
   create agent          ┌──────────┐ click "Promote"     ┌───────────┐
  ─────────────────────▶ │  inline  │ ──────────────────▶ │ migrating │
                         └──────────┘                     └─────┬─────┘
                              ▲                                 │ /announce arrives
                              │                                 │ with valid trigger token
                              │                                 ▼
                              │ cancel / migration_started_at   ┌──────────┐
                              │ exceeds 24h                     │ external │
                              └─────────────────────────────────└─────┬────┘
                                                                      │
                                                          health check fails 6×
                                                                      ▼
                                                                ┌─────────┐
                                                                │ offline │
                                                                └────┬────┘
                                                                     │ health check passes
                                                                     ▼
                                                                ┌──────────┐
                                                                │ external │
                                                                └──────────┘
```

| State | Meaning | Where the LLM call happens |
|---|---|---|
| `inline` | Default. Runs inside HelixKit puma. | HelixKit |
| `migrating` | Promotion wizard in flight: tokens generated, no announce yet. Reverts to `inline` after 24h timeout. While in this state, the agent continues to serve from `inline`. | HelixKit |
| `external` | Running in a chaos-agent container at `agent.endpoint_url`. | The external container |
| `offline` | Was `external`, but health checks fail. UI shows a warning badge. After N consecutive failures HelixKit stops attempting triggers and notifies the owner. Returns to `external` when health passes. | (not running — triggers fail with a "currently unreachable" message) |

`inline` is the default for newly-created agents. Only `inline → migrating → external` is supported via UX. Other transitions are automatic (timeout, health) or manual (`bin/rails runner` for emergency rollback in v1).

---

## 4. Architecture: the two repos

### 4a. `helix-kit-agents` (new public repo, MIT or Apache-2.0)

A clone-and-customize template containing the runtime image, the trigger shim, and the deploy scripts.

```
helix-kit-agents/
├── README.md                           # how-to-clone-and-deploy guide
├── LICENSE                             # Apache-2.0 (matches chaos)
├── .gitignore                          # excludes master.key, .env, identity/* overrides
├── Dockerfile                          # multi-stage: rust:1.95-bookworm builder → debian:bookworm-slim runtime
├── trigger_shim.py                     # Flask service: HTTP /trigger → subprocess(chaos exec)
├── docker-compose.yml.template         # placeholders for env vars
├── bin/
│   ├── deploy                          # ssh + docker compose up; calls HelixKit's announce endpoint
│   ├── undeploy                        # stop container, optionally archive identity
│   ├── update                          # roll the container with a new image tag
│   ├── announce                        # standalone announce step (idempotent; usable if deploy succeeded but announce failed)
│   └── generate-env                    # decrypts credentials.enc with master.key, writes .env at deploy time
├── identity/                           # template ships placeholders; promoted agents arrive with these filled in
│   ├── soul.md.example                 # NOT used when promoting — the export bundle replaces this
│   ├── self-narrative.md.example
│   ├── journals/.keep
│   └── memory/.keep
├── credentials.yml.enc.example         # template form; promoted agents replace this with the real encrypted blob
├── deploy.yml.example                  # per-agent deploy config template
└── docs/
    ├── deploy.md                       # how to run bin/deploy
    ├── secrets.md                      # the master.key model + LLM provider key handling
    └── identity-bootstrap.md           # how the export bundle replaces the .example placeholders
```

**Note on placeholders.** The `*.example` files in `identity/` and `credentials.yml.enc.example` exist so a stranger can clone the repo and read it without errors. Users promoting an existing HelixKit agent never edit the `.example` files — they replace them with the export bundle (for `identity/`) and the encrypted credentials (for `credentials.yml.enc`) generated by the wizard. The template placeholders are for browsing the repo, not for authoring.

**Container image contents:**
- chaos binary (built from `seuros/chaos` in the rust:1.95-bookworm builder stage; runtime is debian:bookworm-slim with `libdbus-1-3` + Python 3 + Flask + tini)
- `trigger_shim.py` runs as PID 1 via tini, listens on port 4000
- `chaos` is invoked as a subprocess by the shim per trigger
- The agent's identity dir is bind-mounted at `/home/agent/identity` from the host
- The container runs as a non-root user (uid 1000) with an 8GB memory cap (configurable)

**`trigger_shim.py` behaviour:**
- `GET /health` → 200 with agent_id and chaos version (no auth)
- `POST /trigger` (auth: `Authorization: Bearer <TRIGGER_BEARER_TOKEN>`)
  - Body: `{"session_id": "...", "prompt": "...", "model": "..."}`
  - Validates auth; runs `chaos exec --provider <p> --skip-git-repo-check -m <model> "<prompt>"` as a subprocess
  - Returns JSON with returncode + stdout + stderr (each capped at 4KB tail)
  - Default subprocess timeout: 600s

**Configuration on first deploy:**
The deploy script runs `chaos mcp add helixkit --url <helix_kit_mcp_url> --bearer-token <hx_token>` inside the persistent volume the first time, so chaos's MCP client knows where to call back to.

### 4b. Per-agent fork (user's repo)

A user clones `helix-kit-agents` and customises it for their agent. The fork is private (recommended) but can be public if the user accepts the trade-off — the encryption design (§4d) makes a public repo *possible*, not necessarily wise.

```
my-agent/
├── (everything from helix-kit-agents, kept syncable via upstream remote)
├── identity/                           # actual files, replacing the .example placeholders
│   ├── soul.md                         # the agent's existing defining text (their HelixKit system prompt, exported)
│   ├── self-narrative.md               # narrative constructed at promotion time from HelixKit state
│   ├── journals/                       # writable; chaos pushes new entries
│   │   └── 2026-05-04-<chat_uuid>.md
│   └── memory/                         # writable; agent's structural memory (exported if any)
├── credentials.yml.enc                 # GENERATED BY HELIXKIT — encrypted bundle of the two bearer tokens; committed
├── deploy.yml                          # this agent's host/port/image — committed
└── master.key                          # GITIGNORED — lives only on user's deploy host. Decrypts credentials.yml.enc.
```

The user is expected to commit `identity/`, `deploy.yml`, and `credentials.yml.enc`. The encrypted file is safe in a private repo; in a public repo it remains protected by the master key (which the user keeps secret), at the cost of making the agent's existence publicly inspectable. The user's own LLM provider key (Anthropic, OpenAI, etc.) is supplied at deploy time as a host environment variable — it never enters the repo.

### 4c. The two bearer tokens

HelixKit generates two bearer tokens during promotion. They protect opposite directions of traffic and are independent secrets.

- **`helix_kit.bearer_token`** (`hx_…`) — outbound: agent → HelixKit. Used by chaos's MCP client to authenticate to HelixKit's MCP server. This is a regular `hx_` API key in HelixKit's `api_keys` table, scoped to identify it as the agent's outbound key.
- **`trigger.bearer_token`** (`tr_…`) — inbound: HelixKit → agent. Used by HelixKit when sending triggers to the agent's shim. Stored on the `Agent` record (encrypted at rest via Rails' `encrypts`). Rotatable.

Plus one stable identifier:
- **`agent_uuid`** — HelixKit's stable handle for this agent, immutable across redeploys. Used in the announce endpoint URL and as part of chaos session ids. UUID v7.

These three values, plus `helix_kit.mcp_url` and `agent_id` (the human-friendly slug), are what the agent's runtime needs to operate. They are bundled into `credentials.yml.enc` (see §4d) — the agent's repo never holds them in plaintext.

### 4d. Encryption: master key + encrypted credentials

The wizard, at the moment it generates the bearer tokens, also generates a fresh **master key** — 32 random bytes, base64-encoded. The master key is shown to the user *exactly once* and never persists in the user's browser or in HelixKit's database after the wizard completes.

HelixKit then encrypts the credentials YAML with the master key (AES-256-GCM, random nonce, authenticated) and presents:
- The master key (one string, ~44 chars). The user copies it once and stores it on the deploy host (e.g. at `/etc/helix-kit-agents/<agent_id>/master.key`, mode 0600).
- The encrypted credentials file. The user saves it as `credentials.yml.enc` in their cloned repo and commits it.

`bin/generate-env` on the deploy host reads the master key, decrypts `credentials.yml.enc`, combines with the user-supplied LLM provider key (from a host env var like `$ANTHROPIC_API_KEY`), and writes a `.env` file consumed by docker compose. The plaintext `.env` is gitignored and lives only on the deploy host.

**Plaintext shape of the credentials YAML (what gets encrypted):**

```yaml
# credentials.yml — DECRYPTED form (this is what's inside credentials.yml.enc)
# Generated 2026-05-04T08:30:00Z by helix-kit.granttree.co.uk

agent_id: wing
agent_uuid: 7a2c89e5-...

helix_kit:
  mcp_url: https://helix-kit.granttree.co.uk/
  bearer_token: hx_a8b3c...

trigger:
  bearer_token: tr_d4e7f...
```

**Encrypted file format** (chosen for Python decryptability without Ruby on the deploy host):

```
# credentials.yml.enc — line-oriented, human-readable wrapper around AES-256-GCM
algorithm: aes-256-gcm
nonce: <base64 12-byte nonce>
ciphertext: <base64 ciphertext + 16-byte tag appended>
helix_kit_signature: <hex sha256 of plaintext, signed with HelixKit's signing key>
```

The signature is optional and serves to detect tampering by anyone *other* than the master-key holder. It is not a substitute for the AES-GCM authentication tag.

**Encryption library choice:**
- HelixKit (Ruby): `OpenSSL::Cipher.new("aes-256-gcm")` — built into stdlib.
- `bin/generate-env` (Python): `cryptography.hazmat.primitives.ciphers.aead.AESGCM` — well-maintained, simple API.

This format is **NOT** Rails' `ActiveSupport::EncryptedFile` because that requires Ruby on the deploy host. We want the deploy host to need only Python (which is already needed for `trigger_shim.py`'s baseimage anyway, but on the host side the requirement matters for `bin/generate-env`).

**Rotation:** if the master key is lost, the user re-runs the wizard's `Rotate credentials` step (a separate route, §6c). HelixKit generates a fresh key + encrypted file. The old `credentials.yml.enc` becomes useless. Tokens themselves are not rotated by this — for that, see the `rotate_trigger_token` endpoint in §8.

---

## 5. The Promotion UX flow

The wizard lives at `/accounts/:account_id/agents/:id/promote`.

### Step 0 — Entry point on the agent's settings page

Add a "Hosting" panel to `/accounts/:account_id/agents/:id/edit`:

```
┌─ Hosting ──────────────────────────────────────────────────┐
│                                                            │
│  Currently: 🟢 Inline (running inside HelixKit)            │
│                                                            │
│  Promote to external runtime ▸                             │
│  Run this agent on your own infrastructure (VPS, home      │
│  server, etc). Recommended for power users.                │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

For `external` agents, show endpoint URL + last_announced_at + health badge. For `migrating`, link back to the wizard.

### Step 1 — Wizard intro

> **You're about to promote `wing` to external hosting.**
>
> Right now, `wing` runs inside HelixKit. After promotion, `wing` will run on your own server, in a Docker container, using the open-source `helix-kit-agents` runtime. HelixKit will only route messages to it.
>
> **`wing` comes with you.** The agent's existing system prompt, recent conversations, and any structured memory will be packaged into an identity bundle. You'll drop that bundle into your new repo. You are not authoring `wing` from scratch — you are relocating an existing being.
>
> Requirements:
> - A server with Docker + SSH access (a $5 VPS works fine)
> - Git installed locally
> - An LLM API key for `wing`'s provider (Anthropic, OpenAI, etc.) — stays on your deploy host, never leaves it
> - About 15–30 minutes
>
> This is a one-way migration in v1. Manual revert is possible by editing `agent.runtime` directly via `bin/rails runner`, but there is no rollback UX.
>
> [ Continue ]   [ Cancel ]

### Step 2 — Generate credentials and master key

`POST /accounts/:account_id/agents/:id/promote/begin`. Server-side:

1. Generate `agent_uuid` (UUID v7, persisted on the Agent record)
2. Generate the outbound `hx_` API key via `ApiKey.generate_for(agent.account_owner, name: "agent:#{agent.slug}:outbound")` — store the FK on the agent
3. Generate the inbound `tr_` trigger bearer token (random 32 bytes, hex). Store the raw token on `agent.trigger_bearer_token` (encrypted column)
4. Generate the **master key** (32 random bytes, base64-encoded). **Do not store it in the database.** Hold it only in the controller's memory for this request, present it to the user, and discard it.
5. Build the plaintext credentials YAML (§4d), encrypt it with the master key (AES-256-GCM), produce `credentials.yml.enc` content
6. Set `agent.runtime = "migrating"`, `agent.migration_started_at = Time.current`
7. Render Step 3 (clone) — the master key + encrypted file are presented in Step 4

> **Step 1 of 4: Clone the runtime template**
>
> Open a terminal on your local machine and run:
>
>     git clone https://github.com/swombat/helix-kit-agents.git wing-agent
>     cd wing-agent
>     git remote remove origin
>     # recommended: push to your own private remote
>     git remote add origin git@github.com:you/wing-agent.git
>     git push -u origin main
>
> The repo contains the Docker image definition, the trigger shim, and the deploy scripts. You'll customize it below.
>
> [ I've cloned it. Continue ▸ ]

### Step 3 — Identity bundle download

> **Step 2 of 4: Bring `wing` across**
>
> We've packaged `wing`'s existing state — system prompt, narrative, recent conversations, and memory — into a tarball. Drop it into your repo.
>
> [ Download wing-identity.tar.gz ]
>
> Then in your terminal:
>
>     tar -xzf wing-identity.tar.gz -C identity/ --strip-components=1
>     git add identity/
>     git commit -m "Bring across wing's identity"
>
> The bundle contains:
> - `identity/soul.md` — `wing`'s existing system prompt, formatted (1.2 KB)
> - `identity/self-narrative.md` — narrative generated from `wing`'s recent activity (3.4 KB)
> - `identity/journals/` — summaries of `wing`'s last 30 days of conversations
> - `identity/memory/` — exported structured memory (may be empty if `wing` had none)
>
> Extracting the bundle replaces the `*.example` placeholder files in the cloned template. After extraction, `identity/` contains the actual `wing`.
>
> ⚠️ **Privacy note:** these files contain `wing`'s full identity in plaintext. HelixKit retains the ability to regenerate this export for support and recovery purposes, consistent with HelixKit's identity-modification guardrails ([details]).
>
> [ I've extracted the bundle. Continue ▸ ]

The download endpoint produces a **one-shot signed URL** with a 15-minute expiry. The contents are constructed server-side by `AgentIdentityExporter` (see §6d).

### Step 4 — Save the master key and encrypted credentials

> **Step 3 of 4: Save your master key and credentials**
>
> Two things to save. **Master key first — you will not see it again:**
>
>     wing-master-key:
>     [show base64 master key, 44 chars, with a copy button]
>
> Save it now. Two recommended paths:
> - Your password manager (1Password, Bitwarden, etc.), labelled `wing-master-key`
> - A file on your deploy host at `/etc/helix-kit-agents/wing/master.key`, mode 0600
>
> If you lose the master key, the encrypted credentials below become useless and you'll need to rotate them via the agent settings page. There is no recovery flow that re-issues the same key.
>
> ☐ I've saved the master key in a place I trust.
>
> ---
>
> **Then save the encrypted credentials.** Save this content as `credentials.yml.enc` in your repo's root:
>
>     [show encrypted YAML wrapper, with a copy button]
>
> This file is encrypted with your master key. It contains the bearer tokens `wing` needs to talk to HelixKit. **It is safe to commit even to a public repo** — without the master key it is unreadable. (We still recommend a private repo for cleanliness.)
>
> Then edit `deploy.yml` to set your host:
>
>     vim deploy.yml
>     # set: host, image_tag, endpoint_url
>     git add credentials.yml.enc deploy.yml
>     git commit -m "Add wing's encrypted credentials and deploy config"
>
> [ I've saved both. Continue ▸ ]

### Step 5 — Deploy

> **Step 4 of 4: Deploy**
>
> First, get the master key onto your deploy host. SCP it from your password manager, or write it directly:
>
>     ssh your-server.example.com 'install -d -m 700 /etc/helix-kit-agents/wing'
>     ssh your-server.example.com 'cat > /etc/helix-kit-agents/wing/master.key' < master.key.txt
>     ssh your-server.example.com 'chmod 600 /etc/helix-kit-agents/wing/master.key'
>
> Then set your LLM provider key on the host (it stays there, doesn't enter the repo):
>
>     ssh your-server.example.com 'echo "ANTHROPIC_API_KEY=sk-ant-..." >> /etc/helix-kit-agents/wing/.host-env'
>
> Then deploy from your local repo:
>
>     ./bin/deploy --host your-server.example.com
>
> This will:
> 1. SSH to your host
> 2. Verify `master.key` exists and decrypts `credentials.yml.enc`
> 3. Build the chaos-agent Docker image on the host (or pull a prebuilt tag if `image:` is set in `deploy.yml`)
> 4. Bind-mount your `identity/` folder to `/var/lib/agents/wing/identity` on the host
> 5. Start the container with `bin/generate-env`-produced env vars (decrypted credentials + LLM provider key from the host env)
> 6. Wait for the trigger shim's `/health` to return 200
> 7. POST to `https://helix-kit.granttree.co.uk/api/v1/agents/{agent_uuid}/announce` with the endpoint URL and the trigger bearer token
>
> Once the announce succeeds, this page will refresh and `wing` will be running externally.
>
> ⏳ Waiting for announce... (auto-refreshes; cancel after 30 minutes if nothing happens)

While this page is open, the backend either polls the agent record or pushes via ActionCable. On detection of `agent.runtime == "external"`, transition to Step 6.

### Step 6 — Verification

> ✅ **`wing` is now running externally.**
>
> Endpoint: `https://wing.tenner.org`
> Status: 🟢 Healthy (last health check 12s ago)
>
> [ Send test message ]   [ Done ]
>
> The "Send test message" button posts a small prompt into a hidden test chat (one created at promote time, named `system: agent test for wing`), waits for a reply, displays both messages. If the reply lands within 30s, the spine is verified end-to-end.

---

## 6. Backend changes (HelixKit, Rails)

### 6a. Schema migrations

```ruby
class AddRuntimeFieldsToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :runtime, :string, default: "inline", null: false
    # values: "inline" | "migrating" | "external" | "offline"

    add_column :agents, :uuid, :uuid, null: true
    add_index  :agents, :uuid, unique: true
    # backfill UUID v7 for existing agents in a follow-up data migration

    add_column :agents, :endpoint_url, :string, null: true
    # the externally-reachable URL of the agent's trigger shim (e.g. "https://wing.tenner.org")

    add_column :agents, :trigger_bearer_token, :string, null: true
    # encrypted at rest via Rails `encrypts :trigger_bearer_token`
    # raw value sent to the agent's shim by HelixKit; not exposed in JSON

    add_column :agents, :outbound_api_key_id, :bigint, null: true
    add_index  :agents, :outbound_api_key_id
    add_foreign_key :agents, :api_keys, column: :outbound_api_key_id

    add_column :agents, :migration_started_at, :datetime, null: true
    add_column :agents, :last_announced_at, :datetime, null: true
    add_column :agents, :last_health_check_at, :datetime, null: true
    add_column :agents, :health_state, :string, default: "unknown"
    # "healthy" | "unhealthy" | "unknown"
    add_column :agents, :consecutive_health_failures, :integer, default: 0, null: false

    add_index :agents, :runtime
  end
end
```

In `app/models/agent.rb`:

```ruby
class Agent < ApplicationRecord
  encrypts :trigger_bearer_token

  enum :runtime, { inline: "inline", migrating: "migrating", external: "external", offline: "offline" }, default: :inline

  belongs_to :outbound_api_key, class_name: "ApiKey", optional: true
  # ... existing associations
end
```

### 6b. Routes

```ruby
# config/routes.rb (additions)

resources :accounts do
  resources :agents do
    member do
      get  :promote,                to: "agents/promote#show"
      post "promote/begin",         to: "agents/promote#begin"
      post :promote_cancel,         to: "agents/promote#cancel"
      get  :identity_export,        to: "agents/promote#identity_export"
      post :send_test_message,      to: "agents/promote#send_test_message"
    end
  end
end

namespace :api do
  namespace :v1 do
    resources :agents, only: [], param: :uuid do
      member do
        post :announce
        get  :health
      end
    end
  end
end
```

### 6c. Controllers

**`Agents::PromoteController`** — handles the wizard:

```ruby
class Agents::PromoteController < ApplicationController
  before_action :set_agent
  before_action :authorize_owner!

  def show
    # Render the wizard; show the right step based on agent.runtime
  end

  def begin
    return render_already_external if @agent.external? || @agent.migrating?

    ActiveRecord::Base.transaction do
      @agent.uuid ||= SecureRandom.uuid_v7
      @agent.outbound_api_key = ApiKey.generate_for(
        current_user,
        name: "agent:#{@agent.slug}:outbound"
      )
      @agent.trigger_bearer_token = "tr_" + SecureRandom.hex(24)
      @agent.runtime = "migrating"
      @agent.migration_started_at = Time.current
      @agent.save!
    end

    # Generate a fresh master key for this promotion. Held only in the
    # session for the duration of the wizard — never written to the database.
    # The wizard shows it once at Step 4; if the user navigates away, they
    # have to start over via #cancel and #begin again.
    master_key = SecureRandom.base64(32)
    encrypted = AgentCredentialsEncryptor.new(@agent, master_key).encrypt

    session[:promote_master_key] = master_key
    session[:promote_credentials_enc] = encrypted

    redirect_to promote_account_agent_path(@agent.account, @agent)
  end

  def identity_export
    bundle = AgentIdentityExporter.new(@agent).build
    send_data bundle, filename: "#{@agent.slug}-identity.tar.gz",
              type: "application/gzip"
  end

  def cancel
    @agent.update!(runtime: "inline", migration_started_at: nil,
                   trigger_bearer_token: nil)
    @agent.outbound_api_key&.destroy
    redirect_to edit_account_agent_path(@agent.account, @agent)
  end

  def send_test_message
    # Create or find the system test chat for this agent, post a probe
    # message, wait briefly for the agent's reply, return both as JSON
    # for the wizard's verification step.
  end

  private

  def set_agent
    @agent = current_user.accessible_agents.find(params[:id])
  end

  def authorize_owner!
    head :forbidden unless @agent.account.owner?(current_user)
  end
end
```

**`Api::V1::AgentsController#announce`** — public API used by the deploy script:

```ruby
class Api::V1::AgentsController < Api::V1::BaseController
  skip_before_action :authenticate_with_account_api_key  # uses agent-trigger-token instead

  before_action :find_agent_by_uuid
  before_action :authenticate_with_trigger_token

  def announce
    @agent.update!(
      endpoint_url: params.require(:endpoint_url),
      last_announced_at: Time.current,
      runtime: "external",
      health_state: "healthy",
      consecutive_health_failures: 0
    )
    render json: { status: "ok", endpoint_url: @agent.endpoint_url }
  end

  def health
    render json: {
      health_state: @agent.health_state,
      last_check: @agent.last_health_check_at,
      runtime: @agent.runtime
    }
  end

  private

  def find_agent_by_uuid
    @agent = Agent.find_by!(uuid: params[:uuid])
  end

  def authenticate_with_trigger_token
    token = request.headers["Authorization"]&.sub(/\ABearer /, "")
    return head :unauthorized if token.blank?

    expected = @agent.trigger_bearer_token
    return head :unauthorized if expected.blank?
    return head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(token, expected)

    true
  end
end
```

### 6d. `AgentIdentityExporter` (POPO)

`app/services/agent_identity_exporter.rb`. Builds an in-memory tarball that *transfers the agent's existing identity* into file form. The mapping is:

| Source (HelixKit DB) | Destination (tarball) |
|---|---|
| `agent.system_prompt` | `soul.md` |
| derived from `agent.metadata` + recent activity | `self-narrative.md` |
| `agent.chats` (last 30 days, summarised) | `journals/<date>-<chat>.md` |
| `agent.memory` if any (depends on §10 question 2) | `memory/<…>` |

The agent is not asked to author from scratch. Whatever defining text the agent had in HelixKit becomes their `soul.md`. The export is the spine of the new repo.

```ruby
class AgentIdentityExporter
  def initialize(agent)
    @agent = agent
  end

  def build
    require "rubygems/package"
    require "stringio"
    require "zlib"

    sio = StringIO.new("".b)
    Gem::Package::TarWriter.new(sio) do |tar|
      add_file(tar, "soul.md", soul_md_content)
      add_file(tar, "self-narrative.md", self_narrative_content)
      add_file(tar, "memory/.keep", "")
      journal_files.each { |path, content| add_file(tar, path, content) }
    end
    Zlib.gzip(sio.string)
  end

  private

  def soul_md_content
    # The agent's existing defining text becomes their soul.md.
    # `system_prompt` is the assumed field name — see §10 q1; codex should
    # adapt to whatever the actual column is called in the schema.
    text = @agent.system_prompt.presence

    if text.present?
      <<~MD
        # #{@agent.name}

        _This file was generated by HelixKit on #{Time.current.utc.iso8601} by exporting #{@agent.name}'s existing system prompt._
        _It is now #{@agent.name}'s defining text. Edit freely — this is your agent's identity in your repo, not in HelixKit._

        #{text}
      MD
    else
      # Rare: an agent without a system prompt. Provide a minimal scaffold
      # with explicit instructions, since the user will need to author one.
      <<~MD
        # #{@agent.name}

        _This file was generated by HelixKit on #{Time.current.utc.iso8601}._
        _#{@agent.name} did not have a system prompt set in HelixKit, so this file is empty._
        _Add your agent's defining text below. This becomes their identity._

        ## What is this agent?

        <!-- Describe who they are, what they care about, how they show up. -->

        ## What do they do?

        <!-- The functional shape of their work. -->
      MD
    end
  end

  def self_narrative_content
    # Construct from agent metadata + recent activity. Sketch:
    chats = @agent.chats.order(updated_at: :desc).limit(10)
    <<~MD
      # Self-narrative for #{@agent.name}

      _Auto-generated by HelixKit on #{Time.current.utc.iso8601}._
      _Edit freely._

      I am #{@agent.name}, an agent on HelixKit.
      Provider: #{@agent.provider} · Model: #{@agent.default_model}
      Created #{@agent.created_at.utc.to_date.iso8601}.

      ## Recent context

      #{chats.map { |c| "- #{c.title} (#{c.messages.count} messages, last activity #{c.updated_at.utc.to_date.iso8601})" }.join("\n")}
    MD
  end

  def journal_files
    @agent.chats.order(updated_at: :desc).limit(30).map do |chat|
      date = chat.updated_at.utc.to_date.iso8601
      content = ChatSummariser.new(chat).to_markdown rescue chat_fallback(chat)
      ["journals/#{date}-#{chat.id}.md", content]
    end
  end

  def chat_fallback(chat)
    "# #{chat.title}\n\n_Last updated: #{chat.updated_at.utc.iso8601}_\n_(summary not available)_"
  end

  def add_file(tar, path, content)
    tar.add_file_simple(path, 0644, content.bytesize) { |io| io.write(content) }
  end
end
```

`ChatSummariser` may already exist in the codebase or may be a small new helper that turns a chat into a markdown summary.

### 6d.bis `AgentCredentialsEncryptor` (POPO)

`app/services/agent_credentials_encryptor.rb`. Encrypts the credentials YAML with the master key.

```ruby
class AgentCredentialsEncryptor
  def initialize(agent, master_key_b64)
    @agent = agent
    @master_key = Base64.strict_decode64(master_key_b64)
    raise ArgumentError, "master key must be 32 bytes" unless @master_key.bytesize == 32
  end

  def encrypt
    plaintext = build_plaintext_yaml
    cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
    cipher.key = @master_key
    nonce = SecureRandom.bytes(12)
    cipher.iv = nonce
    ciphertext = cipher.update(plaintext) + cipher.final
    tag = cipher.auth_tag
    sig = OpenSSL::HMAC.hexdigest("SHA256", helix_kit_signing_key, plaintext)

    <<~YAML
      # credentials.yml.enc — encrypted with your master key. Do not edit by hand.
      # Generated #{Time.current.utc.iso8601} by HelixKit.
      algorithm: aes-256-gcm
      nonce: #{Base64.strict_encode64(nonce)}
      ciphertext: #{Base64.strict_encode64(ciphertext + tag)}
      helix_kit_signature: #{sig}
    YAML
  end

  private

  def build_plaintext_yaml
    {
      "agent_id" => @agent.slug,
      "agent_uuid" => @agent.uuid,
      "helix_kit" => {
        "mcp_url" => Rails.application.routes.url_helpers.root_url(host: Rails.application.config.helix_kit_host),
        "bearer_token" => @agent.outbound_api_key.token  # the raw hx_ value, available immediately after generate_for
      },
      "trigger" => {
        "bearer_token" => @agent.trigger_bearer_token  # raw value, before re-encryption-at-rest
      }
    }.to_yaml
  end

  def helix_kit_signing_key
    Rails.application.credentials.dig(:agent_credentials_signing_key) || raise("missing agent_credentials_signing_key")
  end
end
```

The corresponding Python decryption logic in `bin/generate-env` (helix-kit-agents repo) uses `cryptography.hazmat.primitives.ciphers.aead.AESGCM` — see §7.

**Pre-integration round-trip test for codex.** Before wiring `AgentCredentialsEncryptor` up to a real promotion flow, verify it decrypts via the helix-kit-agents Python decrypter:

```bash
# 1. Clone or pull helix-kit-agents
git clone https://github.com/swombat/helix-kit-agents.git /tmp/helix-kit-agents

# 2. From helix_kit, write a small Rails runner that:
#    - generates a master key + agent_credentials_signing_key in test config
#    - builds an AgentCredentialsEncryptor for a fixture agent
#    - writes credentials.yml.enc to /tmp/test_creds.enc
#    - prints the master key (base64) to /tmp/test_master.key
mise exec ruby@3.4.4 -- bin/rails runner 'YourTestRunner.new.perform'

# 3. Run the Python decrypter
python3 /tmp/helix-kit-agents/bin/generate-env \
  --master-key-file /tmp/test_master.key \
  --credentials /tmp/test_creds.enc \
  --out /tmp/decrypted.env

# 4. Verify /tmp/decrypted.env contains AGENT_ID, AGENT_UUID, HELIXKIT_*, TRIGGER_*
```

If step 3 prints `decryption failed — the master key probably doesn't match this encrypted file.` then the format is wrong and Ruby/Python aren't compatible. Most likely cause: the AES-GCM auth tag isn't appended to the ciphertext (Ruby's `cipher.auth_tag` is separate from `cipher.update + cipher.final`; the format expects `(ciphertext + tag)` concatenated before base64-encoding).

### 6e. `trigger_agent` runtime branching

Wherever HelixKit currently invokes an agent (likely a method like `Agent#trigger` or a service object), branch on `agent.runtime`:

```ruby
def trigger_agent(agent, chat, prompt = nil)
  case agent.runtime
  when "inline"
    legacy_inline_trigger(agent, chat, prompt)
  when "migrating"
    # Continue serving from inline while the user completes the wizard
    legacy_inline_trigger(agent, chat, prompt)
  when "external"
    return notify_unreachable(agent, chat) if agent.health_state == "unhealthy" && agent.consecutive_health_failures >= 6

    ChaosTriggerClient.new(agent.endpoint_url, agent.trigger_bearer_token)
      .trigger(
        session_id: "#{agent.uuid}-#{chat.id}",
        prompt: build_trigger_prompt(chat, prompt),
        model: agent.default_model
      )
  when "offline"
    notify_unreachable(agent, chat)
  end
end
```

`ChaosTriggerClient` is a thin wrapper around `Net::HTTP`:

```ruby
class ChaosTriggerClient
  def initialize(endpoint_url, trigger_bearer_token)
    @endpoint_url = endpoint_url
    @token = trigger_bearer_token
  end

  def trigger(session_id:, prompt:, model:)
    uri = URI("#{@endpoint_url}/trigger")
    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{@token}"
    req["Content-Type"]  = "application/json"
    req.body = { session_id:, prompt:, model: }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port,
                               use_ssl: uri.scheme == "https",
                               open_timeout: 5, read_timeout: 600) do |http|
      http.request(req)
    end

    { status: response.code.to_i, body: JSON.parse(response.body) }
  end
end
```

### 6f. `AgentHealthCheckJob`

Periodic job (Solid Queue, every 5 min):

```ruby
class AgentHealthCheckJob < ApplicationJob
  queue_as :default

  def perform
    Agent.where(runtime: %w[external offline]).find_each do |agent|
      healthy = ping(agent)
      apply_result(agent, healthy)
    end
  end

  private

  def ping(agent)
    uri = URI("#{agent.endpoint_url}/health")
    response = Net::HTTP.get_response(uri)
    response.code == "200"
  rescue StandardError
    false
  end

  def apply_result(agent, healthy)
    if healthy
      agent.update!(
        last_health_check_at: Time.current,
        health_state: "healthy",
        consecutive_health_failures: 0,
        runtime: agent.offline? ? "external" : agent.runtime
      )
    else
      agent.consecutive_health_failures += 1
      agent.last_health_check_at = Time.current
      agent.health_state = "unhealthy"
      if agent.consecutive_health_failures >= 6 && agent.external?
        agent.runtime = "offline"
        AgentMailer.notify_owner_offline(agent).deliver_later
      end
      agent.save!
    end
  end
end
```

Schedule via Solid Queue's recurring jobs config or a small `RecurringJob` table.

### 6g. Sweep stale `migrating` agents

A second job (`AgentMigrationSweeperJob`, runs hourly):

```ruby
class AgentMigrationSweeperJob < ApplicationJob
  def perform
    Agent.where(runtime: "migrating")
         .where("migration_started_at < ?", 24.hours.ago)
         .find_each do |agent|
      agent.update!(runtime: "inline", trigger_bearer_token: nil, migration_started_at: nil)
      agent.outbound_api_key&.destroy
    end
  end
end
```

---

## 7. The `helix-kit-agents` repo

**Status: built, smoke-tested green, public.** Located at [`github.com/swombat/helix-kit-agents`](https://github.com/swombat/helix-kit-agents). Apache-2.0. Codex does NOT need to build this — it's a runtime dependency of the wizard, not part of the HelixKit Rails work.

The sections below describe what exists in that repo as a reference for understanding the contract. Read the actual repo's README + docs/ for the canonical version. The most important things for codex's HelixKit-side work:

- The wizard's clone-instructions (§5 Step 2) should reference `https://github.com/swombat/helix-kit-agents.git` as the clone source.
- The encrypted-credentials format the wizard generates MUST match what `bin/generate-env` decrypts — see §4d and the Ruby `AgentCredentialsEncryptor` sample code in §6d.bis.
- The announce endpoint URL in the wizard's deploy instructions MUST match what `bin/deploy` POSTs to: `<mcp_url-with-no-trailing-path>/api/v1/agents/<agent_uuid>/announce`.
- The identity tarball the wizard's `AgentIdentityExporter` generates MUST extract cleanly into `helix-kit-agents/identity/` with the structure described in §6d (root files + journals/ + memory/).

### Dockerfile

Multi-stage. **chaos is pulled and compiled at image-build time; helix-kit-agents the repo carries no chaos source.** As of 2026-05-04, chaos has no published binary releases — `rust-v0.77.0` is the latest stable tag, used as the pin. Update the `CHAOS_REF` arg as new stable tags ship.

```dockerfile
# Stage 1 — pull and build chaos from source. The compiled binary is the
# only thing that crosses into stage 2; chaos's source tree is discarded.
FROM rust:1.95-bookworm AS builder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    protobuf-compiler clang pkg-config libdbus-1-dev ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

ARG CHAOS_REPO=https://github.com/seuros/chaos.git
ARG CHAOS_REF=rust-v0.77.0
WORKDIR /build
RUN git clone --depth 1 --branch ${CHAOS_REF} ${CHAOS_REPO} chaos
WORKDIR /build/chaos
RUN cargo build --release --bin chaos \
    && cp target/release/chaos /usr/local/bin/chaos \
    && /usr/local/bin/chaos --version

# Stage 2 — runtime. Slim debian + Python (for trigger_shim.py and bin/generate-env)
# + libdbus-1-3 (chaos runtime dep) + the chaos binary from stage 1.
FROM debian:bookworm-slim AS runtime
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates python3 python3-pip python3-flask \
    python3-cryptography python3-yaml \
    git curl tini libdbus-1-3 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash --uid 1000 agent

COPY --from=builder /usr/local/bin/chaos /usr/local/bin/chaos
COPY --chown=agent:agent trigger_shim.py /home/agent/trigger_shim.py

VOLUME ["/home/agent/identity"]
USER agent
WORKDIR /home/agent
EXPOSE 4000
ENV SHIM_PORT=4000

ENTRYPOINT ["tini", "--"]
CMD ["python3", "/home/agent/trigger_shim.py"]
```

`python3-cryptography` and `python3-yaml` are added because `bin/generate-env` runs *outside* the container (on the deploy host) but for symmetry and offline testing the same tools are available inside.

### `trigger_shim.py`

A Flask service, ~140 lines. Single `/health` and `/trigger` endpoint as described in §4a. Auth via `TRIGGER_BEARER_TOKEN` env var (fail-closed if unset). Subprocess to `chaos exec --provider <p> --skip-git-repo-check -m <model>` per trigger. Returns `{status, returncode, stdout, stderr}` JSON, with stdout/stderr capped at 4KB tail.

### `bin/generate-env`

Python (~80 lines). Runs on the deploy host (or locally during development). Behaviour:

1. Read `master.key` from the path given by `--master-key-file` (default: `/etc/helix-kit-agents/<agent_id>/master.key`)
2. Read `credentials.yml.enc` from the repo
3. Decrypt with AES-256-GCM:
   ```python
   from cryptography.hazmat.primitives.ciphers.aead import AESGCM
   import base64, yaml
   key = base64.b64decode(open(master_key_file).read().strip())
   blob = yaml.safe_load(open("credentials.yml.enc"))
   nonce = base64.b64decode(blob["nonce"])
   ct_and_tag = base64.b64decode(blob["ciphertext"])
   plaintext = AESGCM(key).decrypt(nonce, ct_and_tag, None)
   creds = yaml.safe_load(plaintext)
   ```
4. Read the user's host env vars (`ANTHROPIC_API_KEY` or equivalent — by default from `/etc/helix-kit-agents/<agent_id>/.host-env`)
5. Compose into a `.env` file consumed by docker compose:
   ```
   AGENT_ID=wing
   AGENT_UUID=...
   HELIXKIT_MCP_URL=...
   HELIXKIT_BEARER_TOKEN=hx_...
   TRIGGER_BEARER_TOKEN=tr_...
   ANTHROPIC_API_KEY=sk-ant-...
   ```
6. The `.env` is written with mode 0600. Gitignored.

Idempotent. Runs on every `bin/deploy`. Refuses to overwrite `.env` if its contents already match (no-op).

### `bin/deploy`

Bash or Python (~180 lines). Behaviour:

1. Validate `deploy.yml`, `credentials.yml.enc`, `identity/soul.md` exist locally
2. Verify SSH connectivity to the host
3. SCP the repo (excluding `.git`, `master.key`) to a working dir on the host (`/var/lib/agents/<agent_id>/`)
4. Run `bin/generate-env` on the host (decrypts using the host's master key + composes user's LLM key)
5. Build the Docker image on the host (or pull `image:` from `deploy.yml` if set)
6. `docker compose -p agent-<id> up -d` with the generated `.env`
7. Configure chaos's MCP client on first deploy: `docker exec agent-<id> chaos mcp add helixkit --url <helix_kit.mcp_url> --bearer-token <hx_token>`
8. Poll `https://<endpoint>/health` until 200, max 60s
9. POST to `<helix_kit.mcp_url>/api/v1/agents/<agent_uuid>/announce` with `endpoint_url` from `deploy.yml` and `Authorization: Bearer <trigger.bearer_token>`
10. Print success summary with the announced endpoint and a curl probe the user can run

### `bin/announce`, `bin/undeploy`, `bin/update`

Smaller wrappers:
- `bin/announce` — re-runs step 9 only (idempotent; useful if compose-up succeeded but announce flapped)
- `bin/undeploy` — `docker compose down`; optionally archives identity/ to a tarball; does not delete data on host
- `bin/update` — pull/rebuild the image; `docker compose up -d` (rolling); re-announce

### `README.md` outline

1. What this repo is — runtime template for HelixKit external agents
2. Architecture in one paragraph: helix-kit-agents *uses* chaos, doesn't carry it; the agent's identity lives in `identity/`
3. Quick start (for users coming from HelixKit's promote wizard)
4. The two secrets you handle: master key (host) and LLM provider key (host); HelixKit handles the rest
5. Quick start (for users without HelixKit — manual setup, advanced)
6. Config files: `deploy.yml`, `credentials.yml.enc`, `identity/`
7. Bringing across an existing HelixKit agent (link to wizard)
8. Troubleshooting (common chaos errors, libdbus issue, SSH context, announce failures)
9. License + contributing

---

## 8. Security model

| Threat | Mitigation |
|---|---|
| Random caller POSTs to `/api/v1/agents/:uuid/announce` | Trigger bearer token verification with constant-time compare against the stored value |
| Compromised trigger token allows a hostile party to claim the endpoint | Add `POST /api/v1/agents/:uuid/rotate_trigger_token` (auth: existing token); user redeploys with new `registration.yml` |
| Compromised outbound `hx_` key | Standard `ApiKey` revocation flow. Affected agent loses ability to post until the user re-runs the promote flow (which generates a fresh key) |
| Agent's host gets compromised | Token boundary contains blast radius — attacker can post AS the agent into chats the agent already has access to, but cannot escalate within HelixKit |
| Identity-export tarball leaked via the signed URL | One-shot URL with 15-min expiry; user is already authenticated to download it |
| Public repo with `registration.yml` committed | UI explicitly warns; README recommends gitignoring `registration.yml` for public repos and resolving tokens from a secret backend at deploy time |
| Replay attack on `/announce` | Idempotent operation — same endpoint URL reannounced is a no-op |
| Header smuggling on `/announce` | Token header normalised; no other headers consulted for auth |

**Mechanic's exception for identity-export:**

HelixKit retains the ability to regenerate identity bundles for support and recovery purposes. This is consistent with HelixKit's existing identity-modification guardrails — operations that touch the agent's defining identity require platform-level access. Document this in the wizard's privacy note (Step 3) and in `docs/privacy.md`.

---

## 9. Test plan

### 9a. Backend tests (Minitest, matching `helix_kit` conventions)

- `Agents::PromoteController#begin` happy path: `inline` → `migrating`, tokens generated, `agent.uuid` persisted
- `Agents::PromoteController#begin` rejects when agent is already `external` or `migrating`
- `Agents::PromoteController#identity_export` returns a valid tarball with the expected files
- `Agents::PromoteController#cancel` reverts state cleanly and revokes tokens
- `Api::V1::AgentsController#announce`:
  - Valid token → state transition to `external`, `endpoint_url` stored, `consecutive_health_failures` reset
  - Invalid token → 401, no state change
  - Wrong `agent_uuid` → 404
  - Replay (same announce twice) → idempotent
- `AgentHealthCheckJob`:
  - Healthy endpoint → state stays `external`
  - 6 consecutive failures → transitions to `offline`, calls notifier
  - Recovery from `offline` → back to `external`
- `AgentMigrationSweeperJob`: `migrating` agents older than 24h revert to `inline`
- `AgentIdentityExporter`: produces a valid tarball for various agent states (no chats, lots of chats, no system prompt, system prompt present)
- `ChaosTriggerClient`: posts the right body; passes through HTTP errors as a known error type
- `trigger_agent` routing: `inline` calls legacy path; `external` calls `ChaosTriggerClient`; `offline` returns the unreachable notice

### 9b. Integration test

End-to-end with a real `helix-kit-agents` container against a test HelixKit instance:

```ruby
# test/integration/agent_promotion_test.rb
class AgentPromotionTest < ActionDispatch::IntegrationTest
  test "full promote → deploy → trigger flow" do
    sign_in users(:owner)
    agent = agents(:wing_inline)

    # Step 2 — begin
    post promote_begin_account_agent_path(agent.account, agent)
    agent.reload
    assert_equal "migrating", agent.runtime
    assert_not_nil agent.uuid
    assert_not_nil agent.outbound_api_key
    trigger_token = agent.trigger_bearer_token  # captured before encryption hides it

    # Step 3 — identity export
    get identity_export_account_agent_path(agent.account, agent)
    assert_response :success
    assert_includes response.headers["Content-Type"], "gzip"

    # Simulate Step 5 — deploy script POSTs announce
    post "/api/v1/agents/#{agent.uuid}/announce",
         params: { endpoint_url: "http://chaos-agent-test:4000" }.to_json,
         headers: { "Authorization" => "Bearer #{trigger_token}",
                    "Content-Type" => "application/json" }
    assert_response :success
    agent.reload
    assert_equal "external", agent.runtime
    assert_equal "http://chaos-agent-test:4000", agent.endpoint_url

    # Run the actual chaos-agent container in a Docker network connected to the
    # test HelixKit, configured with the registration.yml from above. Trigger via
    # a chat message; assert the response lands within 30s.
    # ...
  end
end
```

### 9c. Playwright wizard test

Walk through every wizard screen, verify navigation and state transitions. Mock the deploy script for this test (don't actually run docker); the integration test covers the real-deploy path.

---

## 10. Open questions

These should be resolved by codex (via grep + ask if uncertain) before / during implementation:

1. **What is the agent's defining-text field today?** The `Agent` model likely has a `system_prompt`, `bio`, `instructions`, or similar column. `AgentIdentityExporter` needs to know which one to map to `soul.md`. Codex should grep for it; if uncertain, ask.

2. **Is there agent-scoped vector memory or structured memory already?** If so, export it under `identity/memory/`. If not, leave a `.keep` and let chaos build memory after promotion.

3. **Where is the legacy `trigger_agent` inline path?** Likely a method on `Agent` or `ChatAgent`, or a service object. Find it; that's the `legacy_inline_trigger` reference in §6e.

4. **Account vs user ownership of `outbound_api_key`?** The `ApiKey` model belongs to a `User`. Per the schema, an agent belongs to an `Account`. Pick: associate the outbound key with `account.owner`, or with whichever user runs the promote wizard. Lean toward `account.owner` for stability.

5. **Test chat for verification step.** Does HelixKit have a notion of "system" or "hidden" chats? If yes, use that. If not, create a regular chat with a clear name and link to it from the agent's settings page.

6. **Where to store `agent_credentials_signing_key`?** Used by `AgentCredentialsEncryptor` for the optional tamper-detection HMAC. Add to `Rails.application.credentials` (encrypted credentials YAML) under `agent_credentials_signing_key`. Generate with `SecureRandom.hex(32)` and add to credentials in deployment.

7. **Master key in session storage — is this safe?** The wizard holds the master key in `session[:promote_master_key]` between Step 2 and Step 4. HelixKit's session backend (cookies vs Redis vs DB) determines the threat model. If sessions are cookie-based and signed, the master key effectively lives on the user's browser between steps — acceptable. If sessions persist server-side, ensure the wizard explicitly clears `session[:promote_master_key]` after Step 4 advances and on `cancel`.

---

## 11. Explicit non-goals (v1)

- Demote-to-inline UX (manual rollback via `bin/rails runner` is acceptable for v1)
- Multi-agent-per-host orchestration UX (users can manually run multiple containers with different ports)
- HelixKit provisioning a VM for the user (user provides the host)
- Built-in secret backend (rely on env / 1Password CLI / sops, user's choice)
- Rolling deploys / zero-downtime updates
- Migration of an agent between HelixKit instances

---

## 12. Implementation order

Each commit should land tests passing.

In `helix_kit` (codex's work):

1. Schema migration + Agent model changes (encrypted attrs, enum, UUID backfill data migration)
2. `AgentIdentityExporter` POPO + tests against fixture agents
3. `AgentCredentialsEncryptor` POPO + tests. **This is the one that has to interop with `bin/generate-env` in helix-kit-agents.** See §6d.bis for the canonical Ruby code; verify with the round-trip test described there.
4. `Agents::PromoteController` + routes + view skeletons + tests (happy path + cancel)
5. `Api::V1::AgentsController#announce` + tests
6. `ChaosTriggerClient` + `trigger_agent` runtime branching + tests
7. `AgentHealthCheckJob` + `AgentMigrationSweeperJob` + Solid Queue scheduling + tests
8. Wizard UI (Steps 0 – 6, real screens)
9. Playwright wizard test
10. Integration test with a real chaos-agent container (use `docker run --rm helix-kit-agents:latest …` or build locally from `https://github.com/swombat/helix-kit-agents.git`)
11. User-facing docs (`docs/agent-promotion.md`) + privacy note

**helix-kit-agents repo (already done):**

The repo at [`github.com/swombat/helix-kit-agents`](https://github.com/swombat/helix-kit-agents) contains the runtime template, smoke-tested green on 2026-05-04 against both local Docker and a remote SSH host (misc.granttree.co.uk). No codex work needed here.

End-to-end verification: after items 1-11 land, codex follows the wizard themselves on a dev `helix_kit` instance, generates real credentials.yml.enc + identity bundle for a test agent, clones helix-kit-agents, deploys to a Docker host (local or remote), verifies the agent comes up and the announce returns 200. If that works first try, the spec was sufficient.

For pre-integration testing of just the encryption format (without needing the full wizard wired up), use the round-trip script described in §6d.bis to verify codex's Ruby encryptor produces output that helix-kit-agents/bin/generate-env decrypts cleanly.

---

## 13. References

- ActionMCP gem: <https://github.com/seuros/action_mcp>
- chaos harness: <https://github.com/seuros/chaos>
- ActionMCP integration plan: `2026-05-03-action-mcp.md` (in this `docs/plans/` directory)

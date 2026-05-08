# Agent Promotion: Local Test Runbook

Use this to test the current per-agent GitHub repo promotion flow end to end.

## Preconditions

- `helix_kit` is running locally on http://localhost:3100.
- `HELIXKIT_APP_URL` is exported before creating credentials:

  ```bash
  export HELIXKIT_APP_URL=http://host.docker.internal:3100
  ```

- Docker Desktop is running.
- `swombat/helix-kit-agents` is marked as a GitHub template repository.
- The current `helix-kit-agents` template changes have been pushed before you create a new agent repo.
- You have a GitHub PAT with `repo` scope.
- You have `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` available in the shell where you deploy.

## Phase 1 - Prepare HelixKit

```bash
cd ~/dev/helix_kit
mise exec ruby@3.4.4 -- bin/rails db:migrate
bin/dev
```

Verify Rails:

```bash
curl -sf http://localhost:3100/up && echo "rails ok"
```

## Phase 2 - Walk the Promotion Wizard

1. Open http://localhost:3100.
2. Log in and open the inline agent you want to promote.
3. Click the promote action from the agent settings page.
4. Paste the GitHub PAT when prompted. HelixKit validates it against GitHub and stores it encrypted on the account.
5. Confirm the repo name. The default is `<agent-slug>-agent`; private repos are the default.
6. Click "Create repo and credentials".

Expected results:

- GitHub contains a new per-agent repo created from `swombat/helix-kit-agents`.
- The new repo contains `identity/`, `deploy.yml`, and `credentials.yml.enc`.
- The repo has a read-write deploy key.
- HelixKit marks the agent `migrating`.
- The wizard shows a one-time `master.key`.

## Phase 3 - Clone and Deploy Locally

Clone the per-agent repo shown by the wizard:

```bash
git clone git@github.com:<github-login>/<agent-slug>-agent.git
cd <agent-slug>-agent
```

Save the one-time key:

```bash
printf '%s' '<master-key-from-wizard>' > master.key
```

Set model provider credentials:

```bash
export ANTHROPIC_API_KEY=...
# or:
export OPENAI_API_KEY=...
```

If macOS Python certificate discovery fails during announce:

```bash
export SSL_CERT_FILE=$(python3 -m certifi)
```

Deploy locally:

```bash
bin/deploy --local
```

Expected results:

- `bin/generate-env` decrypts `credentials.yml.enc`.
- `.agent-deploy-key` is written with mode `0600`.
- Docker starts the runtime and health checks pass.
- The runtime announces to HelixKit.
- The agent changes from `migrating` to `external` in the wizard.

## Phase 4 - Verify Agent Repo Sovereignty

Check the container has a writable repo and deploy key:

```bash
docker exec -it agent-<agent-slug> bash
cd /home/agent/repo
git status
ls -l /run/agent-deploy-key
```

Optional push test:

```bash
cd /home/agent/repo
date -u > identity/manual-push-test.txt
git add identity/manual-push-test.txt
git commit -m "Test agent repo push"
git push origin HEAD
```

Then remove the test file from the GitHub repo or revert the commit.

## Phase 5 - Trigger the Agent

Back in HelixKit, click "Send test request" in the promotion wizard.

Expected results:

- HelixKit sends a request to the external runtime.
- A transport success means the runtime accepted the request.
- The agent may choose not to answer; that is valid.
- If the agent does answer, it posts through the HelixKit REST API using its agent-scoped key.

## Phase 6 - Cancel Behavior

Cancel promotion if you need to roll the HelixKit record back to inline:

- HelixKit sets the agent runtime back to `inline`.
- The GitHub repo is not deleted.
- The deploy key remains on the repo until manually revoked.

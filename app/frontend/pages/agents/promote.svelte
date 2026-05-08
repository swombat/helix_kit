<script>
  import { onDestroy, onMount } from 'svelte';
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import {
    beginPromoteAccountAgentPath,
    cancelPromoteAccountAgentPath,
    editAccountAgentPath,
    githubAccessPromoteAccountAgentPath,
    sendTestRequestAccountAgentPath,
  } from '@/routes';

  let {
    account,
    agent,
    github_configured: githubConfigured = false,
    github_login: githubLogin = null,
    default_repo_name: defaultRepoName,
    github_repo: githubRepo = null,
    clone_url: cloneUrl = null,
    generated_credentials: generatedCredentials = null,
  } = $props();

  let githubPat = $state('');
  let repoName = $state(defaultRepoName);
  let privateRepo = $state(true);
  let creatingRepo = $state(false);
  let savingGithub = $state(false);
  let sendingTestRequest = $state(false);
  let testResult = $state(null);
  let pollTimer = null;

  let editPath = $derived(editAccountAgentPath(account.id, agent.id));
  let beginPath = $derived(beginPromoteAccountAgentPath(account.id, agent.id));
  let githubAccessPath = $derived(githubAccessPromoteAccountAgentPath(account.id, agent.id));
  let cancelPath = $derived(cancelPromoteAccountAgentPath(account.id, agent.id));
  let testRequestPath = $derived(sendTestRequestAccountAgentPath(account.id, agent.id));
  let repo = $derived(generatedCredentials?.repo || githubRepo);
  let sshCloneUrl = $derived(repo?.ssh_url || cloneUrl);
  let repoHtmlUrl = $derived(repo?.html_url || githubRepo?.html_url);
  let masterKeyHref = $derived(
    `data:text/plain;charset=utf-8,${encodeURIComponent(generatedCredentials?.master_key || '')}`
  );
  let shouldPoll = $derived(agent.runtime === 'migrating' || generatedCredentials);

  function saveGithubAccess() {
    savingGithub = true;
    router.post(
      githubAccessPath,
      { github_pat: githubPat },
      {
        preserveScroll: true,
        onFinish: () => {
          savingGithub = false;
          githubPat = '';
        },
      }
    );
  }

  function beginPromotion() {
    creatingRepo = true;
    router.post(
      beginPath,
      { repo_name: repoName, private_repo: privateRepo },
      {
        preserveScroll: true,
        onFinish: () => {
          creatingRepo = false;
        },
      }
    );
  }

  function cancelPromotion() {
    router.post(cancelPath);
  }

  function sendTestRequest() {
    sendingTestRequest = true;
    testResult = null;

    fetch(testRequestPath, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
      },
    })
      .then((response) => response.json().then((body) => ({ ok: response.ok, body })))
      .then(({ ok, body }) => {
        testResult = ok ? body : { status: 'transport_failed', error: body.error || 'Test request failed' };
      })
      .catch((error) => {
        testResult = { status: 'transport_failed', error: error.message };
      })
      .finally(() => {
        sendingTestRequest = false;
      });
  }

  onMount(() => {
    if (shouldPoll) {
      pollTimer = setInterval(() => {
        router.reload({ only: ['agent'], preserveScroll: true });
      }, 5000);
    }
  });

  onDestroy(() => {
    if (pollTimer) clearInterval(pollTimer);
  });
</script>

<svelte:head>
  <title>Promote {agent.name}</title>
</svelte:head>

<div class="mx-auto max-w-4xl space-y-6 p-8">
  <div class="space-y-2">
    <a class="text-sm text-muted-foreground hover:text-foreground" href={editPath}>Back to agent settings</a>
    <h1 class="text-3xl font-semibold">Promote {agent.name}</h1>
    <p class="text-muted-foreground">
      Move this agent to an external Docker runtime. HelixKit will send trigger requests; the agent decides whether to
      respond.
    </p>
  </div>

  <section class="space-y-3 rounded-lg border p-5">
    <h2 class="text-lg font-medium">Status</h2>
    <p class="text-sm">Current runtime: <span class="font-medium">{agent.runtime || 'inline'}</span></p>
    {#if repoHtmlUrl}
      <p class="text-sm">
        Agent repo:
        <a class="font-mono text-primary hover:underline" href={repoHtmlUrl}>{repoHtmlUrl}</a>
      </p>
    {/if}
    {#if agent.endpoint_url}
      <p class="text-sm">Endpoint: <span class="font-mono">{agent.endpoint_url}</span></p>
      <p class="text-sm">Health: <span class="font-medium">{agent.health_state || 'unknown'}</span></p>
    {/if}
  </section>

  <section class="space-y-4 rounded-lg border p-5">
    <div class="space-y-2">
      <h2 class="text-lg font-medium">1. GitHub access</h2>
      {#if githubConfigured}
        <p class="text-sm text-muted-foreground">Connected as <span class="font-medium">@{githubLogin}</span>.</p>
      {:else}
        <p class="text-sm text-muted-foreground">
          Paste a GitHub PAT with repo access. HelixKit stores it encrypted and uses it to create this agent's repo.
        </p>
      {/if}
    </div>
    {#if !githubConfigured}
      <div class="grid gap-3 sm:grid-cols-[1fr_auto]">
        <input
          class="h-10 rounded-md border bg-background px-3 text-sm"
          type="password"
          autocomplete="off"
          placeholder="github_pat_..."
          bind:value={githubPat} />
        <Button onclick={saveGithubAccess} disabled={!githubPat || savingGithub}>
          {savingGithub ? 'Checking...' : 'Save GitHub access'}
        </Button>
      </div>
    {/if}
  </section>

  {#if githubConfigured && !generatedCredentials && agent.runtime !== 'migrating'}
    <section class="space-y-4 rounded-lg border p-5">
      <div class="space-y-2">
        <h2 class="text-lg font-medium">2. Create the agent repo</h2>
        <p class="text-sm text-muted-foreground">
          HelixKit will create a private repo from the runtime template, add this agent's identity files, create an
          agent-scoped API key, and upload a deploy key.
        </p>
      </div>
      <div class="grid gap-4">
        <label class="grid gap-2 text-sm font-medium">
          Repository name
          <input class="h-10 rounded-md border bg-background px-3 font-mono text-sm" bind:value={repoName} />
        </label>
        <label class="flex items-center gap-2 text-sm">
          <input class="h-4 w-4" type="checkbox" bind:checked={privateRepo} />
          Private repo
        </label>
      </div>
      <div class="flex flex-wrap gap-3">
        <Button onclick={beginPromotion} disabled={!repoName || creatingRepo}>
          {creatingRepo ? 'Creating...' : 'Create repo and credentials'}
        </Button>
        {#if agent.runtime === 'migrating'}
          <Button variant="outline" onclick={cancelPromotion}>Cancel promotion</Button>
        {/if}
      </div>
    </section>
  {/if}

  {#if agent.runtime === 'migrating' && !generatedCredentials}
    <section class="space-y-3 rounded-lg border p-5">
      <h2 class="text-lg font-medium">Waiting for runtime</h2>
      <p class="text-sm text-muted-foreground">
        The repo has been prepared. Deploy the runtime, then keep this page open until the status changes to external.
      </p>
      <Button variant="outline" onclick={cancelPromotion}>Cancel promotion</Button>
    </section>
  {/if}

  {#if generatedCredentials}
    <section class="space-y-4 rounded-lg border p-5">
      <h2 class="text-lg font-medium">3. Clone the agent repo</h2>
      <pre class="overflow-x-auto rounded bg-muted p-3 text-sm">git clone {sshCloneUrl}
cd {repo?.name}</pre>
    </section>

    <section class="space-y-4 rounded-lg border p-5">
      <h2 class="text-lg font-medium">4. Save the master key</h2>
      <p class="text-sm text-muted-foreground">
        The repo already contains identity files, deploy.yml, and credentials.yml.enc. This key is shown once.
      </p>
      <a class="inline-flex" href={masterKeyHref} download="master.key">
        <Button variant="outline">Download master.key</Button>
      </a>
      <pre class="overflow-x-auto rounded bg-muted p-3 text-sm">{generatedCredentials.master_key}</pre>
      <pre
        class="overflow-x-auto rounded bg-muted p-3 text-sm">printf '%s' '{generatedCredentials.master_key}' &gt; master.key</pre>
    </section>

    <section class="space-y-4 rounded-lg border p-5">
      <h2 class="text-lg font-medium">5. Set environment and deploy</h2>
      <pre class="overflow-x-auto rounded bg-muted p-3 text-sm">export ANTHROPIC_API_KEY=...
# or: export OPENAI_API_KEY=...
# macOS certificate fallback, only if announce fails with CERTIFICATE_VERIFY_FAILED:
export SSL_CERT_FILE=$(python3 -m certifi)

bin/deploy --local
# later, for a production host:
bin/deploy --host your-docker-host</pre>
      <p class="text-sm text-muted-foreground">
        The deploy script rsyncs the repo, decrypts credentials, builds the image, starts the container, checks health,
        and announces the runtime back to HelixKit.
      </p>
    </section>
  {/if}

  {#if agent.runtime === 'external'}
    <section class="space-y-4 rounded-lg border p-5">
      <h2 class="text-lg font-medium">Verification</h2>
      <p class="text-sm text-muted-foreground">
        Send a request to the external runtime. The agent may choose not to answer; transport errors will be shown
        separately.
      </p>
      <Button onclick={sendTestRequest} disabled={sendingTestRequest}>
        {sendingTestRequest ? 'Sending...' : 'Send test request'}
      </Button>
      {#if testResult}
        <div class="rounded border p-3 text-sm">
          {#if testResult.status === 'runtime_reachable'}
            Runtime accepted the request. The agent may still choose not to post a reply.
          {:else if testResult.status === 'transport_failed'}
            Transport failed{testResult.transport_status ? ` (${testResult.transport_status})` : ''}. Check the endpoint
            and trigger token.
          {:else}
            Request queued.
          {/if}
        </div>
      {/if}
    </section>
  {/if}
</div>

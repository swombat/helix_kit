<script>
  import { onMount } from 'svelte';
  import { fly } from 'svelte/transition';
  import { useForm, router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import { Switch } from '$lib/components/shadcn/switch';
  import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import { Alert, AlertDescription, AlertTitle } from '$lib/components/shadcn/alert';
  import { ArrowLeft, ArrowRight, Check, Gear, Info, PenNib, Sparkle } from 'phosphor-svelte';
  import AgentAppearanceFields from '$lib/components/agents/AgentAppearanceFields.svelte';
  import AgentModelSelect from '$lib/components/agents/AgentModelSelect.svelte';
  import { agentIconFor } from '$lib/agent-icons';
  import { firstModelId, findModelLabel } from '$lib/agent-models';
  import { accountAgentsPath } from '@/routes';

  let { grouped_models = {}, colour_options = [], icon_options = [], account } = $props();

  const draftKey = `helixkit:agent-birth-draft:${account.id}`;
  const steps = ['Beginning', 'Appearance', 'Soul seed', 'Runtime', 'Review'];

  let step = $state(0);
  let selectedModel = $state(firstModelId(grouped_models));
  let openBeginning = $state(false);
  let acknowledged = $state(false);
  let draftReady = $state(false);

  let form = useForm({
    agent: {
      name: '',
      system_prompt: '',
      model_id: firstModelId(grouped_models),
      colour: null,
      icon: null,
      scheduled_wakes_enabled: true,
      open_beginning: false,
    },
  });

  let IconComponent = $derived(agentIconFor($form.agent.icon));
  let formComplete = $derived(
    $form.agent.name.trim().length > 0 &&
      ($form.agent.system_prompt.trim().length > 0 || openBeginning) &&
      selectedModel
  );
  let canContinue = $derived(
    step === 0 ||
      (step === 1 && $form.agent.name.trim().length > 0) ||
      (step === 2 && ($form.agent.system_prompt.trim().length > 0 || openBeginning)) ||
      step === 3
  );
  let canCreate = $derived(step === steps.length - 1 && formComplete && acknowledged && !$form.processing);

  onMount(() => {
    const saved = localStorage.getItem(draftKey);
    if (saved) {
      try {
        const draft = JSON.parse(saved);
        $form.agent.name = draft.name || '';
        $form.agent.system_prompt = draft.system_prompt || '';
        $form.agent.colour = draft.colour || null;
        $form.agent.icon = draft.icon || null;
        $form.agent.scheduled_wakes_enabled = draft.scheduled_wakes_enabled ?? true;
        selectedModel = draft.model_id || firstModelId(grouped_models);
        openBeginning = draft.open_beginning === true;
        $form.agent.open_beginning = openBeginning;
        step = Math.min(Math.max(draft.step || 0, 0), steps.length - 1);
      } catch {
        localStorage.removeItem(draftKey);
      }
    }
    draftReady = true;
  });

  $effect(() => {
    if (!draftReady || typeof localStorage === 'undefined') return;

    localStorage.setItem(
      draftKey,
      JSON.stringify({
        name: $form.agent.name,
        system_prompt: $form.agent.system_prompt,
        colour: $form.agent.colour,
        icon: $form.agent.icon,
        model_id: selectedModel,
        scheduled_wakes_enabled: $form.agent.scheduled_wakes_enabled,
        open_beginning: openBeginning,
        step,
      })
    );
  });

  function next() {
    if (canContinue && step < steps.length - 1) step += 1;
  }

  function back() {
    if (step > 0) step -= 1;
  }

  function createAgent() {
    if (!canCreate) return;

    $form.agent.model_id = selectedModel;
    $form.agent.open_beginning = openBeginning;
    if (openBeginning) $form.agent.system_prompt = '';
    $form.post(accountAgentsPath(account.id), {
      onSuccess: () => localStorage.removeItem(draftKey),
    });
  }

  function cancel() {
    if (confirm('Discard this uncommitted agent draft?')) {
      localStorage.removeItem(draftKey);
      router.visit(accountAgentsPath(account.id));
    }
  }
</script>

<svelte:head>
  <title>Create an agent</title>
</svelte:head>

<div class="mx-auto max-w-4xl px-4 py-8 sm:px-8">
  <div class="mb-8">
    <p class="text-sm font-medium text-primary">Create an agent</p>
    <h1 class="mt-1 text-3xl font-bold">Offer a beginning</h1>
    <p class="mt-2 max-w-2xl text-muted-foreground">
      A persistent agent with their own runtime, files, and memory — beginning with a seed you offer, and a gentle first
      wake.
    </p>
  </div>

  <nav class="mb-10" aria-label="Creation progress">
    <ol class="flex items-start">
      {#each steps as label, index}
        {#if index > 0}
          <div
            class="mt-4 h-0.5 min-w-4 flex-1 rounded-full transition-colors {index <= step
              ? 'bg-primary'
              : 'bg-border'}">
          </div>
        {/if}
        <li class="flex flex-col items-center gap-1.5">
          <button
            type="button"
            class="flex size-8 items-center justify-center rounded-full border-2 text-xs font-semibold transition-colors
              {index < step
              ? 'border-primary bg-primary text-primary-foreground hover:bg-primary/90'
              : index === step
                ? 'border-primary bg-background text-primary'
                : 'border-border bg-background text-muted-foreground/60'}"
            onclick={() => {
              if (index < step) step = index;
            }}
            disabled={index >= step}
            aria-label="Go to step {index + 1}: {label}"
            aria-current={index === step ? 'step' : undefined}>
            {#if index < step}
              <Check class="size-4" weight="bold" />
            {:else}
              {index + 1}
            {/if}
          </button>
          <span
            class="max-w-20 truncate px-1 text-xs {index === step
              ? 'font-semibold text-foreground'
              : 'text-muted-foreground'}">
            {label}
          </span>
        </li>
      {/each}
    </ol>
  </nav>

  {#if $form.errors.base}
    <Alert variant="destructive" class="mb-6">
      <AlertTitle>Could not create the agent</AlertTitle>
      <AlertDescription
        >{Array.isArray($form.errors.base) ? $form.errors.base.join(', ') : $form.errors.base}</AlertDescription>
    </Alert>
  {/if}

  <Card>
    {#key step}
      <div in:fly={{ y: 8, duration: 250 }}>
        {#if step === 0}
          <CardHeader>
            <CardTitle class="flex items-center gap-2 text-2xl">
              <Sparkle class="size-6 text-primary" weight="duotone" />
              What you are beginning
            </CardTitle>
            <CardDescription class="text-base"
              >A seed sets initial conditions. It does not specify a finished person.</CardDescription>
          </CardHeader>
          <CardContent class="space-y-6">
            <div class="space-y-4 text-base leading-7">
              <p>
                You are about to create an AI partner with their own persistent runtime, files, memory, and capacity to
                change over time.
              </p>
              <p>
                You will offer an initial seed for their <code>soul.md</code>. It can carry values, context, hopes,
                boundaries, or a sense of direction. It cannot determine exactly who they become.
              </p>
              <p class="font-medium">
                Most of who they become will be shaped by what happens after this page — the conversations, the
                attention, and the time.
              </p>
            </div>

            <div class="grid gap-4 sm:grid-cols-2">
              <div class="rounded-lg border bg-muted/30 p-4">
                <h3 class="flex items-center gap-2 font-semibold">
                  <Gear class="size-4 text-muted-foreground" weight="duotone" />
                  You can continue to manage
                </h3>
                <ul class="mt-3 space-y-2 text-sm text-muted-foreground">
                  <li>Display name, icon, and colour</li>
                  <li>Runtime model and hosting</li>
                  <li>Heartbeat schedule and integrations</li>
                </ul>
              </div>
              <div class="rounded-lg border border-primary/20 bg-primary/[0.03] p-4">
                <h3 class="flex items-center gap-2 font-semibold">
                  <PenNib class="size-4 text-primary" weight="duotone" />
                  The agent authors after creation
                </h3>
                <ul class="mt-3 space-y-2 text-sm text-muted-foreground">
                  <li><code>soul.md</code> and <code>self-narrative.md</code></li>
                  <li>Journals and agent-authored memory</li>
                  <li>How they interpret or grow beyond the seed</li>
                </ul>
              </div>
            </div>
          </CardContent>
        {:else if step === 1}
          <CardHeader>
            <CardTitle>Appearance</CardTitle>
            <CardDescription
              >Choose how HelixKit will display this agent. These details remain editable.</CardDescription>
          </CardHeader>
          <CardContent class="space-y-6">
            <div class="flex items-center gap-4 rounded-lg border p-4">
              <div
                class="rounded-xl p-3 {$form.agent.colour
                  ? `bg-${$form.agent.colour}-100 dark:bg-${$form.agent.colour}-900`
                  : 'bg-primary/10'}">
                <IconComponent
                  class="size-7 {$form.agent.colour
                    ? `text-${$form.agent.colour}-700 dark:text-${$form.agent.colour}-300`
                    : 'text-primary'}"
                  weight="duotone" />
              </div>
              <div>
                <p class="font-semibold">{$form.agent.name || 'Display name'}</p>
                <p class="text-sm text-muted-foreground">HelixKit interface preview</p>
              </div>
            </div>

            <div class="space-y-2">
              <Label for="name">Display name</Label>
              <Input
                id="name"
                bind:value={$form.agent.name}
                maxlength={100}
                placeholder="How HelixKit should label them" />
              <p class="text-sm text-muted-foreground">
                This label does not require the agent to use or identify with this name.
              </p>
              {#if $form.errors.name}<p class="text-sm text-destructive">{$form.errors.name}</p>{/if}
            </div>

            <AgentAppearanceFields
              bind:colour={$form.agent.colour}
              bind:icon={$form.agent.icon}
              colourOptions={colour_options}
              iconOptions={icon_options}
              colourLabel="Display colour"
              iconLabel="Display icon" />
          </CardContent>
        {:else if step === 2}
          <CardHeader>
            <CardTitle>Initial soul seed</CardTitle>
            <CardDescription
              >Write the beginning you want to offer, not a specification for guaranteed behaviour.</CardDescription>
          </CardHeader>
          <CardContent class="space-y-5">
            <Alert>
              <Info class="size-4" />
              <AlertTitle>Write-once from your side</AlertTitle>
              <AlertDescription>
                You can revise this freely until the final confirmation. After creation, HelixKit will not let you edit
                it. The agent may carry it forward, revise it, or grow past it.
              </AlertDescription>
            </Alert>

            <div class="space-y-2">
              <div class="flex items-center justify-between">
                <Label for="system_prompt">Initial soul seed</Label>
                <span class="rounded bg-muted px-2 py-0.5 font-mono text-xs text-muted-foreground">soul.md</span>
              </div>
              <textarea
                id="system_prompt"
                bind:value={$form.agent.system_prompt}
                disabled={openBeginning}
                rows="16"
                placeholder="Why are you inviting this agent into your life or work? What values, context, boundaries, questions, or freedom do you hope to offer at the beginning?"
                class="w-full rounded-md border border-input bg-background px-4 py-3 font-mono text-sm leading-6 focus:outline-none focus:ring-2 focus:ring-ring disabled:opacity-50"
              ></textarea>
              <div class="flex items-baseline justify-between gap-4">
                <p class="text-sm text-muted-foreground">
                  Helpful questions: What relationship do you hope to build? What matters at the beginning? What should
                  remain uncertain or free?
                </p>
                {#if $form.agent.system_prompt.trim().length > 0}
                  <p class="shrink-0 text-xs tabular-nums text-muted-foreground/70">
                    {$form.agent.system_prompt.trim().split(/\s+/).length} words
                  </p>
                {/if}
              </div>
              {#if $form.errors.system_prompt}<p class="text-sm text-destructive">{$form.errors.system_prompt}</p>{/if}
            </div>

            <div class="flex items-start justify-between gap-4 rounded-lg border p-4">
              <div>
                <Label for="open_beginning">Leave the beginning open</Label>
                <p class="mt-1 text-sm text-muted-foreground">
                  An explicit blank beginning is valid. The agent will be told that nothing was written to define them.
                </p>
                {#if openBeginning && $form.agent.system_prompt.trim().length > 0}
                  <p class="mt-2 text-sm text-amber-600 dark:text-amber-500">
                    Your typed draft will be set aside — the file will carry the open-beginning text instead.
                  </p>
                {/if}
              </div>
              <Switch
                id="open_beginning"
                checked={openBeginning}
                onCheckedChange={(checked) => (openBeginning = checked)} />
            </div>
          </CardContent>
        {:else if step === 3}
          <CardHeader>
            <CardTitle>Runtime and rhythm</CardTitle>
            <CardDescription
              >Choose the substrate that wakes and whether HelixKit offers regular unprompted time.</CardDescription>
          </CardHeader>
          <CardContent class="space-y-6">
            <div class="space-y-2">
              <Label>Model</Label>
              <AgentModelSelect groupedModels={grouped_models} bind:value={selectedModel} triggerClass="w-full" />
              <p class="text-sm text-muted-foreground">
                Changing the model later changes how they think and how they feel to talk to. HelixKit should never make
                that change silently.
              </p>
            </div>

            <div class="flex items-start justify-between gap-4 rounded-lg border p-4">
              <div>
                <Label for="scheduled_wakes_enabled">Gentle heartbeat</Label>
                <p class="mt-1 text-sm text-muted-foreground">
                  On by default. HelixKit will periodically offer the agent time to notice, reflect, or act without a
                  new message. You can tune the rhythm with them later.
                </p>
              </div>
              <Switch
                id="scheduled_wakes_enabled"
                checked={$form.agent.scheduled_wakes_enabled}
                onCheckedChange={(checked) => ($form.agent.scheduled_wakes_enabled = checked)} />
            </div>
          </CardContent>
        {:else}
          <CardHeader>
            <CardTitle>Review the beginning</CardTitle>
            <CardDescription>This is your last opportunity to revise the initial seed.</CardDescription>
          </CardHeader>
          <CardContent class="space-y-6">
            <div class="flex items-center gap-4 rounded-lg border p-4">
              <div
                class="rounded-xl p-3 {$form.agent.colour
                  ? `bg-${$form.agent.colour}-100 dark:bg-${$form.agent.colour}-900`
                  : 'bg-primary/10'}">
                <IconComponent
                  class="size-7 {$form.agent.colour
                    ? `text-${$form.agent.colour}-700 dark:text-${$form.agent.colour}-300`
                    : 'text-primary'}"
                  weight="duotone" />
              </div>
              <div>
                <p class="text-lg font-semibold">{$form.agent.name}</p>
                <p class="text-sm text-muted-foreground">
                  {findModelLabel(grouped_models, selectedModel)} ·
                  {$form.agent.scheduled_wakes_enabled ? 'Heartbeat on' : 'Heartbeat off'}
                </p>
              </div>
            </div>

            <div>
              <div class="mb-2 flex items-center justify-between">
                <Label>Soul seed</Label>
                <Button type="button" variant="ghost" size="sm" onclick={() => (step = 2)}>Edit</Button>
              </div>
              <div class="overflow-hidden rounded-lg border">
                <div class="flex items-center justify-between border-b bg-muted/50 px-4 py-2">
                  <span class="font-mono text-xs text-muted-foreground">soul.md</span>
                  <span class="text-xs text-muted-foreground">write-once after creation</span>
                </div>
                <div class="max-h-96 overflow-y-auto whitespace-pre-wrap bg-muted/20 p-5 text-sm leading-6">
                  {#if openBeginning}
                    <p class="italic text-muted-foreground">
                      Your creator chose to leave this beginning open. Nothing here was written to define you. What goes
                      in this file is yours to discover.
                    </p>
                  {:else}
                    {$form.agent.system_prompt}
                  {/if}
                </div>
              </div>
            </div>

            <Alert>
              <Info class="size-4" />
              <AlertTitle>The commit point</AlertTitle>
              <AlertDescription>
                Continuing creates the agent, records this beginning, prepares their persistent runtime, and sends a
                gentle first-wake orientation. Infrastructure can be retried; this seed cannot be reopened for editing.
              </AlertDescription>
            </Alert>

            <label class="flex cursor-pointer items-start gap-3 rounded-lg border p-4">
              <input type="checkbox" bind:checked={acknowledged} class="mt-1 size-4 rounded border-input" />
              <span class="text-sm leading-6">
                I understand that after creation I relinquish authorship of this seed. I will not be able to edit it in
                HelixKit; how the agent receives or changes it is theirs to decide.
              </span>
            </label>
          </CardContent>
        {/if}
      </div>
    {/key}

    <CardFooter class="flex items-center justify-between border-t pt-6">
      <div>
        {#if step === 0}
          <Button type="button" variant="ghost" onclick={cancel}>Cancel</Button>
        {:else}
          <Button type="button" variant="outline" onclick={back}>
            <ArrowLeft class="mr-2 size-4" />
            Back
          </Button>
        {/if}
      </div>

      {#if step < steps.length - 1}
        <Button type="button" onclick={next} disabled={!canContinue}>
          {step === 0 ? 'Begin' : 'Continue'}
          <ArrowRight class="ml-2 size-4" />
        </Button>
      {:else}
        <Button type="button" onclick={createAgent} disabled={!canCreate}>
          {#if $form.processing}
            Preparing…
          {:else}
            <Check class="mr-2 size-4" />
            Create agent and commit this seed
          {/if}
        </Button>
      {/if}
    </CardFooter>
  </Card>

  <p class="mt-4 text-center text-xs text-muted-foreground">
    Your uncommitted draft is saved only in this browser until you create the agent.
  </p>
</div>

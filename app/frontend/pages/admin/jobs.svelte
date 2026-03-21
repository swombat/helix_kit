<script>
  import { router } from '@inertiajs/svelte';
  import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '$lib/components/shadcn/card';
  import { Button } from '$lib/components/shadcn/button';
  import { Play } from 'phosphor-svelte';

  let { jobs = [], flash = {} } = $props();
  let running = $state({});

  function runJob(key) {
    running[key] = true;
    router.post(
      '/admin/jobs',
      { job_key: key },
      {
        onFinish: () => {
          running[key] = false;
        },
      }
    );
  }
</script>

<div class="container mx-auto max-w-2xl py-8 px-4">
  <h1 class="text-2xl font-bold mb-6">Background Jobs</h1>

  {#if flash?.notice}
    <div class="mb-4 rounded-md bg-green-50 dark:bg-green-950 p-3 text-sm text-green-700 dark:text-green-300">
      {flash.notice}
    </div>
  {/if}

  {#if flash?.alert}
    <div class="mb-4 rounded-md bg-red-50 dark:bg-red-950 p-3 text-sm text-red-700 dark:text-red-300">
      {flash.alert}
    </div>
  {/if}

  <div class="space-y-4">
    {#each jobs as job}
      <Card>
        <CardHeader class="pb-3">
          <div class="flex items-center justify-between">
            <CardTitle class="text-base">{job.name}</CardTitle>
            <Button variant="outline" size="sm" disabled={running[job.key]} onclick={() => runJob(job.key)}>
              <Play class="mr-1.5 size-3.5" weight="fill" />
              {running[job.key] ? 'Queued...' : 'Run'}
            </Button>
          </div>
          <CardDescription>{job.description}</CardDescription>
        </CardHeader>
      </Card>
    {/each}
  </div>
</div>

<script>
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Input } from '$lib/components/shadcn/input/index.js';

  let { name = $bindable(''), onSubmit } = $props();
</script>

<div class="mb-6 p-4 border rounded-lg">
  <form
    onsubmit={(event) => {
      event.preventDefault();
      onSubmit();
    }}
    class="flex gap-2">
    <Input bind:value={name} placeholder="Key name (e.g., Claude Code)" class="flex-1" />
    <Button type="submit">Create</Button>
  </form>
</div>

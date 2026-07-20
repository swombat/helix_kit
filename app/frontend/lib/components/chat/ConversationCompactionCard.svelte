<script>
  import { Archive } from 'phosphor-svelte';
  import { Streamdown } from 'svelte-streamdown';
  import MessageTelemetry from '$lib/components/chat/MessageTelemetry.svelte';

  let { compaction, showMessageTelemetry = false, shikiTheme = 'catppuccin-latte' } = $props();
</script>

<div class="flex justify-center py-1">
  <div class="w-full max-w-2xl">
    <details class="group rounded-lg border border-dashed border-border bg-muted/30 px-4 py-3">
      <summary
        class="flex cursor-pointer list-none items-center gap-2 text-sm text-muted-foreground hover:text-foreground
               [&::-webkit-details-marker]:hidden">
        <Archive size={18} weight="duotone" aria-hidden="true" />
        <span class="font-medium">Earlier conversation compacted</span>
        <span class="text-xs">· {compaction.compacted_message_count} messages</span>
        <span class="ml-auto text-xs transition-transform group-open:rotate-180">⌄</span>
      </summary>

      <div class="mt-3 border-t border-border/60 pt-3">
        <p class="mb-3 text-xs leading-relaxed text-muted-foreground">
          To keep long conversations responsive and affordable, HelixKit replaced earlier messages in the agent’s active
          context with the summary below. The original messages remain stored and the agent can retrieve their exact
          text with a tool when needed.
        </p>
        <div class="rounded-md bg-background/70 p-3">
          <Streamdown
            content={compaction.summary}
            parseIncompleteMarkdown={false}
            baseTheme="shadcn"
            {shikiTheme}
            shikiPreloadThemes={['catppuccin-latte', 'catppuccin-mocha']}
            class="prose prose-sm" />
        </div>
      </div>
    </details>
    {#if showMessageTelemetry && compaction.ruby_llm_telemetry}
      <div class="mt-1 flex">
        <MessageTelemetry telemetry={compaction.ruby_llm_telemetry} />
      </div>
    {/if}
  </div>
</div>

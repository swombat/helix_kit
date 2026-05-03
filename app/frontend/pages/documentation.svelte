<script>
  import DocumentationQuickNavigation from '$lib/components/documentation/DocumentationQuickNavigation.svelte';
  import RealtimeSyncDocumentation from '$lib/components/documentation/RealtimeSyncDocumentation.svelte';
  import JsonAttributesDocumentation from '$lib/components/documentation/JsonAttributesDocumentation.svelte';
  import PromptSystemDocumentation from '$lib/components/documentation/PromptSystemDocumentation.svelte';
</script>

<div class="container mx-auto py-8 px-4 max-w-5xl">
  <h1 class="text-4xl font-bold mb-2">Documentation</h1>
  <p class="text-muted-foreground mb-8">Learn how to use the features of this application</p>

  <DocumentationQuickNavigation />

  <RealtimeSyncDocumentation />

  <JsonAttributesDocumentation />

  <PromptSystemDocumentation />
</div>

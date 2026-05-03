<script>
  import AgentPickerDialog from '$lib/components/chat/AgentPickerDialog.svelte';
  import WhiteboardDrawer from '$lib/components/chat/WhiteboardDrawer.svelte';
  import EditMessageDrawer from '$lib/components/chat/EditMessageDrawer.svelte';
  import ImageLightbox from '$lib/components/chat/ImageLightbox.svelte';
  import ToastNotification from '$lib/components/chat/ToastNotification.svelte';

  let {
    chat,
    account,
    availableAgents = [],
    addableAgents = [],
    shikiTheme,
    agentIsResponding = false,
    whiteboardOpen = $bindable(false),
    editDrawerOpen = $bindable(false),
    editingMessageId = null,
    editingContent = '',
    errorMessage = null,
    successMessage = null,
    assignAgentOpen = $bindable(false),
    assigningAgent = false,
    addAgentOpen = $bindable(false),
    addAgentProcessing = false,
    lightboxOpen = $bindable(false),
    lightboxImage = null,
    onEditSaved = () => {},
    onError = () => {},
    onAssignAgent = () => {},
    onAddAgent = () => {},
  } = $props();
</script>

{#if chat?.active_whiteboard}
  <WhiteboardDrawer
    bind:open={whiteboardOpen}
    whiteboard={chat.active_whiteboard}
    accountId={account.id}
    {agentIsResponding}
    {shikiTheme} />
{/if}

<EditMessageDrawer
  bind:open={editDrawerOpen}
  messageId={editingMessageId}
  initialContent={editingContent}
  onsaved={onEditSaved}
  onerror={onError} />

<ToastNotification message={errorMessage} variant="error" />
<ToastNotification message={successMessage} variant="success" />

<AgentPickerDialog
  bind:open={assignAgentOpen}
  agents={availableAgents}
  title="Assign to Agent"
  description="Select an agent to take over this conversation. The agent will be informed that previous messages were with a model that had no identity or memories."
  confirmLabel="Assign"
  confirmingLabel="Assigning..."
  processing={assigningAgent}
  onconfirm={onAssignAgent} />

<AgentPickerDialog
  bind:open={addAgentOpen}
  agents={addableAgents}
  title="Add Agent to Conversation"
  description="Select an agent to add to this group chat."
  confirmLabel="Add"
  confirmingLabel="Adding..."
  processing={addAgentProcessing}
  onconfirm={onAddAgent} />

<ImageLightbox bind:open={lightboxOpen} file={lightboxImage} />

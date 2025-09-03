<script>
  import { router } from '@inertiajs/svelte';
  import Avatar from './Avatar.svelte';
  import * as Dialog from '$lib/components/shadcn/dialog/index.js';
  import Button from '$lib/components/shadcn/button/button.svelte';
  import Input from '$lib/components/shadcn/input/input.svelte';
  import Label from '$lib/components/shadcn/label/label.svelte';

  let { user, onUpdate = () => {} } = $props();

  console.log('AvatarUpload', user);

  $effect(() => {
    console.log('AvatarUpload effect', user);
  });

  let dialogOpen = $state(false);
  let fileInput;
  let uploading = $state(false);
  let error = $state(null);

  function openDialog() {
    dialogOpen = true;
    error = null;
  }

  function closeDialog() {
    dialogOpen = false;
    error = null;
    if (fileInput) {
      fileInput.value = '';
    }
  }

  async function handleFileSelect(event) {
    const file = event.target.files[0];
    if (!file) return;

    // Validate file
    if (!file.type.startsWith('image/')) {
      error = 'Please select an image file';
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      error = 'File too large. Maximum size is 5MB';
      return;
    }

    error = null;
    uploading = true;

    // Create FormData for avatar upload
    const formData = new FormData();
    formData.append('user[avatar]', file);

    try {
      // Upload avatar to user endpoint
      router.patch('/user', formData, {
        onSuccess: () => {
          onUpdate();
          closeDialog();
        },
        onError: (errors) => {
          error = errors.avatar ? errors.avatar[0] : 'Upload failed. Please try again.';
        },
        onFinish: () => {
          uploading = false;
        },
      });
    } catch (err) {
      error = 'Upload failed. Please try again.';
      uploading = false;
    }
  }

  async function handleDeleteAvatar() {
    if (!user?.avatar_url) return;

    uploading = true;
    error = null;

    try {
      // Delete avatar
      router.delete('/user/avatar', {
        onSuccess: () => {
          onUpdate();
          closeDialog();
        },
        onError: (errors) => {
          error = 'Failed to delete avatar. Please try again.';
        },
        onFinish: () => {
          uploading = false;
        },
      });
    } catch (err) {
      error = 'Failed to delete avatar. Please try again.';
      uploading = false;
    }
  }
</script>

<!-- Avatar with click to open dialog -->
<div class="relative group">
  <Avatar
    {user}
    size="xl"
    class="cursor-pointer hover:opacity-80 transition-opacity outline-ring outline-4 outline-solid outline-offset-4"
    onClick={openDialog} />
</div>

<!-- Upload Dialog -->
<Dialog.Root bind:open={dialogOpen}>
  <Dialog.Content class="sm:max-w-md">
    <Dialog.Header>
      <Dialog.Title>Update Avatar</Dialog.Title>
      <Dialog.Description>Upload a new profile picture or remove your current one.</Dialog.Description>
    </Dialog.Header>

    <div class="py-4">
      <!-- Current avatar preview -->
      <div class="flex justify-center mb-6">
        <Avatar {user} size="large" />
      </div>

      <!-- File input -->
      <div class="space-y-4">
        <div>
          <Label for="avatar-upload">Choose New Avatar</Label>
          <Input
            bind:this={fileInput}
            id="avatar-upload"
            type="file"
            accept="image/*"
            onchange={handleFileSelect}
            disabled={uploading}
            class="mt-1" />
          <p class="text-sm text-muted-foreground mt-1">Supported formats: PNG, JPG, JPEG, GIF (max 5MB)</p>
        </div>

        {#if error}
          <div class="bg-destructive/15 text-destructive px-3 py-2 rounded-md text-sm">
            {error}
          </div>
        {/if}
      </div>
    </div>

    <Dialog.Footer class="flex-col sm:flex-row space-y-2 sm:space-y-0 sm:space-x-2">
      <!-- Delete button (only if user has avatar) -->
      {#if user?.avatar_url}
        <Button variant="destructive" onclick={handleDeleteAvatar} disabled={uploading} class="w-full sm:w-auto">
          {uploading ? 'Deleting...' : 'Delete Avatar'}
        </Button>
      {/if}

      <!-- Cancel button -->
      <Button variant="outline" onclick={closeDialog} disabled={uploading} class="w-full sm:w-auto">Cancel</Button>
    </Dialog.Footer>
  </Dialog.Content>
</Dialog.Root>

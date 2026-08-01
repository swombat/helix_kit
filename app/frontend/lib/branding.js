import { page } from '@inertiajs/svelte';
import { derived } from 'svelte/store';

// Single source of the outward-facing site name.
// Governed by Setting#site_name (shared to every page as `site_settings`
// via Inertia and live-updated by the Broadcastable sync); this constant is
// only the fallback for pages rendered before the share resolves.
export const DEFAULT_SITE_NAME = 'souls.house';

export const siteName = derived(page, ($page) => $page?.props?.site_settings?.site_name || DEFAULT_SITE_NAME);

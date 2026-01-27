import { createConsumer } from '@rails/actioncable';
import { router } from '@inertiajs/svelte';
import * as logging from '$lib/logging';

// Check if we're in browser environment
const browser = typeof window !== 'undefined';

// Create consumer once
const consumer = browser ? createConsumer() : null;

// Pure debounce function
function debounce(fn, delay) {
  let timeoutId;
  let pendingProps = new Set();

  return (props) => {
    // Accumulate props
    props.forEach((prop) => pendingProps.add(prop));

    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => {
      if (pendingProps.size > 0) {
        fn(Array.from(pendingProps));
        pendingProps.clear();
      }
    }, delay);
  };
}

// Global debounced reload (shared across all subscriptions)
const reloadProps = debounce((props) => {
  logging.debug('Reloading props:', props);
  router.reload({
    only: props,
    preserveState: true,
    preserveScroll: true,
  });
}, 300);

/**
 * Internal function to subscribe to model updates
 * @private
 */
export function subscribeToModel(model, id, props) {
  if (!browser || !consumer) return () => {};

  const subscription = consumer.subscriptions.create(
    {
      channel: 'SyncChannel',
      model,
      id,
    },
    {
      connected() {
        logging.debug(`Sync connected: ${model}:${id}`);
      },

      received(data) {
        logging.debug(`Sync received: ${model}:${id}`, data);

        // Handle streaming updates specially - don't reload, just update in place
        if (handleStreamingUpdate(data)) {
          return;
        }

        // Use explicit prop from server or fallback to provided props
        // const propsToReload = data.prop ? [data.prop] : props;
        reloadProps(props);
      },

      disconnected() {
        logging.debug(`Sync disconnected: ${model}:${id}`);
      },
    }
  );

  return () => subscription.unsubscribe();
}

function handleStreamingUpdate(data) {
  if (data.action === 'streaming_update') {
    // Dispatch a custom event that the chat component can listen to
    if (browser) {
      window.dispatchEvent(new CustomEvent('streaming-update', { detail: data }));
    }
    return true;
  } else if (data.action === 'streaming_end') {
    // Dispatch a custom event that the chat component can listen to
    if (browser) {
      window.dispatchEvent(new CustomEvent('streaming-end', { detail: data }));
    }
    return true;
  } else if (data.action === 'debug_log') {
    // Dispatch debug log event for site admins
    if (browser) {
      window.dispatchEvent(new CustomEvent('debug-log', { detail: data }));
    }
    return true;
  }
}

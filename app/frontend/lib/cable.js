import { createConsumer } from '@rails/actioncable';
import { router } from '@inertiajs/svelte';

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
  console.log('Reloading props:', props);
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
  if (!browser || !consumer) return () => { };

  const subscription = consumer.subscriptions.create(
    {
      channel: 'SyncChannel',
      model,
      id,
    },
    {
      connected() {
        console.log(`Sync connected: ${model}:${id}`);
      },

      received(data) {
        console.log(`Sync received: ${model}:${id}`, data);

        // Use explicit prop from server or fallback to provided props
        // const propsToReload = data.prop ? [data.prop] : props;
        reloadProps(props);
      },

      disconnected() {
        console.log(`Sync disconnected: ${model}:${id}`);
      },
    }
  );

  return () => subscription.unsubscribe();
}

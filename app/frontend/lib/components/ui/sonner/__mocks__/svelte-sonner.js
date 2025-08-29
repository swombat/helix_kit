import { vi } from 'vitest';

export const Toaster = {
  name: 'MockedToaster',
  render: () => {
    const div = document.createElement('div');
    div.setAttribute('data-sonner-toaster', 'true');
    document.body.appendChild(div);
    return {
      destroy: () => {
        if (div.parentNode) {
          div.parentNode.removeChild(div);
        }
      }
    };
  }
};

export const toast = vi.fn();
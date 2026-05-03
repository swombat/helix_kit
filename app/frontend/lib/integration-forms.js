export function submitNativePost(path) {
  const form = document.createElement('form');
  form.method = 'POST';
  form.action = path;

  const csrf = document.createElement('input');
  csrf.type = 'hidden';
  csrf.name = 'authenticity_token';
  csrf.value = document.querySelector('meta[name="csrf-token"]')?.content || '';

  form.appendChild(csrf);
  document.body.appendChild(form);
  form.submit();
}

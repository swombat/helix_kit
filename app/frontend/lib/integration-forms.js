export function submitNativePost(path, data = {}) {
  const form = document.createElement('form');
  form.method = 'POST';
  form.action = path;

  const csrf = document.createElement('input');
  csrf.type = 'hidden';
  csrf.name = 'authenticity_token';
  csrf.value = document.querySelector('meta[name="csrf-token"]')?.content || '';

  form.appendChild(csrf);
  for (const [name, value] of Object.entries(data)) {
    const input = document.createElement('input');
    input.type = 'hidden';
    input.name = name;
    input.value = value ?? '';
    form.appendChild(input);
  }
  document.body.appendChild(form);
  form.submit();
}

<script>
  import Highlight from 'svelte-highlight';
  import javascript from 'svelte-highlight/languages/javascript';
  import ruby from 'svelte-highlight/languages/ruby';
  import 'svelte-highlight/styles/atom-one-dark.css';

  const languages = { javascript, ruby };

  let { code, language = 'ruby' } = $props();
</script>

<Highlight language={languages[language] || ruby} {code} />

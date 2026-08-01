<script>
  import logoSrc from '../../../../assets/images/souls-house-logo.svg?raw';
  let props = $props();

  // Extract props for the SVG element
  const { width = 84, height = 84, class: className = '', ...restProps } = props;

  // Convert restProps to HTML attributes
  const restAttributes = Object.entries(restProps)
    .map(([key, value]) => `${key}="${value}"`)
    .join(' ');
</script>

{@html logoSrc.replace('<svg', `<svg width="${width}" height="${height}" class="${className}" ${restAttributes}`)}

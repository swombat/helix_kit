# Phosphor Icons Documentation

This document provides a comprehensive list of all 1512 Phosphor icons available in the `phosphor-svelte` package, along with alternative names and descriptions to make searching easier.

## How to Use This Documentation

### Finding Icons

Use `grep` or `ripgrep` to search for icons by their name or alternative descriptions:

```bash
# Using ripgrep (recommended - faster)
rg -i "trash" docs/icons.md

# Using grep
grep -i "trash" docs/icons.md

# Find all arrow-related icons
rg -i "arrow\|direction\|pointer" docs/icons.md

# Find all user/person icons
rg -i "user\|person\|people\|avatar\|profile" docs/icons.md
```

### Importing Icons in Svelte

Icons follow PascalCase naming when importing:

```svelte
<script>
  // Single word icon: kebab-case 'trash' becomes PascalCase 'Trash'
  import { Trash } from 'phosphor-svelte';
  
  // Multi-word icon: kebab-case 'trash-simple' becomes PascalCase 'TrashSimple'
  import { TrashSimple } from 'phosphor-svelte';
  
  // Icons with numbers: 'number-one' becomes 'NumberOne'
  import { NumberOne } from 'phosphor-svelte';
</script>

<Trash size={24} weight="regular" />
<TrashSimple size={32} weight="bold" class="text-red-200 dark:text-red-800" />
```

### Icon Properties

All icons accept the following props:
- `size` - Icon size (number or string with units)
- `weight` - Style variant: "thin" | "light" | "regular" | "bold" | "fill" | "duotone"
- `color` - Do not use this prop, use `class` instead
- `class` - Additional CSS classes, specify colors here, including dark mode colors
- `mirrored` - Boolean to flip the icon horizontally

## Complete Icon List

The icons are listed in alphabetical order with their kebab-case name in `icons-all.md`, PascalCase import name, and searchable descriptions including alternative names.

---

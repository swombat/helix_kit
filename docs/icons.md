# Phosphor Icons Quick Reference

This project uses `phosphor-svelte` for icons. There are **1,512 icons** available.

## Finding Icons

The complete searchable list is in `docs/icons-all.md`. Use `ripgrep` (rg) or `grep` to search:

```bash
# Find trash/delete icons
rg -i "trash\|delete\|remove" docs/icons-all.md

# Find user/person icons  
rg -i "user\|person\|avatar\|profile" docs/icons-all.md

# Find arrow/direction icons
rg -i "arrow\|direction\|point" docs/icons-all.md

# Find social media icons
rg -i "twitter\|facebook\|instagram\|social" docs/icons-all.md
```

## Using Icons in Svelte

```svelte
<script>
  // Import icons using PascalCase
  import { Trash, User, ArrowRight } from 'phosphor-svelte';
  
  // Multi-word icons: kebab-case becomes PascalCase
  // trash-simple → TrashSimple
  // arrow-down-left → ArrowDownLeft
  import { TrashSimple, ArrowDownLeft } from 'phosphor-svelte';
</script>

<!-- Basic usage -->
<Trash />

<!-- With Tailwind classes (recommended) -->
<User size={32} weight="bold" class="text-red-500 dark:text-red-400" />

<!-- Available weights: thin, light, regular, bold, fill, duotone -->
<ArrowRight size={24} weight="duotone" />
```

## Icon Props

- `size` - Size in pixels (number or string with units)
- `weight` - Style: "thin" | "light" | "regular" | "bold" | "fill" | "duotone"  
- `class` - Tailwind classes for styling (use instead of `color` prop)
- `mirrored` - Boolean to flip horizontally

## Common Icon Categories

- **Navigation**: arrow-*, caret-*, chevron-*
- **Actions**: plus, minus, x, check, trash, download, upload
- **Users**: user, users, person-*
- **Communication**: chat-*, envelope, phone, bell
- **Media**: play, pause, camera, image, video
- **Files**: file-*, folder-*, document
- **System**: gear, settings, warning, info, question
- **Social**: Brand logos ending in -logo

## Examples

```bash
# Find all file type icons
rg "^file-" docs/icons-all.md

# Find all brand logos
rg "\-logo:" docs/icons-all.md

# Find icons with "simple" variants
rg "\-simple:" docs/icons-all.md
```

## Full Documentation

For the complete searchable list with descriptions, see [`docs/icons-all.md`](./icons-all.md)
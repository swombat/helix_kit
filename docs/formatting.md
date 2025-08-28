# Code Formatting with Prettier

This project uses Prettier with the Svelte plugin to automatically format Svelte, JavaScript, and CSS files.

## Configuration

The formatting rules are defined in `.prettierrc`:

```json
{
  "plugins": ["prettier-plugin-svelte"],
  "bracketSameLine": true,
  "printWidth": 80,
  "tabWidth": 2,
  "useTabs": false,
  "semi": true,
  "singleQuote": true,
  "trailingComma": "es5"
}
```

### Key Settings

- **`bracketSameLine: true`**: This allows component attributes to stay on the same line as the opening tag, which is what you wanted for the Sun and Moon components.
- **`printWidth: 80`**: Maximum line length before wrapping
- **`tabWidth: 2`**: Use 2 spaces for indentation
- **`singleQuote: true`**: Use single quotes instead of double quotes

## Usage

### Format all files
```bash
npm run format
```

### Check formatting without changing files
```bash
npm run format:check
```

### Format a specific file
```bash
npx prettier --write path/to/file.svelte
```

## What This Fixes

The main issue you were experiencing was that the Svelte extension in Cursor was automatically formatting your components like this:

```svelte
<Sun
  class="h-[1.2rem] w-[1.2rem] rotate-0 scale-100 !transition-all dark:-rotate-90 dark:scale-0"
/>
```

With the new configuration, it will now format them like this:

```svelte
<Sun class="h-[1.2rem] w-[1.2rem] rotate-0 scale-100 !transition-all dark:-rotate-90 dark:scale-0" />
```

## Auto-formatting in Cursor

The Svelte extension in Cursor will now use these Prettier rules when auto-formatting your Svelte files. You can:

1. **Format on Save**: Enable this in Cursor settings
2. **Format on Paste**: This should also respect the new rules
3. **Manual Formatting**: Use `Cmd+Shift+P` → "Format Document"

## Files Ignored

The `.prettierignore` file excludes:
- Ruby files (`.rb`, `.erb`)
- Build outputs and dependencies
- Database files
- Log files
- Environment files

## Dependencies

- `prettier`: The core formatting tool
- `prettier-plugin-svelte`: Plugin for Svelte-specific formatting rules

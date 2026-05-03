export function formatToolsUsed(toolsUsed) {
  if (!toolsUsed || toolsUsed.length === 0) return [];

  return toolsUsed.map((tool) => {
    if (tool.startsWith('#<')) return 'Web access';

    try {
      return new URL(tool).hostname;
    } catch {
      return tool;
    }
  });
}

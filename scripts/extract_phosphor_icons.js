#!/usr/bin/env node

import { icons } from '@phosphor-icons/core';
import fs from 'fs';
import path from 'path';

// Extract all icon names and format them
const iconList = icons
  .map((icon) => ({
    kebab: icon.name,
    pascal: icon.pascal_name,
    categories: icon.categories || [],
    tags: icon.tags || [],
  }))
  .sort((a, b) => a.kebab.localeCompare(b.kebab));

// Output the list as JSON for further processing
const outputPath = path.join(process.cwd(), 'phosphor_icons_data.json');
fs.writeFileSync(outputPath, JSON.stringify(iconList, null, 2));

console.log(`Extracted ${iconList.length} icons to phosphor_icons_data.json`);

// Also output a simple list to console for quick reference
console.log('\nAll Phosphor Icons (kebab-case):');
console.log('================================');
iconList.forEach((icon) => {
  console.log(icon.kebab);
});

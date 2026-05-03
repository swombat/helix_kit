export function flattenGroupedModels(groupedModels = {}) {
  return Object.values(groupedModels).flat();
}

export function firstModelId(groupedModels = {}, fallback = 'openrouter/auto') {
  return flattenGroupedModels(groupedModels)[0]?.model_id ?? fallback;
}

export function findModel(groupedModels = {}, modelId) {
  return flattenGroupedModels(groupedModels).find((model) => model.model_id === modelId) || null;
}

export function findModelLabel(groupedModels = {}, modelId) {
  return findModel(groupedModels, modelId)?.label || modelId;
}

export function modelSupportsThinking(groupedModels = {}, modelId) {
  return findModel(groupedModels, modelId)?.supports_thinking === true;
}

export function groupModelsByProvider(models = []) {
  const groups = {};
  const groupOrder = [];

  for (const model of models) {
    const group = model.group || 'Other';
    if (!groups[group]) {
      groups[group] = [];
      groupOrder.push(group);
    }
    groups[group].push(model);
  }

  return { groups, groupOrder };
}

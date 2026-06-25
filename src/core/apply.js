import { collectExistingTriggers, mergeStarterRules } from "./config.js";
import { detectConflicts } from "./conflicts.js";
import { rulesForPresetIds, unknownPresetIds } from "./presets.js";

export function planPresetApplication(config, presetIds) {
  const unknownIds = unknownPresetIds(presetIds);
  if (unknownIds.length > 0) {
    return {
      ok: false,
      changed: false,
      config: null,
      conflicts: [],
      unknownPresetIds: unknownIds,
    };
  }

  const selectedRules = rulesForPresetIds(presetIds);
  const conflicts = detectConflicts({
    selectedRules,
    existingTriggers: collectExistingTriggers(config),
  });

  if (conflicts.length > 0) {
    return {
      ok: false,
      changed: false,
      config: null,
      conflicts,
      unknownPresetIds: [],
    };
  }

  const mergeResult = mergeStarterRules(config, selectedRules);

  return {
    ok: true,
    changed: mergeResult.changed,
    config: mergeResult.config,
    conflicts: [],
    unknownPresetIds: [],
  };
}

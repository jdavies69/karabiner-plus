import {
  STARTER_CUSTOM_PREFIX,
  collectExistingTriggers,
  mergeOwnedRules,
  mergeStarterRules,
} from "./config.js";
import { detectConflicts } from "./conflicts.js";
import { buildCustomShortcutRule, validateCustomShortcut } from "./custom-shortcuts.js";
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

export function planCustomShortcutApplication(config, definitions) {
  const requestedDefinitions = Array.isArray(definitions) ? definitions : [definitions];
  const validations = requestedDefinitions.map((definition) => validateCustomShortcut(definition));
  const validationErrors = validations.filter((result) => !result.ok);
  const warnings = validations.flatMap((result) => result.warnings);

  if (validationErrors.length > 0) {
    return {
      ok: false,
      changed: false,
      config: null,
      conflicts: [],
      warnings,
      validationErrors,
    };
  }

  const selectedRules = validations.map((result) => buildCustomShortcutRule(result.value));
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
      warnings,
      validationErrors: [],
    };
  }

  const mergeResult = mergeOwnedRules(config, selectedRules, STARTER_CUSTOM_PREFIX);

  return {
    ok: true,
    changed: mergeResult.changed,
    config: mergeResult.config,
    conflicts: [],
    warnings,
    validationErrors: [],
  };
}

import { STARTER_CUSTOM_PREFIX } from "./config.js";

const keyEntries = [
  ...Array.from("abcdefghijklmnopqrstuvwxyz", (letter) => [letter, letter.toUpperCase()]),
  ...Array.from("0123456789", (digit) => [digit, digit]),
  ["escape", "Escape"],
  ["tab", "Tab"],
  ["caps_lock", "Caps Lock"],
  ["spacebar", "Spacebar"],
  ["return_or_enter", "Return/Enter"],
  ["delete_or_backspace", "Delete/Backspace"],
  ["forward_delete", "Forward Delete"],
  ["home", "Home"],
  ["end", "End"],
  ["page_up", "Page Up"],
  ["page_down", "Page Down"],
  ["left_arrow", "Left Arrow"],
  ["right_arrow", "Right Arrow"],
  ["up_arrow", "Up Arrow"],
  ["down_arrow", "Down Arrow"],
  ["comma", "Comma"],
  ["period", "Period"],
  ["slash", "Slash"],
  ["semicolon", "Semicolon"],
  ["quote", "Quote"],
  ["open_bracket", "Open Bracket"],
  ["close_bracket", "Close Bracket"],
  ["minus", "Minus"],
  ["equal_sign", "Equal"],
  ["backslash", "Backslash"],
  ["grave_accent_and_tilde", "Grave Accent"],
  ...Array.from({ length: 20 }, (_, index) => [`f${index + 1}`, `F${index + 1}`]),
];

const modifierEntries = [
  ["command", "Command"],
  ["left_command", "Left Command"],
  ["right_command", "Right Command"],
  ["control", "Control"],
  ["left_control", "Left Control"],
  ["right_control", "Right Control"],
  ["option", "Option"],
  ["left_option", "Left Option"],
  ["right_option", "Right Option"],
  ["shift", "Shift"],
  ["left_shift", "Left Shift"],
  ["right_shift", "Right Shift"],
  ["fn", "Fn"],
];

export const keyCatalog = keyEntries.map(([id, label]) => ({ id, label }));
export const modifierCatalog = modifierEntries.map(([id, label]) => ({ id, label }));

const keyCatalogById = new Map(keyCatalog.map((entry) => [entry.id, entry]));
const modifierCatalogById = new Map(modifierCatalog.map((entry) => [entry.id, entry]));
const modifierOrder = new Map(modifierCatalog.map((entry, index) => [entry.id, index]));

const keyAliases = new Map([
  ["esc", "escape"],
  ["enter", "return_or_enter"],
  ["return", "return_or_enter"],
  ["backspace", "delete_or_backspace"],
  ["delete", "delete_or_backspace"],
  ["space", "spacebar"],
  ["cmd", "command"],
  ["command", "command"],
  ["ctrl", "control"],
  ["control", "control"],
  ["alt", "option"],
  ["opt", "option"],
  ["option", "option"],
  ["shift", "shift"],
  ["fn", "fn"],
]);

const modifierAliases = new Map([
  ["cmd", "command"],
  ["command", "command"],
  ["left_cmd", "left_command"],
  ["right_cmd", "right_command"],
  ["ctrl", "control"],
  ["control", "control"],
  ["alt", "option"],
  ["opt", "option"],
  ["option", "option"],
  ["shift", "shift"],
  ["fn", "fn"],
]);

const riskyShortcutKeys = new Set(["q", "w", "tab", "spacebar", "c", "v", "x", "z", "s"]);
const plainTextKeys = new Set([
  ..."abcdefghijklmnopqrstuvwxyz0123456789".split(""),
  "tab",
  "spacebar",
  "return_or_enter",
  "delete_or_backspace",
  "forward_delete",
  "comma",
  "period",
  "slash",
  "semicolon",
  "quote",
  "open_bracket",
  "close_bracket",
  "hyphen",
  "minus",
  "equal_sign",
  "backslash",
  "grave_accent_and_tilde",
  "left_arrow",
  "right_arrow",
  "up_arrow",
  "down_arrow",
]);

export function validateCustomShortcut(definition) {
  const normalized = normalizeCustomShortcut(definition);
  const errors = [];

  if (!normalized.name) {
    errors.push("name is required");
  }

  if (!normalized.sourceKey) {
    errors.push("sourceKey is required");
  } else if (!keyCatalogById.has(normalized.sourceKey)) {
    errors.push(`unknown sourceKey: ${normalized.sourceKey}`);
  }

  if (!normalized.outputKey) {
    errors.push("outputKey is required");
  } else if (!keyCatalogById.has(normalized.outputKey)) {
    errors.push(`unknown outputKey: ${normalized.outputKey}`);
  }

  for (const modifier of normalized.sourceModifiers) {
    if (!modifierCatalogById.has(modifier)) {
      errors.push(`unknown sourceModifier: ${modifier}`);
    }
  }

  for (const modifier of normalized.outputModifiers) {
    if (!modifierCatalogById.has(modifier)) {
      errors.push(`unknown outputModifier: ${modifier}`);
    }
  }

  if (
    normalized.sourceKey &&
    normalized.outputKey &&
    normalized.sourceKey === normalized.outputKey &&
    sameArray(normalized.sourceModifiers, normalized.outputModifiers)
  ) {
    errors.push("source and output are the same");
  }

  const warnings = getRiskyShortcutWarnings(normalized);

  return {
    ok: errors.length === 0,
    errors,
    warnings,
    preview: describeCustomShortcut(normalized),
    value: normalized,
  };
}

export function buildCustomShortcutRule(definition) {
  const validation = validateCustomShortcut(definition);
  if (!validation.ok) {
    throw new Error(validation.errors.join("; "));
  }

  const shortcut = validation.value;
  const to = {
    key_code: shortcut.outputKey,
  };

  if (shortcut.outputModifiers.length > 0) {
    to.modifiers = [...shortcut.outputModifiers];
  }

  return {
    description: `${STARTER_CUSTOM_PREFIX} ${shortcut.name}`,
    manipulators: [
      {
        type: "basic",
        from: {
          key_code: shortcut.sourceKey,
          modifiers:
            shortcut.sourceModifiers.length > 0
              ? {
                  mandatory: [...shortcut.sourceModifiers],
                  optional: ["any"],
                }
              : {
                  optional: ["any"],
                },
        },
        to: [to],
      },
    ],
  };
}

function normalizeCustomShortcut(definition) {
  const sourceModifiers = normalizeModifierList(definition?.sourceModifiers);
  const outputModifiers = normalizeModifierList(definition?.outputModifiers);

  return {
    name: normalizeString(definition?.name),
    sourceKey: normalizeKeyId(definition?.sourceKey),
    sourceModifiers,
    outputKey: normalizeKeyId(definition?.outputKey),
    outputModifiers,
  };
}

function normalizeKeyId(value) {
  const normalized = normalizeString(value).toLowerCase();
  return keyAliases.get(normalized) ?? normalized;
}

function normalizeModifierList(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return [...new Set(value.map((modifier) => normalizeModifierId(modifier)).filter(Boolean))].sort(
    (left, right) => (modifierOrder.get(left) ?? Number.MAX_SAFE_INTEGER) - (modifierOrder.get(right) ?? Number.MAX_SAFE_INTEGER)
  );
}

function normalizeModifierId(value) {
  const normalized = normalizeString(value).toLowerCase();
  return modifierAliases.get(normalized) ?? normalized;
}

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function describeCustomShortcut(shortcut) {
  const source = formatShortcutLabel(shortcut.sourceModifiers, shortcut.sourceKey);
  const output = formatShortcutLabel(shortcut.outputModifiers, shortcut.outputKey);
  return `${source} -> ${output}`;
}

function getRiskyShortcutWarnings(shortcut) {
  const warnings = [];

  if (shortcut.sourceModifiers.length === 0 && plainTextKeys.has(shortcut.sourceKey)) {
    warnings.push(
      `${formatShortcutWarning([], shortcut.sourceKey)} will stop typing normally everywhere. Add a modifier unless you really mean to replace that key.`
    );
  }

  if (
    shortcut.sourceKey &&
    shortcut.sourceModifiers.some((modifier) => isCommandModifier(modifier)) &&
    riskyShortcutKeys.has(shortcut.sourceKey)
  ) {
    warnings.push(
      `${formatShortcutWarning(shortcut.sourceModifiers, shortcut.sourceKey)} is a risky macOS shortcut and may override a common system action.`
    );
  }

  if (riskyShortcutKeys.has(shortcut.outputKey) && shortcut.outputModifiers.some((modifier) => isCommandModifier(modifier))) {
    warnings.push(
      `This sends ${formatShortcutWarning(shortcut.outputModifiers, shortcut.outputKey)}, which may trigger a common macOS action.`
    );
  }

  return warnings;
}

function isCommandModifier(modifier) {
  return modifier === "command" || modifier === "left_command" || modifier === "right_command";
}

function formatShortcutLabel(modifiers, key) {
  const parts = [
    ...modifiers.map((modifier) => modifierCatalogById.get(modifier)?.label ?? modifier),
    keyCatalogById.get(key)?.label ?? key,
  ];

  return parts.join("+");
}

function formatShortcutWarning(modifiers, key) {
  const parts = [
    ...modifiers.map((modifier) => modifierCatalogById.get(modifier)?.label ?? modifier),
    keyCatalogById.get(key)?.label ?? key,
  ];

  return parts.join("-");
}

function sameArray(left, right) {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

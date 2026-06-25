import { STARTER_RULE_PREFIX } from "./config.js";

export const presetCatalog = [
  {
    id: "caps_escape_control",
    title: "Caps Lock: Escape / Control",
    summary: "Tap Caps Lock for Escape. Hold it for Control.",
    risk: "low",
    rule: {
      description: `${STARTER_RULE_PREFIX} Caps Lock: Escape when tapped, Control when held`,
      manipulators: [
        {
          type: "basic",
          from: {
            key_code: "caps_lock",
            modifiers: {
              optional: ["any"],
            },
          },
          to: [{ key_code: "left_control" }],
          to_if_alone: [{ key_code: "escape" }],
        },
      ],
    },
  },
  {
    id: "right_command_navigation",
    title: "Right Command navigation",
    summary: "Use Right Command + H/J/K/L as left/down/up/right arrows.",
    risk: "low",
    rule: {
      description: `${STARTER_RULE_PREFIX} Right Command + H/J/K/L navigation`,
      manipulators: [
        rightCommandManipulator("h", "left_arrow"),
        rightCommandManipulator("j", "down_arrow"),
        rightCommandManipulator("k", "up_arrow"),
        rightCommandManipulator("l", "right_arrow"),
      ],
    },
  },
  {
    id: "right_command_forward_delete",
    title: "Right Command forward delete",
    summary: "Use Right Command + Delete as forward delete.",
    risk: "low",
    rule: {
      description: `${STARTER_RULE_PREFIX} Right Command + Delete: forward delete`,
      manipulators: [
        rightCommandManipulator("delete_or_backspace", "delete_forward"),
      ],
    },
  },
];

export function rulesForPresetIds(presetIds) {
  const selected = new Set(presetIds);

  return presetCatalog
    .filter((preset) => selected.has(preset.id))
    .map((preset) => structuredClone(preset.rule));
}

export function unknownPresetIds(presetIds) {
  const knownIds = new Set(presetCatalog.map((preset) => preset.id));
  return presetIds.filter((presetId) => !knownIds.has(presetId));
}

function rightCommandManipulator(fromKey, toKey) {
  return {
    type: "basic",
    from: {
      key_code: fromKey,
      modifiers: {
        mandatory: ["right_command"],
        optional: ["any"],
      },
    },
    to: [{ key_code: toKey }],
  };
}

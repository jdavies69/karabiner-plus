import assert from "node:assert/strict";
import test from "node:test";

import { buildDefaultConfig, findSelectedProfile } from "../src/core/config.js";
import { planPresetApplication } from "../src/core/apply.js";

test("planPresetApplication blocks when a selected preset conflicts with existing config", () => {
  const config = buildDefaultConfig();
  const profile = findSelectedProfile(config);
  profile.complex_modifications.rules.push({
    description: "Custom Right Command H",
    manipulators: [
      {
        type: "basic",
        from: {
          key_code: "h",
          modifiers: { mandatory: ["right_command"] },
        },
        to: [{ key_code: "home" }],
      },
    ],
  });

  const result = planPresetApplication(config, ["right_command_navigation"]);

  assert.equal(result.ok, false);
  assert.equal(result.config, null);
  assert.deepEqual(result.conflicts, [
    {
      trigger: "key:h|mods:right_command",
      rules: [
        "Custom Right Command H",
        "[Karabiner+] Right Command + H/J/K/L navigation",
      ],
    },
  ]);
});

test("planPresetApplication returns merged config for non-conflicting presets", () => {
  const result = planPresetApplication(buildDefaultConfig(), [
    "caps_escape_control",
    "right_command_forward_delete",
  ]);

  assert.equal(result.ok, true);
  assert.equal(result.conflicts.length, 0);
  assert.equal(
    result.config.profiles[0].complex_modifications.rules.length,
    2
  );
});

test("planPresetApplication rejects unknown preset ids", () => {
  const result = planPresetApplication(buildDefaultConfig(), [
    "caps_escape_control",
    "typo_preset",
  ]);

  assert.equal(result.ok, false);
  assert.deepEqual(result.unknownPresetIds, ["typo_preset"]);
  assert.equal(result.config, null);
});

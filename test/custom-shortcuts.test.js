import assert from "node:assert/strict";
import test from "node:test";

import {
  STARTER_CUSTOM_PREFIX,
  STARTER_RECOMMENDED_PREFIX,
  buildDefaultConfig,
  findSelectedProfile,
} from "../src/core/config.js";
import { planCustomShortcutApplication } from "../src/core/apply.js";
import {
  buildCustomShortcutRule,
  keyCatalog,
  modifierCatalog,
  validateCustomShortcut,
} from "../src/core/custom-shortcuts.js";

test("custom shortcut catalogs expose the keys and modifiers needed by the studio", () => {
  assert.ok(keyCatalog.some((entry) => entry.id === "q"));
  assert.ok(keyCatalog.some((entry) => entry.id === "spacebar"));
  assert.ok(modifierCatalog.some((entry) => entry.id === "command"));
  assert.ok(modifierCatalog.some((entry) => entry.id === "shift"));
});

test("buildCustomShortcutRule creates a global Karabiner rule with the starter prefix", () => {
  const rule = buildCustomShortcutRule({
    name: "Launch Terminal",
    sourceKey: "j",
    sourceModifiers: ["command", "shift"],
    outputKey: "escape",
    outputModifiers: [],
  });

  assert.deepEqual(rule, {
    description: "[Karabiner+] Custom: Launch Terminal",
    manipulators: [
      {
        type: "basic",
        from: {
          key_code: "j",
          modifiers: {
            mandatory: ["command", "shift"],
            optional: ["any"],
          },
        },
        to: [{ key_code: "escape" }],
      },
    ],
  });
});

test("validateCustomShortcut reports missing required fields", () => {
  const result = validateCustomShortcut({
    sourceKey: "q",
    outputKey: "w",
    sourceModifiers: ["command"],
    outputModifiers: [],
  });

  assert.equal(result.ok, false);
  assert.ok(result.errors.some((error) => error.includes("name")));
});

test("validateCustomShortcut warns about risky global Mac shortcuts", () => {
  const result = validateCustomShortcut({
    name: "Replace Quit",
    sourceKey: "q",
    sourceModifiers: ["command"],
    outputKey: "escape",
    outputModifiers: [],
  });

  assert.equal(result.ok, true);
  assert.ok(result.warnings.some((warning) => warning.includes("Command-Q")));
});

test("validateCustomShortcut warns before replacing normal typing keys", () => {
  const result = validateCustomShortcut({
    name: "A to Escape",
    sourceKey: "a",
    sourceModifiers: [],
    outputKey: "escape",
    outputModifiers: [],
  });

  assert.equal(result.ok, true);
  assert.ok(result.warnings.some((warning) => warning.includes("A will stop typing normally everywhere")));

  const spaceResult = validateCustomShortcut({
    name: "Space to Escape",
    sourceKey: "spacebar",
    sourceModifiers: [],
    outputKey: "escape",
    outputModifiers: [],
  });

  assert.equal(spaceResult.ok, true);
  assert.ok(spaceResult.warnings.some((warning) => warning.includes("Spacebar will stop typing normally everywhere")));
});

test("validateCustomShortcut warns when output sends a risky Mac shortcut", () => {
  const result = validateCustomShortcut({
    name: "Send Quit",
    sourceKey: "j",
    sourceModifiers: ["right_command"],
    outputKey: "q",
    outputModifiers: ["command"],
  });

  assert.equal(result.ok, true);
  assert.ok(result.warnings.some((warning) => warning.includes("This sends Command-Q")));
});

test("validateCustomShortcut rejects no-op remaps", () => {
  const result = validateCustomShortcut({
    name: "Escape to Escape",
    sourceKey: "escape",
    sourceModifiers: [],
    outputKey: "escape",
    outputModifiers: [],
  });

  assert.equal(result.ok, false);
  assert.ok(result.errors.some((error) => error.includes("source and output are the same")));
});

test("planCustomShortcutApplication blocks conflicting custom shortcuts", () => {
  const config = buildDefaultConfig();
  const profile = findSelectedProfile(config);
  profile.complex_modifications.rules.push({
    description: "User command j",
    manipulators: [
      {
        type: "basic",
        from: {
          key_code: "j",
          modifiers: {
            mandatory: ["command"],
          },
        },
        to: [{ key_code: "escape" }],
      },
    ],
  });

  const result = planCustomShortcutApplication(config, [
    {
      name: "Launcher",
      sourceKey: "j",
      sourceModifiers: ["command"],
      outputKey: "escape",
      outputModifiers: [],
    },
  ]);

  assert.equal(result.ok, false);
  assert.equal(result.config, null);
  assert.equal(result.conflicts.length, 1);
  assert.equal(result.conflicts[0].trigger, "key:j|mods:command");
});

test("planCustomShortcutApplication preserves other starter-owned rules", () => {
  const config = buildDefaultConfig();
  const profile = findSelectedProfile(config);
  profile.complex_modifications.rules.push(
    {
      description: `${STARTER_CUSTOM_PREFIX} Old custom`,
      manipulators: [
        {
          type: "basic",
          from: {
            key_code: "k",
            modifiers: {
              mandatory: ["command"],
            },
          },
          to: [{ key_code: "escape" }],
        },
      ],
    },
    {
      description: `${STARTER_RECOMMENDED_PREFIX} Keep this`,
      manipulators: [
        {
          type: "basic",
          from: { key_code: "f1" },
          to: [{ key_code: "display_brightness_decrement" }],
        },
      ],
    }
  );

  const result = planCustomShortcutApplication(config, [
    {
      name: "New custom",
      sourceKey: "j",
      sourceModifiers: ["command"],
      outputKey: "escape",
      outputModifiers: [],
    },
  ]);

  assert.equal(result.ok, true);
  assert.equal(result.changed, true);
  assert.equal(result.config.profiles[0].complex_modifications.rules.length, 2);
  assert.equal(
    result.config.profiles[0].complex_modifications.rules[0].description,
    `${STARTER_RECOMMENDED_PREFIX} Keep this`
  );
  assert.equal(
    result.config.profiles[0].complex_modifications.rules[1].description,
    "[Karabiner+] Custom: New custom"
  );
});

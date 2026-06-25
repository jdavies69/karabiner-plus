import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  STARTER_RULE_PREFIX,
  backupConfig,
  buildDefaultConfig,
  collectExistingTriggers,
  findSelectedProfile,
  mergeStarterRules,
} from "../src/core/config.js";
import { detectConflicts, triggerForManipulator, triggersForRule } from "../src/core/conflicts.js";
import { presetCatalog, rulesForPresetIds } from "../src/core/presets.js";

test("preset catalog exposes conservative starter presets", () => {
  const ids = presetCatalog.map((preset) => preset.id);

  assert.deepEqual(ids, [
    "caps_escape_control",
    "right_command_navigation",
    "right_command_forward_delete",
  ]);

  assert.ok(
    presetCatalog.every((preset) => preset.risk === "low"),
    "all starter presets should be low-risk"
  );
});

test("triggerForManipulator normalizes key plus mandatory modifiers", () => {
  const trigger = triggerForManipulator({
    type: "basic",
    from: {
      key_code: "h",
      modifiers: {
        mandatory: ["right_command", "shift"],
        optional: ["any"],
      },
    },
    to: [{ key_code: "left_arrow" }],
  });

  assert.equal(trigger, "key:h|mods:right_command+shift");
});

test("detectConflicts finds duplicate preset triggers", () => {
  const conflicts = detectConflicts({
    selectedRules: [
      {
        description: `${STARTER_RULE_PREFIX} A`,
        manipulators: [
          {
            type: "basic",
            from: {
              key_code: "h",
              modifiers: { mandatory: ["right_command"] },
            },
            to: [{ key_code: "left_arrow" }],
          },
        ],
      },
      {
        description: `${STARTER_RULE_PREFIX} B`,
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
      },
    ],
    existingTriggers: [],
  });

  assert.equal(conflicts.length, 1);
  assert.equal(conflicts[0].trigger, "key:h|mods:right_command");
  assert.deepEqual(conflicts[0].rules, [
    `${STARTER_RULE_PREFIX} A`,
    `${STARTER_RULE_PREFIX} B`,
  ]);
});

test("detectConflicts treats generic command and right_command as overlapping", () => {
  const conflicts = detectConflicts({
    existingTriggers: triggersForRule({
      description: "Custom command h",
      manipulators: [
        {
          type: "basic",
          from: {
            key_code: "h",
            modifiers: {
              mandatory: ["command"],
              optional: ["any"],
            },
          },
          to: [{ key_code: "home" }],
        },
      ],
    }),
    selectedRules: [
      {
        description: `${STARTER_RULE_PREFIX} Right Command H`,
        manipulators: [
          {
            type: "basic",
            from: {
              key_code: "h",
              modifiers: {
                mandatory: ["right_command"],
                optional: ["any"],
              },
            },
            to: [{ key_code: "left_arrow" }],
          },
        ],
      },
    ],
  });

  assert.equal(conflicts.length, 1);
  assert.equal(conflicts[0].trigger, "key:h|mods:command overlaps key:h|mods:right_command");
  assert.deepEqual(conflicts[0].rules, [
    "Custom command h",
    `${STARTER_RULE_PREFIX} Right Command H`,
  ]);
});

test("mergeStarterRules preserves unrelated rules and replaces starter rules", () => {
  const config = buildDefaultConfig();
  const selectedProfile = findSelectedProfile(config);

  selectedProfile.complex_modifications.rules.push(
    {
      description: "Keep this custom rule",
      manipulators: [
        {
          type: "basic",
          from: { key_code: "f1" },
          to: [{ key_code: "display_brightness_decrement" }],
        },
      ],
    },
    {
      description: `${STARTER_RULE_PREFIX} Old rule`,
      manipulators: [
        {
          type: "basic",
          from: { key_code: "x" },
          to: [{ key_code: "y" }],
        },
      ],
    }
  );

  const result = mergeStarterRules(
    config,
    rulesForPresetIds(["caps_escape_control", "right_command_navigation"])
  );

  const rules = result.config.profiles[0].complex_modifications.rules;
  assert.equal(result.changed, true);
  assert.equal(rules.length, 3);
  assert.equal(rules[0].description, "Keep this custom rule");
  assert.ok(rules.slice(1).every((rule) => rule.description.startsWith(STARTER_RULE_PREFIX)));
  assert.ok(!rules.some((rule) => rule.description.endsWith("Old rule")));
});

test("collectExistingTriggers ignores starter-owned rules", () => {
  const config = buildDefaultConfig();
  const selectedProfile = findSelectedProfile(config);

  selectedProfile.complex_modifications.rules.push(
    {
      description: "Custom right command h",
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
    },
    {
      description: `${STARTER_RULE_PREFIX} Starter right command j`,
      manipulators: [
        {
          type: "basic",
          from: {
            key_code: "j",
            modifiers: { mandatory: ["right_command"] },
          },
          to: [{ key_code: "down_arrow" }],
        },
      ],
    }
  );

  assert.deepEqual(collectExistingTriggers(config), [
    {
      description: "Custom right command h",
      trigger: "key:h|mods:right_command",
    },
  ]);
});

test("collectExistingTriggers includes simple modifications", () => {
  const config = buildDefaultConfig();
  const selectedProfile = findSelectedProfile(config);

  selectedProfile.simple_modifications.push({
    from: { key_code: "caps_lock" },
    to: [{ key_code: "escape" }],
  });

  assert.deepEqual(collectExistingTriggers(config), [
    {
      description: "Simple modification: caps_lock",
      trigger: "key:caps_lock|mods:",
    },
  ]);
});

test("backupConfig writes a timestamped copy", async () => {
  const dir = await mkdtemp(join(tmpdir(), "karabiner-starter-"));

  try {
    const sourcePath = join(dir, "karabiner.json");
    const backupDir = join(dir, "backups");
    await writeFile(sourcePath, JSON.stringify({ profiles: [] }), "utf8");

    const backupPath = await backupConfig({
      sourcePath,
      backupDir,
      now: new Date("2026-06-25T12:34:56.000Z"),
    });

    assert.equal(backupPath, join(backupDir, "karabiner-2026-06-25T12-34-56-000Z.json"));
    assert.equal(await readFile(backupPath, "utf8"), JSON.stringify({ profiles: [] }));
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

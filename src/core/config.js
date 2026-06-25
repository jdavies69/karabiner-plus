import { copyFile, mkdir, readFile, readdir, rename, rm, stat, writeFile } from "node:fs/promises";
import { basename, dirname, join } from "node:path";

import { triggersForRule } from "./conflicts.js";

export const STARTER_RULE_PREFIX = "[Karabiner Starter]";

export function buildDefaultConfig() {
  return {
    global: {
      check_for_updates_on_startup: true,
      show_in_menu_bar: true,
    },
    profiles: [
      {
        name: "Default profile",
        selected: true,
        simple_modifications: [],
        complex_modifications: {
          parameters: {
            "basic.simultaneous_threshold_milliseconds": 50,
            "basic.to_delayed_action_delay_milliseconds": 500,
            "basic.to_if_alone_timeout_milliseconds": 1000,
            "basic.to_if_held_down_threshold_milliseconds": 500,
            "mouse_motion_to_scroll.speed": 100,
          },
          rules: [],
        },
        devices: [],
        fn_function_keys: [],
        virtual_hid_keyboard: {
          keyboard_type_v2: "ansi",
        },
      },
    ],
  };
}

export async function readKarabinerConfig(configPath) {
  try {
    const contents = await readFile(configPath, "utf8");
    return JSON.parse(contents);
  } catch (error) {
    if (error.code === "ENOENT") {
      return buildDefaultConfig();
    }
    throw error;
  }
}

export async function writeKarabinerConfig(configPath, config) {
  await mkdir(dirname(configPath), { recursive: true });
  const json = `${JSON.stringify(config, null, 2)}\n`;
  JSON.parse(json);

  const tempPath = join(
    dirname(configPath),
    `.${basename(configPath)}.${process.pid}.${Date.now()}.tmp`
  );

  try {
    await writeFile(tempPath, json, "utf8");
    await rename(tempPath, configPath);
  } catch (error) {
    await rm(tempPath, { force: true });
    throw error;
  }
}

export function findSelectedProfile(config) {
  ensureProfiles(config);
  return config.profiles.find((profile) => profile.selected) ?? config.profiles[0];
}

export function mergeStarterRules(config, starterRules) {
  const nextConfig = structuredClone(config);
  const profile = findSelectedProfile(nextConfig);
  ensureComplexModifications(profile);

  const previousRules = profile.complex_modifications.rules;
  const nonStarterRules = previousRules.filter(
    (rule) => !String(rule.description ?? "").startsWith(STARTER_RULE_PREFIX)
  );

  profile.complex_modifications.rules = [
    ...nonStarterRules,
    ...starterRules.map((rule) => structuredClone(rule)),
  ];

  return {
    config: nextConfig,
    changed:
      JSON.stringify(previousRules) !== JSON.stringify(profile.complex_modifications.rules),
  };
}

export function collectExistingTriggers(config) {
  const profile = findSelectedProfile(config);
  ensureComplexModifications(profile);

  const complexTriggers = profile.complex_modifications.rules
    .filter((rule) => !String(rule.description ?? "").startsWith(STARTER_RULE_PREFIX))
    .flatMap((rule) => triggersForRule(rule));

  const simpleTriggers = (profile.simple_modifications ?? [])
    .map((simpleModification) => simpleModificationTrigger(simpleModification))
    .filter(Boolean);

  return [...complexTriggers, ...simpleTriggers];
}

export async function backupConfig({ sourcePath, backupDir, now = new Date() }) {
  await mkdir(backupDir, { recursive: true });
  const timestamp = now.toISOString().replaceAll(":", "-").replaceAll(".", "-");
  const backupPath = join(backupDir, `karabiner-${timestamp}.json`);
  await copyFile(sourcePath, backupPath);
  return backupPath;
}

export async function listBackups(backupDir) {
  try {
    const entries = await readdir(backupDir, { withFileTypes: true });
    const backups = await Promise.all(
      entries
        .filter((entry) => entry.isFile())
        .filter((entry) => /^karabiner-.+\.json$/.test(entry.name))
        .map(async (entry) => {
          const path = join(backupDir, entry.name);
          const details = await stat(path);
          return {
            name: entry.name,
            path,
            size: details.size,
            modifiedAt: details.mtime.toISOString(),
          };
        })
    );

    return backups.sort((a, b) => b.name.localeCompare(a.name));
  } catch (error) {
    if (error.code === "ENOENT") {
      return [];
    }
    throw error;
  }
}

export async function restoreBackup({ backupPath, configPath, backupDir, now = new Date() }) {
  const backupJson = JSON.parse(await readFile(backupPath, "utf8"));
  const preRestoreBackupPath = await backupConfig({
    sourcePath: configPath,
    backupDir,
    now,
  });

  await writeKarabinerConfig(configPath, backupJson);

  return {
    ok: true,
    backupPath,
    preRestoreBackupPath,
  };
}

function ensureProfiles(config) {
  if (!Array.isArray(config.profiles) || config.profiles.length === 0) {
    config.profiles = buildDefaultConfig().profiles;
  }
}

function ensureComplexModifications(profile) {
  profile.complex_modifications ??= {};
  profile.complex_modifications.parameters ??=
    buildDefaultConfig().profiles[0].complex_modifications.parameters;
  profile.complex_modifications.rules ??= [];
  profile.simple_modifications ??= [];
}

function simpleModificationTrigger(simpleModification) {
  const key = simpleModification.from?.key_code;
  if (!key) {
    return null;
  }

  return {
    description: `Simple modification: ${key}`,
    trigger: `key:${key}|mods:`,
  };
}

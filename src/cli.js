#!/usr/bin/env node
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

import { planPresetApplication } from "./core/apply.js";
import {
  backupConfig,
  listBackups,
  readKarabinerConfig,
  restoreBackup,
  writeKarabinerConfig,
} from "./core/config.js";
import { presetCatalog } from "./core/presets.js";
import {
  createSystemStatus,
  installKarabinerWithHomebrew,
} from "./core/system.js";
import { createKarabinerPlusServer } from "./server.js";

const configDir = join(homedir(), ".config", "karabiner");
const configPath = join(configDir, "karabiner.json");
const backupDir = join(configDir, "backups");

const commands = new Set([
  "start",
  "doctor",
  "status",
  "presets",
  "backup",
  "backups",
  "restore",
  "apply",
  "install-karabiner",
]);

export async function main(argv = process.argv.slice(2), io = process) {
  const command = argv[0] ?? "start";

  if (!commands.has(command)) {
    io.stderr.write(`Unknown command: ${command}\n\n${usage()}\n`);
    return 1;
  }

  if (command === "start") {
    return startServer();
  }

  if (command === "doctor" || command === "status") {
    io.stdout.write(`${JSON.stringify(await createSystemStatus(), null, 2)}\n`);
    return 0;
  }

  if (command === "presets") {
    io.stdout.write(`${JSON.stringify({ presets: presetCatalog }, null, 2)}\n`);
    return 0;
  }

  if (command === "backup") {
    if (!existsSync(configPath)) {
      io.stderr.write("Karabiner config was not found. Install and open Karabiner-Elements first.\n");
      return 1;
    }
    io.stdout.write(`${await backupConfig({ sourcePath: configPath, backupDir })}\n`);
    return 0;
  }

  if (command === "backups") {
    io.stdout.write(`${JSON.stringify({ backups: await listBackups(backupDir) }, null, 2)}\n`);
    return 0;
  }

  if (command === "restore") {
    const backupPath = argv[1];
    if (!backupPath) {
      io.stderr.write(`Missing backup path.\n\n${usage()}\n`);
      return 1;
    }
    io.stdout.write(
      `${JSON.stringify(await restoreBackup({ backupPath, configPath, backupDir }), null, 2)}\n`
    );
    return 0;
  }

  if (command === "apply") {
    return applyPresets(argv.slice(1), io);
  }

  if (command === "install-karabiner") {
    io.stdout.write(`${JSON.stringify(await installKarabinerWithHomebrew(), null, 2)}\n`);
    return 0;
  }

  return 1;
}

function usage() {
  return `Usage: karabiner-plus <command>

Commands:
  start              Launch the local setup UI
  doctor             Print install/status diagnostics
  status             Print install/status diagnostics
  presets            List available presets
  backup             Back up ~/.config/karabiner/karabiner.json
  backups            List available Karabiner+ backups
  restore <path>     Restore a backup and create a pre-restore backup
  apply <ids...>     Apply starter presets by id
  install-karabiner  Install official Karabiner-Elements via Homebrew`;
}

async function applyPresets(presetIds, io) {
  if (presetIds.length === 0) {
    io.stderr.write(`No presets provided.\n\n${usage()}\n`);
    return 1;
  }

  if (!existsSync(configPath)) {
    io.stderr.write("Karabiner config was not found. Install and open Karabiner-Elements first.\n");
    return 1;
  }

  const config = await readKarabinerConfig(configPath);
  const plan = planPresetApplication(config, presetIds);
  if (plan.unknownPresetIds?.length > 0) {
    io.stderr.write(
      `${JSON.stringify({ ok: false, unknownPresetIds: plan.unknownPresetIds }, null, 2)}\n`
    );
    return 1;
  }
  if (!plan.ok) {
    io.stderr.write(`${JSON.stringify({ ok: false, conflicts: plan.conflicts }, null, 2)}\n`);
    return 2;
  }

  const backupPath = await backupConfig({ sourcePath: configPath, backupDir });
  await writeKarabinerConfig(configPath, plan.config);
  io.stdout.write(`${JSON.stringify({ ok: true, backupPath }, null, 2)}\n`);
  return 0;
}

function startServer() {
  const server = createKarabinerPlusServer();
  server.listen(0, "127.0.0.1", () => {
    const { port } = server.address();
    const url = `http://127.0.0.1:${port}/`;
    console.log(`Karabiner+ is running at ${url}`);
    openUrl(url);
  });
  return 0;
}

function openUrl(url) {
  execFile("open", [url], () => {});
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const exitCode = await main();
  if (exitCode !== 0) {
    process.exitCode = exitCode;
  }
}

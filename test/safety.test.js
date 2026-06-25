import assert from "node:assert/strict";
import { mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  backupConfig,
  buildDefaultConfig,
  listBackups,
  restoreBackup,
  writeKarabinerConfig,
} from "../src/core/config.js";

test("writeKarabinerConfig writes parseable JSON and leaves no temp files", async () => {
  const dir = await mkdtemp(join(tmpdir(), "karabiner-starter-atomic-"));

  try {
    const configPath = join(dir, "karabiner.json");
    await writeKarabinerConfig(configPath, buildDefaultConfig());

    assert.doesNotThrow(() => readFileSyncJson(configPath));
    assert.deepEqual(
      (await readdir(dir)).sort(),
      ["karabiner.json"]
    );
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("listBackups returns newest backups first", async () => {
  const dir = await mkdtemp(join(tmpdir(), "karabiner-starter-backups-"));

  try {
    const sourcePath = join(dir, "karabiner.json");
    const backupDir = join(dir, "backups");
    await writeFile(sourcePath, JSON.stringify({ value: 1 }), "utf8");
    await backupConfig({
      sourcePath,
      backupDir,
      now: new Date("2026-06-25T12:00:00.000Z"),
    });
    await backupConfig({
      sourcePath,
      backupDir,
      now: new Date("2026-06-25T13:00:00.000Z"),
    });

    const backups = await listBackups(backupDir);
    assert.equal(backups.length, 2);
    assert.match(backups[0].name, /13-00-00/);
    assert.match(backups[1].name, /12-00-00/);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("restoreBackup creates pre-restore backup and restores selected backup", async () => {
  const dir = await mkdtemp(join(tmpdir(), "karabiner-starter-restore-"));

  try {
    const configPath = join(dir, "karabiner.json");
    const backupDir = join(dir, "backups");
    await writeFile(configPath, JSON.stringify({ value: "current" }), "utf8");
    const backupPath = await backupConfig({
      sourcePath: configPath,
      backupDir,
      now: new Date("2026-06-25T12:00:00.000Z"),
    });
    await writeFile(configPath, JSON.stringify({ value: "changed" }), "utf8");

    const result = await restoreBackup({
      backupPath,
      configPath,
      backupDir,
      now: new Date("2026-06-25T13:00:00.000Z"),
    });

    assert.match(result.preRestoreBackupPath, /13-00-00/);
    assert.deepEqual(JSON.parse(await readFile(configPath, "utf8")), { value: "current" });
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

function readFileSyncJson(path) {
  return JSON.parse(process.getBuiltinModule("node:fs").readFileSync(path, "utf8"));
}

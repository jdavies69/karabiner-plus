import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { buildDefaultConfig } from "../src/core/config.js";
import { createKarabinerStarterServer } from "../src/server.js";

test("serves static HTML at the root route", async () => {
  const server = createKarabinerStarterServer();
  const baseUrl = await listen(server);

  try {
    const response = await fetch(`${baseUrl}/`);

    assert.equal(response.status, 200);
    assert.match(response.headers.get("content-type") ?? "", /\btext\/html\b/i);

    const body = await response.text();
    assert.match(body, /<html[\s>]/i);
    assert.match(body, /Karabiner Starter/i);
    assert.match(body, /Restore backup/i);
  } finally {
    await close(server);
  }
});

test("POST /api/apply returns conflicts without writing colliding presets", async () => {
  const dir = await mkdtemp(join(tmpdir(), "karabiner-starter-server-"));

  try {
    const configPath = join(dir, "karabiner.json");
    const backupDir = join(dir, "backups");
    const config = buildDefaultConfig();

    config.profiles[0].complex_modifications.rules.push({
      description: "User right command h",
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
          to: [{ key_code: "home" }],
        },
      ],
    });

    const originalConfigText = `${JSON.stringify(config, null, 2)}\n`;
    await writeFile(configPath, originalConfigText, "utf8");

    const server = createKarabinerStarterServer({ configPath, backupDir });
    const baseUrl = await listen(server);

    try {
      const response = await fetch(`${baseUrl}/api/apply`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          presetIds: ["right_command_navigation"],
        }),
      });

      assert.equal(response.status, 409);
      assert.match(response.headers.get("content-type") ?? "", /\bapplication\/json\b/i);

      const payload = await response.json();
      assert.equal(payload.ok, false);
      assert.deepEqual(payload.conflicts, [
        {
          trigger: "key:h|mods:right_command",
          rules: [
            "User right command h",
            "[Karabiner Starter] Right Command + H/J/K/L navigation",
          ],
        },
      ]);
      assert.equal(await readFile(configPath, "utf8"), originalConfigText);
    } finally {
      await close(server);
    }
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("POST /api/apply requires an existing Karabiner config", async () => {
  const dir = await mkdtemp(join(tmpdir(), "karabiner-starter-first-run-"));

  try {
    const configPath = join(dir, "missing-karabiner.json");
    const backupDir = join(dir, "backups");
    const server = createKarabinerStarterServer({ configPath, backupDir });
    const baseUrl = await listen(server);

    try {
      const response = await fetch(`${baseUrl}/api/apply`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          presetIds: ["caps_escape_control"],
        }),
      });

      assert.equal(response.status, 428);
      const payload = await response.json();
      assert.equal(payload.ok, false);
      assert.match(payload.error, /open Karabiner-Elements first/i);
    } finally {
      await close(server);
    }
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

function listen(server) {
  return new Promise((resolve, reject) => {
    const onError = (error) => reject(error);
    server.once("error", onError);
    server.listen(0, "127.0.0.1", () => {
      server.off("error", onError);
      const address = server.address();
      assert.ok(address && typeof address === "object");
      resolve(`http://127.0.0.1:${address.port}`);
    });
  });
}

function close(server) {
  return new Promise((resolve, reject) => {
    server.close((error) => {
      if (error) {
        reject(error);
        return;
      }

      resolve();
    });
  });
}

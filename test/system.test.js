import assert from "node:assert/strict";
import test from "node:test";

import {
  commandExists,
  createSystemStatus,
  parseCliVersion,
} from "../src/core/system.js";

test("parseCliVersion extracts the first semantic version", () => {
  assert.equal(parseCliVersion("karabiner_cli 16.0.0\n"), "16.0.0");
  assert.equal(parseCliVersion("Karabiner-Elements 15.3.7"), "15.3.7");
  assert.equal(parseCliVersion("no version here"), null);
});

test("commandExists returns true when runner exits with status zero", async () => {
  const exists = await commandExists("brew", {
    run: async () => ({ status: 0, stdout: "", stderr: "" }),
  });

  assert.equal(exists, true);
});

test("createSystemStatus reports missing Karabiner without throwing", async () => {
  const status = await createSystemStatus({
    exists: async (path) => path === "/opt/homebrew/bin/brew",
    run: async () => ({ status: 1, stdout: "", stderr: "missing" }),
    karabinerCliPath: "/missing/karabiner_cli",
    brewPaths: ["/opt/homebrew/bin/brew"],
  });

  assert.deepEqual(status, {
    karabinerInstalled: false,
    karabinerCliPath: "/missing/karabiner_cli",
    karabinerVersion: null,
    homebrewInstalled: true,
    canInstallWithHomebrew: true,
    settingsGuidance: null,
    currentProfileName: null,
  });
});

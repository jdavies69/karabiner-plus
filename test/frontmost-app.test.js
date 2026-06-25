import assert from "node:assert/strict";
import test from "node:test";

import { getFrontmostApp } from "../src/core/frontmost-app.js";

test("getFrontmostApp returns app metadata from Swift helper JSON", async () => {
  const calls = [];
  const app = await getFrontmostApp({
    runner: async (command, args) => {
      calls.push({ command, args });
      return {
        stdout: JSON.stringify({
          name: "Slack",
          bundleIdentifier: "com.tinyspeck.slackmacgap",
          pid: 123,
        }),
      };
    },
  });

  assert.equal(calls[0].command, "swift");
  assert.equal(app.name, "Slack");
  assert.equal(app.bundleIdentifier, "com.tinyspeck.slackmacgap");
  assert.equal(app.pid, 123);
  assert.equal(app.source, "swift");
});

test("getFrontmostApp falls back to AppleScript when Swift is unavailable", async () => {
  const calls = [];
  const app = await getFrontmostApp({
    runner: async (command) => {
      calls.push(command);
      if (command === "swift") {
        throw new Error("swift unavailable");
      }
      return {
        stdout: JSON.stringify({
          name: "Safari",
          bundleIdentifier: "com.apple.Safari",
        }),
      };
    },
  });

  assert.deepEqual(calls, ["swift", "osascript"]);
  assert.equal(app.name, "Safari");
  assert.equal(app.bundleIdentifier, "com.apple.Safari");
  assert.equal(app.source, "osascript");
});

test("getFrontmostApp reports a friendly unavailable status", async () => {
  const app = await getFrontmostApp({
    runner: async () => {
      throw new Error("permission denied");
    },
  });

  assert.equal(app.ok, false);
  assert.equal(app.error, "Unable to read the frontmost app.");
});

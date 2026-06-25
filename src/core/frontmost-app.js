import { execFile } from "node:child_process";

const swiftSource = `
import AppKit
import Foundation

let app = NSWorkspace.shared.frontmostApplication
let payload: [String: Any] = [
  "name": app?.localizedName ?? "Unknown",
  "bundleIdentifier": app?.bundleIdentifier ?? "",
  "pid": app?.processIdentifier ?? 0
]
let data = try JSONSerialization.data(withJSONObject: payload)
FileHandle.standardOutput.write(data)
`;

const appleScriptSource = `
ObjC.import("AppKit");

const app = $.NSWorkspace.sharedWorkspace.frontmostApplication;
const payload = {
  name: app && app.localizedName ? ObjC.unwrap(app.localizedName) : "Unknown",
  bundleIdentifier: app && app.bundleIdentifier ? ObjC.unwrap(app.bundleIdentifier) : "",
  pid: app ? app.processIdentifier : 0
};
JSON.stringify(payload);
`;

export async function getFrontmostApp({ runner = runCommand } = {}) {
  try {
    return normalizeAppPayload(await runFrontmostProvider(runner, "swift"), "swift");
  } catch {
    try {
      return normalizeAppPayload(await runFrontmostProvider(runner, "osascript"), "osascript");
    } catch {
      return {
        ok: false,
        error: "Unable to read the frontmost app.",
      };
    }
  }
}

async function runFrontmostProvider(runner, provider) {
  if (provider === "swift") {
    return await runner("swift", ["-e", swiftSource]);
  }

  return await runner("osascript", ["-l", "JavaScript", "-e", appleScriptSource]);
}

function normalizeAppPayload(result, source) {
  const payload = JSON.parse(String(result.stdout ?? "").trim());
  return {
    ok: true,
    name: cleanString(payload.name) || "Unknown",
    bundleIdentifier: cleanString(payload.bundleIdentifier),
    pid: Number(payload.pid) || 0,
    source,
    sampledAt: new Date().toISOString(),
  };
}

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function runCommand(command, args) {
  return new Promise((resolve, reject) => {
    execFile(command, args, { timeout: 3500 }, (error, stdout, stderr) => {
      if (error) {
        reject(error);
        return;
      }

      resolve({ stdout, stderr });
    });
  });
}

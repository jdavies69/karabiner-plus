import { access } from "node:fs/promises";
import { constants } from "node:fs";
import { execFile } from "node:child_process";

export const DEFAULT_KARABINER_CLI_PATH =
  "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli";

export const DEFAULT_BREW_PATHS = [
  "/opt/homebrew/bin/brew",
  "/usr/local/bin/brew",
];

export async function createSystemStatus({
  exists = pathExists,
  run = runCommand,
  karabinerCliPath = DEFAULT_KARABINER_CLI_PATH,
  brewPaths = DEFAULT_BREW_PATHS,
} = {}) {
  const karabinerInstalled = await exists(karabinerCliPath);
  const homebrewInstalled = await firstExistingPath(brewPaths, exists);
  const status = {
    karabinerInstalled,
    karabinerCliPath,
    karabinerVersion: null,
    homebrewInstalled: Boolean(homebrewInstalled),
    canInstallWithHomebrew: Boolean(homebrewInstalled),
    settingsGuidance: null,
    currentProfileName: null,
  };

  if (!karabinerInstalled) {
    return status;
  }

  const versionResult = await run(karabinerCliPath, ["--version"]);
  if (versionResult.status === 0) {
    status.karabinerVersion = parseCliVersion(versionResult.stdout);
  }

  const profileResult = await run(karabinerCliPath, ["--show-current-profile-name"]);
  if (profileResult.status === 0) {
    status.currentProfileName = profileResult.stdout.trim() || null;
  }

  const guidanceResult = await run(karabinerCliPath, ["--show-settings-window-guidance"]);
  if (guidanceResult.status === 0) {
    status.settingsGuidance = parseGuidance(guidanceResult.stdout);
  }

  return status;
}

export function parseCliVersion(output) {
  return output.match(/\b\d+\.\d+\.\d+\b/)?.[0] ?? null;
}

export async function commandExists(command, { run = runCommand } = {}) {
  const result = await run("/usr/bin/env", ["command", "-v", command]);
  return result.status === 0;
}

export async function installKarabinerWithHomebrew({ run = runCommand, brewPath } = {}) {
  const command = brewPath ?? (await firstExistingPath(DEFAULT_BREW_PATHS, pathExists));
  if (!command) {
    return {
      ok: false,
      message: "Homebrew was not found. Open the official Karabiner download page instead.",
    };
  }

  const result = await run(command, ["install", "--cask", "karabiner-elements"]);
  return {
    ok: result.status === 0,
    message: result.status === 0 ? result.stdout : result.stderr || result.stdout,
  };
}

export function runCommand(command, args = []) {
  return new Promise((resolve) => {
    execFile(command, args, { timeout: 10 * 60 * 1000 }, (error, stdout, stderr) => {
      resolve({
        status: error?.code ?? 0,
        stdout,
        stderr,
      });
    });
  });
}

async function pathExists(path) {
  try {
    await access(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

async function firstExistingPath(paths, exists) {
  for (const path of paths) {
    if (await exists(path)) {
      return path;
    }
  }
  return null;
}

function parseGuidance(output) {
  try {
    return JSON.parse(output);
  } catch {
    return output.trim() || null;
  }
}

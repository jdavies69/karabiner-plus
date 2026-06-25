import { createServer } from "node:http";
import { existsSync } from "node:fs";
import { mkdir, readFile } from "node:fs/promises";
import { dirname, extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { execFile } from "node:child_process";
import { homedir } from "node:os";

import { planCustomShortcutApplication, planPresetApplication } from "./core/apply.js";
import {
  backupConfig,
  collectExistingTriggers,
  listBackups,
  mergeOwnedRules,
  readKarabinerConfig,
  restoreBackup,
  STARTER_RECOMMENDED_PREFIX,
  writeKarabinerConfig,
} from "./core/config.js";
import { detectConflicts } from "./core/conflicts.js";
import { getFrontmostApp } from "./core/frontmost-app.js";
import { presetCatalog } from "./core/presets.js";
import {
  recommendationPacks,
  recommendPacksForUsage,
  rulesForRecommendationIds,
} from "./core/recommendations.js";
import {
  createSystemStatus,
  installKarabinerWithHomebrew,
} from "./core/system.js";

const moduleDir = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(moduleDir, "..");
const publicDir = join(projectRoot, "public");
const defaultConfigDir = join(homedir(), ".config", "karabiner");
const defaultConfigPath = join(defaultConfigDir, "karabiner.json");
const defaultBackupDir = join(defaultConfigDir, "backups");

export function createKarabinerStarterServer({
  configPath = defaultConfigPath,
  backupDir = defaultBackupDir,
  statusProvider = createSystemStatus,
  installer = installKarabinerWithHomebrew,
  opener = openUrlOrApp,
  frontmostAppProvider = getFrontmostApp,
} = {}) {
  return createServer(async (request, response) => {
    try {
      if (request.method === "GET" && request.url === "/api/status") {
        return sendJson(response, 200, await statusProvider());
      }

      if (request.method === "GET" && request.url === "/api/presets") {
        return sendJson(response, 200, { presets: presetCatalog });
      }

      if (request.method === "GET" && request.url === "/api/frontmost-app") {
        return sendJson(response, 200, await frontmostAppProvider());
      }

      if (request.method === "GET" && request.url === "/api/recommendations") {
        return sendJson(response, 200, { packs: recommendationPacks });
      }

      if (request.method === "POST" && request.url === "/api/recommendations") {
        const body = await readJsonBody(request);
        return sendJson(response, 200, {
          recommendations: recommendPacksForUsage(body.usage),
        });
      }

      if (request.method === "POST" && request.url === "/api/install-karabiner") {
        return sendJson(response, 200, await installer());
      }

      if (request.method === "POST" && request.url === "/api/open-settings") {
        await opener("Karabiner-Elements");
        return sendJson(response, 200, { ok: true });
      }

      if (request.method === "POST" && request.url === "/api/open-download") {
        await opener("https://karabiner-elements.pqrs.org/");
        return sendJson(response, 200, { ok: true });
      }

      if (request.method === "POST" && request.url === "/api/backup") {
        if (!existsSync(configPath)) {
          return sendJson(response, 404, {
            ok: false,
            error: "Karabiner config was not found. Install and open Karabiner-Elements first.",
          });
        }
        const backupPath = await backupConfig({ sourcePath: configPath, backupDir });
        return sendJson(response, 200, { ok: true, backupPath });
      }

      if (request.method === "GET" && request.url === "/api/backups") {
        return sendJson(response, 200, { backups: await listBackups(backupDir) });
      }

      if (request.method === "POST" && request.url === "/api/restore") {
        const body = await readJsonBody(request);
        if (!body.backupPath) {
          return sendJson(response, 400, { ok: false, error: "backupPath is required" });
        }
        const result = await restoreBackup({
          backupPath: body.backupPath,
          configPath,
          backupDir,
        });
        return sendJson(response, 200, result);
      }

      if (request.method === "POST" && request.url === "/api/apply") {
        return await handleApply(request, response, { configPath, backupDir });
      }

      if (request.method === "POST" && request.url === "/api/apply-custom") {
        return await handleApplyCustom(request, response, { configPath, backupDir });
      }

      if (request.method === "POST" && request.url === "/api/apply-recommendations") {
        return await handleApplyRecommendations(request, response, { configPath, backupDir });
      }

      if (request.method === "GET") {
        return await serveStatic(request, response);
      }

      sendJson(response, 405, { ok: false, error: "Method not allowed" });
    } catch (error) {
      sendJson(response, 500, {
        ok: false,
        error: error.message,
      });
    }
  });
}

async function handleApplyCustom(request, response, { configPath, backupDir }) {
  if (!existsSync(configPath)) {
    return sendJson(response, 428, {
      ok: false,
      error: "Karabiner config was not found. Install and open Karabiner-Elements first, then apply custom shortcuts.",
    });
  }

  const body = await readJsonBody(request);
  const shortcuts = Array.isArray(body.shortcuts) ? body.shortcuts : [];
  const config = await readKarabinerConfig(configPath);
  const plan = planCustomShortcutApplication(config, shortcuts);

  if (plan.validationErrors?.length > 0) {
    return sendJson(response, 400, {
      ok: false,
      validationErrors: plan.validationErrors,
      warnings: plan.warnings,
    });
  }

  if (!plan.ok) {
    return sendJson(response, 409, {
      ok: false,
      conflicts: plan.conflicts,
      warnings: plan.warnings,
    });
  }

  const backupPath = await backupConfig({ sourcePath: configPath, backupDir });
  await writeKarabinerConfig(configPath, plan.config);

  return sendJson(response, 200, {
    ok: true,
    changed: plan.changed,
    warnings: plan.warnings,
    backupPath,
  });
}

async function handleApplyRecommendations(request, response, { configPath, backupDir }) {
  if (!existsSync(configPath)) {
    return sendJson(response, 428, {
      ok: false,
      error: "Karabiner config was not found. Install and open Karabiner-Elements first, then apply recommendations.",
    });
  }

  const body = await readJsonBody(request);
  const recommendationIds = Array.isArray(body.recommendationIds) ? body.recommendationIds : [];
  const selectedRules = rulesForRecommendationIds(recommendationIds);
  const config = await readKarabinerConfig(configPath);
  const conflicts = detectConflicts({
    selectedRules,
    existingTriggers: collectExistingTriggers(config),
  });

  if (conflicts.length > 0) {
    return sendJson(response, 409, {
      ok: false,
      conflicts,
    });
  }

  const mergeResult = mergeOwnedRules(config, selectedRules, STARTER_RECOMMENDED_PREFIX);
  const backupPath = await backupConfig({ sourcePath: configPath, backupDir });
  await writeKarabinerConfig(configPath, mergeResult.config);

  return sendJson(response, 200, {
    ok: true,
    changed: mergeResult.changed,
    backupPath,
  });
}

async function handleApply(request, response, { configPath, backupDir }) {
  if (!existsSync(configPath)) {
    return sendJson(response, 428, {
      ok: false,
      error: "Karabiner config was not found. Install and open Karabiner-Elements first, then apply presets.",
    });
  }

  const body = await readJsonBody(request);
  const presetIds = Array.isArray(body.presetIds) ? body.presetIds : [];
  const config = await readKarabinerConfig(configPath);
  const plan = planPresetApplication(config, presetIds);

  if (plan.unknownPresetIds?.length > 0) {
    return sendJson(response, 400, {
      ok: false,
      unknownPresetIds: plan.unknownPresetIds,
      error: `Unknown preset id: ${plan.unknownPresetIds.join(", ")}`,
    });
  }

  if (!plan.ok) {
    return sendJson(response, 409, {
      ok: false,
      conflicts: plan.conflicts,
    });
  }

  const backupPath = await backupConfig({ sourcePath: configPath, backupDir });
  await writeKarabinerConfig(configPath, plan.config);

  return sendJson(response, 200, {
    ok: true,
    changed: plan.changed,
    backupPath,
  });
}

async function serveStatic(request, response) {
  const url = new URL(request.url, "http://127.0.0.1");
  const pathname = url.pathname === "/" ? "/index.html" : url.pathname;
  const requestedPath = resolve(publicDir, `.${decodeURIComponent(pathname)}`);

  if (!requestedPath.startsWith(publicDir)) {
    return sendText(response, 403, "Forbidden", "text/plain");
  }

  try {
    const content = await readFile(requestedPath);
    sendBuffer(response, 200, content, contentTypeFor(requestedPath));
  } catch {
    sendText(response, 404, "Not found", "text/plain");
  }
}

function readJsonBody(request) {
  return new Promise((resolve, reject) => {
    let body = "";

    request.setEncoding("utf8");
    request.on("data", (chunk) => {
      body += chunk;
    });
    request.on("end", () => {
      if (!body) {
        resolve({});
        return;
      }

      try {
        resolve(JSON.parse(body));
      } catch (error) {
        reject(error);
      }
    });
    request.on("error", reject);
  });
}

function sendJson(response, statusCode, payload) {
  sendText(response, statusCode, JSON.stringify(payload), "application/json");
}

function sendText(response, statusCode, text, contentType) {
  response.writeHead(statusCode, {
    "content-type": `${contentType}; charset=utf-8`,
  });
  response.end(text);
}

function sendBuffer(response, statusCode, buffer, contentType) {
  response.writeHead(statusCode, {
    "content-type": contentType,
  });
  response.end(buffer);
}

function contentTypeFor(path) {
  switch (extname(path)) {
    case ".css":
      return "text/css; charset=utf-8";
    case ".js":
      return "text/javascript; charset=utf-8";
    case ".html":
      return "text/html; charset=utf-8";
    default:
      return "application/octet-stream";
  }
}

function openUrlOrApp(target) {
  return new Promise((resolve) => {
    const args = target.startsWith("http") ? [target] : ["-a", target];
    execFile("open", args, () => resolve());
  });
}

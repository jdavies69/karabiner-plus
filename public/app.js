const endpoints = {
  status: "/api/status",
  presets: "/api/presets",
  install: "/api/install-karabiner",
  settings: "/api/open-settings",
  download: "/api/open-download",
  backup: "/api/backup",
  backups: "/api/backups",
  restore: "/api/restore",
  apply: "/api/apply",
};

const state = {
  status: null,
  presets: [],
  selectedPresetIds: new Set(),
  selectionInitialized: false,
  conflicts: [],
  warnings: [],
  backups: [],
  selectedBackupPath: "",
  logs: [],
  busy: new Set(),
  loading: false,
};

const els = {
  syncState: byId("syncState"),
  refreshButton: byId("refreshButton"),
  overallStatus: byId("overallStatus"),
  overallDot: byId("overallDot"),
  overallText: byId("overallText"),
  karabinerState: byId("karabinerState"),
  versionState: byId("versionState"),
  homebrewState: byId("homebrewState"),
  profileState: byId("profileState"),
  installStep: byId("installStep"),
  permissionStep: byId("permissionStep"),
  presetStep: byId("presetStep"),
  installButton: byId("installButton"),
  settingsButton: byId("settingsButton"),
  downloadButton: byId("downloadButton"),
  presetList: byId("presetList"),
  presetCount: byId("presetCount"),
  warningList: byId("warningList"),
  warningCount: byId("warningCount"),
  applyHint: byId("applyHint"),
  backupButton: byId("backupButton"),
  applyButton: byId("applyButton"),
  backupList: byId("backupList"),
  refreshBackupsButton: byId("refreshBackupsButton"),
  restoreButton: byId("restoreButton"),
  activityLog: byId("activityLog"),
  clearLogButton: byId("clearLogButton"),
};

addLog("Interface ready. Checking local status.");
bindEvents();
refreshAll();

function byId(id) {
  return document.getElementById(id);
}

function bindEvents() {
  els.refreshButton.addEventListener("click", refreshAll);
  els.installButton.addEventListener("click", () => runAction("install", installKarabiner));
  els.settingsButton.addEventListener("click", () => runAction("settings", openSettings));
  els.downloadButton.addEventListener("click", () => runAction("download", openDownload));
  els.backupButton.addEventListener("click", () => runAction("backup", backupConfig));
  els.applyButton.addEventListener("click", () => runAction("apply", applySelected));
  els.refreshBackupsButton.addEventListener("click", () => runAction("backups", loadBackups));
  els.restoreButton.addEventListener("click", () => runAction("restore", restoreSelectedBackup));
  els.backupList.addEventListener("change", (event) => {
    const input = event.target.closest("[data-backup-option]");
    if (!input) {
      return;
    }

    state.selectedBackupPath = input.value;
    renderControls();
  });
  els.clearLogButton.addEventListener("click", () => {
    state.logs = [];
    renderLog();
  });

  els.presetList.addEventListener("change", (event) => {
    const input = event.target.closest("[data-preset-toggle]");
    if (!input) {
      return;
    }

    if (input.checked) {
      state.selectedPresetIds.add(input.value);
    } else {
      state.selectedPresetIds.delete(input.value);
    }

    state.conflicts = [];
    addLog(`${input.checked ? "Selected" : "Cleared"} ${labelForPreset(input.value)}.`);
    render();
  });
}

async function refreshAll() {
  state.loading = true;
  renderControls();
  setSync("Checking...");

  const results = await Promise.allSettled([loadStatus(), loadPresets(), loadBackups()]);
  const rejected = results.filter((result) => result.status === "rejected");

  state.loading = false;

  if (rejected.length > 0) {
    for (const result of rejected) {
      addLog(result.reason.message || "Unable to refresh local state.", "error");
    }
    setSync("Needs attention");
  } else {
    addLog("Status refreshed.", "success");
    setSync("Current");
  }

  render();
}

async function loadStatus() {
  const payload = await requestJson(endpoints.status);
  const status = unwrapPayload(payload);
  state.status = status;
  absorbSafety(status);
}

async function loadPresets() {
  const payload = await requestJson(endpoints.presets);
  const data = unwrapPayload(payload);
  const normalized = normalizePresets(data);

  state.presets = normalized.presets;
  absorbSafety(data);

  if (!state.selectionInitialized) {
    const selectedIds = normalized.selectedPresetIds.length > 0
      ? normalized.selectedPresetIds
      : state.presets.map((preset) => preset.id);

    state.selectedPresetIds = new Set(selectedIds);
    state.selectionInitialized = true;
  }
}

async function loadBackups() {
  const payload = await requestJson(endpoints.backups);
  const data = unwrapPayload(payload);
  state.backups = Array.isArray(data.backups) ? data.backups : [];

  if (!state.backups.some((backup) => backup.path === state.selectedBackupPath)) {
    state.selectedBackupPath = state.backups[0]?.path || "";
  }
}

async function installKarabiner() {
  addLog("Installing Karabiner-Elements with the local installer endpoint.");
  const payload = await requestJson(endpoints.install, { method: "POST" });
  addLog(messageFromPayload(payload, "Install command completed."), "success");
  await loadStatus();
}

async function openSettings() {
  const payload = await requestJson(endpoints.settings, { method: "POST" });
  addLog(messageFromPayload(payload, "Opened Karabiner Settings."), "success");
}

async function openDownload() {
  const payload = await requestJson(endpoints.download, { method: "POST" });
  addLog(messageFromPayload(payload, "Opened the official Karabiner download page."), "success");
}

async function backupConfig() {
  const payload = await requestJson(endpoints.backup, { method: "POST" });
  const data = unwrapPayload(payload);
  const path = data.backupPath || data.path || data.file || "";
  addLog(path ? `Backup created at ${path}.` : messageFromPayload(payload, "Backup created."), "success");
  await loadBackups();
}

async function applySelected() {
  const presetIds = [...state.selectedPresetIds];
  addLog(`Applying ${presetIds.length} selected preset${presetIds.length === 1 ? "" : "s"}.`);

  const payload = await requestJson(endpoints.apply, {
    method: "POST",
    body: { presetIds: presetIds },
  });

  const data = unwrapPayload(payload);
  absorbSafety(data);

  if (state.conflicts.length > 0) {
    addLog("Apply blocked because conflicts were reported.", "error");
  } else {
    addLog(messageFromPayload(payload, "Selected presets applied."), "success");
  }

  await Promise.allSettled([loadStatus(), loadPresets()]);
  await loadBackups();
}

async function restoreSelectedBackup() {
  if (!state.selectedBackupPath) {
    addLog("Choose a backup before restoring.", "error");
    return;
  }

  const payload = await requestJson(endpoints.restore, {
    method: "POST",
    body: { backupPath: state.selectedBackupPath },
  });
  const data = unwrapPayload(payload);
  addLog(`Restored ${data.backupPath || state.selectedBackupPath}.`, "success");
  if (data.preRestoreBackupPath) {
    addLog(`Pre-restore backup saved at ${data.preRestoreBackupPath}.`, "success");
  }
  await Promise.allSettled([loadStatus(), loadPresets(), loadBackups()]);
}

async function runAction(name, action) {
  if (state.busy.has(name)) {
    return;
  }

  state.busy.add(name);
  renderControls();

  try {
    await action();
  } catch (error) {
    addLog(error.message || "Action failed.", "error");
  } finally {
    state.busy.delete(name);
    render();
  }
}

async function requestJson(url, options = {}) {
  const requestOptions = {
    method: options.method || "GET",
    headers: {
      Accept: "application/json",
    },
  };

  if (options.body !== undefined) {
    requestOptions.headers["Content-Type"] = "application/json";
    requestOptions.body = JSON.stringify(options.body);
  }

  const response = await fetch(url, requestOptions);
  const text = await response.text();
  let payload = {};

  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = { message: text };
    }
  }

  if (!response.ok) {
    throw new Error(messageFromPayload(payload, `${requestOptions.method} ${url} failed with ${response.status}.`));
  }

  return payload;
}

function unwrapPayload(payload) {
  if (!payload || typeof payload !== "object") {
    return {};
  }

  if (payload.data && typeof payload.data === "object") {
    return payload.data;
  }

  return payload;
}

function normalizePresets(payload) {
  const data = unwrapPayload(payload);
  const source = Array.isArray(data)
    ? data
    : Array.isArray(data.presets)
      ? data.presets
      : Array.isArray(data.items)
        ? data.items
        : [];
  const selectedPresetIds = Array.isArray(data.selectedPresetIds)
    ? data.selectedPresetIds.map(String)
    : [];

  return {
    selectedPresetIds,
    presets: source.map((preset) => ({
      id: String(preset.id),
      title: preset.title || preset.name || preset.id,
      summary: preset.summary || preset.description || "Starter Karabiner rule.",
      risk: preset.risk || "low",
      enabled: Boolean(preset.enabled || preset.selected),
    })).filter((preset) => preset.id),
  };
}

function absorbSafety(payload) {
  const data = unwrapPayload(payload);

  if (Array.isArray(data.conflicts)) {
    state.conflicts = data.conflicts;
  }

  if (Array.isArray(data.warnings)) {
    state.warnings = data.warnings;
  }
}

function render() {
  renderStatus();
  renderPresets();
  renderWarnings();
  renderBackups();
  renderControls();
  renderLog();
}

function renderStatus() {
  const status = state.status || {};
  const installed = status.karabinerInstalled === true;
  const hasStatus = state.status !== null;
  const guidance = summarizeGuidance(status.settingsGuidance);
  const needsSettings = installed && guidance.severity === "warning";

  els.karabinerState.textContent = hasStatus ? (installed ? "Installed" : "Not installed") : "Checking...";
  els.versionState.textContent = status.karabinerVersion || "Unknown";
  els.homebrewState.textContent = hasStatus
    ? (status.homebrewInstalled ? "Available" : "Not found")
    : "Checking...";
  els.profileState.textContent = status.currentProfileName || "Unknown";

  setStep(els.installStep, installed ? "complete" : "active");
  setStep(els.permissionStep, needsSettings ? "active" : (installed ? "complete" : ""));
  setStep(els.presetStep, installed && !needsSettings ? "active" : "");

  els.overallDot.className = "status-dot";
  if (!hasStatus) {
    els.overallDot.classList.add("is-checking");
    els.overallText.textContent = "Checking";
  } else if (!installed) {
    els.overallDot.classList.add("is-error");
    els.overallText.textContent = "Install needed";
  } else if (state.conflicts.length > 0 || needsSettings) {
    els.overallDot.classList.add("is-warning");
    els.overallText.textContent = state.conflicts.length > 0 ? "Conflict" : "Review";
  } else {
    els.overallDot.classList.add("is-ready");
    els.overallText.textContent = "Ready";
  }
}

function setStep(element, status) {
  element.classList.remove("is-active", "is-complete");

  if (status === "active") {
    element.classList.add("is-active");
  }

  if (status === "complete") {
    element.classList.add("is-complete");
  }
}

function renderPresets() {
  els.presetList.replaceChildren();

  if (state.presets.length === 0) {
    els.presetList.append(emptyState(state.loading ? "Loading presets..." : "No presets were returned by the local API."));
    renderPresetCount();
    return;
  }

  for (const preset of state.presets) {
    els.presetList.append(presetCard(preset));
  }

  renderPresetCount();
}

function presetCard(preset) {
  const selected = state.selectedPresetIds.has(preset.id);
  const label = document.createElement("label");
  label.className = `preset-card${selected ? " is-selected" : ""}`;

  const input = document.createElement("input");
  input.type = "checkbox";
  input.value = preset.id;
  input.checked = selected;
  input.dataset.presetToggle = "true";

  const switchEl = document.createElement("span");
  switchEl.className = "switch";
  switchEl.setAttribute("aria-hidden", "true");

  const copy = document.createElement("span");
  copy.className = "preset-copy";

  const top = document.createElement("span");
  top.className = "preset-top";

  const title = document.createElement("strong");
  title.className = "preset-title";
  title.textContent = preset.title;

  const risk = document.createElement("span");
  risk.className = "risk-pill";
  risk.textContent = `${preset.risk} risk`;

  const summary = document.createElement("p");
  summary.className = "preset-summary";
  summary.textContent = preset.summary;

  const id = document.createElement("code");
  id.className = "preset-id";
  id.textContent = preset.id;

  top.append(title, risk);
  copy.append(top, summary, id);
  label.append(input, switchEl, copy);

  return label;
}

function renderPresetCount() {
  const selectedCount = state.selectedPresetIds.size;
  const total = state.presets.length;
  els.presetCount.textContent = `${selectedCount} of ${total} selected`;
}

function renderWarnings() {
  const warnings = computedWarnings();
  els.warningList.replaceChildren();
  els.warningCount.textContent = String(warnings.length);

  if (warnings.length === 0) {
    els.warningList.append(emptyState("Clear. No conflicts reported for the selected presets."));
    return;
  }

  for (const warning of warnings) {
    const item = document.createElement("div");
    item.className = `warning-item${warning.type === "conflict" ? " is-conflict" : ""}`;

    const title = document.createElement("strong");
    title.textContent = warning.title;

    const detail = document.createElement("span");
    detail.textContent = warning.detail;

    item.append(title, detail);

    if (warning.code) {
      const code = document.createElement("code");
      code.textContent = warning.code;
      item.append(code);
    }

    els.warningList.append(item);
  }
}

function renderBackups() {
  els.backupList.replaceChildren();

  if (state.backups.length === 0) {
    els.backupList.append(emptyState("No backups yet. Create one before applying changes."));
    return;
  }

  for (const backup of state.backups.slice(0, 6)) {
    const label = document.createElement("label");
    label.className = "backup-option";

    const input = document.createElement("input");
    input.type = "radio";
    input.name = "backup";
    input.value = backup.path;
    input.checked = backup.path === state.selectedBackupPath;
    input.dataset.backupOption = "true";

    const copy = document.createElement("span");
    copy.className = "backup-copy";

    const name = document.createElement("strong");
    name.textContent = backup.name || "Karabiner backup";

    const path = document.createElement("code");
    path.textContent = backup.path;

    copy.append(name, path);
    label.append(input, copy);
    els.backupList.append(label);
  }
}

function computedWarnings() {
  const status = state.status || {};
  const warnings = [];

  if (status.karabinerInstalled === false) {
    warnings.push({
      type: "setup",
      title: "Karabiner is not installed",
      detail: status.homebrewInstalled
        ? "Use the install action, then open settings to approve macOS permissions."
        : "Homebrew was not found. Use the official download action instead.",
    });
  }

  const guidance = summarizeGuidance(status.settingsGuidance);
  if (status.karabinerInstalled && guidance.severity === "warning") {
    warnings.push({
      type: "setup",
      title: "Settings need review",
      detail: guidance.text,
    });
  }

  if (state.presets.length === 0 && !state.loading) {
    warnings.push({
      type: "setup",
      title: "No presets loaded",
      detail: "The preset catalog endpoint did not return selectable rules.",
    });
  }

  if (state.selectedPresetIds.size === 0 && state.presets.length > 0) {
    warnings.push({
      type: "setup",
      title: "Nothing selected",
      detail: "Select at least one starter preset before applying changes.",
    });
  }

  for (const warning of state.warnings) {
    warnings.push(normalizeWarning(warning));
  }

  for (const conflict of state.conflicts) {
    warnings.push(normalizeConflict(conflict));
  }

  return warnings;
}

function normalizeWarning(warning) {
  if (typeof warning === "string") {
    return {
      type: "setup",
      title: "Warning",
      detail: warning,
    };
  }

  return {
    type: warning.type || "setup",
    title: warning.title || "Warning",
    detail: warning.detail || warning.message || "The local API reported a warning.",
    code: warning.code,
  };
}

function normalizeConflict(conflict) {
  const rules = Array.isArray(conflict.rules) ? conflict.rules.join(" vs ") : "Multiple rules";
  return {
    type: "conflict",
    title: "Shortcut conflict",
    detail: rules,
    code: conflict.trigger || conflict.code || "",
  };
}

function renderControls() {
  const status = state.status || {};
  const installed = status.karabinerInstalled === true;
  const selectedCount = state.selectedPresetIds.size;
  const hasConflicts = state.conflicts.length > 0;
  const isLoading = state.loading;
  const applyBlocked = isLoading || !installed || selectedCount === 0 || hasConflicts;
  const restoreBlocked = isLoading || !state.selectedBackupPath;

  els.refreshButton.disabled = isLoading;
  els.installButton.disabled = state.busy.has("install") || installed;
  els.settingsButton.disabled = state.busy.has("settings") || !installed;
  els.downloadButton.disabled = state.busy.has("download") || installed;
  els.backupButton.disabled = state.busy.has("backup") || !installed;
  els.applyButton.disabled = state.busy.has("apply") || applyBlocked;
  els.refreshBackupsButton.disabled = state.busy.has("backups");
  els.restoreButton.disabled = state.busy.has("restore") || restoreBlocked;

  setBusy(els.installButton, state.busy.has("install"));
  setBusy(els.settingsButton, state.busy.has("settings"));
  setBusy(els.downloadButton, state.busy.has("download"));
  setBusy(els.backupButton, state.busy.has("backup"));
  setBusy(els.applyButton, state.busy.has("apply"));
  setBusy(els.restoreButton, state.busy.has("restore"));

  if (!installed) {
    els.applyHint.textContent = "Install Karabiner-Elements before writing starter rules.";
  } else if (hasConflicts) {
    els.applyHint.textContent = "Resolve reported shortcut conflicts before applying presets.";
  } else if (selectedCount === 0) {
    els.applyHint.textContent = "Select at least one preset before applying changes.";
  } else {
    els.applyHint.textContent = `Ready to back up and apply ${selectedCount} preset${selectedCount === 1 ? "" : "s"} to the current profile.`;
  }
}

function setBusy(button, busy) {
  if (busy) {
    button.dataset.busy = "true";
  } else {
    delete button.dataset.busy;
  }
}

function renderLog() {
  els.activityLog.replaceChildren();

  if (state.logs.length === 0) {
    const item = document.createElement("li");
    const time = document.createElement("time");
    time.textContent = "--:--";
    const text = document.createElement("span");
    text.textContent = "No events yet.";
    item.append(time, text);
    els.activityLog.append(item);
    return;
  }

  for (const entry of state.logs.slice(0, 28)) {
    const item = document.createElement("li");
    item.className = `is-${entry.type}`;

    const time = document.createElement("time");
    time.dateTime = entry.iso;
    time.textContent = entry.time;

    const text = document.createElement("span");
    text.textContent = entry.message;

    item.append(time, text);
    els.activityLog.append(item);
  }
}

function addLog(message, type = "info") {
  const now = new Date();
  state.logs.unshift({
    message,
    type,
    iso: now.toISOString(),
    time: now.toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
    }),
  });

  renderLog();
}

function emptyState(message) {
  const item = document.createElement("div");
  item.className = "empty-state";
  item.textContent = message;
  return item;
}

function setSync(text) {
  els.syncState.textContent = text;
}

function summarizeGuidance(guidance) {
  if (!guidance) {
    return {
      severity: "ok",
      text: "No settings guidance reported.",
    };
  }

  if (typeof guidance === "string") {
    return {
      severity: "warning",
      text: guidance,
    };
  }

  if (typeof guidance === "object") {
    const values = Object.values(guidance);
    const blocked = values.some((value) => value === false || value === "false" || value === "missing" || value === "required");
    return {
      severity: blocked ? "warning" : "ok",
      text: blocked
        ? "Karabiner reported at least one permission or settings item that needs review."
        : "Karabiner settings guidance is clear.",
    };
  }

  return {
    severity: "ok",
    text: "No settings guidance reported.",
  };
}

function labelForPreset(id) {
  return state.presets.find((preset) => preset.id === id)?.title || id;
}

function messageFromPayload(payload, fallback) {
  const data = unwrapPayload(payload);
  return data.message || payload?.message || fallback;
}

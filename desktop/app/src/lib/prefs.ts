// UI preferences kept in the webview's localStorage (per user, per machine).
// Project settings will live in <project>/actipass_project.json instead.
// SPDX-License-Identifier: GPL-3.0-or-later

const PREFIX = "actipass.";

export function loadPref<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(PREFIX + key);
    if (raw == null) return fallback;
    const value = JSON.parse(raw);
    return typeof fallback === "object" && fallback !== null && !Array.isArray(fallback)
      ? { ...fallback, ...value }
      : (value as T);
  } catch {
    return fallback;
  }
}

export function savePref<T>(key: string, value: T) {
  try {
    localStorage.setItem(PREFIX + key, JSON.stringify(value));
  } catch {
    // storage unavailable: preferences are not kept
  }
}

/** Folders last picked in a project's file dialogs (kind: "thigh" files, "list" = Excel file
 *  list), remembered as soon as they are picked; "" when none. */
export function projectFolder(project: string, kind: "thigh" | "list"): string {
  return loadPref<Record<string, Record<string, string>>>("folders", {})[project]?.[kind] ?? "";
}

export function rememberProjectFolder(project: string, kind: "thigh" | "list", file: string) {
  if (!project || !file) return;
  const dir = file.replace(/[\\/][^\\/]*$/, "");
  const all = loadPref<Record<string, Record<string, string>>>("folders", {});
  all[project] = { ...all[project], [kind]: dir };
  savePref("folders", all);
}

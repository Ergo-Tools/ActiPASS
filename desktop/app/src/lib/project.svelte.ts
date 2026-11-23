// Current project (result of the engine's project.open).
// SPDX-License-Identifier: GPL-3.0-or-later

import { engine, request, addLog, errorText } from "./engine.svelte";
import { loadPref, savePref } from "./prefs";

export interface ProjectSummary {
  totalFiles: number;
  checkQC: number;
  noWalking: number;
  tooMuchStair: number;
  tooMuchOther: number;
  notEnoughWear: number;
  notEnoughSI: number;
  fileErrors: number;
}

export interface ProjectInfo {
  dir: string;
  exists: boolean;
  empty: boolean;
  hasMasterQC: boolean;
  masterQCFile: string;
  summary: ProjectSummary;
  batches: string[];
  batchFolders: string[];
  lastBatch: string;
  warnings: string[];
  /** the master QC table has trunk / calf columns (false without a master QC table) */
  masterTrunk: boolean;
  masterCalf: boolean;
  /** the master QC table has the raw files' full paths (FilePath; not in older projects) */
  masterFilePaths: boolean;
}

export const project = $state({
  info: null as ProjectInfo | null,
  batch: "",
  loading: false,
  error: "",
  recent: loadPref<string[]>("recentProjects", []),
});

/** true while a job (batch, statistics) runs: the project must not change meanwhile */
export function projectLocked(): boolean {
  return !!engine.busy;
}

export async function openProject(dir: string) {
  if (projectLocked()) {
    addLog("warning", `A job is running (${engine.busy}): the project cannot be changed until it has finished or is canceled.`);
    return;
  }
  project.loading = true;
  project.error = "";
  try {
    const info = await request<ProjectInfo>("project.open", { dir });
    // a project just opened selects its last batch; a refresh of the same project keeps the
    // selection (a finished batch run selects its own batch, see runBatch)
    const same = project.info?.dir === info.dir;
    project.info = info;
    if (!same || !info.batches.includes(project.batch)) project.batch = info.lastBatch;
    project.recent = [dir, ...project.recent.filter((d) => d !== dir)].slice(0, 8);
    savePref("recentProjects", project.recent);
  } catch (e) {
    project.error = errorText(e);
    addLog("error", `project.open: ${project.error}`);
  } finally {
    project.loading = false;
  }
}

export function projectName(): string {
  const d = project.info?.dir ?? "";
  return d.split(/[\\/]/).filter(Boolean).pop() ?? "";
}

/** Close the project (not while a job runs): the page shows the recent projects again;
 *  +page.svelte clears everything that belonged to it (batch inputs, QC, log, settings). */
export function closeProject() {
  if (projectLocked()) {
    addLog("warning", "A job is running: the project cannot be closed until it has finished or is canceled.");
    return;
  }
  project.info = null;
  project.batch = "";
  project.error = "";
}

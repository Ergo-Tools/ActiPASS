// Project and batch checks: one place that says whether everything chosen so far fits
// together. Users may go back and change anything at any time (no locked workflow as in the
// App Designer GUI), so pages, the sidebar and the Process page all read these checks.
//   error:   blocks "Start batch"
//   warning: the batch can run, but the result may not be what was meant
// SPDX-License-Identifier: GPL-3.0-or-later

import { engine } from "./engine.svelte";
import { project } from "./project.svelte";
import { batch, secondaryFolder, scanKey } from "./batch.svelte";
import type { StageId } from "./stages";

export interface Check { stage: StageId; level: "error" | "warning"; text: string }

export function checks(): Check[] {
  const c: Check[] = [];
  const add = (stage: StageId, level: Check["level"], text: string) => c.push({ stage, level, text });
  const s = batch.info?.settings;

  if (engine.status.state !== "connected") add("engine", "error", "The engine is not connected.");

  // project
  if (!project.info?.exists) add("project", "error", "Open a project folder.");
  for (const w of project.info?.warnings ?? []) add("project", "warning", w);

  // data
  const scan = batch.scan;
  if (batch.scanning) add("data", "error", "Reading the accelerometer files…");
  else if (!scan?.rows.length) add("data", "error", "Choose accelerometer files.");
  else {
    if (batch.scanKey !== scanKey()) add("data", "error", "Subject IDs are being updated for the current project and ID settings…");
    if (scan.status) add("data", "warning", scan.status);
    if (scan.needsSensorLocation && !batch.sensorLocation) add("data", "error", "Choose the sensor placement.");
    for (const which of ["trunk", "calf"] as const) {
      const name = which === "trunk" ? "Trunk" : "Calf";
      const f = secondaryFolder(which);
      const on = !!s && (which === "trunk" ? s.TRUNKPOS : s.CALFPOS) !== "off";
      const inList = which === "trunk" ? scan.trunkFiles : scan.calfFiles;
      if (f.needed && !f.dir) add("data", "error", `Choose the ${which} accelerometer folder.`);
      if (f.sameAsThigh) add("data", "warning", `${name} folder is the thigh folder and no prefix/suffix is set: the thigh files would be found as ${which} files.`);
      if (inList && !on) add("data", "warning", `The file list has ${which} files, but the ${which} accelerometer is off: they are not used.`);
      if (inList && on) {
        const n = scan.rows.filter((r) => !(which === "trunk" ? r.trunkFile : r.calfFile)).length;
        if (n) add("data", "warning", `${n} subject(s) have no ${which} file in the file list.`);
      }
    }
  }

  // project: a trunk/calf setup other than the earlier batches' starts a new master QC table
  if (project.info?.hasMasterQC && s) {
    const parts: string[] = [];
    if ((s.TRUNKPOS !== "off") !== project.info.masterTrunk) parts.push(`trunk ${s.TRUNKPOS !== "off" ? "on" : "off"}`);
    if ((s.CALFPOS !== "off") !== project.info.masterCalf) parts.push(`calf ${s.CALFPOS !== "off" ? "on" : "off"}`);
    if (parts.length) add("data", "warning", `The earlier batches of this project were processed with another trunk/calf setup (now ${parts.join(", ")}): ` +
      "the master QC table gets other columns, so the current one is moved to Backups and a new one is started.");
  }

  // settings: the raw+posture intensity algorithm is experimental
  if (typeof s?.INT_ALG === "string" && s.INT_ALG.startsWith("raw+posture")) add("settings", "warning", "The raw+posture intensity algorithm is experimental: check its results before you use them.");

  // diary and calibration
  if (!batch.diaryFile && !batch.noDiary) add("diary", "error", "Choose a diary or 'No diary'.");
  if (!batch.calFile && !batch.noCal) add("diary", "error", "Choose a calibration file or 'No calibration file'.");

  return c;
}

export function stageChecks(stage: StageId): Check[] {
  return checks().filter((x) => x.stage === stage);
}

export function blocking(): Check[] {
  return checks().filter((x) => x.level === "error");
}

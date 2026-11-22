// Settings shown in the app and the inputs of the next batch.
// SPDX-License-Identifier: GPL-3.0-or-later

import { request, runJob, addLog, errorText, CANCELED, type RpcError } from "./engine.svelte";
import { project, openProject } from "./project.svelte";
import type { ProjectSummary } from "./project.svelte";
import type { Licence } from "./licence";

export interface AppSettings {
  Flipped: boolean;
  Rotated: boolean;
  IDMODE: "start" | "end" | "activpal" | "full-filename";
  IDLENGTH: number;
  VISUALIZE: string;
  INT_ALG: string;
  PROPASS: boolean;
  EVALV: boolean;
  TRUNKPOS: string;
  CALFPOS: string;
  TRUNKPREFIX: string;
  TRUNKSUFFIX: string;
  CALFPREFIX: string;
  CALFSUFFIX: string;
  trunkAccDir: string;
  calfAccDir: string;
  thighAccDir: string;
  diary_file: string;
  cal_file: string;
  ADDAUTOCAL: boolean;
  Version: string;
}

export type SettingValue = string | number | boolean | string[];
export type ParamValue = number | number[];

export interface SettingsInfo {
  /** all settings of settings.schema.json plus a few shown ones (paths, PROPASS, EVALV, Version) */
  settings: AppSettings & Record<string, SettingValue>;
  /** algorithm parameters (ParamsAP) */
  params: Record<string, ParamValue>;
  defaults: { settings: Record<string, SettingValue>; params: Record<string, ParamValue> };
  schemaJson: string;
  /** "project": the project's own settings; "global": the user's defaults (not saved to the project yet) */
  source: "project" | "global";
  projectDir: string;
  version: string;
  maxFiles: number;
  licence: Licence;
  configFile: string;
}

export interface SchemaSection {
  id: string;
  page: "settings" | "data" | "process" | "stats";
  title: string;
  showIf?: ShowIf;
  hiddenText?: string;
  /** place in the user manual ("Page#anchor", see help.ts) */
  doc?: string;
}
export interface ShowIf { key: string; in?: string[]; notIn?: string[] }
export interface SchemaField {
  key: string;
  section: string;
  label: string;
  type: "choice" | "bool" | "number" | "text" | "multi";
  choices?: { value: string; label?: string }[];
  min?: number;
  max?: number;
  step?: number;
  unit?: string;
  help?: string;
  propass?: boolean;
  showIf?: ShowIf;
  /** place in the user manual ("Page#anchor", see help.ts) */
  doc?: string;
}
export interface Schema { version: number; sections: SchemaSection[]; fields: SchemaField[] }

/** trunkFile/calfFile: full paths from an Excel file list ("" otherwise) */
export interface ScanRow { id: string; file: string; filename: string; trunkFile?: string; calfFile?: string }
export interface ScanResult {
  ftype: number;
  typeName: string;
  needsSensorLocation: boolean;
  status: string;
  rows: ScanRow[];
  trunkFiles: boolean;
  calfFiles: boolean;
}

export interface BatchResult {
  status: string;
  batch: string;
  batchDir: string;
  elapsedSec: number;
  summary: ProjectSummary;
  orientationWarning: string;
  statusText: string;
}

export const batch = $state({
  info: null as SettingsInfo | null,
  files: [] as string[],
  scan: null as ScanResult | null,
  scanning: false,
  diaryFile: "",
  noDiary: false,
  calFile: "",
  noCal: false,
  sensorLocation: "",
  trunkDir: "",
  calfDir: "",
  /** scanKey() of the current scan */
  scanKey: "",
  running: false,
  result: null as BatchResult | null,
  error: "",
});

/** settings errors by key (shown next to the field), and a counter that redraws the fields
 *  after a rejected change so they show the stored value again */
export const settingsUi = $state({ errors: {} as Record<string, string>, rev: 0, schema: null as Schema | null });
let schemaText = "";

/** project, ID format and ID length a file scan is made with (the IDs depend on them;
 *  +page.svelte rescans when it changes) */
export function scanKey(): string {
  const s = batch.info?.settings;
  return `${settingsProjectDir()}|${s?.IDMODE ?? ""}|${s?.IDLENGTH ?? ""}`;
}

/** project whose settings are used: the open project if its folder exists */
export function settingsProjectDir(): string {
  return project.info?.exists ? project.info.dir : "";
}

function takeInfo(info: SettingsInfo) {
  if (info.schemaJson !== schemaText) {
    schemaText = info.schemaJson;
    settingsUi.schema = JSON.parse(info.schemaJson) as Schema;
  }
  batch.info = info;
}

export async function loadSettings() {
  try {
    takeInfo(await request<SettingsInfo>("settings.get", { projectDir: settingsProjectDir() }));
  } catch (e) {
    addLog("error", `settings.get: ${errorText(e)}`);
  }
}

/** change settings and/or algorithm parameters of the open project (saved there at once) */
export async function setSettings(values: Record<string, SettingValue>, params?: Record<string, ParamValue>) {
  const keys = [...Object.keys(values), ...Object.keys(params ?? {})];
  try {
    takeInfo(await request<SettingsInfo>("settings.set", { projectDir: settingsProjectDir(), values, ...(params ? { params } : {}) }));
    for (const k of keys) delete settingsUi.errors[k];
  } catch (e) {
    const msg = errorText(e);
    for (const k of keys) settingsUi.errors[k] = msg;
    settingsUi.rev++;
    addLog("error", `settings.set: ${msg}`);
  }
}

/** the open project's settings become the defaults for new projects (and the App Designer GUI) */
export async function saveSettingsAsDefault() {
  try {
    takeInfo(await request<SettingsInfo>("settings.saveAsDefault", { projectDir: settingsProjectDir() }));
  } catch (e) {
    addLog("error", `settings.saveAsDefault: ${errorText(e)}`);
  }
}

export function fieldVisible(f: { showIf?: ShowIf }, s: Record<string, SettingValue> | undefined): boolean {
  if (!f.showIf || !s) return true;
  const v = String(s[f.showIf.key]);
  if (f.showIf.in) return f.showIf.in.includes(v);
  if (f.showIf.notIn) return !f.showIf.notIn.includes(v);
  return true;
}

export async function scanFiles(files: string[]) {
  batch.files = files;
  batch.scanning = true;
  batch.scanKey = scanKey();
  try {
    batch.scan = await request<ScanResult>("files.scan", { files, projectDir: settingsProjectDir() });
    if (batch.scan.status) addLog("warning", batch.scan.status);
  } catch (e) {
    batch.scan = null;
    addLog("error", `files.scan: ${errorText(e)}`);
  } finally {
    batch.scanning = false;
  }
}

/** Trunk/calf folder of the next batch: needed when the sensor is on and no Excel file list
 *  gives its files (also without prefix/suffix: files are searched as *<prefix><ID><suffix>).
 *  dir: chosen for this batch, else the project's last one (Settings trunkAccDir/calfAccDir).
 *  sameAsThigh: the thigh folder without prefix/suffix, so the thigh files would match. */
export function secondaryFolder(which: "trunk" | "calf") {
  const s = batch.info?.settings;
  const on = !!s && (which === "trunk" ? s.TRUNKPOS : s.CALFPOS) !== "off";
  const fromList = which === "trunk" ? !!batch.scan?.trunkFiles : !!batch.scan?.calfFiles;
  const chosen = which === "trunk" ? batch.trunkDir : batch.calfDir;
  const last = (which === "trunk" ? s?.trunkAccDir : s?.calfAccDir) ?? "";
  const dir = chosen || last;
  const noAffix = !!s && !(which === "trunk" ? s.TRUNKPREFIX || s.TRUNKSUFFIX : s.CALFPREFIX || s.CALFSUFFIX);
  const thighDir = (batch.scan?.rows[0]?.file ?? "").replace(/[\\/][^\\/]*$/, "");
  const norm = (p: string) => p.replace(/[\\/]+$/, "").toLowerCase();
  return {
    needed: on && !fromList,
    fromList: on && fromList,
    dir,
    isLast: !chosen && !!last,
    sameAsThigh: on && !fromList && noAffix && !!dir && !!thighDir && norm(dir) === norm(thighDir),
  };
}

export async function runBatch() {
  if (!project.info) return;
  batch.running = true;
  batch.result = null;
  batch.error = "";
  try {
    batch.result = await runJob<BatchResult>("batch.run", {
      projectDir: project.info.dir,
      files: batch.files,
      diaryFile: batch.noDiary ? "" : batch.diaryFile,
      calFile: batch.noCal ? "" : batch.calFile,
      sensorLocation: batch.sensorLocation,
      trunkDir: secondaryFolder("trunk").needed ? secondaryFolder("trunk").dir : "",
      calfDir: secondaryFolder("calf").needed ? secondaryFolder("calf").dir : "",
    });
    addLog(batch.result.status === "Canceled" ? "warning" : "info", batch.result.statusText || batch.result.status);
  } catch (e) {
    const err = e as RpcError;
    batch.error = err?.code === CANCELED ? "Batch canceled" : errorText(e);
    addLog(err?.code === CANCELED ? "warning" : "error", batch.error);
    if (err?.data?.report) addLog("error", err.data.report);
  } finally {
    batch.running = false;
    await openProject(project.info.dir); // refresh project summary and batch list
    if (batch.result?.batch && project.info?.batches.includes(batch.result.batch)) project.batch = batch.result.batch;
    await loadSettings();
  }
}

/** start a new batch with the same settings (like "Reset Application" for the batch inputs) */
export function newBatch() {
  batch.files = [];
  batch.scan = null;
  batch.diaryFile = "";
  batch.noDiary = false;
  batch.calFile = "";
  batch.noCal = false;
  batch.sensorLocation = "";
  batch.result = null;
  batch.error = "";
}

/** another project: none of the batch inputs (files, diary, calibration, folders) carry over */
export function resetBatchInputs() {
  newBatch();
  batch.trunkDir = "";
  batch.calfDir = "";
  batch.scanKey = "";
}

// Quality check state: the shown QC table (master or one batch), the selected subject and
// QC_Status changes not saved yet (kept when the user visits other pages).
// SPDX-License-Identifier: GPL-3.0-or-later

import { request, errorText, addLog } from "./engine.svelte";

export interface QcTable {
  source: "master" | "batch";
  batch: string;
  file: string;
  columns: string[];
  /** one array per row, texts in column order; null = no value */
  rows: (string | null)[][];
  flags: string[];
  editable: boolean;
}

export const QC_STATUSES = ["OK", "Check", "NotOK"] as const;

export const qc = $state({
  projectDir: "",
  /** "" = master QC table, else a batch name */
  source: "",
  table: null as QcTable | null,
  loading: false,
  error: "",
  selected: "",
  /** subject ID -> new QC_Status (master table only), saved with saveStatus() */
  pending: {} as Record<string, string>,
  saving: false,
});

export function col(t: QcTable | null, name: string): number {
  return t ? t.columns.indexOf(name) : -1;
}

export async function loadQc(projectDir: string, source: string) {
  qc.loading = true;
  qc.error = "";
  try {
    const t = await request<QcTable>("qc.table", { projectDir, batch: source });
    if (qc.projectDir !== projectDir || qc.source !== source) qc.selected = "";
    qc.projectDir = projectDir;
    qc.source = source;
    qc.table = t;
    const ids = t.rows.map((r) => r[col(t, "SubjectID")] ?? "");
    // keep the selection if the subject is still there; else the page selects the first row
    // in its sort order
    if (!ids.includes(qc.selected)) qc.selected = "";
  } catch (e) {
    qc.error = errorText(e);
    qc.table = null;
  } finally {
    qc.loading = false;
  }
}

export function pendingCount(): number {
  return Object.keys(qc.pending).length;
}

export async function saveStatus(): Promise<boolean> {
  const changes = Object.entries(qc.pending).map(([id, status]) => ({ id, status }));
  if (!changes.length || !qc.projectDir) return true;
  qc.saving = true;
  try {
    const r = await request<{ table: QcTable }>("qc.setStatus", { projectDir: qc.projectDir, changes });
    qc.pending = {};
    if (qc.source === "") qc.table = r.table;
    return true;
  } catch (e) {
    addLog("error", `Saving QC_Status: ${errorText(e)}`);
    qc.error = errorText(e);
    return false;
  } finally {
    qc.saving = false;
  }
}

export function discardStatus() {
  qc.pending = {};
}

/** forget the shown table and selection (project closed or another one opened) */
export function resetQc() {
  qc.projectDir = "";
  qc.source = "";
  qc.table = null;
  qc.error = "";
  qc.selected = "";
  qc.pending = {};
}

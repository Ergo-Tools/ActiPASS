// Links from the app to the Actipass user manual (wiki pages Desktop-App-User-Manual and
// Desktop-App-Manual-<page>). A page, section or tool names its place in the manual with `doc`
// ("Page-Name#anchor", see manual(); settings sections in settings.schema.json); the "?"
// buttons open it in the browser. The anchors are the manual's headings: keep both in step.
// SPDX-License-Identifier: GPL-3.0-or-later

import { openUrl } from "@tauri-apps/plugin-opener";

export const MANUAL_BASE = "https://github.com/Ergo-Tools/ActiPASS/wiki/";

/** manual page of each app page */
export const MANUAL_PAGES = {
  index: "Desktop-App-User-Manual",
  project: "Desktop-App-Manual-Project",
  data: "Desktop-App-Manual-Data",
  diary: "Desktop-App-Manual-Diary-and-calibration",
  settings: "Desktop-App-Manual-Settings",
  process: "Desktop-App-Manual-Process",
  qc: "Desktop-App-Manual-Quality-check",
  stats: "Desktop-App-Manual-Statistics",
  tools: "Desktop-App-Manual-Tools",
  engine: "Desktop-App-Manual-Engine",
  about: "Desktop-App-Manual-About",
} as const;

/** doc of a manual page, optionally at a heading's anchor */
export function manual(page: keyof typeof MANUAL_PAGES, anchor = ""): string {
  return MANUAL_PAGES[page] + (anchor ? "#" + anchor : "");
}

export function docUrl(doc: string): string {
  return /^https?:\/\//.test(doc) ? doc : MANUAL_BASE + doc;
}

export function openDoc(doc: string) {
  openUrl(docUrl(doc)).catch(() => {});
}

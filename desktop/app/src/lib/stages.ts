// Sidebar entries: the workflow stages of the Actipass User Guide, then other pages.
// SPDX-License-Identifier: GPL-3.0-or-later

export type StageId =
  | "project" | "data" | "diary" | "settings" | "process" | "qc" | "stats"
  | "tools" | "engine" | "about";

export interface Stage {
  id: StageId;
  label: string;
  workflow: boolean;
  /** what the page will hold (shown while it is a placeholder) */
  planned: string[];
}

export const stages: Stage[] = [
  { id: "project", label: "Project", workflow: true, planned: [] },
  {
    id: "data", label: "Data", workflow: true, planned: [
      "Add accelerometer files or a file list; per-file table with subject ID preview, device type, size",
      "ID format and ID length",
      "Default orientation: flipped (inside-out), rotated (upside-down)",
      "Trunk and calf accelerometers: on/off, prefix/suffix, orientation, matched files",
    ],
  },
  {
    id: "diary", label: "Diary & calibration", workflow: true, planned: [
      "Load diary or continue without; diary quality check shown inline",
      "Device calibration file: load/save, last used",
    ],
  },
  {
    id: "settings", label: "Settings", workflow: true, planned: [
      "Form generated from settings.schema.json (Main, Auto trimming and non-wear, Automatic time-in-bed, Trunk, Calf, Kneeling, QC thresholds)",
      "ProPASS defaults; changes against defaults highlighted; settings saved per project",
    ],
  },
  {
    id: "process", label: "Process", workflow: true, planned: [
      "Pre-flight checks (R for raw+posture, many files, writable project folder)",
      "Start / cancel, per-file progress, live log, batch summary and orientation warning",
    ],
  },
  {
    id: "qc", label: "Quality check", workflow: true, planned: [
      "QC table (sort, filter, edit QC_Status written to the master QC table)",
      "QC figure viewer with previous/next/search, flags, open folders",
    ],
  },
  {
    id: "stats", label: "Statistics", workflow: true, planned: [
      "Choices per statistics run (schema section statsGen): days, day selection, stat domains, diary matching, file exclusion, valid-day criteria; selected batch only",
      "Statistics options (table format, TAI filter, walk MET, bouts) stay on the Settings page",
      "Run with progress; links to the output tables",
    ],
  },
  {
    id: "tools", label: "Tools", workflow: false, planned: [],
  },
  { id: "engine", label: "Engine", workflow: false, planned: [] },
  {
    id: "about", label: "About", workflow: false, planned: [
      "Version, licence status and activation, user guide and variable definitions links, references, acknowledgements",
    ],
  },
];

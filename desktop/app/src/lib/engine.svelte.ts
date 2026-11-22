// Engine connection state for the UI (mirrors src-tauri/src/engine.rs).
// SPDX-License-Identifier: GPL-3.0-or-later

import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { loadPref, savePref } from "./prefs";

export type EngineState = "stopped" | "waiting" | "connected" | "disconnected" | "failed";

export interface EngineStatus {
  state: EngineState;
  mode: "" | "launch" | "compiled" | "attach";
  program: string;
  port: number;
  attachCommand: string;
  engineDir: string;
  hello: {
    engine?: string;
    engineVersion?: string;
    matlabVersion?: string;
    deployed?: boolean;
    pid?: number;
    paths?: { config: string; actipass: string; utils: string; binaryFileSupport: string; actipassFound: boolean; warnings: string[] };
  } | null;
  lastError: string;
}

export interface Progress {
  job: string;
  title: string;
  value: number;
  message: string;
  indeterminate: boolean;
}

export interface LogEntry {
  time: string;
  /** batch: a line of the batch log (Actipass_BatchLog.txt), sent by the engine while the batch runs */
  level: "info" | "warning" | "warnDetail" | "error" | "output" | "system" | "batch" | "tool";
  text: string;
}

/** JSON-RPC error as thrown by request() */
export interface RpcError {
  code: number;
  message: string;
  data?: { identifier?: string; report?: string };
}

export const CANCELED = -32800;
export const BUSY = -32001;

export type EngineMode = "launch" | "compiled" | "attach";

export interface EnginePrefs {
  /** auto: MATLAB in development builds, the compiled engine in release builds */
  mode: "auto" | EngineMode;
  matlab: string;
  /** compiled engine; empty = installed engine (engine_info().compiledExe) */
  exe: string;
  autoStart: boolean;
}

export interface EngineInfo {
  compiledExe: string | null;
  devBuild: boolean;
  engineDir: string;
  /** app version (ActiPASS version in release builds; placeholder in development) */
  appVersion: string;
}

/** Warning when a release app and its engine have different ActiPASS versions */
export function versionMismatch(): string {
  const ev = engine.status.hello?.engineVersion;
  const av = engine.info?.appVersion;
  // the app may carry a pre-release suffix (2026.11.3-alpha); the engine has the plain version
  if (!ev || !av || engine.info?.devBuild || ev === av.replace(/-.*$/, "")) return "";
  return `The engine is version ${ev}, this app is ${av}. Install the engine that came with this app ` +
    `(run its installer again: Actipass folder, engine\\Actipass_Engine_Installer.exe).`;
}

export const engine = $state({
  status: { state: "stopped", mode: "", program: "", port: 0, attachCommand: "", engineDir: "", hello: null, lastError: "" } as EngineStatus,
  progress: null as Progress | null,
  /** method of the job the UI is waiting for ("" = none) */
  busy: "",
  logs: [] as LogEntry[],
  prefs: { mode: "auto", matlab: "matlab", exe: "", autoStart: true, ...loadPref<Partial<EnginePrefs>>("engine", {}) } as EnginePrefs,
  info: null as EngineInfo | null,
});

const MAX_LOGS = 3000;

function now() {
  return new Date().toLocaleTimeString([], { hour12: false });
}

export function addLog(level: LogEntry["level"], text: string, time = now()) {
  engine.logs.push({ time, level, text });
  if (engine.logs.length > MAX_LOGS) engine.logs.splice(0, engine.logs.length - MAX_LOGS);
}

/** MATLAB marks Command Window colour (warnings in orange) with "[\b" ... "]\b" (backspace);
 *  with -batch these markers reach the output as text */
let inWarning = false;

/** level and clean text of an engine output line: MATLAB warnings ("Warning: ...") as
 *  warnings, their code location lines ("> In ...") as warning detail, other stderr as errors */
function outputLine(stream: string, raw: string): { level: LogEntry["level"]; text: string } {
  const opens = raw.includes("[\b");
  const closes = raw.includes("]\b");
  const text = raw.replace(/\[\x08|\]\x08|\x08/g, "");
  const marked = inWarning || opens;
  inWarning = (inWarning || opens) && !closes;
  if (stream === "system") return { level: "system", text };
  if (/^\s*Warning:/.test(text)) return { level: "warning", text };
  if (marked || /^\s*(>\s*)?In\s.*\(line \d+\)/.test(text)) return { level: "warnDetail", text };
  return { level: stream === "stderr" ? "error" : "output", text };
}

export function clearLogs() {
  engine.logs.length = 0;
}

export function saveEnginePrefs() {
  savePref("engine", engine.prefs);
}

// This module registers the Tauri event listeners once (initEngine). Hot module replacement
// would swap the module while the old listeners keep feeding the old state, so the log and
// status silently stop updating: reload the whole page instead.
if (import.meta.hot) import.meta.hot.accept(() => location.reload());

let initialized = false;

export async function initEngine() {
  if (initialized) return;
  initialized = true;

  await listen<EngineStatus>("engine-status", (e) => {
    const prev = engine.status.state;
    engine.status = e.payload;
    if (prev !== e.payload.state) {
      addLog(e.payload.state === "failed" ? "error" : "system",
        `Engine ${e.payload.state}${e.payload.lastError ? ": " + e.payload.lastError : ""}`);
      if (e.payload.state === "connected" && versionMismatch()) addLog("warning", versionMismatch());
    }
  });
  await listen<{ method: string; params: any }>("engine-notification", (e) => {
    const { method, params } = e.payload;
    if (method === "progress") {
      engine.progress = params as Progress;
    } else if (method === "log") {
      addLog(params.level ?? "info", params.text ?? "", params.time);
    } else {
      addLog("system", `${method} ${JSON.stringify(params)}`);
    }
  });
  await listen<{ stream: string; line: string }>("engine-output", (e) => {
    const o = outputLine(e.payload.stream, e.payload.line);
    addLog(o.level, o.text);
  });

  engine.info = await invoke<EngineInfo>("engine_info");
  engine.status = await invoke<EngineStatus>("engine_status");
  if ((engine.status.state === "stopped" || !engine.status.state) && engine.prefs.autoStart) {
    await startEngine();
  } else if (engine.status.state === "connected") {
    void adoptRunningJob();
  }
}

/** The window was reloaded while the engine runs a job (its request belonged to the old
 *  page): lock the pages as for any job until the engine answers pings as idle again. */
async function adoptRunningJob() {
  let adopted = "";
  for (;;) {
    let r: { busy?: boolean; method?: string };
    try {
      r = await request("engine.ping");
    } catch {
      break;
    }
    if (!r.busy) break;
    if (!adopted) {
      if (engine.busy) return; // a job of this page
      adopted = r.method || "job";
      engine.busy = adopted;
      addLog("system", `The engine is running ${adopted} (started before the window was reloaded)`);
    }
    await new Promise((ok) => setTimeout(ok, 3000));
  }
  if (adopted && engine.busy === adopted) {
    engine.busy = "";
    engine.progress = null;
    addLog("system", `${adopted} has finished`);
  }
}

/** Start mode after resolving "auto" */
export function effectiveMode(): EngineMode {
  if (engine.prefs.mode !== "auto") return engine.prefs.mode;
  return engine.info?.devBuild ? "launch" : "compiled";
}

export async function startEngine() {
  const mode = effectiveMode();
  try {
    addLog("system", mode === "launch"
      ? `Starting MATLAB engine (${engine.prefs.matlab || "matlab"} -batch). This takes a while...`
      : mode === "compiled"
        ? `Starting the compiled engine (${engine.prefs.exe || engine.info?.compiledExe || "not found"})`
        : "Waiting for a MATLAB engine to attach");
    engine.status = await invoke<EngineStatus>("engine_start", { mode, matlab: engine.prefs.matlab, exe: engine.prefs.exe });
  } catch (e) {
    addLog("error", String(e));
  }
}

export async function stopEngine() {
  engine.status = await invoke<EngineStatus>("engine_stop");
  engine.busy = "";
  engine.progress = null;
}

/** JSON-RPC request; throws RpcError */
export function request<T = any>(method: string, params: Record<string, unknown> = {}): Promise<T> {
  return invoke<T>("engine_request", { method, params });
}

/** Long-running request with progress (one at a time) */
export async function runJob<T = any>(method: string, params: Record<string, unknown> = {}): Promise<T> {
  engine.busy = method;
  engine.progress = null;
  try {
    return await request<T>(method, params);
  } finally {
    engine.busy = "";
  }
}

export async function cancelJob() {
  try {
    await request("job.cancel");
    addLog("warning", "Cancel requested");
  } catch (e) {
    addLog("error", errorText(e));
  }
}

export function errorText(e: unknown): string {
  if (e && typeof e === "object" && "message" in e) return String((e as RpcError).message);
  return String(e);
}

export function isConnected() {
  return engine.status.state === "connected";
}

// build-release.mjs  Build the Actipass installer with the ActiPASS version.
//
//   npm run build:release        (in app/; extra arguments are passed to `tauri build`)
//   npm run dev:app              (in app/: `tauri dev` with the same version, no engine check)
//
// The version has one source: <param.version> in ActiPASSV2/ActiPASS_UI_MATLAB2024.prj
// (the project the MATLAB GUI is built from). tools/build_engine.m reads the same file for
// the engine exe and its installer. This script
//   1. reads that version (ActiPASSV2 folder from engine-matlab/paths.local.json),
//   2. checks that the engine installer in engine-matlab/build/dist has the same version
//      (otherwise run tools/build_engine.m in MATLAB R2024b first),
//   3. runs `tauri build` with tauri.release.conf.json and {"version": <version>-<PRERELEASE>}, so the
//      app, its Windows file version and the setup name (Actipass_<version>_x64-setup.exe)
//      all carry it. tauri.conf.json keeps a placeholder version for development builds.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "..");
const engineDir = path.join(repo, "engine-matlab");
const appDir = path.join(repo, "app");
/** pre-release suffix of the desktop app ("" for a final release) */
export const PRERELEASE = "alpha";

export function actipassVersion() {
  let cfgFile = path.join(engineDir, "paths.local.json");
  if (!fs.existsSync(cfgFile)) cfgFile = path.join(engineDir, "paths.example.json");
  const cfg = JSON.parse(fs.readFileSync(cfgFile, "utf8"));
  const prj = path.resolve(engineDir, cfg.actipass, "ActiPASS_UI_MATLAB2024.prj");
  const m = fs.readFileSync(prj, "utf8").match(/<param\.version>\s*([^<\s]+)\s*<\/param\.version>/);
  if (!m) throw new Error(`no <param.version> in ${prj}`);
  // Tauri needs semver (x.y.z); the MATLAB GUI uses the same three-part form
  if (!/^\d+\.\d+\.\d+$/.test(m[1])) throw new Error(`version ${m[1]} in ${prj} is not x.y.z`);
  return { version: m[1], prj };
}

function fail(msg) {
  console.error(`build-release: ${msg}`);
  process.exit(1);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  let v;
  try {
    v = actipassVersion();
  } catch (e) {
    fail(e.message);
  }
  console.log(`build-release: version ${v.version} (${v.prj})`);

  // --dev: `tauri dev` with the same version (title bar, About), no engine installer needed
  const dev = process.argv.includes("--dev");
  const distVer = path.join(engineDir, "build", "dist", "version.txt");
  const engineVersion = fs.existsSync(distVer) ? fs.readFileSync(distVer, "utf8").trim() : "";
  if (!dev && engineVersion !== v.version) {
    fail(`engine installer is ${engineVersion || "missing"} (engine-matlab/build/dist), expected ${v.version}.\n` +
      "  Build it first in MATLAB R2024b: cd tools; build_engine");
  }

  const outDir = path.join(appDir, "src-tauri", "target");
  fs.mkdirSync(outDir, { recursive: true });
  const versionConf = path.join(outDir, "version.conf.json");
  // the app carries a pre-release suffix while it is tested (alpha, beta); the engine and the
  // ActiPASS version stay plain, so both GUIs keep one version number
  const appVersion = PRERELEASE ? `${v.version}-${PRERELEASE}` : v.version;
  console.log(`build-release: app version ${appVersion}`);
  fs.writeFileSync(versionConf, JSON.stringify({ version: appVersion }) + "\n");

  const extra = process.argv.slice(2).filter((a) => a !== "--dev");
  const args = dev ? ["tauri", "dev", "--config", versionConf, ...extra]
    : ["tauri", "build", "--config", "src-tauri/tauri.release.conf.json", "--config", versionConf, ...extra];
  const r = spawnSync("npx", args, { cwd: appDir, stdio: "inherit", shell: process.platform === "win32" });
  process.exit(r.status ?? 1);
}

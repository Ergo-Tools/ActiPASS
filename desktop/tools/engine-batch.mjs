// engine-batch.mjs  Run one Actipass batch through the engine (no app), e.g. to compare
// its outputs with a batch run from the App Designer GUI.
//
// Usage (repo root):
//   node tools/engine-batch.mjs --project <dir> --files <dir-or-file> [--diary <xlsx>] [--cal <csv>]
//        [--idmode start --idlength 6] [--flipped 0|1] [--rotated 0|1] [--visualize off|QC|full|extra]
// --files <dir> takes all files in that folder with the extension of --ext (default .cwa).
//
// SPDX-License-Identifier: GPL-3.0-or-later

import fs from "node:fs";
import path from "node:path";
import { startEngine } from "./engine-client.mjs";

const args = {};
for (let i = 2; i < process.argv.length; i += 2) args[process.argv[i].replace(/^--/, "")] = process.argv[i + 1];
if (!args.project || !args.files) {
  console.error("usage: node tools/engine-batch.mjs --project <dir> --files <dir-or-file> [--diary f] [--cal f]");
  process.exit(2);
}

let files = [args.files];
if (fs.statSync(args.files).isDirectory()) {
  const ext = (args.ext ?? ".cwa").toLowerCase();
  files = fs.readdirSync(args.files).filter((f) => f.toLowerCase().endsWith(ext)).map((f) => path.join(args.files, f));
}

let lastMsg = "";
const eng = await startEngine({
  onNotification: (method, p) => {
    if (method === "log") console.log(`[${p.level}] ${p.text}`);
    else if (method === "progress" && p.message !== lastMsg) {
      lastMsg = p.message;
      console.log(`  ${(p.value * 100).toFixed(0).padStart(3)}%  ${p.message}`);
    }
  },
});
console.log(`engine ${eng.hello.engineVersion}, MATLAB ${eng.hello.matlabVersion}`);

try {
  const values = {};
  if (args.idmode) values.IDMODE = args.idmode;
  if (args.idlength) values.IDLENGTH = Number(args.idlength);
  if (args.flipped) values.Flipped = args.flipped === "1";
  if (args.rotated) values.Rotated = args.rotated === "1";
  if (args.visualize) values.VISUALIZE = args.visualize;
  // settings are per project: changes are saved to <project>/ProjectSettings
  const st = await eng.request(Object.keys(values).length ? "settings.set" : "settings.get", { projectDir: args.project, values });
  console.log("licence:", st.licence.mode || "evaluation", "| PROPASS", st.settings.PROPASS, "| settings:",
    JSON.stringify({ IDMODE: st.settings.IDMODE, IDLENGTH: st.settings.IDLENGTH, Flipped: st.settings.Flipped, Rotated: st.settings.Rotated, INT_ALG: st.settings.INT_ALG, VISUALIZE: st.settings.VISUALIZE }));

  const scan = await eng.request("files.scan", { files, projectDir: args.project });
  console.log(`files: ${scan.rows.length} ${scan.typeName}; IDs: ${scan.rows.map((r) => r.id).join(", ")} ${scan.status}`);

  const res = await eng.request("batch.run", {
    projectDir: args.project, files, diaryFile: args.diary ?? "", calFile: args.cal ?? "",
  });
  console.log("RESULT", JSON.stringify(res, null, 2));
} catch (e) {
  console.error("ERROR", e.message ?? e, e.data?.report ?? "");
  process.exitCode = 1;
} finally {
  await eng.close();
}

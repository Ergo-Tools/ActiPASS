// engine-smoke.mjs  Smoke test of the MATLAB engine without the desktop app.
//
// Acts as the UI: listens on 127.0.0.1, starts `matlab -batch actipass_engine(port, token)`,
// checks the hello token, then runs engine.ping, project.open, a demo job that is canceled
// halfway, a full short demo job and engine.shutdown.
//
// Usage (from the repo root):
//   node tools/engine-smoke.mjs [projectDir]
// Env: ACTIPASS_MATLAB = MATLAB executable (default "matlab" on PATH)
//
// SPDX-License-Identifier: GPL-3.0-or-later

import net from "node:net";
import { spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const engineDir = path.resolve(here, "..", "engine-matlab");
const projectDir = process.argv[2] ?? engineDir;
const matlab = process.env.ACTIPASS_MATLAB ?? "matlab";
const token = randomBytes(16).toString("hex");

let nextId = 1;
const pending = new Map();
let sock;
let failed = false;

function check(cond, what) {
  console.log(`${cond ? "PASS" : "FAIL"}  ${what}`);
  if (!cond) failed = true;
}

function request(method, params = {}) {
  const id = nextId++;
  sock.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
  return new Promise((resolve) => pending.set(id, resolve));
}

const server = net.createServer();
server.listen(0, "127.0.0.1", () => {
  const { port } = server.address();
  const q = (s) => s.replaceAll("'", "''");
  const cmd = `cd('${q(engineDir)}'); actipass_engine(${port}, '${token}')`;
  console.log(`listening on ${port}; starting ${matlab} -batch ...`);
  const child = spawn(matlab, ["-batch", cmd], { stdio: ["ignore", "inherit", "inherit"] });
  child.on("exit", (code) => {
    console.log(`MATLAB exited with ${code}`);
    console.log(failed ? "SMOKE TEST FAILED" : "SMOKE TEST PASSED");
    process.exit(failed ? 1 : 0);
  });
});

server.on("connection", (s) => {
  sock = s;
  let buf = "";
  let progressCount = 0;
  let helloSeen = false;
  s.setEncoding("utf8");
  s.on("data", async (chunk) => {
    buf += chunk;
    let i;
    while ((i = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, i);
      buf = buf.slice(i + 1);
      if (!line.trim()) continue;
      const msg = JSON.parse(line);
      if (msg.method === "engine.hello") {
        helloSeen = true;
        check(msg.params.token === token, "hello carries the token");
        check(msg.params.paths.actipassFound === true, "ActiPASSV2 found on the engine path");
        run().catch((e) => { console.error(e); failed = true; });
      } else if (msg.method === "progress") {
        progressCount++;
      } else if (msg.method === "log") {
        console.log(`  log[${msg.params.level}] ${msg.params.text}`);
      } else if (msg.id !== undefined && pending.has(msg.id)) {
        pending.get(msg.id)(msg);
        pending.delete(msg.id);
      }
    }
  });

  async function run() {
    const ping = await request("engine.ping");
    check(ping.result && ping.result.busy === false, "engine.ping");

    const proj = await request("project.open", { dir: projectDir });
    check(proj.result && proj.result.exists === true, `project.open ${projectDir}`);
    console.log("  summary:", JSON.stringify(proj.result?.summary), "batches:", proj.result?.batches?.length);

    const missing = await request("no.such.method");
    check(missing.error && missing.error.code === -32601, "unknown method -> -32601");

    progressCount = 0;
    const job = request("debug.demoJob", { files: 3, steps: 10, delay: 0.1 });
    await new Promise((r) => setTimeout(r, 1200));
    const busy = await request("project.open", { dir: projectDir });
    check(busy.error && busy.error.code === -32001, "request during a job -> busy");
    const cancel = await request("job.cancel");
    check(cancel.result !== undefined, "job.cancel answered");
    const jobRes = await job;
    check(jobRes.error && jobRes.error.code === -32800, "canceled job -> -32800");
    check(progressCount > 3, `progress notifications received (${progressCount})`);

    const job2 = await request("debug.demoJob", { files: 2, steps: 3, delay: 0.05 });
    check(job2.result && job2.result.status === "Demo batch completed", "demo job completes");

    const bye = await request("engine.shutdown");
    check(bye.result && bye.result.stopping === true, "engine.shutdown");
  }
});

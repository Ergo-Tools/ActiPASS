// engine-client.mjs  Minimal app-side client for the engine protocol (for scripts/tests).
//
// startEngine({ matlab, exe, onNotification, onOutput }) listens on 127.0.0.1, starts
// `matlab -batch actipass_engine(port, token)` (or the compiled engine `exe port token`,
// env ACTIPASS_ENGINE_EXE) and resolves with
// { request(method, params), hello, close() } once the engine has said hello.
// request() resolves with the result and rejects with the JSON-RPC error object.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import net from "node:net";
import { spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
export const engineDir = path.resolve(here, "..", "engine-matlab");

export function startEngine({ matlab = process.env.ACTIPASS_MATLAB ?? "matlab", exe = process.env.ACTIPASS_ENGINE_EXE, onNotification = () => {}, onOutput } = {}) {
  const token = randomBytes(16).toString("hex");
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    let child;
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      const q = (s) => s.replaceAll("'", "''");
      const cmd = `cd('${q(engineDir)}'); actipass_engine(${port}, '${token}')`;
      // a compiled engine (ACTIPASS_ENGINE_EXE) takes port and token as arguments
      const [prog, args] = exe ? [exe, [String(port), token]] : [matlab, ["-batch", cmd]];
      child = spawn(prog, args, { stdio: ["ignore", onOutput ? "pipe" : "inherit", onOutput ? "pipe" : "inherit"] });
      if (onOutput) {
        child.stdout.on("data", (d) => onOutput(String(d)));
        child.stderr.on("data", (d) => onOutput(String(d)));
      }
      child.on("exit", (code) => reject(new Error(`MATLAB exited with ${code} before the engine connected`)));
    });

    server.on("connection", (sock) => {
      let buf = "";
      let nextId = 1;
      const pending = new Map();
      let pingTimer;
      sock.setEncoding("utf8");

      const request = (method, params = {}) => {
        const id = nextId++;
        sock.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
        return new Promise((res, rej) => pending.set(id, { res, rej }));
      };

      sock.on("data", (chunk) => {
        buf += chunk;
        let i;
        while ((i = buf.indexOf("\n")) >= 0) {
          const line = buf.slice(0, i);
          buf = buf.slice(i + 1);
          if (!line.trim()) continue;
          const msg = JSON.parse(line);
          if (msg.method === "engine.hello") {
            if (msg.params.token !== token) { sock.destroy(); return; }
            pingTimer = setInterval(() => request("engine.ping").catch(() => {}), 10000);
            child.removeAllListeners("exit");
            resolve({
              hello: msg.params,
              request,
              close: async () => {
                clearInterval(pingTimer);
                await request("engine.shutdown").catch(() => {});
                await new Promise((r) => child.once("exit", r));
                server.close();
              },
            });
          } else if (msg.method) {
            onNotification(msg.method, msg.params);
          } else if (pending.has(msg.id)) {
            const p = pending.get(msg.id);
            pending.delete(msg.id);
            msg.error ? p.rej(msg.error) : p.res(msg.result);
          }
        }
      });
    });
  });
}

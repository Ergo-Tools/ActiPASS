<script lang="ts">
  // SPDX-License-Identifier: GPL-3.0-or-later
  import HelpLink from "../components/HelpLink.svelte";
  import { manual } from "../help";
  import {
    engine, startEngine, stopEngine, saveEnginePrefs, request, runJob, cancelJob,
    addLog, errorText, effectiveMode, versionMismatch, CANCELED, type RpcError,
  } from "../engine.svelte";
  import { open } from "@tauri-apps/plugin-dialog";
  import ProgressBar from "../components/ProgressBar.svelte";

  let connected = $derived(engine.status.state === "connected");
  let running = $derived(engine.status.state !== "stopped" && engine.status.state !== "failed");
  let copied = $state(false);
  let demo = $state({ files: 5, steps: 10, delay: 0.2 });
  let demoResult = $state("");

  async function copyCommand() {
    await navigator.clipboard.writeText(engine.status.attachCommand);
    copied = true;
    setTimeout(() => (copied = false), 1500);
  }

  async function chooseExe() {
    const f = await open({ multiple: false, directory: false });
    if (typeof f === "string") {
      engine.prefs.exe = f;
      saveEnginePrefs();
    }
  }

  async function ping() {
    try {
      const t0 = performance.now();
      const r = await request("engine.ping");
      addLog("info", `engine.ping: ${Math.round(performance.now() - t0)} ms, busy=${r.busy}`);
    } catch (e) {
      addLog("error", `engine.ping: ${errorText(e)}`);
    }
  }

  async function runDemo() {
    demoResult = "";
    try {
      const r = await runJob("debug.demoJob", demo);
      demoResult = r.status;
    } catch (e) {
      demoResult = (e as RpcError)?.code === CANCELED ? "Canceled" : errorText(e);
    }
  }
</script>

<h1>Engine<HelpLink doc={manual("engine")} /></h1>
<p class="muted">
  The analysis runs in a separate engine process (MATLAB now). The app talks to it over a local
  connection (JSON-RPC on 127.0.0.1); only paths and small results are exchanged, outputs stay in the project folder.
</p>

<div class="card">
  <h2>Connection<HelpLink doc={manual("engine", "connection")} label="Connection" /></h2>
  <dl>
    {#if engine.info}<dt>App</dt><dd>Actipass {engine.info.appVersion}{engine.info.devBuild ? " (development build)" : ""}</dd>{/if}
    <dt>State</dt><dd class:ok={connected} class:err={engine.status.state === "failed"}>{engine.status.state}</dd>
    {#if engine.status.program}<dt>Program</dt><dd class="mono">{engine.status.program}</dd>{/if}
    {#if engine.status.port}<dt>Port</dt><dd class="mono">{engine.status.port}</dd>{/if}
    {#if engine.status.hello}
      <dt>Engine</dt><dd>{engine.status.hello.engine} {engine.status.hello.engineVersion}{engine.status.hello.deployed ? " (compiled)" : ""}, pid {engine.status.hello.pid}</dd>
      <dt>MATLAB</dt><dd>{engine.status.hello.matlabVersion}</dd>
      {#if versionMismatch()}<dt></dt><dd class="err">{versionMismatch()}</dd>{/if}
      {#if engine.status.hello.paths}
        <dt>ActiPASSV2</dt>
        <dd class="mono" class:err={!engine.status.hello.paths.actipassFound}>
          {engine.status.hello.paths.actipass || "(compiled in)"}{engine.status.hello.paths.actipassFound ? "" : "  - actipass_UI_Process not found"}
        </dd>
      {/if}
    {/if}
    {#if engine.status.lastError}<dt>Error</dt><dd class="err">{engine.status.lastError}</dd>{/if}
  </dl>
  {#each engine.status.hello?.paths?.warnings ?? [] as w}<p class="warn">{w}</p>{/each}

  <div class="row" style="margin-top:0.75rem">
    <button class="primary" onclick={startEngine}>{running ? "Restart" : "Start"}</button>
    <button onclick={stopEngine} disabled={!running}>Stop</button>
    <button onclick={ping} disabled={!connected}>Ping</button>
  </div>
</div>

<div class="card">
  <h2>Start options<HelpLink doc={manual("engine", "start-options")} label="Start options" /></h2>
  <div class="opts">
    <label><input type="radio" bind:group={engine.prefs.mode} value="auto" onchange={saveEnginePrefs} /> Automatic
      <span class="muted">({engine.info?.devBuild ? "development build: start MATLAB" : "installed engine"})</span></label>
    <label><input type="radio" bind:group={engine.prefs.mode} value="compiled" onchange={saveEnginePrefs} /> Installed engine (compiled, MATLAB Runtime)</label>
    <label><input type="radio" bind:group={engine.prefs.mode} value="launch" onchange={saveEnginePrefs} /> Start MATLAB automatically (<code>matlab -batch</code>)</label>
    <label><input type="radio" bind:group={engine.prefs.mode} value="attach" onchange={saveEnginePrefs} /> Attach to a MATLAB I start myself (debugging)</label>
    <div class="field">Engine program
      <input class="mono" bind:value={engine.prefs.exe} onchange={saveEnginePrefs}
        placeholder={engine.info?.compiledExe ?? "not installed"} />
      <button onclick={chooseExe}>Choose...</button>
    </div>
    {#if effectiveMode() === "compiled" && !engine.prefs.exe && !engine.info?.compiledExe}
      <p class="warn">The compiled engine is not installed. Run the Actipass engine installer, or choose actipass_engine.exe.</p>
    {/if}
    <label class="field">MATLAB executable
      <input class="mono" bind:value={engine.prefs.matlab} onchange={saveEnginePrefs} placeholder="matlab" />
    </label>
    <label><input type="checkbox" bind:checked={engine.prefs.autoStart} onchange={saveEnginePrefs} /> Start the engine when the app opens</label>
  </div>
  <p class="muted">Changes apply at the next start.</p>

  {#if engine.status.attachCommand && engine.status.mode === "attach"}
    <h2 style="margin-top:1rem">Attach command<HelpLink doc={manual("engine", "attach-command")} label="Attach command" /></h2>
    <p>Run this in the MATLAB command window. It can be run again after the engine stopped, until this app restarts the engine.</p>
    <div class="cmd"><code>{engine.status.attachCommand}</code><button onclick={copyCommand}>{copied ? "Copied" : "Copy"}</button></div>
  {/if}
</div>

<div class="card">
  <h2>Test: demo batch</h2>
  <p class="muted">A fake batch in the engine to check progress, log messages and cancel.</p>
  <div class="row">
    <label>Files <input type="number" min="1" max="100" bind:value={demo.files} style="width:5em" /></label>
    <label>Steps per file <input type="number" min="1" max="100" bind:value={demo.steps} style="width:5em" /></label>
    <label>Seconds per step <input type="number" min="0" step="0.05" bind:value={demo.delay} style="width:5em" /></label>
    <button class="primary" onclick={runDemo} disabled={!connected || !!engine.busy}>Run</button>
    <button class="danger" onclick={cancelJob} disabled={engine.busy !== "debug.demoJob"}>Cancel</button>
  </div>
  {#if engine.busy === "debug.demoJob" && engine.progress}
    <div style="margin-top:0.75rem">
      <ProgressBar value={engine.progress.value} />
      <p class="muted" style="margin-top:0.3em">{engine.progress.message}</p>
    </div>
  {/if}
  {#if demoResult}<p style="margin-top:0.75em">{demoResult}</p>{/if}
</div>

<style>
  dl { display: grid; grid-template-columns: max-content 1fr; gap: 0.3rem 1rem; margin: 0; }
  dt { color: var(--muted); }
  dd { margin: 0; word-break: break-all; }
  .opts { display: grid; gap: 0.5rem; }
  .field { display: flex; align-items: center; gap: 0.6rem; }
  .field input { flex: 1; max-width: 36rem; }
  .cmd { display: flex; gap: 0.6rem; align-items: flex-start; background: var(--surface-2); padding: 0.6rem; border-radius: var(--radius); }
  .cmd code { flex: 1; word-break: break-all; }
</style>

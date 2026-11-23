<script lang="ts">
  // SPDX-License-Identifier: GPL-3.0-or-later
  import HelpLink from "../components/HelpLink.svelte";
  import { manual } from "../help";
  import { ask } from "@tauri-apps/plugin-dialog";
  import { revealItemInDir } from "@tauri-apps/plugin-opener";
  import { engine, cancelJob } from "../engine.svelte";
  import { project } from "../project.svelte";
  import { batch, runBatch, newBatch, setSettings } from "../batch.svelte";
  import { checks } from "../checks.svelte";
  import { stages } from "../stages";
  import ProgressBar from "../components/ProgressBar.svelte";

  let connected = $derived(engine.status.state === "connected");
  let s = $derived(batch.info?.settings);
  let all = $derived(checks());
  let todo = $derived(all.filter((c) => c.level === "error"));
  let warnings = $derived(all.filter((c) => c.level === "warning"));
  const pageName = (id: string) => stages.find((x) => x.id === id)?.label ?? id;

  async function start() {
    if (warnings.length && !(await ask("Please check before starting:\n\n" + warnings.map((w) => "• " + w.text).join("\n") +
      "\n\nStart the batch anyway?", { title: "Actipass batch processing", kind: "warning", okLabel: "Start", cancelLabel: "Cancel" }))) return;
    const n = batch.scan?.rows.length ?? 0;
    if (n > 10) {
      const ok = await ask(`You are about to start an Actipass batch process with ${n} files. This can take a long time. ` +
        "Make sure all settings are correct before proceeding.", { title: "Actipass batch processing", kind: "info", okLabel: "Proceed", cancelLabel: "Cancel" });
      if (!ok) return;
    }
    await runBatch();
  }

  const fmt = (sec: number) => `${Math.floor(sec / 3600)} h ${Math.floor((sec % 3600) / 60)} min ${sec % 60} s`;
</script>

<h1>Process<HelpLink doc={manual("process")} /></h1>

{#if !connected || !s}
  <div class="card"><p class="warn">Waiting for the engine (see Engine).</p></div>
{:else}
  <div class="card">
    <h2>Batch<HelpLink doc={manual("process", "batch")} label="Batch" /></h2>
    <dl>
      <dt>Project</dt><dd class="mono">{project.info?.dir ?? "—"}</dd>
      <dt>Files</dt><dd>{batch.scan ? `${batch.scan.rows.length} ${batch.scan.typeName}` : "—"}</dd>
      <dt>ID format</dt><dd>{s.IDMODE}{s.IDMODE === "start" || s.IDMODE === "end" ? `, ${s.IDLENGTH} characters` : ""}</dd>
      <dt>Orientation</dt><dd>{s.Flipped ? "flipped" : "not flipped"}, {s.Rotated ? "rotated" : "not rotated"}</dd>
      <dt>Diary</dt><dd class="mono">{batch.noDiary ? "none" : batch.diaryFile || "—"}</dd>
      <dt>Calibration</dt><dd class="mono">{batch.noCal ? "none" : batch.calFile || "—"}</dd>
      <dt>Trunk / calf</dt><dd>{s.TRUNKPOS} / {s.CALFPOS}</dd>
      <dt>Mode</dt><dd>{s.EVALV ? "Evaluation/ProPASS" : s.PROPASS ? "ProPASS" : "Advanced"}{batch.info?.licence.mode ? `, licence ${batch.info.licence.mode}` : ""}</dd>
      <dt>Intensity</dt><dd>{s.INT_ALG} <span class="muted">(Settings)</span></dd>
    </dl>
    <div class="row" style="margin-top:0.75rem">
      <label>Visualizations
        <select value={s.VISUALIZE} onchange={(e) => setSettings({ VISUALIZE: e.currentTarget.value })} disabled={batch.running}>
          <option>off</option><option>QC</option><option>full</option>
        </select>
      </label>
    </div>
    {#if todo.length}
      <p class="listhead">Needed before Start:</p>
      <ul class="todo">{#each todo as t}<li>{t.text} <span class="muted">({pageName(t.stage)})</span></li>{/each}</ul>
    {/if}
    {#if warnings.length}
      <p class="listhead">Please check:</p>
      <ul class="warnings">{#each warnings as t}<li>{t.text} <span class="muted">({pageName(t.stage)})</span></li>{/each}</ul>
    {/if}
    <div class="row" style="margin-top:0.75rem">
      <button class="primary" onclick={start} disabled={!!todo.length || batch.running || !!engine.busy}>Start batch</button>
      <button class="danger" onclick={cancelJob} disabled={engine.busy !== "batch.run"}>Cancel</button>
      {#if batch.result || batch.error}<button onclick={newBatch} disabled={batch.running}>New batch</button>{/if}
    </div>
  </div>

  {#if batch.running}
    <div class="card">
      <h2>Processing<HelpLink doc={manual("process", "start-processing")} label="Processing" /></h2>
      <ProgressBar value={engine.progress?.value ?? 0} indeterminate={!engine.progress} height={10} />
      <p class="muted" style="margin-top:0.5em">{engine.progress?.message ?? "Starting…"}</p>
    </div>
  {/if}

  {#if batch.error}<div class="card"><p class="err">{batch.error}</p><p class="muted">Details are in the log and in the project's crashLogs folder.</p></div>{/if}

  {#if batch.result}
    {@const r = batch.result}
    <div class="card">
      <h2>{r.status}<HelpLink doc={manual("process", "results")} label="Results" /></h2>
      <p>{r.statusText}</p>
      {#if r.orientationWarning}<p class="warn">{r.orientationWarning}</p>{/if}
      {#if r.summary && "totalFiles" in r.summary}
        <ul class="summary">
          <li>Files in batch: <strong>{r.summary.totalFiles}</strong></li>
          <li>Manual QC recommended: <strong>{r.summary.checkQC}</strong></li>
          <li>File errors: {r.summary.fileErrors}, not enough wear: {r.summary.notEnoughWear}</li>
          <li>No walking: {r.summary.noWalking}, too much other: {r.summary.tooMuchOther}</li>
          <li>Too much stair: {r.summary.tooMuchStair}, not enough sleep intervals: {r.summary.notEnoughSI}</li>
        </ul>
      {/if}
      <p class="muted">Completed in {fmt(r.elapsedSec)}.</p>
      <button onclick={() => revealItemInDir(r.batchDir)}>Show batch folder</button>
    </div>
  {/if}
{/if}

<style>
  dl { display: grid; grid-template-columns: max-content 1fr; gap: 0.3rem 1rem; margin: 0; }
  dt { color: var(--muted); }
  dd { margin: 0; word-break: break-all; }
  label { display: inline-flex; align-items: center; gap: 0.4rem; }
  .listhead { margin: 0.75rem 0 0.2rem; font-weight: 600; }
  .todo { color: var(--err); margin: 0; padding-left: 1.2rem; }
  .warnings { color: var(--warn); margin: 0; padding-left: 1.2rem; }
  .summary { padding-left: 1.2rem; }
</style>

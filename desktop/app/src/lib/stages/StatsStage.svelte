<script lang="ts">
  // Statistics: the choices of each statistics run (schema section statsGen, saved with the
  // project), which batches, epoch data export; runs genStats in the engine ("stats.run").
  // SPDX-License-Identifier: GPL-3.0-or-later
  import HelpLink from "../components/HelpLink.svelte";
  import { manual } from "../help";
  import { revealItemInDir } from "@tauri-apps/plugin-opener";
  import { engine, runJob, cancelJob, addLog, errorText, CANCELED, type RpcError } from "../engine.svelte";
  import { project } from "../project.svelte";
  import { batch, settingsProjectDir } from "../batch.svelte";
  import SettingsSections from "../components/SettingsSections.svelte";
  import ProgressBar from "../components/ProgressBar.svelte";
  import ToolCard from "../components/ToolCard.svelte";

  interface StatsResult { status: string; elapsedSec: number; warnings: string[]; tables: string[] }

  let connected = $derived(engine.status.state === "connected");
  let s = $derived(batch.info?.settings);
  let running = $derived(engine.busy === "stats.run");
  let otherJob = $derived(!!engine.busy && !running);
  let scope = $state<"all" | "batch">("all");
  let chosenBatch = $state("");
  let epoch = $state<"No" | "1s" | "10s" | "60s">("No");
  let result = $state<StatsResult | null>(null);
  let error = $state("");
  let resultCard = $state<HTMLElement>();

  // a finished run: bring the result into view (the page is longer than the window)
  $effect(() => {
    if ((result || error) && resultCard) resultCard.scrollIntoView({ behavior: "smooth", block: "nearest" });
  });

  let batches = $derived(project.info?.batches ?? []);
  $effect(() => {
    if (!batches.includes(chosenBatch)) chosenBatch = project.batch || batches[batches.length - 1] || "";
  });

  let blocked = $derived(
    !settingsProjectDir() ? "Open a project (Project)." :
    !project.info?.hasMasterQC ? "This project has no processed data yet: run a batch first (Process)." :
    s?.EVALV ? "Actipass is running in evaluation mode: statistics generation is disabled." :
    scope === "batch" && !chosenBatch ? "Choose a batch." : "");

  async function run() {
    result = null;
    error = "";
    try {
      result = await runJob<StatsResult>("stats.run", {
        projectDir: settingsProjectDir(),
        batch: scope === "batch" ? chosenBatch : "",
        epochCSV: epoch,
      });
    } catch (e) {
      const err = e as RpcError;
      error = err?.code === CANCELED ? "Statistics generation canceled" : errorText(e);
      addLog(err?.code === CANCELED ? "warning" : "error", error);
    }
  }

  const base = (f: string) => f.split(/[\\/]/).pop();
</script>

<h1>Statistics<HelpLink doc={manual("stats")} /></h1>
<p class="muted">Statistics tables of the processed files of this project. They can be generated again at any time with other choices.</p>

{#if !connected || !s}
  <div class="card"><p class="warn">Waiting for the engine (see Engine).</p></div>
{:else}
  <SettingsSections ids={["statsGen"]} />

  <div class="card">
    <h2>Run<HelpLink doc={manual("stats", "run")} label="Run" /></h2>
    <div class="opts">
      <label><input type="radio" bind:group={scope} value="all" disabled={!!engine.busy} /> All batches of the project</label>
      <label class="row">
        <input type="radio" bind:group={scope} value="batch" disabled={!!engine.busy || !batches.length} /> Selected batch only
        <select bind:value={chosenBatch} disabled={!!engine.busy || scope !== "batch"}>
          {#each batches as b}<option value={b}>{b}</option>{/each}
        </select>
      </label>
      <label class="row">Save epoch level time series (CSV, folder epoch_data)
        <select bind:value={epoch} disabled={!!engine.busy}>
          <option value="No">No</option><option value="1s">1 s</option><option value="10s">10 s</option><option value="60s">60 s</option>
        </select>
      </label>
    </div>
    <p class="muted small">Options used as well (Settings page): table format {s.TblFormat}, TAI filter {s.FilterTAI}, walk MET {s.WalkMET},
      bouts {s.genBouts}; valid duration {s.minValidDur} h.</p>
    {#if blocked}<p class="warn">{blocked}</p>{/if}
    <div class="row">
      <button class="primary" onclick={run} disabled={!!blocked || running || otherJob}>Generate statistics</button>
      <button class="danger" onclick={cancelJob} disabled={!running}>Cancel</button>
      {#if otherJob}<span class="muted">Another job is running ({engine.busy}).</span>{/if}
    </div>
    {#if running}
      <div style="margin-top:0.75rem">
        <ProgressBar value={engine.progress?.value ?? 0} indeterminate={!engine.progress} height={10} />
        <p class="muted" style="margin-top:0.3em">{engine.progress?.message ?? "Starting…"}</p>
      </div>
    {/if}
  </div>

  {#if result || error}
    <div class="card" bind:this={resultCard}>
      <h2>Result<HelpLink doc={manual("stats", "result")} label="Result" /></h2>
      {#if error}
        <p class="err">{error}</p>
      {:else if result}
        <p class="ok">Statistics generated in {result.elapsedSec} s. The tables are in the project folder.</p>
        {#each result.warnings as w}<p class="warn">{w}</p>{/each}
        {#each result.tables as t}
          <div class="row"><span class="mono">{base(t)}</span><button class="link" onclick={() => revealItemInDir(t)}>Show</button></div>
        {/each}
      {/if}
    </div>
  {/if}

  <h2 class="group">More outputs</h2>
  <ToolCard title="Long-format ProPASS table" doc={manual("stats", "long-format-propass-table")} method="tools.longFormat" params={() => ({ projectDir: settingsProjectDir() })}
    blocked={!settingsProjectDir() ? "Open a project first." : ""} runLabel="Convert">
    {#snippet description()}Converts the wide-format ProPASS master table (one row per subject; Daily table format) to
      long format with one row per day: <span class="mono">ProPASS_LongFormat_MasterFile.csv</span>.{/snippet}
  </ToolCard>
  <ToolCard title="Export 1 s data as CSV" doc={manual("stats", "export-1-s-data-as-csv")} method="tools.export1s" params={() => ({ projectDir: settingsProjectDir() })}
    blocked={!settingsProjectDir() ? "Open a project first." : !project.info?.hasMasterQC ? "No processed data yet." : ""} runLabel="Export">
    {#snippet description()}The per-second activity data of every processed subject as CSV files:
      <span class="mono">1S_CSV_Export/&lt;ID&gt; - Activity_per_s.csv</span>.{/snippet}
  </ToolCard>
{/if}

<style>
  .group { margin-top: 1.5rem; }
  .opts { display: grid; gap: 0.5rem; margin-bottom: 0.5rem; }
  .small { font-size: 0.9em; }
  .ok { color: var(--ok); }
  .err { color: var(--err); }
</style>

<script lang="ts">
  // SPDX-License-Identifier: GPL-3.0-or-later
  import { engine, cancelJob } from "../engine.svelte";
  import { project, projectName } from "../project.svelte";
  import type { StageId } from "../stages";
  import ProgressBar from "./ProgressBar.svelte";

  let { current = $bindable() }: { current: StageId } = $props();

  const stateLabel: Record<string, string> = {
    stopped: "Engine stopped",
    waiting: "Engine starting…",
    connected: "Engine ready",
    disconnected: "Engine disconnected",
    failed: "Engine failed",
  };
  let busyLabel = $derived(engine.busy ? "Engine busy" : "");
  // the batch being processed: its name is in the progress title ("Batch <name>") the engine
  // sends from the start; it is not in the project's batch list until it has finished
  let runningBatch = $derived(engine.busy === "batch.run"
    ? (engine.progress?.title ?? "").replace(/^Batch\s+/, "") || "starting…" : "");
  // what the box shows, said explicitly: the project's latest batch, or one picked by the user
  let batchLabel = $derived(project.batch && project.batch === project.info?.lastBatch ? "Last batch" : "Selected batch");
</script>

<header>
  <div class="brand">Actipass</div>

  <div class="project">
    {#if project.info}
      <button class="link name" title={project.info.dir} onclick={() => (current = "project")}>{projectName()}</button>
      {#if runningBatch}
        <span class="muted">Running batch</span>
        <span class="running mono" title="Batch being processed">{runningBatch}</span>
      {:else if project.info.batches.length}
        <label class="muted" for="batch">{batchLabel}</label>
        <select id="batch" bind:value={project.batch} disabled={!!engine.busy}>
          <option value="">—</option>
          {#each project.info.batches as b}<option value={b}>{b}</option>{/each}
        </select>
      {/if}
    {:else}
      <span class="muted">No project open</span>
    {/if}
  </div>

  {#if engine.busy && engine.progress}
    <div class="job">
      <span class="msg" title={engine.progress.message}>{engine.progress.message || engine.progress.title}</span>
      <ProgressBar value={engine.progress.value} indeterminate={engine.progress.indeterminate} />
      <button class="danger" onclick={cancelJob}>Cancel</button>
    </div>
  {/if}

  <button class="engine" onclick={() => (current = "engine")} title="Engine">
    <span class="dot {engine.status.state}" class:busy={!!engine.busy}></span>
    {busyLabel || stateLabel[engine.status.state] || engine.status.state}
  </button>
</header>

<style>
  .running { color: var(--accent); font-weight: 600; white-space: nowrap; }
  header {
    grid-area: top;
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 0 1rem;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    min-width: 0;
  }
  .brand { font-weight: 700; font-size: 1.1rem; color: var(--accent); letter-spacing: 0.02em; }
  .project { display: flex; align-items: center; gap: 0.5rem; flex: 1; min-width: 0; }
  .name { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 22rem; }
  .job { display: grid; grid-template-columns: minmax(8rem, 18rem) 10rem auto; gap: 0.6rem; align-items: center; }
  .msg { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-size: 0.9em; }
  .engine { display: flex; align-items: center; gap: 0.45rem; white-space: nowrap; }
  .dot { width: 0.65rem; height: 0.65rem; border-radius: 50%; background: var(--muted); }
  .dot.connected { background: var(--ok); }
  .dot.waiting { background: var(--warn); animation: pulse 1s ease-in-out infinite alternate; }
  .dot.failed, .dot.disconnected { background: var(--err); }
  .dot.busy { background: var(--accent); animation: pulse 0.6s ease-in-out infinite alternate; }
  @keyframes pulse { from { opacity: 1; } to { opacity: 0.35; } }
</style>

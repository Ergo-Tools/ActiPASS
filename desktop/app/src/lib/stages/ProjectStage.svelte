<script lang="ts">
  // SPDX-License-Identifier: GPL-3.0-or-later
  import HelpLink from "../components/HelpLink.svelte";
  import { manual } from "../help";
  import { open, ask } from "@tauri-apps/plugin-dialog";
  import { revealItemInDir } from "@tauri-apps/plugin-opener";
  import { engine, request, addLog, errorText } from "../engine.svelte";
  import { project, openProject, closeProject, projectLocked } from "../project.svelte";
  import { pendingCount, saveStatus, discardStatus } from "../qc.svelte";

  let connected = $derived(engine.status.state === "connected");

  // ---- clean unfinished or empty batch folders (the GUI's Tools menu item)
  let toDelete = $state<string[]>([]);
  let unfinished = $derived((project.info?.batchFolders ?? []).filter((b) => !project.info?.batches.includes(b)));
  $effect(() => {
    const keep = toDelete.filter((b) => unfinished.includes(b)); // drop names no longer there
    if (keep.length !== toDelete.length) toDelete = keep;
  });

  async function cleanBatches() {
    const dir = project.info?.dir;
    if (!dir || !toDelete.length) return;
    const ok = await ask(`Delete these batch folders permanently? This cannot be undone.\n\n${toDelete.join("\n")}\n\n` +
      "They are not in the master QC table (unfinished, canceled or empty batches).",
      { title: "Clean batch folders", kind: "warning", okLabel: "Delete", cancelLabel: "Cancel" });
    if (!ok) return;
    try {
      const r = await request<{ deleted: string[]; failed: string[] }>("project.cleanBatches", { dir, batches: toDelete });
      if (r.failed.length) addLog("warning", `Not deleted (files in use?): ${r.failed.join(", ")}`);
    } catch (e) {
      addLog("error", `Clean batch folders: ${errorText(e)}`);
    }
    toDelete = [];
    await openProject(dir);
  }

  // unsaved QC_Status changes belong to the open project: save or discard them before leaving it
  async function leaveProject(): Promise<boolean> {
    if (!pendingCount()) return true;
    const save = await ask(`QC_Status of ${pendingCount()} subject(s) changed (Quality check). Save the changes to the master QC table?`,
      { title: "Unsaved quality check", kind: "warning", okLabel: "Save", cancelLabel: "Discard" });
    if (save) return await saveStatus();
    discardStatus();
    return true;
  }
  async function switchTo(dir: string) {
    if (dir !== project.info?.dir && !(await leaveProject())) return;
    await openProject(dir);
  }
  async function close() {
    if (await leaveProject()) closeProject();
  }

  async function chooseFolder() {
    const dir = await open({ directory: true, title: "Choose the Actipass project folder", defaultPath: project.info?.dir });
    if (typeof dir === "string") await switchTo(dir);
  }

  const cards: { key: keyof NonNullable<typeof project.info>["summary"]; label: string; flag?: boolean }[] = [
    { key: "totalFiles", label: "Files in project" },
    { key: "checkQC", label: "Manual QC suggested", flag: true },
    { key: "fileErrors", label: "File errors", flag: true },
    { key: "notEnoughWear", label: "Not enough wear", flag: true },
    { key: "noWalking", label: "No walking", flag: true },
    { key: "tooMuchOther", label: "Too much 'other'", flag: true },
    { key: "tooMuchStair", label: "Too much stair", flag: true },
    { key: "notEnoughSI", label: "Not enough sleep intervals", flag: true },
  ];
</script>

<h1>Project<HelpLink doc={manual("project")} /></h1>
{#if projectLocked()}<p class="warn">A {engine.busy === "stats.run" ? "statistics run" : "batch"} is in progress: the project can be changed when it has finished or is canceled.</p>{/if}
<p class="muted">One project folder holds all outputs: batches, master QC table, individual outputs and statistics.</p>

<div class="card">
  <div class="row">
    <button class="primary" onclick={chooseFolder} disabled={!connected || project.loading || projectLocked()}>Open project folder…</button>
    {#if project.info}
      <button onclick={() => project.info && revealItemInDir(project.info.dir)}>Show in file manager</button>
      <button onclick={() => project.info && openProject(project.info.dir)} disabled={!connected || project.loading || projectLocked()}>Reload</button>
      <button onclick={close} disabled={project.loading || projectLocked()} title="Close the project: its files, choices, quality check and log are cleared">Close project</button>
    {/if}
    {#if project.loading}<span class="muted">Reading project…</span>{/if}
  </div>
  {#if !connected}
    <p class="warn" style="margin-top:0.75em">The engine is not connected yet. See the Engine page.</p>
  {/if}
  {#if project.error}<p class="err" style="margin-top:0.75em">{project.error}</p>{/if}

  {#if project.recent.length && !project.info}
    <h2 style="margin-top:1em">Recent projects<HelpLink doc={manual("project", "recent-projects")} label="Recent projects" /></h2>
    <ul class="recent">
      {#each project.recent as dir}
        <li><button class="link" onclick={() => switchTo(dir)} disabled={!connected || projectLocked()}>{dir}</button></li>
      {/each}
    </ul>
  {/if}
</div>

{#if project.info}
  {@const info = project.info}
  <div class="card">
    <h2 class="mono">{info.dir}<HelpLink doc={manual("project", "project-summary")} label="Project summary" /></h2>
    {#if !info.exists}
      <p class="err">Folder not found.</p>
    {:else if info.empty}
      <p>Empty folder: a new project. Continue with <strong>Data</strong> to choose accelerometer files.</p>
    {:else if !info.hasMasterQC}
      <p class="warn">No master QC table (Actipass_QC_MasterFile.xlsx) yet. Continue with <strong>Data</strong> for a first batch.</p>
    {:else}
      <p>Existing data found. Proceed to quality check or statistics, or choose files for a new batch.</p>
    {/if}
    {#each info.warnings as w}<p class="warn">{w}</p>{/each}
  </div>

  {#if info.hasMasterQC}
    <div class="grid">
      {#each cards as c}
        <div class="stat card" class:flagged={c.flag && info.summary[c.key] > 0}>
          <div class="value">{info.summary[c.key]}</div>
          <div class="muted">{c.label}</div>
        </div>
      {/each}
    </div>
  {/if}

  {#if info.batches.length || info.batchFolders.length}
    <div class="card">
      <h2>Batches<HelpLink doc={manual("project", "batches")} label="Batches" /></h2>
      <ul class="batches">
        {#each info.batchFolders as b}
          <li>
            {#if unfinished.includes(b)}
              <label class="del"><input type="checkbox" value={b} bind:group={toDelete} disabled={projectLocked()} /> <span class="mono">{b}</span></label>
              <span class="warn">not in master QC table (unfinished or empty)</span>
            {:else}
              <span class="mono">{b}</span>
            {/if}
            {#if b === project.batch}<span class="ok">selected</span>{/if}
          </li>
        {/each}
      </ul>
      {#if unfinished.length}
        <div class="row" style="margin-top:0.6rem">
          <button class="danger" onclick={cleanBatches} disabled={!toDelete.length || projectLocked()}
            title="Delete the ticked batch folders (not in the master QC table) permanently">Delete selected folders ({toDelete.length})</button>
          <button class="link" onclick={() => (toDelete = [...unfinished])} disabled={projectLocked()}>Select all unfinished</button>
          <HelpLink doc={manual("project", "clean-unfinished-batches")} label="Clean unfinished batches" />
        </div>
      {/if}
    </div>
  {/if}
{/if}

<style>
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(11rem, 1fr)); gap: 0.75rem; margin-bottom: 1rem; }
  .stat { margin: 0; padding: 0.75rem 0.9rem; }
  .stat .value { font-size: 1.6rem; font-weight: 600; font-variant-numeric: tabular-nums; }
  .stat.flagged .value { color: var(--warn); }
  .recent, .batches { margin: 0; padding-left: 1.1rem; }
  .batches li { display: flex; gap: 0.8rem; padding: 0.15rem 0; }
</style>

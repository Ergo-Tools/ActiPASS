<script lang="ts">
  // Tools that work on a processed project (the GUI's Project > Tools menu). Tools that
  // belong to a page are there: diary quality check (Diary & calibration), long-format
  // ProPASS table and 1 s CSV export (Statistics), cleaning batch folders (Project).
  // SPDX-License-Identifier: GPL-3.0-or-later
  import HelpLink from "../components/HelpLink.svelte";
  import { manual } from "../help";
  import { open } from "@tauri-apps/plugin-dialog";
  import { engine } from "../engine.svelte";
  import { project } from "../project.svelte";
  import { batch } from "../batch.svelte";
  import ToolCard from "../components/ToolCard.svelte";

  let dir = $derived(project.info?.exists ? project.info.dir : "");
  let propass = $derived(!!batch.info?.settings.PROPASS);
  let base = $derived(
    engine.status.state !== "connected" ? "Waiting for the engine (see Engine)." :
    !dir ? "Open a project first (Project)." :
    !project.info?.hasMasterQC ? "This project has no processed data yet: run a batch first (Process)." : "");
  let advanced = $derived(base || (!propass ? "" : batch.info?.licence.evaluation
    ? "Not available in Evaluation/ProPASS mode: needs a licence (About)." : "Not available in ProPASS mode (Settings > Mode)."));
  let oldProject = $derived(!!project.info?.hasMasterQC && !project.info.masterFilePaths);

  // older projects: the raw data folder (the master QC table has no file paths)
  let rawDir = $state("");
  async function chooseRaw() {
    const d = await open({ directory: true, title: "Folder containing the raw accelerometer data files", defaultPath: dir || undefined });
    if (typeof d === "string") rawDir = d;
  }
  let rawBlock = $derived(oldProject && !rawDir ? "Older project: choose the folder with the raw accelerometer files." : "");

  // options, defaults as the GUI
  let fs = $state(25);
  let axOrient = $state("New");
  let filtMode = $state("Löppönen");
  let calMode = $state("upright");
  let prom = $state(50);
  let width = $state(0.2);
  let sep = $state(0.5);
  let exclusions = $state("None");
  let sleepExcl = $state("NotOK");
  // sit-to-stand tools: only OK files by default (as before)
  let stsExcl = $state("Check+NotOK");
  let clinExcl = $state("Check+NotOK");
</script>

<h1>Tools<HelpLink doc={manual("tools")} /></h1>
<p class="muted">Additional analyses of a processed project. Results are written to the project folder.</p>

{#snippet rawFolder()}
  {#if oldProject}
    <span class="row">
      <button onclick={chooseRaw}>Raw data folder…</button>
      <span class="mono small">{rawDir || "not chosen"}</span>
    </span>
  {/if}
{/snippet}

<ToolCard title="Merge sleep data" doc={manual("tools", "merge-sleep-data")} method="tools.mergeSleep" params={() => ({ projectDir: dir, exclusions: sleepExcl })} blocked={advanced}>
  {#snippet description()}Merges the sleep data of the automatic times-of-bed of the files into one table:
    <span class="mono">SleepData_Export/Merged_SleepData.csv</span>, with the processing errors.{/snippet}
  <label title="Files left out based on the automatic QC">Exclude files
    <select bind:value={sleepExcl}><option>None</option><option>NotOK</option><option value="Check+NotOK">Check and NotOK</option></select></label>
</ToolCard>

<ToolCard title="Sit-to-stand angular velocity" doc={manual("tools", "sit-to-stand-angular-velocity")} method="tools.sitToStand" blocked={advanced || rawBlock}
  params={() => ({ projectDir: dir, fs, axOrient, filtMode, calMode, exclusions: stsExcl, ...(oldProject ? { rawDir } : {}) })}>
  {#snippet description()}Experimental. Sit-to-stand transition speeds from the raw data:
    <span class="mono">STS_Export_&lt;filter&gt;_&lt;calibration&gt;</span>.{/snippet}
  <label>Sample rate <select bind:value={fs}><option value={25}>25 Hz</option><option value={50}>50 Hz</option><option value={100}>100 Hz</option></select></label>
  <label title="Axivity CWA axis orientation (other devices: New)">CWA orientation <select bind:value={axOrient}><option>New</option><option>Old</option></select></label>
  <label>Filter <select bind:value={filtMode}><option>Löppönen</option><option>Pickford</option></select></label>
  <label>Calibration <select bind:value={calMode}><option>upright</option><option>standmove</option><option>stand</option></select></label>
  <label title="Files left out based on the automatic QC">Exclude files
    <select bind:value={stsExcl}><option>None</option><option>NotOK</option><option value="Check+NotOK">Check and NotOK</option></select></label>
  {@render rawFolder()}
</ToolCard>

<ToolCard title="Clinical sit-to-stand counts" doc={manual("tools", "clinical-sit-to-stand-counts")} method="tools.clinicalSts" blocked={advanced || rawBlock}
  params={() => ({ projectDir: dir, prom, width, sep, exclusions: clinExcl, ...(oldProject ? { rawDir } : {}) })}>
  {#snippet description()}Experimental. Counts of sit-to-stand transitions in a clinical test from the raw data:
    <span class="mono">Clinical_STS_Counts</span>.{/snippet}
  <label title="Minimum peak prominence">Peak prominence <select bind:value={prom}><option value={40}>40°</option><option value={50}>50°</option><option value={60}>60°</option></select></label>
  <label title="Minimum peak width">Peak width <select bind:value={width}><option value={0.1}>0.1 s</option><option value={0.2}>0.2 s</option><option value={0.3}>0.3 s</option></select></label>
  <label title="Minimum separation between peaks">Peak separation <select bind:value={sep}><option value={0.3}>0.3 s</option><option value={0.5}>0.5 s</option><option value={0.7}>0.7 s</option></select></label>
  <label title="Files left out based on the automatic QC">Exclude files
    <select bind:value={clinExcl}><option>None</option><option>NotOK</option><option value="Check+NotOK">Check and NotOK</option></select></label>
  {@render rawFolder()}
</ToolCard>

<ToolCard title="WBV prediction for sitting segments" doc={manual("tools", "wbv-prediction-for-sitting-segments")} method="tools.wbv" blocked={advanced || rawBlock}
  params={() => ({ projectDir: dir, exclusions, ...(oldProject ? { rawDir } : {}) })}>
  {#snippet description()}Experimental. Whole-body vibration exposure (ISO 2631) of the sitting segments; needs seated
    transport detection on when processing: <span class="mono">WBV_DATA_Filled_all_sitting_segments.csv</span>.{/snippet}
  <label title="Exclude files based on the automatic QC. For short measurements select None">Exclude files
    <select bind:value={exclusions}><option>None</option><option>NotOK</option><option value="Check+NotOK">Check and NotOK</option></select></label>
  {@render rawFolder()}
</ToolCard>

<style>
  .small { font-size: 0.88em; }
</style>

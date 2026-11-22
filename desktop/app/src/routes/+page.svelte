<script lang="ts">
  // SPDX-License-Identifier: GPL-3.0-or-later
  import { onMount } from "svelte";
  import Sidebar from "$lib/components/Sidebar.svelte";
  import TopBar from "$lib/components/TopBar.svelte";
  import LogStrip from "$lib/components/LogStrip.svelte";
  import ProjectStage from "$lib/stages/ProjectStage.svelte";
  import EngineStage from "$lib/stages/EngineStage.svelte";
  import PlaceholderStage from "$lib/stages/PlaceholderStage.svelte";
  import DataStage from "$lib/stages/DataStage.svelte";
  import DiaryStage from "$lib/stages/DiaryStage.svelte";
  import ProcessStage from "$lib/stages/ProcessStage.svelte";
  import SettingsStage from "$lib/stages/SettingsStage.svelte";
  import StatsStage from "$lib/stages/StatsStage.svelte";
  import AboutStage from "$lib/stages/AboutStage.svelte";
  import QcStage from "$lib/stages/QcStage.svelte";
  import ToolsStage from "$lib/stages/ToolsStage.svelte";
  import { stages, type StageId } from "$lib/stages";
  import { initEngine, addLog, clearLogs, engine } from "$lib/engine.svelte";
  import { batch, loadSettings, settingsProjectDir, scanKey, scanFiles, resetBatchInputs, settingsUi } from "$lib/batch.svelte";
  import { resetQc } from "$lib/qc.svelte";
  import { project } from "$lib/project.svelte";
  import LicenceBanner from "$lib/components/LicenceBanner.svelte";
  import LicenceDialog from "$lib/components/LicenceDialog.svelte";
  import { licenceWarning } from "$lib/licence";

  // the licence warning (evaluation mode, expiring soon) also goes to the log, once
  let loggedLicence = "";
  $effect(() => {
    const w = licenceWarning(batch.info?.licence);
    if (w && w !== loggedLicence) addLog("warning", w);
    loggedLicence = w;
  });

  // always start on the first page (Project): the app never resumes inside a workflow step
  let current = $state<StageId>("project");
  let stage = $derived(stages.find((s) => s.id === current) ?? stages[0]);


  // (re)load the settings when an engine connects and when another project is opened
  // (settings are per project)
  $effect(() => {
    const dir = settingsProjectDir();
    if (engine.status.state === "connected") loadSettings();
    void dir;
  });

  // project state rules (see checks.svelte.ts for what is checked):
  // 1. no project is opened automatically (the Project page lists the recent ones): files of
  //    one study must not be processed into another study's project by mistake
  // 2. the subject IDs follow the project and its ID settings: rescan when they change
  $effect(() => {
    const key = scanKey();
    if (batch.info && batch.files.length && !batch.scanning && batch.scanKey !== key) scanFiles(batch.files);
  });
  // 3. another project, or the project closed: the batch inputs, the last result, the quality
  //    check, settings errors and the log belonged to the previous one (the first project
  //    after start keeps the engine's start-up lines)
  let lastDir = "";
  $effect(() => {
    const dir = project.info?.dir ?? "";
    if (dir !== lastDir) {
      if (lastDir && !batch.running) {
        resetBatchInputs();
        resetQc();
        settingsUi.errors = {};
        clearLogs();
        addLog("system", dir ? `Project opened: ${dir}` : `Project closed: ${lastDir}`);
      }
      lastDir = dir;
    }
  });

  onMount(() => {
    initEngine().catch((e) => addLog("error", String(e)));
  });
</script>

<div class="app">
  <TopBar bind:current />
  <Sidebar bind:current />
  <main>
    <div class="content" class:wide={current === "qc"}>
      <LicenceBanner />
      {#if current === "project"}
        <ProjectStage />
      {:else if current === "data"}
        <DataStage />
      {:else if current === "diary"}
        <DiaryStage />
      {:else if current === "process"}
        <ProcessStage />
      {:else if current === "tools"}
        <ToolsStage />
      {:else if current === "qc"}
        <QcStage />
      {:else if current === "about"}
        <AboutStage />
      {:else if current === "stats"}
        <StatsStage />
      {:else if current === "settings"}
        <SettingsStage />
      {:else if current === "engine"}
        <EngineStage />
      {:else}
        <PlaceholderStage {stage} />
      {/if}
    </div>
  </main>
  <LogStrip />
</div>
<LicenceDialog />

<style>
  .app {
    height: 100vh;
    display: grid;
    grid-template-columns: 220px minmax(0, 1fr);
    grid-template-rows: 48px minmax(0, 1fr) auto;
    grid-template-areas:
      "top top"
      "nav main"
      "log log";
  }
  .app > :global(nav) { grid-area: nav; }
  main { grid-area: main; overflow: auto; }
  .content { max-width: 1100px; padding: 1.25rem 1.5rem 2rem; }
  /* pages that use the whole window (quality check: table and figures) */
  .content.wide { max-width: none; padding: 0.9rem 1.1rem 1.5rem; }
</style>

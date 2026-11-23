<script lang="ts">
  // SPDX-License-Identifier: GPL-3.0-or-later
  import HelpLink from "../components/HelpLink.svelte";
  import { manual } from "../help";
  import { open, save } from "@tauri-apps/plugin-dialog";
  import { batch } from "../batch.svelte";
  import ToolCard from "../components/ToolCard.svelte";

  // diary quality check (the GUI's Tools item): any diary, results in a folder of choice
  let qcDiary = $state("");
  let qcOut = $state("");
  async function chooseQcDiary() {
    const f = await open({ title: "Actipass diary to check", defaultPath: batch.diaryFile || undefined,
      filters: [{ name: "Excel files", extensions: ["xlsx", "xls"] }] });
    if (typeof f === "string") { qcDiary = f; if (!qcOut) qcOut = f.replace(/[\\/][^\\/]*$/, ""); }
  }
  async function chooseQcOut() {
    const d = await open({ directory: true, title: "Folder to save the diary quality check in", defaultPath: qcOut || undefined });
    if (typeof d === "string") qcOut = d;
  }

  let s = $derived(batch.info?.settings);
  // "last used" files come from the project's settings; a project without its own settings
  // yet shows the defaults, i.e. the files of the project used before: say so.
  // LoadSettings puts the home folder there when nothing was used: only real file names count.
  let lastDiary = $derived(/\.(xlsx|xls)$/i.test(s?.diary_file ?? "") ? s!.diary_file : "");
  let lastCal = $derived(/\.(csv|xlsx)$/i.test(s?.cal_file ?? "") ? s!.cal_file : "");
  let lastLabel = $derived(batch.info?.source === "project" ? "Last used in this project" : "Last used in another project");

  async function chooseDiary() {
    const f = await open({ title: "Actipass diary", defaultPath: s?.diary_file || undefined,
      filters: [{ name: "Excel files", extensions: ["xlsx", "xls"] }] });
    if (typeof f === "string") { batch.diaryFile = f; batch.noDiary = false; }
  }

  async function chooseCal() {
    const f = await open({ title: "Device calibration file", defaultPath: s?.cal_file || undefined,
      filters: [{ name: "CSV/Excel files", extensions: ["csv", "xlsx"] }] });
    if (typeof f === "string") { batch.calFile = f; batch.noCal = false; }
  }

  async function newCal() {
    const f = await save({ title: "New device calibration file (autocalibration results are added)", defaultPath: s?.cal_file || undefined,
      filters: [{ name: "CSV/Excel files", extensions: ["csv", "xlsx"] }] });
    if (typeof f === "string") { batch.calFile = f; batch.noCal = false; }
  }
</script>

<h1>Diary &amp; calibration<HelpLink doc={manual("diary")} /></h1>

<div class="card">
  <h2>Diary<HelpLink doc={manual("diary", "diary")} label="Diary" /></h2>
  <p class="muted">Optional Actipass-formatted diary: trimming, manual lying/bed/sleep/non-wear periods, intervals such as work and leisure.</p>
  <div class="row">
    <button class="primary" onclick={chooseDiary} disabled={batch.running}>Choose diary…</button>
    {#if lastDiary}<button onclick={() => { batch.diaryFile = lastDiary; batch.noDiary = false; }} disabled={batch.running}
      title={lastDiary}>{lastLabel}</button>{/if}
    <button onclick={() => { batch.noDiary = true; batch.diaryFile = ""; }} disabled={batch.running}>No diary</button>
  </div>
  <p class="mono choice">{batch.noDiary ? "No diary" : batch.diaryFile || "not chosen"}</p>
  {#if lastDiary && !batch.diaryFile && !batch.noDiary}<p class="muted small">{lastLabel}: <span class="mono">{lastDiary}</span></p>{/if}
</div>

<div class="card">
  <h2>Device calibration file<HelpLink doc={manual("diary", "device-calibration-file")} label="Device calibration file" /></h2>
  <p class="muted">
    Optional, strongly recommended: use the same file for all batches.
    {#if s?.ADDAUTOCAL}Autocalibration results are added to it (a new file is created if it does not exist).{:else}Read only (adding autocalibration results is off).{/if}
  </p>
  <div class="row">
    <button class="primary" onclick={chooseCal} disabled={batch.running}>Choose file…</button>
    {#if s?.ADDAUTOCAL}<button onclick={newCal} disabled={batch.running}>New file…</button>{/if}
    {#if lastCal}<button onclick={() => { batch.calFile = lastCal; batch.noCal = false; }} disabled={batch.running}
      title={lastCal}>{lastLabel}</button>{/if}
    <button onclick={() => { batch.noCal = true; batch.calFile = ""; }} disabled={batch.running}>No calibration file</button>
  </div>
  <p class="mono choice">{batch.noCal ? "No calibration file" : batch.calFile || "not chosen"}</p>
  {#if lastCal && !batch.calFile && !batch.noCal}<p class="muted small">{lastLabel}: <span class="mono">{lastCal}</span></p>{/if}
</div>

<ToolCard title="Diary quality check" doc={manual("diary", "diary-quality-check")} method="tools.diaryQC" runLabel="Check diary"
  params={() => ({ diaryFile: qcDiary, outDir: qcOut })}
  blocked={!qcDiary ? "Choose a diary." : !qcOut ? "Choose where to save the check." : ""}>
  {#snippet description()}Checks an Actipass formatted diary before processing: date/time errors, unfinished events,
    and a table of the durations of each event type, saved in <span class="mono">Diary_quality_checks</span>.{/snippet}
  <span class="row">
    <button onclick={chooseQcDiary}>Diary…</button>
    <span class="mono small">{qcDiary || (batch.diaryFile ? "" : "not chosen")}</span>
    {#if !qcDiary && batch.diaryFile}<button class="link" onclick={() => (qcDiary = batch.diaryFile)}>Use the chosen diary</button>{/if}
  </span>
  <span class="row">
    <button onclick={chooseQcOut}>Save in…</button>
    <span class="mono small">{qcOut || "not chosen"}</span>
  </span>
</ToolCard>

<style>
  .choice { margin: 0.75em 0 0; word-break: break-all; }
  .small { font-size: 0.9em; margin: 0.3em 0 0; word-break: break-all; }
</style>

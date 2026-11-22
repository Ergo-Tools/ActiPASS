<script lang="ts">
  // Settings of the open project: processing options (settings.schema.json), licence and
  // ProPASS mode, statistics options (until the Statistics page exists), algorithm parameters.
  // SPDX-License-Identifier: GPL-3.0-or-later
  import HelpLink from "../components/HelpLink.svelte";
  import { manual } from "../help";
  import { ask } from "@tauri-apps/plugin-dialog";
  import { engine } from "../engine.svelte";
  import { projectName } from "../project.svelte";
  import { batch, settingsUi, setSettings, saveSettingsAsDefault, settingsProjectDir, type ParamValue } from "../batch.svelte";
  import SettingsSections from "../components/SettingsSections.svelte";
  import { licenceLabel, propassModeName } from "../licence";

  let info = $derived(batch.info);
  let connected = $derived(engine.status.state === "connected");
  let running = $derived(batch.running || engine.busy === "batch.run");
  let noProject = $derived(!settingsProjectDir());
  let propass = $derived(!!info?.settings.PROPASS);

  async function setProPASS(on: boolean) {
    if (on && !(await ask("ProPASS mode sets all settings and algorithm parameters of this project back to the defaults " +
      "(except ID format, orientation, visualizations, intensity algorithm and file exclusion) and locks them. " +
      "The project's own settings are kept and come back when ProPASS mode is turned off. Continue?",
      { title: "ProPASS mode", kind: "warning" }))) {
      settingsUi.rev++;
      return;
    }
    await setSettings({ PROPASS: on });
  }

  async function saveDefault() {
    if (await ask("Use this project's settings for new projects? They also become the settings of the App Designer GUI.",
      { title: "Save as defaults" })) await saveSettingsAsDefault();
  }

  // ---- algorithm parameters, grouped by name
  const groups: [string, (k: string) => boolean, string][] = [
    ["Resampling and filter", (k) => k === "Fs" || k === "Fc", "Fs: Hz, Fc: Hz"],
    ["Reference positions", (k) => k.startsWith("Vref"), "degrees: min, max or default angles"],
    ["Minimum bout lengths", (k) => k.startsWith("Bout_"), "s"],
    ["Thresholds", (k) => k.startsWith("Threshold_"), ""],
    ["MET values", (k) => k.startsWith("MET_") || k.startsWith("Wlk_"), "MET"],
  ];
  let paramKeys = $derived(Object.keys(info?.params ?? {}));
  function groupKeys(test: (k: string) => boolean) { return paramKeys.filter(test); }
  let otherKeys = $derived(paramKeys.filter((k) => !groups.some(([, t]) => t(k))));
  function pChanged(k: string) { return JSON.stringify(info?.params[k]) !== JSON.stringify(info?.defaults.params[k]); }
  let changedParams = $derived(paramKeys.filter(pChanged));
  function setParam(k: string, i: number, v: number) {
    const cur = info!.params[k];
    const next: ParamValue = Array.isArray(cur) ? cur.map((x, j) => (j === i ? v : x)) : v;
    setSettings({}, { [k]: next });
  }
  function restoreParams() {
    const p: Record<string, ParamValue> = {};
    for (const k of changedParams) p[k] = info!.defaults.params[k];
    setSettings({}, p);
  }
  let paramsDisabled = $derived(running || noProject || propass);
</script>

<h1>Settings<HelpLink doc={manual("settings")} /></h1>
<p class="muted">How the data are processed. Settings belong to the project: each project keeps its own, and every batch uses the settings of its project.</p>

{#if !connected || !info}
  <div class="card"><p class="warn">Waiting for the engine (see Engine).</p></div>
{:else}
  <div class="card">
    <h2>{noProject ? "No project open" : `Project ${projectName()}`}<HelpLink doc={manual("settings", "project-settings")} label="Project settings" /></h2>
    {#if noProject}
      <p class="warn">Open a project to change settings. Shown: your default settings for new projects (read only).</p>
    {:else if info.source === "global"}
      <p>This project has no settings of its own yet; it starts with your defaults. The first change (or the first batch) saves them to the project.</p>
    {:else}
      <p class="muted">Saved in <span class="mono">{info.configFile}</span></p>
    {/if}
    {#if running}<p class="warn">A batch is running: settings are read only until it has finished.</p>{/if}
    <div class="row">
      <button onclick={saveDefault} disabled={noProject || running} title="Use this project's settings for new projects">Save as defaults for new projects</button>
    </div>
  </div>

  <div class="card">
    <h2>Mode<HelpLink doc={manual("settings", "mode")} label="Mode" /></h2>
    <p>{licenceLabel(info.licence)} <span class="muted small">(details on the About page)</span></p>
    {#key settingsUi.rev}
      <label class="check">
        <input type="checkbox" checked={propass} disabled={info.licence.propass || running || noProject}
          onchange={(e) => setProPASS(e.currentTarget.checked)} />
        {propassModeName(info.licence)}
      </label>
    {/key}
    <p class="muted small">
      {info.licence.evaluation ? "Always on in evaluation mode (no valid licence, see About)." : info.licence.propass ? "Always on with a ProPASS licence." :
        "ProPASS default settings and parameters; only ID format, orientation, visualizations, intensity algorithm and file exclusion can be changed."}
    </p>
    {#if settingsUi.errors.PROPASS}<p class="error">{settingsUi.errors.PROPASS}</p>{/if}
  </div>

  <SettingsSections ids={["processing", "nonwear", "bedtime", "trunk", "calf", "qc", "output"]} />

  <h2 class="group">Statistics<HelpLink doc={manual("settings", "statistics-options")} label="Statistics options" /></h2>
  <p class="muted">Options used whenever statistics are generated. The choices made for each statistics run
    (days, day selection, domains, diary matching, file exclusion, valid days) are on the Statistics page.</p>
  <SettingsSections ids={["stats", "bouts"]} />

  <details class="card">
    <summary><h2>Algorithm parameters<HelpLink doc={manual("settings", "algorithm-parameters")} label="Algorithm parameters" /></h2>
      {#if changedParams.length}<span class="muted"> ({changedParams.length} changed)</span>{/if}
    </summary>
    <p class="muted">Expert settings of the activity detection and statistics. Change only if you know what they do.</p>
    {#if propass}<p class="warn">Locked in {propassModeName(info?.licence)}.</p>{/if}
    {#if changedParams.length}
      <button class="link" onclick={restoreParams} disabled={paramsDisabled}>Restore defaults ({changedParams.length})</button>
    {/if}
    {#key settingsUi.rev}
      {#each [...groups.map(([t, test, u]) => [t, groupKeys(test), u] as const), ["Other", otherKeys, ""] as const] as [title, keys, unit]}
        {#if keys.length}
          <h3>{title} {#if unit}<span class="muted small">({unit})</span>{/if}</h3>
          <div class="params">
            {#each keys as k}
              {@const v = info.params[k]}
              <div class="param" class:changed={pChanged(k)} title={pChanged(k) ? `Default: ${JSON.stringify(info.defaults.params[k])}` : undefined}>
                <span class="mono">{k}</span>
                <span class="vals">
                  {#each Array.isArray(v) ? v : [v] as x, i}
                    <input type="number" step="any" value={x} disabled={paramsDisabled}
                      onchange={(e) => setParam(k, i, Number(e.currentTarget.value))} />
                  {/each}
                </span>
                {#if settingsUi.errors[k]}<span class="error">{settingsUi.errors[k]}</span>{/if}
              </div>
            {/each}
          </div>
        {/if}
      {/each}
    {/key}
  </details>
{/if}

<style>
  .check { display: inline-flex; align-items: center; gap: 0.4rem; }
  .small { font-size: 0.88em; }
  .error { color: var(--err); }
  .group { margin-top: 1.5rem; }
  summary { cursor: pointer; list-style-position: outside; }
  summary h2 { display: inline; }
  h3 { font-size: 0.98rem; margin: 1rem 0 0.4rem; }
  .params { display: grid; grid-template-columns: repeat(auto-fill, minmax(20rem, 1fr)); gap: 0.3rem 1.5rem; }
  .param { display: flex; align-items: center; justify-content: space-between; gap: 0.6rem; padding: 0.15rem 0.4rem; border-left: 3px solid transparent; flex-wrap: wrap; }
  .param.changed { border-left-color: var(--accent); }
  .vals { display: flex; gap: 0.3rem; }
  .vals input { width: 5.5em; }
</style>

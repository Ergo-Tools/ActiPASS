<script lang="ts">
  // Data: files of the next batch, subject IDs and how the devices were worn. ID format,
  // orientation and the trunk/calf options are project settings (saved at once, see
  // settings.schema.json); compact rows here, help in tooltips.
  // SPDX-License-Identifier: GPL-3.0-or-later
  import HelpLink from "../components/HelpLink.svelte";
  import { manual } from "../help";
  import { propassModeName } from "../licence";
  import { open } from "@tauri-apps/plugin-dialog";
  import { engine } from "../engine.svelte";
  import { batch, scanFiles, setSettings, settingsProjectDir, settingsUi, secondaryFolder, type SettingValue } from "../batch.svelte";
  import { stageChecks } from "../checks.svelte";
  import { projectFolder, rememberProjectFolder } from "../prefs";

  let connected = $derived(engine.status.state === "connected");
  let s = $derived(batch.info?.settings);
  let running = $derived(batch.running || !!engine.busy);
  let noProject = $derived(!settingsProjectDir());
  /** trunk/calf options are locked in ProPASS mode (ID format and orientation are not) */
  let proLocked = $derived(!!s?.PROPASS);

  const filters = [
    { name: "Accelerometer files", extensions: ["cwa", "wav", "datx", "dat", "csv", "bin", "hex", "npy", "xml"] },
    { name: "Axivity CWA", extensions: ["cwa"] },
    { name: "Axivity WAV", extensions: ["wav"] },
    { name: "ActivPAL DATX", extensions: ["datx", "dat"] },
    { name: "CSV (ActivPAL, ActiGraph, generic)", extensions: ["csv"] },
    { name: "SENS Motion", extensions: ["bin", "hex"] },
  ];

  // dialogs start in the folder last picked in this project (thigh files and Excel lists
  // separately), else the project's thighAccDir (folder of the last batch's first file)
  async function chooseFiles() {
    const dir = settingsProjectDir();
    const picked = await open({ multiple: true, title: "Choose accelerometer files",
      defaultPath: projectFolder(dir, "thigh") || s?.thighAccDir || undefined, filters });
    if (Array.isArray(picked) && picked.length) {
      rememberProjectFolder(dir, "thigh", picked[0]);
      await scanFiles(picked);
    }
  }

  async function chooseList() {
    const dir = settingsProjectDir();
    const picked = await open({ multiple: false, title: "Choose an Excel list of accelerometer files",
      defaultPath: projectFolder(dir, "list") || projectFolder(dir, "thigh") || s?.thighAccDir || undefined,
      filters: [{ name: "Excel file list", extensions: ["xlsx", "xls"] }] });
    if (typeof picked === "string") {
      rememberProjectFolder(dir, "list", picked);
      await scanFiles([picked]);
    }
  }

  async function chooseDir(which: "trunk" | "calf") {
    const d = await open({ directory: true, title: `Folder with ${which} accelerometer files`,
      defaultPath: (which === "trunk" ? s?.trunkAccDir : s?.calfAccDir) || undefined });
    if (typeof d === "string") which === "trunk" ? (batch.trunkDir = d) : (batch.calfDir = d);
  }

  const set = (key: string, v: SettingValue) => setSettings({ [key]: v });
  // checks of this page (checks.svelte.ts), except the obvious "choose files"
  let dataChecks = $derived(stageChecks("data").filter((c) => batch.scan?.rows.length && !batch.scanning));
  const baseName = (p?: string) => (p ?? "").split(/[\\/]/).pop() ?? "";
  const help = (key: string) => settingsUi.schema?.fields.find((f) => f.key === key)?.help ?? "";

  const DATA_KEYS = ["IDMODE", "IDLENGTH", "Flipped", "Rotated", "TRUNKPOS", "TRUNKPREFIX", "TRUNKSUFFIX", "TRUNKFLIP", "TRUNKROT",
    "CALFPOS", "CALFPREFIX", "CALFSUFFIX", "CALFFLIP", "CALFROT"];
  let errors = $derived([...new Set(DATA_KEYS.map((k) => settingsUi.errors[k]).filter(Boolean))]);

</script>

<h1>Data<HelpLink doc={manual("data")} /></h1>
<p class="muted">Accelerometer files of this batch, how subject IDs are read from the file names, and how the devices were worn. Saved with the project.</p>

{#if !connected || !s}
  <div class="card"><p class="warn">Waiting for the engine (see Engine).</p></div>
{:else}
  {#if noProject}
    <div class="card"><p class="warn">Open a project first: ID format, orientation and the trunk/calf options are saved with the project.</p></div>
  {/if}

  {#key settingsUi.rev}
  <div class="card">
    <h2>Subject IDs and orientation<HelpLink doc={manual("data", "subject-ids-and-orientation")} label="Subject IDs and orientation" /></h2>
    <div class="row">
      <label title={help("IDMODE")}>ID format
        <select value={s.IDMODE} onchange={(e) => set("IDMODE", e.currentTarget.value)} disabled={running || noProject}>
          <option value="full-filename">full-filename</option>
          <option value="start">start</option>
          <option value="end">end</option>
          <option value="activpal">activpal</option>
        </select>
      </label>
      <label title={help("IDLENGTH")}>ID length
        <input type="number" min="0" max="20" style="width:5em" value={s.IDLENGTH}
          disabled={s.IDMODE === "full-filename" || s.IDMODE === "activpal" || running || noProject}
          onchange={(e) => set("IDLENGTH", Number(e.currentTarget.value))} />
      </label>
      <label title={help("Flipped")}><input type="checkbox" checked={s.Flipped} onchange={(e) => set("Flipped", e.currentTarget.checked)} disabled={running || noProject} /> Flipped (inside-out)</label>
      <label title={help("Rotated")}><input type="checkbox" checked={s.Rotated} onchange={(e) => set("Rotated", e.currentTarget.checked)} disabled={running || noProject} /> Rotated (upside-down)</label>
    </div>
  </div>
  {/key}

  <div class="card">
    <h2>Accelerometer files<HelpLink doc={manual("data", "accelerometer-files")} label="Accelerometer files" /></h2>
    <div class="row">
      <button class="primary" onclick={chooseFiles} disabled={running}>Choose files…</button>
      <button onclick={chooseList} disabled={running}>Use an Excel file list…</button>
      {#if batch.scanning}<span class="muted">Reading…</span>{/if}
    </div>
    {#if batch.scan}
      <p style="margin-top:0.75em">
        <strong>{batch.scan.rows.length}</strong> file(s){batch.scan.typeName ? `, ${batch.scan.typeName}` : ""}
        {#if batch.info && batch.scan.rows.length >= batch.info.maxFiles}<span class="warn"> (maximum {batch.info.maxFiles})</span>{/if}
      </p>
      {#if batch.scan.status}<p class="warn">{batch.scan.status}</p>{/if}
      {#if batch.scan.needsSensorLocation}
        <label class="row">Sensor placement
          <select bind:value={batch.sensorLocation}>
            <option value="" disabled>choose…</option>
            <option>Front-thigh</option><option>Right-thigh-side</option><option>Left-thigh-side</option>
          </select>
        </label>
      {/if}
      {#if batch.scan.rows.length}
        <div class="tablewrap">
          <table>
            <thead><tr><th>#</th><th>Subject ID</th><th>{batch.scan.trunkFiles || batch.scan.calfFiles ? "Thigh file" : "File"}</th>
              {#if batch.scan.trunkFiles}<th>Trunk file</th>{/if}{#if batch.scan.calfFiles}<th>Calf file</th>{/if}</tr></thead>
            <tbody>
              {#each batch.scan.rows as r, i}
                <tr><td class="muted">{i + 1}</td><td class="mono">{r.id}</td><td class="mono" title={r.file}>{r.filename}</td>
                  {#if batch.scan.trunkFiles}<td class="mono" title={r.trunkFile}>{baseName(r.trunkFile) || "—"}</td>{/if}
                  {#if batch.scan.calfFiles}<td class="mono" title={r.calfFile}>{baseName(r.calfFile) || "—"}</td>{/if}</tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    {/if}
  </div>

  {#if dataChecks.length}
    <div class="card checks">
      {#each dataChecks as c}<p class={c.level === "error" ? "err" : "warn"}>{c.text}</p>{/each}
    </div>
  {/if}

  {#key settingsUi.rev}
  <div class="card">
    <h2>Trunk and calf accelerometers<HelpLink doc={manual("data", "trunk-and-calf-accelerometers")} label="Trunk and calf accelerometers" /></h2>
    {#if proLocked}<p class="muted small">Locked in {propassModeName(batch.info?.licence)} (Settings).</p>{/if}
    {#each [
      { name: "Trunk", pos: "TRUNKPOS", pre: "TRUNKPREFIX", suf: "TRUNKSUFFIX", flip: "TRUNKFLIP", rot: "TRUNKROT",
        choices: ["off", "back", "front"], f: secondaryFolder("trunk"), which: "trunk" as const },
      { name: "Calf", pos: "CALFPOS", pre: "CALFPREFIX", suf: "CALFSUFFIX", flip: "CALFFLIP", rot: "CALFROT",
        choices: ["off", "on"], f: secondaryFolder("calf"), which: "calf" as const },
    ] as d (d.name)}
      {@const on = s[d.pos] !== "off"}
      {@const dis = running || noProject || proLocked}
      <div class="row dev">
        <label title={help(d.pos)}><strong class="devname">{d.name}</strong>
          <select value={String(s[d.pos])} onchange={(e) => set(d.pos, e.currentTarget.value)} disabled={dis}>
            {#each d.choices as c}<option value={c}>{c}</option>{/each}
          </select>
        </label>
        {#if on}
          <label title={help(d.pre)}>Prefix <input type="text" class="short" value={String(s[d.pre] ?? "")} disabled={dis}
            onchange={(e) => set(d.pre, e.currentTarget.value)} /></label>
          <label title={help(d.suf)}>Suffix <input type="text" class="short" value={String(s[d.suf] ?? "")} disabled={dis}
            onchange={(e) => set(d.suf, e.currentTarget.value)} /></label>
          <label title={help(d.flip)}><input type="checkbox" checked={!!s[d.flip]} disabled={dis} onchange={(e) => set(d.flip, e.currentTarget.checked)} /> Inside-out</label>
          <label title={help(d.rot)}><input type="checkbox" checked={!!s[d.rot]} disabled={dis} onchange={(e) => set(d.rot, e.currentTarget.checked)} /> Upside-down</label>
          {#if d.f.needed}
            <button onclick={() => chooseDir(d.which)} disabled={running}
              title={`Folder searched for <prefix><ID><suffix> files of the ${d.which} accelerometer`}>Folder…</button>
            <span class="mono path" title={d.f.dir}>{d.f.dir || "not chosen"}</span>
            {#if d.f.isLast}<span class="muted small">(last used)</span>{/if}
          {:else if d.f.fromList}
            <span class="muted small">Files from the Excel list.</span>
          {/if}
        {/if}
      </div>
    {/each}
    <p class="muted small">Processing options for trunk and calf (reference position, synchronisation, kneeling) are on the Settings page.</p>
  </div>
  {/key}

  {#each errors as e}<p class="err">{e}</p>{/each}
{/if}

<style>
  label { display: inline-flex; align-items: center; gap: 0.4rem; }
  /* own scroll area of about 12 rows, so the trunk/calf options below stay in view with many files */
  .tablewrap { max-height: 17rem; overflow: auto; border: 1px solid var(--border); border-radius: var(--radius); margin-top: 0.5rem; }
  table { border-collapse: collapse; width: 100%; font-size: 0.86rem; }
  th, td { text-align: left; padding: 0.12rem 0.5rem; border-bottom: 1px solid var(--border); white-space: nowrap; }
  th { position: sticky; top: 0; background: var(--surface-2); font-weight: 600; }
  .dev { padding: 0.3rem 0; }
  .devname { display: inline-block; width: 3.2rem; }
  .short { width: 7em; }
  .path { max-width: 28rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .small { font-size: 0.9em; }
  .checks p { margin: 0.15rem 0; }
  .err { color: var(--err); }
</style>

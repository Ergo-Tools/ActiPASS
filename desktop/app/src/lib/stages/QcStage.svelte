<script lang="ts">
  // Quality check (as Actipass_Batch_GUI.mlapp): the master QC table or one batch's QC table,
  // the QC figures of the selected subject, and QC_Status editing in the master table.
  // Uses the full window width, in three views: split (table + figure), table only, figure
  // only. Browsing keeps the selected row and the figure in step in every view. Figures are
  // read straight from the project folder (they show while the engine is busy); tables come
  // from the engine (qc.table / qc.setStatus).
  // SPDX-License-Identifier: GPL-3.0-or-later
  import HelpLink from "../components/HelpLink.svelte";
  import { manual } from "../help";
  import { tick } from "svelte";
  import { invoke, convertFileSrc } from "@tauri-apps/api/core";
  import { revealItemInDir } from "@tauri-apps/plugin-opener";
  import { ask } from "@tauri-apps/plugin-dialog";
  import { engine } from "../engine.svelte";
  import { project } from "../project.svelte";
  import { loadPref, savePref } from "../prefs";
  import { qc, col, loadQc, saveStatus, discardStatus, pendingCount, QC_STATUSES } from "../qc.svelte";

  type View = "split" | "table" | "figure";
  let view = $state<View>(loadPref<View>("qcView", "split"));
  $effect(() => savePref("qcView", view));

  let connected = $derived(engine.status.state === "connected");
  // the engine runs one job at a time: while a batch or a tool runs the page is locked
  let jobRunning = $derived(!!engine.busy);
  let dir = $derived(project.info?.exists ? project.info.dir : "");
  let t = $derived(qc.table);
  let iId = $derived(col(t, "SubjectID"));
  let iSt = $derived(col(t, "QC_Status"));
  let iBatch = $derived(col(t, "Batch"));
  let iFile = $derived(col(t, "Filename"));
  let flagIdx = $derived(new Set((t?.flags ?? []).map((f) => col(t, f))));
  let sort = $state<"original" | "status">("original");
  let search = $state("");
  let sourceChoice = $state(qc.source);
  let staleProject = $derived(pendingCount() > 0 && !!qc.projectDir && qc.projectDir !== dir);

  // ---- load the table: page opened, project or source changed (not over unsaved changes)
  $effect(() => {
    if (!connected || !dir || jobRunning || staleProject || qc.loading) return;
    if (qc.projectDir !== dir || qc.source !== sourceChoice || (!qc.table && !qc.error)) loadQc(dir, sourceChoice);
  });

  async function changeSource(next: string) {
    if (pendingCount() && qc.source === "" && next !== "") {
      const save = await ask(`QC_Status of ${pendingCount()} subject(s) changed. Save the changes to the master QC table?`,
        { title: "Quality check", kind: "warning", okLabel: "Save", cancelLabel: "Discard" });
      if (save) { if (!(await saveStatus())) return; } else discardStatus();
    }
    // another table starts afresh: no search, first subject in the sort order
    search = "";
    qc.selected = "";
    sourceChoice = next;
  }

  const status = (r: (string | null)[]) => qc.pending[r[iId] ?? ""] ?? r[iSt];
  const rank: Record<string, number> = { NotOK: 0, Check: 1, OK: 2 };

  let rows = $derived.by(() => {
    if (!t) return [];
    let rs = t.rows.map((r, i) => ({ r, i }));
    const q = search.trim().toLowerCase();
    if (q) rs = rs.filter(({ r }) => [r[iId], iFile >= 0 ? r[iFile] : null].some((v) => (v ?? "").toLowerCase().includes(q)));
    if (sort === "status") rs.sort((a, b) => (rank[status(a.r) ?? ""] ?? -1) - (rank[status(b.r) ?? ""] ?? -1) ||
      (a.r[iId] ?? "").localeCompare(b.r[iId] ?? ""));
    return rs;
  });

  // no selection (new table) or the selected subject filtered out: the first row
  $effect(() => {
    if (!t || !rows.length) return;
    if (!qc.selected || !rows.some(({ r }) => r[iId] === qc.selected)) qc.selected = rows[0].r[iId] ?? "";
  });

  let sel = $derived(t?.rows.find((r) => r[iId] === qc.selected) ?? null);
  let selPos = $derived(rows.findIndex(({ r }) => r[iId] === qc.selected));
  function step(d: number) {
    const k = Math.min(Math.max(selPos + d, 0), rows.length - 1);
    if (rows[k]) qc.selected = rows[k].r[iId] ?? "";
  }

  // ---- the table draws only the rows in view (thousands of subjects): fixed row height,
  //      spacer rows above and below, column widths fixed once from the contents
  const ROW_H = 22; // px, as .vt tbody tr in the styles
  const HEAD_H = 24;
  const MARGIN = 15; // rows drawn beyond the visible ones
  let tableEl = $state<HTMLElement>();
  let scrollTop = $state(0);
  let viewH = $state(400);
  let first = $derived(Math.max(0, Math.floor(scrollTop / ROW_H) - MARGIN));
  let last = $derived(Math.min(rows.length, Math.ceil((scrollTop + viewH) / ROW_H) + MARGIN));
  let shown = $derived(rows.slice(first, last));
  let frame = 0;
  function onScroll() {
    if (frame) return;
    frame = requestAnimationFrame(() => { frame = 0; if (tableEl) scrollTop = tableEl.scrollTop; });
  }

  // characters per column: the longest text of the column (header included), 3..48
  let widths = $derived.by(() => {
    if (!t) return [] as number[];
    return t.columns.map((c, j) => {
      let m = c.length;
      for (const r of t.rows) { const v = r[j]; if (v && v.length > m) m = v.length; }
      return Math.min(Math.max(m, 3), 48);
    });
  });
  let tableWidth = $derived(`calc(${widths.reduce((a, w) => a + Math.ceil(w * 1.05), 0)}ch + ${widths.length}rem)`);

  // keep the selected row in view (also after switching views): by its position, no DOM search
  $effect(() => {
    const pos = selPos;
    void view;
    if (pos < 0 || !tableEl) return;
    tick().then(() => {
      const el = tableEl;
      if (!el || !el.clientHeight) return;
      const top = pos * ROW_H;
      const room = el.clientHeight - HEAD_H;
      if (top < el.scrollTop) el.scrollTop = top;
      else if (top + ROW_H > el.scrollTop + room) el.scrollTop = top + ROW_H - room;
      scrollTop = el.scrollTop;
    });
  });

  function setStatus(v: string) {
    if (!sel || !t?.editable) return;
    const id = sel[iId] ?? "";
    if (v === sel[iSt]) delete qc.pending[id]; else qc.pending[id] = v;
  }

  let flagsOn = $derived(sel && t ? t.flags.filter((f) => (sel[col(t, f)] ?? "").toLowerCase() === "yes") : []);

  // ---- figures of the selected subject (listed in every view, so they are ready).
  // They follow the selection once it has settled for SETTLE_MS: holding a key moves the
  // table and the subject bar at once, the (large) figure catches up when the key is let go.
  const SETTLE_MS = 150;
  let figId = $state("");
  $effect(() => {
    const id = qc.selected;
    const timer = setTimeout(() => (figId = id), figId ? SETTLE_MS : 0);
    return () => clearTimeout(timer);
  });
  let images = $state<string[]>([]);
  let page = $state(0);
  let imgError = $state("");
  let shownFor = $state(""); // subject of the figure on screen
  $effect(() => {
    const id = figId;
    const r = id && t ? t.rows.find((x) => x[iId] === id) : null;
    const b = r ? (iBatch >= 0 ? r[iBatch] ?? "" : qc.source) || qc.source : "";
    if (!id || !b || !dir) { images = []; shownFor = ""; return; }
    invoke<string[]>("qc_images", { projectDir: dir, batch: b, subject: id })
      .then((list) => { if (figId === id) { images = list; page = 0; imgError = ""; shownFor = id; } })
      .catch((e) => { if (figId === id) { images = []; imgError = String(e); shownFor = id; } });
  });
  let figureLate = $derived(!!shownFor && shownFor !== qc.selected);
  const turn = (d: number) => { if (images.length) page = (page + d + images.length) % images.length; };

  // key repeats (holding a key) are applied at most once per screen frame
  let stepsQueued = 0;
  let pagesQueued = 0;
  let keyFrame = 0;
  function queue(kind: "step" | "page", d: number) {
    if (kind === "step") stepsQueued += d; else pagesQueued += d;
    if (keyFrame) return;
    keyFrame = requestAnimationFrame(() => {
      keyFrame = 0;
      if (stepsQueued) step(stepsQueued);
      if (pagesQueued) turn(pagesQueued);
      stepsQueued = pagesQueued = 0;
    });
  }

  // keys: ↑/↓ subject in every view; ←/→ figure pages in split and table view, subjects in
  // figure view (browse figure by figure); PgUp/PgDn figure pages in figure view
  function onKey(e: KeyboardEvent) {
    const tag = (e.target as HTMLElement)?.tagName;
    if (jobRunning || tag === "INPUT" || tag === "SELECT" || tag === "TEXTAREA") return;
    let done = true;
    if (e.key === "ArrowDown") queue("step", 1);
    else if (e.key === "ArrowUp") queue("step", -1);
    else if (e.key === "ArrowRight") view === "figure" ? queue("step", 1) : queue("page", 1);
    else if (e.key === "ArrowLeft") view === "figure" ? queue("step", -1) : queue("page", -1);
    else if (e.key === "PageDown" && view === "figure") queue("page", 1);
    else if (e.key === "PageUp" && view === "figure") queue("page", -1);
    else done = false;
    if (done) e.preventDefault();
  }

  const bad = (v: string | null) => v === null || v.toLowerCase() === "yes" || v.toLowerCase() === "cal-error";
  const join = (...p: string[]) => p.join("\\").replace(/[\\/]+/g, "\\");
  const keysHint = $derived(view === "figure"
    ? "←/→ or ↑/↓: previous/next subject · PgUp/PgDn or click: figure pages"
    : "↑/↓: previous/next subject · ←/→: figure pages · double-click a row: figure view");
</script>

<svelte:window onkeydown={onKey} />

<div class="head">
  <h1>Quality check<HelpLink doc={manual("qc")} /></h1>
  {#if dir && !jobRunning}
    <label>Table
      <select value={sourceChoice} onchange={(e) => changeSource(e.currentTarget.value)} disabled={qc.loading || qc.saving}>
        <option value="">Master QC table (all batches)</option>
        {#each [...(project.info?.batches ?? [])].reverse() as b}<option value={b}>Batch {b}</option>{/each}
      </select>
    </label>
    <label>Sort
      <select bind:value={sort}><option value="original">as in the table</option><option value="status">QC_Status (NotOK first)</option></select>
    </label>
    <input class="search" type="search" placeholder="Search subject ID or file" bind:value={search} />
    <div class="views" role="group" aria-label="View">
      <button class:on={view === "split"} onclick={() => (view = "split")} title="Table and figure">Split</button>
      <button class:on={view === "table"} onclick={() => (view = "table")} title="Table only">Table</button>
      <button class:on={view === "figure"} onclick={() => (view = "figure")} title="Figure only">Figure</button>
    </div>
    <button onclick={() => loadQc(dir, sourceChoice)} disabled={!connected || qc.loading || !!engine.busy}>Reload</button>
    <span class="spacer"></span>
    <button class="link" onclick={() => revealItemInDir(qc.table?.file ?? dir)} disabled={!qc.table}>QC table file</button>
    <button class="link" onclick={() => revealItemInDir(join(dir, "QC_Distributions"))}>QC distributions</button>
  {/if}
</div>

{#if !dir}
  <div class="card"><p class="warn">Open a project first.</p></div>
{:else if jobRunning}
  <div class="card"><p class="warn">A job is running ({engine.busy}): the quality check is not available until it has finished or is canceled.</p></div>
{:else if staleProject}
  <div class="card">
    <p class="warn">QC_Status changes of {pendingCount()} subject(s) in project {qc.projectDir} are not saved.</p>
    <div class="row"><button class="primary" onclick={saveStatus} disabled={qc.saving || !connected}>Save them</button>
      <button class="danger" onclick={discardStatus}>Discard</button></div>
  </div>
{:else if !project.info?.hasMasterQC}
  <div class="card"><p class="muted">No processed data in this project yet: run a batch first (Process).</p></div>
{:else if !connected}
  <div class="card"><p class="warn">Waiting for the engine (see Engine).</p></div>
{:else if qc.error}
  <div class="card"><p class="err">{qc.error}</p>{#if engine.busy}<p class="muted">The engine is busy ({engine.busy}); try again when it has finished.</p>{/if}</div>
{:else if t}
  {#if t.editable && pendingCount()}
    <div class="pending row">
      <span>QC_Status of <strong>{pendingCount()}</strong> subject(s) changed, not saved yet.<HelpLink doc={manual("qc", "qc-status")} label="QC status" /></span>
      <button class="primary" onclick={saveStatus} disabled={qc.saving || !!engine.busy}>Save to master QC table</button>
      <button class="link" onclick={discardStatus} disabled={qc.saving}>Discard</button>
      <span class="muted small">The current table is first copied to the project's Backups folder.</span>
    </div>
  {/if}

  <!-- the table stays in the page in every view (hidden in figure view) so it keeps its place -->
  <div class="tablewrap" class:full={view === "table"} class:hidden={view === "figure"} bind:this={tableEl}
    bind:clientHeight={viewH} onscroll={onScroll}>
    <table class="vt" style:width={tableWidth}>
      <colgroup>{#each widths as w}<col style:width={`calc(${Math.ceil(w * 1.05)}ch + 1rem)`} />{/each}</colgroup>
      <thead><tr>{#each t.columns as c}<th title={c}>{c}</th>{/each}</tr></thead>
      <tbody>
        {#if first > 0}<tr class="spacer" style:height={`${first * ROW_H}px`}><td colspan={t.columns.length}></td></tr>{/if}
        {#each shown as { r } (r[iId] + "|" + (iBatch >= 0 ? r[iBatch] : ""))}
          {@const st = status(r)}
          <tr class:sel={r[iId] === qc.selected} class:check={st === null || st === "Check"} class:notok={st === "NotOK"}
            onclick={() => (qc.selected = r[iId] ?? "")} ondblclick={() => { qc.selected = r[iId] ?? ""; view = "figure"; }}>
            {#each r as v, j}
              <td class:bad={flagIdx.has(j) && bad(v)} class:changed={j === iSt && r[iId] !== null && r[iId] in qc.pending}
                title={v ?? ""}>{j === iSt ? st ?? "" : v ?? ""}</td>
            {/each}
          </tr>
        {/each}
        {#if last < rows.length}<tr class="spacer" style:height={`${(rows.length - last) * ROW_H}px`}><td colspan={t.columns.length}></td></tr>{/if}
      </tbody>
    </table>
  </div>
  <p class="muted small">{rows.length} of {t.rows.length} subject(s){search ? ` matching "${search}"` : ""}{selPos >= 0 ? `, ${selPos + 1} selected` : ""}. {keysHint}.
    {#if !t.editable}QC_Status can be changed in the master QC table.{/if}</p>

  {#if sel && view !== "table"}
    <div class="subject card">
      <div class="row">
        <button onclick={() => step(-1)} disabled={selPos <= 0} title="Previous subject">◀ Previous</button>
        {#if view === "figure"}
          <!-- figure view has no table: choose the subject here (current sort and search) -->
          <select class="mono idsel" value={qc.selected} onchange={(e) => (qc.selected = e.currentTarget.value)} title="Subject">
            {#each rows as { r }}<option value={r[iId]}>{r[iId]}</option>{/each}
          </select>
        {:else}
          <strong class="mono id">{sel[iId]}</strong>
        {/if}
        <button onclick={() => step(1)} disabled={selPos >= rows.length - 1} title="Next subject">Next ▶</button>
        <label>QC_Status
          <select value={status(sel) ?? ""} onchange={(e) => setStatus(e.currentTarget.value)} disabled={!t.editable || qc.saving}>
            {#if status(sel) === null}<option value="">(none)</option>{/if}
            {#each QC_STATUSES as s}<option value={s}>{s}</option>{/each}
          </select>
        </label>
        {#if (sel[iId] ?? "") in qc.pending}<span class="changedtag">changed</span>{/if}
        <span class="muted">Batch {iBatch >= 0 ? sel[iBatch] : qc.source}{iFile >= 0 ? ` · ${sel[iFile]}` : ""}</span>
        <span class="flags" class:has={flagsOn.length > 0} role="status" aria-label="Flags">
          <span class="flagslabel">Flags</span><HelpLink doc={manual("qc", "flags")} label="Flags" />
          {#if flagsOn.length}{#each flagsOn as f}<span class="flag">{f}</span>{/each}{:else}<span class="noflag">No flags</span>{/if}
        </span>
      </div>
      {#if images.length}
        <div class="figure">
          <button class="img" class:big={view === "figure"} class:late={figureLate} onclick={() => turn(1)} title="Click for the next page">
            <img src={convertFileSrc(images[page])} alt={`QC figure ${page + 1} of ${shownFor}`} />
          </button>
          <div class="row small">
            {#if images.length > 1}<span>Page {page + 1} of {images.length}</span>{/if}
            <button class="link" onclick={() => revealItemInDir(images[page])}>Show in folder</button>
          </div>
        </div>
      {:else}
        <p class="muted">{imgError || "No QC figure for this subject (visualizations off, or the batch folder was removed)."}</p>
      {/if}
    </div>
  {/if}
{:else if qc.loading}
  <p class="muted">Loading the QC table…</p>
{/if}

<style>
  .head { display: flex; align-items: center; gap: 0.8rem; flex-wrap: wrap; margin-bottom: 0.6rem; }
  .head h1 { margin: 0 0.6rem 0 0; }
  .head label { display: inline-flex; align-items: center; gap: 0.4rem; }
  .search { width: 16rem; }
  .spacer { flex: 1; }
  .views { display: inline-flex; }
  .views button { border-radius: 0; margin-left: -1px; }
  .views button:first-child { border-radius: var(--radius) 0 0 var(--radius); margin-left: 0; }
  .views button:last-child { border-radius: 0 var(--radius) var(--radius) 0; }
  .views button.on { background: var(--accent); color: var(--accent-text); border-color: var(--accent); }
  .small { font-size: 0.88em; }
  .err { color: var(--err); }
  .pending { background: var(--accent-soft); border-radius: var(--radius); padding: 0.4rem 0.7rem; margin-bottom: 0.5rem; }
  /* the table has its own scroll area; drag the lower edge to make it taller (split view) */
  .tablewrap { height: 34vh; min-height: 8rem; resize: vertical; overflow: auto; border: 1px solid var(--border); border-radius: var(--radius); background: var(--surface); }
  .tablewrap.full { height: calc(100vh - 13rem); resize: none; }
  .tablewrap.hidden { display: none; }
  /* fixed layout: widths from the colgroup, one line per row of ROW_H (22 px) */
  table.vt { border-collapse: collapse; font-size: 0.8rem; table-layout: fixed; }
  /* row lines as inset shadows (no border): a row is exactly 22 px, so positions add up */
  th, td { padding: 0 0.5rem; border: none; box-shadow: inset 0 -1px var(--border); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; text-align: left; }
  th { position: sticky; top: 0; background: var(--surface-2); font-weight: 600; z-index: 1; height: 24px; }
  .vt tbody td { height: 22px; line-height: 22px; }
  .vt tbody tr.spacer td { padding: 0; box-shadow: none; height: auto; }
  tr { cursor: pointer; }
  tr.check td { background: color-mix(in srgb, #f2d64b 28%, transparent); }
  tr.notok td { background: color-mix(in srgb, #edb120 45%, transparent); }
  tr.sel td { outline: 2px solid var(--accent); outline-offset: -2px; }
  td.bad { color: var(--err); font-weight: 600; }
  td.changed { font-weight: 700; text-decoration: underline dotted; }
  .subject { margin-top: 0.6rem; }
  .id { font-size: 1.1rem; }
  .idsel { font-size: 1rem; font-weight: 600; max-width: 18rem; }
  /* the flags as a field of their own: a framed box; filled dark orange-brown tags, or a
     green "No flags"; the box only lightly tinted */
  .flags { --flag: #9a4b14; display: inline-flex; flex-wrap: wrap; gap: 0.35rem; align-items: center;
    border: 1px solid var(--border); border-radius: var(--radius); padding: 0.25rem 0.5rem; background: var(--surface-2); }
  @media (prefers-color-scheme: dark) { .flags { --flag: #c7783a; } }
  .flags.has { border-color: color-mix(in srgb, var(--flag) 55%, var(--border)); background: color-mix(in srgb, var(--flag) 6%, var(--surface-2)); }
  .flagslabel { font-weight: 700; margin-right: 0.15rem; }
  .flags.has .flagslabel { color: var(--flag); }
  .flag { background: var(--flag); color: #fff; font-weight: 600; border-radius: 4px; padding: 0.05rem 0.45rem; font-size: 0.85rem; }
  .noflag { background: var(--ok); color: #fff; font-weight: 600; border-radius: 4px; padding: 0.05rem 0.45rem; font-size: 0.85rem; }
  .changedtag { color: var(--accent); font-weight: 600; font-size: 0.9em; }
  .figure { margin-top: 0.5rem; }
  .img { display: block; width: 100%; padding: 0; border: 1px solid var(--border); background: #fff; cursor: pointer; }
  .img img { display: block; width: 100%; height: auto; max-height: 78vh; object-fit: contain; }
  /* figure view: as large as the window allows */
  .img.big img { max-height: calc(100vh - 15rem); }
  /* the figure of the previous subject while the selection moves on (key held down) */
  .img.late img { opacity: 0.45; }
</style>

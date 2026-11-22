<script lang="ts">
  // SPDX-License-Identifier: GPL-3.0-or-later
  import { tick } from "svelte";
  import { engine, clearLogs } from "../engine.svelte";
  import { loadPref, savePref } from "../prefs";

  let open = $state(loadPref<boolean>("logOpen", false));
  let list: HTMLDivElement | undefined = $state();
  let last = $derived(engine.logs.at(-1));
  let errors = $derived(engine.logs.filter((l) => l.level === "error").length);

  function toggle() {
    open = !open;
    savePref("logOpen", open);
  }

  // keep the newest line in view
  $effect(() => {
    engine.logs.length;
    if (open && list) tick().then(() => list && (list.scrollTop = list.scrollHeight));
  });
</script>

<section class:open aria-label="Log">
  <div class="bar">
    <button class="toggle" onclick={toggle} aria-expanded={open}>{open ? "▾" : "▸"} Log</button>
    {#if errors}<span class="err">{errors} error{errors > 1 ? "s" : ""}</span>{/if}
    <span class="last {last?.level}">{last ? `${last.time}  ${last.text}` : ""}</span>
    {#if open}<button class="link" onclick={clearLogs}>Clear</button>{/if}
  </div>
  {#if open}
    <div class="lines" bind:this={list}>
      {#each engine.logs as l}
        <div class="line {l.level}"><span class="t">{l.time}</span>{l.text}</div>
      {/each}
    </div>
  {/if}
</section>

<style>
  section {
    grid-area: log;
    border-top: 1px solid var(--border);
    background: var(--surface);
    display: flex;
    flex-direction: column;
    min-height: 0;
  }
  section.open { height: 220px; }
  .bar { display: flex; align-items: center; gap: 0.8rem; padding: 0.25rem 0.75rem; min-width: 0; }
  .toggle { border: none; background: none; padding: 0.1rem 0.2rem; font-weight: 600; }
  .last { flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-family: var(--mono); font-size: 0.85em; color: var(--muted); }
  .lines { flex: 1; overflow: auto; font-family: var(--mono); font-size: 0.82rem; padding: 0.25rem 0.75rem 0.5rem; }
  .line { white-space: pre-wrap; word-break: break-word; }
  .t { color: var(--muted); margin-right: 0.8em; }
  /* warnings: a soft orange (warning colour toned down with the muted grey); their MATLAB
     code-location lines fainter still */
  .warning { color: color-mix(in srgb, var(--warn) 70%, var(--muted)); }
  .warnDetail { color: color-mix(in srgb, var(--warn) 35%, var(--muted)); }
  .error { color: var(--err); }
  .system { color: var(--accent); }
  .output { color: var(--muted); }
  /* batch log lines (the engine sends Actipass_BatchLog.txt as it is written) */
  .batch { color: var(--text); }
  .line.batch .t::after { content: " batch"; color: var(--accent); font-size: 0.85em; }
  /* per-subject lines of a tool (the tool also writes them to Actipass_ToolLog.txt) */
  .tool { color: var(--text); }
  .line.tool .t::after { content: " tool"; color: var(--accent); font-size: 0.85em; }
</style>

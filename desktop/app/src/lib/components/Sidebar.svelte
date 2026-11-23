<script lang="ts">
  // SPDX-License-Identifier: GPL-3.0-or-later
  import { stages, type StageId } from "../stages";
  import { project } from "../project.svelte";
  import { batch } from "../batch.svelte";
  import { checks } from "../checks.svelte";
  import { engine } from "../engine.svelte";

  let { current = $bindable() }: { current: StageId } = $props();

  let all = $derived(checks());

  // the page whose job runs, and the pages that are read only meanwhile
  const JOB_PAGE: Record<string, StageId> = {
    "batch.run": "process", "stats.run": "stats", "tools.longFormat": "stats", "tools.export1s": "stats",
    "tools.diaryQC": "diary", "tools.mergeSleep": "tools", "tools.sitToStand": "tools", "tools.clinicalSts": "tools",
    "tools.wbv": "tools", "debug.demoJob": "engine",
  };
  let runningPage = $derived<StageId | "">(engine.busy ? JOB_PAGE[engine.busy] ?? "" : "");
  let lockedPages = $derived<StageId[]>(!engine.busy ? [] :
    // the engine does one job at a time: every workflow page but the running one
    (["project", "data", "diary", "settings", "process", "qc", "stats", "tools"] as StageId[])
      .filter((p) => p !== runningPage));

  function mark(id: StageId): "running" | "locked" | "done" | "warn" | "" {
    if (id === runningPage) return "running";
    if (lockedPages.includes(id)) return "locked";
    return badge(id);
  }

  function badge(id: StageId): "done" | "warn" | "" {
    // warnings of the project checks first; "done" only without blocking checks
    const mine = all.filter((c) => c.stage === id);
    if (mine.some((c) => c.level === "warning")) return "warn";
    const blocked = mine.some((c) => c.level === "error");
    switch (id) {
      case "project":
        return project.info?.exists && !blocked ? "done" : "";
      case "data":
        return batch.scan?.rows.length && !blocked ? "done" : "";
      case "diary":
        return !blocked ? "done" : "";
      case "process":
        if (batch.error) return "warn";
        return batch.result ? (batch.result.orientationWarning || batch.result.status === "Canceled" ? "warn" : "done") : "";
      default:
        return "";
    }
  }

  const workflow = stages.filter((s) => s.workflow);
  const other = stages.filter((s) => !s.workflow);
</script>

{#snippet markOf(id: StageId)}
  {@const m = mark(id)}
  {#if m === "running"}<span class="badge running" title="Running ({engine.busy})" aria-label="Running"></span>
  {:else if m === "locked"}<span class="badge locked" title="Read only while a job runs" aria-label="Read only">
      <svg viewBox="0 0 16 16" width="12" height="12" aria-hidden="true"><path fill="currentColor" d="M4 7V5a4 4 0 1 1 8 0v2h1a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1h1Zm2 0h4V5a2 2 0 1 0-4 0v2Z"/></svg></span>
  {:else if m === "done"}<span class="badge done" title="Done">✓</span>
  {:else if m === "warn"}<span class="badge warn" title="Warnings">!</span>{/if}
{/snippet}

<nav aria-label="Workflow">
  <ol class="workflow">
    {#each workflow as s, i}
      <li>
        <button class:active={current === s.id} onclick={() => (current = s.id)} aria-current={current === s.id ? "page" : undefined}>
          <span class="num">{i + 1}</span>
          <span class="label">{s.label}</span>
          {@render markOf(s.id)}
        </button>
      </li>
    {/each}
  </ol>
  <ul class="other">
    {#each other as s}
      <li>
        <button class:active={current === s.id} onclick={() => (current = s.id)} aria-current={current === s.id ? "page" : undefined}>
          <span class="label">{s.label}</span>
          {@render markOf(s.id)}
        </button>
      </li>
    {/each}
  </ul>
</nav>

<style>
  nav {
    background: var(--nav-bg);
    color: var(--nav-text);
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    padding: 0.75rem 0.5rem;
    overflow-y: auto;
  }
  ol, ul { list-style: none; margin: 0; padding: 0; }
  .other { border-top: 1px solid rgba(255, 255, 255, 0.12); padding-top: 0.5rem; }
  button {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 0.6rem;
    text-align: left;
    background: none;
    border: none;
    color: inherit;
    padding: 0.55rem 0.6rem;
    border-radius: var(--radius);
  }
  button:hover { background: rgba(255, 255, 255, 0.07); }
  button.active { background: var(--nav-active); color: #fff; }
  .num {
    width: 1.5rem; height: 1.5rem; flex: none;
    border-radius: 50%;
    border: 1px solid rgba(255, 255, 255, 0.35);
    display: grid; place-items: center;
    font-size: 0.8rem;
  }
  .active .num { background: #fff; color: var(--nav-bg); border-color: #fff; }
  .label { flex: 1; }
  .badge { font-weight: 700; font-size: 0.85rem; }
  .badge.done { color: #6fdc9b; }
  .badge.warn { color: #ffc35a; }
  /* a job runs on this page: a small spinning ring */
  .badge.running { width: 0.8rem; height: 0.8rem; border-radius: 50%; border: 2px solid rgba(255, 255, 255, 0.3);
    border-top-color: #6fdcf0; animation: spin 0.9s linear infinite; }
  .badge.locked { color: rgba(255, 255, 255, 0.55); display: inline-flex; }
  @keyframes spin { to { transform: rotate(360deg); } }
</style>

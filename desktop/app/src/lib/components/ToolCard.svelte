<script lang="ts">
  // One tool (engine method tools.*): description, options (children), Run with progress and
  // cancel, the result message and its output (Show in folder). `blocked` says why it cannot
  // run now (shown instead of running).
  // SPDX-License-Identifier: GPL-3.0-or-later
  import type { Snippet } from "svelte";
  import { revealItemInDir } from "@tauri-apps/plugin-opener";
  import { engine, runJob, cancelJob, addLog, errorText, CANCELED, type RpcError } from "../engine.svelte";
  import ProgressBar from "./ProgressBar.svelte";
  import HelpLink from "./HelpLink.svelte";

  interface ToolResult { status: "OK" | "Check" | "Error"; message: string; output: string }

  let { title, method, params, blocked = "", runLabel = "Run", doc = "", children, description }: {
    title: string;
    /** place in the user manual (help.ts) */
    doc?: string;
    method: string;
    params: () => Record<string, unknown>;
    blocked?: string;
    runLabel?: string;
    children?: Snippet;
    description?: Snippet;
  } = $props();

  let result = $state<ToolResult | null>(null);
  let error = $state("");
  let running = $derived(engine.busy === method);

  async function run() {
    result = null;
    error = "";
    try {
      result = await runJob<ToolResult>(method, params());
    } catch (e) {
      const err = e as RpcError;
      error = err?.code === CANCELED ? err.message || "Canceled" : errorText(e);
      addLog(err?.code === CANCELED ? "warning" : "error", `${title}: ${error}`);
    }
  }
</script>

<section class="card tool">
  <h2>{title}<HelpLink {doc} label={title} /></h2>
  {#if description}<div class="muted desc">{@render description()}</div>{/if}
  {#if children}<div class="opts">{@render children()}</div>{/if}
  {#if blocked}<p class="warn">{blocked}</p>{/if}
  <div class="row">
    <button class="primary" onclick={run} disabled={!!blocked || !!engine.busy}>{runLabel}</button>
    {#if running}<button class="danger" onclick={cancelJob}>Cancel</button>{/if}
    {#if engine.busy && !running}<span class="muted small">Another job is running ({engine.busy}).</span>{/if}
  </div>
  {#if running}
    <div class="prog">
      <ProgressBar value={engine.progress?.value ?? 0} indeterminate={!engine.progress} height={8} />
      <p class="muted small">{engine.progress?.message ?? "Starting…"}</p>
    </div>
  {/if}
  {#if result}
    <p class:ok={result.status === "OK"} class:warn={result.status === "Check"} class:err={result.status === "Error"}>{result.message}</p>
    {#if result.output}<button class="link" onclick={() => revealItemInDir(result!.output)}>Show in folder</button>{/if}
  {:else if error}
    <p class="err">{error}</p>
  {/if}
</section>

<style>
  .tool h2 { margin-bottom: 0.3rem; }
  .desc { margin-bottom: 0.5rem; }
  .opts { display: flex; flex-wrap: wrap; gap: 0.5rem 1.2rem; align-items: center; margin-bottom: 0.6rem; }
  .opts :global(label) { display: inline-flex; align-items: center; gap: 0.4rem; }
  .prog { margin-top: 0.6rem; }
  .small { font-size: 0.88em; }
  .ok { color: var(--ok); }
  .err { color: var(--err); }
  p { word-break: break-word; }
</style>

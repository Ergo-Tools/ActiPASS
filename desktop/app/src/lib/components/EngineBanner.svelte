<script lang="ts">
  // Banner at the top of every page when the installed engine is not the one this app was
  // released with (another ActiPASS version, or an older build of the same version).
  // SPDX-License-Identifier: GPL-3.0-or-later
  import { engine, versionMismatch } from "../engine.svelte";

  let text = $derived(engine.status.state === "connected" ? versionMismatch() : "");
  let closed = $state(false);
</script>

{#if text && !closed}
  <div class="banner" role="alert">
    <span>{text}</span>
    <button class="link close" onclick={() => (closed = true)} title="Hide until the next start" aria-label="Hide">✕</button>
  </div>
{/if}

<style>
  .banner {
    display: flex; align-items: center; gap: 0.75rem;
    margin-bottom: 1rem; padding: 0.55rem 0.8rem;
    border: 1px solid var(--err); border-radius: 6px;
    background: color-mix(in srgb, var(--err) 8%, transparent);
  }
  .banner span { flex: 1; }
  .close { padding: 0 0.3rem; }
</style>

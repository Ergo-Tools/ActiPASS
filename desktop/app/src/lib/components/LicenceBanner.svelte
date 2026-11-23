<script lang="ts">
  // Banner at the top of every page while Actipass runs in evaluation mode or the licence
  // expires within 60 days; opens the licence dialog. Can be closed for the session.
  // SPDX-License-Identifier: GPL-3.0-or-later
  import { batch } from "../batch.svelte";
  import { licenceWarning } from "../licence";
  import { licenceUi, openLicenceDialog } from "../licenceUi.svelte";

  let lic = $derived(batch.info?.licence);
  let text = $derived(licenceWarning(lic));
</script>

{#if text && !licenceUi.bannerClosed}
  <div class="banner" class:soon={lic?.expiring} role="status">
    <span>{text}</span>
    <button onclick={openLicenceDialog}>{lic?.expiring ? "Renew licence…" : "Licence…"}</button>
    <button class="link close" onclick={() => (licenceUi.bannerClosed = true)} title="Hide until the next start" aria-label="Hide">✕</button>
  </div>
{/if}

<style>
  .banner {
    display: flex; align-items: center; gap: 0.75rem;
    margin-bottom: 1rem; padding: 0.55rem 0.8rem;
    border: 1px solid var(--warn); border-radius: 6px;
    background: color-mix(in srgb, var(--warn) 10%, transparent);
  }
  .banner span { flex: 1; }
  .close { padding: 0 0.3rem; }
</style>

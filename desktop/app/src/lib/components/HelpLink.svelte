<script lang="ts">
  // Small "?" that opens the manual at `doc` (see help.ts); nothing when doc is empty.
  // SPDX-License-Identifier: GPL-3.0-or-later
  import { openDoc, docUrl } from "../help";

  let { doc = "", label = "" }: { doc?: string; label?: string } = $props();
</script>

{#if doc}
  <!-- no default action: inside a <summary> the click must not open/close the details -->
  <button class="q" type="button" onclick={(e) => { e.preventDefault(); e.stopPropagation(); openDoc(doc); }}
    title={`Help${label ? ": " + label : ""} (${docUrl(doc)})`}
    aria-label={`Help${label ? ": " + label : ""}`}>?</button>
{/if}

<style>
  .q {
    width: 1.15rem; height: 1.15rem; padding: 0;
    border-radius: 50%;
    font-size: 0.75rem; font-weight: 700; line-height: 1;
    color: var(--accent); border-color: var(--accent);
    background: transparent;
    flex: none;
    margin-left: 0.3em;
    vertical-align: middle;
  }
</style>

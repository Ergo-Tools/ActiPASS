<script lang="ts">
  // SPDX-License-Identifier: GPL-3.0-or-later
  import type { Stage } from "../stages";
  let { stage }: { stage: Stage } = $props();
</script>

<h1>{stage.label}</h1>
<div class="card">
  <p class="muted">Not built yet. This page will hold:</p>
  <ul>
    {#each stage.planned as p}<li>{p}</li>{/each}
  </ul>
</div>

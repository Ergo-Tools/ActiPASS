<script lang="ts">
  // SPDX-License-Identifier: GPL-3.0-or-later
  let { value = 0, indeterminate = false, height = 8 }: { value?: number; indeterminate?: boolean; height?: number } = $props();
</script>

<div class="track" style:height="{height}px" role="progressbar" aria-valuemin="0" aria-valuemax="100"
  aria-valuenow={indeterminate ? undefined : Math.round(value * 100)}>
  <div class="fill" class:indeterminate style:width={indeterminate ? "30%" : `${Math.round(value * 1000) / 10}%`}></div>
</div>

<style>
  .track { width: 100%; background: var(--surface-2); border-radius: 999px; overflow: hidden; }
  .fill { height: 100%; background: var(--accent); transition: width 0.15s linear; }
  .indeterminate { animation: slide 1.2s ease-in-out infinite; }
  @keyframes slide { from { margin-left: -30%; } to { margin-left: 100%; } }
</style>

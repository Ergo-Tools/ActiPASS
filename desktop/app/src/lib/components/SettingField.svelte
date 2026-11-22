<script lang="ts">
  // One setting of settings.schema.json: label, control, unit, help, "changed from default", error.
  // SPDX-License-Identifier: GPL-3.0-or-later
  import type { SchemaField, SettingValue } from "../batch.svelte";
  import HelpLink from "./HelpLink.svelte";

  let { field, value, def, disabled = false, lockedText = "", error = "", onchange }: {
    field: SchemaField;
    value: SettingValue | undefined;
    def: SettingValue | undefined;
    disabled?: boolean;
    lockedText?: string;
    error?: string;
    onchange: (v: SettingValue) => void;
  } = $props();

  let id = $derived(`set-${field.key}`);
  let changed = $derived(def !== undefined && JSON.stringify(value) !== JSON.stringify(def));
  let defText = $derived(Array.isArray(def) ? def.join(", ") : typeof def === "boolean" ? (def ? "on" : "off") : String(def ?? ""));

  function toggleMulti(v: string, on: boolean) {
    const cur = Array.isArray(value) ? value : [];
    const next = on ? [...cur, v] : cur.filter((x) => x !== v);
    // keep the schema order
    onchange((field.choices ?? []).map((c) => c.value).filter((c) => next.includes(c)));
  }
</script>

<div class="field" class:changed class:wide={field.type === "multi"} title={lockedText || undefined}>
  {#if field.type === "bool"}
    <div class="lbl boolspan">
      <label class="check" for={id}>
        <input {id} type="checkbox" checked={!!value} {disabled} onchange={(e) => onchange(e.currentTarget.checked)} />
        {field.label}
      </label>
      <HelpLink doc={field.doc} label={field.label} />
    </div>
  {:else}
    <div class="lbl"><label for={id}>{field.label}</label><HelpLink doc={field.doc} label={field.label} /></div>
    <div class="control">
      {#if field.type === "choice"}
        <select {id} value={String(value ?? "")} {disabled} onchange={(e) => onchange(e.currentTarget.value)}>
          {#each field.choices ?? [] as c}<option value={c.value}>{c.label ?? c.value}</option>{/each}
        </select>
      {:else if field.type === "number"}
        <input {id} type="number" value={value as number} min={field.min} max={field.max} step={field.step ?? "any"} {disabled}
          onchange={(e) => onchange(Number(e.currentTarget.value))} />
        {#if field.unit}<span class="unit">{field.unit}</span>{/if}
      {:else if field.type === "text"}
        <input {id} type="text" value={String(value ?? "")} {disabled} onchange={(e) => onchange(e.currentTarget.value)} />
      {:else if field.type === "multi"}
        <div class="multi" role="group" aria-labelledby={id}>
          {#each field.choices ?? [] as c}
            <label class="check small">
              <input type="checkbox" checked={Array.isArray(value) && value.includes(c.value)} {disabled}
                onchange={(e) => toggleMulti(c.value, e.currentTarget.checked)} />
              {c.label ?? c.value}
            </label>
          {/each}
        </div>
      {/if}
    </div>
  {/if}
  <div class="info">
    {#if error}<span class="error">{error}</span>{/if}
    {#if changed}<span class="dot" title={`Default: ${defText}`}>changed (default: {defText})</span>{/if}
    {#if field.help}<span class="help">{field.help}</span>{/if}
    {#if lockedText}<span class="help">{lockedText}</span>{/if}
  </div>
</div>

<style>
  /* one row: label | control | help; help moves under the control on narrow windows */
  .field {
    display: grid;
    grid-template-columns: 15rem 14rem minmax(0, 1fr);
    gap: 0.1rem 1rem;
    align-items: center;
    padding: 0.2rem 0.5rem;
    border-left: 3px solid transparent;
  }
  .field.changed { border-left-color: var(--accent); }
  .lbl { display: flex; align-items: center; gap: 0.35rem; min-width: 0; }
  .boolspan { grid-column: 1 / 3; }
  .field.wide { grid-template-columns: 15rem minmax(0, 1fr); }
  .field.wide .info { grid-column: 2; }
  .control { display: flex; align-items: center; gap: 0.4rem; min-width: 0; }
  .control select { max-width: 100%; }
  .control input[type="number"] { width: 7em; }
  .control input[type="text"] { width: 100%; }
  .unit { color: var(--muted); }
  .check { display: inline-flex; align-items: center; gap: 0.4rem; }
  .multi { display: flex; flex-wrap: wrap; gap: 0.1rem 0.9rem; }
  .small { font-size: 0.92em; }
  .info { display: flex; flex-wrap: wrap; column-gap: 0.6rem; line-height: 1.3; min-width: 0; }
  .info:empty { display: none; }
  .help { color: var(--muted); font-size: 0.86em; }
  .dot { color: var(--accent); font-size: 0.84em; white-space: nowrap; }
  .error { color: var(--err); font-size: 0.86em; flex-basis: 100%; }
  @media (max-width: 1100px) {
    .field { grid-template-columns: 13rem minmax(0, 1fr); }
    .boolspan { grid-column: 1 / -1; }
    .info { grid-column: 2; }
  }
</style>

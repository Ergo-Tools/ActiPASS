<script lang="ts">
  // Sections of settings.schema.json as cards, with "Restore defaults" per section.
  // Read only without an open project, while a batch runs, and (most fields) in ProPASS mode.
  // SPDX-License-Identifier: GPL-3.0-or-later
  import { engine } from "../engine.svelte";
  import { batch, settingsUi, setSettings, fieldVisible, settingsProjectDir, type SettingValue } from "../batch.svelte";
  import SettingField from "./SettingField.svelte";
  import HelpLink from "./HelpLink.svelte";
  import { propassModeName } from "../licence";

  let { ids, card = true }: { ids: string[]; card?: boolean } = $props();

  let info = $derived(batch.info);
  let s = $derived(info?.settings as Record<string, SettingValue> | undefined);
  let running = $derived(batch.running || engine.busy === "batch.run" || engine.busy === "stats.run");
  let noProject = $derived(!settingsProjectDir());
  let sections = $derived((settingsUi.schema?.sections ?? []).filter((x) => ids.includes(x.id))
    .sort((a, b) => ids.indexOf(a.id) - ids.indexOf(b.id)));

  function fieldsOf(id: string) {
    return (settingsUi.schema?.fields ?? []).filter((f) => f.section === id);
  }
  function locked(f: { propass?: boolean }) {
    return !!s?.PROPASS && !f.propass;
  }
  function changedIn(id: string) {
    return fieldsOf(id).filter((f) => !locked(f) && JSON.stringify(s?.[f.key]) !== JSON.stringify(info?.defaults.settings[f.key]));
  }
  function restore(id: string) {
    const vals: Record<string, SettingValue> = {};
    for (const f of changedIn(id)) vals[f.key] = info!.defaults.settings[f.key];
    if (Object.keys(vals).length) setSettings(vals);
  }
</script>

{#if info && s && settingsUi.schema}
  {#key settingsUi.rev}
    {#each sections as sec (sec.id)}
      <section class:card>
        <div class="head">
          <h2 class="title">{sec.title} <HelpLink doc={sec.doc} label={sec.title} /></h2>
          {#if fieldVisible(sec, s) && changedIn(sec.id).length}
            <button class="link" onclick={() => restore(sec.id)} disabled={running || noProject}
              title="Set the changed settings of this section back to the Actipass defaults">Restore defaults ({changedIn(sec.id).length})</button>
          {/if}
        </div>
        {#if !fieldVisible(sec, s)}
          <p class="muted">{sec.hiddenText ?? "Not used with the current settings."}</p>
        {:else}
          {#each fieldsOf(sec.id) as f (f.key)}
            {#if fieldVisible(f, s)}
              <SettingField field={f} value={s[f.key]} def={info.defaults.settings[f.key]}
                disabled={running || noProject || locked(f)}
                lockedText={locked(f) ? `Locked in ${propassModeName(info?.licence)}.` : ""}
                error={settingsUi.errors[f.key] ?? ""}
                onchange={(v) => setSettings({ [f.key]: v })} />
            {/if}
          {/each}
        {/if}
      </section>
    {/each}
  {/key}
{/if}

<style>
  section:not(.card) { margin-bottom: 1rem; }
  .title { display: inline-flex; align-items: center; gap: 0.4rem; }
  .head { display: flex; align-items: baseline; justify-content: space-between; gap: 1rem; }
</style>

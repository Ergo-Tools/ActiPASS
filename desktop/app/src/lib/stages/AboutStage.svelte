<script lang="ts">
  // About: versions, licence details, credits and links (as ActiPASS_About_UI.mlapp).
  // SPDX-License-Identifier: GPL-3.0-or-later
  import HelpLink from "../components/HelpLink.svelte";
  import { manual } from "../help";
  import { openUrl } from "@tauri-apps/plugin-opener";
  import { engine } from "../engine.svelte";
  import { batch } from "../batch.svelte";
  import { licenceLabel } from "../licence";
  import { openLicenceDialog } from "../licenceUi.svelte";

  let info = $derived(batch.info);
  let lic = $derived(info?.licence);
  let hello = $derived(engine.status.hello);

  const links: [string, string][] = [
    ["Home", "https://github.com/Ergo-Tools/ActiPASS/"],
    ["References", "https://github.com/Ergo-Tools/ActiPASS/wiki/ActiPASS-References"],
    ["Open source software", "https://github.com/Ergo-Tools/ActiPASS/wiki/Open-source-software-used-by-ActiPASS"],
    ["Acknowledgements", "https://github.com/Ergo-Tools/ActiPASS/wiki/acknowledgements#actipass-acknowledgements"],
    ["License agreement", "https://github.com/Ergo-Tools/ActiPASS/wiki/License-agreement#license-and-usage-agreement"],
  ];
  const open = (u: string) => openUrl(u).catch(() => {});
</script>

<h1>About Actipass<HelpLink doc={manual("about")} /></h1>

<!-- versions and licence on the left, the image on the right (stacked on narrow windows) -->
<div class="top">
<div class="info">
<div class="card">
  <h2>Versions<HelpLink doc={manual("about", "versions")} label="Versions" /></h2>
  <dl>
    <dt>Actipass</dt><dd>{engine.info?.appVersion ?? "—"}{engine.info?.devBuild ? " (development build)" : ""}</dd>
    <dt>Engine</dt>
    <dd>{hello ? `${hello.engineVersion}${hello.deployed ? ", compiled" : ", in MATLAB"}` : "not connected"}</dd>
    {#if hello?.matlabVersion}<dt>{hello.deployed ? "MATLAB Runtime" : "MATLAB"}</dt><dd>{hello.matlabVersion}</dd>{/if}
  </dl>
</div>

<div class="card">
  <h2>Licence<HelpLink doc={manual("about", "licence")} label="Licence" /></h2>
  {#if !lic}
    <p class="muted">Shown when the engine is connected.</p>
  {:else}
    <p class:ok={lic.valid && !lic.evaluation} class:warn={lic.evaluation || !lic.valid}><strong>{licenceLabel(lic)}</strong></p>
    <p class="lictext">{lic.text.trim()}</p>
    {#if lic.evaluation}
      <p class="muted">Evaluation mode: at most {info?.maxFiles} files per batch, ProPASS settings, no statistics generation.</p>
    {:else if lic.propass}
      <p class="muted">ProPASS licence: ProPASS mode is always on.</p>
    {/if}
    {#if lic.expiring}<p class="warn">The licence expires in {lic.daysLeft} day(s) ({lic.expires}): request a renewal in time.</p>{/if}
    <div class="row">
      <button class:primary={lic.evaluation || lic.expiring} onclick={openLicenceDialog}>
        {lic.evaluation ? "Request or install a licence…" : lic.expiring ? "Renew licence…" : "Licence…"}</button>
    </div>
  {/if}
</div>
</div>
<div class="logo"><img src="/actipass_rectangular.png" alt="ActiPASS, with the logos of ProPASS, Uppsala University, Akademiska sjukhuset, the National Research Centre for the Working Environment (NFA) and Forte" /></div>
</div>

<div class="card">
  <h2>Credits<HelpLink doc={manual("about", "credits")} label="Credits" /></h2>
  <p>Actipass is developed by Pasan Hettiarachchi and Peter J. Johansson at Occupational and Environmental Medicine,
    Department of Medical Sciences, Uppsala University (Magnus Svartengren).</p>
  <p>Actipass is based on the Acti4 thigh accelerometer activity detection algorithm developed by Jørgen Skotte at the
    National Research Centre for the Working Environment (NFA), Copenhagen, Denmark (Andreas Holtermann).</p>
  <p>The development of Actipass has partly been funded by the ProPASS Consortium.</p>
  <p>Actipass may not be used for any commercial purposes without written permission from the developers. Please acknowledge
    the developers and NFA as the source of the software in any publications by referring to relevant publications about
    Acti4 and Actipass.</p>
  <div class="row">
    {#each links as [label, url]}<button onclick={() => open(url)} title={url}>{label}</button>{/each}
  </div>
</div>

<style>
  dl { display: grid; grid-template-columns: max-content 1fr; gap: 0.3rem 1rem; margin: 0; }
  dt { color: var(--muted); }
  dd { margin: 0; }
  .ok { color: var(--ok); }
  .top { display: grid; grid-template-columns: minmax(16rem, 0.75fr) minmax(0, 1.5fr); gap: 1rem; align-items: start; margin-bottom: 1rem; }
  .top .card { margin-bottom: 0.75rem; }
  .top .card:last-child { margin-bottom: 0; }
  @media (max-width: 1000px) { .top { grid-template-columns: 1fr; } }
  /* the licence text has its own line breaks (CR/LF): show them */
  .lictext { white-space: pre-line; }
  /* the image has a white background: keep it on white in dark mode too */
  .logo { background: #fff; border: 1px solid var(--border); border-radius: var(--radius); padding: 0.25rem; }
  .logo img { display: block; width: 100%; height: auto; }
</style>

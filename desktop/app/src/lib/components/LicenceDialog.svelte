<script lang="ts">
  // Licence dialog (the classic GUI's Help > Activate License and ActiPASS_Licensing.mlapp):
  // the licence of this computer, a licence request or renewal (Host-Details.txt, mailed to
  // the developers with the default mail program, or sent by hand), and installing the licence
  // files received back (ActiPASS.lic and ActiPASS.key).
  // SPDX-License-Identifier: GPL-3.0-or-later
  import { open as openFiles } from "@tauri-apps/plugin-dialog";
  import { openUrl, revealItemInDir } from "@tauri-apps/plugin-opener";
  import { engine, errorText, addLog } from "../engine.svelte";
  import { batch, loadSettings } from "../batch.svelte";
  import { loadPref, savePref } from "../prefs";
  import { licenceUi } from "../licenceUi.svelte";
  import {
    licenceLabel, licenceWarning, writeRequest, mailRequest, installLicence,
    LICENCE_TO, LICENCE_CC, LICENCE_AGREEMENT, type LicenceRequest,
  } from "../licence";
  import HelpLink from "./HelpLink.svelte";
  import { manual } from "../help";

  let dlg = $state<HTMLDialogElement>();
  $effect(() => {
    if (!dlg) return;
    if (licenceUi.open && !dlg.open) dlg.showModal();
    if (!licenceUi.open && dlg.open) dlg.close();
  });

  let connected = $derived(engine.status.state === "connected");
  let lic = $derived(batch.info?.licence);
  let licensed = $derived(!!lic?.valid && !lic.evaluation);
  let renew = $derived(licensed || lic?.problem === "expired");

  // the request form: the holder of the current licence, else the last request
  let form = $state<LicenceRequest>({ name: "", org: "", email: "", mode: "PROPASS", ...loadPref<Partial<LicenceRequest>>("licenceRequest", {}) });
  $effect(() => {
    if (licenceUi.open && lic?.user && !form.name) {
      form.name = lic.user; form.org = lic.org ?? ""; form.email = lic.email ?? "";
      if (lic.mode === "ADVANCED" || lic.mode === "PROPASS") form.mode = lic.mode;
    }
  });
  let accepted = $state(false);
  let busy = $state("");
  let message = $state("");
  let error = $state("");
  let requestFile = $state("");
  let fileToSend = $derived(requestFile || lic?.requestFile || "");

  async function createRequest() {
    error = ""; message = "";
    if (!form.name.trim() || !form.org.trim() || !form.email.trim()) { error = "Fill in full name, email and organisation."; return; }
    busy = "request";
    try {
      savePref("licenceRequest", form);
      const r = await writeRequest(form);
      requestFile = r.file;
      const how = await mailRequest(form, renew, r.file);
      message = how === "attached"
        ? "A new mail with Host-Details.txt attached was opened in your mail program: check it and send it."
        : "Your mail program could not attach the file: a new mail was opened (if a mail program is set up) and the folder " +
          "with Host-Details.txt is shown. Attach the file to the mail, or send it yourself to the addresses below.";
      addLog("info", `Licence request written: ${r.file}`);
    } catch (e) {
      // show the licence folder anyway (an older request file, or to send the files by hand)
      error = errorText(e) + (lic?.folder ? ` The licence folder is shown: ${lic.folder}` : "");
      if (lic?.folder) revealItemInDir(lic.folder).catch(() => {});
    } finally {
      busy = "";
    }
  }

  async function install() {
    error = ""; message = "";
    const files = await openFiles({ multiple: true, title: "Choose ActiPASS.lic and ActiPASS.key",
      filters: [{ name: "Actipass licence files", extensions: ["lic", "key"] }] });
    if (!files || !files.length) return;
    busy = "install";
    try {
      const l = await installLicence(files as string[]);
      message = `Licence installed: ${licenceLabel(l)}, valid until ${l.expires}.`;
      addLog("info", message);
      await loadSettings();
    } catch (e) {
      error = errorText(e);
    } finally {
      busy = "";
    }
  }

  const close = () => { licenceUi.open = false; message = ""; error = ""; };
</script>

<dialog bind:this={dlg} onclose={() => (licenceUi.open = false)} aria-labelledby="lic-title">
  <div class="head">
    <h2 id="lic-title">Actipass licence<HelpLink doc={manual("about", "licence")} label="Licence" /></h2>
    <button class="link" onclick={close} aria-label="Close">✕</button>
  </div>

  {#if !connected || !lic}
    <p class="warn">The engine is not connected yet: the licence is shown when it is (see Engine).</p>
  {:else}
    <section>
      <p class:ok={licensed && !lic.expiring} class:warn={!licensed || lic.expiring}><strong>{licenceLabel(lic)}</strong></p>
      {#if lic.user}
        <dl>
          <dt>Holder</dt><dd>{lic.user}, {lic.org} ({lic.email})</dd>
          <dt>Valid until</dt><dd>{lic.expires || "—"}{licensed ? ` (${lic.daysLeft} days left)` : ""}</dd>
        </dl>
      {/if}
      {#if licenceWarning(lic)}<p class="warn">{licenceWarning(lic)}</p>{/if}
      <p class="muted small">Licence files are kept in <button class="link mono" onclick={() => lic?.folder && revealItemInDir(lic.folder).catch(() => {})}>{lic.folder}</button>,
        shared with the classic ActiPASS app. A licence is for one computer and two years.</p>
    </section>

    <section>
      <h3>1. {renew ? "Renew the licence" : "Request a licence"}</h3>
      <p class="muted small">Creates the licence request file <span class="mono">Host-Details.txt</span> (your details and the network
        adapters of this computer, encrypted) and opens a mail to the developers with it.</p>
      <div class="form">
        <label>Full name <input bind:value={form.name} autocomplete="name" /></label>
        <label>Email <input type="email" bind:value={form.email} autocomplete="email" /></label>
        <label>Organisation <input bind:value={form.org} autocomplete="organization" /></label>
        <label title="ProPASS: all algorithm options at the ProPASS defaults (recommended). Advanced: algorithm options can be changed; use it only after consulting the developers.">
          Licence mode <select bind:value={form.mode}><option value="PROPASS">ProPASS (recommended)</option><option value="ADVANCED">Advanced</option></select></label>
      </div>
      <label class="accept"><input type="checkbox" bind:checked={accepted} />
        I have read and understood the <button class="link" onclick={() => openUrl(LICENCE_AGREEMENT).catch(() => {})}>licence agreement</button>
        and accept its terms. The licence is granted for two years.</label>
      <div class="row">
        <button class="primary" onclick={createRequest} disabled={!accepted || !!busy}>{busy === "request" ? "Creating…" : "Create request and open mail"}</button>
        {#if fileToSend}<button onclick={() => revealItemInDir(fileToSend).catch(() => {})}>Show Host-Details.txt</button>{/if}
      </div>
      <p class="muted small">To send it yourself: mail <span class="mono">Host-Details.txt</span> to
        <span class="mono">{LICENCE_TO.join(", ")}</span> (copy to <span class="mono">{LICENCE_CC.join(", ")}</span>).</p>
    </section>

    <section>
      <h3>2. Install the licence files</h3>
      <p class="muted small">When you have received <span class="mono">ActiPASS.lic</span> and <span class="mono">ActiPASS.key</span>,
        choose both files. They are checked for this computer and copied to the licence folder (files they replace are kept in
        <span class="mono">LicenceBackup</span>).</p>
      <button onclick={install} disabled={!!busy || !!engine.busy} title={engine.busy ? "Wait until the running job has finished" : ""}>
        {busy === "install" ? "Installing…" : "Install licence files…"}</button>
    </section>
  {/if}

  {#if message}<p class="ok msg">{message}</p>{/if}
  {#if error}<p class="err msg">{error}</p>{/if}
  <div class="row end"><button onclick={close}>Close</button></div>
</dialog>

<style>
  dialog {
    width: min(40rem, calc(100vw - 2rem));
    max-height: calc(100vh - 2rem);
    border: 1px solid var(--border); border-radius: 8px;
    padding: 1rem 1.25rem;
    background: var(--surface); color: var(--text);
  }
  dialog::backdrop { background: rgba(0, 0, 0, 0.35); }
  .head { display: flex; justify-content: space-between; align-items: center; }
  h2 { margin: 0; }
  h3 { margin: 0 0 0.3rem; font-size: 1rem; }
  section { padding: 0.75rem 0; border-top: 1px solid var(--border); }
  section:first-of-type { border-top: none; }
  dl { display: grid; grid-template-columns: max-content 1fr; gap: 0.2rem 1rem; margin: 0.3rem 0; }
  dt { color: var(--muted); }
  dd { margin: 0; }
  .form { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem 1rem; margin: 0.5rem 0; }
  .form label { display: flex; flex-direction: column; gap: 0.2rem; }
  .accept { display: block; margin: 0.4rem 0 0.6rem; }
  .small { font-size: 0.88em; }
  .ok { color: var(--ok); }
  .msg { margin: 0.5rem 0 0; }
  .row.end { justify-content: flex-end; margin-top: 0.75rem; }
</style>

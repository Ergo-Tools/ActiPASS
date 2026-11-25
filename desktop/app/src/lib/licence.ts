// Licence of this computer (the engine's check: settings.get .licence, licence.* methods),
// licence requests and installing licence files. The licence files are in the classic GUI's
// config folder (%APPDATA%\Actipass), shared by both GUIs.
// SPDX-License-Identifier: GPL-3.0-or-later

import { invoke } from "@tauri-apps/api/core";
import { openUrl, revealItemInDir } from "@tauri-apps/plugin-opener";
import { request } from "./engine.svelte";

export interface Licence {
  valid: boolean;
  mode: string;
  text: string;
  evaluation: boolean;
  propass: boolean;
  /** why there is no valid licence: none | invalid | host | expired | mode ("" when valid) */
  problem?: string;
  user?: string;
  email?: string;
  org?: string;
  date?: string;
  expires?: string;
  daysLeft?: number;
  /** valid, but expires within 60 days */
  expiring?: boolean;
  folder?: string;
  requestFile?: string;
}

/** licence requests go to the developers (Actipass README) */
export const LICENCE_TO = ["pasan.hettiarachchi@medsci.uu.se"];
export const LICENCE_CC = ["peter.johansson@medsci.uu.se"];
export const LICENCE_AGREEMENT = "https://github.com/Ergo-Tools/ActiPASS/wiki/License-agreement#license-and-usage-agreement";

export function licenceLabel(l: Licence | undefined | null): string {
  if (!l) return "unknown";
  if (l.evaluation || !l.valid) return "Evaluation mode (not licensed)";
  if (l.propass) return "ProPASS licence";
  if (l.mode === "ADVANCED") return "Advanced licence";
  return `${l.mode} licence`;
}

/** name of the locked mode: in evaluation mode ProPASS mode is forced, shown as such */
export function propassModeName(l: Licence | undefined | null): string {
  return l?.evaluation ? "Evaluation/ProPASS mode" : "ProPASS mode";
}

/** one-line warning for the banner ("" = nothing to warn about) */
export function licenceWarning(l: Licence | undefined | null): string {
  if (!l) return "";
  if (l.expiring) return `The Actipass licence of this computer expires in ${l.daysLeft} day(s) (${l.expires}). Request a renewal in time.`;
  if (l.valid && !l.evaluation) return "";
  const why: Record<string, string> = {
    none: "No licence found",
    expired: `The licence has expired${l.expires ? ` (${l.expires})` : ""}`,
    host: "The licence is for another computer",
    invalid: "The licence files cannot be read",
    mode: "The licence mode is not supported",
  };
  return `${why[l.problem ?? ""] ?? "No valid licence"}: Actipass runs in evaluation mode (few files per batch, ProPASS settings, no statistics).`;
}

export interface LicenceRequest { name: string; org: string; email: string; mode: "PROPASS" | "ADVANCED" }
export interface RequestResult { file: string; plainFile: string; folder: string; details: string }

export function writeRequest(r: LicenceRequest): Promise<RequestResult> {
  return request<RequestResult>("licence.request", { ...r });
}

export function installLicence(files: string[]): Promise<Licence> {
  return request<Licence>("licence.install", { files });
}

function mailText(r: LicenceRequest, renew: boolean, attached: boolean) {
  const subject = `Actipass licence ${renew ? "renewal" : "request"}: ${r.name}, ${r.org}`;
  const body = [
    "Dear Actipass developers,",
    "",
    `I would like to ${renew ? "renew my" : "request a"} licence for Actipass on this computer.`,
    "",
    `Name: ${r.name}`,
    `Organisation: ${r.org}`,
    `Email: ${r.email}`,
    `Licence mode: ${r.mode}`,
    "",
    attached ? "The licence request file Host-Details.txt is attached." : "[Attach the licence request file Host-Details.txt here.]",
    "",
    "Kind regards,",
    r.name,
  ].join("\r\n");
  return { subject, body };
}

/** Open a new mail to the developers with Host-Details.txt attached (default mail program).
 *  Without a mail program that accepts attachments, opens a mailto: mail and shows the file
 *  in the file manager to attach by hand. Nothing is sent without the user. */
export async function mailRequest(r: LicenceRequest, renew: boolean, file: string): Promise<"attached" | "manual"> {
  try {
    const { subject, body } = mailText(r, renew, true);
    await invoke<string>("mail_with_attachment", { to: LICENCE_TO, cc: LICENCE_CC, subject, body, attachment: file });
    return "attached";
  } catch {
    const { subject, body } = mailText(r, renew, false);
    const q = (s: string) => encodeURIComponent(s);
    await openUrl(`mailto:${LICENCE_TO.join(",")}?cc=${q(LICENCE_CC.join(","))}&subject=${q(subject)}&body=${q(body)}`).catch(() => {});
    await revealItemInDir(file).catch(() => {});
    return "manual";
  }
}

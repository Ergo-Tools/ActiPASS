// Page changes asked for by a page (e.g. Statistics -> Settings, Statistics options): the main page
// switches to the page and scrolls to the settings section (SettingsSections ids "settings-<id>").
// SPDX-License-Identifier: GPL-3.0-or-later
import type { StageId } from "./stages";

export const nav = $state<{ request: { page: StageId; section?: string } | null }>({ request: null });

export function goTo(page: StageId, section?: string) {
  nav.request = { page, section };
}

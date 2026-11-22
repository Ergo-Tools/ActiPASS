// Open state of the licence dialog and the banner (evaluation mode / licence expiring soon).
// SPDX-License-Identifier: GPL-3.0-or-later

export const licenceUi = $state({
  /** the licence dialog is open */
  open: false,
  /** the banner was closed in this session (it returns at the next start) */
  bannerClosed: false,
});

export function openLicenceDialog() {
  licenceUi.open = true;
}

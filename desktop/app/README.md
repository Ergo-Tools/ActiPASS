# app

Tauri v2 app: Svelte 5 + TypeScript front end (SvelteKit, static adapter, `src/`) and a Rust
shell (`src-tauri/`). Scaffolded with `create-tauri-app` (svelte-ts template); still the
template page. Identifier: `se.uu.medsci.actipass`.

## Requirements

- Node.js LTS, Rust stable (rustup)
- Windows: Visual Studio Build Tools with "Desktop development with C++", WebView2 (built into Windows 11)
- macOS / Linux: see https://tauri.app/start/prerequisites/

## Commands (run in this folder)

```
npm install
npm run tauri dev                       # run with hot reload
npm run check                           # svelte-check / TypeScript
npm run tauri build                     # release build + installers
npm run tauri build -- --debug --no-bundle   # quick debug exe, no installer
```

Icons in `src-tauri/icons` were generated from ActiPASSV2 `actipass_square_231024.png`
with `npx tauri icon <png>` (Android/iOS icons removed).

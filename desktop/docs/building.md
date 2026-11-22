# Building Actipass desktop

How to run the desktop app for development, build the compiled engine and build the Windows
installer. Commands are for Windows PowerShell; run them in a fresh shell after installing the tools
(or put Node and cargo on `PATH`: `$env:Path = "$env:LOCALAPPDATA\Programs\nodejs;$env:USERPROFILE\.cargo\bin;$env:Path"`).

## 1. Tools

| Tool | Used for | Notes |
|---|---|---|
| [Node.js](https://nodejs.org/) LTS | front end (Vite, SvelteKit), Tauri CLI, build scripts | per-user install is fine |
| [Rust](https://rustup.rs/) stable, MSVC toolchain | Tauri shell (`app/src-tauri`) | `rustup default stable-x86_64-pc-windows-msvc` |
| Visual Studio Build Tools, "Desktop development with C++" | Rust linker, Windows SDK | |
| MATLAB R2024b + MATLAB Compiler | compiled engine and its installer | the release the classic GUI is built with (`ActiPASS_UI_MATLAB2024.prj`) |
| MATLAB (any recent release) | engine during development | the app starts `matlab -batch` |
| R (64-bit), optional | the `raw+posture` intensity algorithm | only to test that algorithm |

WebView2 is part of Windows 10/11.

## 2. Checkouts

Next to each other (the defaults of `engine-matlab/paths.example.json`):

```
Ergo-Tools/
  actipass-desktop/     this repository
  ActiPASSV2/           branch desktop-engine
  Utils/
  BinaryFileSupport/
```

Copy `engine-matlab/paths.example.json` to `engine-matlab/paths.local.json` (not tracked) and adjust the
folders if they are elsewhere. Then install the front-end packages once:

```powershell
cd actipass-desktop\app
npm install
```

## 3. Development

```powershell
cd actipass-desktop\app
npm run dev:app
```

This runs `tauri dev` with the ActiPASS version in the title (`2026.11.3-alpha (development build)`).
The app starts MATLAB (`matlab -batch`, MATLAB must be on `PATH` or set on the Engine page) and runs the
engine from `engine-matlab/` directly, so MATLAB changes need only an engine restart (Engine page:
Stop, Start). Front-end changes reload at once; Rust changes rebuild and restart the app.

To debug the engine in MATLAB: Engine page > "Attach to a MATLAB I start myself", paste the shown
command in your MATLAB session (breakpoints work).

Checks: `npx svelte-check --tsconfig ./tsconfig.json` (in `app/`), `cargo check` (in `app/src-tauri/`),
`node tools/engine-smoke.mjs` (engine protocol test, from the repository root).

## 4. Release

The version has one source: `<param.version>` in `ActiPASSV2/ActiPASS_UI_MATLAB2024.prj`. The engine and
its installer get that version; the app gets `<version>-<PRERELEASE>` (`PRERELEASE` in
`tools/build-release.mjs`: `"alpha"` now, `""` for a final release).

1. **Compiled engine** (MATLAB R2024b, about 10 minutes):

   ```powershell
   cd actipass-desktop\tools
   & "C:\Program Files\MATLAB\R2024b\bin\matlab.exe" -batch "build_engine"
   ```

   Output: `engine-matlab/build/<version>/exe/actipass_engine.exe`, the "Actipass Engine" installer
   (downloads the MATLAB Runtime when installed) and a copy of it with `version.txt` in
   `engine-matlab/build/dist/`. Rebuild the engine after every change in `engine-matlab/` (including
   `settings.schema.json`) or in ActiPASSV2.

2. **App installer**:

   ```powershell
   cd actipass-desktop\app
   npm run build:release
   ```

   Output: `app/src-tauri/target/release/bundle/nsis/Actipass_<version>-alpha_x64-setup.exe`. It contains
   the engine installer from `engine-matlab/build/dist` and runs it during setup
   (`app/src-tauri/windows/engine-hooks.nsh`). The script stops if that engine installer has another version.

Close the development app before a release build: the running app locks `target/`, and the release build
regenerates `.svelte-kit/`, which makes a running development app reload.

## 5. Where things are

| Path | Contents |
|---|---|
| `app/src/routes/+page.svelte` | the window layout: top bar, sidebar, page area, log strip; page switching |
| `app/src/lib/stages/*.svelte` | one file per page (Project, Data, Diary, Settings, Process, Qc, Stats, Tools, Engine, About) |
| `app/src/lib/components/*.svelte` | shared parts: TopBar, Sidebar, LogStrip, SettingsSections/SettingField (forms from the schema), ToolCard, HelpLink, LicenceDialog, LicenceBanner |
| `app/src/lib/*.svelte.ts`, `*.ts` | state and logic: engine connection (`engine.svelte.ts`), project, batch and settings (`batch.svelte.ts`), checks, QC, licence, help links (`help.ts`), sidebar pages (`stages.ts`) |
| `app/src/app.css` | colours (light and dark), fonts, buttons, cards |
| `app/static/` | images (About picture, favicon); the app icons are in `app/src-tauri/icons/` |
| `app/src-tauri/` | Rust shell: engine process and socket (`src/engine.rs`), QC figures (`src/qc.rs`), mail (`src/mail.rs`), `tauri.conf.json`, installer hooks |
| `engine-matlab/` | MATLAB engine: `actipass_engine.m`, `cmd_*.m` method handlers, `settings.schema.json` (settings pages) |
| `tools/` | build scripts and engine test clients |
| `docs/plan.md` | design and plan |

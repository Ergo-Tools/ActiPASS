# Building the Actipass desktop app from source

This guide is for anyone who wants to build the Actipass desktop app (the user interface) from its
source code. It builds the app's executable only. The app does no processing itself: it needs the
**Actipass Engine**, a separate program that is not part of this source code. Install the engine once
with the official Actipass installer (it installs the app and the engine); the app you build then uses
that engine. See the [Actipass desktop app user manual](https://github.com/Ergo-Tools/ActiPASS/wiki/Desktop-App-User-Manual)
and [Actipass engine and protocol](https://github.com/Ergo-Tools/ActiPASS/wiki/Desktop-App-Engine-and-protocol).

The commands below are for Windows PowerShell.

## 1. Install the tools

| Tool | Notes |
|---|---|
| [Node.js](https://nodejs.org/) (LTS) | builds the user interface (Svelte, TypeScript) |
| [Rust](https://rustup.rs/) (stable) | builds the small native shell; on Windows choose the MSVC toolchain |
| [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/), workload "Desktop development with C++" | the linker and Windows SDK that Rust needs |

Microsoft Edge WebView2, which the app uses to show its pages, is part of Windows 10 and 11.

Check the installation in a new PowerShell window:

```powershell
node --version
cargo --version
```

## 2. Get the source

Download or clone the [Actipass repository](https://github.com/Ergo-Tools/ActiPASS). The app is in the
folder `desktop/app`:

```powershell
git clone https://github.com/Ergo-Tools/ActiPASS.git
cd ActiPASS\desktop\app
npm ci
```

`npm ci` installs the packages listed in `package-lock.json` (once, and again after an update of the source).

## 3. Build the executable

```powershell
Set-Content version.json '{"version": "2026.11.3"}'
npx tauri build --no-bundle --config version.json
```

Write the Actipass version of the source (see `ChangeLog.txt` in the repository root) in `version.json`
instead of 2026.11.3: the app compares it with the engine's version. Without `--config`, the app has the
placeholder version 0.1.0 and warns that the engine has another version.

The first build takes several minutes (Rust compiles all its packages); later builds are faster. The
result is

```
desktop\app\src-tauri\target\release\actipass-desktop.exe
```

`--no-bundle` builds only the executable, without an installer. Copy it anywhere and start it.

## 4. Run it with the installed engine

The app looks for the engine at `C:\Program Files\Ergo-Tools\Actipass Engine\application\actipass_engine.exe`,
where the official installer puts it, and starts it automatically. If the engine is somewhere else, choose
it on the app's **Engine** page (**Installed engine**, then the engine file). The engine must have the same
Actipass version as the app source (the title bar and the About page show the app version); otherwise the
app shows a warning.

To try changes while you work on the user interface, start the app in development mode instead:

```powershell
npx tauri dev
```

The window reloads when you change a file under `src/`. A development build starts MATLAB by default
(this is how the developers run the engine source); on the **Engine** page choose **Installed engine**
to use the installed engine instead.

## 5. Where things are

| Path | Contents |
|---|---|
| `app/src/routes/+page.svelte` | the window layout: top bar, sidebar, page area, log strip |
| `app/src/lib/stages/` | one file per page (Project, Data, Diary, Settings, Process, Quality check, Statistics, Tools, Engine, About) |
| `app/src/lib/components/` | shared parts: top bar, sidebar, log, settings forms, tool cards, licence dialog |
| `app/src/lib/*.ts` | state and logic: engine connection, project, batch and settings, checks, quality check, help links |
| `app/src/app.css` | colours (light and dark), fonts, buttons, cards |
| `app/src-tauri/` | Rust shell: starts the engine and talks to it (`src/engine.rs`), QC figures, mail; `tauri.conf.json` |
| `protocol/` | the protocol between the app and the engine |

## License

The desktop app source is licensed under the GNU General Public License, version 3.0 or later (see
`../LICENSE.md`). The Actipass Engine is distributed in compiled form under the
[Actipass End-User License Agreement](https://github.com/Ergo-Tools/ActiPASS/wiki/License-agreement#license-and-usage-agreement).

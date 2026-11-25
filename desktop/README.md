# Actipass desktop app

The Actipass desktop app is the new user interface of Actipass: a Windows desktop application
(built with [Tauri](https://tauri.app/), a Svelte + TypeScript front end and a small Rust shell)
that guides you through a project: data, diary and calibration, settings, processing, quality
check, statistics and tools. It is released together with the classic Actipass app, with the same
version number, and gives the same results.

- **User manual:** [Actipass desktop app user manual](https://github.com/Ergo-Tools/ActiPASS/wiki/Desktop-App-User-Manual)
- **Installer:** the Windows setup (`Actipass_<version>_x64-setup.exe`) installs the app and the
  Actipass engine (which downloads the MATLAB Runtime during setup). No MATLAB licence is needed.

## How it works

The app does no processing itself. It starts the **Actipass engine**, a separate program, and talks to
it over a local socket with JSON-RPC 2.0 (see [`protocol/`](protocol/)). The engine runs the
Actipass algorithms (the MATLAB code in this repository's `algorithms/`, `library/`, `stats/` and
`utils/` folders) and handles the licence. The engine is distributed in compiled form only, under the
[End-User License Agreement](https://github.com/Ergo-Tools/ActiPASS/wiki/License-agreement#license-and-usage-agreement);
its source is not in this repository.

## Contents

| Folder | Contents |
|---|---|
| `app/src/` | front end: window layout (`routes/+page.svelte`), one file per page (`lib/stages/`), shared components (`lib/components/`), state and logic (`lib/*.ts`), styles (`app.css`) |
| `app/src-tauri/` | Rust shell: starting and connecting to the engine, QC figures, mail; Tauri configuration and installer hooks |
| `protocol/` | the JSON-RPC protocol between the app and the engine |
| `tools/` | release build script and small engine test clients |
| `docs/building.md` | how to build and run the app |

## Building

See [docs/building.md](docs/building.md). In short: Node.js, Rust and the Visual Studio C++ build
tools; `npm install` and `npm run dev:app` in `app/`.

Notes for this public copy:

- Only the generic protocol layer of the engine is included ([`engine-matlab/`](engine-matlab/README.md)); the
  handlers that run the Actipass workflow are part of the compiled engine. To run the app you need an
  installed Actipass engine (install the Actipass desktop app once, then choose **Installed engine** on
  the app's Engine page), or your own engine that implements the protocol.
- `npm run build:release` builds the setup around the compiled engine installer, so it needs that
  installer; `npx tauri build` builds the app alone.

## License

The desktop app is licensed under the GNU General Public License, version 3.0 or later; the Actipass
algorithms are licensed under the BSD 3-Clause License. See [LICENSE.md](LICENSE.md).

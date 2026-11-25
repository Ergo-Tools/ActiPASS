# engine-matlab (protocol layer)

The generic part of the Actipass engine: the MATLAB side of the [engine protocol](../protocol/README.md)
(JSON-RPC 2.0, one JSON message per line over a localhost TCP socket; the desktop app listens, the engine
connects back with a token). Licensed under GPL-3.0-or-later, like the rest of `desktop/`.

| File | Role |
|---|---|
| `actipass_engine_main.m` | Main of the compiled engine: `actipass_engine.exe <port> <token> [host] [idleTimeout]` |
| `actipass_engine.m` | Entry point `actipass_engine(port, token)`: connect, send `engine.hello` (with the token), serve requests until `engine.shutdown`, a lost connection or 60 s without messages |
| `EngineConn.m` | Socket, line framing, responses and notifications; `poll()` answers `job.cancel` and `engine.ping` while a handler runs and rejects other requests as busy (-32001) |
| `IpcProgress.m` | Stand-in for `uiprogressdlg` (Value, Message, CancelRequested, close) that sends `progress` notifications, so workflow functions can run without a GUI |
| `engineHandlers.m` | Method name → handler (`result = handler(params, conn)`) |
| `settings.schema.json`, `engineSchema.m` | Description of every setting (section, page, label, type, choices, limits, help); the app draws its forms from it |
| `engineTypeName.m` | Device type names for the file type numbers |
| `engineBuild.m` | Build number of a compiled engine |
| `cmd_debug_demoJob.m` | `debug.demoJob`: a fake batch to test progress, logging and cancel |
| `paths.example.json` | Template of `paths.local.json` (folders of the Actipass MATLAB code) |

Not published: the handlers that run the Actipass workflow and manage projects, settings and licences
(`cmd_batch_run`, `cmd_stats_run`, `cmd_settings`, `cmd_project_*`, `cmd_qc`, `cmd_tools`, `cmd_files_scan`,
`cmd_licence` and their helpers `engineProject`, `engineAppSettings`, `engineApplyLicence`, `engineLicence`,
`engineHostInfo`, `engineAccFiles`, `engineSetupPaths`, `engineActipassVersion`, `enginePropassKeep`).
They are part of the compiled Actipass engine, which is distributed under the
[Actipass End-User License Agreement](https://github.com/Ergo-Tools/ActiPASS/wiki/License-agreement#license-and-usage-agreement).
Their methods and parameters are documented in the [protocol](../protocol/README.md), so another engine can
implement them.

Errors: -32601 unknown method, -32001 busy, -32800 canceled (a handler threw `ActiPASS:Canceled`),
-32000 other MATLAB error (`data.report` holds the full report).

SPDX-License-Identifier: GPL-3.0-or-later

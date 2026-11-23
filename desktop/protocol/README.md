# Actipass engine protocol

How the Actipass desktop app (and any other client) talks to the Actipass engine.

The engine is a separate program: the MATLAB code in [`../engine-matlab`](../engine-matlab), run in
MATLAB or compiled with MATLAB Compiler to `actipass_engine.exe`. The app never links to it; all
communication goes through the protocol described here. Everything in this file is taken from the
code: [`actipass_engine.m`](../engine-matlab/actipass_engine.m),
[`actipass_engine_main.m`](../engine-matlab/actipass_engine_main.m),
[`EngineConn.m`](../engine-matlab/EngineConn.m), [`IpcProgress.m`](../engine-matlab/IpcProgress.m),
[`engineHandlers.m`](../engine-matlab/engineHandlers.m), the `cmd_*.m` handlers,
[`settings.schema.json`](../engine-matlab/settings.schema.json), the app side in
[`../app/src-tauri/src/engine.rs`](../app/src-tauri/src/engine.rs) and the minimal Node client
[`../tools/engine-client.mjs`](../tools/engine-client.mjs). If the code and this file disagree, the
code is right; please fix this file.

## Transport

- **JSON-RPC 2.0**, one JSON message per line: NDJSON, UTF-8, each message ends with a line feed
  (`\n`). Empty lines are ignored.
- **Localhost TCP.** The **app is the server**: it listens on `127.0.0.1:<port>` (the desktop app
  takes a random free port). The **engine is the client**: it connects to that port.
- Only one engine connection is used at a time. A disconnected engine may connect again to the same
  port with the same token (the app keeps listening).
- No bulk data goes over the socket. Messages carry file paths, settings and small tables; all
  outputs are files in the project folder, which the app reads directly.

### Starting the engine

Compiled engine (`actipass_engine_main.m`):

```
actipass_engine.exe <port> <token> [<host>] [<idleTimeoutSec>]
```

| Argument | Meaning |
|---|---|
| `port` | TCP port the app listens on (integer 1..65535). |
| `token` | One-time token chosen by the app for this start. |
| `host` | Host to connect to; default `127.0.0.1`. An empty argument keeps the default. |
| `idleTimeoutSec` | Seconds without a message from the app before the engine stops; default 60. |

With fewer than two arguments the exe prints a usage line and exits with status 2; an invalid port
or another start error exits with status 1. The installed engine is
`%ProgramFiles%\Ergo-Tools\Actipass Engine\application\actipass_engine.exe` (MATLAB Runtime R2024b).

In MATLAB (development, from the `engine-matlab` folder):

```matlab
actipass_engine(port, token)
actipass_engine(port, token, Host="127.0.0.1", IdleTimeout=60, Backtrace="on")
```

`Backtrace="off"` hides the code location lines under warnings; a compiled engine always hides them.
In MATLAB the engine puts ActiPASSV2, Utils and BinaryFileSupport on the path from
`paths.local.json` (copy of `paths.example.json`) next to `actipass_engine.m`.

The desktop app starts the engine in one of three modes (`engine.rs`):

- `compiled`: `actipass_engine.exe <port> <token>`.
- `launch`: `matlab -batch "cd('<engineDir>'); actipass_engine(<port>, '<token>')"`.
- `attach`: the app only listens and shows that command; the developer runs it in their own MATLAB.

The app passes neither host nor idle timeout, so the defaults apply.

### Handshake: `engine.hello`

After connecting, the engine's **first message** is the notification `engine.hello`. The app reads the
first line of a new connection (waiting at most 10 s) and **drops the connection** if it is not
`engine.hello` with the token it gave the engine. After a good hello both sides exchange JSON-RPC
messages.

`engine.hello` params:

| Field | Type | Meaning |
|---|---|---|
| `token` | string | The token from the command line. The app removes it before showing the hello. |
| `engine` | string | `"matlab"`. |
| `engineVersion` | string | ActiPASS version, e.g. `"2026.11.3"` (`"unknown"` if it cannot be read). |
| `engineBuild` | string | Build of a compiled engine, e.g. `"2026.11.3.32718"`; `""` in MATLAB. The desktop app compares it with the engine build it was released with. |
| `matlabVersion` | string | Output of MATLAB `version` (MATLAB or MATLAB Runtime). |
| `deployed` | bool | `true` for the compiled engine. |
| `pid` | number | Process ID of the engine. |
| `paths` | object | `config`, `actipass`, `utils`, `binaryFileSupport` (folders used in MATLAB; `""` when compiled), `actipassFound` (bool: the ActiPASS processing code was found), `warnings` (array of strings). |

### Messages

Requests (app to engine) are ordinary JSON-RPC requests with a numeric `id`, a `method` and
`params` (an object; missing or empty params are treated as `{}`):

```json
{"jsonrpc":"2.0","id":7,"method":"project.open","params":{"dir":"D:/Study1"}}
```

Responses carry the same `id` and either `result` or `error` (`{code, message, data?}`). A request
without `id` (a notification) is run but gets no response; its errors only go to the engine's
standard error output.

Messages from the engine without `id` and with a `method` are notifications: `engine.hello`,
`progress` and `log`. Messages from the app without `method` (responses) are ignored by the engine;
the engine sends no requests to the app.

Note on JSON encoding: the engine encodes with MATLAB `jsonencode` and decodes with `jsondecode`.
Lists in the results below are JSON arrays (the handlers take care of single elements). For
parameters, send lists as JSON arrays; a single path may also be sent as a string.

## Liveness and concurrency

- **Heartbeat.** The app sends `engine.ping` every 10 s while connected (and waits up to 30 s for the
  answer). The engine stops when it has received **no message** for `IdleTimeout` seconds (default
  60), so an engine is not left running when the app is gone. Any message resets this timer.
- **One request at a time.** The engine runs one handler at a time (a "job"). While a job runs, the
  engine reads the socket whenever the job checks for a cancel (the workflow does this often, through
  `IpcProgress.CancelRequested`). Then:
  - `engine.ping` is answered with `{"busy": true, "method": "<running method>"}`.
  - `job.cancel` is answered with `{"canceling": "<running method>"}` and sets the cancel flag; the
    running job then ends with error -32800 (or, for `batch.run`, may return a result with
    `status: "Canceled"`, see below).
  - `engine.shutdown` cancels the running job; it is answered after the job has ended, and then the
    engine stops.
  - **Every other request is rejected** at once with error **-32001** (`"Engine busy with <method>"`).
    Wait for the job's response and send the request again.
  - Notifications from the app are ignored while a job runs.

  A job step that does not check for a cancel delays these answers until it does.
- **Idle.** `engine.ping` and `job.cancel` (nothing to cancel) are both answered with
  `{"busy": false, "time": "yyyy-MM-dd HH:mm:ss"}`.

### Engine methods

| Method | Params | Result |
|---|---|---|
| `engine.ping` | none | Idle: `{busy: false, time}`. Busy: `{busy: true, method}`. |
| `job.cancel` | none | Busy: `{canceling: method}`. Idle: `{busy: false, time}`. |
| `engine.shutdown` | none | `{stopping: true}`; then the engine closes the connection and exits. |

## Error codes

| Code | Meaning |
|---|---|
| -32700 | Parse error: a line was not valid JSON. Sent with an empty `id` (`[]`), so it cannot be matched to a request. |
| -32601 | Method not found (`"Method not found: <method>"`). |
| -32001 | Engine busy: another job is running (see above). |
| -32800 | Canceled: the job was canceled by `job.cancel` (or `engine.shutdown`). Message `"Canceled"`. |
| -32000 | MATLAB error in the handler. `message` is the error message; `data.identifier` is the MATLAB error identifier and `data.report` the full error report (with stack). |

Identifiers used by the handlers in `data.identifier` with -32000:

| Identifier | Meaning |
|---|---|
| `ActiPASS:BadParams` | Missing or invalid parameters, missing folders/files, value out of range. |
| `ActiPASS:NoProject` | A project is needed (settings change without `projectDir`). |
| `ActiPASS:Batch` | `batch.run` could not prepare or run the batch (no files, diary error, R missing, ...). |
| `ActiPASS:Stats` | `stats.run` failed (evaluation mode, no master QC table, genStats error). |
| `ActiPASS:Tool` | A tool is not available (ProPASS mode, no completed batch, older project without file paths). |
| `ActiPASS:Licence` | A licence request or installation failed. |
| others | Unexpected errors of the processing code. `batch.run`, `stats.run` and `tools.*` then also write a crash log to `<project>/crashLogs`. |

Errors made by the desktop app itself (never sent by the engine; `engine.rs`): -32002 engine not
connected, -32003 engine disconnected while the request was waiting.

## Notifications from the engine

### `progress`

Sent by jobs that report progress (`IpcProgress`, a stand-in for MATLAB's `uiprogressdlg`).
Throttled: at most about every 0.15 s while the message is unchanged; always sent at the start and
end of a job and when the message changes.

| Field | Type | Meaning |
|---|---|---|
| `job` | string | The method of the job, e.g. `"batch.run"`, `"stats.run"`, `"tools.wbv"`, `"debug.demoJob"`. |
| `title` | string | Title of the job, e.g. `"Batch 2026-11-23 10.15.02"`, `"Statistics"`. |
| `value` | number | Fraction done, 0..1. |
| `message` | string | Current step, as the classic GUI's progress dialog shows it. |
| `indeterminate` | bool | `true` when no fraction is known (show a busy indicator). |

### `log`

A line for the app's log.

| Field | Type | Meaning |
|---|---|---|
| `level` | string | `info`, `warning` (also warnings the classic GUI showed as alerts), `error` (tool errors), `batch` (lines of the batch log file `Actipass_BatchLog.txt`, sent while the batch writes them), `tool` (one line per subject of a tool, and tool messages). |
| `text` | string | The text. |
| `time` | string | `HH:mm:ss`; for `batch` lines the time written in the batch log (may be `""`). |

## Methods

The methods are listed in [`engineHandlers.m`](../engine-matlab/engineHandlers.m); each calls
`result = handler(params, conn)` in a `cmd_*.m` file. Paths are full paths as strings. "Project" is
an Actipass project folder (see the
[project folder structure](https://github.com/Ergo-Tools/ActiPASS/wiki/ActiPASS-project-folder-structure)).

Settings are **per project**: a project keeps them in `<project>/ProjectSettings/Actipass_UI.conf`
and `AktDetect_UI.conf`. A project without these files uses the user's global (last used) settings
until it is saved (`settings.set` and `batch.run` save it). The engine keeps the settings of the last
used project in memory between requests. Licence, evaluation and ProPASS modes are applied on top.

### `project.open`

Read-only summary of a project folder. Nothing is created or changed.

Params: `dir` (required), `quiet` (bool, optional: no log line).

Result:

| Field | Meaning |
|---|---|
| `dir`, `exists`, `empty` | The folder, whether it exists, whether it has no files or folders. |
| `hasMasterQC`, `masterQCFile` | Whether `Actipass_QC_MasterFile.xlsx` exists, and its path. |
| `summary` | Counts from the master QC table: `totalFiles`, `checkQC`, `noWalking`, `tooMuchStair`, `tooMuchOther`, `notEnoughWear`, `notEnoughSI`, `fileErrors`. |
| `batches` | Batch names in the master QC table (array, oldest first). |
| `batchFolders` | Folder names in `BatchOut` (includes unfinished batches). |
| `lastBatch` | The newest batch of the master QC table (`""` if none). |
| `masterTrunk`, `masterCalf` | The master QC table has trunk / calf columns. |
| `masterFilePaths` | The master QC table has a `FilePath` column (older projects do not). |
| `warnings` | E.g. the master QC table cannot be read. |

### `project.cleanBatches`

Permanently deletes unfinished or empty batch folders (folders in `BatchOut` that are not a batch of
the master QC table). Refused when the master QC table exists but cannot be read.

Params: `dir` (required), `batches` (folder names to delete; each must be such a folder).

Result: `deleted` (names), `failed` (names that could not be deleted, e.g. files in use),
`batchFolders` (folders left in `BatchOut`).

### `qc.table`

A QC table, all values as text.

Params: `projectDir` (required), `batch` (optional; `""` or missing: the master QC table
`Actipass_QC_MasterFile.xlsx`, otherwise `BatchOut/<batch>/Actipass_BatchQC.csv`).

Result:

| Field | Meaning |
|---|---|
| `source` | `"master"` or `"batch"`. |
| `batch`, `file` | The batch (`""` for master) and the table file. |
| `columns` | Column names. |
| `rows` | Array of rows; each row an array of strings, `null` where there is no value. |
| `flags` | The flag columns present (e.g. `NoWalking`, `NotEnoughWear`, `DataFile_Errs`, `Calf_Errs`, `TooMuchKneel`). |
| `editable` | `QC_Status` can be changed (master table only). |

### `qc.setStatus`

Sets `QC_Status` of subjects in the master QC table. The table is first copied to
`<project>/Backups/Actipass_QC_MasterFile_backup_<time>.xlsx`.

Params: `projectDir` (required), `changes`: array of `{id, status}` (`id` = SubjectID, `status` =
`"OK"`, `"Check"` or `"NotOK"`).

Result: `saved` (number of changes), `backup` (path), `table` (the master table, as `qc.table`).

### `tools.*`

The tools of the classic GUI's Tools menu, without dialogs: the GUI's questions are parameters with
the same choices and defaults. Each reports `progress` (job `tools.<name>`) and `log` lines (level
`tool`, one per subject), and appends to `Actipass_ToolLog.txt` in its output folder. All tools except
`tools.diaryQC` need `projectDir`, and all except `tools.longFormat` and `tools.diaryQC` need a
completed batch (master QC table). `tools.mergeSleep` and the experimental tools (`sitToStand`,
`clinicalSts`, `wbv`) are not available in ProPASS mode.

| Method | Params (default in bold) | Output |
|---|---|---|
| `tools.longFormat` | `projectDir` | `ProPASS_LongFormat_MasterFile.csv` from `ProPASS_WideFormat_MasterFile.csv` (needs statistics in the Daily table format). |
| `tools.export1s` | `projectDir` | Folder `1S_CSV_Export` (one CSV of per-second activity data per subject). |
| `tools.diaryQC` | `diaryFile`, `outDir` (both required) | Folder `<outDir>/Diary_quality_checks`. |
| `tools.mergeSleep` | `projectDir`, `exclusions` (`None`, **`NotOK`**, `Check+NotOK`) | Folder `SleepData_Export`. |
| `tools.sitToStand` | `projectDir`, `exclusions` (`None`, `NotOK`, **`Check+NotOK`**), `fs` (**25**, 50, 100), `axOrient` (**`New`**, `Old`; only used for CWA files), `filtMode` (**`Löppönen`**, `Pickford`), `calMode` (**`upright`**, `standmove`, `stand`), `rawDir` | Folder `STS_Export_<filtMode>_<calMode>`. |
| `tools.clinicalSts` | `projectDir`, `exclusions` (`None`, `NotOK`, **`Check+NotOK`**), `prom` (40, **50**, 60), `width` (0.1, **0.2**, 0.3), `sep` (0.3, **0.5**, 0.7), `rawDir` | Folder `Clinical_STS_Counts`. |
| `tools.wbv` | `projectDir`, `exclusions` (**`None`**, `NotOK`, `Check+NotOK`), `rawDir` | File `WBV_DATA_Filled_all_sitting_segments.csv`. |

`rawDir`: the folder with the raw accelerometer files, needed only for older projects whose master
QC table has no `FilePath` column.

Result (all tools): `status` (`"OK"` all files done, `"Check"` some files could not be processed,
`"Error"` none), `message` (the classic GUI's message), `output` (output folder or file).

### `settings.get`, `settings.set`, `settings.saveAsDefault`

`settings.get` params: `projectDir` (optional; `""` or missing: the user's global settings, read
only), `reload` (bool, optional: read the files again, including the licence).

`settings.set` params:

- `projectDir` (required).
- `values` (optional): `{KEY: value}` for settings listed in `settings.schema.json`, plus `PROPASS`.
  Each value is checked against the schema (type, choices, `min`/`max`). In ProPASS mode only fields
  with `"propass": true` can be changed. `PROPASS` cannot be turned off with a ProPASS licence;
  turning ProPASS mode on resets the other settings to the defaults and keeps the project's own
  settings, which come back when ProPASS mode is turned off again.
- `params` (optional): `{NAME: number or number array}` for algorithm parameters (same size as the
  current value, finite numbers). Not allowed in ProPASS mode.

The settings are saved to the project at once.

`settings.saveAsDefault` params: `projectDir` (required). The project's settings become the user's
global settings (the start of new projects; also used by the classic GUI).

Result (all three):

| Field | Meaning |
|---|---|
| `settings` | Values of the schema fields plus `PROPASS`, `EVALV`, `trunkAccDir`, `calfAccDir`, `thighAccDir`, `diary_file`, `pers_file`, `cal_file`, `out_folder`, `Version`. |
| `params` | Algorithm parameters (name: number or array). |
| `defaults` | `{settings, params}`: the Actipass defaults, for "restore defaults". |
| `schemaJson` | The text of `settings.schema.json` (a string; parse it on the app side). |
| `source` | `"project"` (the project's own settings) or `"global"` (not saved to the project yet). |
| `projectDir` | The project (`""` for global). |
| `configFile` | The settings file in use. |
| `version` | ActiPASS version. |
| `maxFiles` | Maximum files per batch (10 in evaluation mode). |
| `licence` | The licence status, as `licence.status`. |

### `licence.status`, `licence.request`, `licence.install`

`licence.status`: no params. Result: `valid`, `evaluation`, `propass` (bools), `mode` (`"PROPASS"`,
`"ADVANCED"` or `""`), `text` (shown in About), `problem` (`""`, `none`, `invalid`, `host`,
`expired`, `mode`), `user`, `email`, `org`, `date`, `expires` (`yyyy-MM-dd`), `daysLeft` (-1 when
unknown), `expiring` (bool), `folder`, `requestFile`.

`licence.request` params: `name`, `org`, `email`, `mode` (`PROPASS` or `ADVANCED`), all required.
Writes a licence request to be sent to the developers. Result: `file` (the request file to send),
`plainFile` (a readable copy), `folder`, `details` (text).

`licence.install` params: `files` (paths of the two licence files received from the developers).
Result: the new licence status (as `licence.status`). Settings are reloaded with the new licence.

### `files.scan`

Device type and subject IDs of accelerometer files. Nothing is written.

Params: `files` (required: full paths of data files, or one Excel file list), `projectDir` (optional:
the project whose ID format and length are used; otherwise the global settings).

Result:

| Field | Meaning |
|---|---|
| `ftype`, `typeName` | Device type number and name (e.g. 1 `"Axivity CWA"`). |
| `needsSensorLocation` | SENS or Movisens files: `batch.run` needs `sensorLocation`. |
| `status` | A warning, or `""`. |
| `rows` | Array of `{id, file, filename, trunkFile, calfFile}` (`trunkFile`/`calfFile`: full paths from an Excel file list, `""` otherwise). |
| `trunkFiles`, `calfFiles` | Whether the file list gave trunk / calf files. |

### `batch.run`

Prepares and processes one batch, as the classic GUI does from "Choose Acc Files" to the end of
processing: project folders (`crashLogs`, `IndividualOut`, `Backups`), a new batch folder
`BatchOut/<yyyy-MM-dd HH.mm.ss>` with its batch log, IDs, diary, calibration, the R check for the
`raw+posture` intensity algorithm, processing, the batch summary and the orientation check. Uses and
saves the project's settings. Questions the classic GUI asks in dialogs are parameters; ask them
before sending the request.

Params:

| Param | Meaning |
|---|---|
| `projectDir` | Project folder (required, must exist). |
| `files` | Accelerometer files or one Excel file list (required). |
| `diaryFile` | Actipass diary (`.xlsx`/`.xls`); `""` or missing: no diary. |
| `calFile` | Device calibration file; `""` or missing: none. With the setting `ADDAUTOCAL` on, a missing file is created with the autocalibration results. |
| `sensorLocation` | For SENS and Movisens files: `Front-thigh`, `Right-thigh-side` or `Left-thigh-side`. |
| `trunkDir`, `calfDir` | Folders with the trunk / calf files, when that sensor is on and no file list gives them (default: the project's last folder). |

Progress: job `batch.run`; the batch log lines arrive as `log` notifications with level `batch`.

Result:

| Field | Meaning |
|---|---|
| `status` | The processing status (e.g. `"Canceled"` when the batch was canceled). |
| `batch`, `batchDir` | Batch name and folder. |
| `elapsedSec` | Processing time in seconds. |
| `summary` | `totalFiles`, `checkQC`, `fileErrors`, `notEnoughWear`, `noWalking`, `tooMuchOther`, `tooMuchStair`, `notEnoughSI` (empty object when canceled). |
| `orientationWarning` | Text when the detected orientations do not match the chosen defaults, else `""`. |
| `statusText` | The status line the classic GUI shows. |

A cancel may also end the request with error -32800 instead of a result.

### `stats.run`

Generates the statistics tables of a project (as "Generate Stats" in the classic GUI). The
statistics choices are settings (schema section `statsGen` and the statistics options): set them
with `settings.set` first. Not available in evaluation mode.

Params:

| Param | Meaning |
|---|---|
| `projectDir` | Project folder (required). |
| `batch` | Batch name for "selected batch only"; `""` or missing: all batches. |
| `epochCSV` | Save epoch level time series: `"No"` (default), `"1s"`, `"10s"`, `"60s"` (to `<project>/epoch_data`). |
| `persFile` | Personal data table (SubjectID, Age, Sex, Height, Weight; CSV or Excel), needed when the setting `PERSDATA` is on; default: the project's last one. |

Progress: job `stats.run`; warnings appear as `log` with level `warning`.

Result: `status` (`"OK"`), `elapsedSec`, `warnings` (array of texts, e.g. incompatible tables that
were backed up), `tables` (paths of the master statistics tables that exist for the chosen table
format).

### `debug.demoJob`

A fake batch to test progress, logging and cancel. Reads and writes no data.

Params: `files` (default 5), `steps` (steps per file, default 10), `delay` (seconds per step, default
0.2).

Result: `{files, status: "Demo batch completed"}`. Progress job `debug.demoJob`, title
`"Demo batch"`.

## Example exchange

`>` app to engine, `<` engine to app (one JSON message per line; values shortened):

```
< {"jsonrpc":"2.0","method":"engine.hello","params":{"token":"9f2c...","engine":"matlab","engineVersion":"2026.11.3","engineBuild":"2026.11.3.32718","matlabVersion":"24.2.0.... (R2024b)","deployed":true,"pid":12345,"paths":{"config":"","actipass":"","utils":"","binaryFileSupport":"","actipassFound":true,"warnings":[]}}}
> {"jsonrpc":"2.0","id":1,"method":"debug.demoJob","params":{"files":2,"steps":2,"delay":0.5}}
< {"jsonrpc":"2.0","method":"progress","params":{"job":"debug.demoJob","title":"Demo batch","value":0,"message":"Initializing...","indeterminate":false}}
< {"jsonrpc":"2.0","method":"log","params":{"level":"info","text":"Demo batch started: 2 files x 2 steps","time":"10:15:02"}}
< {"jsonrpc":"2.0","method":"progress","params":{"job":"debug.demoJob","title":"Demo batch","value":0.25,"message":"File 1 of 2: step 1 of 2","indeterminate":false}}
> {"jsonrpc":"2.0","id":2,"method":"engine.ping","params":{}}
< {"jsonrpc":"2.0","id":2,"result":{"busy":true,"method":"debug.demoJob"}}
> {"jsonrpc":"2.0","id":3,"method":"settings.get","params":{}}
< {"jsonrpc":"2.0","id":3,"error":{"code":-32001,"message":"Engine busy with debug.demoJob"}}
  ... more progress and log ...
< {"jsonrpc":"2.0","id":1,"result":{"files":2,"status":"Demo batch completed"}}
> {"jsonrpc":"2.0","id":4,"method":"engine.shutdown","params":{}}
< {"jsonrpc":"2.0","id":4,"result":{"stopping":true}}
```

## Reference client (Node.js)

[`../tools/engine-client.mjs`](../tools/engine-client.mjs) is a minimal client: it listens on a
random localhost port, starts the engine (`matlab -batch ...`, or the compiled engine given as `exe`
or in the environment variable `ACTIPASS_ENGINE_EXE`), checks the hello token, pings every 10 s and
returns `{hello, request(method, params), close()}`. `request` resolves with the result or rejects
with the JSON-RPC error object. Example use:

```js
import { startEngine } from "./engine-client.mjs";

const eng = await startEngine({
  exe: "C:/Program Files/Ergo-Tools/Actipass Engine/application/actipass_engine.exe",
  onNotification: (method, p) =>
    method === "progress" ? console.log(`${Math.round(p.value * 100)}% ${p.message}`)
                          : console.log(`[${p.level}] ${p.text}`),
});
console.log("engine", eng.hello.engineVersion);
console.log(await eng.request("project.open", { dir: "D:/Study1" }));
await eng.close(); // engine.shutdown, wait for the process to exit
```

`tools/engine-smoke.mjs` (protocol smoke test) and `tools/engine-batch.mjs` (one real batch without
the app) use it.

## `settings.schema.json`

[`../engine-matlab/settings.schema.json`](../engine-matlab/settings.schema.json) describes the Actipass
settings the app shows. It is the single description of these settings for both sides:

- The **engine** sends it unchanged as the string `schemaJson` in every `settings.*` result, and
  checks every value of `settings.set` against it (unknown keys, type, choices, `min`/`max`,
  ProPASS mode).
- The **app** draws its setting forms from it (Data, Settings and Statistics pages), so a new setting
  needs no app code when an existing type fits.

Defaults are not in the schema: they come from the engine (ActiPASSV2 `LoadSettings`, sent as
`defaults`).

Top level: `version` (currently 1), `sections`, `fields`.

**Sections** (cards of fields):

| Key | Meaning |
|---|---|
| `id` | Section id, referenced by the fields. |
| `title` | Card title. |
| `page` | App page that shows the section: `data`, `settings`, `process` or `stats`. |
| `doc` | Place in the user manual, `"Page-Name#anchor"` of the wiki (e.g. `"Desktop-App-Manual-Settings#processing"`); the app shows a "?" link to `https://github.com/Ergo-Tools/ActiPASS/wiki/<doc>`. |
| `showIf` | Optional condition (below). When false, the fields are hidden and `hiddenText` is shown. |
| `hiddenText` | Text shown instead of a hidden section (default: "Not used with the current settings."). |

**Fields** (one per setting):

| Key | Meaning |
|---|---|
| `key` | Setting name, as in ActiPASSV2 `LoadSettings.m` (e.g. `IDMODE`, `TRUNKPOS`). |
| `section` | Section id. |
| `label`, `help` | Label and tooltip text. |
| `type` | `bool`, `number`, `text`, `choice` (one of `choices`) or `multi` (one or more of `choices`, a JSON array of strings). |
| `choices` | For `choice`/`multi`: array of `{value, label?}`; `label` defaults to `value`. |
| `min`, `max`, `step`, `unit` | For `number`: limits (checked by the engine), input step and unit text. |
| `propass` | `true`: the field can still be changed in ProPASS mode; all others are read only in ProPASS mode. |
| `showIf` | Optional condition (below): the field is shown only when it holds. |
| `doc` | Optional manual place, as for sections. |

**`showIf`**: `{"key": "<other setting>", "in": [values]}` or `{"key": ..., "notIn": [values]}`. The
app compares the other setting's current value, converted to a string (so a bool is `"true"` or
`"false"`), with the listed strings. Example: the trunk processing section has
`"showIf": {"key": "TRUNKPOS", "notIn": ["off"]}`. `showIf` only hides fields in the app; the engine
does not use it.

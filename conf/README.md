## Configuration files

Example configuration files in the JSON format ActiPASS uses (read by [`LoadSettings.m`](../library/LoadSettings.m)):

| File | Contents |
|---|---|
| [`ActiPASS_UI.conf`](ActiPASS_UI.conf) | Settings of the workflow and the user interface (IDs, orientation, processing options, statistics options) |
| [`AktDetect_UI.conf`](AktDetect_UI.conf) | Algorithm parameters (thresholds, reference angles, bout lengths, MET values) |

The apps keep these files in `%APPDATA%\Actipass` (the user's last used settings); the desktop app also keeps a copy per
project in `<project>\ProjectSettings`. See the settings in the
[desktop app user manual](https://github.com/Ergo-Tools/ActiPASS/wiki/Desktop-App-Manual-Settings) and
[Adjusting algorithm parameters](https://github.com/Ergo-Tools/ActiPASS/wiki/Adjusting-algorithm-parameters,-and-options-which-are-not-exposed-via-GUI).

Licensed under the BSD 3-Clause License (see `../LICENSES/BSD-3-Clause.txt`).

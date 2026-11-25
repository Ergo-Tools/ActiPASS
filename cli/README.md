## Actipass CLI

A command-line version of Actipass for quick activity classification, previews and participant feedback. For study
results use the full Actipass (desktop or classic app). See [ReadMe_CLI.txt](ReadMe_CLI.txt), [Usage_CLI.txt](Usage_CLI.txt) and the
[Actipass CLI wiki page](https://github.com/Ergo-Tools/ActiPASS/wiki/Actipass-CLI-%E2%80%90-for-CLI-workflows-and-quick%E2%80%90previewing-accelerometer-files).

### Contents

| File | What it does |
|---|---|
| [`actipass_cli.m`](actipass_cli.m) | Main program: classifies the activities of accelerometer files |
| [`cli_diary_events.m`](cli_diary_events.m) | Diary events for the figures and the interval based statistics |
| [`cli_diary_tick_warnings.m`](cli_diary_tick_warnings.m) | Warnings about diary times that are not used as given |
| [`cli_visualize.m`](cli_visualize.m) | Figures of activities, times-in-bed, sleep and diary events |
| [`cli_weekly_plots.m`](cli_weekly_plots.m) | Weekly activity preview figures |
| [`cli_add_to_sendto.m`](cli_add_to_sendto.m) | Adds actipass_cli.exe to the Windows Send To menu |
| [`getInstalledExePath.m`](getInstalledExePath.m) | Path of the running (compiled) program |

The CLI uses the functions in `../algorithms`, `../library` and `../utils`.

### License

The CLI code in this folder is licensed under the GNU General Public License, version 3.0 or later. See [LICENSE.md](LICENSE.md).

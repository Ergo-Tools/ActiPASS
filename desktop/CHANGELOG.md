# Actipass desktop app: change log

## 2026.11.7-alpha (2026-11-27)

Released together with the classic Actipass app 2026.11.7.

Changes:
1. Intensity algorithm (raw+posture is still experimental: check its results before you use them):
   "raw+posture (M)" (new, computed by the engine, no R needed) and "raw+posture (R)" (the R module as before,
   needs R; projects with "raw+posture" use it). Both give the same PAEE. The R check before processing runs
   only for "raw+posture (R)"; the "experimental" warning shows for both.
2. "raw+posture (R)" about 2x faster; its large temporary files go to the local temp folder, not the project.
   PAEE is saved as "<ID> - PAEE.bin"; statistics also read the PAEE.csv of earlier projects. See the classic
   app's ChangeLog.txt for details, including a fix of how the 10 s PAEE is applied to seconds.

## 2026.11.6-alpha (2026-11-26)

Released together with the classic Actipass app 2026.11.6.

Changes:
1. Fixed: after the computer slept (for example a laptop on battery), the log showed "Engine failed: Engine
   exited (exit code: 0) before the engine connected" and the app had to be restarted. The engine stops itself
   when it has not heard from the app for 60 s, which happens on wake-up. The app now says so ("The engine
   stopped after a long time without contact with the app (the computer probably slept)") and starts the
   engine again (when "start automatically" is on; not in attach mode). The open project stays open.
2. An engine that connected and later exits is reported as "stopped" (exit code 0) or "exited (code)", not as
   "exited before the engine connected".
3. ActiGraph .gt3x files are read in memory, without temporary files (about 0.5 GB for a week at 100 Hz),
   about twice as fast and with about 40% less memory. The licence text of miniz (MIT), now part of the .gt3x
   reader, is in NOTICE-readGT3xMex.txt in the app's `licenses` folder and next to the engine.
4. Warnings during processing no longer add an empty line to the log.

## 2026.11.5-alpha (2026-11-25)

Released together with the classic Actipass app 2026.11.5.

Changes:
1. ActiGraph .gt3x files are read directly (no ActiLife CSV export needed): they can be chosen in the file
   dialog ("ActiGraph GT3X" filter) and in Excel file lists, and are processed as ActiGraph CSV files are.
2. The .gt3x reader (readGT3xMex, ported from the R package read.gt3x) is licensed under the EUPL v1.2: its
   licence, notice and source are installed in the app's `licenses` folder and next to the engine.

## 2026.11.4-alpha (2026-11-25)

Released together with the classic Actipass app 2026.11.4.

Changes:
1. The name is written "Actipass" in the app, its messages and the user manual links.
2. App and installer icon: the Actipass logo mark (transparent background) instead of the splash image; the
   engine exe and its installer use it too. New Actipass logo on the About page.
3. The raw+posture intensity algorithm is marked as experimental (Settings help, and a warning on the Process
   page and in the Start dialog).
4. Statistics page: a "Statistics options…" link opens the Settings page at its Statistics options section.
5. Settings help for the Automatic time-in-bed settings and the Quality check thresholds.
6. The engine installer shows the Actipass splash image (as the classic app's installer).
7. Fixed: generating statistics stopped with "Unrecognized function or variable 'finlTrnkDT'" when the trunk
   accelerometer was off but "Save trunk angle data" was on (for example after turning the trunk off in a
   project processed with it). The setting is hidden while the trunk is off, so this could not be undone in the
   app.
8. Kneeling gets an intensity: the algorithm parameter MET_Kneel (default 1.55, as standing), or the walking MET
   when there is a cadence. Before, kneeling time was in none of the intensity classes.
9. Statistics of projects with batches processed with and without the trunk or calf accelerometer: empty
   (NaN) kneeling or trunk variables for the participants without those data, with a warning; a warning also
   names batches processed with the trunk or calf accelerometer when it is off in the statistics.

## 2026.11.3-alpha (2026-11-23)

First release of the Actipass desktop app, a new user interface for Actipass, released together with the classic
Actipass app 2026.11.3 (same processing, same results). The app is licensed under GPL-3.0-or-later; the processing
engine is a separate, compiled program under the Actipass End-User License Agreement.

Features:
1. Workflow pages in a sidebar: Project, Data, Diary & calibration, Settings, Process, Quality check, Statistics,
   plus Tools, Engine and About. Each page shows checks (errors block Start, warnings are confirmed) and the
   sidebar marks pages as done, needing attention, running or locked while a job runs.
2. Settings per project, stored in <project>/ProjectSettings (the classic app keeps one global setting set).
   ProPASS mode keeps the project's own settings and restores them when it is switched off.
3. Project page: recent projects, project summary, batches, cleaning unfinished batch folders, closing a project
   (clears all inputs, the quality check and the log of the previous project).
4. Process page: one place to review the batch before Start; per-subject progress and the batch log in the log
   strip; cancel.
5. Quality check: master or batch QC table and QC figures side by side, table only or figure only, for projects
   with thousands of files; keyboard browsing; QC_Status editing saved to the master QC table with a backup.
6. Statistics and all tools of the classic app (long-format ProPASS table, 1 s CSV export, diary quality check,
   merge sleep data, sit-to-stand tools, WBV prediction), with per-subject progress and a tool log file.
7. Licence dialog: licence status and expiry, licence request or renewal by mail (Host-Details.txt attached in the
   default mail program, or sent by hand), installing the licence files; a banner in evaluation mode and during
   the last 60 days of a licence. The licence files are shared with the classic app.
8. Help: "?" buttons on every page, section and tool open the new desktop app user manual in the wiki.
9. Windows installer that also installs the Actipass engine (MATLAB Runtime downloaded during setup; no MATLAB
   licence needed). Title bar and About page show the version; the About page shows this change log.
10. Statistics with personal data (optional): a table with SubjectID, Age, Sex, Height and Weight; each person's
    height in the cadence-MET equation and, for raw+posture, the person's resting metabolic rate (Mifflin-St Jeor)
    as 1 MET of the PAEE intensity cut-offs (Settings > Statistics options; the file on the Statistics page).

Fixes:
1. Every engine build has its own version (Actipass version plus a build number, e.g. 2026.11.3.32718): the
   installer now installs a newer engine of the same Actipass version (before, a computer with an earlier
   2026.11.3 engine kept it, and the licence request failed with "Method not found: licence.request"). The app
   warns when the installed engine is not the one it came with, and explains a "Method not found" error.
2. Licence request: when the request cannot be made, the licence folder (%APPDATA%\Actipass) is shown.

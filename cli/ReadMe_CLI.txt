Actipass CLI version 2026.11.7

WARNING:
Use the CLI version only to quickly preview accelerometer files or to give participant feedback.
For physical activity and sedentary behaviour variables in studies use only the full version of Actipass
(desktop app or classic app).

See the wiki page for more information:
https://github.com/Ergo-Tools/ActiPASS/wiki/Actipass-CLI-%E2%80%90-for-CLI-workflows-and-quick%E2%80%90previewing-accelerometer-files

Installation:
* Compile from source (MATLAB R2024b with MATLAB Compiler) or contact the developers to obtain the binary files.
* Install the MATLAB Runtime R2024b (64-bit, Windows) if the binary does not come with an installer.
* Extract the ActiPASS_CLI folder (which contains "actipass_cli.exe") and add it to the system path.
* Running actipass_cli.exe without arguments shows the usage and adds it to the Windows "Send to" menu.

Licensing:
* Binary executables are licensed according to the agreement at
  https://github.com/Ergo-Tools/ActiPASS/wiki/License-agreement#license-and-usage-agreement
* The source of Actipass CLI is licensed under GPL-3.0-or-later (see LICENSE.md); the Actipass algorithms it uses
  are licensed under BSD-3-Clause.
* The ActiGraph .gt3x reader readGT3xMex (ported from the R package read.gt3x) is licensed under the EUPL v1.2
  (see LICENSE-EUPL-1.2.txt and NOTICE-readGT3xMex.txt; its source readGT3xMex.cpp is included).

Supported accelerometer files:
* Axivity CWA (.cwa) and WAV exported by OmGui (.wav)
* ActivPAL (.datx, .dat, .npy and CSV)
* ActiGraph .gt3x and CSV exported by ActiLife (.csv)
* SENS motion (.bin, .hex)
* Movisens (.xml with its binary data)
* Acti4 (.act4)
* Generic CSV with ISO 8601 time stamps (.csv)

Execution settings:
* mode "PROPASS" (default) uses the Actipass default settings and algorithm parameters.
* mode "ADVANCED" or "CLI" uses the settings and parameters of the Actipass config files
  (%APPDATA%\Actipass\Actipass_UI.conf and AktDetect_UI.conf); change them with the Actipass app.
* Figures are always the quality-check figures (the Visualizations setting is not used).

Usage via Windows File Explorer:
In this situation
 a) the daily activity table (<ID>_dailyact.xlsx) and
 b) the quality-check figures (<ID>_QC-1.png, ...)
are created in the same folder as the source file (<ID> is the file name).
* Drag and drop a supported accelerometer raw data file onto "actipass_cli.exe"
* Right click an accelerometer file and "Send to" Actipass CLI
* Associate supported accelerometer files with "actipass_cli.exe" (right click an accelerometer file and select "Open with")

Syntax for usage via command line:
actipass_cli.exe "file_in" out "file_or_folder_out" ID "ID" diary "file_diary" daily "on" vis "on" loc "front" mode "PROPASS"
  - arguments:
   file_in: first argument is always the full file path of the accelerometer raw data file
   out:     optional. Output file or folder for the 1 s data:
            - a file ending .csv or .xlsx: the 1 s table is written as a CSV or Excel table
            - a file ending .mat: the 1 s table (T_1s) is saved as a MATLAB file
            - a file with another extension: saved as "<name>_actipass_1s.mat" in that folder
            - a folder: saved as "<ID>_actipass_1s.mat" in that folder
            Without "out", no 1 s data are saved and the daily table and figures go to the folder of file_in;
            with "out", they go to the output folder.
            The 1 s table has the columns DateTime, Activity, Steps, SVM, Event, TimeInBed and SleepInterval.
   ID:      optional participant ID. Default: the file name of file_in
   diary:   optional Actipass formatted diary (Excel, .xlsx or .xls)
   daily:   optional. Default "on". "off" disables the daily activity table
   vis:     optional. Default "on". "off" disables the quality-check figures
   loc:     optional device location: "front" (default), "right" or "left"
   mode:    optional operation mode: "PROPASS" (default), "ADVANCED" or "CLI" (see Execution settings)

actipass_cli.exe --help
    - display this help/readme text in the console
actipass_cli.exe --add-to-sendto
    - add actipass_cli.exe to the Windows SendTo folder as a shortcut

Examples:
* actipass_cli.exe "testdata.cwa"
  - daily activity table is saved as "testdata_dailyact.xlsx" in the same folder as testdata.cwa
  - quality-check figure is saved as "testdata_QC-1.png" in the same folder as testdata.cwa

* actipass_cli.exe "C:\Users\UNAME\Desktop\testdata.csv" out "C:\Users\UNAME\Downloads" mode "ADVANCED"
  - settings and algorithm parameters are loaded from the Actipass json config files
  - 1 s output is saved to "C:\Users\UNAME\Downloads\testdata_actipass_1s.mat"
  - daily activity table is saved to "C:\Users\UNAME\Downloads\testdata_dailyact.xlsx"
  - quality-check figure is saved as "C:\Users\UNAME\Downloads\testdata_QC-1.png"

* actipass_cli.exe "C:\Users\UNAME\Desktop\testdata.csv" out "C:\Users\UNAME\Downloads\test_out.csv"
  - 1 s output is saved as a CSV table to "C:\Users\UNAME\Downloads\test_out.csv"
  - daily activity table is saved to "C:\Users\UNAME\Downloads\testdata_dailyact.xlsx"
  - quality-check figure is saved as "C:\Users\UNAME\Downloads\testdata_QC-1.png"

* actipass_cli.exe "C:\Users\UNAME\Desktop\testdata.csv" out "C:\Users\UNAME\Downloads" ID "S0001"
  - 1 s output is saved to "C:\Users\UNAME\Downloads\S0001_actipass_1s.mat"
  - daily activity table is saved to "C:\Users\UNAME\Downloads\S0001_dailyact.xlsx"
  - quality-check figure is saved as "C:\Users\UNAME\Downloads\S0001_QC-1.png"

* actipass_cli.exe "C:\Users\UNAME\Desktop\testdata.csv" out "C:\Users\UNAME\Downloads" ID "S0001" diary "C:\Users\UNAME\Desktop\diary.xlsx"
  - diary is used to trim data, define manual lying, bed, sleep or non-wear periods or divide data into intervals
  - outputs as in the previous example

* actipass_cli.exe "C:\Users\UNAME\Desktop\testdata.csv" out "C:\Users\UNAME\Downloads" daily "off" vis "off"
  - only the 1 s output is saved (to "C:\Users\UNAME\Downloads\testdata_actipass_1s.mat")


Return codes:
0 = everything went well. However it is still necessary to check for outliers.

Other codes are the sum of the following (each digit position is one kind of problem):
1          unhandled exception
100        unknown accelerometer file type
200        unknown CSV file type
300        accelerometer file not found
400, 500   invalid output file or folder
1000       automatic device calibration problems
10000      automatic orientation and trimming correction error
100000     reference position errors
1000000    times-in-bed and sleep detection error
10000000   diary file not found
20000000   invalid diary
100000000  possible misclassification (unfixed orientation)
200000000  no sleep found for two consecutive days

Example: 100100000 = possible misclassification combined with reference position errors.


Copyright notice:
Actipass CLI is developed by: Pasan Hettiarachchi pasan.hettiarachchi@medsci.uu.se
at Occupational and Environmental Medicine, Department of Medical Sciences, Uppsala University

See full license agreement:
https://github.com/Ergo-Tools/ActiPASS/wiki/License-agreement#license-and-usage-agreement

ActiPASS CLI version 2025.03.1

WARNING:
Use CLI version only for quick preview Accelerometer files or to give paricipant feedback. 
For finding physical and sedentary behaviour variables for studies use only full version of ActiPASS.

See Wiki page for more information.
https://github.com/Ergo-Tools/ActiPASS/wiki/Quick-preview-accelerometer-files-using-ActiPASS-CLI-version

Installation:
* compile from source or contact developers to obtain binary files.
* Install Matlab runtime 2020b 64bit for windows
* Extract and add ActiPASS_CLI folder (which contains "actipass_cli.exe" to system path)

Licensing:
* Binary executables are licensed according to agreement at "https://github.com/Ergo-Tools/ActiPASS/wiki/License-agreement"
* Source of ActiPASS_CLI is GPLV3 licensed (see LICENSE for more info)

Execution settings:
* Use ActiPASS GUI version to change settings. CLI version uses the same settings when relevant.

Usage via Windows File Explorer:
In this situation:
 a) daily PA and SB report in XLSX format and 
 b) PA/SB visualization in PNG format 
will be created at the same location as the source file.
* Drag and drop supported accelerometer raw data file on to "actipass_cli.exe"
* Right click on accelerometer file and "send it to" ActiPASS CLI
* Associate supported accelerometer files with "actipass_cli.exe" (right click an accelerometer file and select "Open with")

Syntax for usage via command line:
actipass_cli.exe "file_in" out "file_or_folder_out" ID "ID" diary "file_diary" daily "on" vis "on" loc "front"
  - arguments:
   file_in: first argument is always the full file-path to accelerometer raw data file
   out: optional output file or a folder (only .csv, .xlsx or .mat files accepted)
   ID: optional participant ID
   diary: optional ActiPASS formatted diary Excel format
   daily: optional. Default "on". "off" disables daily output table
   vis: optional. Default "on". "off" disables activity visualizations
   loc: optional device location. default: "front", "right" or "left"
   mode: optional operation-mode. default: "PROPASS" or "ADVANCED"

actipass_cli.exe --help
    - display help/readme text in console
actipass_cli.exe --add-to-sendto
    - add actipass_cli.exe to windows SendTo folder as a shortcut

Examples:
* actipass_cli.exe "testdata.cwa"
    - daily output is saved as "testdata_actipass_dailyact.csv" in the same folder as testdata.cwa
    - quality-check visualization is saved as "testdata_QC-1.png" in the same folder as testdata.cwa

* actipass_cli.exe "testdata.csv" 
  - daily output is saved "testdata_actipass_dailyact.csv" in the same folder as testdata.csv
  - quality-check visualization is saved as "testdata_QC-1.png" in the same folder as testdata.cwa

* actipass_cli.exe "C:\Users\UNAME\Desktop\testdata.csv" out "C:\Users\UNAME\Downloads" mode "ADVANCED"
  - algorithm parameters and options are loaded from ActiPASS json config files
  - 1s output is saved to "C:\Users\UNAME\Downloads\testdata_actipass_1s.mat"
  - daily output is saved to "C:\Users\UNAME\Downloads\testdata_actipass_dailyact.xlsx"
  - quality-check visualization is saved as "C:\Users\UNAME\Downloads\testdata_QC-1.png" 

* actipass_cli.exe "C:\Users\UNAME\Desktop\testdata.csv" out "C:\Users\UNAME\Downloads\test_out.csv"
  - 1s output is saved to matlab binary file "C:\Users\UNAME\Downloads\test_out.csv" 
  - daily output is saved to "C:\Users\UNAME\Downloads\test_out_dailyact.xlsx"
  - quality-check visualization is saved as "C:\Users\UNAME\Downloads\test_out_QC-1.png"

* actipass_cli.exe "C:\Users\UNAME\Desktop\testdata.csv" out "C:\Users\UNAME\Downloads" ID "S0001"
  - 1s output is saved to "C:\Users\UNAME\Deownloads\S0001_actipass_1s.mat"
  - daily is saved to "C:\Users\UNAME\Deownloads\S0001_actipass_daily.xlsx"
  - quality-check visualization is saved as "C:\Users\UNAME\Downloads\S0001_QC-1.png"

* actipass_cli.exe "C:\Users\UNAME\Desktop\testdata.csv" out "C:\Users\UNAME\Downloads" ID "S0001" diary "C:\Users\UNAME\Desktop\diary.xlsx"
  - diary is used to trim data, define manual lying, bed, sleep or non-wear periods or divide data into intervals
  - 1s output is saved to "C:\Users\UNAME\Deownloads\S0001_actipass_1s.mat"
  - daily output is saved to "C:\Users\UNAME\Deownloads\S0001_actipass_daily.xlsx"
  - quality-check visualization is saved as "C:\Users\UNAME\Downloads\S0001_QC-1.png"

* actipass_cli.exe "C:\Users\UNAME\Desktop\testdata.csv" out "C:\Users\UNAME\Downloads" daily "off" vis "off"
  - only 1s outputs is saved. (to "C:\Users\UNAME\Deownloads\testdata_actipass_1s.mat")
     

Return codes:
0 = everything went well. However it's still necessary to check for outliers

Other errors are categorized by their decimal digit position:
1s indicates an unhandled exception
10s indicates a license related error
100s indicate file loading error
1000s indicate automatic device calibration error
10000s indicate automatic orientation and trimming correction error
100000s indicate reference position errors 
1000000s times-in-bed and sleep detection error
10000000s diary related error
100000000s possible misclassifications

example error code: 300100000 (possible misclassifications combined with reference position errors)


Copyright notice:
ActiPASS CLI version is developed by: Pasan Hettiarachchi pasan.hettiarachchi@medsci.uu.se 
at Occupational and Environmental Medicine, Department of Medical Sciences, Uppsala University

See full license agreement:
https://github.com/Ergo-Tools/ActiPASS/wiki/License-agreement#license-and-usage-agreement

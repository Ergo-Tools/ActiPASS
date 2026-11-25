# Actipass

<img width="1200" alt="image" src="https://github.com/user-attachments/assets/8570104e-eafb-4dec-a3b5-4362a15937cc" />

### About Actipass

Actipass is a thigh-worn accelerometer data processing software which is developed by: [Pasan Hettiarachchi](mailto:pasan.hettiarachchi@medsci.uu.se) and [Peter J. Johansson](mailto:peter.johansson@medsci.uu.se) 
at Occupational and Environmental Medicine, Department of Medical Sciences, Uppsala University. Lead: [[Magnus Svartengren](mailto:magnus.svartengren@medsci.uu.se)]

Actipass is based on: [Acti4 thigh accelerometer activity detection algorithm](https://github.com/motus-nfa/Acti4/) developed by Jørgen Skotte 
at the National Research Centre for the Working Environment (NFA), Copenhagen, Denmark. Lead: [[Andreas Holtermann](mailto:aho@nfa.dk)]

The development of Actipass has partly been funded by [ProPASS Consortium](https://www.propassconsortium.org) and [FORTE](https://forte.se/), the Swedish Research Council for Health, Working Life and Welfare [project 2021–01561.](https://www.vr.se/swecris#/project/2021-01561_Forte)

Actipass may not be used for any commercial purposes without written permission from the developers.
Please acknowledge the Developers and NFA as the source of the Software in any publications by referring to [relevant publications](https://github.com/Ergo-Tools/ActiPASS/wiki/Actipass-References) about Acti4 /Actipass.

Actipass is made possible by [these open source software](https://github.com/Ergo-Tools/ActiPASS/wiki/Open-source-software-used-by-Actipass) and developers [acknowledge](https://github.com/Ergo-Tools/ActiPASS/wiki/acknowledgements) all who contributed in various means.

### Report your work
Please report any publications which implement Actipass [here](https://doit.medfarm.uu.se/bin/kurt3/kurt/8865977)


### Actipass graphical user interface

<img width="655" alt="image" src="https://github.com/user-attachments/assets/dcfcc005-d0c8-45d7-ac61-dee58910d462" />

*Actipass desktop app: a modern Rust/Tauri based GUI*

<img width="655" alt="image" src="https://github.com/user-attachments/assets/b5710dbc-898e-422a-b7b6-1602f369406a" />

*Actipass classic desktop app*

### Actipass desktop app (new)

From version 2026.11.3, Actipass also comes as a desktop app with a new user interface, released together
with the classic app and with the same version number. Its source code is in [`desktop/`](desktop/) under
GPL-3.0-or-later; see the [desktop app user manual](https://github.com/Ergo-Tools/ActiPASS/wiki/Desktop-App-User-Manual).
The processing engine it uses is distributed in compiled form under the End-User License Agreement.

### Download Actipass

Please contact developers via email to receive a compiled executable version of Actipass if you agree to the [End-User License Agreement](https://github.com/Ergo-Tools/ActiPASS/wiki/License-agreement#license-and-usage-agreement).


### Links

[**Citing Actipass**](https://github.com/Ergo-Tools/ActiPASS/wiki/Actipass-References)

[**Documentation**](https://github.com/Ergo-Tools/ActiPASS/wiki)

[**Acti4**](https://github.com/motus-nfa/Acti4/)

[**Open source contributions**](https://github.com/Ergo-Tools/ActiPASS/wiki/Open-source-software-used-by-Actipass)

[**Acknowledgements**](https://github.com/Ergo-Tools/ActiPASS/wiki/acknowledgements#actipass-acknowledgements)

[**End-User License Agreement (for compiled binary releases)**](https://github.com/Ergo-Tools/ActiPASS/wiki/License-agreement#license-and-usage-agreement)

[**Source code license**](https://github.com/Ergo-Tools/ActiPASS/blob/main/LICENSE.md)

### Source code structure

| Folder | Contents | License |
|---|---|---|
| [`algorithms/`](algorithms) | classification and analysis algorithms (activities, reference positions, lying, time-in-bed and sleep, kneeling, trunk variables) and the analysis tools (sit-to-stand, merge sleep data, WBV) | BSD-3-Clause |
| [`library/`](library) | functions of the processing workflow: settings, files and diary, calibration, resampling, non-wear, orientation checks, synchronisation, figures, helpers | BSD-3-Clause |
| [`stats/`](stats) | stats generation: daily, event based and bout variables, trunk variables | BSD-3-Clause |
| [`utils/`](utils) | readers for the supported accelerometer file formats | BSD-3-Clause |
| [`conf/`](conf) | example settings and algorithm parameter files | BSD-3-Clause |
| [`main/`](main) | example workflow script | BSD-3-Clause |
| [`cli/`](cli) | Actipass CLI (command-line version for previews and feedback) | GPL-3.0-or-later |
| [`desktop/`](desktop) | Actipass desktop app (user interface; the processing engine is distributed in compiled form) | GPL-3.0-or-later |
| [`docs/`](docs) | documentation files (diary example, variable definitions) | |
| [`LICENSES/`](LICENSES) | full license texts | |

Each folder has a README with a list of its files. See [LICENSE.md](LICENSE.md), [NOTICE.md](NOTICE.md) and [ChangeLog.txt](ChangeLog.txt).

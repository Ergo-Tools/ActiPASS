# Source license


**Actipass desktop app - user interface of Actipass**

Copyright 2026 by Pasan Hettiarachchi & Peter Johansson

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
licenses below for more details.


=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

- The **Actipass desktop app code** in this folder `desktop/` (the Tauri/Rust shell, the Svelte and
  TypeScript front end, the protocol description and the build scripts) is licensed under the
  **GNU General Public License, version 3.0 or (at your option) any later version**.
  See `../LICENSES/GPL-3.0-or-later.txt` and per-file license headers.

- The **algorithms, configs, library, statistics, and utility** functionality
  in the respective folders of this repository is licensed under the **BSD 3-Clause License** or the
  license specified in the individual file.
  See `../LICENSES/BSD-3-Clause.txt` and per-file license headers.

- The **Actipass engine**, which the desktop app starts and talks to, is a separate program. It is
  not part of this folder; it is distributed in compiled form under the
  [Actipass End-User License Agreement](https://github.com/Ergo-Tools/ActiPASS/wiki/License-agreement#license-and-usage-agreement).
  The app communicates with it only through its protocol (JSON-RPC 2.0 over a local TCP socket,
  see `protocol/`); it is not linked into the app.

——

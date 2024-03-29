## Source code relevant to ActiPASS stats generation module

See [**ActiPASS variables**](https://github.com/Ergo-Tools/ActiPASS/wiki/ActiPASS-variables-and-other-quality-check-files) for more information about the variables and different tables.

## How stats generation module work
1. The function [**genStat**](genStats.m) is called by ActiPASS GUI after the completion of one or more batch processes
2. [**genStat**](genStats.m) parses the file [**ActiPASS_QC_MasterFile.xlsx**](https://github.com/Ergo-Tools/ActiPASS/wiki/ActiPASS-project-folder-structure#5-actipass_qc_masterfilexlsx)
3. It then loads raw (1s epoch) activity and sedentary behaviour data for each participant
4. It calls the function [**genDlyTable**](genDlyTable.m) and/or [**genEventTable**](genEventTable.m) to generate daily and/or event interval based tables
5. These functions in turn calls **genVariables**, **genAktStats** and **findBouts** functions.

## License
Unless otherwise specified in an individual source file, all source code in this repository are release under **BSD 3-Clause license**. This means if a different license is included in a source file, that license supersedes the BSD 3-Clause license.

**BSD 3-Clause license**

Copyright (c) 2022, Pasan Hettiarachchi .
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

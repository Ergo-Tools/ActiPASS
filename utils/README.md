## Binary and text loaders for various brands of accelerometers and other utility functions

### Contents

Readers for the supported accelerometer file formats (see [Supported accelerometers](https://github.com/Ergo-Tools/ActiPASS/wiki/Supported-accelerometers)).

| File | What it does |
|---|---|
| [`Axivity/CWA_readFile.m`](Axivity/CWA_readFile.m) | Axivity AX3/AX6 CWA files (with the mex helpers parseDate and parseValueBlock) |
| [`readWAVtoACC.m`](readWAVtoACC.m) | Axivity WAV files exported by OmGui |
| [`readActivPAL.m`](readActivPAL.m), [`readActivPALcsv.m`](readActivPALcsv.m), [`checkActivPALFile.m`](checkActivPALFile.m) | ActivPAL datx/dat and CSV files |
| [`readActGT3x.m`](readActGT3x.m) | ActiGraph .gt3x files, read directly (with the mex reader [`ActiGraph/readGT3xMex`](ActiGraph/readGT3xMex.cpp), EUPL-1.2, ported from read.gt3x; see [`ActiGraph/readme.txt`](ActiGraph/readme.txt)) |
| [`readActGT3xcsv.m`](readActGT3xcsv.m) | ActiGraph GT3X files converted to CSV by ActiLife (6.13 or later) |
| [`readSENSBin.m`](readSENSBin.m) | SENS motion binary (bin/hex) files |
| [`readMovisensBin.m`](readMovisensBin.m) | Movisens binary files |
| [`readGenericCSV.m`](readGenericCSV.m) | Generic CSV files with ISO 8601 time stamps |
| [`readActi4.m`](readActi4.m) | Acti4 .act4 files |

### License
Unless otherwise specified in an individual source file, all source code in this repositery are release under **BSD 3-Clause license**. This means if a different license is included in a source file, that license supersedes the BSD 3-Clause license.

**BSD 3-Clause license**

Copyright (c) 2022, Pasan Hettiarachchi .
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

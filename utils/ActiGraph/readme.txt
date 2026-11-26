ActiGraph .gt3x reader (MEX)
============================

readGT3xMex.cpp / readGT3xMex.mexw64 parse the activity samples of ActiGraph
.gt3x files. Call them through ../readActGT3x.m, which returns the same
outputs as ../readActGT3xcsv.m:

    [Data,SF,deviceID] = readActGT3x(Fil)

The MEX reads the .gt3x (zip) archive in memory with miniz: no temporary files
are written. A missing, truncated or corrupt file gives a MATLAB error.

Supported: log.bin files (GT3X+, wGT3X-BT, GT9X, CentrePoint; 12-bit and int16
activity packets) and the older NHANES-era activity.bin files (NEO/MRA with
firmware <= 2.5.0). Gaps (idle sleep mode, missing seconds) are filled with the
last sample, and with zeros after an empty activity packet, as ActiLife does in
its CSV export; the recording ends at 'Last Sample Time' in info.txt.

Credits and licence
-------------------
The parsing code is ported from the R package read.gt3x by Tuomo Nieminen,
John Muschelli and contributors (https://github.com/THLfi/read.gt3x), which
is licensed under the European Union Public Licence (EUPL). readGT3xMex.cpp is
therefore distributed under the EUPL v1.2 (see LICENSE-EUPL-1.2.txt).
readActGT3x.m keeps the BSD licence of the rest of this repository.

Zip reading uses miniz 3.0.2 by Rich Geldreich, RAD Game Tools and Valve
Software (https://github.com/richgel999/miniz), MIT licence (see
LICENSE-miniz.txt). miniz.c and miniz.h are the unmodified files of the
miniz-3.0.2.zip release. The MIT text is repeated in NOTICE-readGT3xMex.txt,
which is shipped with the compiled apps (so LICENSE-miniz.txt need not be).

Validation (2026-11): identical to read.gt3x 1.2.0 (imputeZeroes = TRUE) in
time stamps and values on 8 files (wGT3X-BT 100 Hz, GT3X+ MOS 30 Hz, and three
NHANES-format NEO/MRA files), and identical to ActiLife 6.13 CSV exports read
with readActGT3xcsv on the 3 files that had one. Not yet tested: log.bin files
with 12-bit (type 0x00) activity packets. The in-memory zip version (2026-11)
gives output identical to the earlier unzip-to-temp version on the same files,
in about half the time and with about 40% lower peak memory.

Rebuild
-------
In MATLAB, from this folder:

    mex -O readGT3xMex.cpp miniz.c

A C++ compiler must be set up (mex -setup C++). MATLAB R2024b does not detect
Visual Studio 2026 (version 18) by itself; to use it, copy
<matlabroot>\bin\win64\mexopts\msvcpp2022.xml, replace every "[17.0,18.0)" with
"[17.0,19.0)", and build with

    mex -f path\to\the\copied.xml -O readGT3xMex.cpp miniz.c

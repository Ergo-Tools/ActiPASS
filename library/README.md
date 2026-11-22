## Various library functions used by ActiPASS software

### Contents

Functions used by the processing workflow: settings, file and diary handling, calibration, resampling,
non-wear, orientation checks, synchronisation, figures and small helpers.

| File | What it does |
|---|---|
| [`LoadSettings.m`](LoadSettings.m) | Default settings and algorithm parameters, and reading them from the JSON config files |
| [`open_accfiles.m`](open_accfiles.m) | Information about the chosen accelerometer files (type, subject IDs, trunk/calf files) |
| [`open_diary.m`](open_diary.m) | Reads an ActiPASS diary for given subject IDs |
| [`readCalFile.m`](readCalFile.m) | Reads a device calibration file (device IDs as text) |
| [`AutoCalibrate.m`](AutoCalibrate.m) | Automatic calibration of triaxial accelerometer data |
| [`CalibrateData.m`](CalibrateData.m) | Applies calibration coefficients (from the calibration file or auto-calibration) |
| [`toActiPASSFrame.m`](toActiPASSFrame.m) | Maps the raw axes of a device to the ActiPASS frame |
| [`ChangeAxes.m`](ChangeAxes.m) | Changes the raw data for orientation (flipped, rotated) and device type |
| [`resampleAcc.m`](resampleAcc.m) | Resamples accelerometer data to an evenly spaced time axis |
| [`FindAnglesAndVM.m`](FindAnglesAndVM.m) | Angles (6 Hz low-pass), vector magnitude and normalised acceleration |
| [`findCadenceN.m`](findCadenceN.m) | Step frequency (cadence) from the thigh acceleration (FFT algorithm) |
| [`NotWorn.m`](NotWorn.m) | Non-wear periods |
| [`NotWornQC.m`](NotWornQC.m) | Non-wear periods for the quality check (auto trim) |
| [`ProcessNonWearAndBedtime.m`](ProcessNonWearAndBedtime.m) | Thigh non-wear with time-in-bed adjustment |
| [`WarmNightT.m`](WarmNightT.m) | Warm night periods (diary or time of day) |
| [`QCFlipRotation.m`](QCFlipRotation.m) | Quality check of the thigh orientation (inside-out, upside-down, 90 degree rotation) and correction |
| [`TrunkFlipRot.m`](TrunkFlipRot.m) | Automatic correction of the trunk orientation |
| [`TimeSyncAcc.m`](TimeSyncAcc.m) | Time synchronisation of several devices worn by the same person |
| [`MaxIncTid.m`](MaxIncTid.m) | Longest period with an inclination above a threshold (trunk variables, from Acti4) |
| [`VisualizeActvts.m`](VisualizeActvts.m) | Quality check figures, histograms and pie charts |
| [`findDistributions.m`](findDistributions.m) | Activity time distributions and outliers of a project (QC_Distributions) |
| [`downsampleTable.m`](downsampleTable.m) | Resamples an activity table to a fixed epoch length (epoch export) |
| [`timeToSec.m`](timeToSec.m), [`matchDiaryTicks.m`](matchDiaryTicks.m) | Times as whole seconds; matching diary event times to the processed seconds |
| [`rle.m`](rle.m), [`removeShortRuns.m`](removeShortRuns.m), [`movingMode.m`](movingMode.m) | Run-length helpers and a moving mode filter (replace Image Processing Toolbox functions) |
| [`brewermap.m`](brewermap.m), [`rgb.m`](rgb.m) | Colour maps and named colours for the figures |

### License

Unless otherwise specified in an individual source file, all source code in this repositery are release under **BSD 3-Clause license**. This means if a different license is included in a source file, that license supersedes the BSD 3-Clause license.

**BSD 3-Clause license**

Copyright (c) 2022, Pasan Hettiarachchi.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

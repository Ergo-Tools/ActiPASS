## Various classifications algorithms used by Actipass software

### Contents

The classification and analysis algorithms: activity types, reference positions, lying, time-in-bed and sleep,
kneeling, trunk variables, sit-to-stand and whole-body vibration (WBV).

| File | What it does |
|---|---|
| [`ActivityDetect.m`](ActivityDetect.m) | Activity types (sit, stand, move, walk, run, stairs, cycle, row) from the thigh acceleration (based on Acti4) |
| [`AktFilt.m`](AktFilt.m) | Additional filtering of the activities |
| [`EstimateRefThigh1.m`](EstimateRefThigh1.m) | Thigh reference angle from walking |
| [`EstimateRefThigh2.m`](EstimateRefThigh2.m) | Thigh reference angle from the DFT of the vector magnitude |
| [`EstimateRefThighD.m`](EstimateRefThighD.m) | Thigh reference angle from diary reference (Ref) events |
| [`EstimateRefTrunk1.m`](EstimateRefTrunk1.m) | Trunk reference angle from walking |
| [`EstimateRefTrunkD.m`](EstimateRefTrunkD.m) | Trunk reference angle from diary reference events |
| [`EstimateRefCalfD.m`](EstimateRefCalfD.m) | Calf reference angle from diary reference events |
| [`lyingAlgA.m`](lyingAlgA.m), [`lyingAlgB.m`](lyingAlgB.m) | Lying periods from thigh rotation during sit/lie bouts (lying algorithms A and B) |
| [`trunkLying.m`](trunkLying.m) | Lying from the trunk (or hip) accelerometer |
| [`FindNonWearTrunk.m`](FindNonWearTrunk.m) | Non-wear periods of trunk, hip or arm accelerometers |
| [`calcBedLgc.m`](calcBedLgc.m) | Time-in-bed logic by filtering the activities |
| [`calcBedtime.m`](calcBedtime.m) | Time-in-bed (from lying or the diary) and sleep |
| [`SkottesSlp.m`](SkottesSlp.m) | Sleep estimation during lying or given times-in-bed |
| [`detectKneeling.m`](detectKneeling.m) | Kneeling/squatting from the calf and thigh accelerometers |
| [`genTrnkVariables.m`](genTrnkVariables.m) | Daily and interval based trunk variables (as Acti4) |
| [`genSitToStandTable.m`](genSitToStandTable.m) | Tool: sit-to-stand transition speeds (angular velocity) of a project |
| [`genClinicSitToStandTable.m`](genClinicSitToStandTable.m) | Tool: sit-to-stand counts in a clinical test |
| [`mergeSleepData.m`](mergeSleepData.m) | Tool: merge the sleep data of a project into one table |
| [`calculate_wbv_segments.m`](calculate_wbv_segments.m) | Tool: whole-body vibration (ISO 2631) prediction for sitting segments |
| [`load_AX3_iso2631.m`](load_AX3_iso2631.m) | Loads an Axivity CWA file with calibration and ISO 2631 frequency weighting (WBV) |
| [`iso2631_wbv.m`](iso2631_wbv.m) | ISO 2631-1 frequency weighting filters (WBV) |

## Wavelet cadence algorithms (not included)

The cadence algorithms `Wavelet1` and `Wavelet2` (setting `CADALG`) use a modified version of `find_walking.m` and
`find_continuous_dominant_peaks.m` by Marcin Straczkiewicz, the MATLAB implementation of:

> Straczkiewicz M., Huang E.J., Onnela J.-P. A "one-size-fits-most" walking recognition method for smartphones,
> smartwatches, and wearable accelerometers. npj Digital Medicine 6, 29 (2023). https://doi.org/10.1038/s41746-022-00745-z

These files are not published here. The original code can be found at the author's repository:
https://github.com/MStraczkiewicz/find_walking

## raw+posture intensity algorithm (experimental, not included)

The `raw+posture` intensity algorithm (setting `INT_ALG`) estimates physical activity energy expenditure (PAEE)
with machine-learning models in R, from the raw thigh acceleration and the activity types. It is experimental:
check its results before you use them. Its R code and models are not included here; they will be hosted in a
separate repository and published in the future. The default `posture` algorithm (MET values per activity type)
is part of this repository.


### License

Unless otherwise specified in an individual source file, all source code in this repositery are release under **BSD 3-Clause license**. This means if a different license is included in a source file, that license supersedes the BSD 3-Clause license.

**BSD 3-Clause license**

Copyright (c) 2022, Pasan Hettiarachchi & Peter Johansson.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

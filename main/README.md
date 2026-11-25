## Example workflow

[`Actipass_example_workflow.m`](Actipass_example_workflow.m) shows, step by step, how the Actipass functions in this
repository process one accelerometer file: loading the data and an optional diary, calibration, the quality check with
automatic flip/rotation correction, activity classification per day, time-in-bed and sleep, and writing the detected
activity time series to a file. It is a basic example: the workflow of the apps is more robust (error handling,
visualisations, quality checks and fallbacks for the reference positions). Use it to understand how Actipass works or
as a starting point for your own scripts. It needs the folders `algorithms`, `library`, `stats` and `utils` on the
MATLAB path.

Licensed under the BSD 3-Clause License (see `../LICENSES/BSD-3-Clause.txt`).

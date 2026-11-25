function calStruct = readCalFile(calFile)
% readCalFile  Read a device calibration file (CSV or Excel, as written by
% actipass_UI_Process) into the calibration structure: one element per row with
% DeviceID (string) and X_scale, X_offst, Y_scale, Y_offst, Z_scale, Z_offst.
%
% DeviceID is always read as text. A plain readtable would read the column as
% numbers when most IDs look numeric: other IDs become NaN, leading zeros are lost,
% and hexadecimal IDs such as "8136E1" (SENS) are read as numbers in E notation.

% Copyright (c) 2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the Actipass repository (https://github.com/Ergo-Tools/ActiPASS).
opts = detectImportOptions(calFile);
opts = setvartype(opts, 'DeviceID', 'string');
calStruct = table2struct(readtable(calFile, opts));
end

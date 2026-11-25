function [AXES, mtStart, mtEnd] = resampleAcc(time, xyz, mtStart, mtEnd, Fs)
% resampleAcc  Resample accelerometer data to an evenly spaced time axis.
%
%   [AXES, mtStart, mtEnd] = resampleAcc(time, xyz, mtStart, mtEnd, Fs)
%
%   time    : [n,1] sample times (datenum), increasing
%   xyz     : [n,3] samples (already mapped to the Actipass frame)
%   mtStart, mtEnd : requested window (datenum). It is clamped to the data and
%             rounded to whole seconds; pass -Inf/Inf to use the data limits.
%   Fs      : output sample frequency (Hz)
%
%   AXES    : [m,4] = [t x y z] at Fs, pchip-interpolated, 0 outside the data
%   mtStart, mtEnd : the window actually used

% Copyright (c) 2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the Actipass repository (https://github.com/Ergo-Tools/ActiPASS).

mtStart = round(max(mtStart, time(1))*86400)/86400;
mtEnd = round(min(mtEnd, time(end))*86400)/86400;

% evenly spaced time axis at the given sample rate
% number of samples: rounded, since (mtEnd-mtStart)*86400*Fs is not always an exact integer in
% floating point and linspace would truncate it (one sample short, grid stretched by up to 1/Fs)
t = linspace(mtStart, mtEnd, round((mtEnd-mtStart)*86400*Fs)+1);

AXES = zeros(length(t), 4);
AXES(:,2:4) = interp1(time, xyz, t, 'pchip', 0); % xyz must be double for 'pchip'
AXES(:,1) = t;
end

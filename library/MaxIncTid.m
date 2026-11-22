function [MaxTid,Imax] = MaxIncTid(V,Iok,Threshold,SF)

% MaxIncTid finds the maximal length of a period with a inclination above 'Threshold'.
%
% Input:
% V [N]: Array of inclination values (rad) for arm or trunk. 
% Iok [N]: Array of logical values; values of V for which Iok is false, are set to 0 (below Threshold angle)  
% Threshold: Threshold angle (rad)
% SF: Sample frequency
%
% Output:
% MaxTid: Length (seconds) of maximum period with V>Threshold
%
% A 5 second median filter is included to remove short 'pauses'

% From Acti4 (https://github.com/motus-nfa/Acti4).
% Copyright (c) 2020, Jørgen Skotte
% Copyright (c) 2021-2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the ActiPASS repository (https://github.com/Ergo-Tools/ActiPASS).

V = V(1:SF:end);
Iok = Iok(1:SF:end);
Iv = medfilt1(double(V),5)>Threshold; %medfilt: a 1 or 2 sec. 'pause' is removed
Iv(~Iok) = 0;
runsIv = rle(Iv); % run-length-encoding of the inclined periods
Op = reshape(runsIv{3}(runsIv{1}),[],1); % start of each inclined period
Tider = reshape(runsIv{2}(runsIv{1}),[],1); % length of each inclined period
[MaxTid,I] = max(Tider); %in seconds
Imax = Op(I);
if isempty(Tider), MaxTid = 0; end
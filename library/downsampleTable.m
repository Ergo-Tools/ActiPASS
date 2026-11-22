function T_N = downsampleTable(T, epochSec, alignToGrid)
% DOWNSAMPLETABLE  Fast resample of an activity table to a fixed epoch length.
%   mean : Steps, Temperature, SVM (ENMO), and MET or paee (whichever exists)
%   mode : Activity, Event, Bedtime, SleepInterval
%   Column classes are preserved. DateTime = epoch start (datenum).
%   Epochs with no samples are omitted.

% Copyright (c) 2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the ActiPASS repository (https://github.com/Ergo-Tools/ActiPASS).

if nargin < 3, alignToGrid = false; end

t = T.DateTime;
if ~issorted(t)
    T = sortrows(T, 'DateTime');
    t = T.DateTime;
end

% ---- Which columns to aggregate (names matched case-insensitively) -------
vn        = T.Properties.VariableNames;
meanCands = ["Steps" "Temperature" "SVM" "MET" "paee"];
modeCands = ["Activity" "Bedtime" "SleepInterval" "Event"];
meanVars  = string(vn(ismember(lower(vn), lower(meanCands))));
modeVars  = string(vn(ismember(lower(vn), lower(modeCands))));

% ---- Epoch start ---------------------------------------------------------
if alignToGrid
    day0 = floor(t(1));
    t0 = day0 + floor((t(1) - day0) * 86400 / epochSec + 1e-6) * epochSec / 86400;
else
    t0 = t(1);
end

% ---- Epoch index per row (time based, not row-count based) ---------------
sec = (t - t0) * 86400;
bin = floor((sec + 1e-3) / epochSec);          % 0-based epoch index

isStart = [true; diff(bin) > 0];
g       = cumsum(isStart);                     % 1..G
G       = g(end);
binIdx  = bin(isStart);

T_N = table();
T_N.DateTime = t0 + binIdx * epochSec / 86400;

% ---- Means ---------------------------------------------------------------
for v = meanVars
    x    = double(T.(v));
    ok   = ~isnan(x);
    x(~ok) = 0;
    s    = accumarray(g, x,  [G 1]);
    n    = accumarray(g, double(ok), [G 1]);
    m    = s ./ n;                             % NaN if an epoch has no valid data
    T_N.(v) = cast(m, class(T.(v)));
end

% ---- Modes ---------------------------------------------------------------
for v = modeVars
    T_N.(v) = groupMode(T.(v), g, G);
end

% Restore original column order (only columns that were aggregated)
T_N = T_N(:, vn(ismember(vn, T_N.Properties.VariableNames)));
end

function out = groupMode(x, g, G)
% Most common value per group; ties -> first in sorted order (same as mode()).
[u, ~, c] = unique(x);
K = numel(u);
bestCnt = zeros(G, 1);
bestCod = ones(G, 1);
for k = 1:K
    cnt = accumarray(g, double(c == k), [G 1]);
    better = cnt > bestCnt;
    bestCnt(better) = cnt(better);
    bestCod(better) = k;
end
out = u(bestCod);
end
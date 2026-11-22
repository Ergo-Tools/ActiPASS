function [iTick, iTime, unmatched] = matchDiaryTicks(ticks, t)
% matchDiaryTicks  Find the diary ticks (event times) that fall on a second of t.
%
%   [iTick, iTime, unmatched] = matchDiaryTicks(ticks, t)
%
%   ticks     : diary event times, datetime (or datenum); NaT/NaN are ignored
%   t         : the time axis to match against, datenum (e.g. Tid, timeFull or
%               the 1 s sampled raw times), increasing, one value per second
%   iTick     : [m,1] indices into ticks of the matched ticks
%   iTime     : [m,1] the matching indices into t (t(iTime(k)) is the second
%               of ticks(iTick(k))); sorted by time, as from intersect
%   unmatched : [u,1] indices into ticks that lie inside [t(1), t(end)] but
%               match no second of t (e.g. a tick in a gap of the data);
%               these would otherwise be ignored silently
%
% Both sides are compared as whole seconds (timeToSec). This replaces the
% pattern  [~,iTick,iTime] = intersect(datenum(ticks), round(t*86400)/86400)
% with the same result for whole-second ticks. A sub-second tick now matches
% its nearest second instead of being dropped.
% As with intersect, a tick time that occurs twice is matched once.

% Copyright (c) 2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the ActiPASS repository (https://github.com/Ergo-Tools/ActiPASS).

arguments
    ticks {mustBeA(ticks, ["double", "datetime"])}
    t double
end
tickSec = timeToSec(ticks(:));
tSec = timeToSec(t(:));
[~, iTick, iTime] = intersect(tickSec, tSec);
if isempty(tSec)
    unmatched = zeros(0,1);
else
    inside = tickSec >= tSec(1) & tickSec <= tSec(end);
    unmatched = find(inside & ~ismember(tickSec, tSec));
end
end

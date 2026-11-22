function sec = timeToSec(t)
% timeToSec  Convert times to whole seconds (an integer-valued double).
%
%   sec = timeToSec(t)
%
%   t   : datenum (double) or datetime, any shape
%   sec : round(datenum(t)*86400), same shape; NaN for NaN/NaT
%
% Use the result for every exact time comparison (==, intersect, ismember,
% unique) and for day/hour splits: day = floor(sec/86400), hour = floor(sec/3600).
% The values (about 6.4e10 for current dates) are far below flintmax, so they
% are exact and such comparisons are safe. Comparing datenums directly is not:
% a datenum has a resolution of about 10 us, and values built by adding
% seconds (t0 + k/86400) are often one step off the exact second.
%
% Back to datenum: sec/86400 gives exactly the same double as
% round(t*86400)/86400, so saved files (datenum) are unchanged.
%
% Times are rounded to the nearest second, so a sub-second time (e.g. a diary
% entry 08:15:02.4) maps to its nearest second (08:15:02).

% Copyright (c) 2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the ActiPASS repository (https://github.com/Ergo-Tools/ActiPASS).

arguments
    t {mustBeA(t, ["double", "datetime"])}
end
if isdatetime(t)
    t = datenum(t); %#ok<DATNM> datenum is the time format used in ActiPASS data
end
sec = round(t*86400);
end

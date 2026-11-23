function warned = cli_diary_tick_warnings(diaryStrct,timeFull,dataWin)
% cli_diary_tick_warnings  Warn about diary event times that are not used as given
%  - a time that is not on a whole second (it is matched to the nearest second)
%  - a time inside the data window that falls on no processed second, e.g. in a
%    non-wear-trimmed start or end: that diary entry does not start an event period
% 'Start' and 'Stop' are not checked against the processed seconds (they define the
% data window). Same checks as diaryTickWarnings in the ActiPASS GUI version.
%
%   diaryStrct : diary of the subject (open_diary), Ticks/Events
%   timeFull   : processed per-second times (datenum)
%   dataWin    : [start stop] of the data window before trimming (datenum)
%   warned     : a warning was given

% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (c) 2021-2025 Pasan Hettiarachchi and Peter Johansson

% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
%
% This **ActiPASS_CLI code** in `/cli/` is licensed under the
% GNU General Public License, version 3.0 or (at your option) any later version.
% See `../LICENSES/GPL-3.0-or-later.txt` for more details.

warned = false;
ticks = diaryStrct.Ticks(:);
events = string(diaryStrct.Events(:));
valid = ~isnat(ticks);
if ~any(valid), return; end % no diary
subSec = valid & second(ticks) ~= round(second(ticks));
for k = find(subSec)'
    warning('Diary: event ''%s'' at %s is not on a whole second. Matched to %s.', events(k), ...
        string(ticks(k),'yyyy-MM-dd HH:mm:ss.SSS'), string(dateshift(ticks(k),'start','second','nearest'),'yyyy-MM-dd HH:mm:ss'));
    warned = true;
end
used = matchDiaryTicks(ticks, timeFull);
win = datetime(dataWin,'ConvertFrom','datenum');
inWin = valid & ticks >= win(1) & ticks <= win(2) & ~matches(events, ["Start","Stop"], 'IgnoreCase', true);
for k = setdiff(find(inWin), used)'
    warning('Diary: event ''%s'' at %s is not used: no processed data at that time (non-wear trimmed or a gap).', ...
        events(k), string(ticks(k),'yyyy-MM-dd HH:mm:ss'));
    warned = true;
end
end

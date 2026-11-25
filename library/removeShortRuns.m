function lgc = removeShortRuns(lgc, minLen)
% removeShortRuns sets runs of true values shorter than minLen to false.
%
% lgc = removeShortRuns(lgc, minLen)
%
% 1-D replacement of bwareaopen(lgc, minLen) for a logical vector: runs of true with at least minLen elements are
% kept, shorter runs are removed. Runs touching either end are treated like any other run. To fill gaps (runs of
% false) shorter than N instead, use ~removeShortRuns(~lgc, N).
%
% Input:
%   lgc    [vector] logical (or numeric, nonzero is true) row or column vector
%   minLen [scalar] minimum run length to keep (in elements)
%
% Output:
%   lgc    [vector] logical vector of the same size as the input

% Copyright (c) 2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the Actipass repository (https://github.com/Ergo-Tools/ActiPASS).

lgc = logical(lgc);
r = rle(lgc); % runs: {values, lengths, starts, ends}
shortRuns = r{1} & r{2} < minLen; % true runs with fewer than minLen elements
if any(shortRuns)
    lgc(repelem(shortRuns, r{2})) = false;
end
end

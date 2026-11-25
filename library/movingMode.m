function y = movingMode(x, w)
% movingMode moving mode (most frequent value) of a vector over an odd window.
%
% y = movingMode(x, w)
%
% 1-D replacement of modefilt(x,[1 w],'replicate') (row vector) or modefilt(x,[w 1],'replicate') (column vector)
% without the Image Processing Toolbox. The ends are padded by repeating the first and last values. When several
% values are equally frequent in a window, the centre value is chosen if it is one of them, otherwise the smallest.
% Intended for vectors with few distinct values (e.g. activity codes); time grows with the number of distinct values.
%
% Input:
%   x [vector] numeric or logical row or column vector
%   w [scalar] odd window length (in elements)
%
% Output:
%   y [vector] moving mode, same size and class as x

% Copyright (c) 2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the Actipass repository (https://github.com/Ergo-Tools/ActiPASS).

if isempty(x)
    y = x;
    return
end
h = (w-1)/2; % half window
sz = size(x);
x = x(:);
n = numel(x);
[vals,~,idx] = unique(x); % distinct values (ascending) and the index of each element into them
idxPad = [repmat(idx(1),h,1); idx; repmat(idx(end),h,1)]; % replicate padding
best = zeros(n,1);
bestCnt = -inf(n,1);
for k = 1:numel(vals)
    % count of value k in each window; +0.5 for the centre value so that it wins ties
    cnt = movsum(idxPad==k, w, 'Endpoints', 'discard') + 0.5*(idx==k);
    better = cnt > bestCnt; % strict: on remaining ties the smaller value (checked first) is kept
    best(better) = k;
    bestCnt(better) = cnt(better);
end
y = reshape(vals(best), sz);
end

function T = readAPBin(fileName)
% readAPBin  Read an Actipass binary table (.bin, format "APB1") into a table of doubles.
%   T = readAPBin(fileName)
% See writeAPBin for the format. IntensityCal.R writes "<ID> - PAEE.bin" in this format.

% Copyright (c) 2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the Actipass repository (https://github.com/Ergo-Tools/ActiPASS).

fid = fopen(fileName, 'r', 'ieee-le');
if fid < 0
    error('readAPBin:open', 'Cannot open %s', fileName);
end
cleanF = onCleanup(@() fclose(fid));
magic = fread(fid, [1 4], 'uint8=>char');
if ~strcmp(magic, 'APB1')
    error('readAPBin:format', '%s is not an Actipass binary table', fileName);
end
h = fread(fid, [1 4], 'double');   % version, columns, rows, byte length of the names
if numel(h) < 4 || h(1) ~= 1
    error('readAPBin:format', '%s: unsupported version or truncated header', fileName);
end
nm = split(string(native2unicode(fread(fid, [1 h(4)], 'uint8=>uint8'), 'UTF-8')), sprintf('\t'));
M = fread(fid, [h(3) h(2)], 'double');
if ~isequal(size(M), [h(3) h(2)]) || numel(nm) ~= h(2)
    error('readAPBin:format', '%s is truncated or damaged', fileName);
end
T = array2table(M, 'VariableNames', cellstr(nm'));
end

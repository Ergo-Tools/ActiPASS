function writeAPBin(fileName, M, colNames)
% writeAPBin  Write a numeric matrix with column names as an Actipass binary table (.bin).
%   writeAPBin(fileName, M, colNames)
%   M        : numeric matrix (saved as double), one variable per column
%   colNames : string array, one name per column (no tabs)
%
% Format "APB1" (also read and written by IntensityCal.R; read with readAPBin):
%   4 bytes   'APB1'
%   4 doubles version (1), number of columns, number of rows, byte length of the names
%   names     UTF-8, separated by tabs
%   data      doubles, column by column (column-major), little-endian
% The file is written under a temporary name and renamed when complete.

% Copyright (c) 2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the Actipass repository (https://github.com/Ergo-Tools/ActiPASS).

colNames = string(colNames);
if size(M,2) ~= numel(colNames)
    error('writeAPBin:cols', '%d columns but %d names', size(M,2), numel(colNames));
end
nm = unicode2native(char(join(colNames, sprintf('\t'))), 'UTF-8');
tmpF = fileName + ".tmp";
fid = fopen(tmpF, 'w', 'ieee-le');
if fid < 0
    error('writeAPBin:open', 'Cannot write %s', tmpF);
end
try
    fwrite(fid, 'APB1', 'uint8');
    fwrite(fid, [1 size(M,2) size(M,1) numel(nm)], 'double');
    fwrite(fid, nm, 'uint8');
    cnt = fwrite(fid, M, 'double');
catch ME
    fclose(fid);
    delete(tmpF);
    rethrow(ME);
end
fclose(fid);
if cnt ~= numel(M)
    delete(tmpF);
    error('writeAPBin:write', 'Writing %s failed (disk full?)', fileName);
end
[ok, msg] = movefile(tmpF, fileName, 'f');
if ~ok
    error('writeAPBin:move', 'Cannot rename %s: %s', tmpF, msg);
end
end

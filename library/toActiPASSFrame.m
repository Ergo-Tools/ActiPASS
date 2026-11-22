function xyz = toActiPASSFrame(xyz, srcFormat, loc)
% toActiPASSFrame  Map raw accelerometer axes of a device to the ActiPASS frame.
%
%   xyz = toActiPASSFrame(xyz, srcFormat, loc)
%
%   xyz       : [n,3] raw x, y, z samples as returned by the file reader
%   srcFormat : data format/brand the axes come from: "Axivity" (CWA, WAV),
%               "GenericCSV", "ActivPAL", "ActiGraph", "SENS" or "Movisens"
%   loc       : sensor placement, needed for SENS and Movisens only:
%               "Front-thigh", "Right-thigh-side" or "Left-thigh-side"
%
% This is the single place where brand-specific axis changes are made. Each
% entry is a signed column order: [1 -3 2] means x stays x, new y = -z and
% new z = y. Orientation corrections (flips/rotations found from the data, see
% ChangeAxes and QCFlipRotation) are applied later and are not part of this.
%
% A combination without an entry raises an error ('ActiPASS:axisMap') instead
% of guessing, e.g. a SENS sensor at an unknown location.
%
% Note: ActiGraph [-1 -2 -3] flips the sign of every axis. That is a sign
% convention change (not a rotation); all other entries are proper rotations.

% Copyright (c) 2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the ActiPASS repository (https://github.com/Ergo-Tools/ActiPASS).

switch lower(string(srcFormat))
    case {"axivity", "genericcsv"}  % Generic CSV follows the Axivity axes convention
        p = [1 -2 -3];
    case "activpal"
        p = [1 2 3];
    case "actigraph"
        p = [-1 -2 -3];
    case "sens"
        switch lower(string(loc))
            case "front-thigh",      p = [1 2 3];
            case "right-thigh-side", p = [1 -3 2];  % -z becomes y, y becomes z
            case "left-thigh-side",  p = [1 3 -2];  % z becomes y, -y becomes z
            otherwise, p = [];
        end
    case "movisens"
        switch lower(string(loc))
            case "front-thigh",      p = [2 -1 3];
            case "right-thigh-side", p = [2 -3 -1];
            case "left-thigh-side",  p = [2 3 1];   % right side rotated 180 deg about x
            otherwise, p = [];
        end
    otherwise
        p = [];
end
if isempty(p)
    error('ActiPASS:axisMap', 'No axis mapping for device format "%s" at location "%s"', ...
        string(srcFormat), string(loc));
end

xyz = xyz(:, abs(p));
neg = p < 0;
xyz(:, neg) = -xyz(:, neg);
end

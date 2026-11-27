function alg = intensityAlg(INT_ALG)
% intensityAlg  The intensity algorithm of the setting INT_ALG:
%   "posture" - from the postures only (INT_ALG "posture")
%   "M"       - raw+posture, computed in MATLAB (INT_ALG "raw+posture (M)", intensityPAEE.m)
%   "R"       - raw+posture, computed in R (INT_ALG "raw+posture (R)", IntensityCal.R; also the
%               value "raw+posture" of settings saved before 2026-11-27)
% Both raw+posture versions write "<ID> - PAEE.bin"; the statistics treat them alike.

% Copyright (c) 2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the Actipass repository (https://github.com/Ergo-Tools/ActiPASS).

v = lower(strtrim(string(INT_ALG)));
if ismissing(v)
    alg = "posture";
elseif v == "raw+posture (m)"
    alg = "M";
elseif v == "raw+posture (r)" || v == "raw+posture"
    alg = "R";
else
    alg = "posture";
end
end

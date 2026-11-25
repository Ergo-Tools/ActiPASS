function v = engineBuild()
% engineBuild  Build of a compiled engine, e.g. "2026.11.3.32718" ("" in MATLAB).
%
% The file version of the engine exe and its installer: the Actipass version and a build
% number (tools/build_engine.m generates engineBuiltBuild.m). The app compares it with the
% engine build it was released with, so an older engine of the same Actipass version is found.
%
% SPDX-License-Identifier: GPL-3.0-or-later

v = "";
try
    v = string(engineBuiltBuild()); % only exists in a compiled engine
catch
end
end

function name = engineTypeName(ftype)
% engineTypeName  Device type name for the ftype numbers used by actiPass_UI_Process.
% SPDX-License-Identifier: GPL-3.0-or-later
names = ["Axivity CWA", "Axivity WAV", "ActivPAL DATX", "ActivPAL CSV", "ActiGraph CSV", ...
    "SENS Motion BIN", "Generic CSV", "", "Movisens"];
if ftype >= 1 && ftype <= numel(names)
    name = names(ftype);
else
    name = "";
end
end

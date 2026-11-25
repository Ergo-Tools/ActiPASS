function [schema, text] = engineSchema()
% engineSchema  The settings description settings.schema.json (next to this file).
%
% schema: decoded struct (fields: version, sections, fields); text: the file as is (sent to
% the app unchanged, so JSON arrays keep their shape). Cached after the first call.
%
% SPDX-License-Identifier: GPL-3.0-or-later

persistent cS cT
if isempty(cT)
    cT = string(fileread(fullfile(fileparts(mfilename('fullpath')), 'settings.schema.json')));
    cS = jsondecode(cT);
end
schema = cS;
text = cT;
end

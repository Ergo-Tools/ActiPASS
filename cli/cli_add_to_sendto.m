function cli_add_to_sendto(exePath)
% ADD_CLI_TO_SENDTO add actipass_cli.exe to Windows SendTo folder
%
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (c) 2021-2025 Pasan Hettiarachchi and Peter Johansson

% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
%
% This *ActiPASS_CLI** in `/cli/` is licensed under the
% GNU General Public License, version 3.0 or (at your option) any later version.
% See `../LICENSES/GPL-3.0-or-later.txt` for more details.


% Resolve the path to the compiled exe
% If mfilename('fullpath') returns the exe path in your deployment, use it directly.

% In some packaging setups, you might need to ensure it ends with .exe:
if ~endsWith(lower(exePath), '.exe')
    exePath = [exePath, '.exe']; % adjust if your build produces a different filename
end

% Compute SendTo folder for the current user
sendToDir = fullfile(getenv('APPDATA'), 'Microsoft', 'Windows', 'SendTo');

% Choose the shortcut name (change as needed)
lnkPath = fullfile(sendToDir, 'ActiPASS_CLI.lnk');

% If shortcut already exists, you may skip or recreate
if exist(lnkPath, 'file')
    fprintf('Shortcut already exists and will be replaced: %s\n', lnkPath);
    delete(lnkPath);
end

workDir = fileparts(exePath);

% Build PowerShell command. Use single quotes inside and escape with doubled quotes for safety.
psCmd = sprintf([...
    'powershell -NoProfile -ExecutionPolicy Bypass -Command ', ...
    '"$ws=New-Object -ComObject WScript.Shell;', ...
    '$s=$ws.CreateShortcut(''%s'');', ...
    '$s.TargetPath=''%s'';', ...
    '$s.WorkingDirectory=''%s'';', ...
    '$s.IconLocation=''%s,0'';', ...
    '$s.Description=''YourTool (Send To)'';', ...
    '$s.Save()"'], ...
    lnkPath, exePath, workDir, exePath);

status = system(psCmd);
if status == 0
    fprintf('Created Send To shortcut: %s\n', lnkPath);
else
    warning('Failed to create shortcut. system() exit code: %d', status);
end




function exePath = getInstalledExePath()
% Returns full path to the running EXE, e.g.
% C:\Program Files\Ergo-Tools\actipass_cli\application\actipass_cli.exe



% Read Windows environment variables
progFiles    = getenv('ProgramFiles');      % C:\Program Files (64‑bit proc) or C:\Program Files (x86) (WOW64)
%progFilesX86 = getenv('ProgramFiles(x86)'); % Always C:\Program Files (x86) on 64‑bit Windows
progW6432    = getenv('ProgramW6432');      % Always C:\Program Files on 64‑bit Windows

% Choose the base Program Files folder to target
if ~isempty(progW6432)
    % On 64‑bit Windows prefer the native 64‑bit Program Files
    base = progW6432;
else
    % On 32‑bit Windows there is only Program Files
    base = progFiles;
end

% Your installed path (default installer choice = %ProgramFiles%\Ergo-Tools\actipass_cli\...)
exePath = fullfile(base, 'Ergo-Tools', 'actipass_cli', 'application', 'actipass_cli.exe');

end

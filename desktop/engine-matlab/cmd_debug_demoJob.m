function result = cmd_debug_demoJob(params, conn)
% cmd_debug_demoJob  "debug.demoJob": a fake batch to test progress, logging and cancel.
%
% params.files (default 5) "files", params.steps (default 10) steps per file,
% params.delay (default 0.2) seconds per step. Uses IpcProgress the same way
% actipass_UI_Process uses its progress dialog (Value, Message, CancelRequested).
%
% SPDX-License-Identifier: GPL-3.0-or-later

nFiles = getOpt(params, 'files', 5);
nSteps = getOpt(params, 'steps', 10);
delay = getOpt(params, 'delay', 0.2);

dlg = IpcProgress(conn, "debug.demoJob", 'Title', 'Demo batch', 'Message', 'Initializing...');
cleanup = onCleanup(@() dlg.close());
conn.log("info", sprintf('Demo batch started: %d files x %d steps', nFiles, nSteps));
for f = 1:nFiles
    for s = 1:nSteps
        dlg.Value = ((f-1) + s/nSteps) / nFiles;
        dlg.Message = sprintf('File %d of %d: step %d of %d', f, nFiles, s, nSteps);
        if dlg.CancelRequested
            conn.log("warning", sprintf('Demo batch canceled in file %d', f));
            error('ActiPASS:Canceled', 'Batch canceled by user.');
        end
        pause(delay);
    end
    conn.log("info", sprintf('File %d of %d done', f, nFiles));
end
result = struct('files', nFiles, 'status', 'Demo batch completed');
end

function v = getOpt(s, name, default)
if isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = default;
end
end

function h = engineHandlers()
% engineHandlers  JSON-RPC method name -> handler function.
%
% Every handler has the signature  result = handler(params, conn)
%   params: struct decoded from the request's JSON params (struct() when none)
%   conn:   EngineConn, for log/progress notifications and cancel checks
%   result: struct/array encoded with jsonencode as the response result
% Throw error('ActiPASS:Canceled', ...) to report a user cancel.
% "engine.shutdown", "engine.ping" and "job.cancel" are handled by actipass_engine
% (idle) and EngineConn.poll (while a handler runs).
%
% SPDX-License-Identifier: GPL-3.0-or-later

h = containers.Map('KeyType', 'char', 'ValueType', 'any');
h('project.open')    = @cmd_project_open;
h('project.cleanBatches') = @cmd_project_clean;
h('qc.table')        = @(p, c) cmd_qc(p, c, "table");
h('qc.setStatus')    = @(p, c) cmd_qc(p, c, "setStatus");
for t = ["longFormat", "export1s", "diaryQC", "mergeSleep", "sitToStand", "clinicalSts", "wbv"]
    h(char("tools." + t)) = @(p, c) cmd_tools(p, c, t);
end
h('settings.get')    = @(p, c) cmd_settings(p, c, "get");
h('settings.set')    = @(p, c) cmd_settings(p, c, "set");
h('settings.saveAsDefault') = @(p, c) cmd_settings(p, c, "saveAsDefault");
h('licence.status')  = @(p, c) cmd_licence(p, c, "status");
h('licence.request') = @(p, c) cmd_licence(p, c, "request");
h('licence.install') = @(p, c) cmd_licence(p, c, "install");
h('files.scan')      = @cmd_files_scan;
h('batch.run')       = @cmd_batch_run;
h('stats.run')       = @cmd_stats_run;
h('debug.demoJob')   = @cmd_debug_demoJob;
end

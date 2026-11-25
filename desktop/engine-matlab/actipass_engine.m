function actipass_engine(port, token, opts)
% actipass_engine  Actipass engine for the actipass-desktop UI.
%
%   actipass_engine(port, token)
%   actipass_engine(port, token, Host="127.0.0.1", IdleTimeout=60, Backtrace="on")
%
% Connects to the desktop UI listening on Host:port, introduces itself with an
% "engine.hello" notification carrying the one-time token, then serves JSON-RPC 2.0
% requests (one JSON message per line) until "engine.shutdown", until the UI has been
% silent for IdleTimeout seconds (the UI pings every few seconds), or until the
% connection fails.
%
% Development: run this from the MATLAB command window with the port and token the UI
% shows under "Engine > Attach to MATLAB", or let the UI start MATLAB with -batch.
% Release: compiled with MATLAB Compiler (not set up yet).
%
% Request handlers are listed in engineHandlers.m (one function per method).
%
% SPDX-License-Identifier: GPL-3.0-or-later

arguments
    port (1,1) double {mustBeInteger, mustBePositive}
    token (1,1) string
    opts.Host (1,1) string = "127.0.0.1"
    opts.IdleTimeout (1,1) double = 60
    opts.Backtrace (1,1) string {mustBeMember(opts.Backtrace, ["on", "off"])} = "on" % warning code lines (always off when compiled)
end

engineDir = fileparts(mfilename('fullpath'));
pathInfo = engineSetupPaths(engineDir);

% Warnings of the workflow go to the app's log: one "Warning: ..." line each. The code
% location lines under them ("> In function (line N)") only in MATLAB, for debugging.
if isdeployed || opts.Backtrace == "off"
    warning('off', 'backtrace');
end

conn = EngineConn(opts.Host, port, 10);
cleanup = onCleanup(@() delete(conn));

conn.notify("engine.hello", struct( ...
    'token', char(token), ...
    'engine', 'matlab', ...
    'engineVersion', char(engineActipassVersion()), ...
    'engineBuild', char(engineBuild()), ...
    'matlabVersion', version, ...
    'deployed', isdeployed, ...
    'pid', feature('getpid'), ...
    'paths', pathInfo));
fprintf('actipass_engine: connected to %s:%d\n', opts.Host, port);

handlers = engineHandlers();
running = true;
while running
    try
        msg = conn.next();
    catch ME
        fprintf(2, 'actipass_engine: connection lost (%s)\n', ME.message);
        break;
    end

    if isempty(msg)
        if conn.idleSeconds() > opts.IdleTimeout
            fprintf(2, 'actipass_engine: no message from the UI for %g s, stopping\n', opts.IdleTimeout);
            break;
        end
        pause(0.02);
        continue;
    end

    if ~isfield(msg, 'method')
        continue; % responses to engine requests are not used yet
    end
    method = string(msg.method);
    hasId = isfield(msg, 'id');
    params = struct();
    if isfield(msg, 'params') && ~isempty(msg.params)
        params = msg.params;
    end

    try
        if method == "engine.shutdown"
            if hasId, conn.respond(msg.id, struct('stopping', true)); end
            running = false;
            continue;
        end
        if method == "engine.ping" || method == "job.cancel"
            % idle: nothing to cancel; ping answered here (EngineConn.poll answers while busy)
            if hasId
                conn.respond(msg.id, struct('busy', false, ...
                    'time', char(string(datetime('now'), 'yyyy-MM-dd HH:mm:ss'))));
            end
            continue;
        end
        if ~isKey(handlers, char(method))
            if hasId, conn.respondError(msg.id, -32601, "Method not found: " + method); end
            continue;
        end

        conn.beginJob(method);
        try
            handler = handlers(char(method));
            result = handler(params, conn);
            conn.endJob();
        catch ME
            conn.endJob();
            rethrow(ME);
        end
        if hasId, conn.respond(msg.id, result); end
    catch ME
        if ~hasId
            fprintf(2, 'actipass_engine: %s failed: %s\n', method, ME.message);
            continue;
        end
        try
            if ME.identifier == "ActiPASS:Canceled"
                conn.respondError(msg.id, EngineConn.CANCELED_CODE, "Canceled");
            else
                conn.respondError(msg.id, -32000, ME.message, struct( ...
                    'identifier', ME.identifier, ...
                    'report', getReport(ME, 'extended', 'hyperlinks', 'off')));
            end
        catch ME2
            fprintf(2, 'actipass_engine: connection lost (%s)\n', ME2.message);
            break;
        end
    end
end
fprintf('actipass_engine: stopped\n');
end

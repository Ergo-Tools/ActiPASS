classdef EngineConn < handle
    % EngineConn  JSON-RPC 2.0 connection of the Actipass engine to the desktop UI.
    %
    % One JSON message per line (UTF-8, LF terminated) over a localhost TCP socket.
    % The engine is a TCP client; the UI listens and starts or waits for the engine.
    %
    % While a request handler runs (Busy), the handler can call poll() (IpcProgress does
    % this when CancelRequested is read). poll() answers "job.cancel" and "engine.ping"
    % at once and rejects other requests with an "engine busy" error, so the UI never
    % waits on a request the engine cannot start.
    %
    % SPDX-License-Identifier: GPL-3.0-or-later

    properties (SetAccess = private)
        Client                      % tcpclient
        Busy (1,1) logical = false  % a request handler is running
        CurrentMethod (1,1) string = ""
        CancelRequested (1,1) logical = false
        LastReceived = []           % tic of the last message from the UI
    end

    properties
        Session struct = struct()   % state kept between requests (settings, licence, ...)
    end

    properties (Access = private)
        Buffer uint8 = uint8.empty(1,0) % received bytes not yet split into lines
        Queue cell = {}                 % decoded messages waiting for the main loop
    end

    properties (Constant)
        BUSY_CODE = -32001
        CANCELED_CODE = -32800
    end

    methods
        function obj = EngineConn(host, port, timeoutSec)
            obj.Client = tcpclient(host, port, "Timeout", timeoutSec, "ConnectTimeout", timeoutSec);
            obj.LastReceived = tic;
        end

        function delete(obj)
            obj.Client = [];
        end

        % ---------------------------------------------------------------- sending
        function send(obj, msg)
            % send one message (struct) as a JSON line
            bytes = unicode2native(char(jsonencode(msg)), 'UTF-8');
            write(obj.Client, [bytes uint8(10)]);
        end

        function notify(obj, method, params)
            % JSON-RPC notification (no id)
            if nargin < 3 || isempty(params), params = struct(); end
            obj.send(struct('jsonrpc', '2.0', 'method', char(method), 'params', params));
        end

        function respond(obj, id, result)
            if isempty(result), result = struct(); end
            obj.send(struct('jsonrpc', '2.0', 'id', id, 'result', result));
        end

        function respondError(obj, id, code, message, data)
            err = struct('code', code, 'message', char(message));
            if nargin >= 5 && ~isempty(data), err.data = data; end
            obj.send(struct('jsonrpc', '2.0', 'id', id, 'error', err));
        end

        function log(obj, level, text)
            % log line shown in the UI log strip
            obj.notify("log", struct('level', char(level), 'text', char(text), ...
                'time', char(string(datetime('now'), 'HH:mm:ss'))));
        end

        % --------------------------------------------------------------- receiving
        function msgs = receive(obj)
            % read all available bytes and return the complete messages (cell of structs)
            msgs = {};
            n = obj.Client.NumBytesAvailable;
            if n > 0
                obj.Buffer = [obj.Buffer, read(obj.Client, n, "uint8")];
            end
            lf = find(obj.Buffer == 10);
            if isempty(lf), return; end
            starts = [1, lf(1:end-1) + 1];
            for k = 1:numel(lf)
                line = strtrim(native2unicode(obj.Buffer(starts(k):lf(k)-1), 'UTF-8'));
                if isempty(line), continue; end
                try
                    msgs{end+1} = jsondecode(line); %#ok<AGROW>
                catch
                    obj.respondError([], -32700, "Parse error");
                end
            end
            obj.Buffer = obj.Buffer(lf(end)+1:end);
            obj.LastReceived = tic;
        end

        function msg = next(obj)
            % next message for the main loop ([] when none is waiting)
            if isempty(obj.Queue)
                obj.Queue = obj.receive();
            end
            if isempty(obj.Queue)
                msg = [];
            else
                msg = obj.Queue{1};
                obj.Queue(1) = [];
            end
        end

        function poll(obj)
            % handle messages that arrive while a handler is running
            msgs = obj.receive();
            for k = 1:numel(msgs)
                m = msgs{k};
                if ~isfield(m, 'method') || ~isfield(m, 'id')
                    continue; % notifications or stray responses: ignore
                end
                switch string(m.method)
                    case "job.cancel"
                        obj.CancelRequested = true;
                        obj.respond(m.id, struct('canceling', char(obj.CurrentMethod)));
                    case "engine.ping"
                        obj.respond(m.id, struct('busy', true, 'method', char(obj.CurrentMethod)));
                    case "engine.shutdown"
                        % stop the running job, then the main loop sees the shutdown again
                        obj.CancelRequested = true;
                        obj.Queue{end+1} = m;
                    otherwise
                        obj.respondError(m.id, obj.BUSY_CODE, ...
                            "Engine busy with " + obj.CurrentMethod);
                end
            end
        end

        function beginJob(obj, method)
            obj.Busy = true;
            obj.CurrentMethod = string(method);
            obj.CancelRequested = false;
        end

        function endJob(obj)
            obj.Busy = false;
            obj.CurrentMethod = "";
            obj.CancelRequested = false;
        end

        function s = idleSeconds(obj)
            s = toc(obj.LastReceived);
        end
    end
end

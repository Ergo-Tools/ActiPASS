classdef IpcProgress < handle
    % IpcProgress  Stand-in for uiprogressdlg that reports to the desktop UI.
    %
    % Has the properties ActiPASSV2 workflow functions use on a uiprogressdlg
    % (Value, Message, Title, Indeterminate, Cancelable, CancelRequested, close), so
    % e.g. actipass_UI_Process can be given an IpcProgress instead of a figure.
    % Setting Value/Message sends a throttled "progress" notification; reading
    % CancelRequested polls the connection for a "job.cancel" request. warn(msg) takes
    % the warnings a GUI would show as alerts (genStats).
    %
    % LogFile (optional): a log file the workflow writes (the batch log). Its new complete
    % lines are sent as "log" notifications (level "batch") whenever progress is reported
    % or cancel is polled, at most every LogInterval seconds, and at close. The workflow
    % keeps writing the file as before; the UI never reads it.
    %
    % SPDX-License-Identifier: GPL-3.0-or-later

    properties
        Value (1,1) double = 0
        Message (1,1) string = ""
        Title (1,1) string = ""
        Indeterminate = "off"
        Cancelable = "on"
        LogFile (1,1) string = ""
        % SubjectLog: a message naming another subject ("... ID: <id> ...") is also a log line
        % (level "tool") and, with ToolLogFile, a line of that file (tools; see note)
        SubjectLog (1,1) logical = false
        ToolLogFile (1,1) string = ""
    end

    properties (Dependent)
        CancelRequested (1,1) logical
    end

    properties (SetAccess = private)
        Conn EngineConn
        Job (1,1) string = ""
        Warnings (1,:) string = strings(1, 0) % messages passed to warn()
    end

    properties (Access = private)
        LastSent = []       % tic of the last notification
        LastMessage = ""
        MinInterval = 0.15  % seconds between notifications with an unchanged message
        LogPos = 0          % bytes of LogFile already sent
        LastLogRead = []    % tic of the last LogFile read
        LogInterval = 0.5   % seconds between LogFile reads
        LastSubject = ""    % subject of the last SubjectLog line
    end

    methods
        function obj = IpcProgress(conn, job, varargin)
            obj.Conn = conn;
            obj.Job = string(job);
            for k = 1:2:numel(varargin)-1
                if isprop(obj, varargin{k}) && ~strcmp(varargin{k}, 'CancelRequested')
                    obj.(varargin{k}) = varargin{k+1};
                end
            end
            obj.emit(true);
        end

        function set.Value(obj, v)
            obj.Value = min(max(v, 0), 1);
            obj.emit(false);
        end

        function set.Message(obj, m)
            obj.Message = string(m);
            obj.emit(false);
            if obj.SubjectLog
                tok = regexp(char(obj.Message), 'ID:\s*(\S+?)\.?(\s|$)', 'tokens', 'once'); % cell of char
                if ~isempty(tok) && ~strcmp(tok{1}, obj.LastSubject)
                    obj.LastSubject = string(tok{1});
                    obj.note(obj.Message);
                end
            end
        end

        function note(obj, text, level)
            % a line of the app's log (default level "tool") and of ToolLogFile, if set
            if nargin < 3, level = "tool"; end
            text = string(text);
            if ~isempty(obj.Conn), obj.Conn.log(level, char(text)); end
            if obj.ToolLogFile ~= ""
                try
                    fid = fopen(obj.ToolLogFile, 'a', 'n', 'UTF-8');
                    if fid > 0
                        fprintf(fid, '%s %s\n', string(datetime('now'), 'yyyy-MM-dd HH:mm:ss'), text);
                        fclose(fid);
                    end
                catch
                    % the log file is a convenience: never stop a tool for it
                end
            end
        end

        function tf = get.CancelRequested(obj)
            obj.Conn.poll();
            obj.pumpLog(false);
            tf = obj.Conn.CancelRequested;
        end

        function close(obj)
            obj.emit(true);
            obj.pumpLog(true);
        end

        function warn(obj, msg)
            % a warning the GUI would show as an alert (e.g. genStats): logged in the app,
            % and collected in Warnings for the job's result
            obj.Warnings(end+1) = string(msg);
            obj.Conn.log("warning", char(msg));
        end

        function pumpLog(obj, force)
            % send the new complete lines of LogFile (all remaining text when force)
            if obj.LogFile == "" || isempty(obj.Conn), return; end
            if ~force && ~isempty(obj.LastLogRead) && toc(obj.LastLogRead) < obj.LogInterval
                return;
            end
            obj.LastLogRead = tic;
            try
                d = dir(obj.LogFile);
                if isempty(d) || d.bytes <= obj.LogPos, return; end
                fid = fopen(obj.LogFile, 'r');
                if fid < 0, return; end
                closer = onCleanup(@() fclose(fid));
                fseek(fid, obj.LogPos, 'bof');
                bytes = fread(fid, [1 inf], '*uint8');
                if ~force
                    lastNL = find(bytes == 10, 1, 'last'); % only complete lines
                    if isempty(lastNL), return; end
                    bytes = bytes(1:lastNL);
                end
                obj.LogPos = obj.LogPos + numel(bytes);
                lines = splitlines(string(native2unicode(bytes, 'UTF-8')));
                for l = lines(strlength(strtrim(lines)) > 0)'
                    tok = regexp(l, '^(\d\d:\d\d:\d\d)\s+(.*)$', 'tokens', 'once');
                    if isempty(tok)
                        t = ""; txt = l;
                    else
                        t = tok(1); txt = tok(2);
                    end
                    obj.Conn.notify("log", struct('level', 'batch', 'text', char(strip(txt, 'right')), 'time', char(t)));
                end
            catch
                % a log line that cannot be read is not worth stopping the batch
            end
        end
    end

    methods (Access = private)
        function emit(obj, force)
            if isempty(obj.Conn), return; end
            obj.pumpLog(false);
            changed = obj.Message ~= obj.LastMessage;
            if ~force && ~changed && ~isempty(obj.LastSent) && toc(obj.LastSent) < obj.MinInterval
                return;
            end
            ind = strcmpi(string(obj.Indeterminate), "on");
            obj.Conn.notify("progress", struct('job', char(obj.Job), 'title', char(obj.Title), ...
                'value', obj.Value, 'message', char(obj.Message), 'indeterminate', ind));
            obj.LastSent = tic;
            obj.LastMessage = obj.Message;
        end
    end
end

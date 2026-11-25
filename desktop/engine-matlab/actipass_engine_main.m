function actipass_engine_main(varargin)
% actipass_engine_main  Entry point of the compiled engine (actipass_engine.exe).
%
%   actipass_engine <port> <token> [<host>] [<idleTimeoutSec>]
%
% A compiled application gets its command-line arguments as text; this converts them and
% calls actipass_engine. Open figures are closed at the end, otherwise a compiled
% application keeps running until the user closes them.
%
% Build: tools/build_engine.m. Development uses actipass_engine directly.
%
% SPDX-License-Identifier: GPL-3.0-or-later

status = 0;
try
    if nargin < 2
        fprintf(2, 'usage: actipass_engine <port> <token> [<host>] [<idleTimeoutSec>]\n');
        status = 2;
    else
        port = str2double(varargin{1});
        if ~isfinite(port) || port < 1 || port > 65535 || port ~= round(port)
            error('actipass_engine:args', 'invalid port: %s', varargin{1});
        end
        opts = {};
        if nargin >= 3 && strlength(varargin{3}) > 0
            opts = [opts, {'Host', string(varargin{3})}];
        end
        if nargin >= 4
            opts = [opts, {'IdleTimeout', str2double(varargin{4})}];
        end
        actipass_engine(port, string(varargin{2}), opts{:});
    end
catch ME
    fprintf(2, 'actipass_engine: %s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
    status = 1;
end
close all force;
if isdeployed
    exit(status);
end
end

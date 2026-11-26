function [Data,SF,deviceID] = readActGT3x(Fil)

% Read ActiGraph .gt3x files directly (no ActiLife CSV export needed)
%
% Same interface and output as readActGT3xcsv, so it can replace it for
% .gt3x files. Supports the log.bin format (GT3X+, wGT3X-BT, GT9X, CentrePoint
% Insight, ...) and the older NHANES-era activity.bin format. Gaps in the
% recording (idle sleep mode, missing packets) are filled with the last
% sample, as ActiLife does in its CSV export, and the recording runs to the
% 'Last Sample Time' in info.txt.
%
% Input:
%       Fil   [string/char-array]    full file path as a string
%   Output:
%       Data          [Nx4]  datetime (Matlab datenum format, local time of
%                            the device) and triaxial Acc data in g, columns
%                            ordered as in readActGT3xcsv
%       SF            [double] sample frequency
%       deviceID      [string] the device serial number as written in the header
%
% The .gt3x (zip) archive is read in memory (no temporary files) and parsed
% by the MEX function ActiGraph/readGT3xMex, a port
% of the C++ parser of the R package read.gt3x (THLfi, EUPL licence):
% https://github.com/THLfi/read.gt3x . See ActiGraph/readme.txt for how to
% rebuild it.
%
%
% Copyright (c) 2026, Pasan Hettiarachchi .
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
% 1. Redistributions of source code must retain the above copyright notice,
%    this list of conditions and the following disclaimer.
% 2. Redistributions in binary form must reproduce the above copyright notice,
%    this list of conditions and the following disclaimer in the documentation
%    and/or other materials provided with the distribution.
% 3. Neither the name of the copyright holder nor the names of its contributors
%    may be used to endorse or promote products derived from this software without
%    specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.


% intialise outputs
Data=[];
SF=NaN;
deviceID=NaN;

if exist('readGT3xMex','file')~=3
    addpath(fullfile(fileparts(mfilename('fullpath')),'ActiGraph'));
end

try
    % the MEX reads the .gt3x (zip) archive in memory: no temporary files
    Fil=char(Fil);
    [infoTxt,files]=readGT3xMex(Fil);
    [~,names,exts]=fileparts(files);
    names=lower(string(names)+string(exts));

    info=parseInfo(infoTxt);
    deviceID=string(strtrim(getField(info,"Serial Number","")));
    SF=str2double(getField(info,"Sample Rate",""));
    if isnan(SF) || SF<=0
        error("missing or invalid 'Sample Rate' in info.txt");
    end
    startSec=ticks2unix(getField(info,"Start Date",""));
    if isnan(startSec)
        error("missing 'Start Date' in info.txt");
    end
    scale=accScale(info,deviceID);

    % format: the old NHANES-era files (NEO/MRA with firmware <= 2.5.0) have
    % activity.bin instead of log.bin
    hasLog=any(names=="log.bin");
    hasAct=any(names=="activity.bin");
    if hasLog && ~(hasAct && isOldVersion(info,deviceID))
        fmt=0;
        % ActiLife's export runs to the last sample time, filling idle sleep
        lastSec=ticks2unix(getField(info,"Last Sample Time",""));
        if isnan(lastSec) || lastSec<=startSec
            lastSec=ticks2unix(getField(info,"Stop Date",""));
        end
        if isnan(lastSec) || lastSec<=startSec
            nRows=0;
        else
            nRows=round((lastSec-startSec)*SF);
        end
    elseif hasAct
        fmt=1;
        nRows=0;
    else
        error("no log.bin or activity.bin found in the .gt3x file");
    end

    % Data: time (matlab datenum, device local time) and the acc columns in
    % the order readActGT3xcsv returns them
    Data=readGT3xMex(Fil,fmt,startSec,SF,scale,nRows,1);

catch APE
    error("Error loading Actigraph GT3X file: "+APE.message);
end
end


function info=parseInfo(infoTxt)
% read the "Key: Value" lines of info.txt into a containers.Map of char values
txt=splitlines(string(infoTxt));
txt=txt(contains(txt,":"));
info=containers.Map('KeyType','char','ValueType','char');
for i=1:numel(txt)
    kv=split(txt(i),": ");
    if numel(kv)>=2
        info(char(strtrim(kv(1))))=char(strtrim(join(kv(2:end),": ")));
    end
end
end

function v=getField(info,key,default)
if isKey(info,char(key))
    v=info(char(key));
else
    v=default;
end
end

function s=ticks2unix(ticks)
% .NET ticks (100 ns since 0001-01-01) to seconds since 1970-01-01
t=sscanf(char(ticks),'%ld');
if isempty(t) || t<=0
    s=NaN;
    return;
end
s=double(idivide(int64(t),int64(10000)))/1000-62135596800;
end

function scale=accScale(info,deviceID)
% acceleration scale (counts per g), with the defaults used by read.gt3x
scale=str2double(getField(info,"Acceleration Scale",""));
if isnan(scale) || scale<=0
    if startsWith(deviceID,["MOS","TAS"])
        scale=256;
    else % NEO, CLE, MRA and unknown
        scale=341;
    end
end
end

function tf=isOldVersion(info,deviceID)
fw=sscanf(getField(info,"Firmware","99"),'%d.%d.%d')';
fw(end+1:3)=0;
tf=startsWith(deviceID,["MRA","NEO"]) && ...
    (fw(1)<2 || (fw(1)==2 && (fw(2)<5 || (fw(2)==5 && fw(3)==0))));
end

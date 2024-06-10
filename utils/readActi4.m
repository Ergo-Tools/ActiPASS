function [Data,SF,deviceID,AccType] = readActi4(File)
% readActi4 Read data from .act4 file

% Modified from original Acti4 Rev: 8/1-18 version at
% https://github.com/motus-nfa/Acti4/blob/main/Version%20July%202020/ReadACT4.m)
% 
% Input:
%       PATH [string]: full file path as a string
%
%   Output:
%       Data          [Nx4]  datetime (Matlab datenum format) and 3D acceleration data
%       SF            [double] the sample frequency
%       deviceID      [double] the device ID

% Copyright (c) 2024, Pasan Hettiarachchi
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

% define arguments types and default values
arguments
    File {mustBeFile}
end
%Byte offset for start of recorded data, always 100
IbyteStart = 100; 

try
    % [Acc,SF,StartActi,SN,AccType]
    Fid = fopen(File,'r'); %open for reading file
    AccType = str2double(fgetl(Fid)); %version no/device type.
    deviceID = fgetl(Fid); %Serial number of ActiGraph unit
    % convert the device ID to a number (until ActiPASS supports string device IDs)
    deviceID = str2double(strjoin(extract(deviceID,digitsPattern),'')); 
    SF = str2double(fgetl(Fid)); %Sample frequency (Hz)
    Start = str2double(fgetl(Fid)); %Start time of recording (datenum value)
    %End = str2double(fgetl(Fid)); %End time of recording (datenum value)
    %Stop = str2double(fgetl(Fid)); %Stop time of recording (NaN if stop time was not set)
    %Down = str2double(fgetl(Fid)); %Download time of recording (datenum value)
    
    Nsamples = str2double(fgetl(Fid)); %Number of samples sets (triple value) in recording
    % seek to begining of data block
    fseek(Fid,IbyteStart,'bof');
    %read acc data
    Acc = double(fread(Fid,[3,Nsamples],'uint16')')/1000-10;
    fclose(Fid); %close file handöe
    
    %restoring NaNs that have been saved as 0 in act4 files
    Acc(Acc==-10) = NaN;
    
    %recreate time axis
    time = Start+(0:1:(Nsamples-1))'/SF/86400;
    
    Data=[time,Acc];
    
catch ACT4E
    % try to close the file if still open
    if ~isempty(fopen(Fid))
        fclose(Fid);
    end
    % propagate the error to calling function/script
    error("Error loading ACT4 file: " + ACT4E.message);
end


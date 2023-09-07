function [Data,SF,deviceID] = readSENSBin(File)

% Read SENS motion binary files
% 
% Input:
%       File   [string/char-array]    full file path as a string
%   Output:
%       Data          [Nx4]  datetime (Matlab datenum format) and triaxial Acc data
%       SF            [double] sample frequency
%       deviceID      [string] the device ID -currently set to NaN since SENS bin files do not carry this information
%
%
% Copyright (c) 2023, Pasan Hettiarachchi .
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

try
    Fid = fopen(File);
    D_raw = fread(Fid,[6,Inf],'int16=>int16',0,'b')'; %6 bytes (Unix ms), 2 bytes (X), 2 bytes (Y), 2 bytes (Z)
    fclose(Fid);
    Acc = double(D_raw(:,4:6))*0.0078125; %Acceleration
    T_raw = double([typecast(D_raw(:,1),'uint16'),typecast(D_raw(:,2),'uint16'),typecast(D_raw(:,3),'uint16')]) * [2^32,2^16,1]';
    T_sens = datenum('1970/01/01') + T_raw/1000/86400 + 2/24; %UTC
    SF=round(1/(86400*mean(diff(T_sens(1:min(1000,length(T_sens)))))),1); % find the sample frequency
    Data =  [T_sens,Acc];
catch ME
    error("Error loading SENS motion bin file: "+ME.message);
end
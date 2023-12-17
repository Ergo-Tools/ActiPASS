function [Data,SF,deviceID] = readSENSBin(File,timeZoneOffset)
% Read SENS motion binary files

% Input:
%       File   [string/char-array]    full file path as a string
%       timeZoneOffset [double] Timezone offset in hours from UTC where the measurement is made
%   Output:
%       Data          [Nx4]  datetime (Matlab datenum format) and triaxial Acc data
%       SF            [double] sample frequency
%       deviceID      [string] the device ID -currently set to NaN since SENS bin files do not carry this information

% arguments checks
arguments
    
    File {mustBeFile}
    % if no timeZoneOffset is given assume it's local time-zone
    timeZoneOffset double = hours(tzoffset(datetime('now','TimeZone','local')))
end

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

% initialise outputs
Data=[];
SF=NaN;
deviceID=NaN;

try
    [~,f_name,f_ext] = fileparts(File);
    if ~matches(f_ext,[".hex",".bin"],'IgnoreCase',true)
        error(f_ext+" file type not supported");
    end
    patStartID = textBoundary+"export_";
    patEndID = "_acc-"+wildcardPattern+textBoundary;
    deviceID=extractBetween(f_name,patStartID,patEndID); % find the device-ID string
    % check whether the iD_string have the correct format
    if ~matches(deviceID,textBoundary+alphanumericsPattern(2)+"-"+alphanumericsPattern(2)+"."+alphanumericsPattern(2)+textBoundary)
        deviceID=NaN;
    else
        try
            % assume ID string is hexadecimal and find the decimal value from the hex value
            deviceID=hex2dec(erase(deviceID,["-","."]));
        catch
            deviceID=NaN;
        end
    end
    
    if strcmpi(f_ext,".bin")
        Fid = fopen(File);
        D_raw = fread(Fid,[6,Inf],'int16=>int16',0,'b')'; %6 bytes (Unix ms), 2 bytes (X), 2 bytes (Y), 2 bytes (Z)
        fclose(Fid);
        Acc = double(D_raw(:,4:6))*0.0078125; %Acceleration
        T_raw = double([typecast(D_raw(:,1),'uint16'),typecast(D_raw(:,2),'uint16'),typecast(D_raw(:,3),'uint16')]) * [2^32,2^16,1]';
        T_sens = datenum('1970/01/01') + T_raw/1000/86400 + timeZoneOffset/24; %return local time
        SF=round(1/(86400*mean(diff(T_sens(1:min(1000,length(T_sens)))))),1); % find the sample frequency
        Data =  [T_sens,Acc]; % merge time and Acc data horizontally into one matrix
        
    elseif strcmpi(f_ext,".hex")
        D_hex = fileread(File);  % oload the full hex file into memory
        D_hex(D_hex==char(10))=[]; %remove the newline character
        D_hex=reshape(D_hex,2,[])'; %reshape such that two-byte hext string is in each row
        D_hex =uint8(base2dec(D_hex,16)); % converthex values to uint8 (bytes)
        D_hex=swapbytes(typecast(D_hex,'int16')); % typecast to integers and change the endian
        D_hex=reshape(D_hex,6,[])';% reshape to 6 words (12 byte) rows: 6 bytes (Unix ms), 2 bytes (X), 2 bytes (Y), 2 bytes (Z) again 
        Acc = double(D_hex(:,4:6))*0.0078125; %Acceleration
        T_raw = double([typecast(D_hex(:,1),'uint16'),typecast(D_hex(:,2),'uint16'),typecast(D_hex(:,3),'uint16')]) * [2^32,2^16,1]';
        T_sens = datenum('1970/01/01') + T_raw/1000/86400 + timeZoneOffset/24; %return local time
        SF=round(1/(86400*mean(diff(T_sens(1:min(1000,length(T_sens)))))),1); % find the sample frequency
        Data =  [T_sens,Acc]; % merge time and Acc data horizontally into one matrix
    
    end
    
catch ME
    error("Error loading SENS motion bin file: "+ME.message);
end
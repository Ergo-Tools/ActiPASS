
function [Data, SF, deviceID] = readGenericCSV(PATH)
% readGenericCSV Read generic CSV files with specified format and ISO8601 timestamp
% 
% 
%   Input:
%       PATH [string]: full file path as a string
%
%       Note:   Input CSV file must have the shape of (n_rows, 3). Where
%               n_rows is the number of sampled datapoints. The columns must be
%               named [x, y, z] and arranged in the exact order.
%               
%               The acceleration axis must conform to the standard ActiPASS AX3
%               orientation (i.e. x-axis pointing down, z-axis inwards towards skin).
%
%               The first four lines in the CSV file must contain the
%               deviceID (only numeric), the sampling frequency, start-time and the column names.
%               ID=<numeric devideID>  (e.g. 'ID=34567850')
%               SF=<sampling frequency> (e.g. 'SF=50')
%               START=<start time in ISO8601 format> (e.g. 'START=20240301T154517.250')
%               x, y, z
%               
%               Remarks:
%               1. To improve performance and to reduce file sizes a seperate time colun is excluded. 
%               2. Consequently, only supports data which are resampled to a fixed sampling frequency.
%
%
%   Output:
%       Data          [Nx4]  datetime (Matlab datenum format) and 3D acceleration data
%       SF            [double] the sample frequency
%       deviceID      [string] the device ID

% Copyright (c) 2024, Claas Lendt & Pasan Hettiarachchi
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

Data = [];
SF = NaN;
deviceID = NaN;

try
    % Open the file once and keep it open for reading both metadata and data
    fileID = fopen(PATH, 'r');
    
    % Read the first three lines for metadata and start-time
    idLine = fgetl(fileID);
    sfLine = fgetl(fileID);
    startLine = fgetl(fileID);
    
    % read the column header line
    headL=fgetl(fileID);
    
    % Extract ID and SF values using correct indexing
    deviceID = extractBetween(idLine,textBoundary+"ID=",textBoundary);
    SF = extractBetween(sfLine,textBoundary+"SF=",textBoundary);
    
    % find the start time. If this fails function will return
    startT=datenum(extractBetween(startLine,textBoundary+"START=",textBoundary),'yyyymmddTHHMMSS.FFF');
    
    % check for file-validity by checking for DeviceID and SF
    if isempty(deviceID) || isempty(SF) || isempty(startT) || ~matches(headL,["x,y,z","x, y, z"],'IgnoreCase',true)
        error("unrecognized generic CSV format");
    end
    
    % convert SF and DeviceID to numbers (ActiPASS only supports numeric device serial-numbers)
    SF=str2double(SF);
    deviceID=str2double(deviceID);
    
    % Use textscan to read the data, reading datetime as text
    formatSpec = '%f%f%f';
    dataArray = textscan(fileID, formatSpec, 'Delimiter', ',', 'EmptyValue', NaN);
    fclose(fileID); % Ensure file is closed after reading
    
    % Prepare the output data
    time = startT+(0:1:(length(dataArray{1})-1))'/SF/86400; % re-create the time vector
    x = dataArray{1};
    y = dataArray{2};
    z = dataArray{3};
    Data = [time, x, y, z];
    
catch APE
    % try to close the file if still open
    if ~isempty(fopen(fileID)) 
        fclose(fileID); 
    end
    % propagate the error to calling function/script
    error("Error loading CSV file: " + APE.message); 
end


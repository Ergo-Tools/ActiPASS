function [Data,SF,deviceID] = readActGT3xcsv(Fil)

% Read actigraph GT3X files converted by recent versions of ActiLife(6.13 or later)
% 
% Input:
%       Fil   [string/char-array]    full file path as a string
%   Output:
%       Data          [Nx4]  datetime (Matlab datenum format) and triaxial Acc data
%       SF            [double] sample frequency
%       deviceID      [string] the device ID


% Copyright (c) 2021, Pasan Hettiarachchi .
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
       
    
    %Import of data from csv-file:
    
    Rec = importdata(Fil,',');
    headLs=string(Rec.textdata(:,1));
    %parse the text data in header
    dataFmtL=extractBetween(headLs(1),"date format","Hz",'Boundaries','inclusive');
    dateFormat=strip(extractBetween(dataFmtL,"date format","at"));
    SF=str2double(extractBetween(dataFmtL,dateFormat+" at","Hz"));
    deviceID=extractAfter(headLs(2),"Serial Number: ");
    deviceID=regexp(deviceID,'\d+','match');
    deviceID=str2double(deviceID(end));
    startTime=extractAfter(headLs(3),"Start Time ");
    startDate=extractAfter(headLs(4),"Start Date ");
    
    dateFormat=replace(replace(dateFormat,"M","mm"),"d","dd");
    startTime=datenum(startDate+" "+startTime,dateFormat+" HH:MM:SS");
    % create the time axis as a matlab datenum
    timeDN=startTime+(0:1:(size(Rec.data,1)-1))'/SF/86400;
    % Merge time with Acc data to 'Data'
    Data = [timeDN,Rec.data(:,2),Rec.data(:,1),Rec.data(:,3)];
    
catch APE
    error("Error loading Actigraph CSV file: "+APE.message);
end


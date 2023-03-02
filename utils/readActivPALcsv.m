function [Data,SF,deviceID,ID] = readActivPALcsv(Fil)

% Reads compressed or uncompressed ActiPAL csv files and interpolate data to sample frequency SF
%   Input:
%       Fil   [string/char-array]    full file path as a string
%
%   
%   Output:
%       Data          [Nx4]  datetime (Matlab datenum format) and triaxial Acc data
%       SF            [double] sample frequency
%       deviceID      [string] the device ID
%       ID            [string] the participant ID



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

%File name information:
[~,FileName] = fileparts(Fil);

try
    
    
    patSN_ID = (textBoundary|"-")+alphanumericsPattern+"-AP" + digitsPattern(6) + whitespaceBoundary;
    textSN_ID=extract(FileName,patSN_ID);
    if ~isempty(textSN_ID)
        deviceID=str2double(extractAfter(textSN_ID,"-AP"));
        ID=extractBetween(textSN_ID,("-"|textBoundary),"-AP" + digitsPattern(6));
    else
        warning('Unsupported ActivPAL filename: %s',FileName);
        
        ID=FileName;
        deviceID=NaN;
        
    end
    
    %Import af data fra csv-datafilen:
    
    Rec = importdata(Fil,';',2);
   
    time = Rec.data(:,1);
    
    
    it = Rec.data(:,2); %sampleindex
    Acc = Rec.data(:,size(Rec.data,2)-2:size(Rec.data,2)); %last 3 columns
    clear Rec
    
    % check for compressed or uncompressed data format
    if length(it) < it(end)+1 %Compressed data
        t = interp1(it,time,0:it(end),'linear');
        Acc = interp1(time,Acc,t,'nearest');
    else %uncompresses data
        t = time;
    end
    
    SF=round(1/(86400*mean(diff(t(1:min(1000,length(t))))))); % find the sample frequency
    
    Data=zeros(length(t),4);
    Data(:,1)=x2mdate(t);
    
    
    if max(max(Acc))> 255 % if any number exceed 255 the file must be a AP4 file
        Grange = 2*4; %range +/-4G
        Data(:,2:4) = (Acc-(1023+4)/2) * (Grange/(1023-4));
    else % otherwise it's an ActivPAL3 file
        Grange = 2*2; %range +/-2G
        Data(:,2:4) = (Acc-(253+1)/2)*(Grange/(253-1));
    end
    
catch APE
    error("Error loading ActivPal CSV file: "+APE.message);
end


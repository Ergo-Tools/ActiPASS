function [Data, SF, deviceID, ID] = readMovisensBin(XML_File,ACC_File)
% readMovisensBin Read movisens binary acceleration data
% See https://docs.movisens.com/Unisens/UnisensFileFormat/

% Input:
%       XML_File    [string/char-array]     full "unisens.xml" file path
%       ACC_File    [string/char-array]     full "acc.bin" file path (optional)

% Output:
%       Data        [Nx4]       datetime (Matlab datenum format) and triaxial acceleration data (in g)
%       SF          [double]    sample frequency (in Hz)
%       deviceID    [string]    the sensor serial number (five digits)
%       ID          [string]    the participant ID

% Copyright (c) 2024, Carl Bittendorf & Pasan Hettiarachchi
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

% arguments check
arguments
    XML_File {mustBeFile}
	ACC_File (1,1) string = ""
end


try
    % check for input files validity and derive optional filename
    [us_folder,~,f_ext] = fileparts(XML_File);
    [~,~,f_ext_bin] = fileparts(XML_File);
    if ~strcmpi(f_ext,".xml")
        error(f_ext+" file type not supported");
    end
    % if the second argument was ommited derive ACC_File from the path
    if ACC_File=="" 
        ACC_File = fullfile(us_folder,"acc.bin");
        if ~isfile(ACC_File)
            error("file: "+ACC_File+" does not exist");
        end
    elseif ~isfile(ACC_File)
        error("file: "+ACC_File+" does not exist");
    elseif ~strcmpi(f_ext_bin,".bin")
        error("file type not supported: "+ACC_File);
    end

    % read XML file
    tree = xmlread(XML_File);

    % parse the relevant information into a struct
    info = parseXML(tree, struct());

    SF = info.SF;
    deviceID = info.deviceID;
    ID = info.ID;
    Start = info.Start;
    scale = info.scale;
    
	% parse binary acc.bin file
    Fid = fopen(ACC_File);
    Data_raw = fread(Fid,[3,Inf],'int16=>double',0,'l')'; % 2 bytes (X), 2 bytes (Y), 2 bytes (Z)...
    fclose(Fid);
    Acc = Data_raw * scale; % scaling factor (0.00048828125 for ±16g)
    N = size(Acc, 1); % number of measurements
    TimestampStart = datetime(Start, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS'); % convert input to datetime format
    TimestampEnd = TimestampStart + seconds((N - 1) / SF); % timestamp of the last measurement
    T = TimestampStart:seconds(1 / SF):TimestampEnd; % generate sequence of timestamps
    Data = [transpose(datenum(T)),Acc]; % merge time (in datenum format) and acceleration data horizontally into one matrix

catch ME
    error("Error loading movisens binary file: "+ME.message);
end


% ----- Local function PARSEXML -----
function [info] = parseXML(node, info)

if node.hasAttributes
    attributes = node.getAttributes;
    numAttributes = attributes.getLength;
    values = arrayfun(@(i) string(attributes.item(i-1).getValue), 1:numAttributes); % array with the values from every attribute

    for count = 1:numAttributes
        attribute = attributes.item(count-1);
        name = string(attribute.getName);

        % check if the node possesses any attributes we want and save them as fields in the struct
        if any(strcmp(values, "acc"))
            if name == "sampleRate"
                info.SF = str2double(string(attribute.getValue));
            elseif name == "lsbValue"
                info.scale = str2double(string(attribute.getValue));
            end

        elseif any(strcmp(values, "sensorSerialNumber")) && name == "value"
            info.deviceID = string(attribute.getValue);

        elseif any(strcmp(values, "personId")) && name == "value"
            info.ID = string(attribute.getValue);

        elseif name == "timestampStart"
            info.Start = string(attribute.getValue); % timestamp of the first measurement in the format "yyyy-mm-ddTHH:MM:SS.FFF"
        end
    end
end

% recurse over node children
if node.hasChildNodes
    childNodes = node.getChildNodes;
    numChildNodes = childNodes.getLength;

    for count = 1:numChildNodes
        child = childNodes.item(count-1);
        info = parseXML(child, info);
    end
end

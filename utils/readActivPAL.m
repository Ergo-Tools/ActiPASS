function Data = readActivPAL(filePath, varargin)
%LOAD_DATX Opens the raw data files from activpal devices
%   SYNTAX:
%       Data = readActivPAL(filePath)
%       Data = readActivPAL(filePath, 'Name', 'Value')
%
%   DESCRIPTION:
%       Data = readActivPAL(filePath) - loads data from binary activpal data files.
%
%       Data = readActivPAL(filePath, 'Name', 'Value') - modifies the output using
%                   Name, Value pair arguments.
%           Named arguments:
%               'units' - Specify the units for accelerometer data.
%                         Accepted values are: 'g' (default), 'ms-2', 'raw'
%
%   OUTPUT:
%       A structure with two fields:
%           signals - a table with 4 columns (dateTime, x, y, z)
%           meta - a structure containing the metadata
%       The fields of the meta structure are:
%           bitdepth - 8bits or 10bits
%           resolution - ±2g, ±4g or ±8g (g = 9.81 ms-2)
%           hz - the sample frequency
%           axes - the number of axes recorded
%           startTime - the start time of the recording
%           stopTime - the stop time of the recording
%           duration - the length of the recording (Matlab duration type)
%           stopCondition - Trigger, Immediately, Set Time
%           startCondition - Memory Full, Low Battery, USB, Programmed Time
%           deviceID - ActivPAL serial number read from filename (may be inaccurate)
%
%   EXAMPLE:
%       [fileName, fileDir] = uigetfile( ...
%           {'*.datx; *.dat', 'activPAL Files (*.dat, *.datx)'}, ...
%           'Select an activPAL data file' );
%       filePath = fullfile(fileDir, fileName);
%       Data = activpal_utils.readActivPAL(filePath);
%
%   For more information, see <a href="matlab:web(...
%   'https://github.com/R-Broadley/activpal_utils-matlab/wiki/Documentation'...
%   )">activpal_utils wiki</a>
%
%   Requires Matlab version 8.2 (2013b) or later.
%
%   Copyright: R Broadley 2017
%
%   License: GNU General Public License version 2.
%            A copy of the General Public License version 2 should be included
%            with this code. If not, see <a href="matlab:web(...
%            'https://www.gnu.org/licenses/gpl-2.0.html'...
%            )"> GNU General Public License version 2</a>.
%   Modified: Pasan Hettiarachchi (C) 2020

% Check matlab version supported
if verLessThan('matlab', '8.2')
    msgID = 'MATLAB:VersionError';
    msgText = 'Matlab version is too old to support readActivPAL';
    ME = MException(msgID, msgText);
    throw(ME);
end

% Imports



% Defaults
defaultUnits = 'g';

% Input validation functions
checkFilePath = @(x) checkActivPALFile(x, 'validExt', {'.datx', '.dat'});
checkUnits = @(x) ischar(x) && any(strcmp(x, {'g', 'ms-2', 'raw'}));

% Parse inputs
p = inputParser;
addRequired(p, 'filePath', checkFilePath);
addParameter(p, 'units', defaultUnits, checkUnits);
parse(p, filePath, varargin{:});

% Get inputs
filePath = p.Results.filePath;
units = p.Results.units;

% Get file extension
[~,FileName,fileExt] = fileparts(filePath);

% Determine length of header
headerEndMap = containers.Map({'.datx', '.dat'}, {1024, 1023});
headerEnd = headerEndMap(fileExt);

% Open file
f = fopen(filePath, 'r');
fileContents = uint8(transpose(fread(f)));
fclose(f);

% Identify firmware
firmware = uint64(fileContents(40)) * 255 + uint64(fileContents(18));
% Identify if file uses compression
compression = fileContents(37);  % True(1) / False(0)

% Extract Metadata
Data.meta = extract_metadata_ActivPAL(fileContents(1:headerEnd));

% Add device-ID to metadata
% device-ID is found using the filename


patSN_ID = (textBoundary|"-")+alphanumericsPattern+"-AP" + digitsPattern(5,8) + whitespaceBoundary;
textSN_ID=extract(FileName,patSN_ID);
if ~isempty(textSN_ID)
    deviceID=str2double(extractAfter(textSN_ID,"-AP"));
else
    warning('Unsupported ActivPAL filename: %s',FileName);
    deviceID=NaN;
end


Data.meta.deviceID = deviceID;


% Locate Tail
tailStart = locate_tail_ActivPAL(fileContents, headerEnd, fileExt);
% Extract accelerometer data
fbodyInd = headerEnd + 1 : tailStart - 1;
signals = extract_accdata_ActivPAL( fileContents(fbodyInd), firmware, ...
    compression, Data.meta.axes );

% Check sample rate
try
    Data.meta.hz = correct_hz_ACTIVPAL(length(signals), Data.meta.hz, ...
        Data.meta.duration);
catch ME
    if strcmp(ME.identifier, 'readActivPAL:samplerateError')
        msg =  ['The sample rate is outside the excepted range in file:\n' ...
            '%s\n' ...
            'Please report this to the developers at:\n' ...
            'https://github.com/R-Broadley/activpal_utils-matlab/issues'];
        ME = MException(ME.identifier, msg, filePath);
    end
    throw(ME);
end

% Remove invalid rows
signals = clean_ActivPAL(signals, 254);
signals = clean_ActivPAL(signals, 255);

if ~strcmp(units, 'raw')
    % Convert binary values to g
    signals = (double(signals) - 127) / 63;
end
if strcmp(units, 'ms-2')
    % Convert from g to ms-2
    signals = signals * 9.81;
end

% Generate time stamps
nsec = (1 : length(signals)) * (1 / double(Data.meta.hz));
timeStamps = (Data.meta.startTime + seconds(nsec))';

Data.signals = table( timeStamps, ...
    signals(:,1), signals(:,2), signals(:,3), ...
    'VariableNames', {'dateTime', 'x', 'y', 'z'} );

Data.signals.Properties.VariableUnits = [ {'datetime'}, ...
    repmat({units}, 1, 3) ];
end


function tailStart = locate_tail_ActivPAL(fileContents, headerEnd, fileExt)
if strcmp(fileExt, '.datx')
    tailStart = strfind(fileContents, [116 97 105 108]);
    tailStart = tailStart(end);
elseif strcmp(fileExt, '.dat')
    tailStart = find( (fileContents(headerEnd : end - 7)== 0) & ...
        (fileContents(headerEnd + 1 : end - 6) == 0) & ...
        (fileContents(headerEnd + 2 : end - 5) >= 1) & ...
        (fileContents(headerEnd + 3 : end - 4) == 0) & ...
        (fileContents(headerEnd + 4 : end - 3) == 0) & ...
        (fileContents(headerEnd + 5 : end - 2) >= 1) & ...
        (fileContents(headerEnd + 6 : end - 1) >= 1) & ...
        (fileContents(headerEnd + 7 : end) == 0), 1 );
    tailStart = tailStart + headerEnd;
end
end


function Metadata = extract_metadata_ActivPAL(header)
if header(39) < 128
    Metadata.bitdepth = 8;
    resolutionByte = header(39);
else
    Metadata.bitdepth = 10;
    resolutionByte = header(39) - 128;
end

resolutionMap = containers.Map({0, 1, 2}, {2, 4, 8});
try
    Metadata.resolution = resolutionMap(resolutionByte);
catch ME
    if strcmp(ME.identifier, 'MATLAB:Containers:Map:NoKey')
        Metadata.resolution = ['Unknown (' num2str(resolutionByte) ')'];
    else
        rethrow(ME);
    end
end

Metadata.hz = header(36);

axesMap = containers.Map({0, 1}, {3, 1});
try
    Metadata.axes = axesMap(header(281));
catch ME
    if strcmp(ME.identifier, 'MATLAB:Containers:Map:NoKey')
        Metadata.axes = ['Unknown (' num2str(header(281)) ')'];
    else
        rethrow(ME);
    end
end

Metadata.startTime = datetime( uint64(header(262)) + 2000, header(261), ...
    header(260), header(257), header(258), ...
    header(259) );

Metadata.stopTime = datetime( uint64(header(268)) + 2000, header(267), ...
    header(266), header(263), header(264), ...
    header(265) );

Metadata.duration = Metadata.stopTime - Metadata.startTime;

startConditionMap = containers.Map( {0, 1, 2}, ...
    {'Trigger', 'Immediately', 'Set Time'} );
try
    Metadata.startCondition = startConditionMap(header(269));
catch ME
    if strcmp(ME.identifier, 'MATLAB:Containers:Map:NoKey')
        Metadata.startCondition = ['Unknown (' num2str(header(269)) ')'];
    else
        rethrow(ME);
    end
end

stopConditionMap = containers.Map( {0, 3, 64, 128}, ...
    {'Memory Full', 'Low Battery', 'USB', ...
    'Programmed Time'} );
try
    Metadata.stopCondition = stopConditionMap(header(276));
catch ME
    if strcmp(ME.identifier, 'MATLAB:Containers:Map:NoKey')
        Metadata.stopCondition = ['Unknown (' num2str(header(276)) ')'];
    else
        rethrow(ME);
    end
end
end


function accelerometerData = extract_accdata_ActivPAL(fbody, firmware, compression, naxes)
if naxes ~= 3
    msgID = 'readActivPAL:fileError';
    msgText = ['Reading data from uniaxial recordings has not been ' ...
        'implemented yet.\n' ...
        'Please report this to the developers at:\n' ...
        'https://github.com/R-Broadley/activpal_utils-matlab/issues'
        '\n Affected file: \n %s'];
    ME = MException(msgID, msgText, filePath);
    throw(ME);
end

% Check length of data is divisible by naxes
remainder = rem(length(fbody), naxes);
if remainder ~= 0
    fbody = fbody(1 : end - remainder);
    warning( strcat('Length of data_stream is not divisible ', ...
        ' by the number of axes. Either the file ',...
        ' tail has not have been completed removed ',...
        ' or some accelerometer data has been removed.') );
end

% Reshape fbody to n by naxes
fbody = reshape(fbody, naxes, [])';

% Decompress
if compression && firmware > 217
    accelerometerData = decompress_ActivPAL(fbody);
elseif compression
    accelerometerData = old_decompress_ActivPAL(fbody);
end
end


function decompressedData = decompress_ActivPAL(inputData)


compressedLoc = find(inputData(:, 1) == 0 & inputData(:, 2) == 0);
compressionN = double(inputData(compressedLoc, 3));

rowMultiplier = ones(length(inputData), 1);
rowMultiplier(compressedLoc - 1) = compressionN + 1;
rowMultiplier(compressedLoc) = 0;

decompressedData = repelem(inputData, rowMultiplier,1);

end


function decompressedData = old_decompress_ActivPAL(inputData)

compressedLoc = find(inputData(:, 1) == 0 & inputData(:, 2) == 0);
compressionN = double(inputData(compressedLoc, 3)) + 1;

starts = diff([0; compressedLoc]);
starts(starts == 1 ) = 0;
starts(starts > 0) = 1;
edges = diff([starts; 1]);
startInd = find(edges < 0);
endInd = find(edges > 0);
for i = 1:length(startInd)
    compressionN(startInd(i)) = sum(compressionN(startInd(i) : endInd(i)));
end

rowMultiplier = ones(length(inputData), 1);
rowMultiplier(compressedLoc - 1) = compressionN + 1;
rowMultiplier(compressedLoc) = 0;

decompressedData = repelem(inputData, rowMultiplier,1);
end


function hz = correct_hz_ACTIVPAL(nsamples, hz, duration)
allowedVariability = 0.005;  % 0.5%
maxAllowedHz = double(hz) * (1 + allowedVariability);
minAllowedHz = double(hz) * (1 - allowedVariability);
avgHz = nsamples / seconds(duration);

if avgHz > minAllowedHz && avgHz < maxAllowedHz
    hz = avgHz;
else
    ME = MException('readActivPAL:samplerateError', '');
    throw(ME);
end
end


function cleanedData = clean_ActivPAL(inputData, value)
[rows2remove, ~] = find(inputData == value);
cleanedData = inputData;

% If no rows2remove return (out = in)
if isempty(rows2remove)
    return;
end

rows2remove = unique(rows2remove);
for i = 1 : length(rows2remove)
    r = rows2remove(i);
    cleanedData(r, :) = cleanedData(r - 1, :);
end
end

%% ActiPASS Example workflow for understanding how it works
% WARNING: 
% This is a very basic basic example workflow. Actual ActiPASS workflow used in the GUI is much more robust and
% contains improved error handling including, visualizations, quality-checks and fallbacks to alternative methods
% for reference-position corrections.
% Use this just as an example script how ActiPASS algorithms can be used. 

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

%% Initialize 
clear variables;
acc_file="C:\Users\xxxxx\Downloads\testdata.csv";
out_file="C:\Users\xxxxx\Downloads\ActiPASS_output.csv";

tic; % start a timer
fprintf('%s Intialized.\n',string(datetime,"HH:mm:ss.SSS"));

% load default settings
[Settings,SettingsAkt] = LoadSettings("","");
fprintf('%s Loaded settings.\n',string(datetime,"HH:mm:ss.SSS"));

% define extra settings not saved/loaded from config files
Fs=25; % The resample frequency
Fc=2; % the cutoff frequency for angle and vector-magnitude finding (primary filter)

% give a dummy subject-ID to the data
subjectIDs="S001"; % normally a vector of strings. See open_accfiles.m 
% the device type is "Generic" for generic CSV files. Will be used if necessary in quality check function
devType="Generic";
% also specify the file/devtype in SettingsAkt struct (used for any device specific correction like for SENS accelerometers)
% for more info see open_accfiles.m
SettingsAkt.ftype=7; % ftype is set to generic CSV files

% reference position values min, max and defaults
VrefThighMin = (pi/180)*[0,-32,-15];
VrefThighMax = (pi/180)*[32,0,15];
VrefThighDef = (pi/180)*[16,-16,0];

%an empty vector to hold the activity classification of each second
actFull=[];
timeFull=[];

%% load or skip optional diary data
% we skip loading a diary
[d_status,diaryStrct,diary_file] = open_diary("",subjectIDs,0); % call open_diary function with no diary file
fprintf('%s %s\n',string(datetime,"HH:mm:ss.SSS"),d_status);

%% load  accelerometer data and calibrate

% loading generic CSV file
fprintf('%s Generic CSV file loading....\n',string(datetime,"HH:mm:ss.SSS"));
[genCSVData,SF,deviceID]=readGenericCSV(acc_file);

% generic CSV format follows Axivity ProPASS axes convention.
%therefore y and z axes should be inverted to match ActiPASS internal convention
genCSVData(:,3:4)=-genCSVData(:,3:4);

% interpolate Acc. data at evenly spaced samples
fprintf('%s Data interpolating at %d Hz....\n',string(datetime,"HH:mm:ss.SSS"),Fs);

% fix start and end to interger second time of mtStart and mtEnd.
% This  is because main activity detection algorithm expects it
mtStart = round(genCSVData(1,1)*86400)/86400;
mtEnd = round(genCSVData(end,1)*86400)/86400;


% create evenly spaced time axis at given samplerate
t = linspace(mtStart,mtEnd,(mtEnd-mtStart)*86400*Fs+1)';

% preaalocate a 4-column vector to hold interpolated acc data
Dintp=zeros(length(t),4);
Dintp(:,1)=t;

% do the interpolation
for j=2:4
   Dintp(:,j) = interp1(genCSVData(:,1),genCSVData(:,j),t,'pchip',0); % cubic interpolation at given sample points
end

%time and accelrometer data
dataTH.AXES=Dintp;
% empty temperature vector
dataTH.TEMP=[];
% clear big temperorary variables
clear genCSVData  t


%% Autocalibrate data
% call autocalibrate function
fprintf('%s Automatic device calibration....\n',string(datetime,"HH:mm:ss.SSS"));
[dataTH.AXES,~,~,cal_status]= AutoCalibrate(dataTH.AXES);
if ~isempty(cal_status)
    warning("Calibration problems: "+cal_status);
end


%% Quality Check & Auto flip/rotation correction

fprintf('%s Auto orientation correction and auto-trimming....\n',string(datetime,"HH:mm:ss.SSS"));
% define NW trimming parameters - set to trim automatically
nwTrimMode=[true,true]; % trim at both start and end

% call QCFlipRotation function
[~,dataTH.AXES,~,statusQC,~] = QCFlipRotation(dataTH.AXES,dataTH.TEMP,diaryStrct(1),devType,Settings,nwTrimMode);
if ~strcmpi(statusQC,"OK")
    warning("Automatic orientation correction and auto-trimming failed: "+statusQC);
end

%% divide data into days and analyse

% find the days of measurement
MesDays=unique(floor(dataTH.AXES(:,1)));
% find start time of data
startTime=dataTH.AXES(1,1);
% find the end time of data
endTime=dataTH.AXES(end,1);

% get days with +-3h overlaps in-order to feed algorithms enough data (with a buffer)
dayStartTimes=max(MesDays-0.125,startTime);
dayEndTimes=min(MesDays+1.125,endTime);

% set the intial reference position to default ref-position
VrefThigh=VrefThighDef;

for itrDay=1:length(MesDays)
    
    fprintf('%s Reference correction & PA and SB classification day %d....\n',string(datetime,"HH:mm:ss.SSS"),itrDay);
    
    % find start/end indices of accelerometer data corresponding to current day
    % Acti4 algorithms expects full seconds of data. Therefore we need to find indices as follows
    dayStartIndx=floor(find(dataTH.AXES(:,1)>= dayStartTimes(itrDay),1,'first')/Fs)*Fs+1;
    dayEndIndx=floor(find(dataTH.AXES(:,1)<= dayEndTimes(itrDay),1,'last')/Fs)*Fs;
    
    %find inclination angles and acceleration data for this day
    [Vthigh,AccFilt,SVM,~] = FindAnglesAndVM(dataTH.AXES(dayStartIndx:dayEndIndx,2:4),Fs,Fc);
    
    % calculate individual ref-position for this day
    VrefThigh = EstimateRefThigh1(dataTH.AXES(dayStartIndx:dayEndIndx,:),Vthigh,VrefThigh,VrefThighDef,Fs,SettingsAkt);
    refPosStr=string(sprintf('def:[%.2f, %.2f]',VrefThigh(2:3)*180/pi));
    
    % warn if ref-position cannot be found
    if isequal(VrefThigh,VrefThighDef)
        warning('Ref.Pos: Day: %d: Not found. Deafult assumed.',itrDay);
    end
    
    % check for VrefThigh limits with known limits and warn if they are out-of-bounds
    if sum((VrefThigh<=VrefThighMax) & (VrefThigh>= VrefThighMin))<2 % at least two angles are ok
        warning('RefencePos: abnormal? [%s] on Day: %d',refPosStr,itrDay);
    end
    
    %call the main activity detection algorithm
    [Akt,Tid,FBthigh,Std2Sec] = ActivityDetect(dataTH.AXES(dayStartIndx:dayEndIndx,2:4),...
        Fs,dataTH.AXES(dayStartIndx:dayEndIndx,1),VrefThigh,SettingsAkt);
    
    % Lying Detection using lying-down algorithm AlgA
    Akt=lyingAlgA(AccFilt,VrefThigh,Akt,Fs);
    
    % after differentiating 'Sit' and 'Lie' we need to median filter once again these two activities
    Akt = AktFilt(Akt,'sit',SettingsAkt);
    Akt = AktFilt(Akt,'lie',SettingsAkt);
    
    % Find non-wear and process night/bed times for thigh accelerometer
    Akt = ProcessNonWearAndBedtime(itrDay==1,Vthigh,dataTH.AXES(dayStartIndx:dayEndIndx,2:4),Fs,Tid,Akt,diaryStrct(1),Settings);
    
    % find stepping frequency for walk/stair/run
    Fstep = findCadenceN(dataTH.AXES(dayStartIndx:dayEndIndx,2:4),Akt,Fs);
    
    %Slow/quiet running correction could be misclassified as walk (24/10-12)
    Akt(Akt==5 & Fstep>2.5) = 6; %Slow/quiet running correction could be misclassified as walk (24/10-12)
    
    % trim the days back to exact 24h (because we had an overlap of +/- 3h per day)
    indsAktDay=find(floor(Tid)==MesDays(itrDay));
    Akt=Akt(indsAktDay);
    Tid=Tid(indsAktDay);
    
    %aggregate activity classification and time vector for this day
    actFull=[actFull,Akt];
    timeFull=[timeFull,Tid];
    
end

%% calculate bedtime and sleep-intervals
fprintf('%s Now calculating times-of-bed and running sleep-algorithm....\n',string(datetime,"HH:mm:ss.SSS"));
% call bedtime and sleep detection function
[statusBdTime,~,~,actFull]=calcBedtime(Settings,subjectIDs(1),diaryStrct(1),timeFull,actFull,dataTH.AXES,Fs,1280,720);
% check for errors in times-of-bed algorithm
if ~strcmpi(statusBdTime,"OK")
    warning("Error calculating times-of-bed and sleep");
end
fprintf('%s Now exporting output to a CSV file....\n',string(datetime,"HH:mm:ss.SSS"));

%% write detected activity time-series to a file
writetable(table(timeFull',actFull','VariableNames',["Time","Activity"]),out_file);
% show elapsed time
toc;
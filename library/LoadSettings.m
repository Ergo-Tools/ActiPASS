function [Settings,SettingsAkt] = LoadSettings(ActiPASSConfig,AktConfig)
%LOADSETTINGS Load settings related to ActiPASS-GUI, Workflow and algorithms

% Input:
%   ActiPASSConfig: full file-path of config file containing GUI, workflow, and Stats module settings
%   AktConfig: full file-path of config file containing main activity detection parameters

% Output:
%   Settings: A structure with loaded UI, workflow, and Statssettings.
%             If empty ActiPASSConfig is given, default settings are returned
%   SettingsAkt: A structure with loaded activity-detection settings.  
%                If empty ActiPASSConfig is given, default settings are returned

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

% check whether the config folder exists, if not create it
[configDir,~,~] = fileparts(ActiPASSConfig);
if configDir~="" && ~isfolder(configDir)
    mkdir(configDir);
end

% if activity config file exists load config data
if isfile(AktConfig)
    SettingsAkt=table2struct(readtable(AktConfig,'FileType','text'));
else
    % otherwise use default settings
    SettingsAkt = struct;
    SettingsAkt.Bout_cycle = 15;
    SettingsAkt.Bout_lie = 5;
    SettingsAkt.Bout_move = 2;
    SettingsAkt.Bout_row = 15;
    SettingsAkt.Bout_run = 2;
    SettingsAkt.Bout_sit = 5;
    SettingsAkt.Bout_stair = 5;
    SettingsAkt.Bout_stand = 2;
    SettingsAkt.Bout_walk = 2;
    SettingsAkt.Threshold_sitstand = 45;
    SettingsAkt.Threshold_staircycle = 40;
    SettingsAkt.Threshold_standmove = 0.1;
    SettingsAkt.Threshold_walkrun = 0.72;
    SettingsAkt.Threshold_slowfastwalk = 100;
    
end


%% check if the main config file exist and load last settings
if isfile(ActiPASSConfig)
    imptOpt=detectImportOptions(ActiPASSConfig,'FileType','text');
    varNamesOrig=string(imptOpt.VariableNames);
    strVarNames=["TRUNKSUFFIX","TRUNKPREFIX","TRUNKPOS","REFPOSTRNK","CALMETHOD","CADALG","LIEALG","SLEEPALG",...
        "IDMODE","TRIMMODE","FLIPROTATIONS","REFPOSTHIGH","BEDTIME","NWCORRECTION","VISUALIZE","CheckSlpInt",...
        "STATDOMAINS","statsIgnoreQC","StatMtchMode","statSlctDays","StatsVldD","WalkMET","FilterTAI","TblFormat",...
        "genBouts","thighAccDir","diary_file","trunkAccDir","out_folder","cal_file"];
    
    varTypesOrig=string(imptOpt.VariableTypes);
    [~,idStrVars,~]=intersect(varNamesOrig,strVarNames);
    varTypesOrig(idStrVars)="string";
    imptOpt.VariableTypes=varTypesOrig;
    Settings=table2struct(readtable(ActiPASSConfig,imptOpt));
else
    % otherwise create an empty Settings structure
    Settings = struct;
end


%% %% main ActiPASS options like file-paths etc

% the flag for Activating ProPASS mode of ActiPASS_GUI
if ~isfield(Settings,'PROPASS')
    Settings.PROPASS=true;
else
    Settings.PROPASS=logical(Settings.PROPASS);
end

% the flag for showing advanced options dialog
if ~isfield(Settings,'ADVOPTIONS')
    Settings.ADVOPTIONS=true;
else
    Settings.ADVOPTIONS=logical(Settings.ADVOPTIONS);
end

% the flag for enabling experimental features
if ~isfield(Settings,'LAB')
    Settings.LAB=false;
else
    Settings.LAB=logical(Settings.LAB);
end

% load file and folder paths (In order to save and load last used files/folders)
if ispc
    if ~isfield(Settings,'thighAccDir') || isnumeric(Settings.thighAccDir),Settings.thighAccDir = getenv('USERPROFILE');end
    if ~isfield(Settings,'trunkAccDir') || isnumeric(Settings.trunkAccDir),Settings.trunkAccDir = getenv('USERPROFILE');end
    if ~isfield(Settings,'diary_file') || isnumeric(Settings.diary_file),Settings.diary_file = getenv('USERPROFILE');end
    if ~isfield(Settings,'cal_file') || isnumeric(Settings.cal_file),Settings.cal_file = fullfile(getenv('USERPROFILE'),'DeviceCal.csv');end
    if ~isfield(Settings,'out_folder') || isnumeric(Settings.out_folder),Settings.out_folder = getenv('USERPROFILE');end
else
    if ~isfield(Settings,'thighAccDir') || isnumeric(Settings.thighAccDir),Settings.thighAccDir = getenv('HOME');end
    if ~isfield(Settings,'trunkAccDir') || isnumeric(Settings.trunkAccDir),Settings.trunkAccDir = getenv('HOME');end
    if ~isfield(Settings,'diary_file') || isnumeric(Settings.diary_file),Settings.diary_file = getenv('HOME');end
    if ~isfield(Settings,'cal_file') || isnumeric(Settings.cal_file),Settings.cal_file = fullfile(getenv('HOME'),'DeviceCal.csv');end
    if ~isfield(Settings,'out_folder') || isnumeric(Settings.out_folder),Settings.out_folder = getenv('HOME');end
end


%% Load ID related settings

% The Subject-ID mode:
if ~isfield(Settings,'IDMODE')|| ismissing( Settings.IDMODE) ||...
        ~matches(Settings.IDMODE,["start","end","activpal","full-filename"])
    Settings.IDMODE="full-filename"; % alternatives start, end, activpal, full-filename default: full-filename
end

% number of ID digits
if ~isfield(Settings,'IDLENGTH')
    Settings.IDLENGTH=5; % the number of numerals denoting the subject-ID in fiename
end


%% Device calibration settings

% the flag for autocalibrating data
if ~isfield(Settings,'CALMETHOD')|| ismissing( Settings.CALMETHOD)||...
        ~matches(Settings.CALMETHOD,["off","auto","file"])
    % alternatives (auto,file,off)
    Settings.CALMETHOD="auto";
end

% the flag for appending autocalibrating data to calibration file
if ~isfield(Settings,'ADDAUTOCAL')
    Settings.ADDAUTOCAL=true;
else
    Settings.ADDAUTOCAL=logical(Settings.ADDAUTOCAL);
end

%% settings related to thigh Acc and Flips/Rots/NWTrim module

% flags for auto flips/rotatins corrections
if ~isfield(Settings,'FLIPROTATIONS')|| ismissing( Settings.FLIPROTATIONS)||...
        ~matches(Settings.FLIPROTATIONS,["warn","force"])
    Settings.FLIPROTATIONS="force";  % alternatives: 'warn', 'force'
end

% flags for Rotated' orientation, only used when FLIPROTATIONS=false
if ~isfield(Settings,'Rotated')
    Settings.Rotated=false;
else
    Settings.Rotated=logical(Settings.Rotated);
end

% flags for Flipped' orientation, only used when FLIPROTATIONS=false
if ~isfield(Settings,'Flipped')
    Settings.Flipped=false;
else
    Settings.Flipped=logical(Settings.Flipped);
end

% flags for reference position finding method
if ~isfield(Settings,'REFPOSTHIGH')|| ismissing( Settings.REFPOSTHIGH)||...
        ~matches(Settings.REFPOSTHIGH,["default","auto1","auto2","diary"])
    Settings.REFPOSTHIGH="auto1";  % alternatives: 'auto1', 'auto2', 'diary', 'default'
end

%% Load NW related settings

% flags for automatic cropping NW at begining or end
if ~isfield(Settings,'TRIMMODE')|| ismissing(Settings.TRIMMODE)||...
        ~matches(Settings.TRIMMODE,["off","force","nodiary"])
    Settings.TRIMMODE="nodiary";  % alternatives: 'force', 'nodiary', 'off'
end

% min length of short NW periods within active periods to ignore in hrs
if ~isfield(Settings,'NWSHORTLIM')
    Settings.NWSHORTLIM=3;
end

% The buffer around NW cropping (used in Flips/Rots/NWTrim module)
if ~isfield(Settings,'NWTRIMBUF')
    Settings.NWTRIMBUF=1;
end

% min length of Active consecutive active period to consider for processing in hrs
if ~isfield(Settings,'NWTRIMACTLIM')
    Settings.NWTRIMACTLIM=48; % the number of numerals denoting the subject-ID in fiename
end

% NW correction using bedtime based on lying
if ~isfield(Settings,'NWCORRECTION')|| ismissing(Settings.NWCORRECTION) ||...
        ~matches(Settings.NWCORRECTION,["lying","fixed"])% alternatives (fixed,lying)
    Settings.NWCORRECTION="lying";
end


%% Load cadence, lying, bedtime and sleep related settings

% the flag for cadence detection algorithm
if ~isfield(Settings,'CADALG')|| ismissing(Settings.CADALG) ||...
        ~matches(Settings.CADALG,["FFT","Wavelet1","Wavelet2"])
    Settings.CADALG="FFT";% alternatives ("FFT","Wavelet1","Wavelet2")
end

% different lying algorithms to find lying periods
if ~isfield(Settings,'LIEALG')|| ismissing( Settings.LIEALG)||...
        ~matches(Settings.LIEALG,["off","auto","diary","algA","algB","trunk"])
    Settings.LIEALG="auto"; % alternatives: 'off', 'diary', 'auto','algA', 'algB', 'trunk',
end

% The sleep algorithm: currently only Skotte
if ~isfield(Settings,'SLEEPALG')|| ismissing(Settings.SLEEPALG) ||...
        ~matches(Settings.SLEEPALG,["off","In-Bed","InOut-Bed","diary"])
    Settings.SLEEPALG="In-Bed"; % alternatives: "off","In-Bed","InOut-Bed","diary"
end

% enable or disable considering no-sleep-interval  flag for final QC_Status'
if ~isfield(Settings,'CheckSlpInt')|| ismissing( Settings.CheckSlpInt)||...
        ~matches(Settings.CheckSlpInt,["on","off"])
    Settings.CheckSlpInt="on";   % alternatives 'on', 'off'
end

% the flag for bedtime algorithm
if ~isfield(Settings,'BEDTIME')|| ismissing(Settings.BEDTIME) ||...
        ~matches(Settings.BEDTIME,["off","auto1","auto2","diary"])
    Settings.BEDTIME="auto2";% alternatives ("off","auto1","auto2","diary")
end

% bedtime algorithm max-active-time threshold
if ~isfield(Settings,'BDMAXAKTT') || (Settings.BDMAXAKTT<1 || Settings.BDMAXAKTT>60)
    Settings.BDMAXAKTT=20; % bedtime algorithm max-active-time threshold
end

% bedtime algorithm min-Lie-time threshold
if ~isfield(Settings,'BDMINLIET') || (Settings.BDMINLIET<60|| Settings.BDMINLIET>720)
    Settings.BDMINLIET=180; %bedtime algorithm minimum-lying-time threshold
end

% bedtime algorithm very-long-sit threshold
if ~isfield(Settings,'BDVLONGSIT') || (Settings.BDVLONGSIT<120|| Settings.BDVLONGSIT>720)
    Settings.BDVLONGSIT=240; %bedtime algorithm minimum-lying-time threshold
end

% the flag for saving the 1Hz activity and steps data
if ~isfield(Settings,'EXTERNFUN')
    Settings.EXTERNFUN=false;
else
    Settings.EXTERNFUN=logical(Settings.EXTERNFUN);
end


%% load settings related to trunk accelerometer
% The trunk accelerometer position  and also enable it
if ~isfield(Settings,'TRUNKPOS')|| ismissing( Settings.TRUNKPOS)||...
        ~any(strcmpi(["off","back","front"],Settings.TRUNKPOS))
    % alternatives (off,back,front)
    Settings.TRUNKPOS="off";
end


% The trunk accelerometer filename suffix:
if ~isfield(Settings,'TRUNKSUFFIX') || ismissing(Settings.TRUNKSUFFIX)
    Settings.TRUNKSUFFIX="";
end

% flag for flipped (inside-out) orientation
if ~isfield(Settings,'TRUNKFLIP')
    Settings.TRUNKFLIP=false; %default false
else
    Settings.TRUNKFLIP=logical(Settings.TRUNKFLIP);
end

% flag for rotated (upside-down) orientation
if ~isfield(Settings,'TRUNKROT')
    Settings.TRUNKROT=false; %default false
else
    Settings.TRUNKROT=logical(Settings.TRUNKROT);
end

% flag for force-synchronization with thigh
if ~isfield(Settings,'FORCESYNC')
    Settings.FORCESYNC=true;
else
    Settings.FORCESYNC=logical(Settings.FORCESYNC);
end

% The trunk accelerometer filename prefix:
if ~isfield(Settings,'TRUNKPREFIX')|| ismissing( Settings.TRUNKPREFIX)
    Settings.TRUNKPREFIX="";
end

% Keep the trunk accelerometer NW as NW in the final result:
if ~isfield(Settings,'KEEPTRUNKNW')
    Settings.KEEPTRUNKNW=true;
else
    Settings.KEEPTRUNKNW=logical(Settings.KEEPTRUNKNW);
end

% flags for reference position finding method
if ~isfield(Settings,'REFPOSTRNK')|| ismissing( Settings.REFPOSTRNK)||...
        ~matches(Settings.REFPOSTRNK,["default","auto1","diary"])
    Settings.REFPOSTRNK="auto1";  % alternatives: 'auto1', 'diary', 'default'
end

% save trunk angle data for further processing
if ~isfield(Settings,'SAVETRNKD')
    Settings.SAVETRNKD=false;
else
    Settings.SAVETRNKD=logical(Settings.SAVETRNKD);
end

% attempt trunk orientation correction
if ~isfield(Settings,'FLIPROTTRNK')
    Settings.FLIPROTTRNK=false;
else
    Settings.FLIPROTTRNK=logical(Settings.FLIPROTTRNK);
end

%% load settings related to stage1 outputs and visualizations

% the flag for saving the 1Hz activity and steps data
if ~isfield(Settings,'SAVE1SDATA')
    Settings.SAVE1SDATA=true;
else
    Settings.SAVE1SDATA=logical(Settings.SAVE1SDATA);
end

% flag for visualization option
if ~isfield(Settings,'VISUALIZE')|| ismissing(Settings.VISUALIZE)||...
        ~matches(Settings.VISUALIZE,["off","full","QC","extra"])
    Settings.VISUALIZE="QC";
end

% the histogram bin size
if ~isfield(Settings,'histgStep')
    Settings.histgStep=60; % bin size for activity histogram in minutes
end

% minimum valid duration to consider day for histogram inclusion
if ~isfield(Settings,'histgMinDur')
    Settings.histgMinDur=22; % minimum duration of day to be included in histograms given in hrs
end

% flag for Pie Charts
if ~isfield(Settings,'PIECHARTS')
    Settings.PIECHARTS=true;
else
    Settings.PIECHARTS=logical(Settings.PIECHARTS);
end
% flag for Diary comments
if ~isfield(Settings,'PRINTCOMMNTS')
    Settings.PRINTCOMMNTS=true;
else
    Settings.PRINTCOMMNTS=logical(Settings.PRINTCOMMNTS);
end


%% Settings related to outlier detection and stage3 stats generation


% ignoring bad or problematic files in stats gen module
if ~isfield(Settings,'statsIgnoreQC') || ismissing(Settings.statsIgnoreQC) || isnumeric(Settings.statsIgnoreQC) || ...
       ~matches(Settings.statsIgnoreQC,["NotOK","NotOK+Check","None"])
    Settings.statsIgnoreQC="NotOK";
end

% The domains for stat generation (compared against diary events):
if ~isfield(Settings,'STATDOMAINS') || ismissing(Settings.STATDOMAINS)
    Settings.STATDOMAINS=""; % default: "", examples: 'Work Leisure'
end


% how stat domains are compared with diary events 
if ~isfield(Settings,'StatMtchMode')|| ismissing( Settings.StatMtchMode)||...
        ~matches(Settings.StatMtchMode,["Inclusive","Strict"])
    Settings.StatMtchMode="Inclusive";   % alternatives ('inclusive' or 'strict')
end

% for stat-domain calculations, treat diary bedtime as leisure
if ~isfield(Settings,'DBedAsLeis')
    Settings.DBedAsLeis=true;
else
    Settings.DBedAsLeis=logical(Settings.DBedAsLeis);
end

% valid-day threshold
if ~isfield(Settings,'minValidDur')
    Settings.minValidDur=20;
end
% number of days to generate stats
if ~isfield(Settings,'statNumDays')
    Settings.statNumDays=7;
end
% how valid days are found when more measurement days than statNumDays present
if ~isfield(Settings,'statSlctDays') || ismissing( Settings.statSlctDays) || ...
        ~matches(Settings.statSlctDays,["first valid days", "pick window: optimal work/leisure",...
        "pick days: optimal work/leisure"])
    % alternatives: 'first valid days', 'pick valid work/leisure days, no gaps','pick valid work/leisure days, allow gaps'
    Settings.statSlctDays="first valid days";   

end

% criteria for daily validity
if ~isfield(Settings,"StatsVldD") || ismissing( Settings.StatsVldD) || ~matches(Settings.StatsVldD,["ProPASS", "only wear-time"])
    % alternatives: 'ProPASS', 'only wear-time'
    Settings.StatsVldD="ProPASS";   
end

% minimum walking seconds before flagging as no-walking
if ~isfield(Settings,'minWlkDur')
    Settings.minWlkDur=30;
end
% maximum 'other' minutes allowed before flagging
if ~isfield(Settings,'maxOtherDur')
    Settings.maxOtherDur=30;
end
% max stair walking minutes per day before flagging
if ~isfield(Settings,'maxStairDur')
    Settings.maxStairDur=120;
end


% enable or disable bouts generation'
if ~isfield(Settings,'genBouts')|| ismissing( Settings.genBouts)||...
        ~matches(Settings.genBouts,["on","off"])
    Settings.genBouts="off";   % alternatives 'on', 'off'
end
% bout threshold value
if ~isfield(Settings,'boutThresh')
    Settings.boutThresh=0; % default is 0 which disables the bout-threshold.
end
% bout break for all bouts except 1 min bout in seconds
if ~isfield(Settings,'boutBreak')
    Settings.boutBreak=20;
end

% how to calculate MET values for walking- fixed cutoffs or cadence based regression? default - 'fixed'
if ~isfield(Settings,'WalkMET')|| ismissing( Settings.WalkMET)||...
        ~matches(Settings.WalkMET,["fixed","regression"])
    Settings.WalkMET="fixed";   % alternatives 'fixed', 'regression', default - 'fixed'
end


% flag to calculate cadence per minute instead of per second (before slow/fast walking detection and INT classes)
if ~isfield(Settings,'CADPMIN')
    Settings.CADPMIN=false;
else
    Settings.CADPMIN=logical(Settings.CADPMIN);
end

% load exponential smoothing on TAI options
if ~isfield(Settings,'FilterTAI')|| ismissing( Settings.FilterTAI)||...
        ~matches(Settings.FilterTAI,["off","TC10","TC20","TC30","TC60","TC90","TC120"])
    Settings.FilterTAI="off";  % apply exponential smoothing on TAI options 'off', 'TC10',"TC20","TC30","TC60","TC90","TC120" - default off
end

% load stat-generation table format options
if ~isfield(Settings,'TblFormat')|| ismissing( Settings.TblFormat) || ...
        ~matches(Settings.TblFormat,["Daily","Events","EventsNoBreak","Daily+Events"])
    % output table format of stat generation - default- Horizontal
    Settings.TblFormat="Daily";  
end



end


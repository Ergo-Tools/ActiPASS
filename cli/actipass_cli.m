function exitcode = actipass_cli(acc_file,options)
% actipass_cli simple CLI version of ActiPASS for quick activity classification
%
% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (c) 2021-2025 Pasan Hettiarachchi and Peter Johansson

% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
% 
% This **ActiPASS_CLI** in `/cli/` is licensed under the
% GNU General Public License, version 3.0 or (at your option) any later version.
% See `../LICENSES/GPL-3.0-or-later.txt` for more details.


% Required toolboxes:
% 'Signal Processing Toolbox'
% 'Image Processing Toolbox'
% 'Statistics and Machine Learning Toolbox'

% Required files (make sure these are in Matlab path)

% "actipass_cli.m"
% "ActivityDetect.m"
% "AktFilt.m"
% "AutoCalibrate.m"
% "brewermap.m"
% "calcBedLgc.m"
% "calcBedtime.m"
% "ChangeAxes.m"
% "checkActivPALFile.m"
% "cli_add_to_sendto.m"
% "cli_diary_events.m"
% "cli_visualize.m"
% "cli_weekly_plots.m"
% "CWA_readFile.m" 
% "EstimateRefThigh1.m"
% "FindAnglesAndVM.m"
% "findCadenceN.m"
% "getInstalledExePath.m"
% "LoadSettings.m"
% "lyingAlgA.m"
% "lyingAlgB.m"
% "NotWorn.m"
% "NotWornQC.m"
% "open_diary.m"
% "parseDate.mexw64"
% "parseValueBlock.mexw64"
% "ProcessNonWearAndBedtime.m"
% "QCFlipRotation.m"
% "readActGT3xcsv.m"
% "readActi4.m"
% "readActivPAL.m"
% "readActivPALcsv.m"
% "readGenericCSV.m"
% "readMovisensBin.m"
% "readSENSBin.m"
% "readWAVtoACC.m"
% "rgb.m"
% "rle.m"
% "SkottesSlp.m"
% "WarmNightT.m"


% define arguments types and default values
arguments
    acc_file (1,1) string = ""
    options.out (1,1) string = ""
    options.ID (1,1) string = ""
    options.diary (1,1) string = ""
    options.daily (1,1) string = "on"
    options.vis (1,1) string = "on"
    options.mode (1,1) string = "PROPASS"
    options.loc {mustBeMember(options.loc,["front","right","left"])} = "front"
end

%% intialize actipass_cli
version="2025.12.1"; % actipass_cli version string
exitcode=0; % set exit code to zero

% define ProPASS or Advanced mode
% depending on the mode of operation, workflow can be customized
opmode=options.mode;

% asign the optional arguments
out_file=options.out;
diary_file=options.diary;

% print Version to console
fprintf("ActiPASS CLI version: "+version+newline);

% find executable path when deployed
if isdeployed
    exe_path = getInstalledExePath;
end

%find script path
script_path=fileparts(mfilename('fullpath'));

if acc_file=="" % no arguments: display Usage.txt
    usageTxt=fileread(fullfile(script_path,"Usage_CLI.txt"));
    disp(usageTxt);
    if isdeployed
        cli_add_to_sendto(exe_path);
        pause(10);
    end
    return;
elseif acc_file=="--help" % display ReadMe.txt
    readmeTxt=fileread(fullfile(script_path,"ReadMe_CLI.txt"));
    disp(readmeTxt);
    return;
elseif acc_file=="--add-to-sendto" % add actipass_cli to Windows SendTo folder as shortcut
    if isdeployed
        cli_add_to_sendto(exe_path);
    else
        warning("Works only if deployed as an EXE.");
    end
    return;
elseif ~isfile(acc_file)
    warning("Accelerometer file does not exist: "+acc_file);
    exitcode=exitcode+300;
    fprintf("Return code: "+exitcode);
    pause(5);
    return;
end

% find filename and extension of given input file
[fpath,fname,fext]=fileparts(acc_file);

% give the subject-ID same as filename
if options.ID==""
    subjectID=string(fname); % should be a  vector of strings. See open_accfiles.m
else
    subjectID=options.ID;
end


% find file extension of output file
[outDir,outName,outext]=fileparts(out_file);
%check and do corrections to out_file
if outext~="" && ~matches(outext,[".csv",".mat",".xlsx"]) && isfolder(outDir)
    warning("Unsupported output file-format. 1s data will be saved in MATLAB format");
    out_file=fullfile(outDir,outName+"_actipass_1s.mat");
    outext=".mat";
elseif outext~="" && matches(outext,[".csv",".mat",".xlsx"]) && ~isfolder(outDir)
    exitcode=exitcode+400;
    warning("Invalid output file-path: "+out_file);
    fprintf("Return code: "+exitcode);
    return;
elseif outext~="" && matches(outext,[".csv",".mat",".xlsx"]) && isfolder(outDir)
elseif outext=="" && out_file~="" && isfolder(out_file)
    outDir=out_file; % set the output directory for other files
    out_file=fullfile(outDir,subjectID+"_actipass_1s.mat");
    outext=".mat";
elseif outext=="" && out_file~="" && ~isfolder(out_file)
    exitcode=exitcode+500;
    warning("Invalid output file-path: "+out_file);
    fprintf("Return code: "+exitcode);
    return;
elseif outext=="" && out_file==""
    outDir=fpath; % set the output directory for other files to the acc-file directory
end

tic; % start a timer
fprintf('%s Intializing ....\n',string(datetime,"HH:mm:ss.SSS"));


actvtTxts=["NW","Lie","Sit","Stand", "Move", "Walk", "Run","Stair", "Cycle","Other","SlpIBD","LieStill"];
% variable names of per/sec output table
varn_1S=["DateTime","Activity","Steps","SVM","Event","TimeInBed","SleepInterval"];


%define location of configuration and license files
appDDir=fullfile(getenv('APPDATA'),'ActiPASS');
ParamsConfig=fullfile(appDDir,'AktDetect_UI.conf');
ActiPASSConfig=fullfile(appDDir,'ActiPASS_UI.conf');


% empty vectors to hold the activity  classification of each second
actFull=[];
timeFull=[];
stepsFull=[];
svmFull=[];

try
     
    %% load settings
    % use ActiPASS GUI to change settings
    if matches(opmode,["CLI","ADVANCED"],"IgnoreCase",true)
        % if Advanced or CLI mode license found load settings and parameters from config files
        [Settings,ParamsAP] = LoadSettings(ActiPASSConfig,ParamsConfig);
        fprintf('%s %s mode. Settings and parameters are loaded from config files.\n',string(datetime,"HH:mm:ss.SSS"),opmode);
    elseif matches(opmode,"PROPASS","IgnoreCase",true)
        % if ProPASS mode load default settings and parameters
        [Settings,ParamsAP] = LoadSettings("","");
        fprintf('%s ProPASS mode. Default settings and parameters loaded.\n',string(datetime,"HH:mm:ss.SSS"));
    end
    % force visualization level to QC only (no bedtime figures)
    Settings.VISUALIZE="QC"; 

    % define important parameters not loaded from config files
    Fs=ParamsAP.Fs; % The resample frequency for raw accelerometer data
    Fc=ParamsAP.Fc; % the cutoff frequency for angle and vector-magnitude finding (primary filter)

    % reference position values min, max and defaults
    VrefThighMin = (pi/180)*ParamsAP.VrefThighMin;
    VrefThighMax = (pi/180)*ParamsAP.VrefThighMax;
    VrefThighDef = (pi/180)*ParamsAP.VrefThighDef;

    fprintf('%s Loaded settings ....\n',string(datetime,"HH:mm:ss.SSS"));
    
    %% depending on the extension define 'ftype'
    
    if strcmpi(fext,".cwa")
        ftype=1;
        devType="Axivity";
    elseif strcmpi(fext,".wav")
        ftype=2;
        devType="Axivity";
    elseif strcmpi(fext,".dat") || strcmpi(fext,".datx")
        ftype=3;
        devType="ActivPAL";
    elseif strcmpi(fext,".csv")
        fidTmp=fopen(acc_file,'r');
        headLines=fgetl(fidTmp);
        fclose(fidTmp);
        if contains(headLines,"ActiGraph",'IgnoreCase',true)
            ftype=5;
            devType="ActiGraph";
        elseif startsWith(headLines,"sep=;",'IgnoreCase',true)
            ftype=4;
            devType="ActivPAL";
        elseif startsWith(headLines,"ID=",'IgnoreCase',true)
            ftype=7;
            devType="Generic";
        else
            warning("Unknown CSV file-type: "+acc_file);
            exitcode=exitcode+200;
            fprintf("Return code: "+exitcode);
            pause(5);
            return;
        end
    elseif strcmpi(fext,".npy")
        ftype=4;
        devType="ActivPAL";
    elseif strcmpi(fext,".bin") || strcmpi(fext,".hex")
        ftype=6;
        devType="SENS";
    elseif strcmpi(fext,".act4")
        ftype=8;
        devType="Acti4";
    elseif strcmpi(fext,".xml")
        ftype=9;
        devType="Movisens";
    else
        warning("Unknown accelerometer file-type: "+acc_file);
        exitcode=exitcode+100;
        fprintf("Return code: "+exitcode);
        pause(5);
        return;
    end
    
    % also add ftype to ParamsAP struct
    ParamsAP.ftype=ftype;
    %% load or skip optional diary data
    % we skip loading a diary
    if diary_file==""
        [d_status,diaryStrct] = open_diary(diary_file,subjectID,0); % call open_diary function with no-diary option
        fprintf('%s %s ...\n',string(datetime,"HH:mm:ss.SSS"),d_status);
    elseif ~isfile(diary_file)
        warning("Diary file not found: "+diary_file);
        exitcode=exitcode+10000000;
        [d_status,diaryStrct] = open_diary(diary_file,subjectID,0); % call open_diary function with no-diary option
        fprintf('%s %s ...\n',string(datetime,"HH:mm:ss.SSS"),d_status);
    elseif isfile(diary_file)
        [d_status,diaryStrct] = open_diary(diary_file,subjectID,2); % call open_diary function with predefined diary file
        fprintf('%s %s ...\n',string(datetime,"HH:mm:ss.SSS"),d_status);
        if ~startsWith(d_status,"Diary:")
            exitcode=exitcode+20000000;
        end
    end
    
    %% load  accelerometer data
    if ftype==1
        % loading Axivity CWA file
        fprintf('%s Axivity CWA file loading ....\n',string(datetime,"HH:mm:ss.SSS"));
        cwaData = CWA_readFile(acc_file, 'useC', 1);
        cwaData.ACC = cwaData.AXES(diff(cwaData.ACC(:,1))>0,:);
        AccData=cwaData.ACC;
        AccData(:,3:4)=-AccData(:,3:4); % correction to y and z  axes
    elseif ftype==2
        % loading Axivity WAV file
        fprintf('%s Axivity WAV file loading ....\n',string(datetime,"HH:mm:ss.SSS"));
        cwaData = readWAVtoACC(acc_file,'data');
        cwaData.ACC = cwaData.AXES(diff(cwaData.ACC(:,1))>0,:);
        AccData=cwaData.ACC;
        AccData(:,3:4)=-AccData(:,3:4); % correction to y and z  axes
    elseif ftype==7
        % loading generic CSV file
        fprintf('%s Generic CSV file loading ....\n',string(datetime,"HH:mm:ss.SSS"));
        AccData=readGenericCSV(acc_file);
        AccData(:,3:4)=-AccData(:,3:4); % correction to y and z  axes
    elseif ftype==4
        % loading ActivPAL 3/4 CSV file
        fprintf('%s ActivPAL CSV file loading ....\n',string(datetime,"HH:mm:ss.SSS"));
        AccData = readActivPALcsv(acc_file);
    elseif ftype==5
        % loading ActiGraph GT3x CSV file
        fprintf('%s ActiGraph CSV file loading ....\n',string(datetime,"HH:mm:ss.SSS"));
        AccData=readActGT3xcsv(acc_file);
    elseif ftype==3
        % loading ActivPAL 3 DATX file
        fprintf('%s ActivPAL 3 DATX file loading ....\n',string(datetime,"HH:mm:ss.SSS"));
        AP_data=readActivPAL(char(acc_file));
        AccData=[datenum(AP_data.signals.dateTime),AP_data.signals{:,2:4}];
    elseif ftype==6
        % loading SENS Motion bin/hex file
        fprintf('%s SENS Motion bin/hex file loading ....\n',string(datetime,"HH:mm:ss.SSS"));
        AccData=readSENSBin(acc_file);
    elseif ftype==8
        % loading Acti4 converted file
        fprintf('%s Acti4 binary file loading ....\n',string(datetime,"HH:mm:ss.SSS"));
        AccData=readActi4(acc_file);
    elseif ftype==9
        % loading Movisens binary file
        fprintf('%s Movisens binary file loading ....\n',string(datetime,"HH:mm:ss.SSS"));
        AccData=readMovisensBin(acc_file);
        AccData(:,2:3)=[AccData(:,3),-AccData(:,2)]; % correction to y and x  axes
    end
    
    % correction to raw data depending on sensor-location
    
    if options.loc=="front"
        % if loc is front, device is worn on the front of thigh and no change needed
    elseif options.loc=="right"
        % if loc right, device is worn on the outside of right-thigh
        AccData(:,3:4)=[-AccData(:,4),AccData(:,3)]; % negative z-axis becomes front mounted y-axis and y-axis becomes front mounted z-axis
    elseif options.loc=="left"
        % if loc left, device is worn on the outside of left-thigh
        AccData(:,3:4)=[AccData(:,4),-AccData(:,3)];  % z-axis becomes front mounted y-axis and negative y-axis becomes front mounted z-axis
    end
    
    % interpolate Acc. data at evenly spaced samples
    fprintf('%s Data interpolating at %d Hz ....\n',string(datetime,"HH:mm:ss.SSS"),Fs);
    
    % find diary defined start and end times if exists
    dStart=datenum(diaryStrct.StartT);
    dEnd=datenum(diaryStrct.StopT);
    % if 'Start' exist (may be multiple) and falls within raw data
    okStarts=dStart < AccData(end,1) & dStart > AccData(1,1);
    % if a 'Stop' exist (may be multiple) and falls within raw data
    okStops=dEnd < AccData(end,1) & dEnd > AccData(1,1);
    
    dStart=dStart(find(okStarts,1,'first')); % first pick a valid diary start time
    if ~isempty(dStart)
        % pick the first valid diary end time which is larger than selected diary start time
        dEnd=dEnd(find(okStops & dEnd>dStart,1,'first'));
    else
        % pick the first valid diary end time
        dEnd=dEnd(find(okStops,1,'first')); % pick the first valid diary end time
    end
    
    % fix start and end to interger seconds. Chosse between diary start or accelerometer start times
    % This  is because main activity detection algorithm expects it
    if ~isempty(dStart)
        mtStart = round(dStart*86400)/86400;
    else
        mtStart = round(AccData(1,1)*86400)/86400;
    end
    
    if ~isempty(dEnd)
        mtEnd = round(dEnd*86400)/86400;
    else
        mtEnd = round(AccData(end,1)*86400)/86400;
    end
    
    % create evenly spaced time axis at given samplerate
    t = linspace(mtStart,mtEnd,(mtEnd-mtStart)*86400*Fs+1)';
    
    % preaalocate a 4-column vector to hold interpolated acc data
    Dintp=zeros(length(t),4);
    Dintp(:,1)=t;
    
    % interpolate accelerometer data with equi-distance samples at (with start and end times fixed to whole seconds)
    Dintp(:,2:4) = interp1(AccData(:,1),AccData(:,2:4),t,'pchip',0); % cubic interpolation at given sample points
        
    %time and accelrometer data
    dataTH.AXES=Dintp;
    % empty temperature vector
    dataTH.TEMP=[];
    % clear big temperorary variables
    clear AccData  t
    
    
    %% Autocalibrate data
    % call autocalibrate function
    fprintf('%s Automatic device calibration ....\n',string(datetime,"HH:mm:ss.SSS"));
    [dataTH.AXES,~,~,cal_status]= AutoCalibrate(dataTH.AXES);
    if ~isempty(cal_status)
        warning("Calibration problems: "+cal_status);
        exitcode=exitcode+1000;
    end
    
    %% Quality Check & Auto flip/rotation correction
    
    fprintf('%s Auto orientation correction and auto-trimming ....\n',string(datetime,"HH:mm:ss.SSS"));
    
    % define the correct NW trimming parameters depending on settings and diary Start/Stop existence
    if strcmpi(Settings.TRIMMODE,"force")
        nwTrimMode=[true,true];
    elseif strcmpi(Settings.TRIMMODE,"nodiary")
        nwTrimMode(1)=isempty(dStart);
        nwTrimMode(2)=isempty(dEnd);
    elseif strcmpi(Settings.TRIMMODE,"off")
        nwTrimMode=[false,false];
    else
        nwTrimMode=[false,false];
    end
    
    % call QCFlipRotation function
    [QCData,dataTH.AXES,~,statusQC,~] = QCFlipRotation(dataTH.AXES,dataTH.TEMP,diaryStrct(1),devType,Settings,nwTrimMode);
    if ~strcmpi(statusQC,"OK")
        warning("Automatic orientation correction and auto-trimming failed: "+statusQC);
        exitcode=exitcode+10000;
        fprintf("Return code: "+exitcode);
        return;
    end
    % display QC data in console
    fprintf('\t Total_T=%.2fh, Worn_T=%.2fh \n\t Trim_start=%.2fh, Trim_end=%.2fh \n\t Rot_T=%.2fh, Flip_T=%.2fh\n\n',...
        QCData.TotTime/3600,QCData.WornTime/3600,QCData.cropStart,QCData.cropEnd,QCData.RotTime/3600,QCData.FlipTime/3600);
    
    
    %% divide data into days and analyse
    
    % find the days of measurement
    MesDays=unique(floor(dataTH.AXES(:,1)));
    % find start time of data
    startTime=dataTH.AXES(1,1);
    % find the end time of data
    endTime=dataTH.AXES(end,1);
    
    % get days with +-3h overlaps in-order to feed algorithms enough data (with an overlapping buffer)
    dayStartTimes=max(MesDays-0.125,startTime);
    dayEndTimes=min(MesDays+1.125,endTime);
    
    % set the intial reference position to default ref-position
    VrefThigh=VrefThighDef;
    % reference position and method as a string (including trunk if used)
    refPosStr=strings(length(MesDays),1);
    
    for itrDay=1:length(MesDays)
        
        fprintf('%s Auto reference-position & PA/SB classification day %d ....\n',string(datetime,"HH:mm:ss.SSS"),itrDay);
        
        % find start/end indices of accelerometer data corresponding to current day
        % Acti4 algorithms expects full seconds of data. Therefore we need to find indices as follows
        dayStartIndx=floor(find(dataTH.AXES(:,1)>= dayStartTimes(itrDay),1,'first')/Fs)*Fs+1;
        dayEndIndx=floor(find(dataTH.AXES(:,1)<= dayEndTimes(itrDay),1,'last')/Fs)*Fs;
        
        %find inclination angles and acceleration data for this day
        [Vthigh,AccFilt,SVM] = FindAnglesAndVM(dataTH.AXES(dayStartIndx:dayEndIndx,2:4),Fs,Fc);
        
        % calculate individual ref-position for this day
        VrefThigh = EstimateRefThigh1(dataTH.AXES(dayStartIndx:dayEndIndx,:),Vthigh,VrefThigh,VrefThighDef,Fs,ParamsAP);
        
        
        % warn if ref-position cannot be found (in the GUI version EstimateRefThigh2 can be used as fallback, but not in this version)
        if isequal(VrefThigh,VrefThighDef)
            refPosStr(itrDay)=string(sprintf('def:[%.2f, %.2f]',VrefThigh(2:3)*180/pi));
            warning('Ref.Pos: Day: %d: Not found. Deafult assumed.',itrDay);
            exitcode=exitcode+100000;
        else
            refPosStr(itrDay)=string(sprintf('a1:[%.2f, %.2f]',VrefThigh(2:3)*180/pi));
        end
        
        % check for VrefThigh limits with known limits and warn if they are out-of-bounds
        if sum((VrefThigh<=VrefThighMax) & (VrefThigh>= VrefThighMin))<2 % at least two angles are ok
            warning('RefencePos: abnormal? [%s] on Day: %d',refPosStr(itrDay),itrDay);
            exitcode=exitcode+100000;
        end
        
        %call the main activity detection algorithm
        [Akt,Tid,~,Std2Sec] = ActivityDetect(dataTH.AXES(dayStartIndx:dayEndIndx,2:4),...
            Fs,dataTH.AXES(dayStartIndx:dayEndIndx,1),VrefThigh,ParamsAP);
        
        if  matches(Settings.LIEALG,["auto","algB","algA"],'IgnoreCase',true)
            % Lying Detection using lying-down algorithm AlgA or AlgB
            if  strcmpi(Settings.LIEALG,'auto')
                if ftype ==3 || ftype ==4 || ftype ==5
                    Akt=lyingAlgA(AccFilt,VrefThigh,Akt,Fs);
                else
                    Akt=lyingAlgB(AccFilt,max(Std2Sec,[],2),VrefThigh,Akt,Fs);
                end
            elseif strcmpi(Settings.LIEALG,'algB')
                Akt=lyingAlgB(AccFilt,max(Std2Sec,[],2),VrefThigh,Akt,Fs);
            elseif  strcmpi(Settings.LIEALG,'algA')
                Akt=lyingAlgA(AccFilt,VrefThigh,Akt,Fs);
            end
            
            % after differentiating 'Sit' and 'Lie' we need to median filter once again these two activities
            Akt = AktFilt(Akt,'sit',ParamsAP);
            Akt = AktFilt(Akt,'lie',ParamsAP);
        end
        % Find non-wear and process night/bed times for thigh accelerometer
        Akt = ProcessNonWearAndBedtime(itrDay==1,Vthigh,dataTH.AXES(dayStartIndx:dayEndIndx,2:4),Fs,Tid,Akt,diaryStrct(1),Settings);
        
        % find stepping frequency for walk/stair/run
        Fstep = findCadenceN(dataTH.AXES(dayStartIndx:dayEndIndx,2:4),Akt,Fs);
        
        %Slow/quiet running correction could be misclassified as walk (24/10-12)
        Akt(Akt==5 & Fstep>2.5) = 6; %Slow/quiet running correction could be misclassified as walk (24/10-12)
        
        % find the indices of exact 24h (because we had an overlap of +/- 3h per day)
        indsAktDay=find(floor(Tid)==MesDays(itrDay));
        
        %aggregate activity classification and time vector for this day
        actFull=[actFull,Akt(indsAktDay)];
        timeFull=[timeFull,Tid(indsAktDay)];
        stepsFull=[stepsFull,Fstep(indsAktDay)];
        % filtered vector magnitude (moving mean at 2s)
        SVM=movmean(SVM,2*Fs); %filter SVM find the moving mean at a 2s time window
        % find the start-index of original AXES (without buffer)
        dayStrtIndx00h=floor(find(dataTH.AXES(:,1)>= Tid(indsAktDay(1)),1,'first')/Fs)*Fs+1;
        svmFull=[svmFull;SVM(dayStrtIndx00h-dayStartIndx+(1:Fs:Fs*length(indsAktDay)))];
    end
    
    %% calculate bedtime and sleep-intervals
    if matches(Settings.BEDTIME,["diary","auto1","auto2"],"IgnoreCase",true)
        fprintf('%s Now calculating times-of-bed and running sleep-algorithm ....\n',string(datetime,"HH:mm:ss.SSS"));
        % call bedtime and sleep detection function
        [statusBdTime,~,~,actFull,BD_full,SI_full]=calcBedtime(Settings,subjectID,diaryStrct(1),timeFull,actFull,dataTH.AXES,Fs,1280,720);
        % check for errors in times-of-bed algorithm
        if ~strcmpi(statusBdTime,"OK")
            warning("Error calculating times-of-bed and sleep:"+newline+statusBdTime);
            exitcode=exitcode+1000000;
        end
    end
    
    
    %% analysing each day again for diary integration and outlier and misclassification detection
    fprintf('%s Preparing for exports and oulier/misclassification detection ....\n',string(datetime,"HH:mm:ss.SSS"));
    
    noWlkProblem=false(size(MesDays));
    NoSleepProblem=false(size(MesDays));
    %initialise eventsVis structure
    eventsVis=struct('start',{},'stop',{},'Event',{},'Comment',{},'Ref',{});
    % structure to hold all event information (to be used later in stat module and trunk data processing)
    evntMeta=struct('Names',[],'StartTs',[],'EndTs',[],'Comments',[],'Indices',[]);
    % find problematic situations for each valid day
    for itrDay=1:length(MesDays)
        indsAktDay=find(floor(timeFull)==MesDays(itrDay));
        % process diary-events for current day
        [evntMeta,eventsVis] = cli_diary_events(itrDay==1,diaryStrct(1),refPosStr(itrDay),evntMeta,eventsVis,indsAktDay,timeFull);
        
        % find and tag possible outliers and misclassification: will be used later
        valid_T=length(indsAktDay)-sum(actFull(indsAktDay)==0);
        walk_T=sum(actFull(indsAktDay)==5);
        other_T=sum(actFull(indsAktDay)==9);
        sleep_T=sum(actFull(indsAktDay)==10);
        noWlkProblem(itrDay) = (valid_T>=Settings.minValidDur)  && (walk_T < Settings.minWlkDur) && (other_T>=Settings.maxOtherDur);
        NoSleepProblem(itrDay) = (valid_T>=Settings.minValidDur)  && (sleep_T == 0);
    end
    
    %% calculating additional data for exports
    % create activity data based on time-bins (histograms) will be used for daily activity histograms
    histEdgeStart=MesDays(1); % begining of first day
    histEdgeEnd=MesDays(end)+1; % end of last day
    % the histogram edges of time slots
    histEdgesT=linspace(histEdgeStart,histEdgeEnd,histEdgeEnd-histEdgeStart+1);
    % the edges for activities
    histEdgesAkt=linspace(-0.5,11.5,13); % since the activities range from 0 to 11
    % find the activity histogram counts
    histMatrix = round(histcounts2(timeFull,actFull,histEdgesT,histEdgesAkt)/60,2);
    Date=string(datetime(histEdgesT(1:end-1)','ConvertFrom','datenum'),'yyyy-MM-dd');
    histMatT=[table(Date),array2table(histMatrix,'VariableNames',actvtTxts)];
    
    % generate 1s events vector
    % interpolate eventMeta.StartTs to generate the per/sec  Events vector
    if length(evntMeta.StartTs)>=2
        evntsFull=interp1(evntMeta.StartTs,1:length(evntMeta.StartTs),timeFull,'previous','extrap');
        evntsFull=evntMeta.Names(evntsFull); % event names in strings
    else
        evntsFull=repmat(evntMeta.Names,[length(timeFull),1]); % event names in strings
    end
    %% outlier and misclassification detection
    % no-walking and too-much-other indicates misclassifications due to unfixed orinetation issues
    if any(noWlkProblem)
        warning('Possible misclassification due to unfixed-orientation');
        exitcode=exitcode+100000000;
    end
    % if two consecutive days with no-sleep, then it's a problem
    if strcmpi(statusBdTime,"OK") && ~strcmpi(Settings.SLEEPALG,"off")
        rle_Si=rle(NoSleepProblem); % do a run length encoding of daily-sleep-interval flag
        if any(rle_Si{1}==1 & rle_Si{2}>=2)
            warning('No sleep found for two consecutive days');
            exitcode=exitcode+200000000;
        end
    end
    %% export data and figures
    
    % export 1s activity table
    fprintf('%s Now exporting output to files: %s ....\n',string(datetime,"HH:mm:ss.SSS"),out_file);
    
    % write detected activity time-series to a file (only under ADVANCED or CLI mode license)
    if matches(opmode,["PROPASS","CLI","ADVANCED"],"IgnoreCase",true)
        if out_file~=""
            T_1s=table(timeFull',actFull',stepsFull',svmFull,evntsFull,BD_full',SI_full','VariableNames',varn_1S);
            if matches(outext,[".csv",".xlsx",".txt",],'IgnoreCase',true)
                writetable(T_1s,out_file); % save as CSV or Excel table
            elseif strcmpi(outext,".mat")
                save(out_file,'T_1s'); % save as matlab binary
            end
        end
    end
    
    % export daily activity times
    if strcmpi(options.daily,"on")
        out_file2=fullfile(outDir,subjectID+"_dailyact.xlsx");
        fprintf('%s Now exporting daily activity times to file: %s ....\n',string(datetime,"HH:mm:ss.SSS"),out_file2);
        writetable(histMatT,out_file2);
    end
    
    % export daily activity times
    if strcmpi(options.vis,"on")
        fprintf('%s Now exporting weekly activity figures to: %s ....\n',string(datetime,"HH:mm:ss.SSS"),outDir);
        % visualize and export activity and diary-events
        status = cli_visualize(subjectID,timeFull,actFull,svmFull,BD_full,SI_full,eventsVis,histMatT,Settings,statusBdTime,outDir);
        if status~=""
            warning("Visualization error"+newline+status);
        end
    end
catch ME
    warning("Unhandled exception: \n%s",getReport(ME,'extended','hyperlinks','off'));
    exitcode=exitcode+1;
    % display elapsed time
    toc;
    fprintf("Return code: "+exitcode);
    pause(10);
end
% display elapsed time
toc;
if exitcode~=0
    fprintf("Return code: "+exitcode);
end

end
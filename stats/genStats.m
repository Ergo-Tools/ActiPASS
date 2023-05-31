function status = genStats(statStruct,uiFig)
% genTables generate ActiPASS variables
% INPUT:
% statStruct: a structure containing all information for stat generation
% OUTPUT:
% status: status of function execution ('OK', 'Canceled' etc)

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


%% Loading settings, parameters
status="OK";
allMsgs=strings(3,1);

Settings.PrPASS_MFile_Wide=statStruct.PrPASS_MFile_Wide; % the name of the wide-format daily master file
Settings.ActiPASS_MFile_Long=statStruct.ActiPASS_MFile_Long; % the name of the long-format daily master file
Settings.evntMasterFile=statStruct.evntMasterFile; % the name of the long-formats events master file
Settings.masterQCTblF=fullfile(statStruct.projectDir,statStruct.filQCMOut); % the master QC file of this project
Settings.statNumDays=statStruct.statNumDays; % the number of days to report. Missing days will be reported as empty columns
Settings.validDayHrs=statStruct.minValidDur; % minimum duration in hrs for a valid day
Settings.StatsVldD=statStruct.StatsVldD; %daily validity criteria (only wear time or ProPASS mode)
Settings.projectDir=statStruct.projectDir; % analysis directory

Settings.Batch=statStruct.Batch; % the selected batch
Settings.indvDirOut=statStruct.indvDirOut; % the directory name of individual output
Settings.TblFormat=statStruct.TblFormat; % the output table format(s)

Settings.prec_dig_min=2; % precision of results for variables in minutes
Settings.prec_dig_hrs=4; % precision of results for variables in hrs

% Settings.genAllBouts=true; not used anymore
Settings.wlkHeight=170;  % the default height for curvilinear MET calculation based on cadence
Settings.WalkMET=statStruct.WalkMET; % how to calculate MET values for walking- fixed cutoffs or cadence based regression? default - 'fixed'
Settings.FilterTAI=statStruct.FilterTAI; % apply exponential smoothing on TAI options 'off' 'TC2' 'TC5', 'TC10' - default off
Settings.genBouts=statStruct.genBouts; % enable/disable bouts generation
Settings.boutThresh=statStruct.boutThresh; % bout threshold value
Settings.boutBreak=statStruct.boutBreak; % bout break for all bouts except 1 min bout in seconds

% activity to MET translation
Settings.MET_SI=0.90;
Settings.MET_LieStill=0.95;
Settings.MET_Lie=1.0;
Settings.MET_Sit=1.3;
Settings.MET_Stand=1.55; % 2022-07-05 standing falls into light physical activity class (changed from 1.4)
Settings.MET_Move=2.0;
Settings.Wlk_Low_MET=2;
Settings.Wlk_Fast_MET=4;
Settings.Wlk_VFast_MET=7;
Settings.MET_Running=10;
Settings.MET_Stairs=8;
Settings.MET_Cycle=7;
Settings.MET_Other=2; % "Other" with no periodicity falls into light physical activity

% MET citoffs for intensity classes
Settings.PA_Slp=0.0;
Settings.PA_SED=0.95; %lieStill belongs to sedentary
Settings.PA_LPA=1.5;
Settings.PA_LPA_Amb=1.6; %introduce another called LPA_ambulatory to seperate standing from other LPA activities
Settings.PA_MPA=3.0;
Settings.PA_VPA=6.0;

%cadence cutoffs for walk-slow, walk-fast and walk-very-fast
Settings.Wlk_Slow_Cad=100;
%2022-08-26 From ActiPASS version 1.42 Wlk_VFast_Cad=135, previously it was 130 (Myles O'Brien <Myles.OBrien@dal.ca>)
Settings.Wlk_VFast_Cad=135; %prior versions: Wlk_VFast_Cad=130

% the domains to calculate seperate decriptive stats
Settings.StatDomains=statStruct.StatDomains; % domain string is splitted into a vector
Settings.statSlctDays=statStruct.statSlctDays; % how days are selected for stat generation
Settings.statsIgnoreQC=statStruct.statsIgnoreQC; % the QC_Status ignore flag
Settings.StatMtchMode=statStruct.StatMtchMode; % how stat domains are compared with diary events ('inclusive' or 'exclusive')
Settings.DBedAsLeis=statStruct.DBedAsLeis; % treat bedtime as leisure during stat generation when bedtime is not explicitely a stat-domain

%% defining variables for common all tables
% the variables names of the per-sec-table saved by ActiPASS
% perSecVarNms=["DateTime","Activity","Steps","Temperature","SVM","Event","Bedtime","SleepInterval"];

%variables specific to all days of a specific ID
varN_Sbjct=["SubjectID","QC_Status","Batch","Sensor_Errs"];

%variables specific to all events of a specific ID
varN_Sbjct_evnt=["SubjectID","QC_Status","Batch"];

varN_Comm=["Duration","NonWear","AwakeNW","SlpIntNW","ValidDuration","Awake","SleepInterval","Bedtime",...
    "Sleep","SleepInBed","LieStill","Walk_Slow","Walk_Fast","NumSteps","NumStepsWalk","NumStepsRun","TotalTransitions"];

% define variables commmon to each activity or intensity class
varN_Akt=["P50","T50","P10","P90","T30min","N30min","Tmax","NBreaks"];

%define bout variables for all activity/intensity classes
bout_durs=["1min","2min","3min","4min","5min","10min","30min","60min"];
varN_Bouts_TH=[bout_durs+"_bouts_TH",bout_durs+"_freq_H"];
varN_Bouts_TL=[bout_durs+"_bouts_TL",bout_durs+"_freq_L"];
% check whether bout-generation is turned on and create variables oly if necessary
if strcmpi(Settings.genBouts,"on")
    varN_Bouts=[varN_Bouts_TH,varN_Bouts_TL];
else
    varN_Bouts=[];
end

% define variable names for each activity or intensity class
varN_SitLie=["SitLie","SitLie_"+[varN_Akt,varN_Bouts]];
varN_Sit=["Sit","Sit_"+[varN_Akt,varN_Bouts]];
varN_Lie=["Lie","Lie_"+[varN_Akt,varN_Bouts]];
varN_Stand=["Stand","Stand_"+[varN_Akt,varN_Bouts]];
varN_Move=["Move","Move_"+[varN_Akt,varN_Bouts]];
varN_StandMove=["StandMove","StandMove_"+[varN_Akt,varN_Bouts]];
varN_Walk=["Walk","Walk_"+[varN_Akt,varN_Bouts]];
varN_Run=["Run","Run_"+[varN_Akt,varN_Bouts]];
varN_Stair=["Stair","Stair_"+[varN_Akt,varN_Bouts]];
varN_Cycle=["Cycle","Cycle_"+[varN_Akt,varN_Bouts]];
varN_Upright=["Upright","Upright_"+[varN_Akt,varN_Bouts]];
varN_Other=["Other","Other_"+[varN_Akt,varN_Bouts]];

%intensity classes are named INT1, INT2, INT3, INT4 and INT34 (corresponding to SED, LPA, MPA, MVPA)
varN_SED=["INT1","INT1_"+[varN_Akt,varN_Bouts]];
varN_LPA=["INT2","INT2_"+[varN_Akt,varN_Bouts]];
varN_LPA_Amb=["INT2_Amb","INT2_Amb_"+[varN_Akt,varN_Bouts]];
varN_MPA=["INT3","INT3_"+[varN_Akt,varN_Bouts]];
varN_VPA=["INT4","INT4_"+[varN_Akt,varN_Bouts]];
varN_MVPA=["INT34","INT34_"+[varN_Akt,varN_Bouts]];


%% define variable names specific to horizontal table

% variables specific for each day in horizontal table
varN_Dly1=["Date","Day","Weekend","DayType","DayStart","DayStop","Day_QC","NotEnoughWear","NoWlk",...
    "TooMuchOther","TooMuchStair","NoSleepInt","NumPrimaryBDs","NumExtraBDs","Excluded"];

varT_Dly1=["string","string","logical","string","string","string","string","logical",...
    "logical","logical","logical","logical","double","double","double"];

varN_Smry=["NumDays","NumValidDays","NumWorkDays","NumLeisureDays",];

% aggregate all variable names in the horizontal tables
dlyVarNames = [varN_Dly1,varN_Comm,varN_Lie,varN_Sit,varN_SitLie,varN_Stand,varN_Move,varN_StandMove,varN_Walk,...
    varN_Run,varN_Stair,varN_Cycle,varN_Upright,varN_Other,varN_SED,varN_LPA,varN_LPA_Amb,varN_MPA,varN_VPA,varN_MVPA];
% define variable types of the horizontal table
dlyVarTypes=[varT_Dly1,repmat("double",[1,length(dlyVarNames)-length(varN_Dly1)])];

%% define variable names specific to events table

% variables specific for each day in horizontal table
varN_Evnt1=["EventStart","EventStop","Event","Comment"];

% aggregate all variable names in the horizontal tables
evntVarNames = [varN_Sbjct_evnt,varN_Evnt1,varN_Comm,varN_Lie,varN_Sit,varN_SitLie,varN_Stand,varN_Move,varN_StandMove,varN_Walk,...
    varN_Run,varN_Stair,varN_Cycle,varN_Upright,varN_Other,varN_SED,varN_LPA,varN_LPA_Amb,varN_MPA,varN_VPA,varN_MVPA];
% define variable types of the horizontal table
NumStringVars=length(varN_Sbjct_evnt)+length(varN_Evnt1);
evntVarTypes=[repmat("string",[1,NumStringVars]),repmat("double",[1,length(evntVarNames)-NumStringVars])];

%% loading master QC table
try
    
    uiPgDlg = uiprogressdlg(uiFig,'Title','Generating Stats. Please wait.',...
        'Message','Loading Master QC Table...','Cancelable','on');
    %fPrgBar = waitbar(0,'Finding per_sec activity files...');
    %     perSecFs=dir(fullfile(Settings.projectDir,"*","*-Activity_per_s.csv"));
  
    if ~isfile(Settings.masterQCTblF)
        status="Master QC table not found";
        return;
    end
    opt = detectImportOptions(Settings.masterQCTblF,'VariableNamingRule','preserve');
    opt.VariableTypes=repmat("string",[1,length(opt.VariableTypes)]);
    opt.PreserveVariableNames=true;
    masterQCTbl=readtable(Settings.masterQCTblF,opt);
    
    % select files only from given batch if Settings.Batch is not empty
    if ~isempty(Settings.Batch)
        masterQCTbl=masterQCTbl(strcmpi(masterQCTbl.Batch,Settings.Batch),:);
    end
    
    % if QC status is not ignored and QC_Status is not "OK" skip this file from stat generation
    if Settings.statsIgnoreQC=="NotOK"
        masterQCTbl=masterQCTbl(masterQCTbl.QC_Status=="OK" | masterQCTbl.QC_Status=="Check",:);
    elseif Settings.statsIgnoreQC=="NotOK+Check"
        masterQCTbl=masterQCTbl(masterQCTbl.QC_Status=="OK",:);
    elseif Settings.statsIgnoreQC=="None"
        masterQCTbl=masterQCTbl(~ismissing(masterQCTbl.QC_Status),:);
    end
    
    %% Horizontal table generation
    
    % create dlyGenStruct with parameters needed for horizontal table generation
    dlyGenStruct.dlyVarNames=dlyVarNames;
    dlyGenStruct.dlyVarTypes=dlyVarTypes;
    dlyGenStruct.varN_Smry=varN_Smry;
    dlyGenStruct.NumVarDly=length(varN_Dly1);
    dlyGenStruct.sbjctVarNames=varN_Sbjct;
    dlyGenStruct.uiPgDlg=uiPgDlg;
    dlyGenStruct.Settings=Settings;
    dlyGenStruct.totFiles=height(masterQCTbl);
        
    % create empty tables to hold data from daily stat generation process
    fnlPrPSTbl=[]; % empty variable to hold the final horizontal table
    fnlDlyTbl=[]; % empty variable to hold the final long format daily table
    
    % create evntGenStruct with parameters needed for vertical table generation
    evntGenStruct.evntVarNames=evntVarNames;
    evntGenStruct.evntVarTypes=evntVarTypes;
    evntGenStruct.uiPgDlg=uiPgDlg;
    evntGenStruct.Settings=Settings;
    evntGenStruct.totFiles=height(masterQCTbl);
    
    % create empty table to hold data from stat generation process for events
    finalEvntTbl=[]; % empty variable to hold the final vertical table
    
    for itrFil=1:height(masterQCTbl)
       
        if uiPgDlg.CancelRequested
            status="Canceled";
            return;
        end
        subjctID=masterQCTbl.SubjectID(itrFil);
        perSecF=fullfile(statStruct.projectDir,statStruct.indvDirOut,subjctID,subjctID+" - Activity_per_s.mat");
        metaF=fullfile(statStruct.projectDir,statStruct.indvDirOut,subjctID,subjctID+" - Metadata.mat");
        
        uiPgDlg.Value=(itrFil-1)/height(masterQCTbl)+(1/height(masterQCTbl))*0.1;
        uiPgDlg.Message="Loading data: ID: "+subjctID+". File "+itrFil+" of "+height(masterQCTbl)+"..";
        
        % find batch,  QC_Status and  Sensor_Errs of current file 
        % Sensor_Errs is per file flag, but will be propagated into daily tables
        qcBatch=masterQCTbl.Batch(itrFil);
        QC_Status=masterQCTbl.QC_Status(itrFil);
        Sensor_Errs=masterQCTbl.Sensor_Errs(itrFil);
        
        
        % now load real per-ssec data from binary mat file
%         perSOBJ = matfile(perSecF); % without directly opening the mat file let's find variables contained
%         if ismember("aktTbl",who(perSOBJ)) % if QC data found
%             perSecT=perSOBJ.aktTbl;
%         else
%             status="Activity table not found for ID: "+subjctID;
%             return;
%         end
        
        perSOBJ = load(perSecF,'-mat');
        perSecT=perSOBJ.aktTbl;
       
        % now load metadata from binary mat file
%        metaOBJ = matfile(metaF); % without directly opening the mat file let's find variables contained
        metaOBJ = load(metaF,'-mat'); %load meta data directly
        if matches(Settings.TblFormat,["Daily","Daily+Events"],'IgnoreCase',true)
            
%             if ismember("dlyQCT_meta",who(metaOBJ)) % if QC data found
%                 qcMeta=metaOBJ.dlyQCT_meta;
%             else
%                status="Daily QC metadata not found for ID: "+subjctID;
%                return;
%             end

            qcMeta=metaOBJ.dlyQCT_meta; 
            % append data to dlyGenStruct relevant to this iteration of stat generation
            dlyGenStruct.itrFil=itrFil;
            dlyGenStruct.subjctID=subjctID;
            dlyGenStruct.QC_Status=QC_Status;
            dlyGenStruct.qcBatch=qcBatch;
            dlyGenStruct.qcMeta=qcMeta;
            dlyGenStruct.Sensor_Errs=Sensor_Errs;
            
            % call genHorzTable function for this ID
            [status,fnlPrPSTbl,fnlDlyTbl] = genDlyTable(perSecT,fnlPrPSTbl,fnlDlyTbl,dlyGenStruct);
            % give the user chance to cancel before next iteration
            if status=="Canceled"
                return;
            end
        end
        
        
        if matches(Settings.TblFormat,["Events","EventsNoBreak","Daily+Events"],'IgnoreCase',true)
%             if ismember("eventMeta",who(metaOBJ)) % if QC data found
%                 eventMeta=metaOBJ.eventMeta;
%             else
%                 status="Event metadata not found for ID: "+subjctID;
%                 return;
%             end
            eventMeta=metaOBJ.eventMeta;
            % remove midnight breaks in events
            if strcmpi(Settings.TblFormat,"EventsNoBreak") && length(eventMeta.Names)>=2
                indsRLE = [find(eventMeta.Names(1:end-1) ~= eventMeta.Names(2:end));length(eventMeta.Names)]; % find unique consecutive events
                runL = diff([0;indsRLE ]); % run length of those events
                indsDel=setdiff(1:length(eventMeta.Names),indsRLE); % the indices of events to delete
                % if any events should be deleted
                if ~isempty(indsDel)
                    eventMeta.StartTs(indsRLE,:)=eventMeta.StartTs(indsRLE-(runL-1),:); %adjust start time of the events if necessary 
                    eventMeta.Indices(indsRLE,1)=eventMeta.Indices(indsRLE-(runL-1),1); % adjust index of main 1S vector for each event if necessary
                    % delete repeating events
                    eventMeta.Names(indsDel,:)=[];
                    eventMeta.StartTs(indsDel,:)=[];
                    eventMeta.EndTs(indsDel,:)=[];
                    eventMeta.Comments(indsDel,:)=[];
                    eventMeta.Indices(indsDel,:)=[];
                end
                
            end
            % append data to evntGenStruct relevant to this iteration of stat generation
            evntGenStruct.itrFil=itrFil;
            evntGenStruct.subjctID=subjctID;
            evntGenStruct.QC_Status=QC_Status;
            evntGenStruct.qcBatch=qcBatch;
                        
            % call genHorzTable function for this ID
            [status,finalEvntTbl] = genEventTable(perSecT,eventMeta,finalEvntTbl,evntGenStruct);
            
            % give the user chance to cancel before next iteration
            if status=="Canceled"
                return;
            end
        end
       
    end
    
    %% Saving daily and events table
    % saving long format daily table and ProPASS table
    if matches(Settings.TblFormat,["Daily","Daily+Events"],'IgnoreCase',true)
        % merge finalHozTbl with existing master horizontal table in the disk
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        fnlPrPSTblF=fullfile(Settings.projectDir,Settings.PrPASS_MFile_Wide);
        fnlDlyTblF=fullfile(Settings.projectDir,Settings.ActiPASS_MFile_Long);
        
        uiPgDlg.Value=(itrFil-1)/height(masterQCTbl)+(0.8/height(masterQCTbl));
        uiPgDlg.Message="Saving the final daily tables to disk..";
        %waitbar(0.85,fPrgBar,"Saving the final horizontal table to file..");
        % save wide-format ProPASS daily table to disk
        if ~isempty(fnlPrPSTbl) 
            %writetable(finalHozTbl,finalHorzTblF,'WriteMode','overwritesheet');
            % find the rows masterQCTbl with the same subjectIDs as current batch (only with non-missimng QC_status)
            if isfile(fnlPrPSTblF)
                impOptPrPST=detectImportOptions(fnlPrPSTblF,'VariableNamingRule',"preserve");
                if isequal(impOptPrPST.VariableNames,fnlPrPSTbl.Properties.VariableNames)
                    impOptPrPST.VariableTypes=varfun(@class,fnlPrPSTbl(1,:),'OutputFormat','cell');
                    oldPrPSTbl=readtable(fnlPrPSTblF,impOptPrPST);
                    indOverlap= ismember(oldPrPSTbl.SubjectID,fnlPrPSTbl.SubjectID);
                    oldPrPSTbl(indOverlap,:)=[]; % delete those overlapping rows from old horizontal table
                    
                    fnlPrPSTbl=vertcat(oldPrPSTbl,fnlPrPSTbl); % concatenate master QC table with current batch  QC table
                    fnlPrPSTbl=sortrows(fnlPrPSTbl,"SubjectID"); % sort the table first by ID
                else
                    %save the existing incompatiable horizontal table
                    [oldPrPSTDir,oldPrPSTFName,oldPrPSTExt]=fileparts(fnlPrPSTblF);
                    oldPrPSTblF=oldPrPSTFName+"_Renamed_Old_"+datestr(now,'yyyymmdd HHMMSS')+oldPrPSTExt;
                    
                    uialert(uiFig,"Incompatiable ProPASS table found. Old table is saved as: "+oldPrPSTblF,"Stats Warning",...
                        "Icon","warning");
                    copyfile(fnlPrPSTblF,fullfile(oldPrPSTDir,oldPrPSTblF));
                end
            end
            writetable(fnlPrPSTbl,fnlPrPSTblF,'WriteMode','overwrite');
        else
            allMsgs(1)="No valid data for ProPASS table.";
        end
        
        % save long format daily table to disk
        if ~isempty(fnlDlyTbl) 
            %writetable(finalHozTbl,finalHorzTblF,'WriteMode','overwritesheet');
            % find the rows masterQCTbl with the same subjectIDs as current batch (only with non-missimng QC_status)
            fnlDlyTbl=movevars(fnlDlyTbl,"Sensor_Errs",'After',"Day_QC"); %move Sensor_Errs next to other daily QC flags (table looks nice this way)
            if isfile(fnlDlyTblF)
                impOptDlyT=detectImportOptions(fnlDlyTblF,'VariableNamingRule',"preserve");
                if isequal(impOptDlyT.VariableNames,fnlDlyTbl.Properties.VariableNames)
                    impOptDlyT.VariableTypes=varfun(@class,fnlDlyTbl(1,:),'OutputFormat','cell');
                    oldDlyTbl=readtable(fnlDlyTblF,impOptDlyT);
                    indOverlap= ismember(oldDlyTbl.SubjectID,fnlDlyTbl.SubjectID);
                    oldDlyTbl(indOverlap,:)=[]; % delete those overlapping rows from old horizontal table
                    
                    fnlDlyTbl=vertcat(oldDlyTbl,fnlDlyTbl); % concatenate master QC table with current batch  QC table
                    fnlDlyTbl=sortrows(fnlDlyTbl,["SubjectID","Date"]); % sort the table first by ID and then by date
                else
                    %save the existing incompatiable horizontal table
                    [oldDlyTDir,oldDlyTFName,oldDlyTExt]=fileparts(fnlDlyTblF);
                    oldDlyTblF=oldDlyTFName+"_Renamed_Old_"+datestr(now,'yyyymmdd HHMMSS')+oldDlyTExt;
                    
                    uialert(uiFig,"Incompatiable long format daily table found. Old table is saved as: "+oldDlyTblF,"Stats Warning",...
                        "Icon","warning");
                    copyfile(fnlDlyTblF,fullfile(oldDlyTDir,oldDlyTblF));
                end
            end
            writetable(fnlDlyTbl,fnlDlyTblF,'WriteMode','overwrite');
        else
            allMsgs(2)="No valid data for long format daily table.";
        end
    end
    
    % Saving events table to disk
    if matches(Settings.TblFormat,["Events","EventsNoBreak","Daily+Events"],'IgnoreCase',true)
        % merge finalHozTbl with existing master horizontal table in the disk
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        fnlEvntTblF=fullfile(Settings.projectDir,Settings.evntMasterFile);
        uiPgDlg.Value=(itrFil-1)/height(masterQCTbl)+(0.9/height(masterQCTbl));
        uiPgDlg.Message="Saving the final events table to file..";
        %waitbar(0.85,fPrgBar,"Saving the final horizontal table to file..");
        if ~isempty(finalEvntTbl)
            %writetable(finalVerTbl,finalVertTblF,'WriteMode','overwritesheet');
            % find the rows masterQCTbl with the same subjectIDs as current batch (only with non-missimng QC_status)
            if isfile(fnlEvntTblF)
                impOptVertT=detectImportOptions(fnlEvntTblF,'VariableNamingRule',"preserve");
                if isequal(impOptVertT.VariableNames,finalEvntTbl.Properties.VariableNames)
                    impOptVertT.VariableTypes=varfun(@class,finalEvntTbl(1,:),'OutputFormat','cell');
                    oldEvntTbl=readtable(fnlEvntTblF,impOptVertT);
                    indOverlap = ismember(oldEvntTbl.SubjectID,finalEvntTbl.SubjectID);
                    oldEvntTbl(indOverlap,:)=[]; % delete those overlapping rows from old horizontal table
                    
                    finalEvntTbl=vertcat(oldEvntTbl,finalEvntTbl); % concatenate master QC table with current batch  QC table
                    finalEvntTbl=sortrows(finalEvntTbl,1); % sort the table first by ID
                else
                    %save the existing incompatiable horizontal table
                    [oldVertTDir,oldVertFName,oldVertTExt]=fileparts(fnlEvntTblF);
                    oldVertTblF=oldVertFName+"_Renamed_Old_"+datestr(now,'yyyymmdd HHMMSS')+oldVertTExt;
                    
                    uialert(uiFig,"Incompatiable Events table found. Old table is saved as: "+oldVertTblF,"Stats Warning",...
                        "Icon","warning");
                    copyfile(fnlEvntTblF,fullfile(oldVertTDir,oldVertTblF));
                end
            end
            writetable(finalEvntTbl,fnlEvntTblF,'WriteMode','overwrite');
        else
            allMsgs(3)="No valid data for Events table.";
        end
    end
    
    if any(allMsgs~="")
        status=join(allMsgs(allMsgs~=""));
    end
    %close(fPrgBar);
    close(uiPgDlg);
catch ME
    close(uiPgDlg);
    status=[string(ME.message);string(getReport(ME,'extended','hyperlinks','off'))];
    
end

end


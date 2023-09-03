function [status,fnlPrPSTbl,fnlDlyTbl] = genDlyTable(perSecT,fnlPrPSTbl,fnlDlyTbl,dlyGenStruct)
% genDlyTable generate ActiPASS daily tables (both ProPASS format and long format)from the given per-sec table
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

% set status to "OK"
status="OK";

% load data back from horzGenStruct
sbjctVarNames=dlyGenStruct.sbjctVarNames; %
varN_Smry=dlyGenStruct.varN_Smry;
dlyVarNames=dlyGenStruct.dlyVarNames;
dlyVarTypes=dlyGenStruct.dlyVarTypes;
NumVarDly=dlyGenStruct.NumVarDly;
uiPgDlg=dlyGenStruct.uiPgDlg;
Settings=dlyGenStruct.Settings;
itrFil=dlyGenStruct.itrFil;
subjctID=dlyGenStruct.subjctID;
totFiles=dlyGenStruct.totFiles;
qcBatch=dlyGenStruct.qcBatch;
QC_Status=dlyGenStruct.QC_Status;
Sensor_Errs=dlyGenStruct.Sensor_Errs;
qcMeta=dlyGenStruct.qcMeta;
varN_DlyQC=["NotEnoughWear","NoWlk","TooMuchOther","TooMuchStair","NoSleepInt","NumPrimaryBDs","NumExtraBDs"];



% convert excel date-numbers to matlab datetime vector
dateTimeDT=datetime(perSecT.DateTime,'ConvertFrom','datenum');
%round off datetime values to nearest second
dateTimeDT=dateshift(dateTimeDT, 'start', 'second', 'nearest');
%find the 00.00hrs of the day corresponding to first of bouts
startDay=dateshift(dateTimeDT(1),'start','day');
%find the midnight of the day corresponding to last of bouts
endDay=dateshift(dateTimeDT(end),'start','day');

% if for some case data ends exactly at midnight, endDay should actually be the previous day
if endDay==dateTimeDT(end)
    qcMeta(datetime(qcMeta.Start)==endDay,:)=[]; %remove the last day from daily-qc table
    endDay=endDay-days(1); % select the previous day as the end day
end

%check whether stat domains is empty
if ismissing(Settings.StatDomains) || Settings.StatDomains==""
    dmnStats=false; % a flag to disable stat domain processing
else
    dmnStats=true; % a flag to enable stat domain processing
    StatDomains=split(Settings.StatDomains);
    % the flag UseDBedAsLeis will be later used to rename bedtime diary events to leisure if the Settings.DBedAsLeis is
    % enabled and StatDomains explicitely ask for bedtime stats
    UseDBedAsLeis=Settings.DBedAsLeis && any(strcmpi(StatDomains,"Leisure")) &&...
        ~any(matches(StatDomains,["bed","bedtime","night"],'IgnoreCase',true));
end

analysDays=startDay:endDay;
% find the number of days
numDays=length(analysDays);
%iterate through the days
dlyTable=table('Size',[numDays,length(dlyVarNames)],'VariableTypes',dlyVarTypes,'VariableNames',dlyVarNames);

%intialize the tables to hold domain-specific daily stats and store them in a cellarray
if dmnStats
    dlyTblDmns=cell(length(StatDomains),1); % cell array of tables to hold domain-specific horizontal tables
    for itrDm=1:length(StatDomains)
        dlyTblDmns{itrDm}=table('Size',[numDays,length(dlyVarNames)-NumVarDly],'VariableTypes',...
            dlyVarTypes((NumVarDly+1):end),'VariableNames',dlyVarNames((NumVarDly+1):end));
        dlyTblDmns{itrDm}{:,:}=NaN;%fill table with NaN
    end
    
end

workDays=false(numDays,1);% array to hold valid workday flag
offDays=false(numDays,1);% array to hold valid leisure-day flag

%% Iterate through each day
for itrDay=1:numDays
    % update progress dialog
    uiPgDlg.Value=(itrFil-1)/totFiles+(1/totFiles)*(0.1+(itrDay/numDays)*0.5);
    uiPgDlg.Message="Daily Table: ID: "+subjctID+". File "+itrFil+" of "+totFiles+...
        ", Day "+itrDay+" of "+numDays+"..";
    % find basic data for this particular day
    %     rowsDay=day(startDay+days(itrDay-1),'dayofyear')==day(dateTimeDT,'dayofyear');
    % find indices for this day (using find speedier than direct logical indexing)
    rowsDay=find((dateTimeDT>=analysDays(itrDay)) & (dateTimeDT<analysDays(itrDay)+days(1)));
    dayDT=dateTimeDT(rowsDay);
    dayPerSecT=perSecT(rowsDay,:);
    
    % fill information related to current day
    dlyTable.Date(itrDay)=string(analysDays(itrDay),"yyyy-MM-dd");
    dlyTable.Day(itrDay)= day(analysDays(itrDay),"name");
    dlyTable.Weekend(itrDay)=isweekend(analysDays(itrDay));
    dlyTable.DayStart(itrDay)=string(dayDT(1),"HH:mm:ss");
    dlyTable.DayStop(itrDay)=string(dayDT(end),"HH:mm:ss");
    
    %find excluded seconds and total time of excluded
    dayRowsExcld=strcmpi(dayPerSecT.Event,"X");
    dlyTable.Duration(itrDay)=round(height(dayPerSecT)/60,Settings.prec_dig_min);
    dlyTable.Excluded(itrDay)=round(sum(dayRowsExcld)/60,Settings.prec_dig_min);
    
    dayPerSecT.Activity(dayRowsExcld)=-1; % reclassify all seconds flagged as 'X' from diary as new activity -1
    rows_SI=dayPerSecT.SleepInterval ==1; % find the seconds flagged as sleep-interval
    rows_BT=dayPerSecT.Bedtime ==1; % find the seconds flagged as bedtime
    % call genVariables function
    dlyTable=genVariables(dlyTable,dayPerSecT.Activity,dayPerSecT.Steps,rows_SI,rows_BT,itrDay,Settings);
    
    if dmnStats
        if any(contains(dayPerSecT.Event,StatDomains,'IgnoreCase',true))
            if UseDBedAsLeis
                indsBed=matches(dayPerSecT.Event,["bed","bedtime","night"],'IgnoreCase',true);
                dayPerSecT.Event(indsBed)="Leisure";
            end
            for itrDm=1:length(StatDomains)
                
                %actDomain(~strcmpi(StatDomains(itrDm),dayPerSecT.Event))=-1;% match only exact stat-domain names (work, Leisure etc)
                if strcmpi(Settings.StatMtchMode,"Inclusive")
                    % loosely match any event containing the stat-domain names (WorkFromHome, LeisureCommute etc)
                    rowsDomain=contains(dayPerSecT.Event,StatDomains(itrDm),'IgnoreCase',true);
                elseif strcmpi(Settings.StatMtchMode,"Strict")
                    % strictly match any event containing the stat-domain names (WorkFromHome, LeisureCommute etc)
                    rowsDomain=strcmpi(dayPerSecT.Event,StatDomains(itrDm));
                end
                actDomain=dayPerSecT.Activity;
                dlyTblDmns{itrDm}.Duration(itrDay)=round(sum(rowsDomain)/60,Settings.prec_dig_min); % the time duration within this domain
                actDomain(~rowsDomain)=-1; % exclude epochs other than times of this domain
                dlyTblDmns{itrDm}=genVariables(dlyTblDmns{itrDm},actDomain,dayPerSecT.Steps,rows_SI,rows_BT,itrDay,Settings);
                if contains(StatDomains(itrDm),"Work",'IgnoreCase',true) && dlyTblDmns{itrDm}.Duration(itrDay) >0
                    workDays(itrDay)=true;
                end
                if contains(StatDomains(itrDm),"Leisure",'IgnoreCase',true) && dlyTblDmns{itrDm}.Duration(itrDay)>0 &&...
                        ~workDays(itrDay)
                    offDays(itrDay)=true;
                end
            end
        else
            for itrDm=1:length(StatDomains)
                dlyTblDmns{itrDm}{itrDay,:}=NaN;
            end
        end
        
        if uiPgDlg.CancelRequested
            status="Canceled";
            return;
        end
    end
end

%% find daily DayType, QC-status and fill all QC-flags from metadata

% asign WorkDay LeisureDay flag for each day
dlyTable.DayType(workDays)="Work";
dlyTable.DayType(offDays)="DayOff";

%find consecutive no-sleep-interval cases
consecNoSlp=movsum(qcMeta.NoSleepInt,2);
if height(dlyTable)>1
    consecNoSlp(1)=consecNoSlp(2);
end

notEnoughValid = dlyTable.ValidDuration < (Settings.validDayHrs*60);
%fill in daily-QC flag for alldays
Sensor_Errs_day=repmat(Sensor_Errs=="Yes",height(dlyTable),1); % consider file-level Sensor_Errs into account for each day
dlyTable.Day_QC(notEnoughValid | (qcMeta.NoWlk & qcMeta.TooMuchOther) | (consecNoSlp>1) | (dlyTable.Awake==0))="NotOK";
dlyTable.Day_QC(ismissing(dlyTable.Day_QC ) & (qcMeta.TooMuchOther | qcMeta.TooMuchStair | qcMeta.NoWlk | Sensor_Errs_day))="Check";
dlyTable.Day_QC(ismissing(dlyTable.Day_QC ))="OK";
%fill daily QC flags from metadata file
dlyTable(:,varN_DlyQC)=qcMeta(:,varN_DlyQC);

%% merge dlyTable and  domain-specific table dlyTblDmns to mgdLngDlyTbl

% create a table with subject-related info which are the same for all days
subjctTLng=array2table(repmat([subjctID,QC_Status,qcBatch,Sensor_Errs],[height(dlyTable),1]),'VariableNames',sbjctVarNames);

mgdLngDlyTbl=horzcat(subjctTLng,dlyTable);
% if stat-domains defined merge domain specific tables with daily table
if dmnStats
    for itrDm=1:length(StatDomains)
        tempTbl_2=dlyTblDmns{itrDm};
        tempTbl_2.Properties.VariableNames=StatDomains(itrDm)+"_"+tempTbl_2.Properties.VariableNames;
        mgdLngDlyTbl=horzcat(mgdLngDlyTbl,tempTbl_2);
    end
end

if isempty(fnlDlyTbl)
    fnlDlyTbl=mgdLngDlyTbl;
else
    fnlDlyTbl=vertcat(fnlDlyTbl,mgdLngDlyTbl);
end


%% find selected days for ProPASS table

% How validDays are defined, only considering weartime (ValidDuration to be precise) or ProPASS  daily QC criteria
if Settings.StatsVldD=="only wear-time"
    validDays = ~notEnoughValid; % find days with enough valid duration
elseif Settings.StatsVldD=="ProPASS"
    validDays = dlyTable.Day_QC ~="NotOK";
end

reqdWkDays=ceil(Settings.statNumDays*5/7);

valDNs=find(validDays); % the valid day numbers
validWorkDays=validDays & workDays; % valid work days
validLeisureDays=validDays & offDays; % valid leisure days
validOtherDays=validDays & ~(workDays | offDays); % valid other days

if sum(validDays)<=Settings.statNumDays
    finValidDays=find(validDays);
elseif strcmp(Settings.statSlctDays,"first valid days")
    finValidDays=valDNs(1:Settings.statNumDays);
elseif strcmp(Settings.statSlctDays,"pick days: optimal work/leisure")
    % calculate required work days (try to find at least this many work days if possible)
    
    finValidDays=[];
    % if any work days existe append upto reqdWkDays of them to  finValidDays
    if any(validWorkDays)
        finValidDays=find(validWorkDays);
        finValidDays=finValidDays(1:min(reqdWkDays,length(finValidDays)));
    end
    
    % if there are any leisure days append them to the finValidDays upto a maximum of Settings.statNumDays
    if any(validLeisureDays)
        selLesDays=find(validLeisureDays);
        finValidDays=[finValidDays;selLesDays(1:min(Settings.statNumDays-length(finValidDays),length(selLesDays)))];
    end
    % fill any remaining days with validOtherDays
    if length(finValidDays)<Settings.statNumDays && any(validOtherDays)
        otherDays=find(validOtherDays);
        finValidDays=[finValidDays;otherDays(1:min(Settings.statNumDays-length(finValidDays),length(otherDays)))];
    end
    
    % sort the days in acending order
    finValidDays=sort(finValidDays);
elseif strcmp(Settings.statSlctDays,"pick window: optimal work/leisure")
    % extra valid days beyonf first Settings.statNumDays
    numExtraDs=sum(validDays)-Settings.statNumDays;
    % use a moving window of Settings.statNumDays numExtraDs times and calculate work and leisure days
    posWkDNs=zeros(numExtraDs,1);
    posLesDNs=zeros(numExtraDs,1);
    
    %move the window numExtraDs times and find work and leisure days for each option
    for itrExD=1:numExtraDs
        posWkDNs(itrExD)=sum(workDays(valDNs(itrExD:(itrExD+Settings.statNumDays-1))));
        posLesDNs(itrExD)=sum(offDays(valDNs(itrExD:(itrExD+Settings.statNumDays-1))));
    end
    %if at least one work day and one leisure day found for different options
    if any(posWkDNs>0) &&  any(posLesDNs>0)
        % the best case senario is work and leisure days are distributed at the ratio 5:2 (total 7 days, 5 work days 2
        % leisure days)
        [~,itrBest]=min(abs(2/5-posLesDNs./posWkDNs));
        finValidDays=valDNs(itrBest:(itrBest+Settings.statNumDays-1));
    elseif all(posWkDNs==0) &&  any(posLesDNs>0)
        % no work days but some leisure days exist, best case is the case with maximum leisure days
        [~,itrBest]=max(posLesDNs);
        finValidDays=valDNs(itrBest:(itrBest+Settings.statNumDays-1));
    elseif  all(posLesDNs==0)  &&  any(posWkDNs>0)
        % no leisure days but some work days exist, best case is the case with maximum work days
        [~,itrBest]=max(posWkDNs);
        finValidDays=valDNs(itrBest:(itrBest+Settings.statNumDays-1));
    else
        % if no work or leisure days available for any case, just use the first valid statNumDays
        finValidDays=valDNs(1:Settings.statNumDays);
    end
    
end

%% create ProPASS table
% again iterate through days  fill in final horizontal table
numValidDays=length(finValidDays); % the number of valid days used in horizontal table

% create an empty vector to merge wide-format table
mgdDlyTble=[];

% iterate through final valid days
for itrVDay=1:numValidDays
    dayN=finValidDays(itrVDay);
    
    tempTbl=dlyTable(dayN,:);
    tempTbl.Properties.VariableNames=tempTbl.Properties.VariableNames+"_"+itrVDay;
    mgdDlyTble=horzcat(mgdDlyTble,tempTbl);
    if dmnStats
        for itrDm=1:length(StatDomains)
            tempTbl=dlyTblDmns{itrDm}(dayN,:);
            
            tempTbl.Properties.VariableNames=StatDomains(itrDm)+"_"+tempTbl.Properties.VariableNames+"_"+itrVDay;
            mgdDlyTble=horzcat(mgdDlyTble,tempTbl);
        end
    end
end

if numValidDays<Settings.statNumDays && numValidDays >=1
    for itrRem=(numValidDays+1):Settings.statNumDays
        %iterate through the days
        tempTbl=table('Size',[1,length(dlyVarNames)],'VariableTypes',dlyVarTypes,'VariableNames',dlyVarNames+"_"+itrRem);
        tempTbl{1,(NumVarDly+1):end}=NaN;%fill empty table with NaN
        mgdDlyTble=horzcat(mgdDlyTble,tempTbl);
        if dmnStats
            for itrDm=1:length(StatDomains)
                tempTbl=table('Size',[1,length(dlyVarNames)-NumVarDly],'VariableTypes',dlyVarTypes((NumVarDly+1):end),...
                    'VariableNames',StatDomains(itrDm)+"_"+dlyVarNames((NumVarDly+1):end));
                tempTbl.Properties.VariableNames=tempTbl.Properties.VariableNames+"_"+itrRem;
                tempTbl{1,:}=NaN; %fill empty table with NaN
                mgdDlyTble=horzcat(mgdDlyTble,tempTbl);
            end
        end
    end
end

if  numValidDays >=1
    
    subjctT=table(subjctID,QC_Status,qcBatch,Sensor_Errs,'VariableNames',sbjctVarNames);
    smmryT=table(numDays,numValidDays,sum(workDays(finValidDays)),sum(offDays(finValidDays)),'VariableNames',varN_Smry);
    
    % generate average tables
    avgDlyVals=round(mean(dlyTable{finValidDays,(NumVarDly+1):end},1,'omitnan'),Settings.prec_dig_min);
    avgDlyTbl=array2table(avgDlyVals,'VariableNames',dlyVarNames((NumVarDly+1):end)+"_Avg");
    if dmnStats
        for itrDm=1:length(StatDomains)
            avgDmVarN=StatDomains(itrDm)+"_"+dlyTblDmns{itrDm}.Properties.VariableNames+"_Avg";
            vagDmVals=round(mean(dlyTblDmns{itrDm}{finValidDays,:},1,'omitnan'),Settings.prec_dig_min);
            tempTbl=array2table(vagDmVals,'VariableNames',avgDmVarN);
            avgDlyTbl=horzcat(avgDlyTbl,tempTbl);
        end
    end
    if isempty(fnlPrPSTbl)
        fnlPrPSTbl=horzcat(subjctT,smmryT,mgdDlyTble,avgDlyTbl);
    else
        fnlPrPSTbl=vertcat(fnlPrPSTbl,horzcat(subjctT,smmryT,mgdDlyTble,avgDlyTbl));
    end
end
end


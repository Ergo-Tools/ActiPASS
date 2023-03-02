function [status,tblBedtime,aktFull,logicBD,logicSlpInt] = calcBedtime(Settings,subjectID,diaryStrct,timeFull,aktFull,Acc,Fs,figW,figH)
% Calculate bedtime by filtering Liying (or consider the diary defined bedtimes) and calculate sleep within bedtime
%
%  %%Inputs %%%%%%%%%%%%%%%%%
% Settings [struct] - The main settings structure
% SubjectID [string] - The ID - used for debug printing/visualizations
% diaryStruct [struct] - The diary data structure for the given ID. See below for details
% timeFull[datenum - n] - The times given at 1s epoch -complete data for all days
% aktFull [double-n] - Full Activity vector given at 1s epoch for all days
% Acc [double - nx4] - Acc matrix including time
% Fs - sample interval
% figW, figH - debug figure width, height

% %%Outputs%%%%%%%%%%%%%%%%%%%%
% status - [string] - execution status string
% tblBedtime - [table] - the bedtime and sleep parameter table
% aktFull [double-n] - Full Activity vector given at 1s epoch for all days
% logicBD [double-n] - A logical vector given at 1s epoch representing bedtime status
% logicSlpInt [double-n] - A logical vector given at 1s epoch representing sleep-interval status

% %%diary-structure%% example - diary structure is used only to find diary defined night/bed
%  diaryStrct.ID - subjectID ;
%  diaryStrct.Ticks - all transitions times as Matlab datenum;
%  diaryStrct.Events - all diary events names (work, leisure etc);
%  diaryStrct.Comments - all comments for each diary event
%  diaryStrct.StartT- the diary defined data start time;
%  diaryStrct.StopT - diary defined data stop time;
%  diaryStrct.RefTs - standing reference times defined in diary;
%  diaryStrct.rawData - the raw diary data for this subjectID as a table (including invalid entries)


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

lenLieFilt=Settings.BDMINLIET*60; % minimum accepted bedtime when start/stop is a lying bout
lenAktFilt=Settings.BDMAXAKTT*60; % maximum active gap within a given bedtime
VLongSitBt=Settings.BDVLONGSIT*60; % very-long-sit bouts to consider for bedtime expanding and also minimum bedtime length when start/stop is not a lying bout (240*60)
maxDiffD=4; % when comparing auto and diary bedtimes, maximum allowed differance of midpoint of bedtime (hrs)
indvDirOut="IndividualOut"; % individual output directory

visualizeBD=strcmpi(Settings.VISUALIZE,"extra");

% find the time step for visualizing activities & ENMO based on figure size
visStep=round(24*3600/figW);% the shortest possible odd stepSize is 61s for 1440 pixels

%define output table vartypes and varnames

varNames=["ID","Method","Flag","Start","End","Duration","DiaryStart","DiaryStartDiff","DiaryEnd","DiaryEndDiff","DiaryDurDiff","SleepOnset",...
    "FinalSleep","MidSleep","SleepInterval","TotalSleep","AwakeIndx","NumAwakes","SleepLatency","WASO"];
varTypes=repmat("string",size(varNames)); %all variables are defined as string to keep formatting while saving

% Define activity types(add another activity called "Bed" to the activity vector for visualizing bedtime and activities)
actvtTxts=["NW","Lie","Sit","Stand", "Move", "Walk", "Run","Stair", "Cycle","Other","SlpInBD","SlpOutBD","Bed"];
% predefined activity colours
actvtColors={'Gray','Lavender','Yellow', 'LimeGreen', 'DarkGreen', 'DarkOrange', 'Red','Cornsilk',...
    'Purple','Sienna','DodgerBlue','Aquamarine','DeepSkyBlue'};

% actvtColors={'WhiteSmoke','DarkTurquoise','Yellow','SeaGreen','YellowGreen','DodgerBlue','BlueViolet',...
%    'HotPink','LightPink','DarkOrange','DarkSLateBlue','DeepSkyBlue'};


%evaluation version text
evalWTxt=" - ActiPASS Beta v"+Settings.Version+ " - for Evaluation purpose only";

try
    %convert datenum times to datetime
    timeFlDT=datetime(timeFull,'ConvertFrom','datenum');
    
    %prellocate bedtime and sleep-interval logical vectors
    logicBD=false(size(timeFull));
    logicSlpInt=false(size(timeFull));
    %define the directories to save distributions
    saveDir=fullfile(Settings.out_folder,indvDirOut,subjectID);
    
    if visualizeBD
        %The primary color-map for activities as rgb triplets (for plotting activities in colour)
        actvtColMap=cellfun(@rgb,actvtColors,'UniformOutput',false);
        actvtColMap=cell2mat(actvtColMap');
        
        
        
        % Create a figure title using SubjectID and date
        figTitle=subjectID+ " - Bedtime ("+ string(timeFlDT(1),"yy/MM/dd")+" - "+string(timeFlDT(end),"yy/MM/dd")+")";
        % create a figure with given width and height (figW,figH)
        figSlpAkt=figure('units','pixels','position',[0 0 figW figH],...
            'Name',subjectID,'NumberTitle','off','Visible','off');
        % assign the title to all subplots
        if ~Settings.EVALV
            sgtitle(figSlpAkt,figTitle,'FontSize',14,'Color','Blue');
        else
            sgtitle(figSlpAkt,figTitle+evalWTxt,'FontSize',13,'Color','Blue');
        end
    end
    %% find bedtime automatically or using diary
    % fiirst find diary bedtimes irrespective of Bedtime method
    % find indices of diary events matching 'bed' or 'night'
    iBdStarts=find(matches(diaryStrct.Events,["bed","bedtime","night"],"IgnoreCase",true));
    % dfeine the diary dedtime starts: bdDStarts
    bdDStarts=diaryStrct.Ticks(iBdStarts);
    % diary bedtime ends should be the next indices respectively
    iBdEnds=iBdStarts+1;
    %but if for some reason end of bedtime is not defined the end is considered to be the end of file
    if isempty(iBdStarts)
        
        bdDEnds=datetime([],[],[]);
    elseif length(diaryStrct.Ticks)>=iBdEnds(end)
        bdDEnds=diaryStrct.Ticks(iBdEnds);
    else
        bdDStarts(end)=[]; % remove this bedtime
        iBdEnds(end)=[];
        bdDEnds=diaryStrct.Ticks(iBdEnds);
    end
    %the number of diary bedtimes
    numDBedTs=length(bdDStarts);
    
    if  matches(Settings.BEDTIME,["auto1","auto2"],"IgnoreCase",true)
        % this is where automatic bedtime detection happens. It is done using a simple filtering of lying "auto1"
        if strcmpi(Settings.BEDTIME,"auto1")
            bedLgc=~bwareaopen(aktFull~=1,lenAktFilt);
            bedLgc=bwareaopen(bedLgc,lenLieFilt);
            
            % or somewhat complicated "auto2" bedtime algorithm
        elseif strcmpi(Settings.BEDTIME,"auto2")
            [bedLgc,bedFlags]=calcBedLgc(aktFull,timeFlDT,lenAktFilt,lenLieFilt,VLongSitBt);
            
            infoTxt=join(split(strip(string(num2str(bedFlags,2)))),",");
            % find indices of bedtime starts and stops
        end
        % find indices of bedtime starts and stops
        indBdStarts=find(diff([0,bedLgc])==1);
        indBdEnds=find(diff([0,bedLgc])==-1);
        % if for some reason last element of bedtime logic vector bedLgc is true
        % then length(indBdEnds) < length(indBdStarts)
        if length(indBdEnds) < length(indBdStarts)
            indBdEnds=[indBdEnds,length(bedLgc)];
        end
        
        
        %find bedtime starts
        bdStarts=timeFlDT(indBdStarts);
        %find bedtime starts
        bdEnds=timeFlDT(indBdEnds);
        
        %find bedtime durations
        % btDurs=bdEnds-bdStarts;
        %find the shortest
        % numFullDays=round(days(dataDT(end)-dataDT(1)));
    elseif strcmpi(Settings.BEDTIME,"diary")
        bdStarts=bdDStarts;
        bdEnds=bdDEnds;
        indBdStarts=zeros(length(bdStarts),1);
        indBdEnds=zeros(length(bdEnds),1);
        for itrBdD=1:length(bdStarts)
            indBdStart=find(timeFlDT>=bdStarts(itrBdD),1,'first');
            indBdEnd=find(timeFlDT<=bdEnds(itrBdD),1,'last');
            if ~isempty(indBdStart) && ~isempty(indBdEnd)
                indBdStarts(itrBdD)=indBdStart;
                indBdEnds(itrBdD)=indBdEnd;
            end
            
        end
        bdStarts(indBdStarts==0)=[];
        bdEnds(indBdStarts==0)=[];
        indBdEnds(indBdStarts==0)=[];
        indBdStarts(indBdStarts==0)=[];
        
    end
    numBedTs=length(bdStarts);
    % find the mid points of auto-bedtimes
    midBeds=bdStarts+(bdEnds-bdStarts)/2;
    
    %% calculating bedtime and sleep parameters
    tblBedtime=table('Size',[numBedTs,length(varNames)],'VariableTypes',varTypes,'VariableNames',varNames);
    
    % intializing visualizing activity data
    if visualizeBD
        % get a handle to the axes
        axComb=axes;
        
        %Initialise vectors to hold the line objects and the SleepStage texts
        linesBedLgc=gobjects(numBedTs,1);
        lblsBedLgc=strings(numBedTs,1);
        linesBedDLgc=gobjects(numDBedTs,1);
        lblsBedDLgc=strings(numDBedTs,1);
    end
    for itrL=1:numBedTs
        %find the start of bedtime
        bdStart=bdStarts(itrL);
        %find the end of current bedtime
        bdEnd=bdEnds(itrL);
        % the bedtime method (auto or diary)
        bdMethod=Settings.BEDTIME;
        % the duration of bedtime as a duration vector
        bdDur=bdEnd-bdStart;
        % if the bedtime method is diary
        if strcmpi(Settings.BEDTIME,"diary")
            diffStart=hours(0); %thereis no diff
            diffEnd=hours(0);%thereis no diff
            diffDur=hours(0);%thereis no diff
            bdDStart=bdStart;
            bdDEnd=bdEnd;
            bdFlag=0;
            % if the bedtime methosdi auto
        elseif matches(Settings.BEDTIME,["auto1","auto2"],"IgnoreCase",true)
            % if the differance of start bedtime is less than 4hrs we match auto bedtime to a diary bedtime
            %find middle point of this auto bedtime and each diary bedtimes
            midAutoBed=midBeds(itrL);
            midDBeds=bdDStarts+(bdDEnds-bdDStarts)/2;
            bdFlag=bedFlags(itrL,1);
            if any(abs(midAutoBed-midDBeds)< hours(maxDiffD))
                %find the relevant bedtime from the diary
                [~,iMin]=min(abs(midDBeds-midAutoBed));
                % find the diffs
                diffStart=bdDStarts(iMin)-bdStart;
                diffEnd=bdDEnds(iMin)-bdEnd;
                diffDur=(bdDEnds(iMin)-bdDStarts(iMin))-(bdEnd-bdStart);
                bdDStart=bdDStarts(iMin);
                bdDEnd=bdDEnds(iMin);
            else
                % if no relevant bedtimes found diffs are nan
                diffStart=hours(nan);
                diffEnd=hours(nan);
                diffDur=hours(nan);
                bdDStart=NaT;
                bdDEnd=NaT;
            end
        end
        indBDS=indBdStarts(itrL):indBdEnds(itrL); % the indices of current bedtime
        bdDT=timeFlDT(indBDS); % Crop the dataDT vector to current bedtime limits
        logicBD(indBDS)=true; %flag the bedtime in logical bedtime vector
        %run sleep algorithm for each bedtime
        if strcmpi(Settings.SLEEPALG,'In-Bed') || strcmpi(Settings.SLEEPALG,'InOut-Bed')
            if ~strcmpi(Settings.BEDTIME,"auto2") || (strcmpi(Settings.BEDTIME,"auto2") && bdFlag==1)
            indBdStartAcc=floor(find(Acc(:,1)>= timeFull(indBdStarts(itrL)),1,'first')/Fs)*Fs+1;
            % SkottesSlp algorithm expects exactly aktEvent*Fs elements in ACC matrix.
            % Therefore we have to create the eventEndIndx as follows
            indBdEndAcc=indBdStartAcc+(Fs*length(bdDT)-1);
            
            %skotte sleep function is called with opMode=2, which considers both sit and lie periods within bedtime
            Sleep = SkottesSlp(aktFull(indBDS),2,Acc(indBdStartAcc:indBdEndAcc,2:4),Fs,'Thigh');
            aktFull(indBDS(Sleep==0))=10;
            end
        end
        
        bdAkt=aktFull(indBDS); % Crop the activity vector to current bedtime limits
        
        %find the time sleep onset
        indSlpOnset=find(bdAkt==10,1,'first');
        slpOnset=bdDT(indSlpOnset);
        if isempty(slpOnset), slpOnset=NaT; end
        %find the time final sleep
        indFinalSlp=find(bdAkt==10,1,'last');
        finalSlp=bdDT(indFinalSlp);
        if isempty(finalSlp), finalSlp=NaT; end
        if ~isnat(finalSlp) && ~isnat(slpOnset)
            tWASO=sum(bdAkt(indSlpOnset:indFinalSlp)~=10 & bdAkt(indSlpOnset:indFinalSlp)~=0)/3600;
            midSleep=slpOnset+(finalSlp-slpOnset)/2;
        else
            tWASO=NaN;
            midSleep=NaT;
        end
        % flag the Sleep Interval in logical sleep-interval vector
        logicSlpInt(indBDS(indSlpOnset:indFinalSlp))=true;
        totalSlp=sum(bdAkt==10)/3600; % the total sleep time
        slpIntvl=hours(finalSlp-slpOnset); %sleep interval
        numAwakes = length(find(diff([bdAkt==10,0])==-1)); %find the number of awakes including the final awake
        awakeIndx=numAwakes/slpIntvl; %find the number of awakes per 1hour
        slpLtncy=minutes(slpOnset-bdStart); %sleep latency
        if isempty(slpLtncy), slpLtncy=minutes(nan); end
        
        %fill-in the bedtime parameters table
        tblBedtime{itrL,:}=[subjectID,bdMethod,string(bdFlag),string(bdStart,"yyyy-MM-dd HH:mm:ss"),string(bdEnd,"yyyy-MM-dd HH:mm:ss"),...
            string(bdDur),string(bdDStart,"yyyy-MM-dd HH:mm:ss"),string(diffStart),string(bdDEnd,"yyyy-MM-dd HH:mm:ss"),string(diffEnd),...
            string(diffDur),string(slpOnset,"yyyy-MM-dd HH:mm:ss"),string(finalSlp,"yyyy-MM-dd HH:mm:ss"),...
            string(midSleep,"yyyy-MM-dd HH:mm:ss"),string(slpIntvl),string(totalSlp),awakeIndx,numAwakes,string(slpLtncy),string(tWASO)];
        %% visualizing bedtime
        if visualizeBD
            
            % define the line colour
            if bdFlag~=-1
                lineC=rgb('DeepSkyBlue');
            else
                lineC=rgb('Khaki');
            end
            % create the X values line segments
            lineX=[bdStarts(itrL),bdEnds(itrL)];
            lineY=[1.12,1.12];
            linesBedLgc(itrL)=line(axComb,lineX,lineY,'Color',lineC,'LineWidth',20);
            lblsBedLgc(itrL)="Bed";
            txtTick(1)=text(axComb,bdStarts(itrL),1.13,"- "+string(bdStarts(itrL),"HH:mm"),'FontSize',6);
            txtTick(2)=text(axComb,bdEnds(itrL),1.13,"- "+string(bdEnds(itrL),"HH:mm"),'FontSize',6);
            txtTick(1).Rotation=90;
            txtTick(2).Rotation=90;
            
            %debug text
            if bdFlag~=0
                txtTick(5)=text(axComb,midBeds(itrL),1.12,"("+infoTxt(itrL)+")",'FontSize',6);
                txtTick(5).Rotation=90;
            end
        end
    end
    
    %% find sleep outside bedtimes
    if strcmpi(Settings.SLEEPALG,'InOut-Bed')
        indStartAcc=floor(find(Acc(:,1)>= timeFull(1),1,'first')/Fs)*Fs+1;
        % SkottesSlp algorithm expects exactly aktEvent*Fs elements in ACC matrix.
        % Therefore we have to create the eventEndIndx as follows
        
        indEndAcc=floor(find(Acc(:,1)<= timeFull(end),1,'last')/Fs)*Fs; %check this
        
        % also exclude all seconds flagged as bedtime (make them NW)
        %then call SkottesSlp with opMode=1 (it only considers lying times for sleep detection)
        SleepOBD = SkottesSlp(~logicBD.*aktFull,1,Acc(indStartAcc:indEndAcc,2:4),Fs,'Thigh');
        aktFull(SleepOBD==0)=11;
    end
    %% Plot diary bedtimes
    if visualizeBD
        
        %% processing activity vector for visualization
        % change aktFull vector offset by one (inorder to match against activity color vector)
        
        % use a moving-mode filter (using colfilt) to reduce the resolution of activity vector (for faster plotting)
        % aktFullVis = colfilt(aktFull+1,[1,visStep],'sliding',@mode);
        aktFullVis = modefilt(aktFull+1,[1,2*floor(visStep/2)+1],'replicate');
        
        % fix zero padding errors caused by colfilt
        % nonZeroFirst=find(aktFullVis~=0,1,'first');
        % nonZeroLast=find(aktFullVis~=0,1,'last');
        % if ~isempty(nonZeroFirst)
        %     aktFullVis(1:nonZeroFirst-1)=aktFullVis(nonZeroFirst);
        % end
        % if ~isempty(nonZeroLast)
        %     aktFullVis(nonZeroLast+1:end)=aktFullVis(nonZeroLast);
        % end
        
        % find the indices of activity transitions
        diffAkts=[find(diff([0,aktFullVis])~=0),length(aktFullVis)];
        % find the number of activity bouts (consecutive periods of the same activity)
        numAkt=length(diffAkts)-1;
        %Initialise vectors to hold the line objects and the Activity texts
        linesAkt=gobjects(numAkt,1);
        lblsAkt=strings(numAkt,1);
        for itrL=1:numAkt
            % define the line colour
            lineC=actvtColMap(aktFullVis(diffAkts(itrL)),:);
            % create the X values line segments
            lineX=[timeFlDT(diffAkts(itrL)),timeFlDT(diffAkts(itrL+1))];
            lineY=[1,1];
            linesAkt(itrL)=line(axComb,lineX,lineY,'Color',lineC,'LineWidth',100);
            lblsAkt(itrL)=actvtTxts(aktFullVis(diffAkts(itrL)));
        end
        
        allTicks=dateshift(timeFlDT(1),'start','day'):hours(3):dateshift(timeFlDT(end),'end','day');
        majorTicks=dateshift(timeFlDT(1),'start','day'):days(1):dateshift(timeFlDT(end),'end','day');
        axComb.XTick=majorTicks;
        axComb.XTickLabelRotation=90;
        axComb.TickDir = 'out';
        axComb.XMinorTick='on';
        axComb.XAxis.MinorTickValues=setdiff(allTicks,majorTicks);
        axComb.XGrid = 'on';
        axComb.XMinorGrid = 'on';
        
        
        if matches(Settings.BEDTIME,["auto1","auto2"],"IgnoreCase",true)
            for itrL=1:numDBedTs
                % define the line colour
                lineC=rgb('RoyalBlue');
                % create the X values line segments
                lineX=[bdDStarts(itrL),bdDEnds(itrL)];
                lineY=[1.2,1.2];
                linesBedDLgc(itrL)=line(axComb,lineX,lineY,'Color',lineC,'LineWidth',20);
                lblsBedDLgc(itrL)="D-Bed";
                txtTick(3)=text(axComb,bdDStarts(itrL),1.21,"- "+string(bdDStarts(itrL),"HH:mm"),'FontSize',6);
                txtTick(4)=text(axComb,bdDEnds(itrL),1.21,"- "+string(bdDEnds(itrL),"HH:mm"),'FontSize',6);
                txtTick(3).Rotation=90;
                txtTick(4).Rotation=90;
            end
        end
        
        
        %finalize figure with legends, ticks and labels
        
        if matches(Settings.BEDTIME,["auto1","auto2"],"IgnoreCase",true)
            ylim([0.9,1.4]);
            yticks([1,1.13,1.2]);
            yticklabels({'Activity','AutoBed','DiaryBed'});
            % set y-axis limits, ticks and labels
            lblsAkt=[lblsAkt;lblsBedLgc;lblsBedDLgc];
            linesAkt=[linesAkt;linesBedLgc;linesBedDLgc];
        elseif strcmpi(Settings.BEDTIME,"diary")
            ylim([0.9,1.4]);
            yticks([1,1.13]);
            yticklabels({'Activity','Diary-Bed'});
            % set y-axis limits, ticks and labels
            lblsAkt=[lblsAkt;lblsBedLgc];
            linesAkt=[linesAkt;linesBedLgc];
        end
        xticklabels(string(axComb.XTick,"yy/MM/dd"));
        
        % find the unique diary events and their indices
        [uniqLAkt,iUniqLAkt]=unique(lblsAkt,'stable');
        % create the legend labels for alldays plot
        linesAkt=linesAkt(iUniqLAkt);
        %apply the legends
        legend(axComb,linesAkt,uniqLAkt,'Location','eastoutside');
        
        % save bedtime figure
        % set(figSlpAkt, 'Color', 'w');
        exportgraphics(figSlpAkt,fullfile(saveDir,subjectID+" - bedtime.png"));
        % export_fig(figSlpAkt,fullfile(saveDir,subjectID+" - bedtime"),'-png','-r150','-p0.01');
        close(figSlpAkt);
    end
    % Save output to files
    writetable(tblBedtime,fullfile(saveDir,subjectID+" - bedtime.csv"));
    status='OK';
catch ME
    % if an exception occur assign status with error details
    status=getReport(ME,'extended','hyperlinks','off');
    logicBD=[];
    logicSlpInt=[];
    tblBedtime=[];
end

end


function status = VisualizeActvts(Settings,batchDir,qcDirOutP,Acti4QCTbl,dataVis,eventsVis,histMatrix,dailyTable,visInfo,evntHist,drivingT,warnFID)
%VisualizeActvts Visualize activities and generate histograms and pie-charts
%   Detailed explanation goes here

% Copyright (c) 2021-2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the Actipass repository (https://github.com/Ergo-Tools/ActiPASS).

status=''; % a non empty status message is returned when errors occur
maxPlotDays=10; % maximum number of days to plot in QualityCheck figure

% scale ENMO depending on file-type
if ismember(visInfo.ftype,[1,2])
    scaleENMO=2.5; % scale the ENMO vector to fill the plots
elseif ismember(visInfo.ftype,[3,4,5])
    scaleENMO=3.0; % scale the ENMO vector to fill the plots
else
    scaleENMO=3.0; % scale the ENMO vector to fill the plots
end

indvDirOut="IndividualOut"; % individual output directory
figW=visInfo.figW; % width of weekly and histogram figure (QC figure uses full monitor width)
figH=visInfo.figH; % height of weekly and histogram figure (QC figure uses full monitor height)

excldSettings={'PRINTCOMMNTS','ADVOPTIONS','VISUALIZE','INT_ALG','PIECHARTS','CheckSlpInt','histgStep','EVALV','LAB',...
    'histgMinDur','EXTERNFUN','STATDOMAINS','StatMtchMode','DBedAsLeis','statsIgnoreQC','statNumDays','TRANSPORT',...
    'statSlctDays','StatsVldD','FilterTAI','WalkMET','CADPMIN','TblFormat','genBouts','boutBreak','boutThresh',...
    'varsBout','minWlkDur','maxOtherDur','maxStairDur','maxKneelDur'};

% predefined activities
if strcmpi(Settings.LIEALG,"off")
    sitLBL="Sit/Lie";
else
    sitLBL="Sit";
end
actvtTxts=["NW","Lie",sitLBL,"Stand", "Move", "Walk", "Run","Stair", "Cycle","Other","SlpIBD","LieStill","Kneel"];
dlTActTxt=["timeNW","timeLie","timeSit","timeStand","timeMove","timeWalk","timeRun","timeStair",...
    "timeCycle","timeOther","timeSlpInBD","timeLieStill","timeKneel"];
% predefined activity colours
%actvtColors={'WhiteSmoke','DarkTurquoise','Yellow','SeaGreen','YellowGreen','DodgerBlue','BlueViolet','HotPink','LightPink','DarkOrange','DarkSLateBlue'};
actvtColors={'Gray','Lavender','Yellow', 'LimeGreen', 'DarkGreen', 'DarkOrange', 'Red','Cornsilk', 'Purple','Sienna','DodgerBlue','Aquamarine','Fuchsia'};
colorsBDSlp={'White','PaleVioletRed','CornflowerBlue'};
emptyActCol=rgb('White'); % to be used with empty daily plots
% predefined diary events
evntTxts=["","ND","NE","Work","Leisure","Night"];
% predefined diary events colours
evntColors={'GhostWhite','Gainsboro','Gold','SeaGreen','Bisque','RoyalBlue'};
% use colours from 'colurcube' colormap for additional unknown events
evntColsUnknwn=brewermap(12,'Set3');
% colour of trunk inclination line
trnkCol=[rgb('LightSlateGray'),0.4]; % colour with alpha channel
% colour of calf-angle line
calfCol=[rgb('LightSlateGray'),0.4]; % colour with alpha channel
% the width of visualization lines
visLineWdth=3;
% the height of activity visualization patches
visPtchHght=0.7;

% the y-location of evaluation warning text
visEvalWY=0.4;
% the evaluation version warning
evalWTxt="Actipass Beta v"+Settings.Version+ " - for Evaluation purpose only";
% the y-location of steps-count text
visDStatY=-0.08;
% the names of the days
dayNames=["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"];

% map for changing day order from Sunday=1(Matlab) to Monday=1 order
dayOrder=[6,0,1,2,3,4,5];

persistent histGWkds histGWkEnds numGWkds numGWkEnds numSubjects numGskpdWkDs numGskpdWkEndDs;

try
    %% Initialising
    % load various options
    SubjectID=Acti4QCTbl.SubjectID(1);
    saveDir=fullfile(Settings.out_folder,indvDirOut,SubjectID);
    PIECHARTS=Settings.PIECHARTS;
    c_trnk=visInfo.c_trnk; % trunk inclination column number in dataVis matrix
    c_calf=visInfo.c_calf; % calf-angle column number in dataVis matrix
    c_tmp=visInfo.c_tmp; % temperature if exist column number in dataVis matrix
    
    % rescale ENMO values by ratio scaleENMO and clip at a maximum given by visPtchHght
    dataVis(:,3)=dataVis(:,3)*scaleENMO;
    dataVis(dataVis(:,3)>visPtchHght-0.1,3)=visPtchHght-0.1;
    
    
    % if temperature data exists, rescale to fit within activity patch rectangles
    if c_tmp~=0
        temp99pcnt=prctile(dataVis(:,c_tmp),99); %95th pcntile of temp
        temp5pcnt=prctile(dataVis(:,c_tmp),5); %5th pcntile of temp
        dataVis(dataVis(:,c_tmp)<temp5pcnt,5)=temp5pcnt; % clip the lowest temperature at 5th percentile
        dataVis(dataVis(:,c_tmp)>temp99pcnt,5)=temp99pcnt; % clip the highest temperature at 99th percentile
        dataVis(:,c_tmp)=(dataVis(:,c_tmp)-temp5pcnt)/(temp99pcnt-temp5pcnt)*(visPtchHght-0.1); % scale the values to be within [0,visPtchHght] range
    end
    
    % if trunk inclination data data exists, rescale to fit within activity patch rectangles
    if c_trnk~=0
        dataVis(:,c_trnk)=dataVis(:,c_trnk)/(pi)*(visPtchHght-0.1); % scale the values to be within [0,visPtchHght] range
    end

    % if trunk inclination data data exists, rescale to fit within activity patch rectangles
    if c_calf~=0
        dataVis(:,c_calf)=dataVis(:,c_calf)/(180)*(visPtchHght-0.1); % scale the values to be within [0,visPtchHght] range
    end

    %convert datenum times to datetime
    dataDT=datetime(dataVis(:,1),'ConvertFrom','datenum');
    % visStep=round(mean(diff(dataVis(:,1)))*86400);
    
    %The primary color-map for activities as rgb triplets
    actvtColMap=cellfun(@rgb,actvtColors,'UniformOutput',false);
    actvtColMap=cell2mat(actvtColMap');
    
    %The color-map for diary events as rgb triplets
    bDSlpColMap=cellfun(@rgb,colorsBDSlp,'UniformOutput',false);
    bDSlpColMap=cell2mat(bDSlpColMap');
    
    %The color-map for bedtime-sleep as rgb triplets
    eventColMap=cellfun(@rgb,evntColors,'UniformOutput',false);
    eventColMap=cell2mat(eventColMap');
    
    %find the 00.00hrs of the day corresponding to start of data.
    startDay=dateshift(dataDT(1),'start','day');
    %find the midnight of the day corresponding to end of data
    endDay=dateshift(dataDT(end),'start','day');
    
    % if a the end-time is on 00hrs, then the end-day should be one day prior
    if endDay==dataDT(end)
        endDay=endDay-days(1);
    end
    
    % the days for visualization (where there's data)
    visDays=startDay:endDay;
    
    % find the number of days
    numDays=length(visDays);
    
    if numDays>maxPlotDays
        maxPlotDays=8;
    else
        maxPlotDays=max(8,numDays);
    end
    
    wkDayStart=dayOrder(day(startDay,'dayofweek'));
    numWeeks=ceil((wkDayStart+numDays)/7);
    
    numQCFigs=ceil(numDays/maxPlotDays);
    figsQC=gobjects(numQCFigs,1);
    axsWkly=gobjects(numWeeks,7); % axes handles in weekly plots
    % axes handles for QC plot. maximum maxPlotDays +1 for warnings
    axsQC=gobjects(numDays,1);
    figWks=gobjects(numWeeks,1); % figure handles for weekly plots
    figTitles=strings(numWeeks,1); % figure names as strings
    
    %% Activity figures (single all days figure and weekly figures)
    for itrWk=1:numWeeks
        % Create a figure title using SubjectID, year and week number
        figTitles(itrWk)=SubjectID+" - "+year(startDay)+" - Week "+(week(startDay)+itrWk-1);
        % create a figure with given width and height (figW,figH)
        figWks(itrWk)=figure('units','pixels','position',[0 0 figW figH],...
            'Name',figTitles(itrWk),'NumberTitle','off','Visible','off');
        %figWks(itrWk)=figure('units','normalized','position',[0 0 1 1],...
        %    'Name',figTitles(itrWk),'NumberTitle','off','Visible','off');
        % assign the title to all subplots
        sgtitle(figWks(itrWk),figTitles(itrWk),'FontSize',12);
        %iterate through every weekday
        for itrDay=1:7
            % find the original day number starting from startDay
            dayNum=(itrWk-1)*7+itrDay-wkDayStart;
            % create a subplot for each day
            axsWkly(itrWk,itrDay)=subplot(7,1,itrDay);
            axsWkly(itrWk,itrDay).FontSize=6;
            % check whether current day has data (because we always start from Monday)
            if dayNum <1 || dayNum >numDays
                xticks(axsWkly(itrWk,itrDay),[]);
                % Use  the day name as the y-label in each subplot
                yticklabels(axsWkly(itrWk,itrDay),[' ',dayNames(itrDay)]);
                % rotate the text to vertical orientation
                ytickangle(axsWkly(itrWk,itrDay),90);
            end
        end
    end
    
    % create a figure to plot all days
    % and display it in the default monitor maximized using normalized units
    %figHAll=round((figH-40)*min(numDays,maxPlotDays)/7)+40;
    %figAll=figure('units','pixels','position',[0 0 figW figHAll],'Name',...
    %strcat(SubjectID,'-Activity'),'NumberTitle','off','Visible','off');
    
    for itrQCF=1:numQCFigs
        figsQC(itrQCF)=figure('units','normalized','OuterPosition',[0 0 1 1],'Name',...
            sprintf('%s - QC Fig. %d',SubjectID,itrQCF),'NumberTitle','off','Visible','off');
        % the title of the figure for all subplots
        sgtitle(figsQC(itrQCF),sprintf('%s - QC Fig. %d of %d',Acti4QCTbl.Filename(1),itrQCF,numQCFigs),'Interpreter', 'none');
    end

    % handle array to hold VM plots for applying a legend later
    pAcc_QC=gobjects(numDays,1); % plot handles for ENMO plots in QualityCheck figure
    pAcc_wkly=gobjects(numDays,1); % plot handles for ENMO values in weekly figures
    pTemp_QC=gobjects(numDays,1); % plot handles for ENMO values in weekly figures
    pTrnk_QC=gobjects(numDays,1); % plot handles for trunk forward-bending angle in weekly figures
    pCalf_QC=gobjects(numDays,1); % plot handles for calf angle in weekly figures
    
    % intialise cellarrays to hold handles of line-segments for each day
    % these handles will be later used for creating the legend
    l_wkly=cell(numDays,1);
    l_all=cell(numDays,1);
    l_labels=cell(numDays,1);
    
    for itr=1:numDays
        
        wkNum=ceil((wkDayStart+itr)/7);
        wkDay=itr-(wkNum-1)*7+wkDayStart;
        
        % find start and end indices of dataVis corresponding to the current day
        dayStartIndx=find(dataDT>=visDays(itr), 1,'first');
        dayEndIndx=find(dataDT<= visDays(itr)+1, 1,'last');
        % the time vector in datetime format
        dayDT=dataDT(dayStartIndx:dayEndIndx)';
        
        % find activities corresponding to current day
        dayAkts=dataVis(dayStartIndx:dayEndIndx-1,2);
        % the edges for activities
        % histEdgesAkt=linspace(0.5,11.5,12); % since the activities range from 1 to 11
        % cntAkts= histcounts(dayAkts,histEdgesAkt);
        %find the matching day from daily table
        dayIndDT=find(dateshift(datetime(dailyTable.Start),'start','day')==visDays(itr));
        
        timeAkts=dailyTable{dayIndDT,dlTActTxt};
        % find the indices of activity transitions
        diffAkts=find(diff([0;dayAkts;0])~=0);
        % find the number of activity bouts (consecutive periods of the same activity)
        numBts=length(diffAkts)-1;
        
        % find the Steps count and cadence from dailyTable
        stpsTxt="Stps: ["+dailyTable.Steps(dayIndDT)+","+round(dailyTable.avgCadence(dayIndDT))+"], NRise: "+round(dailyTable.nRises(dayIndDT));
        
        % create the X values of the vertices
        % create only one patch for each transition of activities (filtered)
        ptchX=[dayDT(diffAkts(1:end-1));dayDT(diffAkts(2:end));dayDT(diffAkts(2:end));dayDT(diffAkts(1:end-1))];
        % create the Y values of the vertices
        ptchY=[zeros(1,numBts);zeros(1,numBts);ones(1,numBts)*(visPtchHght-0.1);ones(1,numBts)*(visPtchHght-0.1)];
        % find the activity for each patch object
        btAkts=dayAkts(diffAkts(2:end)-1);
        %find unique activities
        uniqAkts=unique(btAkts);
        % generate patch color indices 'ptchC'
        btMap=zeros(length(actvtTxts),1);
        btMap(uniqAkts)=1:length(uniqAkts);
        ptchC=btMap(btAkts);
        colrBarLbls=actvtTxts(uniqAkts)+repmat(": ",1,length(uniqAkts))+...
            round(timeAkts(uniqAkts),1)+ repmat("h, ",1,length(uniqAkts))+...
            round(timeAkts(uniqAkts)/24*100)+repmat("%",1,length(uniqAkts));

        % QualityCheck Plot - plot activities in colors using fill and add a colorbar
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % set the correct QCfigure as current
        set(0,'CurrentFigure',figsQC(ceil(itr/maxPlotDays)));
        curSPlot=itr-(ceil(itr/maxPlotDays)-1)*maxPlotDays;
        
        % create a subplot for the day
        axsQC(itr)=subplot(maxPlotDays,5,5*(curSPlot-1)+(1:4));
        axsQC(itr).FontSize=7;
        % assgn the unique colormap to the axis
        colormap(axsQC(itr),actvtColMap(uniqAkts,:));
        % hold is on for fill
        hold(axsQC(itr),'on');
        fill(axsQC(itr),ptchX,ptchY,ptchC,'EdgeColor','none');
        %correctly place the colorbar ticks and labels
        segOffst=(length(uniqAkts)-1)/length(uniqAkts)/2;
        colbar_tks=linspace(1+segOffst,length(uniqAkts)-segOffst,length(uniqAkts));
        if length(uniqAkts)>9
            colbarFontSz=5.5;
        else
            colbarFontSz=6.5;
        end
        %plot the colorbar legend for activities
        colorbar(axsQC(itr),'Ticks',colbar_tks,'TickLabels',colrBarLbls,'FontSize',colbarFontSz);
        
        % plot the ENMO values withing activity patches
        pAcc_QC(itr)=plot(axsQC(itr),dayDT,dataVis(dayStartIndx:dayEndIndx,3),'-k','LineWidth',1);
        
        % plot temperature curve
        if c_tmp~=0
            % plot the temperature as a red dottet line
            pTemp_QC(itr)=plot(axsQC(itr),dayDT,dataVis(dayStartIndx:dayEndIndx,c_tmp),'--r','LineWidth',1);
        end
        
        if c_trnk~=0
            % plot the trunk inclination as a colour coded line
            % jet_cols=jet(256);
            % tl_y=repmat(visPtchHght,size(dayDT)); % y-values are fixed at height visPtchHght
            % normalize trunk inclination angle as colour of trunk inclination line
            % cl_v=dataVis(dayStartIndx:dayEndIndx,c_trnk)'/(2*pi)*256;
            % cl_v=jet_cols(round(cl_v*255)+1,:);
            %cData=zeros(2,length(dayDT),3);
            %cData(1,:,:)=cl_v;
            %cData(2,:,:)=cl_v;
            %pTrnk_QC(itr)= surface(axsQC(itr),[dayDT;dayDT],[tl_y;tl_y],zeros(2,length(dayDT)),[cl_v;cl_v],'facecol','no','edgecol','interp','linew',2);
            pTrnk_QC(itr)=plot(axsQC(itr),dayDT,dataVis(dayStartIndx:dayEndIndx,c_trnk),'-', 'Color',trnkCol,'LineWidth',2);
        end
        if c_calf~=0
            % plot the calf inclination as a colour coded line
            pCalf_QC(itr)=plot(axsQC(itr),dayDT,dataVis(dayStartIndx:dayEndIndx,c_calf),'-', 'Color',calfCol,'LineWidth',2);
        end
        % Set limits, labels an ticks for weekly plots
        axsQC(itr).XLim=[visDays(itr),visDays(itr)+1];
        axsQC(itr).XTick=linspace(visDays(itr),visDays(itr)+1,13);
        axsQC(itr).XAxis.MinorTickValues = linspace(visDays(itr)+hours(1),visDays(itr)+1-hours(1),12);
        %axsQC(itr).XAxis.TickLabels =datestr(axsQC(itr).XTick,'HH');
        axsQC(itr).TickLength = [0 0];
        axsQC(itr).XGrid = 'on';
        axsQC(itr).XMinorGrid = 'on';
        axsQC(itr).Layer = 'top';
        axsQC(itr).YTick=[0,(visPtchHght+0.1)/2,(visPtchHght+0.2)];
        axsQC(itr).YTickLabelRotation=90;
        %ylabel(axsQC(itr),dayNames(wkDay));
        axsQC(itr).YTickLabel=[" ",dayNames(wkDay)];
        % add the steps count and avg speed to the plot
        text(axsQC(itr),visDays(itr)+1.018,visDStatY,stpsTxt,'FontSize',colbarFontSz);
        if Settings.EVALV
            % add an evaluation version warning text to each plot
            text(axsQC(itr),visDays(itr)+0.4,visEvalWY,evalWTxt,'FontSize',colbarFontSz,'Color','red');
        end
        
        % Weekly Plot - plot activities in colors in weekly figures
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % replotting instead of copying axes because it's faster
        % assgn the unique colormap to the axis
        colormap(axsWkly(wkNum,wkDay),actvtColMap(uniqAkts,:));
        hold(axsWkly(wkNum,wkDay),'on'); % hold is on for fill
        fill(axsWkly(wkNum,wkDay),ptchX,ptchY,ptchC,'EdgeColor','none');
        segOffst=(length(uniqAkts)-1)/length(uniqAkts)/2;
        colbar_tks=linspace(1+segOffst,length(uniqAkts)-segOffst,length(uniqAkts));
        %plot the colorbar legend for activities
        colorbar(axsWkly(wkNum,wkDay),'Ticks',colbar_tks,'TickLabels',colrBarLbls,'FontSize',colbarFontSz);
        
        % plot the ENMO values withing activity patches
        pAcc_wkly(itr)=plot(axsWkly(wkNum,wkDay),dayDT,dataVis(dayStartIndx:dayEndIndx,3),'Color','k','LineWidth',1);
        % Set limits, labels an ticks for weekly plots
        axsWkly(wkNum,wkDay).XLim=[visDays(itr),visDays(itr)+1];
        axsWkly(wkNum,wkDay).XTick=linspace(visDays(itr),visDays(itr)+1,13);
        axsWkly(wkNum,wkDay).XAxis.MinorTickValues = linspace(visDays(itr)+hours(1),visDays(itr)+1-hours(1),12);
        %axsWkly(wkNum,wkDay).XAxis.TickLabels =datestr(axsQC(itr).XTick,'HH');
        %axsWkly(wkNum,wkDay).XLabel.String = datestr(visDays(itr),29);
        axsWkly(wkNum,wkDay).TickLength = [0 0];
        axsWkly(wkNum,wkDay).XGrid = 'on';
        axsWkly(wkNum,wkDay).XMinorGrid = 'on';
        axsWkly(wkNum,wkDay).Layer = 'top';
        axsWkly(wkNum,wkDay).YTick=[0,(visPtchHght)/2,(visPtchHght+0.1)];
        axsWkly(wkNum,wkDay).YTickLabelRotation=90;
        %ylabel(axsWkly(wkNum,wkDay),dayNames(wkDay));
        axsWkly(wkNum,wkDay).YTickLabel=[" ",dayNames(wkDay)];
        % add the steps count and avg speed to the plot
        text(axsWkly(wkNum,wkDay),visDays(itr)+1.02,visDStatY,stpsTxt,'FontSize',colbarFontSz);
        
        %find bedtime and sleep-int values corresponding to current day
        valsBDSlp=dataVis(dayStartIndx:(dayEndIndx-1),4);
        diffBDSlp=find(diff([-1;valsBDSlp;-1])~=0);
        %iterate through each transitions of bedtime and sleep
        for itrBDSlp=1:(length(diffBDSlp)-1)
            % endpoints of the event visualization line
            lineXBDSLp=[dayDT(diffBDSlp(itrBDSlp)),dayDT(diffBDSlp(itrBDSlp+1))];
            % line is drawn at y=visPtchHght+0.1
            lineYBDSlp=[visPtchHght-0.05,visPtchHght-0.05];
            
            switch valsBDSlp(diffBDSlp(itrBDSlp))
                case 2
                    lineCBDSlp=[bDSlpColMap(3,:),0.5]; %2022-10-19 use the same colour as sleep-interval but with transparent level of 0.5
                    lblBDSlp="*Bed";
                case 11
                    lineCBDSlp=bDSlpColMap(3,:);
                    lblBDSlp="*Sl.In.";
                otherwise
                    lineCBDSlp=bDSlpColMap(1,:);
                    lblBDSlp="";
            end
            if valsBDSlp(diffBDSlp(itrBDSlp))~=0
                %plot a line representing bedtime and sleep in QC and weekly graphs
                l_all{itr}=[l_all{itr},line(axsQC(itr),lineXBDSLp,lineYBDSlp,'Color',lineCBDSlp,'LineWidth',visLineWdth)];
                l_wkly{itr}=[l_wkly{itr},line(axsWkly(wkNum,wkDay),lineXBDSLp,lineYBDSlp,'Color',lineCBDSlp,'LineWidth',visLineWdth)];
                % aggregate event names to be used in creating a legend
                l_labels{itr}=[l_labels{itr},lblBDSlp];
            end
        end
        
        if ~isempty(drivingT)
            % plot vehicle driving line
            % find driving segments for current day
            midDT= drivingT.Start+(drivingT.Stop-drivingT.Start)/2;
            drvSegsInds=find(dayDT(1)<=midDT & dayDT(end)>= midDT & drivingT.Transport=="Yes");
            if ~isempty(drvSegsInds)
                for itrDSeg=1:length(drvSegsInds)
                    lineXDrv=[max(dayDT(1),drivingT.Start(drvSegsInds(itrDSeg))),min(dayDT(end),drivingT.Stop(drvSegsInds(itrDSeg)))];
                    lineYDrv=[visPtchHght/2,visPtchHght/2];
                    line(axsQC(itr),lineXDrv,lineYDrv,'Color','red','LineWidth',visLineWdth);
                end
            end
        end
        
        if Settings.EVALV
            % add an evaluation version warning text to each plot
            text(axsWkly(wkNum,wkDay),visDays(itr)+0.4,visEvalWY,evalWTxt,'FontSize',colbarFontSz,'Color','red');
        end
    end
    
    % Diary event visualization
    
    % l_comments=strings(numDays,1);
    unknownEvents=[]; % vector to hold unknown events (known events in evntTxts)
    
    for itrEvnt=1:length(eventsVis)
        % find the day relevant to diary event
        dayNum=find(day(visDays,'dayofyear')==day(eventsVis(itrEvnt).start,'dayofyear'));
        % Counting workdays and leisure days for generating average work and leisure activity table
        
        if ~isempty(dayNum)
            
            % find the week number
            wkNum=ceil((wkDayStart+dayNum)/7);
            % find the week day
            wkDay=dayNum-(wkNum-1)*7+wkDayStart;
            % endpoints of the event visualization line
            lineX=[eventsVis(itrEvnt).start,eventsVis(itrEvnt).stop];
            % line is drawn at y=visPtchHght+0.1
            lineY=[visPtchHght+0.05,visPtchHght+0.05];
            % find the colour of current event for known events
            eventColIndx=find(strcmpi(eventsVis(itrEvnt).Event,evntTxts));
            if ~isempty(eventColIndx)
                % known event, find colour from eventColMap
                lineC=eventColMap(eventColIndx,:);
            else
                % an unknown event, assign colors from evntColsUnknwn colormap
                unknownEvents=unique([unknownEvents,lower(eventsVis(itrEvnt).Event)],'stable');
                indxUnknownClr=find(strcmpi(eventsVis(itrEvnt).Event,unknownEvents));
                indxUnknownClr=rem(indxUnknownClr-1,12)+1; % maximum 12 colours, reuse the same colors for more than 12 events
                % define the line colour
                lineC=evntColsUnknwn(indxUnknownClr,:);
            end
            
            
            % plot the Event visualization lines and keep the handles
            % make the line thicker inorder to print event comments inside lines
            %if Settings.PRINTCOMMNTS
            %    visLineWdth=6;
            %else
            %    visLineWdth=4.5;
            %end
            % plot event visualization lines and keep handles for creating legends
            l_wkly{dayNum}=[l_wkly{dayNum},line(axsWkly(wkNum,wkDay),lineX,lineY,'Color',lineC,'LineWidth',visLineWdth)];
            l_all{dayNum}=[l_all{dayNum},line(axsQC(dayNum),lineX,lineY,'Color',lineC,'LineWidth',visLineWdth)];
            
            % aggregate event names to be used in creating a legend
            l_labels{dayNum}=[l_labels{dayNum},eventsVis(itrEvnt).Event];
            
            
            %find the length of the even segment in correct units
            widthDsUnit = diff(ruler2num(lineX,axsWkly(wkNum,wkDay).XAxis));
            widthQCsUnit = diff(ruler2num(lineX,axsQC(dayNum).XAxis));
            
            % add Comments and ref. position text to Event line segments
            % uf text is too long (by checking theit extents) trim them
            % txtC=imcomplement(lineC);
            
            visTxt=" "+ eventsVis(itrEvnt).Ref+" "+ eventsVis(itrEvnt).Comment;
            txtQCs=text(axsQC(dayNum),lineX(1),visPtchHght+0.15,visTxt,'FontSize',7,'Margin',0.1);
            widthQCsTxt=txtQCs.Extent(3);
            if widthQCsTxt > widthQCsUnit
                txtQCs.String=extractBetween(txtQCs.String,1,max(floor(strlength(txtQCs.String)*widthQCsUnit/widthQCsTxt*0.93)-2,0));
            end
            
            if Settings.PRINTCOMMNTS
                txtWkly=text(axsWkly(wkNum,wkDay),lineX(1),visPtchHght+0.15,eventsVis(itrEvnt).Comment,'FontSize',6,'Margin',0.1);
                widthWklTxt=txtWkly.Extent(3);
                if widthWklTxt > widthDsUnit
                    txtWkly.String=extractBetween(txtWkly.String,1,max(floor(strlength(txtWkly.String)*widthDsUnit/widthWklTxt*0.93)-2,0));
                end
                % adjust yticklabel position (which shows name of the day)
                axsWkly(wkNum,wkDay).YTick=[0,(visPtchHght+0.1)/2,(visPtchHght+0.2)];
                axsWkly(wkNum,wkDay).YLim=[0,(visPtchHght+0.1)];
            end
        end
        
    end
    
    % Make a legend for diary events and ENMO plots in both weekly and QC figures
    for itr=1:numDays
        % find week and day numbers
        wkNum=ceil((wkDayStart+itr)/7);
        wkDay=itr-(wkNum-1)*7+wkDayStart;
        % find the unique diary events and their indices
        [uniqL,iUniqL]=unique(l_labels{itr});
        
        %only select handles of unique event visualization lines
        l_wkly{itr}=l_wkly{itr}(iUniqL);
        l_all{itr}=l_all{itr}(iUniqL);
        %apply the legends
        
        % create the legend labels for weekly plot
        legend(axsWkly(wkNum,wkDay),[pAcc_wkly(itr),l_wkly{itr}],["Acc.",uniqL],'Location','westoutside','Interpreter', 'none');
        % create the legend labels for QC plot
        h_mgd=pAcc_QC(itr);
        txt_mgd="Acc.";
        if c_tmp~=0
            h_mgd=[h_mgd,pTemp_QC(itr)];
            txt_mgd=[txt_mgd,"Temp"];
        end
        if  c_trnk~=0
            h_mgd=[h_mgd,pTrnk_QC(itr)];
            txt_mgd=[txt_mgd,"TrInc"];
        end
        if  c_calf~=0
            h_mgd=[h_mgd,pCalf_QC(itr)];
            txt_mgd=[txt_mgd,"ClfInc"];
        end
        legend(axsQC(itr),[h_mgd,l_all{itr}],[txt_mgd,uniqL],'Location','westoutside','Interpreter', 'none');
    end
    
    % Save weekly figures (QC Figures will be saved last (after histograms
    % and pie charts)
    % Iterate through weekly plots one more time before before saving insert legends to empty
    % plots and then save
    for itrWk=1:numWeeks
        %iterate through the days
        for itrDay=1:7
            %find the dayNum
            dayNum=(itrWk-1)*7+itrDay-wkDayStart;
            %check for empty plots
            if dayNum <1 || dayNum >numDays
                %adjust size and position to match other plots
                colormap(axsWkly(itrWk,itrDay),emptyActCol);
                colorbar(axsWkly(itrWk,itrDay),'Ticks',0.5,'TickLabels',"");
                legend(axsWkly(itrWk,itrDay),'Location','westoutside','Interpreter', 'none');
            end
        end
        % save weekly figure
        % set(figWks(itrWk), 'Color', 'w');
        if  any(strcmpi(Settings.VISUALIZE,["full","extra"]))
            exportgraphics(figWks(itrWk),fullfile(saveDir,figTitles(itrWk)+".png"));
        end
        % export_fig(figWks(itrWk),fullfile(saveDir,figTitles(itrWk)),'-png','-r150','-p0.01');
        %print(figWks(itrWk),fullfile(save_dir,figNames(itrWk)),'-dpng');
        close(figWks(itrWk));
    end
    
    %% weekday and weekend histograms and Pie charts
    % find number of histogram bins per day (default 24)

    % binsPerDay=size(histMatrix,1)/numDays; % find the number of histogram bins per day
    binsPerDay=(60*24/Settings.histgStep); % find the number of histogram bins per day
    histWkDays=zeros(binsPerDay,size(histMatrix,2));
    histWeekEnds=zeros(binsPerDay,size(histMatrix,2));
    % extra check to detect whether per/sec activity vector has repetitions (in this case there could be more than 3600sec per hr)
    % is this line needed now? Only unique seconds are brought forward in per/sec vectors now
    hrsWrng=find(sum(histMatrix,2)>3600*(24/binsPerDay)); % find the rows where sum of activity seconds is higher than expected
    histMatrix(hrsWrng,:)=histMatrix(hrsWrng,:)./sum(histMatrix(hrsWrng,:),2)*3600*(24/binsPerDay);
    
    % intialise the persistent variables if the fileTag is "first" or if they are not yet intialized 
    if strcmpi (visInfo.fileTag,'first') || size(histMatrix,2) ~= size(histGWkds,2)
        histGWkds=zeros(binsPerDay,size(histMatrix,2));
        histGWkEnds=zeros(binsPerDay,size(histMatrix,2));
        numGWkds=0;
        numGWkEnds=0;
        numGskpdWkDs=0;
        numGskpdWkEndDs=0;
        numSubjects=0;
    end
    numWkEnds=0;
    numWkds=0;
    skpdWkDays=0;
    skpdWkEndDays=0;
    for itr=1:numDays
        %iterate through the days
        wkNum=ceil((wkDayStart+itr)/7);
        wkDay=itr-(wkNum-1)*7+wkDayStart;
        histDay=histMatrix((binsPerDay*(itr-1)+1):binsPerDay*itr,:);
        % find the total recorded activity time except not-worn
        timeUseful=sum(histDay(:,2:end),'all')/3600;
        % if more than one hour of not worn time skip the day
        if timeUseful<Settings.histgMinDur && ismember(wkDay,[1,2,3,4,5])
            skpdWkDays=skpdWkDays+1;
            continue;
        elseif timeUseful<Settings.histgMinDur && ismember(wkDay,[6,7])
            skpdWkEndDays=skpdWkEndDays+1;
            continue;
        end
        if ismember(wkDay,[1,2,3,4,5])
            % aggregate the histogram counts for weekdays
            histWkDays=histWkDays+histDay;
            numWkds=numWkds+1;
        elseif ismember(wkDay,[6,7])
            % aggregate the histogram counts for holidays
            histWeekEnds=histWeekEnds+histDay;
            numWkEnds=numWkEnds+1;
        end
    end


    %normalise histograms to 60*(24/binsPerDay) minutes
    scaleWkds=max(sum(histWkDays,2));
    scaleWkEnds=max(sum(histWeekEnds,2));
    if scaleWkds~=0
        histWkDays= histWkDays*60*(24/binsPerDay)/scaleWkds;
    end
    if scaleWkEnds~=0
        histWeekEnds= histWeekEnds*60*(24/binsPerDay)/scaleWkEnds;
    end


    histGWkds=histGWkds+histWkDays;
    histGWkEnds=histGWkEnds+histWeekEnds;
    numGWkds=numGWkds+numWkds;
    numGWkEnds=numGWkEnds+numWkEnds;
    numGskpdWkDs=numGskpdWkDs+skpdWkDays;
    numGskpdWkEndDs=numGskpdWkEndDs+skpdWkEndDays;
    numSubjects=numSubjects+1;

    if numWkds>=1 || numWkEnds>=1
        % Create a figure title using SubjectID, year and week number
        dayStats.numWkds=numWkds;
        dayStats.numWkEnds=numWkEnds;
        dayStats.skpdWkDays=skpdWkDays;
        dayStats.skpdWkEndDays=skpdWkEndDays;
        titleHist=SubjectID+" - "+"Activity Histogram";
        ActHistP(Settings,histWkDays,histWeekEnds,dayStats,titleHist,saveDir);
    else
        status=sprintf('%s• Insufficient data for histograms.\n',status);
    end
    if PIECHARTS && (numWkds>=1 || numWkEnds>=1 || ~isempty(evntHist))
        % Create a figure title using SubjectID, year and week number

        ActPieP(Settings,evntHist,histWkDays,numWkds,histWeekEnds,numWkEnds,SubjectID,saveDir);
    else
        if PIECHARTS
            status=sprintf('%s• Insufficient data for pie-charts.\n',status);
        end
    end

    if strcmpi(visInfo.fileTag,'last') && (numGWkds>1 || numGWkEnds>1)
        titleGHist="Group Activity Histogram";
        dayStats.numWkds=numGWkds;
        dayStats.numWkEnds=numGWkEnds;
        dayStats.skpdWkDays=numGskpdWkDs; % total skipped weekdays in group histograms
        dayStats.skpdWkEndDays=numGskpdWkEndDs; % total skipped wkend days in group histograms
        ActHistP(Settings,histGWkds/numSubjects,histGWkEnds/numSubjects,dayStats,titleGHist,qcDirOutP);
    end
   
    %% Save the QC figures
    
    % Now generate QCTxts string which summarizes batch, settings, QCdata and
    % warnings and used to annotate the QCFigure
    QCTxts="\bf{Settings:}\rm"+newline; % intialise the textbox heading
    % copy Settings to visSettings and remove unimportant fields
    visSettings=Settings;
    
    %shorten file/dir paths for visualization
    out_folder=split(visSettings.out_folder,filesep);
    out_folder=out_folder(out_folder~="");
    %also add batch information to visualization
    Batch=split(batchDir,filesep);
    Batch=Batch(Batch~="");
    visSettings.out_folder=out_folder(end)+"; batch: "+Batch(end);
    
    thighAccDir=split(visSettings.thighAccDir,filesep);
    thighAccDir= thighAccDir(thighAccDir~="");
    visSettings.thighAccDir=thighAccDir(end);
    
    trunkAccDir=split(visSettings.trunkAccDir,filesep);
    trunkAccDir=trunkAccDir(trunkAccDir~="");
    visSettings.trunkAccDir=trunkAccDir(end);
    
    diary_file=split(visSettings.diary_file,filesep);
    visSettings.diary_file=diary_file(end);
    
    cal_file=split(visSettings.cal_file,filesep);
    visSettings.cal_file=cal_file(end);
    
    %     master_out=split(visSettings.master_out,filesep);
    %     master_out=master_out(master_out~="");
    %     visSettings.master_out=master_out(end);
    
    % remove trunk related fields if not used
    if strcmpi(Settings.TRUNKPOS,"off") 
        visSettings=rmfield(visSettings,intersect({'TRUNKPOS','TRUNKPREFIX','TRUNKSUFFIX','TRUNKFLIP','TRUNKROT',...
            'FORCESYNC','KEEPTRUNKNW','trunkAccDir','REFPOSTRNK','SAVETRNKD'},fieldnames(visSettings)));
    end
    if strcmpi(Settings.CALFPOS,"off")
        visSettings=rmfield(visSettings,intersect({'CALFPOS','CALFPREFIX','CALFSUFFIX',...
            'CALFFLIP','CALFROT','FORCESYNCCALF','KEEPCALFNW','calfAccDir','REFPOSCALF'},fieldnames(visSettings)));
    end
    if matches(Settings.TRUNKPOS,["front","back"],'IgnoreCase',true)
        % otherwise merge important fields with TRUNKPOS
        visSettings.TRUNKPOS=visSettings.TRUNKPOS+"; sync: "+visSettings.FORCESYNC+"; ref.p: "+visSettings.REFPOSTRNK;
        visSettings.TRUNKFLIP=visSettings.TRUNKFLIP+"; rot: "+visSettings.TRUNKROT+"; fixrot: "+visSettings.FLIPROTTRNK;
        visSettings.trunkAccDir=visSettings.trunkAccDir+"; prefix: "+visSettings.TRUNKPREFIX+"; suffix: "+visSettings.TRUNKSUFFIX;
        % remove the merged and unimportant fields
        visSettings=rmfield(visSettings,intersect({'TRUNKPREFIX','TRUNKSUFFIX','TRUNKROT',...
            'FLIPROTTRNK','FORCESYNC','KEEPTRUNKNW','REFPOSTRNK','SAVETRNKD'},fieldnames(visSettings)));
    end
    if strcmpi(Settings.CALFPOS,"on")
        % otherwise merge important fields with TRUNKPOS
        visSettings.CALFPOS=visSettings.CALFPOS+"; sync: "+visSettings.FORCESYNCCALF+"; ref.p: "+visSettings.REFPOSCALF;
        visSettings.CALFFLIP=visSettings.CALFFLIP+"; rot: "+visSettings.CALFROT+"; fixrot: "+visSettings.FLIPROTCALF;
        visSettings.calfAccDir=visSettings.calfAccDir+"; prefix: "+visSettings.CALFPREFIX+"; suffix: "+visSettings.CALFSUFFIX;
        % remove the merged and unimportant fields
        visSettings=rmfield(visSettings,intersect({'CALFPREFIX','CALFSUFFIX','CALFROT',...
            'FLIPROTCALF','FORCESYNCCALF','KEEPCALFNW','REFPOSTRNK','SAVETRNKD'},fieldnames(visSettings)));
    end
    %     %remove bedtime auto algorithm fields if not used
    %     if ~matches(Settings.BEDTIME,["auto1","auto2"],"IgnoreCase",true)
    %         visSettings=rmfield(visSettings,intersect({'BDMINLIET','BDMAXAKTT'},fieldnames(visSettings)));
    %     end
    % remove other fields not necessary for visualization
    visSettings=rmfield(visSettings,intersect(excldSettings,fieldnames(visSettings)));
    
    % merge fields (because of limited vertical space in QCfigure)
    visSettings.IDMODE=visSettings.IDMODE+"; idlength: "+visSettings.IDLENGTH;
    visSettings.TRIMMODE=visSettings.TRIMMODE+"; nwshortlim: "+visSettings.NWSHORTLIM+"; nwtrimactlim: "+visSettings.NWTRIMACTLIM+...
        "; nwtrimbuf: "+visSettings.NWTRIMBUF;
    visSettings.CALMETHOD=visSettings.CALMETHOD+"; addautocal: "+visSettings.ADDAUTOCAL;
    visSettings.CADALG=visSettings.CADALG+"; liealg: "+visSettings.LIEALG+"; sleepalg: "+visSettings.SLEEPALG;
    visSettings.BEDTIME=visSettings.BEDTIME+"; bdmaxaktt: "+visSettings.BDMAXAKTT+"; bdminliet: "+visSettings.BDMINLIET+...
        "; bdvlongsit: "+visSettings.BDVLONGSIT;
    visSettings.FLIPROTATIONS=visSettings.FLIPROTATIONS+"; flipped: "+visSettings.Flipped+"; rotated: "+visSettings.Rotated;
    % remove fields which are already merged with others
    visSettings=rmfield(visSettings,["IDLENGTH","LIEALG","SLEEPALG","NWSHORTLIM","NWTRIMACTLIM","NWTRIMBUF","ADDAUTOCAL","BDMINLIET",...
        "BDMAXAKTT","BDVLONGSIT","Flipped","Rotated"]);
    
    % reformat Settings structure data suitable to be annotated to the figure
    QCData=string(struct2cell(visSettings));
    QCNames=string(lower(fieldnames(visSettings)));
    QCData=QCNames+" : "+QCData;
    QCData=strjoin(QCData,'\n');
    QCTxts=QCTxts+strrep(strrep(QCData,'\','\\'),'_','\_');
    
    QCTxts=QCTxts+newline+newline+"\bf{QC Info:}\rm"+newline; % intialise the textbox heading
    QCData=string(table2cell(Acti4QCTbl(1,3:end)))';
    QCNames=string(Acti4QCTbl.Properties.VariableNames(3:end))';
    QCData=QCNames+" : "+fillmissing(QCData,'constant',"");
    QCData=strjoin(QCData,'\n');
    QCTxts=QCTxts+strrep(QCData,'_','\_');
    QCTxts=QCTxts+newline+newline+"\bf{Warnings:}\rm\color{orange}"+newline; % intialise the textbox string
    % now try to annotate the warning messages into the QC figure
    try
        % open the warning.txt file for current subject as as readonly
        % warnFID=fopen(fullfile(saveDir,SubjectID+" - warnings.txt"),'r');
        if isfile(fopen(warnFID)) % check warnFID is a valid file handle
            %curPos=ftell(warnFID);
            frewind(warnFID); % rewind to the start of file
            while ~feof(warnFID)
                
                %numLine=numLine+1;
                tLine=fgets(warnFID); % read the file line by line with newline characters
                if ~isnumeric(tLine) % if the file is empty fgts return -1
                    QCTxts = QCTxts+"• "+tLine;
                end
            end
            % fseek(warnFID,curPos,'bof');
            % fclose(warnFID); %close the file
        else
            status=sprintf('%s• Warnings from main program missing. File: "%s" not found.\n',status,SubjectID+" - Warnings.txt");
        end
    catch MFE
        status=sprintf('%s• %s.\n',status,MFE.message);
    end
    %append the status messages from current function to the warnTxt
    if ~isempty(status)
        QCTxts = QCTxts+string(status);
    end
    for itrQCF=1:numQCFigs
        % set the correct QCfigure as current
        set(0,'CurrentFigure',figsQC(itrQCF));
        % The last subplot is in the 5th column of QC figure
        axTxtBox=subplot(maxPlotDays,5,5*(1:maxPlotDays)');
        axTxtBox.Visible='off';
        txtBoxPos=axTxtBox.Position; % place the textbox at the same position as the subplot axes
        
        %fill the annotation textbox with warnTxt
        annotation(figsQC(itrQCF),'textbox',txtBoxPos,'String',QCTxts,'FontSize',7);
        
        % save QCFigure
        % set(figsQC(itrQCF), 'Color', 'w');
        exportgraphics(figsQC(itrQCF),fullfile(batchDir,sprintf('%s-QC-%d.png',SubjectID,itrQCF)));
        % export_fig(figsQC(itrQCF),fullfile(batchDir,sprintf('%s-QC-%d',SubjectID,itrQCF)),'-png','-r150','-p0.01');
        close(figsQC(itrQCF)); % close selected QCfigure
    end
    
catch ME
    % add exception message to the existing status text
    status=sprintf('%s• %s\n', status,getReport(ME,'extended','hyperlinks','off'));
end
% The histogram function
    function ActHistP(Settings,histMatWkdP,histMatWkEndsP,dayStatsP,titleHistP,saveDirP)
        % create a figure with given width and height (figW,figH)
        figHist=figure('units','pixels','position',[100 50 1280 720],...
            'Name',titleHistP,'NumberTitle','off','Visible','off');
        if Settings.EVALV
            titleHistPP=titleHistP+": "+evalWTxt;
        else
            titleHistPP=titleHistP;
        end
        % assign the title to all subplots
        sgtitle(figHist,titleHistPP);
        barX=(0:binsPerDay-1)*(24/binsPerDay);
        
        %plot the weekday histogram
        if dayStatsP.numWkds>1
            axWkd=subplot(2,1,1);
            %find activities with a duration of at least 1e-4
            validActvts=find(sum(histMatWkdP,1)>1e-4);
            % make sedentery activities negative in histograms
            histMatWkdP(:,[1:4,11,12])= -histMatWkdP(:,[1:4,11,12]);
            %plot the histogram as a stacked bar plot
            barWkd=bar(axWkd,barX,histMatWkdP(:,validActvts),1,'stacked','FaceColor','flat');
            % assign the CData of each activity bar to use correct activity colors
            for ibar=1:length(barWkd)
                barWkd(ibar).CData=actvtColMap(validActvts(ibar),:);
            end
            axWkd.XTick=barX;
            if length(barX) > 30
                xtickangle(axWkd,90);
            end
            axWkd.YTick=[-60,-40,-20,0,20,40,60]*(24/binsPerDay);
            axWkd.YTickLabel=string(abs(axWkd.YTick));
            axWkd.TickLength=[0,0];
            axWkd.TickDir='out';
            legend(axWkd,actvtTxts(validActvts),'Location','eastoutside','Interpreter', 'none');
            title(axWkd,sprintf('Weekdays (valid: %d, skipped: %d)',dayStatsP.numWkds,dayStatsP.skpdWkDays));
            ylabel(axWkd,'Duration (min)');
            xlabel(axWkd,'Time (h)');
        end
        %plot the weekend histogram
        if dayStatsP.numWkEnds>1
            axWkEnds=subplot(2,1,2);
            %find activities with a duration of at least 1e-4
            validActvts=find(sum(histMatWkEndsP,1)>1e-4);
            %make sedentery activities negative in histograms
            histMatWkEndsP(:,[1:4,11,12])= -histMatWkEndsP(:,[1:4,11,12]);
            %plot the histogram as a stacked bar plot
            barWkEnds=bar(axWkEnds,barX,histMatWkEndsP(:,validActvts),1,'stacked','FaceColor','flat');
            % assign the CData of each activity bar to use correct activity colors
            for ibar=1:length(barWkEnds)
                barWkEnds(ibar).CData=actvtColMap(validActvts(ibar),:);
            end
            axWkEnds.XTick=barX; % Xticks equal to histogram edges
            if length(barX) > 30
                xtickangle(axWkEnds,90); % if more than 30 bins, rotate xlabels
            end
            axWkEnds.YTick=[-60,-40,-20,0,20,40,60]*(24/binsPerDay);
            axWkEnds.YTickLabel=string(abs(axWkEnds.YTick));
            axWkEnds.TickLength=[0,0];
            axWkEnds.TickDir='out';
            legend(axWkEnds,actvtTxts(validActvts),'Location','eastoutside','Interpreter', 'none');
            title(axWkEnds,sprintf('Weekends (valid: %d days, skipped: %d days)',dayStatsP.numWkEnds,dayStatsP.skpdWkEndDays));
            ylabel(axWkEnds,'Duration (min)');
            xlabel(axWkEnds,'Time (h)');
        end
        % save histogram figure
        % set(figHist, 'Color', 'w');
        % export_fig(figHist,fullfile(saveDirP,titleHistP),'-png','-p0.01');
        if ~Settings.EVALV &&  any(strcmpi(Settings.VISUALIZE,["full","extra"]))
            exportgraphics(figHist,fullfile(saveDirP,titleHistP+".png"));
        end
        % save histogram data
        histTblWkds=cell2table(num2cell([barX',histMatWkdP]),'VariableNames',["Time (h)",actvtTxts]);
        histTblHolids=cell2table(num2cell([barX',histMatWkEndsP]),'VariableNames',["Time (h)",actvtTxts]);
        writetable(histTblWkds,fullfile(saveDirP,strcat(titleHistP,'-WeekDays.csv')));
        writetable(histTblHolids,fullfile(saveDirP,strcat(titleHistP,'-Weekends.csv')));
        close(figHist);
    end

% the PieChart function
    function ActPieP(Settings,evntHist,histMatWkdP,numWkdsP,histMatWkEndsP,numWkEndsP,SubjectP,saveDirP)
        titlePieP=SubjectP+" - "+"Activity Pie Charts";
        if Settings.EVALV
            titlePiePP=titlePieP+": "+evalWTxt;
        else
            titlePiePP=titlePieP;
        end
        
        if numWkdsP>0 || numWkEndsP>0 || ~isempty(evntHist)
            % find the total nuber of Pie Charts needed (make it even)
            totPieC=(numWkdsP>0) + (numWkEndsP>0) +length (evntHist);
            
            
            % make the total pie chants count even number
            if rem(totPieC,2)==1, totPieC=totPieC+1; end
            curChart=0;
            
            % fill-in missing time for each hour as 'Missing' activity (weekdays)
            missTWkd=60*(24/binsPerDay)-sum(histMatWkdP,2);
            missTWkd(missTWkd<0)=0;
            histMatWkdP=[histMatWkdP,missTWkd];
            % fill-in missing time for each hour as 'Missing' activity (holidays)
            missTWkEnds=60*(24/binsPerDay)-sum(histMatWkEndsP,2);
            missTWkEnds(missTWkEnds<0)=0;
            histMatWkEndsP=[histMatWkEndsP,missTWkEnds];
            %extend the activity colourmap and text label for unknown
            %activities
            actvtColMPie=[actvtColMap;rgb('white')];
            actvtTxtsPie=[actvtTxts,"Missing"];
            
            % create a figure with given width and height (figW,figH)
            figPie=figure('units','pixels','position',[100 50 1280 800],...
                'Name',titlePieP,'NumberTitle','off','Visible','off');
            % assign the title to all subplots
            sgtitle(figPie,titlePiePP);
            
            
            %plot the weekday pie chart
            if numWkdsP>0
                curChart=curChart+1;
                axWkd=subplot(totPieC/2,2,curChart);
                pieWkdX=sum(histMatWkdP,1);
                validActvts=find(pieWkdX>1e-4);
                pieWkd=pie(pieWkdX(validActvts));
                % intialise a string vector for legends
                legTxts=strings(length(validActvts),1);
                % assign correct activity colours to pie chart
                for iPie=1:length(validActvts)
                    pieWkd(2*iPie-1).FaceColor=actvtColMPie(validActvts(iPie),:);
                    legTxts(iPie)=sprintf('%s %.2f',actvtTxtsPie(validActvts(iPie)),pieWkdX(validActvts(iPie))/60);
                    pieWkd(2*iPie).Visible='off';
                end
                legPieWkd=legend(axWkd,legTxts,'Location','bestoutside','Interpreter', 'none');
                title(legPieWkd,'Activity Time (hrs)');
                title(axWkd,sprintf('Weekdays (%d days)',numWkdsP));
            end
            
            %plot the weekend pie chart
            if numWkEndsP>0
                curChart=curChart+1;
                axWkEnds=subplot(totPieC/2,2,curChart);
                pieWkEndsX=sum(histMatWkEndsP,1);
                validActvts=find(pieWkEndsX>1e-4); %valid if there is sufficient time
                pieWkEnds=pie(pieWkEndsX(validActvts));
                % intialise a string vector for legends
                legTxts=strings(length(validActvts),1);
                % assign correct activity colours to pie chart
                for iPie=1:length(validActvts)
                    pieWkEnds(2*iPie-1).FaceColor=actvtColMPie(validActvts(iPie),:);
                    legTxts(iPie)=sprintf('%s %.2f',actvtTxtsPie(validActvts(iPie)),pieWkEndsX(validActvts(iPie))/60);
                    pieWkEnds(2*iPie).Visible='off';
                end
                legPieWkEnds=legend(axWkEnds,legTxts,'Location','bestoutside','Interpreter', 'none');
                title(legPieWkEnds,'Activity Time (hrs)');
                title(axWkEnds,sprintf('Weekends (%d days)',numWkEndsP));
            end
            
            if ~isempty(evntHist)
                axEvnt=gobjects(length(evntHist),1);
                aktTimesTbl=[];
                for itrP=1:length(evntHist)
                    curChart=curChart+1;
                    axEvnt(itrP)=subplot(totPieC/2,2,curChart);
                    validActvts=find(evntHist(itrP).histG>0.01);
                    pieEvent=pie(evntHist(itrP).histG(validActvts));
                    % intialise a string vector for legends
                    legTxtEvnt=strings(length(validActvts),1);
                    % assign correct activity colours to pie chart
                    for iPie=1:length(validActvts)
                        pieEvent(2*iPie-1).FaceColor=actvtColMPie(validActvts(iPie),:);
                        legTxtEvnt(iPie)=sprintf('%s %.2f%%',actvtTxtsPie(validActvts(iPie)),evntHist(itrP).histG(validActvts(iPie))/evntHist(itrP).duration*100);
                        pieEvent(2*iPie).Visible='off';
                    end
                    legPieEvent=legend(axEvnt(itrP),legTxtEvnt,'Location','bestoutside','Interpreter', 'none');
                    title(legPieEvent,'Activity %');
                    title(axEvnt(itrP),sprintf('Event: %s (duration: %.2f hrs)',evntHist(itrP).Event,evntHist(itrP).duration/3600),'Interpreter', 'none');
                    %create average activity times tables for each event
                    avgAktTimes=round(evntHist(itrP).histG(validActvts)/3600/length(evntHist(itrP).Days),3)';
                    
                    if isempty(aktTimesTbl)
                        aktTimesTbl=table(actvtTxtsPie(validActvts)',avgAktTimes,'VariableNames',["Activity",(evntHist(itrP).Event+" (hrs/day)")]);
                    else
                        aktTimesTbl=outerjoin(aktTimesTbl,table(actvtTxtsPie(validActvts)',avgAktTimes,'VariableNames',["Activity",(evntHist(itrP).Event+" (hrs/day)")]),'MergeKeys',true);
                    end
                end
                aktTimesTbl=fillmissing(aktTimesTbl,'constant',0,'DataVariables',aktTimesTbl.Properties.VariableNames(2:end));
                aktTimesTbl.Activity=categorical(aktTimesTbl.Activity,actvtTxtsPie,'Ordinal',true);
                aktTimesTbl=sortrows(aktTimesTbl,'Activity');
                writetable(aktTimesTbl,fullfile(saveDirP,(SubjectP+" - EventAverageTimes.csv")));
            end
            % save Pie figure
            % set(figPie, 'Color', 'w');
            if  any(strcmpi(Settings.VISUALIZE,["full","extra"]))
                exportgraphics(figPie,fullfile(saveDirP,titlePieP+".png"));
            end
            % export_fig(figPie,fullfile(saveDirP,titlePieP),'-png','-p0.05');
            close(figPie);
        end
    end
end


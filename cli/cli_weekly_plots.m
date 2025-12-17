function cli_weekly_plots(ID,outDir,dataVis,eventsVis,dailyT,disPos)
% cli_weekly_plots Save weekly activity preview figures

% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (c) 2021-2025 Pasan Hettiarachchi and Peter Johansson

% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
% 
% This **workflow/orchestration code** in `/cli/` is licensed under the
% GNU General Public License, version 3.0 or (at your option) any later version.
% See `../LICENSES/GPL-3.0-or-later.txt` for more details.

maxPlotDays=10; % maximum number of days to plot in QualityCheck figure

scaleENMO=3.0; % scale the ENMO vector to fill the plots

actvtTxts=["NW","Lie","Sit","Stand", "Move", "Walk", "Run","Stair", "Cycle","Other","SlpIBD","LieStill"];

% predefined activity colours
%actvtColors={'WhiteSmoke','DarkTurquoise','Yellow','SeaGreen','YellowGreen','DodgerBlue','BlueViolet','HotPink','LightPink','DarkOrange','DarkSLateBlue'};
actvtColors={'Gray','Lavender','Yellow', 'LimeGreen', 'DarkGreen', 'DarkOrange', 'Red','Cornsilk', 'Purple','Sienna','DodgerBlue','Aquamarine'};
colorsBDSlp={'White','PaleVioletRed','CornflowerBlue'};

% predefined diary events
evntTxts=["","ND","NE","Work","Leisure","Night"];
% predefined diary events colours
evntColors={'GhostWhite','Gainsboro','Gold','SeaGreen','Bisque','RoyalBlue'};
% use colours from 'colurcube' colormap for additional unknown events
evntColsUnknwn=brewermap(12,'Set3');
% the width of visualization lines
visLineWdth=3;
% the height of activity visualization patches
visPtchHght=0.7;

% the names of the days
dayNames=["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"];

% map for changing day order from Sunday=1(Matlab) to Monday=1 order
dayOrder=[6,0,1,2,3,4,5];

% hold figure handles
figsQC=[];


%% Initialising

% rescale ENMO values by ratio scaleENMO and clip at a maximum of 0.8
dataVis(:,3)=dataVis(:,3)*scaleENMO;
dataVis(dataVis(:,3)>visPtchHght-0.1,3)=visPtchHght-0.1;


%convert datenum times to datetime
dataDT=datetime(dataVis(:,1),'ConvertFrom','datenum');

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

numQCFigs=ceil(numDays/maxPlotDays);
figsQC=gobjects(numQCFigs,1);

% axes handles for QC plot. maximum maxPlotDays +1 for warnings
axsQC=gobjects(numDays,1);


%% Activity figures (single all days figure and weekly figures)

% create a figure to plot all days
% and display it in the default monitor maximized using normalized units

for itrQCF=1:numQCFigs
    figsQC(itrQCF)=figure('OuterPosition',disPos,'Color','white','Name',...
        sprintf('%s - QC Fig. %d',ID,itrQCF),'NumberTitle','off','Visible','off','MenuBar','None','ToolBar','none');
    tiledlayout(maxPlotDays,1,'TileSpacing','compact','Padding','normal');
end
% handle array to hold VM plots for applying a legend later
pAcc_QC=gobjects(numDays,1); % plot handles for ENMO plots in QualityCheck figure
pTemp_QC=gobjects(numDays,1); % plot handles for ENMO values in QualityCheck figures

% intialise cellarrays to hold handles of line-segments for each day
% these handles will be later used for creating the legend

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
    
    % find the indices of activity transitions
    diffAkts=find(diff([0;dayAkts;0])~=0);
    % find the number of activity bouts (consecutive periods of the same activity)
    numBts=length(diffAkts)-1;
    
    
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
    % daily activity times
    timeAkts=dailyT{dailyT.Date==datestr(visDays(itr),29),actvtTxts}/60; % activity times in hours
    colrBarLbls=actvtTxts(uniqAkts)+repmat(": ",1,length(uniqAkts))+...
            round(timeAkts(uniqAkts),1)+ repmat("h, ",1,length(uniqAkts))+...
            round(timeAkts(uniqAkts)/24*100)+repmat("%",1,length(uniqAkts));
    % QualityCheck Plot - plot activities in colors using fill and add a colorbar
    
    % set the correct QCfigure as current
    set(0,'CurrentFigure',figsQC(ceil(itr/maxPlotDays)));
    curSPlot=itr-(ceil(itr/maxPlotDays)-1)*maxPlotDays;
    
    % create a subplot for the day
    %axsQC(itr)=subplot(maxPlotDays,1,curSPlot);
    axsQC(itr)=nexttile(curSPlot);
    axsQC(itr).FontSize=6;
    % assgn the unique colormap to the axis
    colormap(axsQC(itr),actvtColMap(uniqAkts,:));
    % hold is on for fill
    hold(axsQC(itr),'on');
    fill(axsQC(itr),ptchX,ptchY,ptchC,'EdgeColor','none');
    %correctly place the colorbar ticks and labels
    segOffst=(length(uniqAkts)-1)/length(uniqAkts)/2;
    colbar_tks=linspace(1+segOffst,length(uniqAkts)-segOffst,length(uniqAkts));
    if length(uniqAkts)>9
        colbarFontSz=4.5;
    else
        colbarFontSz=5;
    end
    %plot the colorbar legend for activities
    colorbar(axsQC(itr),'Ticks',colbar_tks,'TickLabels',colrBarLbls,'FontSize',colbarFontSz);
    
    % plot the ENMO values withing activity patches
    pAcc_QC(itr)=plot(axsQC(itr),dayDT,dataVis(dayStartIndx:dayEndIndx,3),'-k','LineWidth',1);
    
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
                lineCBDSlp=[bDSlpColMap(3,:),0.5]; %2022-10-19 use the same colur as sleep-interval but with transparent level of 0.5
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
            
            % aggregate event names to be used in creating a legend
            l_labels{itr}=[l_labels{itr},lblBDSlp];
        end
    end
    
end

% Diary event visualization

% l_comments=strings(numDays,1);
unknownEvents=[]; % vector to hold unknown events (known events in evntTxts)

for itrEvnt=1:length(eventsVis)
    % find the day relevant to diary event
    dayS=find(day(visDays,'dayofyear')==day(eventsVis(itrEvnt).start,'dayofyear'));
    dayE=find(day(visDays,'dayofyear')==day(eventsVis(itrEvnt).stop,'dayofyear'));
    
    % Counting workdays and leisure days for generating average work and leisure activity table
    for dayNum=dayS:dayE
        if ~isempty(dayNum)
            if eventsVis(itrEvnt).start < visDays(dayNum)
                startX=visDays(dayNum);
            else
                startX=eventsVis(itrEvnt).start;
            end
            if eventsVis(itrEvnt).stop > visDays(dayNum)+days(1)
                endX=visDays(dayNum)+days(1);
            else
                endX=eventsVis(itrEvnt).stop;
            end
            % endpoints of the event visualization line
            lineX=[startX,endX];
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
            
            % plot event visualization lines and keep handles for creating legends
            
            l_all{dayNum}=[l_all{dayNum},line(axsQC(dayNum),lineX,lineY,'Color',lineC,'LineWidth',visLineWdth)];
            
            % aggregate event names to be used in creating a legend
            l_labels{dayNum}=[l_labels{dayNum},eventsVis(itrEvnt).Event];
            
            %find the length of the even segment in correct units
            widthQCsUnit = diff(ruler2num(lineX,axsQC(dayNum).XAxis));
            
            % add Comments and ref. position text to Event line segments
            % uf text is too long (by checking theit extents) trim them
            % txtC=imcomplement(lineC);
            
            visTxt=" "+ eventsVis(itrEvnt).Ref+" "+ eventsVis(itrEvnt).Comment;
            txtQCs=text(axsQC(dayNum),lineX(1),visPtchHght+0.15,visTxt,'FontSize',4.5,'Margin',0.1);
            widthQCsTxt=txtQCs.Extent(3);
            if widthQCsTxt > widthQCsUnit
                txtQCs.String=extractBetween(txtQCs.String,1,max(floor(strlength(txtQCs.String)*widthQCsUnit/widthQCsTxt*0.93)-2,0));
            end
            
        end
    end
    
end

% Make a legend for diary events and ENMO plots in both weekly and QC figures
for itr=1:numDays
       
    % find the unique diary events and their indices
    [uniqL,iUniqL]=unique(l_labels{itr});
    
    %only select handles of unique event visualization lines
    l_all{itr}=l_all{itr}(iUniqL);
    if isempty(uniqL)
        uniqL=[];
    end
    %apply the legends
    
    % create the legend labels for QC plot
    legend(axsQC(itr),[pAcc_QC(itr),l_all{itr}],["Acc.",uniqL],'Location','westoutside','Interpreter', 'none');
    
end


%% Display/Save the QC figures

for itrQCF=1:numQCFigs
    % set the correct QCfigure as current
    %set(0,'CurrentFigure',figsQC(itrQCF));
    % set(figsQC(itrQCF), 'Color', 'w');
    %figsQC(itrQCF).Visible=true;
    %drawnow;
    % save QCFigure
    % the title of the figure for all subplots
    sgtitle(figsQC(itrQCF),sprintf('%s - QC Fig. %d of %d',ID,itrQCF,numQCFigs),'Interpreter', 'none','FontSize',7);
    exportgraphics(figsQC(itrQCF),fullfile(outDir,sprintf('%s_QC-%d.png',ID,itrQCF)));
    close(figsQC(itrQCF)); % close selected QCfigure
end

end


function status = findDistributions(masterDlyTbl,qcDirOutP)
%detectOutliers detect outliers and generate activity time distributions

% Copyright (c) 2021-2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the Actipass repository (https://github.com/Ergo-Tools/ActiPASS).


try
    distriDir=fullfile(qcDirOutP,"Distributions"); 
    if ~isfolder(distriDir)
        mkSts=mkdir(distriDir);
    else
        mkSts=1;
    end
    if mkSts==1
        %% generate activity time distributions
        distNames=["Steps","timeNW","timeLie","timeSit","timeStand","timeMove","timeWalk","timeRun",...
            "timeStair","timeCycle","timeOther","timeSlpInBD","timeLieStill"];
        
        
        for distName=distNames
            distIndx=distName==masterDlyTbl.Properties.VariableNames;
            distFigG=figure('units','normalized','OuterPosition',[0 0 1 1],'Name',...
                distName+ " - Distributions, Event: NE",'NumberTitle','off','Visible','off');
            % the title of the figure for all subplots
            sgtitle(distFigG,distName+ " - Daily Time Distribution");
            
            axDist=subplot(1,1,1);
            
            actT=masterDlyTbl{masterDlyTbl.totalDur >=23,distIndx}; % only keep the days which are at least 23hrs or longer'
            
            if ~strcmpi(distName,"Steps")
                actT=actT*60;
            end
            
            subjctIDs=masterDlyTbl.ID(masterDlyTbl.totalDur >=23); % only keep the days which are at least 23hrs or longer' % only keep the events which are at least 2hrs or longer'
            
            numBins=50;
            [~,histEdges,indxBin] = histcounts(actT,numBins);
            binSubjcIDs=cell(1,numBins);
            
            % histG=histogram(axDist,actT,'Normalization','probability');
            hF=histfit(axDist,actT,numBins,'kernel');
            hF(1).FaceColor = [114,147,203]/255;
            hF(1).FaceAlpha = 0.1;
           
%             [f,xi] = ksdensity(actT);
%             area(axDist,xi,f,'FaceAlpha',0.4);
%             xlim(axDist,[-5,axDist.XLim(2)]);
            maxNumID=0;
            for itr4=1:numBins
                binSubjcIDs{itr4}=unique(subjctIDs(indxBin==itr4));
                maxNumID=max(maxNumID,length(binSubjcIDs{itr4}));
            end
            % repeat one more time and create a string matrix
            binSubjcIDsT=strings(maxNumID,numBins);
            for itr4=1:numBins
                binSubjcIDsT(1:length(binSubjcIDs{itr4}),itr4)=binSubjcIDs{itr4};
            end
            binSubjcIDsT=array2table(binSubjcIDsT,'VariableNames',string(histEdges(1:end-1))+"-"+string(histEdges(2:end)));
            writetable(binSubjcIDsT,fullfile(distriDir,distName+ " - SubjectID - Distributions.xlsx"));
            
            % uniqueBins=unique(indxBin);
            percnt75=prctile(actT,75);
            percnt50=prctile(actT,50);
            percnt25=prctile(actT,25);
            %percnt1=prctile(actT,1);
            %meanVal=mean(actT);
            
            xline(axDist,percnt75,':','Color','#D95319','LineWidth',1.5);
            xline(axDist,percnt50,':','Color','#A2142F','LineWidth',1.5);
            xline(axDist,percnt25,':','Color','#7E2F8E','LineWidth',1.5);
            
            
            %xline(percnt1,'r--',"1st pcntile = "+round(percnt1,2));
            %xline(meanVal,'r--',"Mean = "+round(meanVal,2));
            
            
            legTxt=["histogram","kernel density","Median = "+round(percnt50,2),"25th pcntile = "+round(percnt25,2),"75th pcntile = "+round(percnt75,2)];
            legend(axDist,legTxt);
            
            % set(axDist,'YScale','log');
            % axDist.YTickLabel=string(axDist.YTick);
            % xticks(axDist,histEdges);
            xlim(axDist,[0-(histEdges(2)-histEdges(1)),histEdges(end)+(histEdges(2)-histEdges(1))]);
            
            xticks(axDist,histEdges);
            
            axDist.XTickLabelRotation = 90;
            if strcmpi(distName,"Steps")
                xlabel(axDist,'Steps Count');
            else
                xlabel(axDist,'Time (min)');
            end
            
            axDist.XAxis.Exponent = 0;
            axDist.YAxis.Exponent = 0;
            ylabel(axDist,'Num days');
            % save figure
            exportgraphics(distFigG,fullfile(distriDir,distName+ " - Distributions.png"));
            %print(figWks(itrWk),fullfile(save_dir,figNames(itrWk)),'-dpng');
            close(distFigG);
            
        end
        
        status="OK";
    else
        status="Unable to create directory containing activity time distribtions";
    end
catch ME
    status=getReport(ME,'extended','hyperlinks','off');
end
end


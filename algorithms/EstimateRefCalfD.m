function VrefDCALF = EstimateRefCalfD(firstDay,Acc,VCalf,Akt,VrefCalfDef,VrefDTH,RefTs,Fs,dCalfRefFile)
%
% Find reference angle for leg accelerometer using diary markers.
% Leg reference angle is calculated by finding a standing a period
% within a predefined interval surrounding the diary marker.

% TODO:
%The raw Acc data is also modified and returned.
% When there are more than one diary ref markers Acc data following each
% diary ref. marker is adjusted with corresponding ref. values. Any Acc.
% data preceding the first diary ref. marker is adjusted using the first
% ref. value.

tWin=20; % 40s time window surrounding each Ref.P. marker is searched for standing ref. positions.
tMinStand=2; %At least 3 Sec of standing needed
VrefDCALF=struct('RefT',{},'Vref',{},'Method',{});
[~,refFigTitle,~]=fileparts(dCalfRefFile);

persistent oldRef

RefTs=datenum(RefTs); % convert RefTs from datetime to datenum

if firstDay  %first interval for ID: provisionel reference for calculation of Akt
    oldRef = VrefCalfDef; %average back accelerometer angle
end

curRefTs=RefTs(RefTs>= Acc(1,1) & RefTs<Acc(end,1)); % find refTs relevant to current day+-buffer (This function is usually called every day)
if isempty(curRefTs)
    if isequal(oldRef,VrefCalfDef)
        VrefDCALF(1).Vref=VrefCalfDef;
        VrefDCALF(1).Method="ND-def"; % No diary ref. or previous standing ref. , falling back to auto1
    else
        VrefDCALF(1).Vref=oldRef;
        VrefDCALF(1).Method="ND-previous"; % No diary ref. but previous standing ref. exist
        VrefDCALF(1).RefT=Acc(1,1);
    end
    
else
    figRef=figure('units','pixels','position',[0 0 1280 768],...
        'Name',refFigTitle,'NumberTitle','off','Visible','off');
    
    sgtitle(figRef,refFigTitle,'FontSize',12,'Interpreter','none');
    axRefs=gobjects(length(curRefTs),1);
    for itr=1:length(curRefTs)
        
        axRefs(itr)=subplot(length(curRefTs),1,itr);
        indAccStart=floor(find(Acc(:,1)>= curRefTs(itr)-tWin/86400,1,'first')/Fs)*Fs+1;
        indAccEnd=floor(find(Acc(:,1)<= curRefTs(itr)+tWin/86400,1,'last')/Fs)*Fs; %check this
        tDT=datetime(Acc(indAccStart:indAccEnd,1),'convertfrom','datenum');
        plot(axRefs(itr),tDT,Acc(indAccStart:indAccEnd,2:4)); % plot the three Acc signals within the time window
        pltYLims=[-2,2]; % set the ylimits
        axRefs(itr).YLim=pltYLims;
        axRefs(itr).YTick = pltYLims(1):0.2:pltYLims(2);
        axRefs(itr).GridLineStyle = '--';
        grid(axRefs(itr),'on');
        hold(axRefs(itr),'on');
        TimeWin=Acc(indAccStart:Fs:indAccEnd,1);
        AktWin=Akt(((indAccStart-1)/Fs+1):indAccEnd/Fs);
        
        if ~isempty(VrefDTH) && strcmpi(VrefDTH(itr).Method,"standing") 
            indAccStartStand=find(Acc(indAccStart:indAccEnd,1)>=VrefDTH(itr).RefT(1),1,'first');
            indAccEndStand=find(Acc(indAccStart:indAccEnd,1)<=VrefDTH(itr).RefT(2),1,'last');
			
            VrefDCALF(itr).RefT=VrefDTH(itr).RefT; % define the actual standing reference position time
            VrefDCALF(itr).Vref=mean(VCalf(indAccStart-1+(indAccStartStand:indAccEndStand),:),1); % find the reference position
            VrefDCALF(itr).Method="standing";
            oldRef = VrefDCALF(itr).Vref; % if a standing reference position is found, save it for use in next iterations
            
            % Now plot the standing reference position as a semi transparent patch
            ptchX=[tDT(indAccStartStand),tDT(indAccEndStand),tDT(indAccEndStand),tDT(indAccStartStand)];
            ptchY=[pltYLims(1),pltYLims(1),pltYLims(2),pltYLims(2)];
            fill(axRefs(itr),ptchX,ptchY,rgb('Moccasin'),'FaceAlpha',0.5);
            ylabel(axRefs(itr),'Acc');
            legend(axRefs(itr),{'X','Y','Z',sprintf('Stnd: [%.2f,%.2f,%.2f]', VrefDCALF(itr).Vref*180/pi)},'Location','best');
        else
            movStdAcc=movstd(Acc(indAccStart:indAccEnd,2:4),Fs,1);
            movStdAcc=movStdAcc(1:Fs:size(movStdAcc,1),:);
            sumMovStdAcc=sum(movStdAcc,2);
            StandSegs=bwconncomp(AktWin==3 & sumMovStdAcc' < 0.05); % find segments of standing
            StndSgsLnths=cellfun(@length,StandSegs.PixelIdxList);
            SelSegIdxs=find(StndSgsLnths>tMinStand);%  find segments of standing with duration larger than tMinStand
            
            if length(SelSegIdxs) >=1  % if there are at least one segment of standing with duration larger than tMinStand
                StandSegs.PixelIdxList=StandSegs.PixelIdxList(SelSegIdxs); %only select standing with duration larger than tMinStand
                funSumMovStd=@(x) mean(sumMovStdAcc(x)); %define a anonymous function to be used in cellfun to find mean values of sumMovStdAcc in each segment
                [~,segNum]=min(cellfun(funSumMovStd,StandSegs.PixelIdxList)); % find the  standing segment with minimum standard deviation during the given time window
                indStartStand=StandSegs.PixelIdxList{segNum}(1);% The first second of standing segment
                indEndStand=StandSegs.PixelIdxList{segNum}(end); % The last second of standing segment
                [~,indMinSumStd]=min(sumMovStdAcc(indStartStand:indEndStand)); % find the second with minimum sumMovStdAcc
                indMidStand=indStartStand+indMinSumStd-1; % find the second with minimum sumMovStdAcc
                indStartStand=max(indMidStand-floor(tMinStand/2),indStartStand); %define a timewindow centered around the minimum sumMovStdAcc second
                indEndStand=min(indMidStand+floor(tMinStand/2),indEndStand); %define a timewindow centered around the minimum sumMovStdAcc second
                VrefDCALF(itr).RefT=TimeWin([indStartStand,indEndStand]); % define the actual standing reference position time
                VrefDCALF(itr).Vref=mean(VCalf(indAccStart+((indStartStand-1)*Fs:(indEndStand*Fs-1)),:),1); % find the reference position
                VrefDCALF(itr).Method="standing";
                oldRef = VrefDCALF(itr).Vref; % if a standing reference position is found, save it for use in next iterations
                
                % Now plot the standing reference position as a semi transparent patch
                ptchX=[tDT(1+(indStartStand-1)*Fs),tDT(indEndStand*Fs-1),tDT(indEndStand*Fs-1),tDT(1+(indStartStand-1)*Fs)];
                ptchY=[pltYLims(1),pltYLims(1),pltYLims(2),pltYLims(2)];
                fill(axRefs(itr),ptchX,ptchY,rgb('Moccasin'),'FaceAlpha',0.5);
                ylabel(axRefs(itr),'Acc');
                legend(axRefs(itr),{'X','Y','Z',sprintf('Stnd: [%.2f,%.2f,%.2f]', VrefDCALF(itr).Vref*180/pi)},'Location','best');
            else
                if isequal(oldRef,VrefCalfDef)
                    
                    VrefDCALF(itr).Vref = VrefCalfDef;
                    VrefDCALF(itr).Method="D-def"; % indicate diary ref. exist, but no standing section found, falling back to auto1
                else
                    VrefDCALF(itr).Vref=oldRef;
                    VrefDCALF(itr).Method="D-previous"; % % indicate diary ref. exist, but no standing section found, using previous
                end
                VrefDCALF(itr).RefT=curRefTs(itr);
                legend(axRefs(itr),{'X','Y','Z'},'Location','best');
            end
        end
    end
    % save the figure to QC directory
    exportgraphics(figRef,dCalfRefFile+".png");
    % export_fig(figRef,dTrnkRefFile,'-png','-p0.01');
end



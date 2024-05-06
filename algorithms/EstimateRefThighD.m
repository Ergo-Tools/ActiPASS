function VrefD = EstimateRefThighD(Acc,Vthigh,VrefThighDef,VrefThighOld,RefTs,Fs,SettingsAkt,diaryRefFile)
% EstimateRefThighD Find reference angle for leg accelerometer using diary markers.
% Input:
% 
% Output:
%
% Notes:
% Leg reference angle is calculated by finding a standing a period
% within a predefined interval surrounding the diary marker.

% TODO:
% The raw Acc data is also modified and returned.
% When there are more than one diary ref markers Acc data following each
% diary ref. marker is adjusted with corresponding ref. values. Any Acc.
% data preceding the first diary ref. marker is adjusted using the first
% ref. value.

% Copyright (c) 2021, Pasan Hettiarachchi.

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


tWin=20; % 40s time window surrounding each Ref.P. marker is searched for standing ref. positions.
tMinStand=2; %At least 5 Sec of standing needed
VrefD=struct('RefT',{},'Vref',{},'Method',{});
[~,refFigTitle,~]=fileparts(diaryRefFile);

RefTs=datenum(RefTs); % convert RefTs from datetime to datenum

curRefTs=RefTs(RefTs>= Acc(1,1) & RefTs<Acc(end,1)); % find refTs relevant to current day+-buffer (This function is usually called every day)
if isempty(curRefTs)
    if isequal(VrefThighOld,VrefThighDef)
        VrefD(1).Vref = EstimateRefThigh1(Acc,Vthigh,VrefThighOld,VrefThighDef,Fs,SettingsAkt);
        VrefD(1).RefT=Acc(1,1);
        VrefD(1).Method="ND-auto1"; % No diary ref. or previous standing ref. , falling back to auto1
    else
        VrefD(1).Vref=VrefThighOld;
        VrefD(1).Method="ND-previous"; % No diary ref. but previous standing ref. exist
        VrefD(1).RefT=Acc(1,1);
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
        AktWin = ActivityDetect(Acc(indAccStart:indAccEnd,2:4),Fs,Acc(indAccStart:indAccEnd,1),VrefThighOld,SettingsAkt);
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
            
            indsStandSel=indAccStart+((indStartStand-1)*Fs:(indEndStand*Fs-1));
            VrefD(itr).Vref=mean(Vthigh(indsStandSel,:),1); % find the reference position
            VrefD(itr).RefT=Acc([indsStandSel(1),indsStandSel(end)],1); % define the actual standing reference position time
            VrefD(itr).Method="standing";
            %VrefThighOld = VrefD(itr).Vref; % if a standing reference position is found, save it for use in next iterations
            
            % Now plot the standing reference position as a semi transparent patch
            ptchX=[tDT(1+(indStartStand-1)*Fs),tDT(indEndStand*Fs-1),tDT(indEndStand*Fs-1),tDT(1+(indStartStand-1)*Fs)];
            ptchY=[pltYLims(1),pltYLims(1),pltYLims(2),pltYLims(2)];
            fill(axRefs(itr),ptchX,ptchY,rgb('Moccasin'),'FaceAlpha',0.5);
            ylabel(axRefs(itr),'Acc');
            legend(axRefs(itr),{'X','Y','Z',sprintf('Stnd: [%.2f,%.2f,%.2f]', VrefD(itr).Vref*180/pi)},'Location','best');
        else
            if isequal(VrefThighOld,VrefThighDef)
                VrefD(itr).Vref = EstimateRefThigh1(Acc,Vthigh,VrefThighOld,VrefThighDef,Fs,SettingsAkt);
                VrefD(itr).Method="D-auto1"; % indicate diary ref. exist, but no standing section found, falling back to auto1
            else
                VrefD(itr).Vref=VrefThighOld;
                VrefD(itr).Method="D-previous"; % % indicate diary ref. exist, but no standing section found, using previous
            end
            VrefD(itr).RefT=curRefTs(itr);
            legend(axRefs(itr),{'X','Y','Z'},'Location','best');
        end
    end
    % save the figure to QC directory
    % export_fig(figRef,diaryRefFile,'-png','-p0.01');
    exportgraphics(figRef,diaryRefFile+".png");
end



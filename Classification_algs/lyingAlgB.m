function Akt = lyingAlgB(AccFilt,StdMax,VrefThigh,Akt,Fs,Tid,saveDirP)
% lyingAlgB find Lie periods using thigh rotation during Sit/Lie bouts

% Based ON
% Validity of a Non-Proprietary Algorithm for Identifying Lying Down Using Raw Data from Thigh-Worn Triaxial Accelerometers
% Pasan Hettiarachchi,Katarina Aili,Andreas Holtermann,Emmanuel Stamatakis,Magnus Svartengren and Peter Palm*
% doi: 10.3390/s21030904
% AND
% Differentiating Sitting and Lying Using a Thigh-Worn Accelerometer
% LYDEN, KATE; JOHN, DINESH; DALL, PHILIPPA; GRANAT, MALCOLM H.
% doi: 10.1249/MSS.0000000000000804

% Input:
% AccFilt [N,3]: low pass (6th order, 2Hz cutoff butterworth)filtered Acceleration. The
% same settings used by 'Vinkler.m'
% Fs: Sample frequency (N=SF*n)
% VrefThigh [3]: Reference angle for thigh (unit: radians)
% Akt [n]: Combined activity by a 1 sec. time scale (Time) output from
% 'ActivityDetect.m'

% Output:
% Akt [n]: Combined activity with Sit/Lie seperated according to Lyden's
% algorithm

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

twinMean=20; % window length for moving average filter used in rotation logic
thrshld_anglH=65; %The threshold angle for detecting lying - the higher cutoff (def 65)
thrshld_anglL=66; %The threshold angle for detecting lying - the lower cutoff (def 66)
noise_margin= 0.05; % noise margin in threshold angle 
minLieTime=30; % the minimum Sit period to consider for Lying
minNonRotLieTime=1200;
minRotTime=5; % the minimum time duration of rotation crossing to consider
stdThrsEpsd=0.01; % the cutoff threshold of 75th percentile of SD to seperate true lying on side from false positives (def. 0.01)
stdThrshldTot=0.004; % the cutoff threshold of 75th percentile of SD to change false negatives to lying on side (def 0.005)
% fix AccFilt vector according to reference positions
Rot = [cos(VrefThigh(2)) 0 sin(VrefThigh(2)); 0 1 0; -sin(VrefThigh(2)) 0 cos(VrefThigh(2))]; %rotation matrix
AccFilt = AccFilt*Rot; %rotation from axis of AG to axis of leg

% finding the moving average of filtered Acc
meanAcc=movmean(AccFilt,twinMean*Fs);
%down sample meanAcc to per/sec
meanAcc=meanAcc(1:Fs:end,:);

%down sample AccFilt to per/sec
%AccFilt=AccFilt(1:Fs:end,:);
% calculate vector magnitude of AccFilt
%SVM = sqrt(sum(AccFilt .^ 2, 2));
%normAcc = AccFilt./repmat(SVM,1,3);
%Inc = acosd(normAcc(:,1));
%theta = -asind(normAcc(:,3));
%find the thigh rotation angle
%RotAngle=asind(AccFilt(:,2)./sqrt(AccFilt(:,2).^2+AccFilt(:,3).^2));


%find the thigh rotation angle
meanRotAngle=abs(asind(meanAcc(:,2)./sqrt(meanAcc(:,2).^2+meanAcc(:,3).^2)));
%append the first element again because we are going to use diff to find the changes
meanRotAngle=[meanRotAngle(1);meanRotAngle];

% find when the thigh rotation angle crosses the upper threshold
rotCrossPtsH=diff(meanRotAngle>thrshld_anglH)>0 ;

% find when the thigh rotation angle crosses the lower threshold
rotCrossPtsL=diff(meanRotAngle<thrshld_anglL)>0 ;
% find the points where the change of thigh rotation angle is at least
% noise_margin degrees (default 0.05)
noiseIndex = abs(diff(meanRotAngle)) >= noise_margin;
%only select threshold crossings above noise_margin
rotCrossPtsH=rotCrossPtsH & noiseIndex;
rotCrossPtsL=rotCrossPtsL & noiseIndex;

% find the activity times flag as Sit
sitPts=(Akt==2);
%find the consecutive sections of Sit periods
[SitSections,numSitS]=bwlabel(sitPts); % or should this be sitPts(2:end)?
%for each Sit period, find the thigh rotations
for section=1:numSitS
    slctPts=find(SitSections==section);
    %if there is a full rotation, i.e. threshold crossing and falling back
    if length(slctPts)>minLieTime
        ptsH=find(rotCrossPtsH(slctPts));
        ptsL=find(rotCrossPtsL(slctPts));
        nCrossings=0;
        nValdCrssngs=0;
        %pltPtsH=[];
        %pltPtsL=[];
        for itr=1:length(ptsH)
            if itr<length(ptsH)
                indptsL=find(ptsL>ptsH(itr)+minRotTime & ptsL< ptsH(itr+1),1,'first');
            else
                indptsL=find(ptsL>ptsH(itr)+minRotTime,1,'first');
            end
            
            if ~isempty(indptsL) 
                nCrossings=nCrossings+1;
                startLS=ptsH(itr)+slctPts(1)-1;
                endLS=ptsL(indptsL)+slctPts(1)-1;
                if prctile(StdMax(startLS:endLS),75)<stdThrsEpsd
                   nValdCrssngs=nValdCrssngs+1; 
                end
                %pltPtsH=[pltPtsH,startLS];
                %pltPtsL=[pltPtsL,endLS];
            end
        end
        
        if nCrossings>=1
            
            if nValdCrssngs>=1 || nCrossings >5
                Akt(slctPts)=1; % mark the corresponding Sit period as Lie
            end
            %plot decision data
%             dbgF=figure('Name',[datestr(Tid(slctPts(1)),13),'-',datestr(Tid(slctPts(end)),13)],'units','normalized','OuterPosition',[0 0 0.8 0.8],'Visible','off');
%             
%             axThRot=subplot(4,2,1);
%             hold(axThRot,'on');
%             plot(axThRot,Tid(slctPts),meanRotAngle(slctPts));
%             plot(axThRot,Tid(pltPtsH),meanRotAngle(pltPtsH),'rs');
%             plot(axThRot,Tid(pltPtsL),meanRotAngle(pltPtsL),'ms');
%             ylabel(axThRot,'Thigh Rotation °');
%             datetick(axThRot,'x',13);
%             
%             axTheta=subplot(4,2,3);
%             plot(axTheta,Tid(slctPts),theta(slctPts),'Color','#D95319');
%             ylabel(axTheta,'Theta °');
%             datetick(axTheta,'x',13);
%             
%             axInc=subplot(4,2,5);
%             plot(axInc,Tid(slctPts),Inc(slctPts),'Color','#77AC30');
%             ylabel(axInc,'Inc °');
%             datetick(axInc,'x',13);
%             
%             axSD=subplot(4,2,7);
%             plot(axSD,Tid(slctPts),movmean(StdMax(slctPts),200),'Color','#EDB120');
%             ylabel(axSD,'SD');
%             datetick(axSD,'x',13);
%             
%             
%             axDistRot=subplot(4,2,2);
%             histogram(axDistRot,RotAngle(slctPts),30,'Normalization','probability');
%             title(axDistRot,'Thight Rotation distribution');
%             
%             axThetaDist=subplot(4,2,4);
%             histogram(axThetaDist,theta(slctPts),30,'Normalization','probability');
%             title(axThetaDist,'Theta (TP)');
%             
%             axIncDist=subplot(4,2,6);
%             histogram(axIncDist,Inc(slctPts),30,'Normalization','probability');
%             title(axIncDist,'Inc (TP)');
%             
%             axSDDist=subplot(4,2,8);
%             histogram(axSDDist,StdMax(slctPts),linspace(0,0.04,41),'Normalization','probability');
%             title(axSDDist,'maximum SD');
%             % xlim(axSD,[0.0,0.04]);
%             
%             sgtitle([datestr(Tid(slctPts(1)),31),'-',datestr(Tid(slctPts(end)),13)]);
%             export_fig(dbgF,fullfile(saveDirP,[datestr(Tid(slctPts(1)),'mmm_dd_HH_MM_SS'),'-',datestr(Tid(slctPts(end)),'HH_MM_SS')]),'-png','-p0.05');
%             close(dbgF);
        elseif prctile(StdMax(slctPts),75)<stdThrshldTot &&  length(slctPts)>minNonRotLieTime
            Akt(slctPts)=1; % mark the corresponding Sit period as Lie
            
        end
    end
end
end


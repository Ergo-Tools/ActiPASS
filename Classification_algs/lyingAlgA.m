function Akt = lyingAlgA(AccFilt,VrefThigh,Akt,Fs)
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
% Akt [n]: Combined activity with Sit/Lie seperated according to Lyden's algorithm


% Copyright (c) 2021, Pasan Hettiarachchi & Peter Johansson.
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
thrshld_anglH=65; %The threshold angle for detecting lying - the higher cutoff
thrshld_anglL=64; %The threshold angle for detecting lying - the lower cutoff
noise_margin= 0.05; % noise margin in threshold angle
minLieTime=1; % the minimum Sit period to consider for Lying
% fix AccFilt vector according to reference positions
Rot = [cos(VrefThigh(2)) 0 sin(VrefThigh(2)); 0 1 0; -sin(VrefThigh(2)) 0 cos(VrefThigh(2))]; %rotation matrix
AccFilt = AccFilt*Rot; %rotation from axis of AG to axis of leg
% finding the moving average of filtered Acc
meanAcc=movmean(AccFilt,twinMean*Fs);
%downsample to 1 sample per second
meanAcc=meanAcc(1:Fs:end,:);
%find the thigh rotation angle
thigh_angle=abs(asind(meanAcc(:,2)./sqrt(meanAcc(:,2).^2+meanAcc(:,3).^2)));
%append the first element again because we are going to use diff to find the
%changes
thigh_angle=[thigh_angle(1);thigh_angle];

% find when the thigh rotation angle crosses the upper threshold
rotCrossPtsH=diff(thigh_angle>thrshld_anglH)>0 ;

% find when the thigh rotation angle crosses the lower threshold
rotCrossPtsL=diff(thigh_angle<thrshld_anglL)>0 ;
% find the points where the change of thigh rotation angle is at least
% noise_margin degrees (default 0.05)
noiseIndex = abs(diff(thigh_angle)) >= noise_margin;
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
%        sumCrossings=0;
%         for itr=1:length(ptsH)
%             if itr<length(ptsH)
%                 indptsL=find((ptsL>ptsH(itr) & ptsL< ptsH(itr+1)),1,'last');
%             else
%                 indptsL=find(ptsL>ptsH(itr),1,'last');
%             end
%             if ~isempty(indptsL)
%                 sumCrossings=sumCrossings+1;
%             end
%         end
       

        if (length(ptsH)>=1 && length(ptsL)>=1)
        
            Akt(slctPts)=1; % mark the corresponding Sit period as Lie
        end
    end
end
end


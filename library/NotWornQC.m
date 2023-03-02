function  [NotWornLogic,NightLogic,StdSum,warning] = NotWornQC(Acc,meanTEMP,diaryStrct,Fs,smpls1S)

% NotWornQC Estimation of periods of 'not-worn' for quality checking Acc data.
% Based on the not-worn function in Acti4 with inclusion of temperature profiling.
% (c) 2021, Pasan Hettiarachchi, Uppsala University
% 
% Input:
% Acc [N,4]: Unfiltered accelerations evenly sampled
% Fs: Sample frequency
% SamplPts [L]: The sample-points at NotWorn details to be reported back
%               (Normaly this is expected to be at 1 second intervals (or Fs samples)
%               i.e. L=the number of complete seconds in the data
% meanTEMP: [L] - (evenly sampled and moving-mean filtered temperature)
% diaryStrct [struct]  -A structure containing diary information - used for manual non-wear periods defined in diary
%                      -and adjusting the senitivity of NW detection during night/bed times
%                       diaryStrct.ID - subjectID ;
%                       diaryStrct.Ticks - all transitions times as Matlab datetime values;
%                       diaryStrct.Events - all diary events names (work, leisure etc);
%                       diaryStrct.Comments - all comments for each diary event
%                       diaryStrct.StartT- the diary defined data start time;
%                       diaryStrct.StopT - diary defined data stop time;
%                       diaryStrct.RefTs - standing reference times defined in diary;
%                       diaryStrct.rawData - the raw diary data for this subjectID as a table (including invalid entries)
%
% Output:
%   NotWornLogic [L]: true/false, not-worn = true, given at SamplPts
%   NightLogic [L]: logical vector representing night periods
%   StdSum [L]: The sum of moving-standard-deviation given at SamplPts - this will be used further 
%               down the workflow in flips/rotation detection
%   warning [P]: String array of any warnings
%
% All periods longer than 90 minuttes with no activity are considered not-worn;
% periods between 10 to 90 minutes are considered not-worn if a certain amount of movement/acceleration
% is detection just before (within 10 sec.) and the orientaion deviates less than 5° from horizontal lying.
% above notworn is further adjusted based on temperature profiling if Temperature data exist

% Copyright (c) 2022, Pasan Hettiarachchi .
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


filt_win= 2; % main time window for different types of filtering
tShortWorn = 120; % The first step in filtering out very short worn period
tEdgeWorn= 1800; % For extending NW sections just after or just before the start and end of data respectively.
tmin_notworn = 5400; % Time in seconds for the minimum duration of worn period
t_seperation= 600;% time in seconds for not-worn period to be seperated from an activity
still_thrshld= 0.01;% the standard deviation threshold for not-worn detection
mov_thrshld= 0.1;% the standard deviation threshold for not-worn detection
FiltWinSz=Fs*filt_win; % the size of bucket for many tests ( 2s default)
warning=string([]); % the string containing warnings

% Intialise vectors of size smpls1S (at each second)
smplTimes=Acc(smpls1S,1); % the time vector for the selected samples in datenum format
NotWornLogic = false(length(smplTimes),1); % the logical vector to hold NW data
NWForce=false(length(smplTimes),1); % Vector to record forced NW times from diary
NightLogic=false(length(smplTimes),1); % Vector to hold night-time logic either from diary or

% find the moving-standard-deviation with a window of FiltWinSz
movStdAcc=movstd(Acc(:,2:4),FiltWinSz,0,1);
% we need the values only at SamplePts
movStdAcc=movStdAcc(smpls1S,:);
% then find the Sum and Mean of above for the three axes
StdMean  = mean(movStdAcc,2);
StdSum = sum(movStdAcc,2);

% find filtered accleration values for orientation checks
[Blp,Alp] = butter(6,filt_win/(Fs/2));
Acc_filt = filter(Blp,Alp,Acc(:,2:4));
Acc_filt=Acc_filt(smpls1S,:); % pickup values only at the smplPts ( 1 s intervals)
SVM_filt = sqrt(sum(Acc_filt.^ 2, 2)); % also find filtered-svm values at these points
normAcc = Acc_filt./repmat(SVM_filt,1,3);
V = [acos(normAcc(:,1)),-asin(normAcc(:,3)),-asin(normAcc(:,2))];

% For not-worn periods the AG normally enters standby state (Std=0 in all axis) or
% in some cases yield low level noise of ±2-3 LSB:

StillAcc=[false,StdMean(1:end-1)'< still_thrshld,false];
MoveAccLgc=StdMean> mov_thrshld;
% modify StillAcc logical vector with temperature if exist

if ~isempty(meanTEMP)
    
    %% Use Temperature if exist to improve NotWorn detection
    % This part should be improved. Now the logic is based on a simple
    % temperature percentile value.
    
    % find low temperature points below the 10th percentile of temperature
    % data and
    lowTemp=[false,meanTEMP(1:end-1)'< prctile(meanTEMP(MoveAccLgc),5),false];
    % flag very low temperature periods also as still.
    StillAcc=StillAcc|lowTemp;
else
    %warning=[warning,"NonWear detection: Temperature matrix is empty. Accuracy is reduced."];
end

OffOn = diff(StillAcc);
Off = find(OffOn==1);
On = find(OffOn==-1);
OffPerioder = On - Off;
StartOff = Off(OffPerioder>t_seperation); % 10 minutes
SlutOff = On(OffPerioder>t_seperation);

% A not-worn period will normally be preceeded by at least a short period of some movement, so if movement is
% detected within 10 seconds before 'not-worn', it is not accepted as a not-worn period.
% All periods without activity lasting more than 90 minuttes are always not-worn.
Ok_logic = false(size(StartOff));
for i=1:length(StartOff)
    % [num2str(max(StdSum(StartOff(i)-15:StartOff(i)-11))) '  '  datestr(T(SF*StartOff(i)),'HH:MM:SS')]
    Ok_logic(i) = max(StdSum(max(StartOff(i)-15,1):max(StartOff(i)-11,5))) > 0.5... %max: problem if StartOff(1)<15
        || SlutOff(i) - StartOff(i) > tmin_notworn; %over 90min altid off
end
StartOff = StartOff(Ok_logic);
SlutOff = SlutOff(Ok_logic);

% Short periods (<1 minut) of activity between not-worn are filtered out
KortOn = (StartOff(2:end) - SlutOff(1:end-1)) < tShortWorn;

if ~isempty(KortOn)
    SlutOff = SlutOff([~KortOn,true]);
    StartOff = StartOff([true,~KortOn]);
end


% Move the still periods at the very begining and very end to the begining and of
% the total period respectively.

if  ~isempty(StartOff) && StartOff(1)< tEdgeWorn
    StartOff(1)=1;
end

if ~isempty(SlutOff) && (length(OffOn)-SlutOff(end))<tEdgeWorn
    SlutOff(end)=length(OffOn);
end


% Now fill the NotWornLogic vector with still periods which are larger
% than 90 minutes, or for shorter still periods where accelerometer is lying very flat
for i=1:length(StartOff)
    Vmean = 180*mean(V(StartOff(i):SlutOff(i),:))/pi;
    if  SlutOff(i)-StartOff(i)>tmin_notworn ... % >90 minuttes,always not-worn
            || all(abs(Vmean - [90,90,0]) < 5)... % Only not-worn if orientation differs less than 5°
            || all(abs(Vmean - [90,-90,0]) < 5)   % from "flat" lying orientation (up or down)
        
        NotWornLogic(StartOff(i):SlutOff(i)) = true;
    end
end


%% iterate through diaryStruct to find any forced NW and bed/night periods
oldEvent="NE";

% also find indices corresponding to the diary transitions if exist
[~,dTicks,dtickIndices]=intersect(datenum(diaryStrct.Ticks),round(smplTimes*86400)/86400);
% merge diary transitions with activity transitions
eventIndices=unique([1,length(smplTimes),dtickIndices']);
% iterate through each diary Event within the day
for itrEvnt=1:length(eventIndices)-1
    %find the current diary marker if exist
    dSection=find(dtickIndices==eventIndices(itrEvnt),1,'last');
    currEvent=diaryStrct.Events(dTicks(dSection));
    
    % if there is no Event flag and there is no diary, mark Event as ND
    % if there is no Event, but a Diary exist, use the last Event flag
    % If it's the first Event (i.e. no last), it's marked NE
    if isempty(currEvent)
        currEvent=oldEvent;
        
    elseif strcmpi(currEvent,'Start')
        currEvent="NE";
    else
        oldEvent=currEvent;
    end
    % trim the NotWorn vector to the diary Event
    EventIndcs=eventIndices(itrEvnt):eventIndices(itrEvnt+1);
    
    if strcmpi(currEvent,"Night") || strcmpi(currEvent,"Bed") || strcmpi(currEvent,"bedtime")
        NightLogic(EventIndcs)=true;
       
    elseif any(strcmpi(currEvent,["NW","MNW","FNW","ForcedNW"]),'all') %different types of NW keywords coming from diary
        NWForce(EventIndcs)=true;
    
    elseif  strcmpi(currEvent,"NE") || strcmpi(currEvent,"leisure") 
        T = rem(smplTimes(EventIndcs),1);
        NightStart = 22/24; % end of night at 22:00 when no diary night/bed exist
        NightEnd = 7/24; % wakeup at 07:00 when no diary night/bed exist
        Inight = T>NightStart | T<NightEnd;
        NightLogic(EventIndcs(Inight))=true;
    end
    
end

% mrege with diary-defined non-wear periods and also reduce the sensititvity of non-wear during night-times 
if all(~NightLogic) %no night time at all
    NotWornLogic=NotWornLogic | NWForce;
else
    %Find start and end of night periods (more than 1 is possible)
    Idiff = diff([false;NightLogic;false]);
    InightS = find(Idiff==1); %night period starts
    InightE = find(Idiff==-1)-1; %night period ends
    lenNight=zeros(length(InightS),1);
    for i=1:length(InightS)
        lenNight(i) = InightE(i)-InightS(i)+1;
        %If Off-time in night periods is < 50%, no Off-time at all:
        if sum(NotWornLogic(InightS(i):InightE(i))==1)/lenNight(i) < 0.5
            NotWornLogic(InightS(i):InightE(i)) = false;
        end
    end
    NotWornLogic=NotWornLogic | NWForce;
end

% find wear days based on wear-time per day and warn if too many non wear segments
WearDays=smplTimes(end)-smplTimes(1)-(sum(NotWornLogic)/(24*60*60));
rle_NW = rle(NotWornLogic);
numRegions=sum(rle_NW{1}==1);
if numRegions>WearDays
    warning=[warning,"High NW segments. Possible removal during non work hours?"];
end


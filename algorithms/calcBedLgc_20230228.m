% CALCBEDLGC Calculate bedtime logic using by filtering the activities
%
% %% Inputs %%%%%%%%%%%%%%%%%
% aktFull [double-n] - Full Activity vector given at 1s epoch for all days
% timeFull [datetime-n] - Full time vector given at 1s epochs
% lenAktFilt - upright events shorter than this time will be filtered out (also used for connecting ajacent SitLie bouts)
% lenLieFilt - The bedtime should at least be this amount long (also used for considering long Sit bouts for bedtime)
% VLongSitBt - very long sit bouts to consider for bedtime filtering (4*3600 default)
%
% %% Outputs%%%%%%%%%%%%%%%%%%%%
% bedLgc [double-n] - A logical vector given at 1s epoch representing bedtime status
%
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


function [bedLgc,bedFlags]=calcBedLgc(aktFull,timeFull,lenAktFilt,lenLieFilt,VLongSitBt)


MinLieBt=3600; % minimum lying bout to consider for bedtime expanding
MinSitBt=7200; % try to connect sit bouts longer than this to adjacent lying or very-long sit bouts

dayStartMx=hours(9); % how late a measurement can start (for finding primary bedtimes)
dayEndMin=hours(7); % how early a measurement can end (for finding primary bedtimes)
validDay=12; % minimum valid hours criteria for detecting bedtimes (

deltaT=60; % to remove very short gaps between SitLie bouts
% find the bout-runs by running run-length-encoding
runLs=rle(aktFull);

%first filter out very small gaps between large SitLie bouts

indsRunSitLie=find((runLs{1}==1 | runLs{1}==2) & runLs{2}>MinLieBt);

for itr=1:(length(indsRunSitLie)-1)
    indsGap=(indsRunSitLie(itr)+1):(indsRunSitLie(itr+1)-1);
    gapL=runLs{2}(indsGap); % lengths of the bouts within the gap
    gapL(ismember(runLs{1}(indsGap),[1,2]))=0; % do not consider sit/lie in the gap (consider only upright)
    gapLAll=sum(gapL); % the total upright time of the gap
    gapLAct=sum(gapL.*ismember(runLs{1}(indsGap),[5,6,7,8,9]));   % the total walking/stair/run/other,bicycling time
    if gapLAll<deltaT || (gapLAll<5*deltaT && gapLAct<deltaT) % if either the total gap length less than 1minute or gap length less than 5min & active time less than 1min
        
        % after removing the short gap, if a sit bout is adjacent to a lie bout, mark both as lie
        if runLs{1}(indsRunSitLie(itr))~=runLs{1}(indsRunSitLie(itr+1)) % after removing the short gap, if a sit bout is adjacent to a lie bout, mark both as lie
            runLs{1}(indsRunSitLie(itr))=1;
            runLs{1}(indsRunSitLie(itr+1))=1;
            runLs{1}(indsGap)=1;
        else
            runLs{1}(indsGap)=runLs{1}(indsRunSitLie(itr)); %mark the gaps with same either sit or lie
        end
    end
    
end

%readjust run length encoding
if any(diff(runLs{1})==0)
    runLs=rle(rle(runLs));
end

%Then expand Lie bouts and very large Sit bouts to adjacent large-sit or lie bouts by allowing a cumulative upright time of lenAktFilt
% we consider Lie bouts which are bigger than MinLieBt and Sitbouts which are bigger than VLongSitBt
indsRunSitLie=find((runLs{1}==1 & runLs{2}>MinLieBt) | (runLs{1}==2 & runLs{2}>max(VLongSitBt,lenLieFilt)));
% iterate through
for itr=1:length(indsRunSitLie)
    
    % find how far back we can search until hitting another SitLie bout
    if itr==1
        goBackStart=1;
    else
        goBackStart=indsRunSitLie(itr-1)+1;
    end
    goBackEnd=indsRunSitLie(itr)-1;
    
    % find how far forward we can search until hitting another SitLie bout
    goFwdStart=indsRunSitLie(itr)+1;
    if itr==length(indsRunSitLie)
        goFwdEnd=length(runLs{1});
    else
        goFwdEnd=indsRunSitLie(itr+1)-1;
    end
    
    %find the forward and backward bouts range
    goBackI=goBackEnd:-1:goBackStart;
    goFwdI=goFwdStart:goFwdEnd;
    % find all bout-runs for backwards and forward search (also flip the backward search bouts-runs)
    runL_BK=runLs{2}(goBackI);
    runL_FD=runLs{2}(goFwdI);
    
    % do not count NW bouts shorter than lenAktFilt (make the run-length zero)
    zeroBK=runLs{1}(goBackI)==0 & runL_BK<lenAktFilt;
    zeroFD=runLs{1}(goFwdI)==0 & runL_FD<lenAktFilt;
    
    % do not count sit bouts larger than MinSitBt
    zeroBK=zeroBK | (runLs{1}(goBackI)==2 & runL_BK>MinSitBt);
    zeroFD=zeroFD | (runLs{1}(goFwdI)==2 & runL_FD>MinSitBt);
    
    % also need to consider sit bouts larger than MinLieBt and also close to alie bout. How to do this?
    
    % do not count all lie bouts in forward or backward search
    zeroBK=zeroBK | runLs{1}(goBackI)==1;
    zeroFD=zeroFD | runLs{1}(goFwdI)==1;
    
    % make the effectiverun lengths of ignored bouts (Nw, sit and Lie) to zero
    runL_BK(zeroBK)=0;
    runL_FD(zeroFD)=0;
    
    % find the cumulative bout-runs of forward and backward search
    cumSum_BK=cumsum(runL_BK);
    cumSum_FD=cumsum(runL_FD);
    
    %  stop the search when sum of upright, short-sit or short-NW time reach lenAktFilt and stop at sit, lie only
    numBts_BK=find(cumSum_BK<lenAktFilt & runL_BK==0,1,'last');
    numBts_FD=find(cumSum_FD<lenAktFilt & runL_FD==0,1,'last');
    
    %     % find the edge of forward and backward searches (can only be a Lie bout or a large-sit or NW bout)
    %     numBts_BK=find(runL_BK(1:numBts_BK)==0,1,'last');
    %     numBts_FD=find(runL_FD(1:numBts_FD)==0,1,'last');
    
    %mark forward and backward bout-runs as 1 (ie.e. Lie). This is just a marker of Bedtime real Activities are not changed
    runLs{1}(goBackI(1:numBts_BK))=1; % mark forward adjacent sit bouts as 1
    runLs{1}(goFwdI(1:numBts_FD))=1;  % mark backward adjacent sit bouts as 1
    
    % also mark the current bout as 1 (Lie). This is because we consider long sit bouts for bedtime
    runLs{1}(indsRunSitLie(itr))=1;
end

% recalculate bout-runs by re-running run-length-encoding (in other words run-length-decoding)
tmpAkt=rle(runLs);

% filtering out short upright bouts
% bedLgc=~bwareaopen(tmpAkt~=1,lenAktFilt);
runLsUR=rle(tmpAkt~=1); % run length encoding of upright bouts
runLsUR{1}(runLsUR{1}==1 & runLsUR{2} < lenAktFilt)=0; % remove short upright bout from encoding (set to zero)
bedLgc=~rle(runLsUR); % inverse RLE the encoding and invert to find a logical vector of filtered sit/lie

% filter out one last time by and and considering a minimum of lenLieFilt and VLongSitBt for bedtime
runLsBL=rle(bedLgc);

for itr=1:length(runLsBL{1})
    if runLsBL{1}(itr)==1
        if aktFull(runLsBL{3}(itr))==1 && aktFull(runLsBL{4}(itr))==1 % if this sit/lie bout starts and ends with lying
            % do-not consider this lying bout because if it's too short
            if runLsBL{2}(itr)<lenLieFilt
                runLsBL{1}(itr)=0;
            end
        else % else if this sit/lie bout does not both starts and ends with lying
            if runLsBL{2}(itr)<max(VLongSitBt,lenLieFilt)
                runLsBL{1}(itr)=0; % do-not consider this lying bout because it's too short
            end
        end
        
    end
end


%do a run-length-decoding and  return the betime logical vector
bedLgc=rle(runLsBL);

%% scan through the full days to select primary bedtimes.
runLsBL=rle(bedLgc); % re-do the run-length-encoding (because we changed the encoding above)

startDay=dateshift(timeFull(1),'start','day'); % if the day starts dayStartMx hours or later starting day is next day, otherwise start day is today
endDay=dateshift(timeFull(end),'start','day'); % if the day ends dayEndMin or earlier last day is last-calander day, otherwise last-day is previous day

selDays=startDay:endDay;

nValiDays=0;

% only consider bedtimes falling within the startDay:endDay
selBedtms=find(runLsBL{1}==1);
bedStarts=timeFull(runLsBL{3}(selBedtms));
bedEnds=timeFull(runLsBL{4}(selBedtms));
bedMidpts=bedStarts+(bedEnds-bedStarts)/2;
tod_MidPts=timeofday(bedMidpts); % the timeofday of the midpoints as a duration vector
numChcks=3; % the number of different scoring checks

% create a scoring matrix to iterate through days and try to flag bedtimes for selection
selScore=zeros(length(selBedtms),numChcks); % a column vector to hold priority-score of each bedtime

% score based on whether  midpoints of bedtimes falls within 22:00 - 08:00 or 08:00 to 22:00
nightMidPts=tod_MidPts>=hours(22) | tod_MidPts<hours(8);
selScore(nightMidPts,2)=1;
selScore(~nightMidPts,2)=0.5;

% score by iterating through each bedtime
for itr=1:length(selBedtms)
    %score based on percentage of lying time within each bedtime
    selScore(itr,3)=sum(aktFull(runLsBL{3}(selBedtms(itr)):runLsBL{4}(selBedtms(itr)))==1)/runLsBL{2}(selBedtms(itr));
end

% iterate through each day and score based on number of bedtime-midpoints falling on 16:00 to 16:00 periods
%   2. Mark primary/secondary bedtimes based on a 48h window
validHrs=zeros(size(selDays));
for itrDay=1:length(selDays)
    
    % find bedtimes embedded in a period of 16:00 to 16:00 of the selected day and proportion of inclusion (using midpoint)
    startT=max(selDays(itrDay)-hours(8),timeFull(1)); endT=min(selDays(itrDay)+hours(16),timeFull(end)); % start end times of current 24h window
    % find bedtimes where it's midpoint is within selected time window
    
    embdBed24h=find(bedMidpts>=startT & bedMidpts<endT);
    validHrs(itrDay)=sum(aktFull(timeFull>=startT & timeFull<endT)~=0)/3600;
    if validHrs(itrDay)>=validDay
        if length(embdBed24h)==1
            selScore(embdBed24h(selScore(embdBed24h,1)~=1),1)=1;
        elseif length(embdBed24h)>1
            selScore(embdBed24h(selScore(embdBed24h,1)==0),1)=0.5;
        end
        nValiDays=nValiDays+1;
    else
        selScore(embdBed24h(selScore(embdBed24h,1)==0),1)=0.5;
    end
end

bedFlags=zeros(length(selBedtms),1); % the primary/secondary bedtime marker intialised as zeros

% iterate through each day and find primary/secondary bedtimes based on a 48h window
for itrDay=1:length(selDays)
    % find bedtimes embedded in a period of 04:00 to 04:00 of the selected day and proportion of inclusion (using midpoint)
    startT48h=max(selDays(itrDay)-hours(8),timeFull(1)); endT48h=min(selDays(itrDay)+hours(40),timeFull(end)); % start end times of current 24h window
    
    % find the total valid time within the 48h window (use data from previous iteration when available)
    if itrDay<length(selDays)
        validHrs48h=validHrs(itrDay)+validHrs(itrDay+1);
    else
        validHrs48h=sum(aktFull(timeFull>=startT48h & timeFull<endT48h)~=0)/3600;
    end
    % find how many bedtimes we should look for
    numBeds48h=round(validHrs48h/24);
    
    % find bedtimes where it's midpoint is within selected time window
    embdBed48h=find(bedMidpts>=startT48h & bedMidpts<endT48h);
    
    if length(embdBed48h)<=numBeds48h
        bedFlags(embdBed48h)=1;
    else
        bedFlags(embdBed48h)=-1;
        selScr48h=prod(selScore(embdBed48h,:),2);
        [~,indKp]=maxk(selScr48h,numBeds48h);
        bedFlags(embdBed48h(indKp))=1;
    end
end

bedFlags=[bedFlags,selScore,prod(selScore,2)];

% remove low scoring bedtimes from run-length-encoding
% runLsBL{1}(selBedtms(indDel))=0;

% finaly do a run-length-decoding to derive bedtimes
% bedLgc=rle(runLsBL);
% bedLgc=bwareaopen(bedLgc,lenLieFilt);

end
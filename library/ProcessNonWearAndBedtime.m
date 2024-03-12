function Akt = ProcessNonWearAndBedtime(firstday,V,Acc,SF,Tid,Akt,diaryStrct,Settings)

% ProcessNonWearAndBedtime Estimation of 'NonWear' periods for thigh accelerometers considering bed/night adjustments and 
% flag the diary night/bedtime as lying depending on Settings
%
% Calls the function 'NotWorn' for estimation of not-worn periods. For night/bed periods the not-worn criteria is modified
% so not-worn periods with less than 50% of not-worn are considered worn. Diary defined NW events overrule
% the automatic procedure.
%
% Input:
% firstDay [boolean]: Whether data comes from the first day or not (used to handle diaryStruct data)
% V [N,3]: Inclination, forward/backward angle, sideways angle (rad), (calculated by the function 'Vinkler')
% A [N,3]: Acceleration (G), (calculated by the function 'Vinkler').
% SF: Sample time (N=SF*n).
% Tid [n]: Time array (1 sec. step, datenum values).
% Akt [n]: Activity array (1 sec. step)
% diaryStrct: The diary structure containing manual NW and Night time data
% Settings: The Settings structure form main ActiPASS program
%
% Output:
% Akt [n]: redefined activity array including NW and/or diary defined lying


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

persistent oldEvent;

NightLogic=false(length(Tid),1); % Vector to hold night-time logic either from diary or

NWForce=false(length(Tid),1); % Vector to record forced NW times from diary

% also find indices corresponding to the diary transitions if exist
[~,dTicks,dtickIndices]=intersect(datenum(diaryStrct.Ticks),round(Tid*86400)/86400);
% merge diary transitions with activity transitions
eventIndices=unique([1,length(Tid),dtickIndices']);

% the previous Event to be used as the current event if no event is defined
if firstday
    oldEvent="NE";
end

if ~isempty(Akt) && strcmpi(Settings.NWCORRECTION,"lying")
    lenLieFilt=Settings.BDMINLIET*60; % minimum accepted bedtime
    lenAktFilt=Settings.BDMAXAKTT*60; % maximum active gap within a given bedtime
    bedLgc=~bwareaopen(Akt~=1 ,lenAktFilt);
    bedLgc=bwareaopen(bedLgc,lenLieFilt);
end

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
    
    if strcmpi(currEvent,"Night") || strcmpi(currEvent,"Bed") ||  strcmpi(currEvent,"bedtime")
        NightLogic(EventIndcs)=true;
        % if the flag NIGHTLIE is set
        if strcmpi(Settings.LIEALG,'diary')
            % change all sit periods to lie periods
            Akt(EventIndcs(Akt(EventIndcs)==2)) = 1;
        end
    elseif  any(strcmpi(currEvent,["NW","MNW","FNW","ForcedNW"]),'all') %different types of NW keywords coming from diary
        NWForce(EventIndcs)=true;
    elseif ~isempty(Akt) && strcmpi(Settings.NWCORRECTION,"lying") && any(strcmpi(Settings.LIEALG,["algA","algB"]))
        
        NightLogic(EventIndcs(bedLgc(EventIndcs)))=true;
        
    elseif strcmpi(currEvent,"NE") || strcmpi(currEvent,"leisure") 
        T = rem(Tid(EventIndcs),1);
        NightStart = 22/24;
        NightEnd = 8/24;
        Inight = T>NightStart | T<NightEnd;
        NightLogic(EventIndcs(Inight))=true;
    end
    
end


NW = NotWorn(V,Acc,SF); % Estimation of not-worn periods

if all(~NightLogic) %no night time at all
    NW=NW | NWForce;
else
    %Find start and end of night periods (more than 1 is possible)
    Idiff = diff([false;NightLogic;false]);
    InightS = find(Idiff==1); %night period starts
    InightE = find(Idiff==-1)-1; %night period ends
    lenNight=zeros(length(InightS),1);
    for i=1:length(InightS)
        lenNight(i) = InightE(i)-InightS(i)+1;
        %If Off-time in night periods is < 50%, no Off-time at all:
        if sum(NW(InightS(i):InightE(i))==1)/lenNight(i) < 0.5
            NW(InightS(i):InightE(i)) = false;
        end
    end
    NW=NW | NWForce;
end

Akt(NW)=0;

function NW = FindNonWearTrunk(firstday,V,Acc,SF,Tid,diaryStrct)

% Estimation of 'NonWear' periods for trunk, hip or arm accelerometers
%
% Calls the function 'NotWorn' for estimation of not-worn periods. For sleep periods the not-worn criteria is modified
% so not-worn periods with less than 50% of not-worn are considered worn. Manually selected off intervals (Setup) overrule
% the automatic procedure.
%
% Input:
% firstDay [boolean]: Whether data comes from the first day or not (used to handle diaryStruct data)
% V [N,3]: Inclination, forward/backward angle, sideways angle (rad), (calculated by the function 'Vinkler')
% A [N,3]: Acceleration (G), (calculated by the function 'Vinkler').
% SF: Sample time (N=SF*n).
% Tid [n]: Time array (1 sec. step, datenum values).
% diaryStrct: The diary structure containing manual NW and Night time data
%
%
% Output:
% NW [n]: logical Array  1 = Not-worn, 0 = worn

% Copyright (c) 2021-2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the Actipass repository (https://github.com/Ergo-Tools/ActiPASS).


persistent oldEvent;

NightLogic=false(length(Tid),1); % Vector to hold night-time logic either from diary or

NWForce=false(length(Tid),1); % Vector to record forced NW times from diary

% also find indices corresponding to the diary transitions if exist
[dTicks,dtickIndices]=matchDiaryTicks(diaryStrct.Ticks,Tid); % matched on whole seconds
% merge diary transitions with activity transitions
eventIndices=unique([1,length(Tid),dtickIndices']);

% the previous Event to be used as the current event if no event is defined
if firstday
    oldEvent="NE";
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
    
    if strcmpi(currEvent,"Night") || strcmpi(currEvent,"Bed") || strcmpi(currEvent,"bedtime")
        NightLogic(EventIndcs)=true;
    elseif strcmpi(currEvent,"NW")
        NWForce(EventIndcs)=true;
   
    else
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
    runsNL = rle(NightLogic); % run-length-encoding of night logic
    InightS = runsNL{3}(runsNL{1}==1)'; %night period starts
    InightE = runsNL{4}(runsNL{1}==1)'; %night period ends
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
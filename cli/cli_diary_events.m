function [evntMeta,eventsVis] = cli_diary_events(firstDay,diaryStrct,refPosStr,evntMeta,eventsVis,indsAktDay,timeFull)
%UNTITLED process diary events for visualization and interval/events based stats

% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (c) 2021-2025 Pasan Hettiarachchi and Peter Johansson

% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
% 
% This **ActiPASS_CLI code** in `/cli/` is licensed under the
% GNU General Public License, version 3.0 or (at your option) any later version.
% See `../LICENSES/GPL-3.0-or-later.txt` for more details.

% keep previous event and comments persistent
persistent oldEvent oldCmmnt
% also find indices corresponding to the diary transitions if exist
[~,dTicks,dtickIndices]=intersect(datenum(diaryStrct.Ticks),round(timeFull(indsAktDay)*86400)/86400);
% merge diary transitions with activity transitions
eventIndices=unique([indsAktDay(1),indsAktDay(end),(dtickIndices'+indsAktDay(1)-1)]);

% initialize persistent variables on the first-day
if firstDay
    oldEvent="NE";
    oldCmmnt="";
end

% find whether a diary exists or not
noDiary=isnat(diaryStrct.Ticks);

% iterate through each diary Event within the day

for itrEvnt=1:length(eventIndices)-1
    %find the current diary marker if exist
    dSection=find((dtickIndices+indsAktDay(1)-1)==eventIndices(itrEvnt),1,'last');
    currEvent=diaryStrct.Events(dTicks(dSection));
    %find the comment for the event if exist in diary
    dCommnt=diaryStrct.Comments(dTicks(dSection));
    % if there is no Event flag and there is no diary, mark Event as ND
    % if there is no Event, but a Diary exist, use the last Event flag
    % If it's the first Event (i.e. no last), it's marked NE
    if isempty(currEvent)
        if noDiary
            currEvent="ND";
            dCommnt="";
        else
            currEvent=oldEvent;
            dCommnt=oldCmmnt;
        end
    elseif strcmpi(currEvent,'Start')
        currEvent="NE";
    else
        oldEvent=currEvent;
        oldCmmnt=dCommnt;
    end
    
    % Trim the Akt and Tid vectors to only the current diary Event
    % including both start and end times. Therefore when
    % aggregating per/sec data from diary events we have to be aware of this
    
    if itrEvnt < length(eventIndices)-1
        % the end time of any event should be one second prior to the start of next event
        indEvntStart=eventIndices(itrEvnt);
        indEvntEnd=eventIndices(itrEvnt+1)-1;
    else
        % the end time of last event of the day is the last second of the day and no changes needed
        indEvntStart=eventIndices(itrEvnt);
        indEvntEnd=eventIndices(itrEvnt+1);
    end
    
    % save meta info related to this event in the structure array
    evntMeta.StartTs=[evntMeta.StartTs;timeFull(indEvntStart)];
    evntMeta.EndTs=[evntMeta.EndTs;timeFull(indEvntEnd)];
    evntMeta.Indices=[evntMeta.Indices;[indEvntStart,indEvntEnd]];
    evntMeta.Names=[evntMeta.Names;currEvent];
    evntMeta.Comments=[evntMeta.Comments;dCommnt];
    
    
    % assign to event information to eventVis structure
    eventVis.start=datetime(timeFull(indEvntStart),'ConvertFrom','datenum');
    eventVis.stop=datetime(timeFull(indEvntEnd),'ConvertFrom','datenum');
    eventVis.Event=currEvent;
    eventVis.Comment=dCommnt;
    %only assign the ref. position text to the first event of the day.
    % Could be changed later when/if ref.pos. finding changed
    if itrEvnt==1
        eventVis.Ref=refPosStr;
    else
        eventVis.Ref="";
    end
    eventsVis=[eventsVis,eventVis];

end
end


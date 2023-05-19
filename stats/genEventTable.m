function [status,finalEvntTbl] = genEventTable(perSecT,eventMeta,finalEvntTbl,evntGenStruct)
% genEventTable generate the ActiPASS event based  table from the given per-sec table
% Copyright (c) 2023, Pasan Hettiarachchi .
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

% set status to "OK"
status="OK";

% load data back from horzGenStruct

evntVarNames=evntGenStruct.evntVarNames;
evntVarTypes=evntGenStruct.evntVarTypes;
uiPgDlg=evntGenStruct.uiPgDlg;
Settings=evntGenStruct.Settings;
itrFil=evntGenStruct.itrFil;
subjctID=evntGenStruct.subjctID;
totFiles=evntGenStruct.totFiles;
qcBatch=evntGenStruct.qcBatch;
QC_Status=evntGenStruct.QC_Status;


% find the number of days
numEvents=length(eventMeta.Names);
%iterate through the days
eventTable=table('Size',[numEvents,length(evntVarNames)],'VariableTypes',evntVarTypes,'VariableNames',evntVarNames);

% fill common data for all rows
eventTable.SubjectID=repmat(subjctID,[numEvents,1]);
eventTable.QC_Status=repmat(QC_Status,[numEvents,1]);
eventTable.Batch=repmat(qcBatch,[numEvents,1]);



for itrEvent=1:numEvents
    %% update progress dialog
    uiPgDlg.Value=(itrFil-1)/totFiles+(1/totFiles)*(0.6+(itrEvent/numEvents)*0.2);
    uiPgDlg.Message="Event Table: ID: "+subjctID+". File "+itrFil+" of "+totFiles+...
        ", Event "+itrEvent+" of "+numEvents+"..";
    %% find basic data for this particular event
    
    % do a quality check of event indices and correct end index if end-index is equalent to start-index of next event.
    wrongEndInds=eq(eventMeta.Indices(1:end-1,2),eventMeta.Indices(2:end,1));
    if any(wrongEndInds)
        eventMeta.Indices(wrongEndInds,2)=eventMeta.Indices(wrongEndInds,2)-1;
    end
    evntStrtIndx=eventMeta.Indices(itrEvent,1);
    evntEndIndx=eventMeta.Indices(itrEvent,2);
    rowsEvnt=evntStrtIndx:evntEndIndx; % rows corresponding to current event in per-sec table
    
    
    evntPerSecT=perSecT(rowsEvnt,:);
    
    
    % fill information related to current day
    eventTable.EventStart(itrEvent)=datestr(eventMeta.StartTs(itrEvent),31);
    eventTable.EventStop(itrEvent)= datestr(eventMeta.EndTs(itrEvent),31);
    eventTable.Event(itrEvent)=eventMeta.Names(itrEvent);
    eventTable.Comment(itrEvent)=eventMeta.Comments(itrEvent);
    eventTable.Duration(itrEvent)=round(height(evntPerSecT)/60,Settings.prec_dig_min);
    
    rows_SI=evntPerSecT.SleepInterval ==1; % find the seconds flagged as sleep-interval
    rows_BT=evntPerSecT.Bedtime ==1; % find the seconds flagged as bedtime
    % call genVariables function
    eventTable=genVariables(eventTable,evntPerSecT.Activity,evntPerSecT.Steps,rows_SI,rows_BT,itrEvent,Settings);
    
    
    
    if uiPgDlg.CancelRequested
        status="Canceled";
        return;
    end
end
if isempty(finalEvntTbl)
    finalEvntTbl=eventTable;
else
    finalEvntTbl=vertcat(finalEvntTbl,eventTable);
end
end


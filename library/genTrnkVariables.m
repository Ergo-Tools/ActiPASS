
function status=genTrnkVariables(Akt,vTrnkRot,dlyMeta,evntMeta,saveDir,ID,Settings)
%genVariables generate variables for given activity of a given segment(a day or an Event)
% INPUTS:
% Akt [N,1] - a vector representing an activity or behaviour for each second
% vTrnkRot [Fs*N,3] - trunk angles (after reference-positions (rotation))
% Settings - the ActiPASS Settings structure containing  information about how to process data
% dlyMeta - metadata for days (like indices and times)
% evntMeta - metadata for intervals (like indices and times)
% saveDir - directory where to save tables (usually ID folder under IndividualOut)  

% OUTPUTS:
% status - "ok" if everything went well, otherwise detailed exception

% Copyright (c) 2024, Pasan Hettiarachchi .
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


Fs=25; % The resample frequency
baseVars=["StartT","EndT","Interval","NW_Trnk","Valid_Trnk","VrefTrunkAP","VrefTrunkLat"]; % basic information
angTres=["20","30","60","90"]; % thresholds for the variables below
thrshTrnk=str2double(angTres)*pi/180; % the same angles above as numbers
prec=2; % precision of minute variables

% inclination variables while different activities given at different angle thresholds
incVars=["IncTrunk","PctTrunk","ForwardIncTrunk","ForwardIncTrunkSit","ForwardIncTrunkStandMove","ForwardIncTrunkUpright"];
% maximum of above variables at 60-degree threshold
maxVars=["IncTrunkMax60","IncTrunkSitMax60","IncTrunkStandMoveMax60","IncTrunkUprightMax60"];
otherVars="IncTrunkWalk"; % only one variable so far

% combine all variables in to one vector
trnkVarNs=[baseVars,reshape(append(incVars',angTres).',1,[]),maxVars,otherVars];
% variable types for all variables
trnkVarTs=["string","string","string",repmat("double",1,length(trnkVarNs)-3)];

try
    % remove midnight breaks in events
    if strcmpi(Settings.TblFormat,"EventsNoBreak") && length(evntMeta.Names)>=2
        indsRLE = [find(evntMeta.Names(1:end-1) ~= evntMeta.Names(2:end));length(evntMeta.Names)]; % find unique consecutive events
        runL = diff([0;indsRLE ]); % run length of those events
        indsDel=setdiff(1:length(evntMeta.Names),indsRLE); % the indices of events to delete
        % if any events should be deleted
        if ~isempty(indsDel)
            evntMeta.StartTs(indsRLE,:)=evntMeta.StartTs(indsRLE-(runL-1),:); %adjust start time of the events if necessary
            evntMeta.Indices(indsRLE,1)=evntMeta.Indices(indsRLE-(runL-1),1); % adjust index of main 1S vector for each event if necessary
            % delete repeating events
            evntMeta.Names(indsDel,:)=[];
            evntMeta.StartTs(indsDel,:)=[];
            evntMeta.EndTs(indsDel,:)=[];
            evntMeta.Comments(indsDel,:)=[];
            evntMeta.Indices(indsDel,:)=[];
        end
        
    end
    
    
    % create empty tables for daily and interval based trunk data
    trnkDTbl=table('Size',[length(dlyMeta.StartTs),length(trnkVarNs)],'VariableTypes',trnkVarTs,'VariableNames',trnkVarNs);
    trnkETbl=table('Size',[length(evntMeta.StartTs),length(trnkVarNs)],'VariableTypes',trnkVarTs,'VariableNames',trnkVarNs);
    
    % do a quality check of daily indices and correct end-index if end-index is equalent to start-index of next day.
    badDlyEndIs=eq(dlyMeta.Indices(1:end-1,2),dlyMeta.Indices(2:end,1));
    if any(badDlyEndIs)
        dlyMeta.Indices(badDlyEndIs,2)=dlyMeta.Indices(badDlyEndIs,2)-1;
    end
    % process data daily
    for itrD=1:length(dlyMeta.StartTs)
        % find start/end indices of full 1s data for this day
        dStrtIndx=dlyMeta.Indices(itrD,1);
        dEndIndx=dlyMeta.Indices(itrD,2);
        % trim the activity vector and trunk angle matrix
        AktD=Akt(dStrtIndx:dEndIndx);
        vTrnkD=vTrnkRot(((dStrtIndx-1)*Fs+1):(dEndIndx*Fs),:);
        %update the table start/end times, day name and non-wear time
        trnkDTbl.StartT(itrD)=datestr(dlyMeta.StartTs(itrD),31);
        trnkDTbl.EndT(itrD)=datestr(dlyMeta.EndTs(itrD),31);
        trnkDTbl.Interval(itrD)=dlyMeta.Names(itrD);
        NW_T=sum(isnan(vTrnkD(1:Fs:end,1)))/60; % trunk non-wear time
        trnkDTbl.NW_Trnk(itrD)=round(NW_T,prec); 
        trnkDTbl.Valid_Trnk(itrD)=round(length(AktD)/60-NW_T,prec); % trunk valid time
        % trunk ref-position
        trnkDTbl.VrefTrunkAP(itrD)=dlyMeta.VrefTrnk(itrD,1);
        trnkDTbl.VrefTrunkLat(itrD)=dlyMeta.VrefTrnk(itrD,2);
        
        % start the calculation
        IpositiveU = vTrnkD(:,2)>=0;
        InotLie = ~reshape(repmat(AktD==1|AktD==0,Fs,1),1,[])'; %Indices for not lying (in order to exclude lying on the belly)
        %added 7/12-12: not lying must not include Akt==0 (if Akt==0 activity state is undefined)
        IforwardInc =  InotLie & IpositiveU;
        IsitFwd = reshape(repmat(AktD==2,Fs,1),1,[])' & IforwardInc; %Indices for sitting and forward inclined
        IstandmoveFwd = reshape(repmat(AktD==3|AktD==4,Fs,1),1,[])' & IforwardInc; %Indices for stand/move and forward inclined
        IuprightFwd = reshape(repmat(3<=AktD&AktD<=7,Fs,1),1,[])' & IforwardInc; %Indices for stand/move/walk/run/stair and forward inclined (oct13)
        for ith = 1:length(thrshTrnk)
            IncTrunk = sum(vTrnkD(:,1) >= thrshTrnk(ith));
            trnkDTbl.("IncTrunk"+angTres(ith))(itrD)=round(IncTrunk/Fs/60,prec);
            trnkDTbl.("PctTrunk"+angTres(ith))(itrD) = round(100*IncTrunk/sum(~isnan(vTrnkD(:,1))),prec);
            trnkDTbl.("ForwardIncTrunk"+angTres(ith))(itrD) = round(sum(vTrnkD(IforwardInc,1) >= thrshTrnk(ith))/Fs/60,prec);
            trnkDTbl.("ForwardIncTrunkSit"+angTres(ith))(itrD) = round(sum(vTrnkD(IsitFwd,1) >= thrshTrnk(ith))/Fs/60,prec);
            trnkDTbl.("ForwardIncTrunkStandMove"+angTres(ith))(itrD) = round(sum(vTrnkD(IstandmoveFwd,1) >= thrshTrnk(ith))/Fs/60,prec);
            trnkDTbl.("ForwardIncTrunkUpright"+angTres(ith))(itrD) = round(sum(vTrnkD(IuprightFwd,1) >= thrshTrnk(ith))/Fs/60,prec);  %oct13
        end
        trnkDTbl.IncTrunkMax60(itrD) = round(MaxIncTid(vTrnkD(:,1),IforwardInc,thrshTrnk(3),Fs)/60,prec);
        trnkDTbl.IncTrunkSitMax60(itrD) = round(MaxIncTid(vTrnkD(:,1),IsitFwd,thrshTrnk(3),Fs)/60,prec);
        trnkDTbl.IncTrunkStandMoveMax60(itrD) = round(MaxIncTid(vTrnkD(:,1),IstandmoveFwd,thrshTrnk(3),Fs)/60,prec);
        trnkDTbl.IncTrunkUprightMax60(itrD) = round(MaxIncTid(vTrnkD(:,1),IuprightFwd,thrshTrnk(3),Fs)/60,prec); %oct13
        
        
        %Find median inclination of trunk during walk:
        Iw = AktD==5 & ~isnan(vTrnkD(1:Fs:end,1))'; %walk and trunk not off
        if sum(Iw)>60 %if more than 1 minutes of walk is found
            Vtrunkplot = (180/pi)*vTrnkD(1:Fs:end,:);
            trnkDTbl.IncTrunkWalk(itrD) = median(Vtrunkplot(Iw,1));
        end
        
    end
    
    % do a quality check of daily indices and correct end-index if end-index is equalent to start-index of next day.
    badEvntEndIs=eq(evntMeta.Indices(1:end-1,2),evntMeta.Indices(2:end,1));
    if any(badEvntEndIs)
        evntMeta.Indices(badEvntEndIs,2)=evntMeta.Indices(badEvntEndIs,2)-1;
    end
    % process data daily
    for itrE=1:length(evntMeta.StartTs)
        % get event start and end indices from structure
        eStrtIndx=evntMeta.Indices(itrE,1);
        eEndIndx=evntMeta.Indices(itrE,2);
        % trim the activity vector and trunk angle matrix
        AktE=Akt(eStrtIndx:eEndIndx);
        vTrnkE=vTrnkRot(((eStrtIndx-1)*Fs+1):(eEndIndx*Fs),:);
        
        %update the table start/end times, day name and non-wear time
        trnkETbl.StartT(itrE)=datestr(evntMeta.StartTs(itrE),31);
        trnkETbl.EndT(itrE)=datestr(evntMeta.EndTs(itrE),31);
        trnkETbl.Interval(itrE)=evntMeta.Names(itrE);
        NW_T=sum(isnan(vTrnkE(1:Fs:end,1)))/60;
        trnkETbl.NW_Trnk(itrE)=round(NW_T,prec);
        trnkETbl.Valid_Trnk(itrE)=round(length(AktE)/60-NW_T,prec);
        
        % find day number for finding ref-positions
        dayN=find(floor(evntMeta.StartTs(itrE))==floor(dlyMeta.StartTs));
        
        % trunk ref-position
        trnkETbl.VrefTrunkAP(itrE)=dlyMeta.VrefTrnk(dayN,1);
        trnkETbl.VrefTrunkLat(itrE)=dlyMeta.VrefTrnk(dayN,2);
        
        % start the calculation
        IpositiveU = vTrnkE(:,2)>=0;
        InotLie = ~reshape(repmat(AktE==1|AktE==0,Fs,1),1,[])'; %Indices for not lying (in order to exclude lying on the belly)
        %added 7/12-12: not lying must not include Akt==0 (if Akt==0 activity state is undefined)
        IforwardInc =  InotLie & IpositiveU;
        IsitFwd = reshape(repmat(AktE==2,Fs,1),1,[])' & IforwardInc; %Indices for sitting and forward inclined
        IstandmoveFwd = reshape(repmat(AktE==3|AktE==4,Fs,1),1,[])' & IforwardInc; %Indices for stand/move and forward inclined
        IuprightFwd = reshape(repmat(3<=AktE&AktE<=7,Fs,1),1,[])' & IforwardInc; %Indices for stand/move/walk/run/stair and forward inclined (oct13)
        for ith = 1:length(thrshTrnk)
            IncTrunk = sum(vTrnkE(:,1) >= thrshTrnk(ith));
            trnkETbl.("IncTrunk"+angTres(ith))(itrE)=round(IncTrunk/Fs/60,prec);
            trnkETbl.("PctTrunk"+angTres(ith))(itrE) = round(100*IncTrunk/sum(~isnan(vTrnkE(:,1))),prec);
            trnkETbl.("ForwardIncTrunk"+angTres(ith))(itrE) = round(sum(vTrnkE(IforwardInc,1) >= thrshTrnk(ith))/Fs/60,prec);
            trnkETbl.("ForwardIncTrunkSit"+angTres(ith))(itrE) = round(sum(vTrnkE(IsitFwd,1) >= thrshTrnk(ith))/Fs/60,prec);
            trnkETbl.("ForwardIncTrunkStandMove"+angTres(ith))(itrE) = round(sum(vTrnkE(IstandmoveFwd,1) >= thrshTrnk(ith))/Fs/60,prec);
            trnkETbl.("ForwardIncTrunkUpright"+angTres(ith))(itrE) = round(sum(vTrnkE(IuprightFwd,1) >= thrshTrnk(ith))/Fs/60,prec);  %oct13
        end
        trnkETbl.IncTrunkMax60(itrE) = round(MaxIncTid(vTrnkE(:,1),IforwardInc,thrshTrnk(3),Fs)/60,prec);
        trnkETbl.IncTrunkSitMax60(itrE) = round(MaxIncTid(vTrnkE(:,1),IsitFwd,thrshTrnk(3),Fs)/60,prec);
        trnkETbl.IncTrunkStandMoveMax60(itrE) = round(MaxIncTid(vTrnkE(:,1),IstandmoveFwd,thrshTrnk(3),Fs)/60,prec);
        trnkETbl.IncTrunkUprightMax60(itrE) = round(MaxIncTid(vTrnkE(:,1),IuprightFwd,thrshTrnk(3),Fs)/60,prec); %oct13
        
        
        %Find median inclination of trunk during walk:
        Iw = AktE==5 & ~isnan(vTrnkE(1:Fs:end,1))'; %walk and trunk not off
        if sum(Iw)>60 %if more than 1 minutes of walk is found
            Vtrunkplot = (180/pi)*vTrnkE(1:Fs:end,:);
            trnkETbl.IncTrunkWalk(itrE) = median(Vtrunkplot(Iw,1));
        end
        
    end
    
    if ~Settings.EVALV
        % save daily trunk angle data
        dlyTrnkF=fullfile(saveDir,ID+" - Daily_TrunkData.csv");
        writetable(trnkDTbl,dlyTrnkF,'WriteMode','overwrite');
        
        % save interval(event) based trunk angle data
        evntTrnkF=fullfile(saveDir,ID+" - Event_TrunkData.csv");
        writetable(trnkETbl,evntTrnkF,'WriteMode','overwrite');
        
    end
    status="ok";
catch ME
    status=getReport(ME,'extended','hyperlinks','off');
end
end


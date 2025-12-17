function statTable = genVariables(statTable,PerSecT,rows_SI,rows_BT,itrSeg,Settings)
%genVariables generate variables for given activity of a given segment(a day or an Event)
% INPUTS:
% statTable - the table to fill data with
% PerSecT - ActiPASS 1s activity/posture table
%    PerSecT.Activity - a vector representing an activity or behaviour for each second
%    PerSecT.Steps - the steps count (when applicable) for each second
%    PerSecT.paee - intensity calculated from R raw+posture algorithm (if enabled)
% rows_SI - the logical flag representing sleep-interval for each second
% rows_BT - the logical flag representing bedtime for each second
% itrSeg - the iteration number of current segment
% Settings - the settings structure

% OUTPUTS:
% statTable - the table filled with data for this iteration

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

%% generate variables: here we go
% The activity types and corresponding numbers are:
% NonWear=0, Lie=1, Sit=2, Stand=3, Move=4, Walk=5, Run=6, Stair=7, Cycle=8, Other=9, Sleep=10, LieStill=11, Kneel=12

% selected variable names for statistics generation
statVars=Settings.statVars;

% find activity numbers and steps/s values from PerSecT
Activity=PerSecT.Activity;
Steps=PerSecT.Steps;


% precision of variables given in minutes
prec=Settings.prec_dig_min;
%generate non repetitive (for each activity or energy-class) basic variables
% statTable.Duration(itrSeg)=round(length(Activity)/60,prec);
% statTable.Excluded(itrSeg)=round(sum(Activity==-1)/60,prec);
statTable.NonWear(itrSeg)=round(sum(Activity==0)/60,prec);
statTable.ValidDuration(itrSeg)=round(sum(Activity~=0 & Activity~=-1)/60,prec);
statTable.Awake(itrSeg)=round(sum(Activity~=0 & Activity~=-1 & ~rows_SI)/60,prec); % wake-time in minutes
statTable.AwakeNW(itrSeg)=round(sum(Activity==0 & ~rows_SI)/60,prec); % non wear during awake times
statTable.TotalTransitions(itrSeg)= sum(diff(~rows_SI.*Activity)~=0); % total transitions (this actually includes transitions to/from NW or excluded periods)
statTable.Bedtime(itrSeg)= round(sum(Activity~=-1 & rows_BT)/60,prec); % bedtime in minutes
statTable.SleepInterval(itrSeg)=round(sum(Activity~=-1 & Activity~=0 & rows_SI)/60,prec); % sleep-interval in minutes
statTable.SlpIntNW(itrSeg)=round(sum(Activity==0 & rows_SI)/60,prec); % NW during sleep interval

%% generate TAI ("thigh activity index" which resembles a MET time series)

% create MAP for exponential filtering (smoothing) TAI
mapTC=containers.Map(["TC10","TC20","TC30","TC60","TC90","TC120"],[10,20,30,60,90,120]);
if  strcmpi(Settings.INT_ALG,"posture")
    dayTAI=Settings.MET_SI*(rows_SI & Activity~=-1 & Activity~=0)+... % sleep-interval
        Settings.MET_Lie*(~rows_SI & Activity==1)+...% lying
        Settings.MET_LieStill*(~rows_SI & Activity==11)+...% sleep-outside-bed (called LieStill)
        Settings.MET_Sit*(~rows_SI & Activity==2)+... % sitting
        Settings.MET_Stand*(~rows_SI & Activity==3)+... % standing
        Settings.MET_Move*(~rows_SI & Activity==4)+... % moving
        genMETWalk((~rows_SI & Activity==5),Steps*60,Settings)+... % walking
        Settings.MET_Running*(~rows_SI & Activity==6)+... %running
        Settings.MET_Stairs*(~rows_SI & Activity==7)+... % stair-walking
        Settings.MET_Cycle*(~rows_SI & Activity==8)+... & cycling
        genMETOther(~rows_SI & Activity==9,Steps*60,Settings); % other
    % all remaining seconds (non-wear or excluded) are flagged as -1
    dayTAI(dayTAI==0)=-1;

    % filter (smoothen) TAI if needed
    if ~strcmpi(Settings.FilterTAI,"off")
        % find the time-constant corresponding to the FilterTAI setting
        taiTC=mapTC(Settings.FilterTAI);
        % do the exponential filtering (smoothing)
        alpha = 1-exp(-1/taiTC);
        dayTAI=filter(alpha, [1 alpha-1], dayTAI);
    end

    %discretaize TAI to intensity classes
    dayPALevels = discretize(dayTAI,[Settings.MET_INT_Slp,Settings.MET_INT_SED,Settings.MET_INT_LPA,Settings.MET_INT_LPA_Amb,Settings.MET_INT_MPA,Settings.MET_INT_VPA, inf],...
        'categorical',["Slp","SED","LPA","LPA_Amb","MPA","VPA"]);

elseif strcmpi(Settings.INT_ALG,"raw+posture")
    % set paee of excluded and non-wear times to -1
    PerSecT.paee(Activity==-1 | Activity==0)=-1; %excluded or non-wear
    PerSecT.paee(rows_SI & Activity~=-1 & Activity~=0)=-0.5; %sleep-interval
    
    % filter (smoothen) PAEE if needed
    if ~strcmpi(Settings.FilterTAI,"off")
        % find the time-constant corresponding to the FilterTAI setting
        taiTC=mapTC(Settings.FilterTAI);
        % do the exponential filtering (smoothing)
        alpha = 1-exp(-1/taiTC);
        PerSecT.paee=filter(alpha, [1 alpha-1], PerSecT.paee);
    end

    %discretaize TAI to intensity classes
    dayPALevels = discretize(PerSecT.paee,[-0.6, 0, 0.0349, 0.2092, 0.4184, inf],...
        'categorical',["Slp","SED","LPA","MPA","VPA"]);
    % add category LPA_Amb in order to match the workflow posture only intensity algorithm
    dayPALevels = addcats(dayPALevels,"LPA_Amb",After="LPA");
end
%% generate daily basic activity times

statTable.Sleep(itrSeg)=round(sum(Activity==10)/60,prec); % total sleep both in-bed and out-bed in minutes
statTable.SleepInBed(itrSeg)=round(sum(Activity==10)/60,prec); % total sleep in-bed  in minutes
statTable.LieStill(itrSeg)=round(sum(Activity==11)/60,prec); % total sleep  out-bed in minutes
statTable.NumSteps(itrSeg)=round(sum((~rows_SI & (Activity==4 | Activity==5 |...
    Activity==6 | Activity==7)).*Steps)); % number of steps outside sleep-interval
statTable.NumStepsWalk(itrSeg)=round(sum((~rows_SI & Activity==5).*Steps)); % number of steps of walking outside sleep-interval
statTable.NumStepsRun(itrSeg)=round(sum((~rows_SI & Activity==6).*Steps)); % number of steps of walking outside sleep-interval


%% generate descriptive parameters part 2
% flag the seconds of Sit or Lie (including possible sleep outside bedtime) outside sleep interval
for itrVarN=1:length(statVars)
    switch(statVars(itrVarN))
        case "Lie"
            rowsVarN= ~rows_SI &(Activity==1 | Activity==11);
        case "Sit"
            rowsVarN= ~rows_SI &(Activity==2);
        case "SitLie"
            rowsVarN= ~rows_SI &(Activity==1 | Activity==2 | Activity==11);
        case "Stand"
            rowsVarN=~rows_SI &(Activity==3);
        case "Move"
            rowsVarN=~rows_SI &(Activity==4);
        case "StandMove"
            rowsVarN=~rows_SI &(Activity==3 |Activity==4);
        case "Walk"
            rowsVarN=~rows_SI &(Activity==5);
        case "Walk_Slow"
            rowsVarN=~rows_SI & (Activity==5) & Steps<Settings.Wlk_Slow_Cad/60;
        case "Walk_Fast"
            rowsVarN=~rows_SI & (Activity==5) & Steps>=Settings.Wlk_Slow_Cad/60;
        case "Run"
            rowsVarN=~rows_SI &(Activity==6);
        case "Stair"
            rowsVarN=~rows_SI &(Activity==7);
        case "Cycle"
            rowsVarN=~rows_SI &(Activity==8);
        case "Upright"
            rowsVarN=~rows_SI & (Activity==3 | Activity==4 | Activity==5 | Activity==6 | Activity==7);
        case "Other"
            rowsVarN=~rows_SI &(Activity==9);
        case "Kneel"
            rowsVarN=~rows_SI &(Activity==12);
        case "INT1"
            rowsVarN= dayPALevels=="SED";
        case "INT2"
            rowsVarN= (dayPALevels=="LPA" | dayPALevels=="LPA_Amb");
        case "INT2_Amb"
            rowsVarN= dayPALevels=="LPA_Amb";
        case "INT3"
            rowsVarN= dayPALevels=="MPA";
        case "INT4"
            rowsVarN= dayPALevels=="VPA";
        case "INT34"
            rowsVarN= (dayPALevels=="VPA" | dayPALevels=="MPA");
    end
    statTable.(statVars(itrVarN))(itrSeg)=round(sum(rowsVarN)/60,prec); % total duration of selected activity or intensity-class

    % call the bouts and segment-time percentile generation function

    if strcmpi(Settings.genBouts,"on") && matches(statVars(itrVarN),Settings.VarsBout)
        % call the stat generation function with seconds flagged with a given activity, combined-activity or intensity class
        [statTable.(statVars(itrVarN)+"_Tmax")(itrSeg),statTable.(statVars(itrVarN)+"_P50")(itrSeg),...
            statTable.(statVars(itrVarN)+"_T50")(itrSeg),statTable.(statVars(itrVarN)+"_P10")(itrSeg),...
            statTable.(statVars(itrVarN)+"_P90")(itrSeg),statTable.(statVars(itrVarN)+"_T30min")(itrSeg),...
            statTable.(statVars(itrVarN)+"_N30min")(itrSeg), statTable.(statVars(itrVarN)+"_NBreaks")(itrSeg),...
            statTable.(statVars(itrVarN)+"_1min_bouts_TH")(itrSeg),statTable.(statVars(itrVarN)+"_2min_bouts_TH")(itrSeg),...
            statTable.(statVars(itrVarN)+"_3min_bouts_TH")(itrSeg),statTable.(statVars(itrVarN)+"_4min_bouts_TH")(itrSeg),...
            statTable.(statVars(itrVarN)+"_5min_bouts_TH")(itrSeg),statTable.(statVars(itrVarN)+"_10min_bouts_TH")(itrSeg),...
            statTable.(statVars(itrVarN)+"_30min_bouts_TH")(itrSeg),statTable.(statVars(itrVarN)+"_60min_bouts_TH")(itrSeg),...
            statTable.(statVars(itrVarN)+"_1min_freq_H")(itrSeg),statTable.(statVars(itrVarN)+"_2min_freq_H")(itrSeg),...
            statTable.(statVars(itrVarN)+"_3min_freq_H")(itrSeg),statTable.(statVars(itrVarN)+"_4min_freq_H")(itrSeg),...
            statTable.(statVars(itrVarN)+"_5min_freq_H")(itrSeg),statTable.(statVars(itrVarN)+"_10min_freq_H")(itrSeg),...
            statTable.(statVars(itrVarN)+"_30min_freq_H")(itrSeg),statTable.(statVars(itrVarN)+"_60min_freq_H")(itrSeg),...
            statTable.(statVars(itrVarN)+"_1min_bouts_TL")(itrSeg),statTable.(statVars(itrVarN)+"_2min_bouts_TL")(itrSeg),...
            statTable.(statVars(itrVarN)+"_3min_bouts_TL")(itrSeg),statTable.(statVars(itrVarN)+"_4min_bouts_TL")(itrSeg),...
            statTable.(statVars(itrVarN)+"_5min_bouts_TL")(itrSeg),statTable.(statVars(itrVarN)+"_10min_bouts_TL")(itrSeg),...
            statTable.(statVars(itrVarN)+"_30min_bouts_TL")(itrSeg),statTable.(statVars(itrVarN)+"_60min_bouts_TL")(itrSeg),...
            statTable.(statVars(itrVarN)+"_1min_freq_L")(itrSeg),statTable.(statVars(itrVarN)+"_2min_freq_L")(itrSeg),...
            statTable.(statVars(itrVarN)+"_3min_freq_L")(itrSeg),statTable.(statVars(itrVarN)+"_4min_freq_L")(itrSeg),...
            statTable.(statVars(itrVarN)+"_5min_freq_L")(itrSeg),statTable.(statVars(itrVarN)+"_10min_freq_L")(itrSeg),...
            statTable.(statVars(itrVarN)+"_30min_freq_L")(itrSeg),statTable.(statVars(itrVarN)+"_60min_freq_L")(itrSeg)] = genAktStats(rowsVarN',Settings);

    end
end


end

function walkMET=genMETWalk(WlkLgc,Cadence,Settings)
% genMETWalk calculate MET based on cadence for walking
if strcmpi(Settings.WalkMET,"fixed")
    walkMET=(WlkLgc & Cadence <Settings.Wlk_Slow_Cad)*Settings.Wlk_Low_MET+...
        (WlkLgc & (Cadence >=Settings.Wlk_Slow_Cad & Cadence <Settings.Wlk_VFast_Cad))*Settings.Wlk_Fast_MET+...
        (WlkLgc & Cadence >=Settings.Wlk_VFast_Cad)*Settings.Wlk_VFast_MET;
elseif strcmpi(Settings.WalkMET,"regression")
    height=Settings.wlkHeight;
    walkMET=WlkLgc.*(15.49-(0.55* Cadence) + (4.82e-3*Cadence.^2)-(1.19e-5*Cadence.^3) + (3.48e-2*height));
end
end

function otherMET=genMETOther(OtherLgc,Cadence,Settings)
% genMETOther calculate MET based on cadence for "Other" activities
height=Settings.wlkHeight;
MET_Other=Settings.MET_Other;
if strcmpi(Settings.WalkMET,"fixed")
    otherMET_Cadence=(OtherLgc & Cadence~=0).* ...
        ((Cadence<Settings.Wlk_Slow_Cad)*Settings.Wlk_Low_MET+...
        (Cadence >=Settings.Wlk_Slow_Cad & Cadence <Settings.Wlk_VFast_Cad)*Settings.Wlk_Fast_MET+...
        (Cadence >=Settings.Wlk_VFast_Cad)*Settings.Wlk_VFast_MET);
    otherMET_NoCadence=(OtherLgc & Cadence==0)*MET_Other;
    otherMET=otherMET_Cadence+otherMET_NoCadence;
elseif strcmpi(Settings.WalkMET,"regression")
    otherMET_Cadence=(OtherLgc & Cadence~=0).*(15.49-(0.55* Cadence) + (4.82e-3*Cadence.^2)-(1.19e-5*Cadence.^3) + (3.48e-2*height));
    otherMET_NoCadence=(OtherLgc & Cadence==0)*MET_Other;
    otherMET=otherMET_Cadence+otherMET_NoCadence;
end
end

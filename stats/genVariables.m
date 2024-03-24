function statTable = genVariables(statTable,Activity,Steps,rows_SI,rows_BT,itrSeg,Settings)
%genVariables generate variables for given activity of a given segment(a day or an Event)
% INPUTS:
% statTable - the table to fill data with
% Activity - a vector representing an activity or behaviour for each second
% Steps - the steps count (when applicable) for each second
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
% NonWear=0, Lie=1, Sit=2, Stand=3, Move=4, Walk=5, Run=6, Stair=7, Cycle=8, Other=9, Sleep=10, LieStill=11

statVars=["Lie","Sit","SitLie","Stand","Move","StandMove","Walk","Run","Stair","Cycle","Upright","Other","INT1",...
    "INT2","INT2_Amb","INT3","INT4","INT34"];
% check whether to use steps/min in intensity and walk_slow walk_fast calculations
if Settings.CADPMIN
    Steps60=movmean(Steps,60); % calculate steps/min based on one minute window
    %Steps60=movmean(Steps,[0,60],'SamplePoints',1:60:length(Steps));
else
    Steps60=Steps; % use steps/sec as it is
end
% precision of variables given in minutes
prec=Settings.prec_dig_min; 
%generate non repetitive (for each activity or energy-class) basic variables
% statTable.Duration(itrSeg)=round(length(Activity)/60,prec);
% statTable.Excluded(itrSeg)=round(sum(Activity==-1)/60,prec);
statTable.NonWear(itrSeg)=round(sum(Activity==0)/60,prec);
statTable.ValidDuration(itrSeg)=round(sum(Activity~=0 & Activity~=-1)/60,prec);
statTable.Awake(itrSeg)=round(sum(Activity~=0 & Activity~=-1 & ~rows_SI)/60,prec); % wake-time in minutes
statTable.AwakeNW(itrSeg)=round(sum(Activity==0 & ~rows_SI)/60,prec); % non wear during awake times
statTable.Walk_Slow(itrSeg)=round(sum(Activity==5 & ~rows_SI & Steps60<Settings.Wlk_Slow_Cad/60)/60,prec);
statTable.Walk_Fast(itrSeg)=round(sum(Activity==5 & ~rows_SI & Steps60>=Settings.Wlk_Slow_Cad/60)/60,prec);
statTable.TotalTransitions(itrSeg)= sum(diff(~rows_SI.*Activity)~=0); % total transitions (this actually includes transitions to/from NW or excluded periods)
statTable.Bedtime(itrSeg)= round(sum(Activity~=-1 & rows_BT)/60,prec); % bedtime in minutes
statTable.SleepInterval(itrSeg)=round(sum(Activity~=-1 & Activity~=0 & rows_SI)/60,prec); % sleep-interval in minutes
statTable.SlpIntNW(itrSeg)=round(sum(Activity==0 & rows_SI)/60,prec); % NW during sleep interval

%% generate TAI

dayTAI=Settings.MET_SI*(rows_SI & Activity~=-1 & Activity~=0)+... % sleep-interval
    Settings.MET_Lie*(~rows_SI & Activity==1)+...% lying
    Settings.MET_LieStill*(~rows_SI & Activity==11)+...% sleep-outside-bed (called LieStill)
    Settings.MET_Sit*(~rows_SI & Activity==2)+... % sitting
    Settings.MET_Stand*(~rows_SI & Activity==3)+... % standing
    Settings.MET_Move*(~rows_SI & Activity==4)+... % moving
    genMETWalk((~rows_SI & Activity==5),Steps60*60,Settings)+... % walking
    Settings.MET_Running*(~rows_SI & Activity==6)+... %running
    Settings.MET_Stairs*(~rows_SI & Activity==7)+... % stair-walking
    Settings.MET_Cycle*(~rows_SI & Activity==8)+... & cycling
    genMETOther(~rows_SI & Activity==9,Steps60*60,Settings); % other
% all remaining seconds (non-wear or excluded) are flagged as -1
dayTAI(dayTAI==0)=-1;

% filter TAI if needed
if ~strcmpi(Settings.FilterTAI,"off")
    if strcmpi(Settings.FilterTAI,"TC2")
        taiTC=2;
    elseif strcmpi(Settings.FilterTAI,"TC5")
        taiTC=5;
    elseif  strcmpi(Settings.FilterTAI,"TC10")
        taiTC=10;
    elseif  strcmpi(Settings.FilterTAI,"TC20")
        taiTC=20;
    elseif  strcmpi(Settings.FilterTAI,"TC30")
        taiTC=30;
    elseif  strcmpi(Settings.FilterTAI,"TC60")
        taiTC=60;
    end
    alpha = 1-exp(-1/taiTC);
    dayTAI=filter(alpha, [1 alpha-1], dayTAI);
end

%discretaize TAI to intensity classes
dayPALevels = discretize(dayTAI,[Settings.PA_Slp,Settings.PA_SED,Settings.PA_LPA,Settings.PA_LPA_Amb,Settings.PA_MPA,Settings.PA_VPA, inf],...
    'categorical',{'Slp','SED','LPA','LPA_Amb','MPA','VPA'});

%% generate daily basic activity times

statTable.Sleep(itrSeg)=round(sum(Activity==10)/60,prec); % total sleep both inbed and outbed in minutes
statTable.SleepInBed(itrSeg)=round(sum(Activity==10)/60,prec); % total sleep inbed  in minutes
statTable.LieStill(itrSeg)=round(sum(Activity==11)/60,prec); % total sleep  outbed in minutes
statTable.NumSteps(itrSeg)=round(sum((~rows_SI & (Activity==4 | Activity==5 |...
    Activity==6 | Activity==7)).*Steps)); % number of steps outside sleep-interval in minutes
statTable.NumStepsWalk(itrSeg)=round(sum((~rows_SI & Activity==5).*Steps)); % number of steps of walking outside sleep-interval in minutes
statTable.NumStepsRun(itrSeg)=round(sum((~rows_SI & Activity==6).*Steps)); % number of steps of walking outside sleep-interval in minutes


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
    statTable.(statVars(itrVarN))(itrSeg)=round(sum(rowsVarN)/60,prec); % sitting and lying time outside sleep-interval in minutes
    % call the stat generation function
    
    if strcmpi(Settings.genBouts,"on")
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
    else
        % call the stat generation function with seconds flagged with a given activity, combined-activity or intensity class
        % use only percentile variables
        [statTable.(statVars(itrVarN)+"_Tmax")(itrSeg),statTable.(statVars(itrVarN)+"_P50")(itrSeg),...
            statTable.(statVars(itrVarN)+"_T50")(itrSeg),statTable.(statVars(itrVarN)+"_P10")(itrSeg),...
            statTable.(statVars(itrVarN)+"_P90")(itrSeg),statTable.(statVars(itrVarN)+"_T30min")(itrSeg),...
            statTable.(statVars(itrVarN)+"_N30min")(itrSeg), statTable.(statVars(itrVarN)+"_NBreaks")(itrSeg)]=genAktStats(rowsVarN',Settings); % call the stat generation function with seconds flagged with Sit or Lie
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

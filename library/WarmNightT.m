function [WarmNightLogic,warning] = WarmNightT(meanTEMP,SmplTimes,NightLogic)

% WarmNightT Find warm night periods. Uses diary and/or time-of-day based NightLogic found earlier. 
%
% Bedtime is based on both time-of-day (22-08hrs) and temperature profiling.
% If Temperature is empty just the time-of-day is used.
% Date: 2019-12-24  (c) 2019, Pasan Hettiarachchi, Uppsala University
% Inputs:
% Temperature = [N,2] Temperature data (time and temperature)
% SmplTimes = [M] the sample times in datenum format
% NightLogic = [M] the logical vector for night/bed times (from diary or time-of-day) at SmplTimes
%
% Outputs:
% WarmNightLogic =[M] Logical vector of warm night periods given at SmplTimes
% warning: [P] String array of warnings

% **********************************************************************************
% % Copyright (c) 2022, Pasan Hettiarachchi .
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
% ************************************************************************************

JoinTimerActive=  2*60; %[s] % Time limit between identified points for joining them together in a unified section, also disregards any sections shorter than JoinTimer
JoinTimerSleep= 45 * 60; %[s] % Time limit between identified points for joining them together in a unified section, also disregards any sections shorter than JoinTimer
TempLimit=31.7; %[C] % Temperature thereshold which deterims if some time should be classified as sleep or not default 31.7
TShortLimit=1; %[hours] % Limit for shortest allowed sleep (if a sleep section is shorter than 1 hours and more than 50 mins away from another sleep sections it is disregarded)
TMedFWin=60*3; %[s] % Time window for median filtering warm sections.
warning=string([]);



%% Processing Temperature data
% Find the sample-interval of temperature using mean of diff of time vector
if ~isempty(meanTEMP)
    % warn if summer months    
    if any(ismember(string(datestr([SmplTimes(1),SmplTimes(end)],'mmm')),["Jun","Jul","Aug"]))
        warning=[warning,"Summer months, possible incorrect bedtimes used for Flip detection"];
    end
            
    % median filtering
    meanTEMPFilt=medfilt1(meanTEMP,TMedFWin);
    %PickedSD=medfilt1(PickedSD,Sleepmfwindow);% this represents a window of 12*Nminuites*2(1-overlap)
    %%Logic
    
    LogicWarm=meanTEMPFilt>TempLimit; % 
    WarmNightLogic=LogicWarm & NightLogic ;
else
    
    %warning=[warning,"Bedtime detection for flip-detection: Temperature matrix is empty. Accuracy is reduced."];
    WarmNightLogic=NightLogic ;
end
%% Main Night adjustment

% first filter WarmNightLogic with JoinTimerActive
WarmNightLogic=~bwareaopen(~WarmNightLogic, JoinTimerActive); % join groups togheter
WarmNightLogic=bwareaopen(WarmNightLogic, JoinTimerSleep); % remove lonly small groups


% Now remove short sleep sections.
% Also check for sleep overclassifications

rle_WN=rle(WarmNightLogic); % use run-length-encoding to find bouts of WarmNightLogic
SectionsWNL=find(rle_WN{1}==1);

Overclass=false;
for b=1:length(SectionsWNL)
    if rle_WN{2}(SectionsWNL(b))/3600<TShortLimit % 3 h
        WarmNightLogic(rle_WN{3}(SectionsWNL(b)):rle_WN{4}(SectionsWNL(b)))=false; % no short sleep accepted?
    end
    if rle_WN{2}(SectionsWNL(b))/3600>11 % 11 h
        Overclass=true;  % there is possible a overclassification of sleeping
    end
    
end

if Overclass
    warning=[warning,"Possible bedtime over-estimate for Flip detection"];
end



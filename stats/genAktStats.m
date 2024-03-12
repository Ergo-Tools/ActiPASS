function [akt_Tmax,akt_P50,akt_T50,akt_P10,akt_P90,akt_T30min,akt_N30min,akt_NBrk,...
    th_1min_bouts,th_2min_bouts,th_3min_bouts,th_4min_bouts,th_5min_bouts,th_10min_bouts,...
    th_30min_bouts,th_60min_bouts,b1min_freq_H,b2min_freq_H,b3min_freq_H,b4min_freq_H,...
    b5min_freq_H,b10min_freq_H,b30min_freq_H,b60min_freq_H,tl_1min_bouts,tl_2min_bouts,...
    tl_3min_bouts,tl_4min_bouts,tl_5min_bouts,tl_10min_bouts,tl_30min_bouts,tl_60min_bouts,...
    b1min_freq_L,b2min_freq_L,b3min_freq_L,b4min_freq_L,b5min_freq_L,b10min_freq_L,...
    b30min_freq_L,b60min_freq_L] = genAktStats(Akt,Settings)

% genAktStats generate table variables for given activity type.
% activity type could be both direct activity types such as sit, walk or
% energy based types such as LPA, MPA etc

%INPUTS:
% Akt: A logical vector of given activity is true for each second
% Settings: Settings structure

% OUTPUTS:
% See output structure fields below - some are self described. Some definitions follows.

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

%define bout variables for all activity/intensity classes
% varN_Bouts_TH=["1min_bouts_TH","2min_bouts_TH","3min_bouts_TH",...
%     "4min_bouts_TH","5min_bouts_TH","10min_bouts_TH","30min_bouts_TH","60min_bouts_TH",...
%     "1min_freq_H","2min_freq_H","3min_freq_H","4min_freq_H",...
%     "5min_freq_H","10min_freq_H","30min_freq_H","60min_freq_H"];
%
% varN_Bouts_TL=["1min_bouts_TL","2min_bouts_TL","3min_bouts_TL",...
%     "4min_bouts_TL","5min_bouts_TL","10min_bouts_TL","30min_bouts_TL","60min_bouts_TL",...
%     "1min_freq_L","2min_freq_L","3min_freq_L","4min_freq_L",...
%     "5min_freq_L","10min_freq_L","30min_freq_L","60min_freq_L"];




prec_dig=Settings.prec_dig_min; % precision of results in decimal points
boutThresh=Settings.boutThresh; % bout threshold value

boutBreak=Settings.boutBreak; % bout break for all bouts except 1 min bout


OnOff = diff([0,Akt,0]);
On = find(OnOff==1);
Off = find(OnOff==-1);
Times = Off-On;
%akt_Pauses = On(2:end)-Off(1:end-1);

if isempty(Times)
    [akt_Tmax,akt_P50,akt_T50,akt_P10,akt_P90,akt_T30min,akt_N30min,akt_NBrk,...
        th_1min_bouts,th_2min_bouts,th_3min_bouts,th_4min_bouts,th_5min_bouts,...
        th_10min_bouts,th_30min_bouts,th_60min_bouts,tl_1min_bouts,tl_2min_bouts,...
        tl_3min_bouts,tl_4min_bouts,tl_5min_bouts,tl_10min_bouts,tl_30min_bouts,...
        tl_60min_bouts,b1min_freq_H,b2min_freq_H,b3min_freq_H,b4min_freq_H,b5min_freq_H,...
        b10min_freq_H, b30min_freq_H,b60min_freq_H,b1min_freq_L,b2min_freq_L,b3min_freq_L,...
        b4min_freq_L,b5min_freq_L,b10min_freq_L,b30min_freq_L,b60min_freq_L] = deal(NaN);
    return
end

akt_Tmax = round(max(Times)/60,prec_dig); %maximum time akt bout in minutes

aktPrctiles = prctile(Times,[10 50 90]); % 10th, 50th and 90th percentile times of akt in minutes
akt_P10 = round(aktPrctiles(1)/60,prec_dig);
akt_P50 = round(aktPrctiles(2)/60,prec_dig); %median
akt_P90 = round(aktPrctiles(3)/60,prec_dig);
akt_T50 = round(sum(Times(Times>=aktPrctiles(2)))/60,prec_dig); %minutes spent in periods longer than median

i30 = Times>=1800; %30 minuttes
akt_T30min = round(sum(Times(i30))/60,prec_dig); %minutes spent in periods longer than 30 minuttes
akt_N30min = sum(i30); % number of periods longer than 30 minuttes

%if bouts generation is enabled calculate bouts, otherwise those variables will be NaN
if strcmpi(Settings.genBouts,"on")
    [th_1min_bouts,b1min_freq_H,tl_1min_bouts,b1min_freq_L]=findBouts(Akt,60,boutBreak,boutThresh); % for 1min bouts set a bout break of 20 secs, for all other bouts it's fixed at 60s
    th_1min_bouts=round(th_1min_bouts/60,prec_dig); % time spent in 1min bouts
    tl_1min_bouts=round(tl_1min_bouts/60,prec_dig); % time spent bouts less than 1min
    
    [th_2min_bouts,b2min_freq_H,tl_2min_bouts,b2min_freq_L]=findBouts(Akt,120,boutBreak,boutThresh); % find 2min bouts. Bout breaks is fixed at 60s
    th_2min_bouts=round(th_2min_bouts/60,prec_dig); % time spent in 1min bouts
    tl_2min_bouts=round(tl_2min_bouts/60,prec_dig); % time spent bouts less than 1min
    
    [th_3min_bouts,b3min_freq_H,tl_3min_bouts,b3min_freq_L]=findBouts(Akt,180,boutBreak,boutThresh); % find 3min bouts. Bout breaks is fixed at 60s
    th_3min_bouts=round(th_3min_bouts/60,prec_dig); % time spent in 1min bouts
    tl_3min_bouts=round(tl_3min_bouts/60,prec_dig); % time spent bouts less than 1min
    
    [th_4min_bouts,b4min_freq_H,tl_4min_bouts,b4min_freq_L]=findBouts(Akt,240,boutBreak,boutThresh); % find 4min bouts. Bout breaks is fixed at 60s
    th_4min_bouts=round(th_4min_bouts/60,prec_dig); % time spent in 1min bouts
    tl_4min_bouts=round(tl_4min_bouts/60,prec_dig); % time spent bouts less than 1min
    
    [th_5min_bouts,b5min_freq_H,tl_5min_bouts,b5min_freq_L]=findBouts(Akt,300,boutBreak,boutThresh); % find 5min bouts. Bout breaks is fixed at 60s
    th_5min_bouts=round(th_5min_bouts/60,prec_dig); % time spent in 1min bouts
    tl_5min_bouts=round(tl_5min_bouts/60,prec_dig); % time spent bouts less than 1min
    
    [th_10min_bouts,b10min_freq_H,tl_10min_bouts,b10min_freq_L]=findBouts(Akt,600,boutBreak,boutThresh); % find 10min bouts. Bout breaks is fixed at 60s
    th_10min_bouts=round(th_10min_bouts/60,prec_dig); % time spent in 1min bouts
    tl_10min_bouts=round(tl_10min_bouts/60,prec_dig); % time spent bouts less than 1min
    
    [th_30min_bouts,b30min_freq_H,tl_30min_bouts,b30min_freq_L]=findBouts(Akt,1800,boutBreak,boutThresh); % find 10min bouts. Bout breaks is fixed at 60s
    th_30min_bouts=round(th_30min_bouts/60,prec_dig); % time spent in 1min bouts
    tl_30min_bouts=round(tl_30min_bouts/60,prec_dig); % time spent bouts less than 1min
    
    [th_60min_bouts,b60min_freq_H,tl_60min_bouts,b60min_freq_L]=findBouts(Akt,3600,boutBreak,boutThresh); % find 10min bouts. Bout breaks is fixed at 60s
    th_60min_bouts=round(th_60min_bouts/60,prec_dig); % time spent in 1min bouts
    tl_60min_bouts=round(tl_60min_bouts/60,prec_dig); % time spent bouts less than 1min
else
    
    [ th_1min_bouts,th_2min_bouts,th_3min_bouts,th_4min_bouts,th_5min_bouts,...
        th_10min_bouts,th_30min_bouts,th_60min_bouts,tl_1min_bouts,tl_2min_bouts,...
        tl_3min_bouts,tl_4min_bouts,tl_5min_bouts,tl_10min_bouts,tl_30min_bouts,...
        tl_60min_bouts,b1min_freq_H,b2min_freq_H,b3min_freq_H,b4min_freq_H,b5min_freq_H,...
        b10min_freq_H, b30min_freq_H,b60min_freq_H,b1min_freq_L,b2min_freq_L,b3min_freq_L,...
        b4min_freq_L,b5min_freq_L,b10min_freq_L,b30min_freq_L,b60min_freq_L] = deal(NaN);
end

akt_NBrk = length(find(diff(Akt)==-1)); %for akt: number of breaks in given activity
%length(Off) is not used, this would give one extra rise if interval is finished at the activity/behaviour concern
end
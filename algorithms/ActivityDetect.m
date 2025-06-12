function [Comb,Time,FB,Std] = ActivityDetect(Acc,SF,T,VrefThigh,ParamsAP)

% ActivityDetect Calculates activities (Sit,Stand,Move,Walk,Run,Stair,Cycle,Row) by acceleration data at the thigh.
%
% Input:
%   Acc [N,3]: Acceleration
%   SF: Sample frequency (N=SF*n)
%   T [N]: Time scale (datenum values)
%   VrefThigh [3]: Reference angle for AG thigh (unit: radians)
%   ParamsAP: The parameters structure (passed from main batch process)
%
% Output:
%   Comb [n]: Combined activity by a 1 sec. time scale (Time), values are
%           Sit-2, Stand-3, Move-4, Walk-5, Run-6,Stair-7, Cycle-8 and Row-9.
%   Time [n]: One sec. time scale (datenum values)
%   FB [n]: Forward/backward angle (degrees)
%   STD [n]: Max Standard deviation of acceleration in each second
%
% Note: 
%   Outside this function: walking with step frequency > 2.5 steps/s is reclassified as running.
%   Forbedret analyse af cykling/trappegang (7/1-19).
%   Std values are corected for SENS accelerometer (20/4-20)
%   Run criterion corrected, line 80/81 (10/6-20)

% modified ActivityDetect algorithm based on Acti4 version v2007
% See original source at:
% https://github.com/motus-nfa/Acti4/blob/main/Version%20July%202020/ActivityDetect.m

% Copyright (c) 2020, Jørgen Skotte
% Copyright (c) 2021, Pasan Hettiarachchi.

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

Ath = ParamsAP.Threshold_standmove; % acceleration threshold for moving activities (G)
WRth = ParamsAP.Threshold_walkrun; % walk/run acceleration threshold (G)
STth = ParamsAP.Threshold_sitstand; %sit/stand inclination threshold (°)
SCth = ParamsAP.Threshold_staircycle; % stair/cycle forward/backwards threshold (°) (24° used before rotation of AG axis was included)


N = length(Acc);
Time = T(1) + (0:(N-1)/SF)/86400;

%rotation matrix around y-axis (forwar-backward) - pitch
RotFB = [cos(VrefThigh(2)), 0, sin(VrefThigh(2)); 0, 1, 0; -sin(VrefThigh(2)), 0, cos(VrefThigh(2))];
%rotation matrix around z-axis (tilts) - yaw
%RotTilt= [cos(VrefThigh(3)), -sin(VrefThigh(3)), 0; sin(VrefThigh(3)), cos(VrefThigh(3)), 0; 0 0 1]; 

AccRot = Acc*RotFB; %rotation from axis of AG to axis of leg
%AccRot = Acc*RotTilt*RotFB; %rotation from axis of AG to axis of leg
%The above 2 l*ines was added 22/02-2013 to account for individual values of VrefThigh. The mean value of
%the first VrefThigh(2) for all BAua subject is -16°. The inclusion of VrefThigh improved the classification for
%lie, sit, stand, walk, run and walking stairs in Ingunn's data on the standardized setup.

[Bl,Al] = butter(4,5/(SF/2)); %5 Hz low-pass filtering
AccL = filter(Bl,Al,AccRot);
% Acc12 = Acc60(AccL,SF); %3-dim array with 2 sec. of data in each column
% Std = squeeze(std(Acc12)); % standard deviation of 2 sec. intervals
% Mean = squeeze(mean(Acc12)); % mean of 2 sec. intervals

%above three lines from original code by Jörgen Skotte is replaced with newer movstd & movmean functions
Std=movstd(AccL,SF*2,0,1);% moving standard deviation of 2s window taken at dim 1 with no-normalization
Std=Std(1:SF:end,:); % standard deviation of 2 sec. intervals given at each second
%Correction for SENS accelerometer, 20/4-20 (acti4), 2024-02-29(ActiPASS)
if ParamsAP.ftype==6 
   Std = 0.18*Std.^2 +1.03*Std;
end
% moving mean of 2s window taken at dim 1
Mean=movmean(AccL,SF*2,1); 
Mean=Mean(1:SF:end,:);% mean of 2 sec. intervals given at each second


Lng = sqrt(Mean(:,1).^2 + Mean(:,2).^2 + Mean(:,3).^2); % length of mean acceleration vectors

Inc = (180/pi)*acos(Mean(:,1)./Lng); %Inclination of leg (0-180°)
FB = -(180/pi)*asin(Mean(:,3)./Lng); %Forward/backward angle of leg (±90°), (forward angle ~ upwards tilt of Z-axis)
STD = max(Std,[],2);

Th = 4; %ændret fra 5 til 4 (8/1-19)
Vstair = Th+median(FB(.25<Std(:,1) & Std(:,1)<WRth & FB<25)); % walk/stair threshold (degrees) (FB<10 used before rotation was included)
[Row,Cycle,Stair,Run,Walk,Sit,Stand] = deal(zeros(size(Inc)));

Row(90<Inc & Ath<Std(:,1)) = 1;
Row = medfilt1(Row,2*ParamsAP.Bout_row-1);
Row = medfilt1(Row,2*ParamsAP.Bout_row-1);
Etter = Row; % in every step 'Etter' is 1 if the activity is already detected in one of the preceedings steps

%Cycle(SCth<FB & Inc<90 & Ath<Std(:,1)) = 1;
MaybeCycle = zeros(size(Cycle));
MaybeCycle(SCth-15<FB & Inc<90 & Ath<Std(:,1)) = 1; %der undersøges for cykling for FB værdier ned til 30 lavere værdier end førhen,
Cycle = CalcCycle(MaybeCycle,SCth,FB,Acc,SF);       %dvs for en mere "lodret" benvinkel (jan19)
Cycle = medfilt1(Cycle,2*ParamsAP.Bout_cycle-1);
Cycle = medfilt1(Cycle,2*ParamsAP.Bout_cycle-1);
Cycle = Cycle .* ~Etter;
Etter = Cycle + Etter;

Stair(Vstair<FB & FB<SCth & Ath<Std(:,1) & Std(:,1)<WRth & Inc<STth) = 1;  %Inc<STth added 6/1-14
Stair = medfilt1(Stair,2*ParamsAP.Bout_stair-1);
Stair = medfilt1(Stair,2*ParamsAP.Bout_stair-1);
Stair = Stair .* ~Etter;
Etter = Stair + Etter;

%Run(Std(:,1)>WRth & FB<Vstair & Inc<STth) = 1; %Inc<STth added 6/1-14
Run(Std(:,1)>WRth & Inc<STth) = 1; %changed on 2020-06-30 fix for underestimation of 'Run'
Run = medfilt1(Run,2*ParamsAP.Bout_run-1);
Run = medfilt1(Run,2*ParamsAP.Bout_run-1);
Run = Run .* ~Etter;
Etter = Run + Etter;
% very slow/quiet running could sometimes be misclassified as walk;
% a correction is included outside this function using step frequency so walk with step frequency >2.5 per sec.
% is allways classified as running

Walk(Ath<Std(:,1) & Std(:,1)<WRth & FB<Vstair & Inc<STth) = 1; %Inc<STth added 6/1-14
% In Stair, run and walk 'Inc<STth' was added because spurious movement when lying at the side (FB small) could be classified as ex. walk,
% this was first recognized when Nmedfilt was decreased from 9 to 3.
Walk = medfilt1(Walk,2*ParamsAP.Bout_walk-1);
Walk = medfilt1(Walk,2*ParamsAP.Bout_walk-1);
Walk = Walk .* ~Etter;
Etter = Walk + Etter;

Stand(Inc<STth & STD<Ath) = 1; %stand still
Stand = medfilt1(Stand,2*ParamsAP.Bout_stand-1);
Stand = medfilt1(Stand,2*ParamsAP.Bout_stand-1);
Stand = Stand .* ~Etter;
Etter = Stand + Etter;

Sit(Inc>STth) = 1; %no movement critera included, 6/1-14, version 14xx
Sit = medfilt1(Sit,2*ParamsAP.Bout_sit-1);
Sit = medfilt1(Sit,2*ParamsAP.Bout_sit-1);
Sit = Sit .* ~Etter;
Etter = Sit + Etter;

Move = ~Etter;
Comb = (2*Sit+3*Stand+4*Move+5*Walk+6*Run+7*Stair+8*Cycle+9*Row)';

%To completely remove short bouts, especially 'move' has not been filtered above
Comb = AktFilt(Comb,'row',ParamsAP);
Comb = AktFilt(Comb,'cycle',ParamsAP);
Comb = AktFilt(Comb,'stair',ParamsAP);
Comb = AktFilt(Comb,'run',ParamsAP);
Comb = AktFilt(Comb,'walk',ParamsAP);
Comb = AktFilt(Comb,'move',ParamsAP);
Comb = AktFilt(Comb,'stand',ParamsAP);
Comb = AktFilt(Comb,'sit',ParamsAP);

function Cycle = CalcCycle(MaybeCycle,SCth,FB,Acc,SF)
%Improved distinction between cycling and stair climbing (7/1-19):
%A low-pass (<1Hz) and a high-pass filtered (>1Hz) version of the lateral acceleration is calculated and
%the ratio between average (abs) high-pass and low-pass filtered value is determined.
%For cycling intervals the ratio is <0.5, for stair climbing >0.5.
%Data from DKjem_setup_Validation_B3B4samlet.xls used for 'calibration'.
[Bh,Ah] = butter(3,1/(SF/2),'high');
AccH = filtfilt(Bh,Ah,double(Acc(:,3))); %
[Bl,Al] = butter(3,1/(SF/2));
AccL = filtfilt(Bl,Al,double(Acc(:,3)));
N = length(Acc);
Cycle = zeros(size(MaybeCycle));
MaybeCycle = medfilt1(MaybeCycle,9);

for i=1:length(MaybeCycle) %one calculation every 1 sec.
    if MaybeCycle(i)
        ii =  max(1,i*SF-63):min(i*SF+64,N); %128 samples, ca. 4 sek
        HLratio = mean(abs(AccH(ii)))/mean(abs(AccL(ii)));
        if HLratio <.5 || SCth<FB(i) %always cycle if SCth exceeded
            Cycle(i) = 1;
        end
        
        %         x = detrend(Acc(ii,3));
        %         figure
        %         subplot(2,1,1)
        %         t = (0:length(x)-1)/SF;
        %         plot(t,x)
        %         xlabel('sek.')
        %         subplot(2,1,2)
        %         f = SF/2*linspace(0,1,256); %frequency scale
        %         Y = fft(hamming(length(x)).*x,512);
        %         A = 2*abs(Y(1:256));
        %         plot(f(f<=5),A(f<=5))
        %         xlabel('Hz')
        
    end
end



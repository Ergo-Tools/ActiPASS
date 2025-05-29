function [Akt,VcalfDeg,OffCalf,AngCalfWalk,warnings,status] = detectKneeling(AccCalf,AccCalfFilt,Vcalf,Lcalf,VrefCalf,Vthigh,Lthigh,AccThigFilt,VrefThigh,Akt,Settings,ParamsAP)
% detectKneeling detect kneeling/squating using the calf and thigh accelerometer data
%
% INPUTS
%
% OUTPUTS:
%

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

% kneeling and squating threshold for calf-accelerometer
Th=ParamsAP.Threshold_kneel; % kneeling threshold
% The resample frequency for raw accelerometer data
Fs=ParamsAP.Fs;
% default calf ref position
VrefCalfDef = (pi/180)*ParamsAP.VrefCalfDef;
warnings=strings(0,1);
AngCalfWalk=[];
AktIN=Akt; % copy of activity vector
OffCalf=[];


try
    if ~isequal(VrefCalf,VrefCalfDef)
        % rotate (transform) trunk acc data based on the ref. position
        Rot1 = [cos(VrefCalf(2)) 0 sin(VrefCalf(2)); 0 1 0; -sin(VrefCalf(2)) 0 cos(VrefCalf(2))]; %ant/pos rotation matrix
        AccCalfRot = AccCalfFilt*Rot1;

        % recalculate calf ant-post angles using the transformed data
        Vcalfrot = real([acos(AccCalfRot(:,1)./Lcalf),-asin(AccCalfRot(:,3)./Lcalf),-asin(AccCalfRot(:,2)./Lcalf)]);
        Vcalf=Vcalfrot;

        % rotate (transform) thigh acc data based on the ref. position
        Rot2 = [cos(VrefThigh(2)) 0 sin(VrefThigh(2)); 0 1 0; -sin(VrefThigh(2)) 0 cos(VrefThigh(2))]; %ant/pos rotation matrix
        AccThighRot = AccThigFilt*Rot2; %rotation from axis of AG to axis of leg

        % recalculate thigh ant-post angles using the transformed data
        Vthighrot = real([acos(AccThighRot(:,1)./Lthigh),-asin(AccThighRot(:,3)./Lthigh),-asin(AccThighRot(:,2)./Lthigh)]);
        Vthigh=Vthighrot;
    end

    % call general NotWorn function with calf acc data
    OffCalf = NotWorn(Vcalf,AccCalf,Fs);

    %convert radians to degrees
    VcalfDeg = 180*Vcalf/pi;
    VcalfDeg(:,2) = -VcalfDeg(:,2); %maybe more logical when looking at the plot

    % moving mean of 2s window taken at dim 1
    VcalfDeg = movmean(VcalfDeg,Fs*2);
    VcalfDeg=VcalfDeg(1:Fs:end,:);% mean of 2 sec. intervals given at each second

    % moving mean of thigh angles in degrees
    Vthigh = movmean(Vthigh,Fs*2);
    Vthigh=180*Vthigh(1:Fs:end,:)/pi; % mean of 2 sec. intervals given at each second

    %extra search for calf non-wear
    OffCalf = OffCalf | NotWornCalf(AktIN,Vthigh,AccCalf,Fs,VcalfDeg,Th);

    %flag calf NW as NW in daily Akt output if necessary
    if Settings.KEEPCALFNW
        AktIN(OffCalf)=0;
    end

    %intialize variable for Kneel detection
    Kneel = zeros(size(AktIN));
    Kneel(VcalfDeg(:,1)>Th & VcalfDeg(:,2)<-45 & Vthigh(:,2)>-20 & abs(Vthigh(:,3))<30 ...
        & OffCalf==0 & AktIN'~=1 & AktIN'~=0) = 1;

    [AngCalfWalk,warnings] = CheckCalfOrientation(warnings,AktIN,Vthigh,VcalfDeg,OffCalf);

    Kneel = logical(medfilt1(Kneel,5));

    % Make room for kneel in Akt:
    % Akt(Akt>=2) = Akt(Akt>=2)+1;

    % new activity number for kneeling
    AktIN(Kneel) = 12;

    %Find and cancel false 'kneel' embedded in sitting intervals (sitting with calf underneath):
    SitKneel = zeros(size(AktIN));
    SitKneel(AktIN==2) = 1;
    SitKneel(AktIN==12) = -1;
    SitKneel = [0,SitKneel];
    kneel2sit = find(diff(SitKneel)==2); %kneel til sit overgange
    sit2kneel = find(diff(SitKneel)==-2); %sit til kneel overgange
    for iss=1:length(sit2kneel)
        if range(Vthigh(max(sit2kneel(iss)-3,1):min(sit2kneel(iss)+2,length(AktIN)),1)) <30 %benvinkelrange i +/- 3sek ved overgang fra sit til kneel <30
            NextKneel2sit =kneel2sit(find(kneel2sit > sit2kneel(iss),1,'first')); %førstfølgende sit til kneel
            if ~isempty(NextKneel2sit) && all(AktIN(sit2kneel(iss):NextKneel2sit-1)==12) ... %hvis det ét sammenhængende kneel interval
                    && range(Vthigh(max(NextKneel2sit-3,1):min(NextKneel2sit+2,length(AktIN)),1)) <30 %og benvinkelrange <30 ved overgang til sit (som før)
                AktIN(sit2kneel(iss):NextKneel2sit-1) = 2; %så er det sit
            end
        end
    end

    Akt=AktIN; % update the Akt vector and return it
    status="OK";

catch ME
    status="Error detecting kneeling. "+ ME.message;
end

function [AngCalfWalk,warnings] = CheckCalfOrientation(warnings,Akt,Vthigh,VcalfDeg,OffCalf)
%Check orientation of calf accelerometer;
%If lying ("flat", more than 1 minute) is present, forward/backward orientation can be checked,
%if walk is present, up/down is checked

ii = Akt'==1 & (abs(Vthigh(:,2)>60 & abs(VcalfDeg(:,2))>60)) ...
    & OffCalf==0 & (abs(Vthigh(:,3))<30 & abs(VcalfDeg(:,3))<30); %Lying at the back or belly (at least 1 min.):
if sum(Vthigh(ii,2).*VcalfDeg(ii,2) >0)/sum(ii)<.5  && sum(ii)>60 %signs of forward/backward angle should be equal
    warnings=[warnings;"Probably wrong IN/OUT calf (or thigh) accelerometer"];
end
AngCalfWalk = mean(VcalfDeg(Akt'==5 & OffCalf==0,:));
if AngCalfWalk(1) > 45
    warnings=[warnings;"Probably wrong UP/DOWN orientation by calf accelerometer for interval"];
end


function Af = NotWornCalf(Akt,Vthigh,AccCalf,Fs,VcalfDeg,Th)
% Extra search for off periods for calf accelerometer
% Calf accelerometer is off if there is no movement for at least 10 minute where thigh moves.

% StdMeanCalf  = mean(squeeze(std(Acc60(AccCalf,Fs))),2); %1 second time scale

StdMeanCalf = movstd(AccCalf,Fs*2);
StdMeanCalf=mean(StdMeanCalf(1:Fs:end,:),2); % mean across axes of standard deviation of 2s window
% For not-worn periods the AG normally enters standby state (Std=0 in all axis) or
% in some cases yield low level noise of ±2-3 LSB:
OffOn = diff([false,StdMeanCalf(1:end-1)'<.01,false]);
Off = find(OffOn==1);
On = find(OffOn==-1);
OffPerioder = On - Off;
StartOff = Off(OffPerioder>180); % 3 minutes
SlutOff = On(OffPerioder>180);

%Short periods (<1 minut) of activity between not-worn are removed
KortOn = (StartOff(2:end) - SlutOff(1:end-1)) < 60;
if ~isempty(KortOn)
    SlutOff = SlutOff([~KortOn,true]);
    StartOff = StartOff([true,~KortOn]);
end

Af = zeros(size(StdMeanCalf));
for i=1:length(StartOff)
    if  SlutOff(i)-StartOff(i)>600 ... %for more than 10 minuttes
            && max(range(Vthigh(StartOff(i):SlutOff(i),:))) > 10  %if thigh moves more than 10 degrees
        Af(StartOff(i):SlutOff(i)) = 1;
    end
    Vmean = mean(VcalfDeg(StartOff(i):SlutOff(i),:));
    if  SlutOff(i)-StartOff(i)>300 ... % 5 minuttes
            && (all(abs(Vmean - [90,90,0]) < 3)... % Only not-worn if orientation differs less than 3°
            || all(abs(Vmean - [90,-90,0]) < 3))   % from "flat" lying orientation (up or down)
        Af(StartOff(i):SlutOff(i)) = 1;
    end
end
Af(VcalfDeg(:,1)<Th | VcalfDeg(:,2)>-45 | Vthigh(:,2)<-20 | abs(Vthigh(:,3))>30) = 0;
Af(Akt==1) = 0; %no off detection for lying perids




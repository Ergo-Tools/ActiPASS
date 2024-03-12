function Sleep = SkottesSlp(Akt,opMode,Acc,SF,Position)

% Estimation of sleep during lying or given times-of-bed.
% Sleep is estimated in each second for lying periods longer than 15 minutes from thigh,
% arm (preferable) or trunk accelerometer. 
%
% Input:
% Akt: Activity vector (1 sec time scale)
% Acc [N,3]: Acceleration matrix
% SF: Sample frequency (30 Hz)
% Position (string): Thigh, Arm or Trunk
%
% Output:
% Sleep: Vector (size as Akt), 1 for wake, 0 for sleep

% This function is a slightly modified version of Acti4 sleep algorithm. 
% % Copyright (c) 2020, Jørgen Skotte
% https://github.com/motus-nfa/Acti4/blob/main/Version%20July%202020/SleepFun.m


% Copyright (c) 2021, Pasan Hettiarachchi .
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


Sleep = ones(size(Akt)); %all awake
if length(Akt)>floor(size(Acc,1)/SF)
    Akt=Akt(1:floor(size(Acc,1)/SF)); %in case if there's not enough Acc data trim Akt vector
end
%depending on opMode both sitting/lying or only lying is considered for sleep detection
if opMode==1
    DiffLie = diff([0;Akt'==1;0]);
elseif opMode==2
    DiffLie = diff([0;(Akt'==1 | Akt'==2);0]);
end
LieInt = [find(DiffLie==1),find(DiffLie==-1)-1];
Int15 = LieInt(LieInt(:,2)-LieInt(:,1)>60*15,:);
if isempty(Int15) %return if no lying periods longer than 15 minutes are found (all awake)
    return
end

[Bbp,Abp] = butter(6,[.5 10]/(SF/2)); %båndpasfilter 0.5-10 Hz
Acc = filter(Bbp,Abp,Acc);

A = mean(reshape(sqrt(sum(Acc.^2,2)),SF,[]));
A(A<.02) = 0; %remove background noise

% Algorithm constants for the different acceleromters:
K = [exp(-1/(60*18.5)), .19; ...  %Thigh (time constant 18.5 min, gain .19)
    exp(-1/(60*20)), .15;...    %Arm (time constant 20 min, gain .15)
    exp(-1/(60*21)), .24];     %Trunk (time constant 21 min, gain .24)

k = K(strcmp(Position,{'Thigh','Arm','Trunk'}),:); %select the constants

for i=1:size(Int15,1)
    sleep = Calc(A(Int15(i,1):Int15(i,2)),k);
    Sleep(Int15(i,1):Int15(i,2)) = sleep;
end
Sleep = medfilt1(Sleep,19);
Sleep(isnan(A)) = NaN;
end

function sleep = Calc(A,k)
I = zeros(size(A));
I0 = exp(1);
Iprev = I0; %fully awake
for i = 1:length(A)
    I(i) = k(1)*Iprev + k(2)*A(i);
    Iprev = min(I0,I(i));
end
sleep = I>1;
wt = find(diff(sleep)==1); %wake up time is considered to be 2 minutes ahead:
for j=1:length(wt)
    sleep(max(1,wt(j)-120):wt(j)-1) = 1;
end
end


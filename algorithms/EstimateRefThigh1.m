 function VrefThigh = EstimateRefThigh1(Acc,Vthigh,VrefThighOld,VrefThighDef,SF,SettingsAkt) 
% VrefThigh Estimation of reference angle for leg accelerometer.

% Input:
% 
% Output:

% Notes:
%   Leg reference angle is estimeated for each interval in the setup file. The calculation is based on 
%   an investigation of 50 measurements from the BAuA project, in which is was found that 
%   average FBthigh angle was 11 (+/-3.0) degrees during walking (14/1-19)

% modified based on function EstimateRefThigh Acti4 version v2007
% See original source at:
% https://github.com/motus-nfa/Acti4/blob/main/Version%20July%202020/EstimateRefThigh.m

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
 
% In ActiPASS old and default reference-position handling is taken over by the main workflow. 
% Therefore following functionality is no longer needed here
%  persistent oldRef
%  if firstDay  %first interval for ID: provisionel reference for calculation of Akt
%     oldRef =  VrefThighDef; % the default reference positions
%  end

 Akt = ActivityDetect(Acc(:,2:4),SF,Acc(:,1),VrefThighOld,SettingsAkt);
 korr = pi*11/180; %average Forward/Backward angle during walk (BAuA)
 VthighAccAP = mean(reshape(Vthigh(:,2),SF,length(Akt))); %ant/pos accelerometer angle
 VthighAccLat = mean(reshape(Vthigh(:,3),SF,length(Akt))); %lat accelerometer angle
 v2 = median(VthighAccAP(Akt==5)) - korr;
 v3 = median(VthighAccLat(Akt==5));
 VrefThigh = [acos(cos(v2)*cos(v3)),v2,v3]; %sfærisk triangle
 if isnan(v2) || sum(Akt==5)<30 %less than ½ minute is not accepted
    VrefThigh = VrefThighDef;
% following functionality is no longer needed here
%  else
%     oldRef = VrefThigh; %for calculation of Akt for the next interval for ID 
 end
 
 function VrefThigh = EstimateRefThigh2(WlkLgc,Vthigh,VrefThighDef,SF) 
 % EstimateRefThigh2 Estimation of reference angle for thigh accelerometer using DFT of VM.
 
 % Inputs:
 %   WlkLgc - a logical vector representing walking times
 %   Vthigh - output from angle-detection function
 %   VrefThighDef - default reference positions for thigh
 %   SF sampling frequncy
 
 % Output
 %   VrefThigh - thigh reference-position as a three angle vector [roll, anterior-posterior, tilt]
 
 % Notes:
 %   another way to find reference-positions automaticlly. This methos relies on seperate walking-detection
 %   by frequency analysis of vector magnitude (done in QCFlipRotation module). This method should be used as an
 %   alternative to the first method if the first method produces results which seems to be wrong
 %   Pasan Hettiarachchi 2020-Oct
 
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


% Comments by Joergen Skotte (from first method of reference-position finding)
% Estimation of reference angle for leg accelerometer.
% Leg reference angle is estimeated for each interval in the setup file. The calculation is based on 
% an investigation of 50 measurements from the BAuA project, in which is was found that 
% average FBthigh angle was 11 (+/-3.0) degrees during walking (14/1-19)
 
% In ActiPASS old and default reference-position handling is taken over by the main workflow. 
% Therefore following functionality is no longer needed here
%  persistent oldRef
%  if firstDay  %first interval for ID: provisionel reference for calculation of Akt
%     oldRef =  VrefThighDef; % the default reference positions
%  end

 korr = pi*11/180; %average Forward/Backward angle during walk (BAuA)
 VthighAccAP = mean(reshape(Vthigh(:,2),SF,length(WlkLgc))); %ant/pos accelerometer angle
 VthighAccLat = mean(reshape(Vthigh(:,3),SF,length(WlkLgc))); %lat accelerometer angle
 v2 = median(VthighAccAP(WlkLgc)) - korr;
 v3 = median(VthighAccLat(WlkLgc));
 VrefThigh = [acos(cos(v2)*cos(v3)),v2,v3]; %sfærisk triangle
 if isnan(v2) || sum(WlkLgc)<30 %less than ½ minute is not accepted
    VrefThigh = VrefThighDef;
% following functionality is no longer needed here
%  else
%     oldRef = VrefThigh; %for calculation of Akt for the next interval for ID 
 end
 
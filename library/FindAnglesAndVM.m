function  [V,AccFilt,SVM,normAcc] = FindAnglesAndVM(Acc,SF,Fc)
% FindAnglesAndVM calculation of angles (6Hz low-pass filtered), vector magnitude and normalized acceleration.

% Input:
%   Acc: Acceleration [N,3]
%   SF: sample rate.
%   Fc: low-pass filter citoff

% Output:
%   V [N,3]: Inclination, forward/backward angle, sideways angle (rad).
%   AccFilt [N,3]: 2 Hz low-pass filtered acceleration.
%   SVM [N]: vector magnitude of acceleration vector (filtered).
%   normAcc [N,3]: Normalized M

% Notes:
%   Acceleration values are assumed to be caused by gravitation (quasi-stationarity).  
%   rev. 2/5-19: to handle acceleration breaks in firstbeat 'front' data 

% modified based on function Vinkler Acti4 version v2007
% See original source at:
% https://github.com/motus-nfa/Acti4/blob/main/Version%20July%202020/Vinkler.m

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
    
     
   [Blp,Alp] = butter(6,Fc/(SF/2)); % 6th order buttorworth filter at Fc
   AccFilt = filter(Blp,Alp,Acc);
   SVM = sqrt(sum(AccFilt .^ 2, 2));
   normAcc = AccFilt./repmat(SVM,1,3);
   Inc = acos(normAcc(:,1));
   U = -asin(normAcc(:,3));
   V = [Inc,U,-asin(normAcc(:,2))];
   
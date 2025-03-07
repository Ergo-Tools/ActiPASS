function [Acc,trnkOrient] = TrunkFlipRot(Acc,Fs,wlklgc,trunkrot,trunkflip)
%TRUNKFLIPROT try to automatically fix trunk orientations (also considers given orientations when in doubt)

% Inputs:
%   Acc [N,4] Evenly sampled Acc data
%   Fs: sample frequency

%   wlklgc:  walking_yes/no logical vector at 1s epoch (derived from thigh QCFlipRotation module)
%   trunkrot: logical whether trunk Acc. is rotated (upside down) according to defaults
%   trunkflip: logical whether trunk Acc. is flipped according to defaults
%
% Outputs:
%
%   Acc: [N,4] Evenly sampled Acc data adjusted for flips/rotations
%   trnkOrient: The orientation detected

% Copyright (c) 2022, Pasan Hettiarachchi .
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


% expand wlklgc vector to the same size as Acc vector
wlklgc=repelem(wlklgc,Fs);

% check the mean value of x-axis during walking and fix rotation
if mean(Acc(wlklgc,1))>0.7
    trunkrot=1;
elseif mean(Acc(wlklgc,1))< -0.7
    trunkrot=0;
end

% set the orientation value (0,1,2,3)
trnkOrient=2*trunkrot+trunkflip+1;
% do the actual changes to Acc data based on orientations found
Acc = ChangeAxes(Acc,'Axivity',trnkOrient);
end


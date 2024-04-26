
function empT=genEmptyTrunkT(height)
% genEmptyTrunkT generate an empty tableof given height with trank-variables
%
% INPUTS:
% height: the height of the empty table 

% OUTPUTS:
% empT - "an empty table with given height with trunk related variables

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

baseVars=["StartT","EndT","Interval","RefPosStr","NW_Trnk","Valid_Trnk","VrefTrunkAP","VrefTrunkLat"]; % basic information
angTres=["20","30","60","90"]; % thresholds for the variables below
% inclination variables while different activities given at different angle thresholds
incVars=["IncTrunk","PctTrunk","ForwardIncTrunk","ForwardIncTrunkSit","ForwardIncTrunkStandMove","ForwardIncTrunkUpright"];
% maximum of above variables at 60-degree threshold
maxVars=["IncTrunkMax60","IncTrunkSitMax60","IncTrunkStandMoveMax60","IncTrunkUprightMax60"];
otherVars="IncTrunkWalk"; % only one variable so far

% combine all variables in to one vector
trnkVarNs=[baseVars,reshape(append(incVars',angTres).',1,[]),maxVars,otherVars];
% variable types for all variables
trnkVarTs=repmat("string",1,length(trnkVarNs));

% create empty tables for daily and interval based trunk data
empT=table('Size',[height,length(trnkVarNs)],'VariableTypes',trnkVarTs,'VariableNames',trnkVarNs);


end


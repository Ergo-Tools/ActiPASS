function CombNew = AktFilt(Comb,ActType,SETTINGS)
% AktFilt Additional filtering of activities.

% Input:
%   Comb [n]: Combined activity by a 1 sec. time scale
%   ActType: 'lie', 'sit'....
%
% Output:
%   CombNew [n]: Filtered activity
% Notes:
%   Bouts less than the minimum value stored in SETTINGS are removed and replaced with neighbouring values.
%   4/4-16: error correction
%   26/5-16: 4/4-16 correction removed 

% modified AktFilt algorithm based on Acti4 version v2007
% See original source at:
% https://github.com/motus-nfa/Acti4/blob/main/Version%20July%202020/AktFilt.m

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

if strcmp('lie',ActType), bout = SETTINGS.Bout_lie; No=1; end
if strcmp('sit',ActType), bout = SETTINGS.Bout_sit; No=2; end
if strcmp('stand',ActType), bout = SETTINGS.Bout_stand; No=3; end
if strcmp('move',ActType), bout = SETTINGS.Bout_move; No=4; end
if strcmp('walk',ActType), bout = SETTINGS.Bout_walk; No=5; end
if strcmp('walkslow',ActType), bout = SETTINGS.Bout_walk; No=5.1; end %4/4-16
if strcmp('walkfast',ActType), bout = SETTINGS.Bout_walk; No=5.2; end %4/4-16
if strcmp('run',ActType), bout = SETTINGS.Bout_run; No=6; end
if strcmp('stair',ActType), bout = SETTINGS.Bout_stair; No=7; end
if strcmp('cycle',ActType), bout = SETTINGS.Bout_cycle; No=8; end
if strcmp('row',ActType), bout = SETTINGS.Bout_row; No=9; end

CombNew = Comb;

Akt = zeros(size(Comb))';
Akt(Comb==No) = 1;
DiffAkt = diff([0;Akt;0]);
Start = find(DiffAkt==1);
Slut = find(DiffAkt==-1)-1;
Korte = find(Slut-Start<bout); %fejl
%Korte = find(Slut-Start<bout-1); %rigtig
SS = [Start(Korte),Slut(Korte)];
%4/4-16: opdager en +/-1 fejl her; ovenstående resulterer i at minimum bout faktisk er 'bout+1' sek. Hvis bout=2,
%fjernes aktivittesintervaller med 2 elementer. 
%26/5-16: Ændret igen til gamle beregning, 'bout+1'

for i=1:size(SS,1)
  if i==1 && SS(i,1)==1 %special case for start of interval
     CombNew(SS(i,1):SS(i,2)) = Comb(SS(i,2)+1); 
  elseif i==size(SS,1) && SS(i,2)==length(Akt) %special case for end of enterval
     CombNew(SS(i,1):SS(i,2)) = Comb(SS(i,1)-1);
  else %general case
     Midt = fix(mean(SS(i,:))); 
     CombNew(SS(i,1):Midt) = Comb(SS(i,1)-1); %left values replacement
     CombNew(Midt+1:SS(i,2)) = Comb(SS(i,2)+1); %right values replacement
  end
end

%Nbout = sum(Slut-Start==bout);

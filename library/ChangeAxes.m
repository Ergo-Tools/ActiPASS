function  Acc = ChangeAxes(Acc,Type,Orientation)

% ChangeAxes Change the raw Acc data based on orientation and device type. 
%
% Type (text): ActiGraph, Axivity or ActivPAL
% Orientation: 1, 2, 3, 4 
% Acc: [n,3]: Triaxial accelerometer data
%
% Standard ActiPASS orientationn: x downwards, z inward towards body surface
% for more info about ActiPASS default orientations for various brands, see:
% https://github.com/Ergo-Tools/ActiPASS/wiki/ActiPASS-accelerometer-default-orientations

% Note: This function is different from original Acti4 ChangeAxesfunction. Acti4 negate all axes when accelerometer
% data is converted to .acti4 file format. Since ActiPASS does not use intermediate .acti4 file format, we need to do
% the axes negation in this function. This is because Acti4 algorithms expects positive values towards gravity

% **********************************************************************************
% % Copyright (c) 2022, Pasan Hettiarachchi .
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

if  strcmp(Type,'ActiGraph') || strcmp(Type,'Axivity') || strcmp(Type,'ActivPAL') ||...
        strcmp(Type,'SENS') || strcmp(Type,'Generic') || strcmp(Type,'Movisens')
   if Orientation == 1 %no shift
      Acc = -Acc; 
   end
   if Orientation == 2 %in/out shift
      Acc = Acc.*[-1,1,1]; 
   end
   if Orientation == 3 %up/down shift
      Acc = Acc.*[1,1,-1]; 
   end
   if Orientation == 4 %both up/down and in/out shift
      Acc = Acc.*[1,-1,1];  
   end
end





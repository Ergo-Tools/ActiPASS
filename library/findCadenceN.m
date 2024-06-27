function Fstep = findCadenceN(Acc,Akt,SF)
% findCadenceN Calculates instantaneous step frequency from the vertical acceleration of thigh.
% modified ActivityDetect algorithm based on Acti4 version v2007
% See original source at:
% https://github.com/motus-nfa/Acti4/blob/main/Version%20July%202020/TrinAnalyse.m
%
% Input:
% Acc [N]: acceleration of thigh, only x-axis is considered for steps/cadence detection
% Akt [n]: activity calculated by 'ActivityDetect' (1 sec time scale)
% SF: sample frequency (N=n*SF)
%
% Output:
% Fstep [n]: Step frequency (steps/sec) in a 1 sec time scale.
% If the epochs of activity "Other" is determined to be periodic, cadence is calculated for those epochs, otherwise
% cadence is only calculated for "Walk", "Run" and "Stairs"

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

% The following description comes from the original version by Jørgen Skotte
%
% Step frequency is calculated by FFT analysis of a 4 sec. (128 samples) running window with 1 sec. overlap.
% Generally the spectrum of the vertical thigh acceleration contains peaks for the step frequency, half the step frequency
% and double the step frequency and any of these could have the highest peak. For walking the acceleration is 1.5-2.5Hz
% band-pass filtered; for running an additional 3Hz high-pass filter is included. The step frequency is found as the
% frequency of highest peak in the filtered signals.

SP_other=0.1; % power threshold of normalized frequency spectrum for periodicity of "Other"

[Bc,Ac] = butter(6,2.5/(SF/2));
Xc = filter(Bc,Ac,Acc(:,1)); %2.5Hz low-pass frequency filtering, consider only x-axis (should we consider all axes instead?)
[Bw,Aw] = butter(6,1.5/(SF/2),'high');
Xw = filter(Bw,Aw,Xc); %1.5-2.5Hz band-pass filtering for walking
[Br,Ar] = butter(6,3/(SF/2),'high');
Xr = filter(Br,Ar,Xw); %extra 3Hz high-pass filter for running

% comments by Pasan:
% one might wonder what's going on above: if the passband is 1.5-2.5, why filter again with 3Hz highpass? but it works because during running Acc is high and the q-factors of filters are fairly wide I think
% however when some walks very slow the acceleration magnitude is also low, perhaps then this algorithm is not very good at detecting lower cadence (say below 80/min or 1.33 Hz)
% anyway validations done shows that the method works fairly well
% Validation: https://doi.org/10.4172/2165-7556.1000119


%intialize variables with zeros; modification by Pasan 2021-May: to also consider activity 'other' for cadence finding
[Fstep,Walk,Run,Stairs,Other] = deal(zeros(size(Akt)));
Walk(Akt==5) = 1;
Run(Akt==6) = 1;
Stairs(Akt==7) = 1;
Other(Akt==9)=1;
Alle = Walk+Run+Stairs+Other;
N = length(Acc(:,1));
fftWin=128; % fft spectrum is taken at 128 sample points
f_scale = SF/2*linspace(0,1,fftWin/2); %frequency scale; this gives a frequency scale of 0-12.5Hz for a sample frequency of 25Hz

for i=1:length(Akt) %one calculation every 1 sec.
    if Alle(i) == 1
        ii =  max(1,i*SF-(fftWin/2-1)):min(i*SF+fftWin/2,N); %128 samples
        
        if Run(i)==1
            %x = detrend(Xr(ii));
            % to make it faster detrend is replaced with simple DC offset correction
            x= Xr(ii)-mean(Xr(ii));
        else
            %x = detrend(Xw(ii)); %walk is default
            x= Xw(ii)-mean(Xw(ii));
        end
        
        fft_x=fft(x,fftWin);
        P1 = 2*abs(fft_x(1:fftWin/2)/fftWin); %normalise the freq-spectrum;
        
        [P_i,f_i]=max(P1);  % here consider most prominent peak of the freq. spectrum. Can we use findpeaks to detect other frequency peaks?
        if Other(i)~=1 % if activity is not 'other' we just take the frequency value
            Fstep(i) = f_scale(f_i);
        else
            % if activity is 'Other' we find cadence only if spectrum power is above a certain threshold
            % this means, we assume a spectrum with peaks above the thresholds contain a perodic signature
            if P_i>SP_other
                Fstep(i)=f_scale(f_i);
            end
        end
        
        
    end
end
Fstep = medfilt1(Fstep,3); %6/1-14: changed from 9 to 3 (re ActivityDetect)


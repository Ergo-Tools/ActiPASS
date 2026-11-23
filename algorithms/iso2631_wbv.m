function filtered=iso2631_wbv(signal,type,fs)
% iso2631_wbv Calculate frequency weights according to ISO 2631-1 and return the frequency weighted accelerations.
% --------------------------------------------------------------------------
% signal is the acceleration column
% type is the one of the strings 'Wk' , 'Wd' , 'Wf' , 'Wc' , 'We' or 'Wj
% the output 'filtered' is a column vector as the same length as the signal.
% filtering is done in time domain. the function first assigns the polynomial
% coeffecients for numerator and denominator for the band pass and
% weighting transfer functions. The analog s-domain tranfer function is
% then mapped to digital Z-domain transfer function using bilinear function
% and then the signal is passed through the digital filter using matlab 'filter' function.
% the various weighting filter parameters are f_l,f_h,f3,f4,f5,f6 and q4,q5
% and q6 .These are defined in the iso2631 standard.
% --------------------------------------------------------------------------
% modified from function ISO2631.m from https://github.com/janiex/SimulinkMatlab/tree/master/Matlab

%   version 0.01 
%   Pasan Hettiarachchi (c), 2021
%   <pasan.hettiarachchi@medsci.uu.se>

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

%% Initialise parameters for the filter given in variable 'type'
try
    switch lower(type)
        case 'wk' %Wk filter
            f_l=0.4; % the low pass cutoff. common for all filteres
            f_h=100; % the high pass cutoff common for all filters
            f3=12.5;
            f4=12.5;
            q4=0.63;
            f5=2.37;
            q5=0.91;
            f6=3.35;
            q6=0.91;
            w_l=2*pi*f_l; % corresponding angular frequencies
            w_h=2*pi*f_h; % corresponding angular frequencies
            w5=2*pi*f5;
            w6=2*pi*f6;
            w3=2*pi*f3;
            w4=2*pi*f4;
        case 'wd' %Wd filter
            f_l=0.4; % the low pass cutoff. common for all filteres
            f_h=100; % the high pass cutoff common for all filters
            
            f3=2.0;
            f4=2.0;
            q4=0.63;
            w_l=2*pi*f_l; % corresponding angular frequencies
            w_h=2*pi*f_h; % corresponding angular frequencies
            w3=2*pi*f3;
            w4=2*pi*f4;
        case 'wf' %Wf filter
            f_l=0.08;
            f_h=0.63;
            
            f3=inf;
            f4=0.25;
            q4=0.86;
            f5=0.0625;
            q5=0.80;
            f6=0.1;
            q6=0.80;
            w_l=2*pi*f_l; % corresponding angular frequencies
            w_h=2*pi*f_h; % corresponding angular frequencies
            w5=2*pi*f5;
            w6=2*pi*f6;
            w3=2*pi*f3;
            w4=2*pi*f4;
        case 'wc' % Wc filter
            f_l=0.4; % the low pass cutoff. common for all filteres
            f_h=100; % the high pass cutoff common for all filters
            f3=8.0;
            f4=8.0;
            q4=0.63;
            w_l=2*pi*f_l; % corresponding angular frequencies
            w_h=2*pi*f_h; % corresponding angular frequencies
            w3=2*pi*f3;
            w4=2*pi*f4;
        case 'we' %We filter
            f_l=0.4; % the low pass cutoff. common for all filteres
            f_h=100; % the high pass cutoff common for all filters
            f3 = 1.0;
            f4 = 1.0;
            q4 = 0.63;
            w_l=2*pi*f_l; % corresponding angular frequencies
            w_h=2*pi*f_h; % corresponding angular frequencies
            w3=2*pi*f3;
            w4=2*pi*f4;
        case 'wj' %Wj filter
            f_l=0.4; % the low pass cutoff. common for all filteres
            f_h=100; % the high pass cutoff common for all filters
            f5 =3.75;
            q5 =0.91;
            f6= 5.32;
            q6 = 0.91;
            w_l=2*pi*f_l; % corresponding angular frequencies
            w_h=2*pi*f_h; % corresponding angular frequencies
            w5=2*pi*f5;
            w6=2*pi*f6;
        otherwise
            %disp('Type should be Wk , Wd , Wf , Wc , We or Wj ');
            error('Type should be Wk , Wd , Wf , Wc , We or Wj ');
            
    end
    
    
    switch lower(type)
        case {'wk'}
            
            %% Filter is Wk
            
            %----------------------band pass filter----------------------------
            % low pass filter
            numf_l = [1 0 0];
            denf_l = [1 sqrt(2)*w_l w_l^2];
            % high pass filter
            numf_h= [0 0 1];
            denf_h =[1/(w_h^2) sqrt(2)/w_h 1];
            % band pass filter
            
            % It is the product of low and high pass filter transfer functions
            numf = conv(numf_l,numf_h); %build the complete filter by convolution of the both filters
            denf = conv(denf_l,denf_h);
            [numdf, dendf] = bilinear(numf,denf,fs); %convert the s-domain to discrete
            %filter the input vector 'signal' with the with the filter described by
            %numerator coefficient vector numf and denominator coefficient vector dendf.
            filtered = filter(numdf,dendf,signal);
            
            
            %------------------------------------------------------------------
            %------------------Weighting Filters-------------------------------
            % Acceleration-velocity transition
            numav = [1/w3 1];
            denav = [1/(w4^2) 1/(q4*w4) 1];
            %Upward step filter
            numus = [1/(w5^2) 1/(q5*w5) 1]*((w5/w6)^2);
            denus = [ 1/w6^2 1/(q6*w6) 1];
            % Actual weighting transfer function
            numw = conv(numav,numus);
            denw = conv(denav,denus);
            [numdw, dendw] = bilinear(numw,denw,fs);
            filtered = filter(numdw,dendw,filtered);
            
            
        case {'wf'}
            %% Filter is Wf
            %----------------------band pass filter----------------------------
            % low pass filter
            numf_l = [1 0 0];
            denf_l = [1 sqrt(2)*w_l w_l^2];
            % high pass filter
            numf_h= [1];
            denf_h =[1/(w_h^2) sqrt(2)/w_h 1];
            % band pass filter
            % It is the product of low and high pass filter transfer functions
            numf = conv(numf_l,numf_h);
            denf = conv(denf_l,denf_h);
            [numdf, dendf] = bilinear(numf,denf,fs);
            filtered = filter(numdf,dendf,signal);
            
            %------------------------------------------------------------------
            %------------------Weighting Filters-------------------------------
            % Acceleration-velocity transition
            numav = [1];
            denav = [1/(w4^2) 1/(q4*w4) 1];
            %Upward step filter
            numus = [1/(w5^2) 1/(q5*w5) 1]*((w5)^2);
            denus = [1/(w6^2) 1/(q6*w6) 1]*((w6)^2);
            % Actual wieghting transfer function
            numw = conv(numav,numus);
            denw = conv(denav,denus);
            [numdw, dendw] = bilinear(numw,denw,fs);
            filtered = filter(numdw,dendw,filtered);
            
        case {'wd','wc','we'}
            
            %% Filters are Wd, Wc or We
            %----------------------band pass filter----------------------------
            % low pass filter
            numf_l = [1 0 0];
            denf_l = [1 sqrt(2)*w_l w_l^2];
            % high pass filter
            numf_h= [1];
            denf_h =[1/(w_h^2) sqrt(2)/w_h 1];
            % band pass filter
            % It is the product of low and high pass filter transfer functions
            numf = conv(numf_l,numf_h);
            denf = conv(denf_l,denf_h);
            [numdf, dendf] = bilinear(numf,denf,fs);
            filtered = filter(numdf,dendf,signal);
            
            %------------------------------------------------------------------
            %------------------Weighting Filters-------------------------------
            % Acceleration-velocity transition
            numav = [1/w3 1];
            denav = [1/(w4^2) 1/(q4*w4) 1];
            %Upward step filter
            numus = [1];
            denus = [1];
            % Actual wieghting transfer function
            numw = conv(numav,numus);
            denw = conv(denav,denus);
            [numdw, dendw] = bilinear(numw,denw,fs);
            filtered = filter(numdw,dendw,filtered);
            
        case {'wj'}
            %% Filter is Wj
            %----------------------band pass filter----------------------------
            % low pass filter
            numf_l = [1 0 0];
            denf_l = [1 sqrt(2)*w_l w_l^2];
            % high pass filter
            numf_h= [1];
            denf_h =[1/(w_h^2) sqrt(2)/w_h 1];
            % band pass filter
            % It is the product of low and high pass filter transfer functions
            numf = conv(numf_l,numf_h);
            denf = conv(denf_l,denf_h);
            [numdf, dendf] = bilinear(numf,denf,fs);
            filtered = filter(numdf,dendf,signal);
            
            %------------------------------------------------------------------
            %------------------Weighting Filters-------------------------------
            % Acceleration-velocity transition
            numav = [1];
            denav = [1];
            %Upward step filter
            numus = [1/(w5^2) 1/(q5*w5) 1]*((w5/w6)^2);
            denus = [ 1/w6^2 1/(q6*w6) 1];
            % Actual wieghting transfer function
            numw = conv(numav,numus);
            denw = conv(denav,denus);
            [numdw, dendw] = bilinear(numw,denw,fs);
            filtered = filter(numdw,dendw,filtered);
            
            
    end
catch excp % gotcha!
     throw(excp);
    
end
return

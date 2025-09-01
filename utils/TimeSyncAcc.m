function  [AccX,status,warnings] = TimeSyncAcc(AccR,AccX,SF,OtherFile,syncFigName)
% TimeSyncAcc try to time synchronize data multiple devices worn by the same person based on signal cross-covariance
% Even if proper synchronization is failed the returned data is time matched to reference data. Any
% data which falls outside reference time range will be returned as zeros or NaNs
% accelerometer. If the times are mismatched a lot a warning will be produced.

% Input:
%   AccR [N,4]: Reference accelerometer data first column is time-axis
%   AccX: [N,4] raw-data from other sensor
%   SF: Sample frequency (N=SF*n)
%   OtherFiles: [1,1] string: filename of the other sensor (for plotting sync results)
%   syncFigName: [1,1] String: Figure title of synchronization (if empty no figures will be exported)
%
% Output:
%   AccX [N,4] raw-data from other sensor time-matched and if possible after synchronization
%           Sit-2, Stand-3, Move-4, Walk-5, Run-6,Stair-7, Cycle-8 and Row-9.
%   status [1,1] string: synchronization status OK or NotOK
%   warnings [1,1] string: synchronization status OK or NotOK

%

% based on original sensor synchronization Acti4 algorithm
% See original source at:
% https://github.com/motus-nfa/Acti4/blob/main/Version%20July%202020/AutoSynchronization.m

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


if isempty(syncFigName)
    graph=false;
else
    graph=true;
end

% accumulate all warnings
warnings="";
nsek = 30; % number of seconds to look forward and backward (window size = 2*nsek)

try

    if ~isbetween(AccR(1,1),AccX(1,1)-nsek/86400,AccX(end,1)+nsek/86400) ||...
            ~isbetween(AccR(end,1),AccX(1,1)-nsek/86400,AccX(end,1)+nsek/86400)
        warnings=warnings+" time range mismatch";
    end

    N=size(AccR,1);

    % for covarians analysis (transverse axis not used)
    Rrms = rms(AccR(:,[2,4]),2);

    %number of nsek intervals
    numSeg = fix(N/(SF*nsek));

    % overlapping range of AccX data with AccR is retained and the rest is substituted by zero
    Dintp=zeros(size(AccR));
    Dintp(:,2:4) = interp1(AccX(:,1),AccX(:,2:4),AccR(:,1),'pchip',0); %dataCALF.AXES must be double if 'cubic' is selected
    Dintp(:,1)=AccR(:,1);
    AccX=Dintp; % reasssign interpolated data back to AccX

    % find rms of other sensor (using all axes)
    Xrms = rms(AccX(:,2:4),2);

    % max correlation and lag
    Corr = zeros(numSeg,1);
    Lag = NaN(numSeg,1);


    warning('off','stats:statrobustfit:IterationLimit');
    for j=1:numSeg %every nsek
        iisync = nsek*SF*(j-1)+1:min(nsek*SF*(j+1),N);% +/- nsek intervals, 50% overlap
        if std(Rrms(iisync)) >.05 %some activity must be found
            Kryds = xcov(Rrms(iisync),Xrms(iisync),2*nsek*SF,'coeff'); %max 2*nsek sec lag
            [Corr(j),indMax] = max(Kryds);
            Lag(j) = 2*nsek*SF-indMax+1;
        end
    end

    % time points for correlation tests
    t = (1:numSeg)'*nsek/86400;
    % linear reference time axis starting with 0
    tR = 0:(size(AccR,1)-1);

    % set coreelations less than 0.4 to NaN
    Lag(Corr<0.4) = NaN;


    %disp(OtherFiles{k})
    ii = ~isnan(Corr) & ~isnan(Lag);

    %warning('off')
    if any(ii)
        % linear regression coffeficinets A and B of robust fit (Y=Ax+B)
        [Fit,stat] = robustfit(t(ii),Lag(ii),'bisquare',1);
        %warning('on')
        Lfit = polyval(flip(Fit),t);
        SFratio = N/(N+Lfit(end)-Lfit(1));
        tX = polyval([SFratio,-Lfit(1)],0:(size(AccX,1)-1));

        if graph
            figSync=figure('Units','Normalized','Position',[.55 .05 0.4 0.3],'Visible','off');
            subplot(1,1,1)
            plot(t(ii),Lag(ii)/SF,'k.',t,Lfit/SF,'r')
            ylim([min(Lfit([1,end]))/SF-2 max(Lfit([1,end]))/SF+2])
            title("Sync Thigh Acc against: "+OtherFile,'Interpreter','None')
            xlabel('Elapsed Time (days)')
            ylabel('Relative Delay (s)')
            text(.75,.075,['MAD = ',num2str(stat.mad_s/SF,'%6.3f')],'Units','Normalized')
            drawnow
            exportgraphics(figSync,(syncFigName+"-Sync-"+OtherFile+".png"));
            %export_fig(figSync,(syncFigName+"-Sync-"+OtherFiles{k}),'-png','-p0.05');
            close(figSync);
        end

        if stat.mad_s/SF > 1
            warnings=warnings+" Uncertain synchronization "+OtherFile;
            status="NotOK";
        else
            %outside values are set to NaN
            AccX(:,2:4) = interp1(tX,AccX(:,2:4),tR,'pchip');
            status="OK";
        end
    else
        status="NotOK";
        warnings=warnings+" Not enough active data for synchronization";
    end
    warning('on','stats:statrobustfit:IterationLimit');

catch ME
    status="NotOK";
    warnings=warnings+ME.message;
    warning('on','stats:statrobustfit:IterationLimit');
end
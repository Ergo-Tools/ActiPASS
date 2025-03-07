function  [Xsync,status] = SyncHipTrunkThigh(R,X,SF,OtherFiles,syncFigName)
% SyncHipTrunkThigh time synchronize data multiple devices worn by the same person based on signal cross-covariance

% Input:
%   R [N,3]: Thigh Acc raw data
%   X: {[N,3],[N,3],...} A cell-array of raw-data from other locations (M number of sensors)
%   SF: Sample frequency (N=SF*n)
%   OtherFiles: {'filename1','filename2',...}: filenames of other sensors (for plotting sync results)
%   syncFigName: [1,1] String: Figure title of synchronization (if empty no figures will be exported)
%
% Output:
%   Xsync {[N,3],[N,3],...}: CA cell-array of raw-data from other locations after synchronization
%           Sit-2, Stand-3, Move-4, Walk-5, Run-6,Stair-7, Cycle-8 and Row-9.
%   status [M,1]: synchronization status with any error messages for each sensor

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


N = min([length(R),cellfun(@length,X)]);
nsek = 30; % number of seconds to look forward and backward (window size = 2*nsek)

n = fix(N/(SF*nsek)); %number of nsek intervals

Rrms = rms(R(:,[1 3]),2); %for covarians analyse (transverse axis not used)

minN = min(cellfun(@length,X)); %make sure matrices in X have same length (minN)
X = cellfun(@(x) x(1:minN,:),X,'UniformOutput',false);
Xrms = cell2mat(cellfun(@(x) rms(x,2),X,'UniformOutput',false));

Nchan = size(X,2);
Corr = zeros(n,Nchan);
Lag = NaN(n,Nchan);
Xsync = cell(1,Nchan);
status=strings(Nchan,1);

try
    warning('off','stats:statrobustfit:IterationLimit');
    for j=1:n %every nsek
        iisync = nsek*SF*(j-1)+1:min(nsek*SF*(j+1),N);% +/- nsek intervals, 50% overlap
        if std(Rrms(iisync)) >.05 %some activity must be found
            Kryds = xcov([Rrms(iisync),Xrms(iisync,:)],2*nsek*SF,'coeff'); %max 2*nsek sec lag
            Kryds = Kryds(:,2:Nchan+1);
            [Corr(j,:),I(1:Nchan)] = max(Kryds);
            Lag(j,:) = 2*nsek*SF-I+1;
        end
    end
    
    t = (1:n)'*nsek/86400;
    tR = 0:length(R)-1;
    Fit = zeros(2,Nchan);
    Lfit = zeros(size(Lag));
    
    Lag(Corr<0.4) = NaN;
   
    for k=1:Nchan
        %disp(OtherFiles{k})
        ii = ~isnan(Corr(:,k)) & ~isnan(Lag(:,k));
        
        %warning('off')
        if any(ii)
            [Fit(1:2,k),stat] = robustfit(t(ii),Lag(ii,k),'bisquare',1);
            %warning('on')
            Lfit(:,k) = polyval(flip(Fit(:,k)),t);
            SFratio = N/(N+Lfit(end,k)-Lfit(1,k));
            tX = polyval([SFratio,-Lfit(1,k)],0:length(X{k})-1);
            
            if graph
                figSync=figure('Units','Normalized','Position',[.55 .05 .4 min(.85,.1+Nchan*.19)],'Visible','off');
                subplot(Nchan,1,k)
                plot(t(ii),Lag(ii,k)/SF,'k.',t,Lfit(:,k)/SF,'r')
                ylim([min(Lfit([1 end],k))/SF-2 max(Lfit([1 end],k))/SF+2])
                title("Sync Thigh Acc against: "+OtherFiles{k},'Interpreter','None')
                xlabel('Elapsed Time (days)')
                ylabel('Relative Delay (s)')
                text(.75,.075,['MAD = ',num2str(stat.mad_s/SF,'%6.3f')],'Units','Normalized')
                drawnow
                exportgraphics(figSync,(syncFigName+"-Sync-"+OtherFiles{k}+".png"));
                %export_fig(figSync,(syncFigName+"-Sync-"+OtherFiles{k}),'-png','-p0.05');
                close(figSync);
            end
            
            if stat.mad_s/SF > 1
                status(k)="Uncertain synchronization "+OtherFiles{k};
            else
                Xsync{k} = interp1(tX,X{k},tR,'pchip'); %outside values are set to NaN
                status(k)="OK";
            end
        else
            status(k)="Not enogh points to do the synchronization";
        end
        
    end
    warning('on','stats:statrobustfit:IterationLimit');
catch ME
    status="Error: "+ME.message;
    warning('on','stats:statrobustfit:IterationLimit');
end
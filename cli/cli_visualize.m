function status = cli_visualize(ID,timeFull,actFull,svmFull,BD_full,SI_full,eventsVis,dailyT,Settings,statusBdTime,outDir)
% CLI_VISUALIZE Visualize activities, times-in-beds, sleep and diary-defined events for QC/feedback purposes

% SPDX-License-Identifier: GPL-3.0-or-later
% Copyright (c) 2021-2025 Pasan Hettiarachchi and Peter Johansson

% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
% 
% This **workflow/orchestration code** in `/cli/` is licensed under the
% GNU General Public License, version 3.0 or (at your option) any later version.
% See `../LICENSES/GPL-3.0-or-later.txt` for more details.


visStep=30; % visualization downsampling window
figW=1440; % the width of the weekly visualization figure in pixels
figH=900; % height of the weekly visualization figure
status="";
try
    % create a indices of downsampling data for visualization
    downSmplPts=1:visStep:length(timeFull);
    %always include last elements from 1s data vectors
    if downSmplPts(end)~=length(timeFull)
        downSmplPts=[downSmplPts,length(timeFull)];
    end
    
    % instead of just resampling activity vector use a mode-filter to find the new low-resolution activity vector
    Akt_mode= modefilt(actFull+1,[1,2*floor(visStep/2)+1],'replicate'); %filter window should be odd
    
    % add time-of-bed and sleep data to visualizations
    if (strcmpi(Settings.BEDTIME,"diary") || matches(Settings.BEDTIME,["auto1","auto2"],"IgnoreCase",true)) && strcmpi(statusBdTime,"OK")
        % fill the dataVis cellarray with mode-filtered Akt, SVM and bedtime-sleep data
        visBDSlp=2*BD_full(downSmplPts)+9*SI_full(downSmplPts); % bedtime=2, sleep=11,
    else
        visBDSlp=zeros(length(downSmplPts),1); % no bedtime/sleep just fill a zero column
    end
    
    % find the moving mean of ENMO based on figure resolution
    enmoFull=svmFull-1; % convert SVM to ENMO
    enmoFull(enmoFull<0)=0; % clip negative values at 0
    enmoFull=movmean(enmoFull,visStep); %find the moving mean at 2*visStep window
    enmoFull=enmoFull(downSmplPts); % downsample activit vector for visualization
    
    % fill the dataVis cellarray with mode-filtered Akt, SVM and bedtime-sleep data and temperature
    dataVis=[timeFull(downSmplPts)',Akt_mode(downSmplPts)',enmoFull,visBDSlp'];
    
    % preview the activities
    cli_weekly_plots(ID,outDir,dataVis,eventsVis,dailyT,[0,0,figW,figH]);
    
catch ME
    % add exception message to the existing status text
    status=sprintf('Visualizing error: \n%s\n', getReport(ME,'extended','hyperlinks','off'));
end
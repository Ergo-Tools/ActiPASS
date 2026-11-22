function  [QCData,Acc,meanTEMP,status,warnings] = QCFlipRotation(Acc,TEMP,diaryStrct,devType,Settings,nwTrimMode)

% QCFlipRotation Finds whether thigh accelerometer is incorrectly placed, return corrected data, and 
% trim non-wear in the begining and at the end
%
% How the orientation is decided:
%   - Worn periods are the runs of worn seconds found by NotWornQC (and the diary).
%   - Per worn period, walking (FFT of the band-passed vector magnitude, 10 s buckets) gives the mean
%     X (and Y) while walking, and sitting gives the mean Z.
%   - 90 degree rotation (Y axis vertical) is tested once per worn period, using only that period, and
%     only for periods of at least minRot90Period (1 day) with more than minRot90Walk (120 s) of walking.
%     It is always corrected, also in warn mode, and reported separately (Rot90Time, a warning per period).
%   - The data are cut into segments at the 4 h boundaries of the day and at every start and end of a
%     worn period. Each worn segment votes upside-down (X, from walking) and inside-out (Z, from sitting).
%   - The decision is made per worn period, not per segment: the votes of its segments, weighted by
%     the walking/sitting seconds behind them, decide for the whole worn period. With no vote, or a
%     tie, the GUI default (Settings.Rotated/Flipped) is used. Not-worn segments get the GUI default.
%   - A device turned within a worn period is not followed; when at least minChangeSegs (2 for rotation, 4 for flip) consecutive decided
%     segments vote against the decision, a warning "Possible ... change within worn period" is given.
%
% FunctionCalls:
%   NotWornQC
%   WarmNightT
%   ChangeAxes
%   rle - run_length_encoding function
%
% Inputs:
%   ACC [N,4] Evenly sampled Acc data
%   TEMP [M,2] Temperature data (not necesserarily evenly sampled)

%   diaryStrct [struct] - structure containing diary data (forced NW and bed/night in diary are considered to improve NW)
%   devType: "Axivity", "ActivPAL" etc passed on to ChangeAxes
%   Settings [struct] main ActiPASS Settings structure
%       following fields are used from Settings structure
%       Settings.FLIPROTATIONS [string] - two options: 'warn' or 'force' (LoadSettings allows only these)
%         'warn' - find flips/rotations and report them (QC times, warnings), but transform the whole
%                  file with the GUI default orientation (the 90 degree correction is still applied)
%         'force'- find flips/rotations and return the corrected Acc data
%       [Settings.Rotated, Settings.Flipped] [boolean,boolean] Rotated or Flipped according to ActiPASS default orientation
%   nwTrimMode: [boolean,boolean] flags for cropping NW at Start/End respectively
%
% Outputs:
%
%   QCData: A structure containing 4h segments info used for Flip/Rotations
%           logic and a lot of metadata of the given Acc file
%   ACC: The corrected ACC data
%   meanTemp: the moving-mean temperature taken at 1 minute intervals, sampled at each second (QCData.smpls1S)
%   status: 'OK' if everything is OK. A text containing the error message otherwise
%   warnings [P]: String array of any warnings
%       QCData stucture definition of fields
%           QCData.smpls1S: % the row-index of Acc matrix at every 1s
%           QCData.TotTime: the total duration of datafile in full seconds
%           QCData.WornTime: the variable to hold the number of worn seconds
%           QCData.RotTime: the variable to hold the number of rotated (upside-down) seconds
%           QCData.Rot90Time: the number of seconds corrected for a 90 degree rotation (worn periods of at
%               least one day only; always corrected, also in warn mode; not included in RotTime)
%           QCData.FlipTime: the variable to hold the number of flipped seconds
%           QCData.WalkMarker: a logical array containing probable walking data given at smpls1S
%           QCData.SitMarker: a logical array containing probable sit data given at smpls1S
%      
%      The following are vectors of length [numSegs] having data for 4h segments used to determine
%      flips and rotations. A segment could be shorter than 4h depending on NonWear
%
%           QCData.MTimes[numSegs+1]: the start time of each segment and, last, the time of the last second (datenum)
%           QCData.ElapsedSecs[numSegs+1]: the first second of each segment as an index into the 1 s vectors
%               (smpls1S etc.); the last value is length(smpls1S)+1. Segment k covers ElapsedSecs(k):ElapsedSecs(k+1)-1
%           QCData.XFlipValue[numSegs]: a flag representing probable rotation, -1-rotated, +1-not_rotated, 0-not_determined
%           QCData.ZFlipValue[numSegs]: a flag representing probable flips, -1-flipped, +1-not_flipped, 0-not_determined
%           QCData.XFlipCalc[numSegs]: a flag representing determined rotation, -1-rotated, +1-not_rotated
%           QCData.ZFlipCalc[numSegs]: a flag representing determined flips, -1-flipped, +1-not_flipped
%           QCData.IsWornSeg[numSegs]: a flag whether the the segment is Worn or NotWorn


% **********************************************************************************
%
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

twin_filt= 2; % main time window for different types of filtering
tshort_sit = 20; % time in seconds for filtering out shorter sit periods
twin_medfilt=8; % the time window for median filtering angles and VMs (in seconds)
twin_wlk = 10; % define the time window for walking detection using FFT profile
maxNWWin = Settings.NWSHORTLIM*3600; % maximum accepted continuous NW window within active period before triming (in s)
minActiveWin= Settings.NWTRIMACTLIM*3600; % minimum accepted continuous active window for trimming NW (in s)
trimBuffer=Settings.NWTRIMBUF*3600; % 0; % time buffer before and after active periods when cropping NW
minSitT=120; % the minimum duration of Sitting (per 4h segment) to satisfy sit condition, to be used later in flip detection
minSitTPD=1800; % the minimum duration of Sitting (per 4h segment) to satisfy sit condition, to be used later in flip detection
minWalkT=30; % the minimum duration of walking per day (s), for rotation detection
minRot90Period=86400; % 90 degree rotation is tested only in worn periods of at least this duration (s)
minRot90Walk=120; % ... and only when more than this much walking (s) is detected in the worn period
minChangeSegs=[2,4]; % warn of a possible orientation change within a worn period when at least this many consecutive decided 4h segments disagree with its decision: [rotation (upside-down, from walking), flip (inside-out, from sitting; less specific)]
status=''; % the status flag
warnings=string([]); % any warnings generated
QCData=struct; % the structure to hold multiple results
meanTEMP=[]; % filtered and evenly sampled temperature if exist
meanTEMPWin=60; % time windoww for finding smoothing temperature

% asign default orinetation from Settings
if Settings.Rotated
    defRotation=-1;
else
    defRotation=1;
end

if Settings.Flipped
    defFlip=-1;
else
    defFlip=1;
end

% asign execution mode from settings
exMode=Settings.FLIPROTATIONS;

try
    %% Initialising
    %finding true sampel T and sampel f
    tmpEndInd=min(1000,size(Acc,1));
    SampleInterval=86400*mean(diff(Acc(1:tmpEndInd,1)));% Find the sample interval, Acc time should already be evenly sampled
    Fs=round(1/SampleInterval);
    
    % last sample index for the end of last full second
    lastSmpl = floor(length(Acc)/Fs)*Fs;
    smpls1S=1:Fs:lastSmpl; % main 1 second time scale for many calculations and results
    %     N = length(Acc);
    %     Time = Acc(1,1) + (0:(N-1)/Fs)/86400;
    %svm_bukts=reshape(Acc(1:lastSmpl),[buktSize,bukts]);
    
    %handling temperature vector if exist
    if ~isempty(TEMP)
        SamplIntrvlT=86400*mean(diff(TEMP(:,1))); %sampel period T (it is not precise and has some variation)
        %finding true sampel T and sampel f
        
        meanTEMP=movmean(TEMP(:,2),round(meanTEMPWin/SamplIntrvlT)); % Moving mean to calculate the mean temperatures every one minute
        %interpolate at Acc(smpls1S,1)
        meanTEMP = interp1(TEMP(:,1),meanTEMP,Acc(smpls1S,1));
    else
         %warnings=[warnings,"No Temperature data. Accuracy reduced in NW and auto flips/rotation."];
    end
    
    
    %% Call NotWorn function to find not-worn details
    [NotWornLogic,NightLogic,StdSum,warning] = NotWornQC(Acc,meanTEMP,diaryStrct,Fs,smpls1S);
    warnings=[warnings,warning]; % merge any warning with main warnings vector
    
    
    %% Trim the data based on the NW
    % nwTRIM.mode indicates whether to trim NW from start, end or both ex [1,0],[0,1] or [1,1]
    if any(nwTrimMode)
        NWFilt=removeShortRuns(NotWornLogic,maxNWWin);
        NWFilt=~removeShortRuns(~NWFilt,minActiveWin);
        if ~all(NWFilt)
            if nwTrimMode(1)
                activStart=find(~NWFilt,1,'first'); % find the index of start time of first active period
                indxStartDay=find(Acc(smpls1S,1)>=floor(Acc(smpls1S(activStart),1)),1,'first'); % find the index of start of above day
                % find the index of start of active period on the same day, but with seconds trimBuffer prior
                activStart=max([1,indxStartDay,activStart-trimBuffer]);
            else
                activStart=1;
            end
            if nwTrimMode(2)
                activeEnd=find(~NWFilt,1,'last'); % find the end time of last active period
                indxEndDay=find(Acc(smpls1S,1)<ceil(Acc(smpls1S(activeEnd),1)),1,'last'); % find the index of end of above day
                % find the index of end of active period on the same day, but with seconds trimBuffer added
                activeEnd=min([length(NWFilt),indxEndDay,activeEnd+trimBuffer]);
            else
                activeEnd= length(NWFilt);
            end
            % if the file is completely NW use keep the first day of data
        else
            activStart=1;
            activeEnd= min(86400,length(smpls1S));
        end
        if activStart>1 ||  activeEnd < length(NWFilt)
            QCData.cropStart=round(activStart/3600,2);
            QCData.cropEnd=round((length(NWFilt)-activeEnd)/3600,3);
            if activStart>1 && activeEnd == length(NWFilt)
                warnings=[warnings,QCData.cropStart+" hrs NW at the begining is removed"]; % merge any warning with main warnings vector
            elseif activStart==1 && activeEnd < length(NWFilt)
                warnings=[warnings,QCData.cropEnd+" hrs NW at the end is removed"]; % merge any warning with main warnings vector
            elseif activStart>1 && activeEnd< length(NWFilt)
                warnings=[warnings,QCData.cropStart+" and "+QCData.cropEnd+" hrs NW at the begining and the end is removed"]; % merge any warning with main warnings vector
            end
            % trim NotWornLogic cropping-out NW in the begining and end
            NotWornLogic=NotWornLogic(activStart:activeEnd);
            % trim NightLogic vector
            NightLogic=NightLogic(activStart:activeEnd);
            % trim StdSum Vector
            StdSum=StdSum(activStart:activeEnd);
            % trim the Acc vectors.
            indActivStart=smpls1S(activStart);
            indActivEnd=smpls1S(activeEnd)+Fs-1;
            Acc=Acc(indActivStart:indActivEnd,:);
            % save trim start/end indices of original Acc vector (for trimming other sensor data)
            QCData.indActivStart=indActivStart;
            QCData.indActivEnd=indActivEnd;
            % trim the smpls1S vector
            smpls1S=smpls1S(activStart:activeEnd)-smpls1S(activStart)+1;
            %trim the meanTemp vector if exist
            if ~isempty(meanTEMP)
                meanTEMP=meanTEMP(activStart:activeEnd);
            end
        end
    end
    
    % define the main time vector, find total duration after trimming and bring forward these data QCData struct 
    Time1S=Acc(smpls1S,1); % the time vector for the selected samples in datenum format
    QCData.smpls1S=smpls1S;
    QCData.TotTime=length(smpls1S); % the total duration of datafile in full seconds
    
    %if no auto-trimming was done, set trimming data to zer
    if ~isfield(QCData,'cropStart')
        QCData.cropStart=0;
            
    end
    if ~isfield(QCData,'cropEnd')
        QCData.cropEnd=0;
    end
    
    % check the execution mode and execute flips/rotations logic
    if strcmpi(exMode,'Warn') || strcmpi(exMode,'Force')
        
        %% Finding means,SDs and median-filtering of ACC data
               
        FiltWinSz=Fs*twin_filt; % the size of time-window as number of samples  ( 2s default)
        
        movMeanAcc=movmean(Acc(:,2:4),FiltWinSz,1);
        movMeanAcc=movMeanAcc(smpls1S,:);
        % find median filtered vector magnitude in XY plane. This will be used
        % later for detecting sit periods (for flip detection)
        medfiltXY=medfilt1(sqrt(movMeanAcc(:,1).^2 + movMeanAcc(:,2).^2),twin_medfilt);
        %% Find warm periods during nights to exclude in Flip detection logic
        % uses NightLogic returned from NotWornQC (which contains night/bed times given in diary or based on time of day)       % day)
        % after the following call NightLogic contains warm night periods
        [NightLogic,warning] = WarmNightT(meanTEMP,Time1S,NightLogic);
        warnings=[warnings,warning]; % merge any warning with main warnings vector
        %% The Main flips/rotations detection code
        % Each worn period is processed seperately in a for loop flip detection
        % flipDetails=cell(numPeriod,5); % A cell array of the flip details to be returned by the function as a cell array for debug purposes
        
        WalkMarker=nan(length(smpls1S),1); % An array to be filled with mean values of X-vector for walking periods
        WalkMarkerY=nan(length(smpls1S),1); % An array to be filled with mean values of Y-vector for walking periods (in case the device is only rotated 90 degrees)
        SitMarker=nan(length(smpls1S),1); % An array to be filled with mean values of Z-vector for sit periods
        
        % Seperate worn sections to be processed for Flip/Rotation detection
        rle_W=rle(~NotWornLogic); % run-length-encoding of Wear-Logic
        WornPeriods=find(rle_W{1}==1);
        numPeriod=length(WornPeriods);
        
        % time of 90 degree rotation
        timeRot90=0;

        % things that do not change between worn periods
        [B_bp,A_bp] = butter(6,[1.0,3.0]/(Fs/2)); % bandpass filter of 1.0 -3.0 Hz for walking detection
        numSmpls1S=length(smpls1S);
        regular1S=smpls1S(1)==1 && all(diff(smpls1S)==Fs); % smpls1S(k)=1+(k-1)*Fs (always, unless Acc was not evenly sampled)
        
        % Now we are iterating through each worn period
        for period=1:numPeriod
            selectPts=rle_W{3}(WornPeriods(period)):rle_W{4}(WornPeriods(period)); % % the indices of the selected worn period (of all main 1 s intervals arrays - (smplPts1S, NotWornLogic etc.)
             
            % the full range of indices in the original ACC vector, including all samples of the last worn second
            selIndsAcc=smpls1S(selectPts(1)):min(smpls1S(selectPts(end))+Fs-1,size(Acc,1));

            
            %% Find Rotations using walking detection
            
            % finding the VM of thigh acclerometer...
            svm_walk=sqrt(sum(Acc(selIndsAcc,2:4) .^ 2, 2));
            % filtering data with a bandpass filter of 1.0 -3.0 Hz (B_bp,A_bp designed before the loop)
            svm_walk_f = filter(B_bp,A_bp,svm_walk);
           
            
            % number of full buckets we can supply, do not include a partial bucket
            buktSize=Fs*twin_wlk;
            bukts = floor(length(svm_walk) / buktSize);
            
            % last sample index for the end of the last bucket
            lastSmpl = bukts * buktSize;
            
            svm_bukts=reshape(svm_walk_f(1:lastSmpl),[buktSize,bukts]);
            % t_bukts=reshape(Acc(1:lastSmpl,1),[buktSize,bukts]);
            
            f_scale = Fs*(0:(buktSize/2))/buktSize; %frequency scale
            fft_bukts=fft(svm_bukts);
            P1 = abs(fft_bukts/buktSize);
            P1 = P1(1:buktSize/2+1,:);
            P1(2:end-1,:) = 2*P1(2:end-1,:);
            [f_pwr,f_i]=max(P1,[],1);  % Can we use findpeaks to detect other frequency peaks
            f_i=f_scale(f_i);
            
            %wlk_bukts=(f_pwr> 0.3) & (f_i> 1.4) & (f_i <2.4); % find the buckets matching FFT walking profile %default
            %
            wlk_bukts=(f_pwr> 0.3) & (f_i> 1.3) & (f_i < 2.3); % find the buckets matching FFT walking profile
            wlk_logic=repelem(wlk_bukts,1,buktSize); % expand the buckets to a logical array of the length of the data
            % seperate sections of walking withing the worn period using run-length-encodings

            % For each walking period find flips using the range of X-axis value
            rle_Wlk=rle(wlk_logic); % run-length-encode wlk_logic vector
            wlkSections=find(rle_Wlk{1}==1); % find walking sections
            wlkSecStarts=selIndsAcc(rle_Wlk{3}(wlkSections)); % start indices of those sections
            wlkSecEnds=selIndsAcc(rle_Wlk{4}(wlkSections));  % end indices of those sections
            
            for section=1:length(wlkSections)
                % the indices of Acc vector corresponding to current walking section
                wlkSectAccInds=wlkSecStarts(section):wlkSecEnds(section);
                if regular1S % smpls1S(k)=1+(k-1)*Fs: the same as the find calls below, without searching smpls1S
                    wlkSmplPtStart=ceil((wlkSectAccInds(1)-1)/Fs)+1; % the first second starting at or after the section start
                    wlkSmplPtEnd=min(ceil((wlkSectAccInds(end)-1)/Fs),numSmpls1S); % the last second starting before the section end
                else
                    wlkSmplPtStart=find(smpls1S>=wlkSectAccInds(1),1,'first'); % find corresponding index of main 1S vector
                    wlkSmplPtEnd=find(smpls1S<wlkSectAccInds(end),1,'last'); % find corresponding index of main 1S vector
                end
                % the mean value of X-axis for detected walking segment
                WalkMarker(wlkSmplPtStart:wlkSmplPtEnd)=mean(Acc(wlkSectAccInds,2)); %assign mean x-value to all seconds in current section 
                
                % in case accelerometer is rotated only 90 degrees (y-axis becomes the vertical axis). We can correct
                % this error straight-away. We need also the mean values of y-axis during walking segments to do this
                WalkMarkerY(wlkSmplPtStart:wlkSmplPtEnd)=mean(Acc(wlkSectAccInds,3)); %assign mean y-value to all seconds in current section 
            end
            % Test for 90 degree rotation. This is always corrected, even when flip-rotation is set to off or warn.
            % It is a rare case and the FFT walking detection is too uncertain for short periods, so the test
            % is done only for worn periods of at least minRot90Period with more than minRot90Walk of walking.
            % Only the walking of the current worn period is used.
            nWalkSecs=sum(~isnan(WalkMarker(selectPts))); % seconds of walking in the current worn period
            if length(selectPts)>=minRot90Period && nWalkSecs>minRot90Walk
                nanMeanX=mean(WalkMarker(selectPts),'omitnan'); nanMeanY=mean(WalkMarkerY(selectPts),'omitnan');
                if abs(nanMeanX-1)>=0.4 && abs(nanMeanX-1)<=1.6  % this means rotation cannot be detected using X axis.
                    timeRot90Before=timeRot90;
                    if  abs(nanMeanY-1)<0.35 % x-axis has become positive y-axis
                        Acc(selIndsAcc,2:3)= [-Acc(selIndsAcc,3),Acc(selIndsAcc,2)];
                        WalkMarker(selectPts)=-WalkMarkerY(selectPts); % use the y-axis based walkmaker (this worn period only)
                        timeRot90=timeRot90+length(selectPts);
                    elseif abs(nanMeanY-1)>1.65 % y-axis has become positive x-axis
                        Acc(selIndsAcc,2:3)= [Acc(selIndsAcc,3),-Acc(selIndsAcc,2)];
                        WalkMarker(selectPts)=WalkMarkerY(selectPts); % use the y-axis based walkmaker (this worn period only)
                        timeRot90=timeRot90+length(selectPts);
                    end
                    if timeRot90>timeRot90Before % report each corrected worn period
                        warnings=[warnings,sprintf('90 degree rotation corrected between %s to %s',...
                            datestr(Time1S(selectPts(1)),'mmm.dd, HH:MM'),datestr(Time1S(selectPts(end)),'mmm.dd, HH:MM'))];
                    end
                end
            end
            %% Find Flips by trying to find the sit periods
            % first we have to identify sit periods within the selected worn period. They are defined as the
            % periods where sum of standard deviation of all axes less than 0.1,
            % and not-sleeping as well as not standing or wlking (based on median filtered XY vector magnitude.
            
            SitSelect=(StdSum(selectPts) < 0.1) & ~NightLogic(selectPts) & ~(medfiltXY(selectPts)>0.7);
            SitSelect=removeShortRuns(SitSelect,tshort_sit); % remove sit periods shorter than tshort_sit seconds (default 20)
            
            
            % seperate sections of valid Z data withing the worn period using run-length-encoding 
            rle_Sit=rle(SitSelect); % run-length-encode SitSelect vector
            sitSections=find(rle_Sit{1}==1); % find walking sections
            sitSecStarts=selectPts(rle_Sit{3}(sitSections)); % start indices of those sections
            sitSecEnds=selectPts(rle_Sit{4}(sitSections));  % end indices of those sections
            % Now iterate through each section and save the mean value of Z-vector for each section.
            % All elements for the time period of selected section of primary ZFlipLogic array fill be filled with
            % this mean value.
           
            for section=1:length(sitSections)
                
                % then find the relevant range of indices of main 1s vector
                sitSectAccInds=smpls1S(sitSecStarts(section)):smpls1S(sitSecEnds(section)); % the corresponding indices range for Accvector
                SitMarker(sitSecStarts(section):sitSecEnds(section))=mean(Acc(sitSectAccInds,4));% mean z-value is assigned to corresponding secods in SItMarker
            end
            
        end
        
        %% create 4h segments for flips/rotations correction
        % The segments are kept as indices into the 1 s vectors (Time1S, smpls1S, NotWornLogic etc.): segment k
        % covers the seconds segEdges(k):segEdges(k+1)-1. A new segment starts at every 4 h boundary of the day
        % (00, 04, 08, 12, 16 and 20 h) and at every start and end of a worn period, so each segment is either
        % fully worn or fully not worn. The 4 h boundaries are found on whole seconds (no datenum comparisons).
        numSecs1S=length(smpls1S);
        block4h=floor(round(Time1S(:)*86400)/14400); % the 4 h block of the day each second belongs to
        wornStarts=rle_W{3}(WornPeriods); wornEnds=rle_W{4}(WornPeriods); % first and last second of each worn period
        segEdges=unique([1; find(diff(block4h)~=0)+1; wornStarts(:); wornEnds(:)+1; numSecs1S+1]);
        numSegments=length(segEdges)-1; % the number of 4h or shorter segments (depending on not-worn gaps)
        QCData.ElapsedSecs=segEdges; % the first second (index of the 1 s vectors) of each segment, the last value is numSecs1S+1
        QCData.MTimes=[Time1S(segEdges(1:end-1)); Time1S(end)]; % segment start times and the time of the last second

        % intialise QCData fields to hold various details

        QCData.WornTime=0; % the variable to hold the number of worn seconds
        QCData.RotTime=0; % the variable to hold the number of rotated (upside-down) seconds
        QCData.Rot90Time=timeRot90; % the number of seconds corrected for a 90 degree rotation (not part of RotTime)
        QCData.FlipTime=0; % the variable to hold the number of flipped seconds

        QCData.XFlipValue=zeros(numSegments,1); % a flag representing probable rotation, -1-rotated, +1-not_rotated
        QCData.ZFlipValue=zeros(numSegments,1); % a flag representing probable flips, -1-flipped, +1-not_flipped
        QCData.XFlipCalc=zeros(numSegments,1); % a flag representing determined rotation, -1-rotated, +1-not_rotated
        QCData.ZFlipCalc=zeros(numSegments,1); % a flag representing determined flips, -1-flipped, +1-not_flipped
        ZFlipCalcLength=zeros(numSegments,1); % the duration in seconds used to determine probable otations
        XFlipCalcLength=zeros(numSegments,1); % the duration in seconds used to determine probable flips
        QCData.IsWornSeg=false(numSegments,1); % a flag whether the the segment is Worn or NotWorn
        QCData.WalkMarker=WalkMarker; %export WalkMarker array to be used in reference position calculation in the main program
        QCData.SitMarker=SitMarker; %export SitMarker array (to be used if needed)
        %XUncertSeg=0; % to hold the segment number of last uncertain segment for X-flips
        %ZUncertSeg=0; % to hold the segment number of last uncertain segment for Z-flips
        
        %% the following for loop is the logic for decideing whether a given 4h
        % segment (or shorter depending on non-wear periods) is flipped, rotated
        % or both using mean values of X and Z (during walking and sit periods)
        % A decision is made only when it can be made with enough certanity
        % The decision made here could be changed in the following for loop where
        % it considers all segments in a given worn period and make the final
        % decision of flip and rotation.
        
        for segnum=1:numSegments
            segSamplPts=segEdges(segnum):segEdges(segnum+1)-1;
            nanMeanX=mean(WalkMarker(segSamplPts),'omitnan'); % find the mean value excluding NaN
            nanMeanZ=mean(SitMarker(segSamplPts),'omitnan'); % find the mean value excluding NaN
            n_nanZ=sum(~isnan(SitMarker(segSamplPts))); % find the the no of non-NaN
            n_nanX=sum(~isnan(WalkMarker(segSamplPts))); % find the the no of non-NaN

            IsWornSegment=~NotWornLogic(segSamplPts(1)); % a segment is either fully worn or fully not worn
            QCData.IsWornSeg(segnum)=IsWornSegment; % mark the segment as worn
            
            % the segment is determined to be worn
            if IsWornSegment
                % Rotation Check:
                if ~isnan(nanMeanX) % if not all are NaN
                    if abs(nanMeanX-1)<0.4 % rotated
                        QCData.XFlipValue(segnum)= -1;
                        
                    elseif abs(nanMeanX-1)>1.6 % not rotated
                        QCData.XFlipValue(segnum)= 1;
                    end
                    % also save the no of seconds used to make the decision
                    XFlipCalcLength(segnum)=n_nanX;
                end
                
                % Flip Check:
                % if not all are NaN and more than 120 s of sit period
                if ~isnan(nanMeanZ) && n_nanZ> minSitT
                    if abs(nanMeanZ-1)<0.4 % not flipped
                        QCData.ZFlipValue(segnum)= 1;
                        
                    elseif abs(nanMeanZ-1)>1.6
                        QCData.ZFlipValue(segnum)= -1; %flipped
                    end
                    % also save the no of seconds used to make the decision
                    ZFlipCalcLength(segnum)=n_nanZ;
                end
            end
        end

        %% Extrapolate the XFlips (rotations) and ZFlips (Flips) for all segments
        % First, Use flip/rotation values for each 4h segment during a single worn
        % period to find the orinentations for that particular worn period. Then
        % for each worn period the raw accelerometer data is changed based on
        % the orientation
        
        % use run_length_encoding to find each worn period
        rle_WS=rle(QCData.IsWornSeg); % run-length-encode wlk_logic vector
        WSegments=find(rle_WS{1}==1); % find walking sections
            
        
        for segmnt=1:length(WSegments)
            slctSgments=(rle_WS{3}(WSegments(segmnt)):rle_WS{4}(WSegments(segmnt)))';
            tempXFlipV=QCData.XFlipValue(slctSgments);
            tempXFlipCalcLength=XFlipCalcLength(slctSgments);
            tempZFlipV=QCData.ZFlipValue(slctSgments);
            tempZFlipCalcLength=ZFlipCalcLength(slctSgments);
            segTimes=QCData.MTimes([slctSgments,slctSgments+1]);
            % use mode to find the whether selected worn period is rotated
            nonZeroXFlpV=tempXFlipV~=0; % the non-zero logical index of tempXFlipV
            if any(nonZeroXFlpV)
                % majority vote of the 4h segments, each weighted by the number of
                % walking seconds used for its decision (a tie gives the default)
                QCData.XFlipCalc(slctSgments)=weightedVote(tempXFlipV,tempXFlipCalcLength,defRotation);
                % check whether at least 'minWalkT' of walking per day detected for rotation detection
                if sum(tempXFlipCalcLength(nonZeroXFlpV)) < minWalkT*(segTimes(end)-segTimes(1)) % normalized to per/day, i.e. multiplied seg. length in days
                    % find the times of short worn segments
                    warnings=[warnings,sprintf('Rotation detection between %s to %s uncertain',...
                        datestr(segTimes(1),'mmm.dd, HH:MM'),datestr(segTimes(end),'mmm.dd, HH:MM'))];
                end
            else
                QCData.XFlipCalc(slctSgments)=defRotation;
                warnings=[warnings,sprintf('Rotation detection between %s to %s unsuccessful. Defaults assumed',...
                    datestr(segTimes(1),'mmm.dd, HH:MM'),datestr(segTimes(end),'mmm.dd, HH:MM'))];
            end
            % use mode to find the whether selected worn period is flipped
            nonZeroZFlpV=tempZFlipV~=0;% the non-zero logical index of tempZFlipV
            if any(nonZeroZFlpV)
                
                % majority vote of the 4h segments, each weighted by the number of
                % sitting seconds used for its decision (a tie gives the default)
                QCData.ZFlipCalc(slctSgments)=weightedVote(tempZFlipV,tempZFlipCalcLength,defFlip);
                % check whether at least 'minSitTPD' of sitting per day detected for Flip detection
                if sum(tempZFlipCalcLength(nonZeroZFlpV)) < minSitTPD*(segTimes(end)-segTimes(1)) % normalized to per/day by multiplying segment length in days
                    warnings=[warnings,sprintf('Flip detection between %s to %s uncertain',...
                        datestr(segTimes(1),'mmm.dd, HH:MM'),datestr(segTimes(end),'mmm.dd, HH:MM'))];
                end
            else
                QCData.ZFlipCalc(slctSgments)=defFlip;
                warnings=[warnings,sprintf('Flip detection between %s to %s unsuccessful. Defaults assumed',...
                    datestr(segTimes(1),'mmm.dd, HH:MM'),datestr(segTimes(end),'mmm.dd, HH:MM'))];
            end
            % Diagnostic only (the decision above is kept for the whole worn period): warn when the 4h votes
            % against the decision form a run of at least minChangeSegs consecutive decided segments, which
            % suggests that the device was turned within the worn period (e.g. re-attached without a still period)
            chgTxt=["rotation (upside-down)","flip (inside-out)"];
            chgVals={tempXFlipV,tempZFlipV};
            chgDecs=[QCData.XFlipCalc(slctSgments(1)),QCData.ZFlipCalc(slctSgments(1))];
            for itrChg=1:2
                chgSeg=orientChangeStart(chgVals{itrChg},chgDecs(itrChg),minChangeSegs(itrChg));
                if ~isempty(chgSeg)
                    warnings=[warnings,sprintf('Possible %s change within worn period %s to %s, from about %s',...
                        chgTxt(itrChg),datestr(segTimes(1),'mmm.dd, HH:MM'),datestr(segTimes(end),'mmm.dd, HH:MM'),...
                        datestr(QCData.MTimes(slctSgments(chgSeg)),'mmm.dd, HH:MM'))];
                end
            end

        end
        
        %% Flip-Rotation correction by transforming the raw-data
        % Iterate through 4H segments  and transform raw ACC data according to the orientation
        for segnum=1:numSegments
            numSecs=QCData.ElapsedSecs(segnum+1)-QCData.ElapsedSecs(segnum);
            % Find accumulated worn, flipped and rotated times
            if QCData.IsWornSeg(segnum)
                QCData.WornTime=QCData.WornTime+numSecs;
                QCData.FlipTime=QCData.FlipTime+numSecs*(QCData.ZFlipCalc(segnum)== -1);
                QCData.RotTime=QCData.RotTime+numSecs*(QCData.XFlipCalc(segnum) == -1);
            end
            
            if strcmpi(exMode,'Force')
                % Find the orinetation value based on XFlipCalc and ZFlipCalc of worn segments. Not-worn
                % segments get the default orientation of the GUI settings (Settings.Rotated/Flipped)
                if QCData.IsWornSeg(segnum)
                    xCalc=QCData.XFlipCalc(segnum); zCalc=QCData.ZFlipCalc(segnum);
                else
                    xCalc=defRotation; zCalc=defFlip;
                end
                if xCalc == -1 && zCalc== -1
                    Orientation=4; % both flipped and rotated
                elseif xCalc == -1 && zCalc== 1
                    Orientation=3; % Rotated
                elseif xCalc == 1 && zCalc== -1
                    Orientation=2; % flipped
                else
                    Orientation=1; % no flip or rotation
                end
                
                %Find the indices corresponding to the 4h period in Acc matrix (the last segment runs to the end of Acc)
                if segnum<numSegments
                    SgtSmplPts=smpls1S(segEdges(segnum)):smpls1S(segEdges(segnum+1))-1;
                else
                    SgtSmplPts=smpls1S(segEdges(segnum)):size(Acc,1);
                end
                % call ChangeAxes function to change the orientation
                Acc(SgtSmplPts,2:4) = ChangeAxes(Acc(SgtSmplPts,2:4),devType,Orientation);
            end
        end
    end
    
    %% Final stage of QC-module 
    % if exMode is Warn or off assume default flips/rotations
    if ~strcmpi(exMode,'Force')
        
        % derive orientation form [Settings.Rotated, Settings.Flipped] (1=[0,0], 2=[0,1],3=[1,0], 4=[1,1]
        Orientation=2*Settings.Rotated+Settings.Flipped+1; 
        % call ChangeAxes function to change the orientation
        Acc(:,2:4) = ChangeAxes(Acc(:,2:4),devType,Orientation);
    end
    
    % if everything is fine set the status flag
    status='OK';
catch ME
    % if an exception occur and exMode is force assume default orientation
    % and correct Acc data s.t. activity detection works
    if ~strcmpi(status,'OK')
        % derive orientation form [Settings.Rotated, Settings.Flipped]. (1=[0,0], 2=[0,1],3=[1,0], 4=[1,1]
        Orientation=2*Settings.Rotated+Settings.Flipped+1; 
        % call ChangeAxes function to change the orientation
        Acc(:,2:4) = ChangeAxes(Acc(:,2:4),devType,Orientation);
    end
    status="QC Module crashed";
    % add detailed exception message to warnings vector
    warnings=[warnings,getReport(ME,'extended','hyperlinks','off')]; % merge any warning with main warnings vector
end

end

function v = weightedVote(values, secs, defValue)
% weightedVote  majority of the -1/+1 decisions in values, each weighted by its seconds in secs
% (0 = no decision, ignored); a tie gives defValue
wPos=sum(secs(values==1));
wNeg=sum(secs(values==-1));
if wPos>wNeg
    v=1;
elseif wNeg>wPos
    v=-1;
else
    v=defValue;
end
end

function k = orientChangeStart(values, decision, minRun)
% orientChangeStart  start (index into values) of the longest run of at least minRun consecutive decided
% votes (-1/+1; 0 = no decision, skipped) against decision; empty if there is no such run
k=[];
idx=find(values(:)~=0);
if isempty(idx), return; end
r=rle((values(idx)==-decision)');
runs=find(r{1}==1 & r{2}>=minRun);
if ~isempty(runs)
    [~,b]=max(r{2}(runs));
    k=idx(r{3}(runs(b)));
end
end

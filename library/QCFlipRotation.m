function  [QCData,Acc,meanTEMP,status,warnings] = QCFlipRotation(Acc,TEMP,diaryStrct,devType,exMode,defOrientation,nwTRIM)

% QCFlipRotation Finds whether thigh accelerometer is incorrectly placed, return corrected data, and 
% trim non-wear in the begining and at the end
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
%   exMode [string] - two options: 'Warn' or 'Full' 
%       'Warn' - Only find flips/rotations but returns original Acc data,
%       'Full'- find flips/rotations and return corrected Acc data
%   diaryStrct [struct] - structure containing diary data (forced NW and bed/night in diary are considered to improve NW)
%   devType: "Axivity", "ActivPAL" etc passed on to ChangeAxes
%   defaultOrientation [boolean,boolean] Rotated or Flipped according to Acti4 default orientation
%   nwTRIM: [struct] Settings for cropping NW at Start/End
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
%           QCData.RotTime: the variable to hold the number of rotated seconds
%           QCData.FlipTime: the variable to hold the number of flipped seconds
%           QCData.WalkMarker: a logical array containing probable walking data given at smpls1S
%           QCData.SitMarker: a logical array containing probable sit data given at smpls1S
%      
%      The following are vectors of length [numSegs] having data for 4h segments used to determine
%      flips and rotations. A segment could be shorter than 4h depending on NonWear
%
%           QCData.MTimes[numSegs+1]: all transition times of 4h segments including the end points in datenum format
%           QCData.ElapsedSecs[numSegs+1]: number of seconds elapsed at the transitions of each 4h segment
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
maxNWWin = nwTRIM.NWSHORTLIM*3600; % maximum accepted continuous NW window within active period before triming (in s)
minActiveWin= nwTRIM.NWTRIMACTLIM*3600; % minimum accepted continuous active window for trimming NW (in s)
trimBuffer=nwTRIM.NWTRIMBUF*3600; % 0; % time buffer before and after active periods when cropping NW
minWornT=60; % the minimum duration of an active segment to be considered worn, to be used later in NW detection
minSitT=120; % the minimum duration of Sitting (per 4h segment) to satisfy sit condition, to be used later in flip detection
minSitTPD=1800; % the minimum duration of Sitting (per 4h segment) to satisfy sit condition, to be used later in flip detection
minWalkT=30; % the minimum duration of walking per day (s), for rotation detection
status=''; % the status flag
warnings=string([]); % any warnings generated
QCData=struct; % the structure to hold multiple results
meanTEMP=[]; % filtered and evenly sampled temperature if exist

if defOrientation(1)
    defRotation=-1;
else
    defRotation=1;
end
if defOrientation(2)
    defFlip=-1;
else
    defFlip=1;
end


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
        
        meanTEMP=movmean(TEMP(:,2),round(60/SamplIntrvlT)); % Moving mean to calculate the mean temperatures every one minute
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
    if any(nwTRIM.mode)
        NWFilt=bwareaopen(NotWornLogic ,maxNWWin);
        NWFilt=~bwareaopen(~NWFilt,minActiveWin);
        if ~all(NWFilt)
            if nwTRIM.mode(1)
                activStart=find(~NWFilt,1,'first'); % find the index of start time of first active period
                indxStartDay=find(Acc(smpls1S,1)>=floor(Acc(smpls1S(activStart),1)),1,'first'); % find the index of start of above day
                % find the index of start of active period on the same day, but with seconds trimBuffer prior
                activStart=max([1,indxStartDay,activStart-trimBuffer]);
            else
                activStart=1;
            end
            if nwTRIM.mode(2)
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
        WornTimes=zeros(1,numPeriod*2); % The start, end and worn-not worn transition times. Should be twice the size of nmber of worn periods
        
        % time of 90 degree rotation
        timeRot90=0;
        
        % Now we are iterating through each worn period
        for period=1:numPeriod
            selectPts=rle_W{3}(WornPeriods(period)):rle_W{4}(WornPeriods(period)); % % the indices of the selected worn period (of all main 1 s intervals arrays - (smplPts1S, NotWornLogic etc.)
             
            selIndsAcc=smpls1S(selectPts(1)):smpls1S(selectPts(end)); % the full range of indices in the original ACC vector
            WornTimes(2*period-1)=Acc(selIndsAcc(1),1); % the start of current worn period as datetime value
            WornTimes(2*period)=Acc(selIndsAcc(end),1); % the end of current worn period as datetime value
            %flipDetails{period,4}=[WornTimes(2*period-1),WornTimes(2*period)]; % also save above to flipDetails cell array
           
            
            %% Find Rotations using walking detection
            
            % finding the VM of thigh acclerometer...
            svm_walk=sqrt(sum(Acc(selIndsAcc,2:4) .^ 2, 2));
            % filtering data with a bandpass filter of 1.0 -3.0 Hz
            [B_bp,A_bp] = butter(6,[1.0,3.0]/(Fs/2));
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
                wlkSmplPtStart=find(smpls1S>=wlkSectAccInds(1),1,'first'); % find corresponding index of main 1S vector
                wlkSmplPtEnd=find(smpls1S<wlkSectAccInds(end),1,'last'); % find corresponding index of main 1S vector
                % the mean value of X-axis for detected walking segment
                WalkMarker(wlkSmplPtStart:wlkSmplPtEnd)=mean(Acc(wlkSectAccInds,2)); %assign mean x-value to all seconds in current section 
                
                % in case accelerometer is rotated only 90 degrees (y-axis becomes the vertical axis). We can correct
                % this error straight-away. We need also the mean values of y-axis during walking segments to do this
                WalkMarkerY(wlkSmplPtStart:wlkSmplPtEnd)=mean(Acc(wlkSectAccInds,3)); %assign mean y-value to all seconds in current section 
            end
            nanMeanX=nanmean(WalkMarker); nanMeanY=nanmean(WalkMarkerY);
            % Test for 90 degree rotation. This is always corrected, even when flip-rotation is set to off or warn
            if abs(nanMeanX-1)>=0.4 && abs(nanMeanX-1)<=1.6  % this means rotation cannot be detected using X axis.
                
                if  abs(nanMeanY-1)<0.35 % x-axis has become positive y-axis
                    Acc(selIndsAcc,2:3)= [-Acc(selIndsAcc,3),Acc(selIndsAcc,2)];
                    WalkMarker=-WalkMarkerY; % use the y-axis based walkmaker
                    timeRot90=timeRot90+length(selectPts);
                elseif abs(nanMeanY-1)>1.65 % y-axis has become positive x-axis
                    Acc(selIndsAcc,2:3)= [Acc(selIndsAcc,3),-Acc(selIndsAcc,2)];
                    WalkMarker=WalkMarkerY; % use the y-axis based walkmaker
                    timeRot90=timeRot90+length(selectPts);
                end
            end
            %% Find Flips by trying to find the sit periods
            % first we have to identify sit periods within the selected worn period. They are defined as the
            % periods where sum of standard deviation of all axes less than 0.1,
            % and not-sleeping as well as not standing or wlking (based on median filtered XY vector magnitude.
            
            SitSelect=(StdSum(selectPts) < 0.1) & ~NightLogic(selectPts) & ~(medfiltXY(selectPts)>0.7);
            SitSelect=bwareaopen(SitSelect,tshort_sit); % remove sit periods shorter than tshort_sit seconds (default 20)
            
            
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
        
        startTime=Time1S(1);
        endTime=Time1S(end);
        
        if (startTime*6) ~= ceil(startTime*6)
            first4hend=ceil(startTime*6)/6;
        else
            first4hend= min(startTime+ 1/6.0,endTime);
        end
        %first4hend=dateshift(startDTime,'start','day')+ hours(4*ceil(hour(dateshift(startDTime,'end','hour'))/4)); % find the start of next 4h period from the start time
        
        if (endTime*6) ~= floor(endTime*6)
            last4hstart=floor(endTime*6)/6;
        else
            last4hstart= max(endTime -1/6.0,startTime);
        end
        %last4hstart=dateshift(endDTime,'start','day')+ hours(4*floor(hour(dateshift(endDTime,'start','hour'))/4)); % find the begining of last 4h period
        
        segMarkers=round((first4hend:(1/6):last4hstart)*86400)/86400;
        QCData.MTimes=[startTime,segMarkers,endTime];
        QCData.MTimes=unique(sort([QCData.MTimes,WornTimes]))'; % Merge with Worn times, now it contains both 4h intervals and also worn-notWorn transitions, transpose to make it a column vector
        
        numSegments=length(QCData.MTimes)-1; % the number of 4h or shorter segments (depending on not-worn gaps)
        
        % intialise QCData fields to hold various details
        
        QCData.WornTime=0; % the variable to hold the number of worn seconds
        QCData.RotTime=timeRot90; % the variable to hold the number of rotated seconds (this include previously calculated 90 degree rotations)
        QCData.FlipTime=0; % the variable to hold the number of flipped seconds
        QCData.ElapsedSecs=zeros(length(QCData.MTimes),1);
        
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
            segStartPt=find(Time1S>=QCData.MTimes(segnum),1,'first');
            segEndPt=find(Time1S< QCData.MTimes(segnum+1),1,'last');
            QCData.ElapsedSecs(segnum)=segStartPt;
            
            segSamplPts=segStartPt:segEndPt;
            nanMeanX=nanmean(WalkMarker(segSamplPts)); % find the mean value excluding NaN
            nanMeanZ=nanmean(SitMarker(segSamplPts)); % find the mean value excluding NaN
            n_nanZ=sum(~isnan(SitMarker(segSamplPts))); % find the the no of non-NaN
            n_nanX=sum(~isnan(WalkMarker(segSamplPts))); % find the the no of non-NaN
            
            IsWornSegment=sum(~NotWornLogic(segSamplPts))>minWornT; % if at least minWornT(s) worn
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
        % set the end of time as the end of ElapsedSecs
        QCData.ElapsedSecs(end)=segEndPt;
        
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
                % before finding the mode, repeat the value found by
                % the number of seconds used make the decision within each
                % particular 4h segment. If a decision cannot be made for a
                % particular worn period XFlipCalc = 0
                QCData.XFlipCalc(slctSgments)=mode(repelem(tempXFlipV(nonZeroXFlpV),tempXFlipCalcLength(nonZeroXFlpV)));
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
                
                % before finding the mode, repeat the value found by
                % the number of seconds used make the decision within each
                % particular 4h segment.If a decision cannot be made for a
                % particular worn period ZFlipCalc = 0
                QCData.ZFlipCalc(slctSgments)=mode(repelem(tempZFlipV(nonZeroZFlpV),tempZFlipCalcLength(nonZeroZFlpV)));
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
                % Find the orinetation value based on XFlipCalc and ZFlipCalc. The
                if QCData.XFlipCalc(segnum) == -1 && QCData.ZFlipCalc(segnum)== -1
                    Orientation=4; % both flipped and rotated
                elseif QCData.XFlipCalc(segnum) == -1 && QCData.ZFlipCalc(segnum)== 1
                    Orientation=3; % Rotated
                elseif QCData.XFlipCalc(segnum) == 1 && QCData.ZFlipCalc(segnum)== -1
                    Orientation=2; % flipped
                else
                    Orientation=1; % no flip or rotation
                end
                
                %Find the indices corresponding to the 4h period in Acc matrix
                SgtSmplPts=smpls1S(QCData.ElapsedSecs(segnum)):smpls1S(QCData.ElapsedSecs(segnum+1))-1;
                % call ChangeAxes function to change the orientation
                Acc(SgtSmplPts,2:4) = ChangeAxes(Acc(SgtSmplPts,2:4),devType,Orientation);
            end
        end
    end
    
    %% Final stage of QC-module 
    % if exMode is Warn or off assume default flips/rotations
    if ~strcmpi(exMode,'Force')
        
        % derive orientation form defOrientation (1=[0,0], 2=[0,1],3=[1,0], 4=[1,1]
        Orientation=2*defOrientation(1)+defOrientation(2)+1; 
        % call ChangeAxes function to change the orientation
        Acc(:,2:4) = ChangeAxes(Acc(:,2:4),devType,Orientation);
    end
    
    % if everything is fine set the status flag
    status='OK';
catch ME
    % if an exception occur and exMode is force assume default orientation
    % and correct Acc data s.t. activity detection works
    if ~strcmpi(status,'OK')
        % derive orientation form defOrientation (1=[0,0], 2=[0,1],3=[1,0], 4=[1,1]
        Orientation=2*defOrientation(1)+defOrientation(2)+1; 
        % call ChangeAxes function to change the orientation
        Acc(:,2:4) = ChangeAxes(Acc(:,2:4),devType,Orientation);
    end
    status="QC Module crashed";
    % add detailed exception message to warnings vector
    warnings=[warnings,getReport(ME,'extended','hyperlinks','off')]; % merge any warning with main warnings vector
end

end
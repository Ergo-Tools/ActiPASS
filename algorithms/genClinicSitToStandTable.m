function status = genClinicSitToStandTable(projectDir,outDir,AP_MQCT,Params,uiPgDlg,exclusions)
%GENSITTOSTANDTABLE generate sit-to-stand transition table for currently loaded project

% INPUTS
% projectDir [string]: Actipass project folder
% outDir [string]: Output directory
% AP_MQCT [table]: Actipass master QC table
% Params [struct]: STS peak detection parameters
%            Params.prom - min prominence of peaks
%            Params.width - min width 
%            Params.sep - min seperation
% exclusions [string, optional]: files left out by QC_Status: "Check+NotOK" (default, only
%   OK files, as before), "NotOK" or "None" (all files)
% Fs [double]: resampling frequency used in Actipass while processing data

% OUTPUT
% status [string]: "OK": everything went well, "Check": only some files processed,  "Error": none of the files processed


% Copyright (c) 2024, Pasan Hettiarachchi
% pasan.hettiarachchi@medsci.uu.se
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

% figure width and height
figW=1280;
figH=720;

% Clinical sit-to-stand-test time-window w.r.t. trimStart time given by Actipass QC table
TestEndBuf=3; % default is four hours
TestStartBuf=3; % default is one  hours

%resample frequency
Fs=25;

% create a butterwotrth filter of given order for filtering raw acc data
fc_lp=2; % low-pass filter-cutoff
filt_order=4; % low-pass filter-order
[B_LP,A_LP] = butter(filt_order,fc_lp/(Fs/2)); %  given order low pass filter at given cut-off frequency

% define variable names and types in the output tables
varN_SS=["SubjectID","test_start","test_end","STS_counts","Median_Angle_Change","Error_Flags"];
varT_SS=["string","string","string","double","double","string"];


% leave out files by their QC_Status (default: all but OK files, as before)
if nargin<6 || isempty(exclusions), exclusions="Check+NotOK"; end
if exclusions=="Check+NotOK"
    AP_MQCT(AP_MQCT.QC_Status~="OK",:)=[]; % delete cases where QC_Status is not OK
elseif exclusions=="NotOK"
    AP_MQCT(AP_MQCT.QC_Status=="NotOK",:)=[];
elseif exclusions~="None"
    error("exclusions must be None, NotOK or Check+NotOK");
end

% detect orientation changes during measurement
pcnt_rot=str2double(extractAfter(AP_MQCT.("TimeRot(h,%)"),",")); % percentage_rotated
pcnt_flp=str2double(extractAfter(AP_MQCT.("TimeFlip(h,%)"),",")); % percentage_rotated

% consider rotations and flips which are closer to 100 or 0
pcnt_rot(pcnt_rot>=90)=100;
pcnt_rot(pcnt_rot<=10)=0;
pcnt_flp(pcnt_flp>=90)=100;
pcnt_flp(pcnt_flp<=10)=0;


% files with a 90 degree rotation correction cannot be reproduced from the QC table (QC tables from older
% versions have no TimeRot90 column; there the 90 degree time was part of TimeRot)
if ismember("TimeRot90(h,%)",AP_MQCT.Properties.VariableNames)
    rot90=str2double(extractBefore(AP_MQCT.("TimeRot90(h,%)"),","))>0;
else
    rot90=false(height(AP_MQCT),1);
end

% only select cases where orinetation doesn't change during the measurement (and without 90 degree rotation)
slct=ismember(pcnt_rot,[0,100]) & ismember(pcnt_flp,[0,100]) & ~rot90;
pcnt_rot=pcnt_rot(slct);
pcnt_flp=pcnt_flp(slct);

% delete rows with partially rotated or flipped data
AP_MQCT(~slct,:)=[];

% we are going to derive final orientation based on rotated and flipped data
pcnt_rot(pcnt_rot==100)=1; % set 100% value to 1 (just to be a nice logical flag)
pcnt_flp(pcnt_flp==100)=1; % set 100% value to 1 (just to be a nice logical flag)

% set the final orinetation flag to be used for raw-data transformation
Orientation=pcnt_rot*2+pcnt_flp+1; % orientation value (default=1, flipped=2, rotated=3, both flipped and rotated=4)


% table to hold summary data for each transition for all participants
SiStFnl_T=table('Size',[height(AP_MQCT),length(varN_SS)],'VariableNames',varN_SS,'VariableTypes',varT_SS);

%count non problamatic files
doneFs=0;

% iterate through files
for itrFil=1:height(AP_MQCT)
    try
        % check for cancelation
        if uiPgDlg.CancelRequested
            status="Cancelled";
            return;
        end

        % find the ID of this person
        subjctID=AP_MQCT.SubjectID(itrFil);
        SiStFnl_T.SubjectID(itrFil)=subjctID; % also for files that fail below

        % location of per-second-table
        perSecF=fullfile(projectDir,"IndividualOut",subjctID,subjctID+" - Activity_per_s.mat");

        % update progress dialog
        uiPgDlg.Value=(itrFil-1)/height(AP_MQCT)+(1/height(AP_MQCT))*0.1;
        uiPgDlg.Message="Processing: ID: "+subjctID+". File "+itrFil+" of "+height(AP_MQCT)+"..";

        % load data from mat file
        perSOBJ = load(perSecF,'-mat');
        perSecT=perSOBJ.aktTbl;

        t_First_StandMove=datetime(perSecT.DateTime(find(perSecT.Activity==3 | perSecT.Activity==4,1,"first")),"ConvertFrom","datenum");

        % try to find matching raw acc data file
        Acc_f=AP_MQCT.FilePath(itrFil);

        % if file cannot be found continue to next file
        if ~isfile(Acc_f)
            msgTxt="file: "+AP_MQCT.Filename(itrFil)+ " not found";
            SiStFnl_T.Error_Flags(itrFil)=msgTxt;
            continue;
        end

        % find acc file extension
        [~,Acc_fn,ext]=fileparts(Acc_f);


        %find trimStart time from QC table
        % trimStart=datetime(AP_MQCT.trimStart(itrFil));

        %load raw accelerometer data CWA format
        if strcmpi(ext,".cwa")
            try
                accInfo = CWA_readFile(Acc_f, 'info', 1,'useC', 1);
                % AX3_readfile returns data in a shorter range than requested
                % Adjust start and end times before calling AX3_readfile

                % load max TestEnd hours from trimStart
                accInfo.stop.mtime=min(accInfo.stop.mtime,datenum(t_First_StandMove)+TestEndBuf/24);

                accInfo.start.mtime=max(accInfo.start.mtime,datenum(t_First_StandMove)-TestStartBuf/24);

                dataTH = CWA_readFile(Acc_f,'packetInfo', accInfo.packetInfo,'startTime', accInfo.start.mtime, ...
                    'stopTime', accInfo.stop.mtime, 'useC', 1);
                %  Remove any duplicate timestamps
                dataTH.AXES = dataTH.AXES(diff(dataTH.AXES(:,1))>0,:);

                % time as datetime
                t_orig=datetime(dataTH.AXES(:,1),'ConvertFrom','datenum');

                % fix start and end to interger second time of mtStart and mtEnd.
                % Also make sure mtStart and mtEnd lies within the returned data
                mtStart = dateshift(t_orig(1),"end","second");
                mtEnd = dateshift(t_orig(end),"start","second");

                % create evenly spaced time axis at given samplerate
                t = linspace(mtStart,mtEnd,seconds((mtEnd-mtStart))*Fs);

                % interpolate Acc. data at evenly spaced samples
                % Axivity ProPASS default orientations are different from Acti4 default orientation therefor we need to inverse y and z axes
                % we do this together with interpolating data
                Dintp=zeros(length(t),3);
                for j=1:3

                    if j==1
                        Dintp(:,j) = interp1(t_orig,dataTH.AXES(:,j+1),t,'pchip',0); %data.ACC must be double if 'cubic' is selected
                    else
                        Dintp(:,j) = -interp1(t_orig,dataTH.AXES(:,j+1),t,'pchip',0); %data.ACC must be double if 'cubic' is selected
                    end

                end
                DOut.t=t;
                DOut.Acc=Dintp;
                % clear big temperorary variables
                %accInfo.validPackets=[];
                accInfo.packetInfo=[];
                clear t Dintp t_orig dataTH
            catch AX3ME
                SiStFnl_T.Error_Flags(itrFil)="Error reading file: "+Acc_fn;
                continue;
            end

            % load raw accelerometer data CSV format  (assume csv files are ActivPAL files, ToDo: handle ActiGraph files)
        elseif strcmpi(ext,".csv")
            try
                % call ActivPAL import function
                [activPALData,~,~,~] = readActivPALcsv(Acc_f);

                % time as datetime
                t_orig=datetime(activPALData(:,1),'ConvertFrom','datenum');

                % only consider first TestEndBuf hours
                t_activPAL_end=min(t_orig(end),t_First_StandMove+hours(TestEndBuf));
                t_activPAL_start=max(t_orig(1),t_First_StandMove-hours(TestStartBuf));

                % fix start and end to interger second time of mtStart and mtEnd.
                % Also make sure mtStart and mtEnd lies within the returned data
                mtStart = dateshift(t_activPAL_start,"end","second");
                mtEnd = dateshift(t_activPAL_end,"start","second");

                % create evenly spaced time axis at given samplerate
                t = linspace(mtStart,mtEnd,seconds((mtEnd-mtStart))*Fs);

                % interpolate Acc. data at evenly spaced samples
                Dintp=zeros(length(t),3);
                for j=1:3
                    Dintp(:,j) = interp1(t_orig,activPALData(:,j+1),t,'pchip',0); %data.ACC must be double if 'cubic' is selected
                end
                DOut.t=t;
                DOut.Acc=Dintp;

                % clear big temperorary variables
                clear t Dintp activPALData t_orig

            catch CSVME

                SiStFnl_T.Error_Flags(itrFil)="Error reading file: "+Acc_fn;
                continue;
            end
        else
            SiStFnl_T.Error_Flags(itrFil)="file: "+Acc_fn+ " not supported";
            continue;
        end
        % check for cancelation
        if uiPgDlg.CancelRequested
            status="Cancelled";
            return;
        end

        % change raw-accelerometer data based on orientation
        DOut.Acc = ChangeAxes(DOut.Acc,"Axivity",Orientation(itrFil));


        %% Clinical Sit to Stand

        % assign the ID column
        SiStFnl_T.SubjectID(itrFil)=subjctID;

        % a figure for individual transition speed curves
        fig=figure('Name',"clinical_sit_to_stand_counts for ID: "+subjctID,'Visible','off','units','pixels','position',[0 0 figW figH]);


        % update progress dialog
        uiPgDlg.Value=(itrFil-1)/height(AP_MQCT)+(1/height(AP_MQCT))*0.5;
        uiPgDlg.Message="Processing: ID: "+subjctID+". File "+itrFil+" of "+height(AP_MQCT);


        % filter the segment of using a low pass butterworth filter
        filtAcc = filtfilt(B_LP,A_LP, DOut.Acc);

        % calculate the angle w.r.t. x-axis using inverse cosine
        vmAcc = sqrt(filtAcc(:,1).^2 + filtAcc(:,2).^2 + filtAcc(:,3).^2); % first find vector magnitude
        % inverse cosines do not have a discontinuity compared to inverse tangents
        angle = acosd(filtAcc(:,1)./vmAcc);

        % recalculate angle such that we find peaks when people stand
        angle=180-angle;

        % intialize a matrix to hold i-minute window peaks details
        pksInfo=zeros(length(angle)/Fs-60,4);

        % iterate the angle vector with one second increments and 60sec window size
        for itrSec=1:(size(pksInfo,1)-1)
            segStart=(itrSec-1)*Fs+1;
            segEnd=(itrSec-1)*Fs+Fs*60;
            [~,~,w,p] = findpeaks(angle(segStart:segEnd),Fs,MinPeakProminence=Params.prom,MinPeakDistance=Params.sep,MinPeakWidth=Params.width);
            pksInfo(itrSec,1)=segStart;
            pksInfo(itrSec,2)=length(w);
            pksInfo(itrSec,3)=median(w);
            pksInfo(itrSec,4)=median(p);
        end

        % check for cancelation
        if uiPgDlg.CancelRequested
            status="Cancelled";
            return;
        end

        % find the location of maximum number of peaks
        % preSelect=find(pksInfo(:,4)>45 & pksInfo(:,4)>0.2);
        [maxPks,maxInd]=max(pksInfo(:,2));
        % find the actual max-index after pre-selection
        % maxInd=preSelect(maxInd);

        if maxPks>10 &&  maxPks<60
            % recalculate the peaks for exact timing and details (with +/- 5 seconds extra buffer)
            segStart=pksInfo(maxInd,1)-Fs*5;
            segEnd=pksInfo(maxInd,1)+Fs*65;
            angleSel=angle(segStart:segEnd);
            [pks,locs] = findpeaks(angleSel,Fs,MinPeakProminence=Params.prom,MinPeakDistance=Params.sep,MinPeakWidth=Params.width);
            % convert locs to actual datetime value
            locs=DOut.t(segStart)+seconds(locs);
            % find the  valleys
            locsV=find(islocalmin(angleSel,"MinProminence",Params.prom));
            botms=angleSel(locsV);
            % medianBottomLevel=median(botms);
            locsV=DOut.t(segStart)+seconds(locsV/Fs);

            %define lower and upper valuesfor sliding windows of 1minute with 0.1s increments
            lowerVls=DOut.t(segStart)+seconds(0:0.1:10);
            upperVls=DOut.t(segStart)+seconds(60:0.1:70);

            %find maximum peaks we can find within 1min window by sliding a window in 0.1s increments 
            sumPeaks=sum(isbetween(locs,lowerVls,upperVls,"open"),1);
            numPks1min=max(sumPeaks);
            indPks1min=round(median(find(sumPeaks==numPks1min)));
            
            %find maximum valleys we can find within 1min window by sliding a window in 0.1s increments
            % sumValleys=sum(isbetween(locsV,lowerVls,upperVls,"open"),1);
            % numVls1min=max(sumValleys);
            % indVls1min=round(median(find(sumValleys==numVls1min)));

            plot(DOut.t(segStart:segEnd),angleSel,locs,pks,'o',locsV,botms,'r*');
            hold on;
            startTest=lowerVls(indPks1min);
            endTest=lowerVls(indPks1min)+seconds(60);
            xline([startTest,endTest],"-",[string(startTest,"HH:mm:ss.S"),string(endTest,"HH:mm:ss.S")]);

            % fill the table with STS data
            SiStFnl_T.test_start(itrFil)=string(startTest,"yyyy-MM-dd HH:mm:ss.S");
            SiStFnl_T.test_end(itrFil)=string(endTest,"yyyy-MM-dd HH:mm:ss.S");
            SiStFnl_T.STS_counts(itrFil)=numPks1min;
            SiStFnl_T.Median_Angle_Change(itrFil)=pksInfo(maxInd,4);

            SiStFnl_T.Error_Flags(itrFil)="none";
        else
            SiStFnl_T.Error_Flags(itrFil)="not-found. pksInfo(maxInd): "+ num2str(pksInfo(maxInd,2:end));
        end

        % set x/y labels
        xlabel("Time");
        ylabel("Angle (deg)")
        %save and close superimposed figure
        exportgraphics(fig,fullfile(outDir,subjctID+" - Sit_to_stand_clinical_test.png"));
        close(fig);

        doneFs=doneFs+1;
    catch ME
        % if there are errors still continue
        msgTxt=getReport(ME,'extended','hyperlinks','off');
        SiStFnl_T.Error_Flags(itrFil)=msgTxt;
        continue;
    end
end


% write all transitions data to the sit-to-stand master-file
writetable(SiStFnl_T,fullfile(outDir,"Clinical_sit_to_stand_data.xlsx"),"WriteMode","replacefile");
% update the status field
if doneFs==height(AP_MQCT)
    status="OK";
elseif doneFs>=1
    status="Check";
elseif doneFs==0
    status="Error";
end

end


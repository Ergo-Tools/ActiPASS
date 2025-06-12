function status = genSitToStandTable(projectDir,outDir,AP_MQCT,Fs,AX_Orient,filt_mode,cal_mode,uiPgDlg)
%GENSITTOSTANDTABLE generate sit-to-stand transition table for currently loaded project

% INPUTS
% projectDir [string]: ActiPASS project folder
% outDir [string]: Output directory
% AP_MQCT [table]: ActiPASS master QC table
% AX_Orient [string]: New or old orientation defaults (because ActiPASS changed default orientations fall 2023)
% filt_mode [string]: filtering mode ("Pickford or Löppönen)
% cal_mode [string]: specify whch upright activities considered as "Stand" in sit-to-stand
% Fs [double]: resampling frequency used in ActiPASS while processing data
% uiPgDlg: a handle to UI-progress-dialog to show updates

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


% minimum transition interval (to avoid too-small transitions)
tmin_Trns=5/Fs; % five sample intervals

if strcmpi(filt_mode,"Löppönen")
    % create a butterwotrth filter of given order for filtering raw acc data
    fc_lp=1; % low-pass filter-cutoff
    filt_order=4; % low-pass filter-order
    [B_LP,A_LP] = butter(filt_order,fc_lp/(Fs/2)); %  given order low pass filter at given cut-off frequency
    
    % create another butterwotrth filter of given order for further filtering angle data
    fc_lp2=10; % filter cutoff
    filt_order2=4; % filter order
    [B_LP2,A_LP2] = butter(filt_order2,fc_lp2/(Fs/2)); %  given order low pass filter at given cut-off frequency
    
elseif strcmpi(filt_mode,"Pickford")
    % create a butterwotrth filter of given order for filtering raw acc data
    fc_lp=0.18; % low-pass filter-cutoff
    filt_order=1; % low-pass filter-order
    [B_LP,A_LP] = butter(filt_order,fc_lp/(Fs/2)); %  given order low pass filter at given cut-off frequency
end

% define variable names and types in the output tables
varN_SS=["SubjectID","t_transit","ang_spd_mean","ang_spd_peak","ft","lt","ut","pt","ll","ul"];
varT_SS=["string","string",repmat("double",1,length(varN_SS)-2)];

% create a table to record processing log 
varNLog=["DateTime","Process_Time","processing_status"];
ProcLogT=[AP_MQCT(:,"SubjectID"),table('size',[height(AP_MQCT),3],'VariableTypes',repmat("string",1,3),'VariableNames',varNLog)];

% if QC_Status is not "OK" skip this file from stat generation
indsNotOk=find(AP_MQCT.QC_Status~="OK");
indsOk=find(AP_MQCT.QC_Status=="OK");
AP_MQCT(indsNotOk,:)=[]; % delete cases where QC_Status is not OK
% log deleted cases to the ProcLogT table
ProcLogT{indsNotOk,2:end}=repmat([string(datetime("now")),"0.0","QC_Status is not ""OK"""],size(indsNotOk));

% detect orientation changes during measurement
pcnt_rot=str2double(extractAfter(AP_MQCT.("TimeRot(h,%)"),",")); % percentage_rotated
pcnt_flp=str2double(extractAfter(AP_MQCT.("TimeFlip(h,%)"),",")); % percentage_rotated

% only select cases where orinetation doesn't change during the measurement
slct=ismember(pcnt_rot,[0,100]) & ismember(pcnt_flp,[0,100]);
pcnt_rot=pcnt_rot(slct);
pcnt_flp=pcnt_flp(slct);

% delete rows with partially rotated or flipped data
AP_MQCT(~slct,:)=[];
% log deleted cases to the ProcLogT table
ProcLogT{indsOk(~slct),2:end}=repmat([string(datetime("now")),"0.0","Orientation change during measurements"],size(indsOk(~slct)));
indsOk=indsOk(slct);

% we are going to derive final orientation based on rotated and flipped data
pcnt_rot(pcnt_rot==100)=1; % set 100% value to 1 (just to be a nice logical flag)
pcnt_flp(pcnt_flp==100)=1; % set 100% value to 1 (just to be a nice logical flag)

% set the final orinetation flag to be used for raw-data transformation
Orientation=pcnt_rot*2+pcnt_flp+1; % orientation value (default=1, flipped=2, rotated=3, both flipped and rotated=4)


% table to hold summary data for each transition for all participants
SiStFnl_T=table('Size',[0,length(varN_SS)],'VariableNames',varN_SS,'VariableTypes',varT_SS);

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
        tic;
        % find the ID of this person
        subjctID=AP_MQCT.SubjectID(itrFil);
        
        % location of per-second-table
        perSecF=fullfile(projectDir,"IndividualOut",subjctID,subjctID+" - Activity_per_s.mat");
        
        % update progress dialog
        uiPgDlg.Value=(itrFil-1)/height(AP_MQCT)+(1/height(AP_MQCT))*0.1;
        uiPgDlg.Message="Processing: ID: "+subjctID+". File "+itrFil+" of "+height(AP_MQCT)+"..";
        
        % load data from mat file
        perSOBJ = load(perSecF,'-mat');
        perSecT=perSOBJ.aktTbl;
        
        % if use_move flag is set
        if strcmpi(cal_mode,"upright")
            indsStand=find(perSecT.Activity==3 | perSecT.Activity==4 | perSecT.Activity==6); % indices of stand, move and run
        elseif strcmpi(cal_mode,"standmove")
            indsStand=find(perSecT.Activity==3 | perSecT.Activity==4); % indices of both stand and move
        elseif strcmpi(cal_mode,"stand")
            indsStand=find(perSecT.Activity==3); % indices of stand
        end
        
        indsSit=find(perSecT.Activity==2);  % indices of sit
        
        % transistions of sit-to-stand or move
        indsSitToStand=indsSit(ismember(indsSit+1,indsStand));
        
        % try to find matching raw acc data file
        Acc_f=AP_MQCT.FilePath(itrFil);
        
        % if file cannot be found continue to next file
        if ~isfile(Acc_f)
            msgTxt="file: "+AP_MQCT.Filename(itrFil)+ " not found";
            ProcLogT.processing_status(indsOk(itrFil))=msgTxt;
            ProcLogT{indsOk(itrFil),2:end}=[string(datetime("now")),string(toc),msgTxt];
            continue;
        end
        % find acc file extension
        [~,Acc_fn,ext]=fileparts(Acc_f);
        
        %load raw accelerometer data CWA format
        if strcmpi(ext,".cwa")
            try
                accInfo = CWA_readFile(Acc_f, 'info', 1,'useC', 1);
                % AX3_readfile returns data in a shorter range than requested
                % Adjust start and end times before calling AX3_readfile
                
                dataTH = CWA_readFile(Acc_f,'packetInfo', accInfo.packetInfo,'startTime', accInfo.start.mtime, ...
                    'stopTime', accInfo.stop.mtime, 'useC', 1);
                %  Remove any duplicate timestamps
                dataTH.AXES = dataTH.AXES(diff(dataTH.AXES(:,1))>0,:);
                
                % fix start and end to interger second time of mtStart and mtEnd.
                % Also make sure mtStart and mtEnd lies within the returned data
                mtStart = round(dataTH.AXES(1,1)*86400)/86400;
                mtEnd = round(dataTH.AXES(end,1)*86400)/86400;
                
                % create evenly spaced time axis at given samplerate
                t = linspace(mtStart,mtEnd,(mtEnd-mtStart)*86400*Fs+1);
                
                % interpolate Acc. data at evenly spaced samples
                % Axivity ProPASS default orientations are different from Acti4 default orientation therefor we need to inverse y and z axes
                % we do this together with interpolating data
                Dintp=zeros(length(t),4);
                for j=2:4
                    if strcmpi(AX_Orient,"New")
                        if j==2
                            Dintp(:,j) = interp1(dataTH.AXES(:,1),dataTH.AXES(:,j),t,'pchip',0); %data.ACC must be double if 'cubic' is selected
                        else
                            Dintp(:,j) = -interp1(dataTH.AXES(:,1),dataTH.AXES(:,j),t,'pchip',0); %data.ACC must be double if 'cubic' is selected
                        end
                    elseif strcmpi(AX_Orient,"Old")
                        Dintp(:,j) = interp1(dataTH.AXES(:,1),dataTH.AXES(:,j),t,'pchip',0); %data.ACC must be double if 'cubic' is selected
                    end
                end
                Dintp(:,1)=t;
                dataTH.AXES=Dintp;
                % clear big temperorary variables
                %accInfo.validPackets=[];
                accInfo.packetInfo=[];
                clear t Dintp
            catch AX3ME
                ProcLogT{indsOk(itrFil),2:end}=[string(datetime("now")),string(toc),"Error reading file: "+Acc_fn];
                continue;
            end
            
            % load raw accelerometer data CSV format  (assume csv files are ActivPAL files, ToDo: handle ActiGraph files)
        elseif strcmpi(ext,".csv")
            try
                % call ActivPAL import function
                [activPALData,~,~,~] = readActivPALcsv(Acc_f);
                % time axis of ActivPAL raw data
                time_activPAL=activPALData(:,1);
                
                % fix start and end to interger second time of mtStart and mtEnd.
                % Also make sure mtStart and mtEnd lies within the returned data
                mtStart = round(time_activPAL(1)*86400)/86400;
                mtEnd = round(time_activPAL(end)*86400)/86400;
                
                % create evenly spaced time axis at given samplerate
                t = linspace(mtStart,mtEnd,(mtEnd-mtStart)*86400*Fs+1);
                
                % interpolate Acc. data at evenly spaced samples
                Dintp=zeros(length(t),4);
                for j=2:4
                    Dintp(:,j) = interp1(time_activPAL,activPALData(:,j),t,'pchip',0); %data.ACC must be double if 'cubic' is selected
                end
                Dintp(:,1)=t;
                dataTH.AXES=Dintp;
                
                % clear big temperorary variables
                clear t Dintp activPALData time_activPAL
                
            catch CSVME
                
                ProcLogT{indsOk(itrFil),2:end}=[string(datetime("now")),string(toc),"Error reading file: "+Acc_fn];
                continue;
            end
        else
            ProcLogT{indsOk(itrFil),2:end}=[string(datetime("now")),string(toc),"file: "+Acc_fn+ " not supported"];
            continue;
        end
        % check for cancelation
        if uiPgDlg.CancelRequested
            status="Cancelled";
            return;
        end
        
        % change raw-accelerometer data based on orientation
        dataTH.AXES(:,2:4) = ChangeAxes(dataTH.AXES(:,2:4),"Axivity",Orientation(itrFil));
        
        % create a directory to save sit-to-stand speed data
        dirSS=fullfile(outDir,subjctID);
        % create the subdirectory with ID
        if ~isfolder(dirSS)
            mkdir(dirSS);
        end
        
        %% Sit to Stand
        
        % table to hold summary data for each transition
        SiSt_T=table('Size',[length(indsSitToStand),length(varN_SS)],'VariableNames',varN_SS,'VariableTypes',varT_SS);
        % pre-assign the ID column
        SiSt_T.SubjectID=repmat(subjctID, length(indsSitToStand), 1);
        % a figure for individual transition speed curves
        fig=figure('Name',"sit_to_stand speed for ID: "+subjctID,'Visible','off');
        
        % the matrix to hold sit-stand time series for all transitions
        sit_stand_data=zeros(length(indsSitToStand),Fs*6);
        
        for itrTrns=1:length(indsSitToStand)
            % update progress dialog
            uiPgDlg.Value=(itrFil-1)/height(AP_MQCT)+(1/height(AP_MQCT))*((itrTrns-1)/(2*length(indsSitToStand)));
            uiPgDlg.Message="Processing: ID: "+subjctID+". File "+itrFil+" of "+height(AP_MQCT)+" transition: "+itrTrns;
            indTrans=find(dataTH.AXES(:,1)>=perSecT.DateTime(indsSitToStand(itrTrns)),1,'first');
            indAccStart=indTrans-Fs*3; % 3 seconds backward from time of transition
            indAccEnd=indTrans+Fs*3; % 3 seconds forward from the time of transition
            
            %derive the time axis
            timeAx=((indAccStart:indAccEnd)-indTrans)/Fs;
            
            % filter the segment of using a low pass butterworth filter
            filtAcc = filtfilt(B_LP,A_LP, dataTH.AXES(indAccStart:indAccEnd,2:4));
            
            % calculate the angle w.r.t. x-axis using inverse cosine
            vmAcc = sqrt(filtAcc(:,1).^2 + filtAcc(:,2).^2 + filtAcc(:,3).^2); % first find vector magnitude
            % inverse cosines do not have a discontinuity compared to inverse tangents
            angle = acosd(filtAcc(:,1)./vmAcc);
            
            if strcmpi(filt_mode,"Löppönen")
                % further smooth the angle signal
                angle = filtfilt(B_LP2,A_LP2, angle);
            end
            
            %plot the inclination angle
            plot(timeAx,angle);
            hold on;
            
            % calculate the speed by dividing difference of adjacent values by sampling interval
            ang_speed=-diff(angle)*Fs; % angle is going down, therefore negate it for speed calculation
            
            %update sit_stand_matrix
            sit_stand_data(itrTrns,:)=ang_speed;
            
            % calculate fall-time (for sit-to-stand transitions angle decreases)
            [ft,lt,ut,ll,ul] = falltime(angle,timeAx);
            
            %update the table
            SiSt_T.t_transit(itrTrns)=datestr(perSecT.DateTime(indsSitToStand(itrTrns)),31); % transition time in ISO format
            
            % if only one falltime with least tmin_Trns long
            if ~isempty(ft) && isscalar(ft) && (lt-ut)> tmin_Trns
                %find the indices of upper and lower times
                ind_ut=find(timeAx>=ut,1,'first');
                ind_lt=find(timeAx>=lt,1,'first');
                % in case ind_lt is at the end consider the index before that
                if ind_lt==length(timeAx)
                    ind_lt=length(timeAx)-1;
                end
                SiSt_T.ang_spd_mean(itrTrns)=(1/ft)*(ul-ll); % mean angular speed within the transition
                % peak angular speed within the transition
                [SiSt_T.ang_spd_peak(itrTrns),pi]=max(ang_speed(ind_ut:ind_lt));
                % save pt, ft, lt, ut, ll and ul to SiST table
                SiSt_T.pt(itrTrns)=timeAx(ind_ut+pi-1);
                SiSt_T.ft(itrTrns)=ft;
                SiSt_T.lt(itrTrns)=lt;
                SiSt_T.ut(itrTrns)=ut;
                SiSt_T.ll(itrTrns)=ll;
                SiSt_T.ul(itrTrns)=ul;
            end
            
            % check for cancelation
            if uiPgDlg.CancelRequested
                status="Cancelled";
                return;
            end
        end
        % set x/y labels
        xlabel("Time (s)");
        ylabel("Angle (deg)")
        %save and close superimposed figure
        exportgraphics(fig,fullfile(dirSS,subjctID+" - Sit_to_stand_angle.png"));
        close(fig);
        
        
        % now plot merged data figure
        figMGD=figure('Name',"merged_sit_to_stand speed for ID: "+subjctID,'Visible','off');
        timeAx=(-Fs*3:(Fs*3-1))/Fs;  % create time axis centered around 0s (range: -3s to +3s)
        
        % only select valid sit_stand transitions (where a rise-time can be found)
        valid_sit_stand= sit_stand_data(SiSt_T.ft~=0,:);
        
        mean_si_st=mean(valid_sit_stand,1)'; % mean taken at each sample point for all transitions
        std_si_st=std(valid_sit_stand,0,1)'; % std taken at each sample point for all transitions
        
        % plot a figure of merged speed curves without time alignment
        plot(timeAx,mean_si_st,'-k');
        hold on;
        plot(timeAx,mean_si_st+std_si_st,'--b');
        plot(timeAx,mean_si_st-std_si_st,'--b');
        xlabel("Time (s)");
        ylabel("Angl_spd (deg/s)");
        exportgraphics(figMGD,fullfile(dirSS,subjctID+" - Sit_to_Stand_merged_speeds.png"));
        close(figMGD);
        
        % save individual transition data
        writetable(SiSt_T,fullfile(dirSS,subjctID+" - Sit_to_stand_speeds_and_falltimes.xlsx"));
        
        % concatenate transition data
        SiStFnl_T=[SiStFnl_T;SiSt_T];
        
        % save sit_stand full data matrix
        writematrix(sit_stand_data,fullfile(dirSS,subjctID+" - Sit_to_stand_speed_all_transitions.csv"));
        % save sit-stand instantaneous sit-stand speeds for all transitions
        
        % update processing error table
        ProcLogT{indsOk(itrFil),2:end}=[string(datetime("now")),string(toc),"OK"];
        doneFs=doneFs+1;
    catch ME
        % if there are errors still continue
        msgTxt=getReport(ME,'extended','hyperlinks','off');
        ProcLogT{indsOk(itrFil),2:end}=[string(datetime("now")),string(toc),msgTxt];
        continue;
    end
end

% write any errors during processing to disk
writetable(ProcLogT,fullfile(outDir,"Processing log and errors.xlsx"),'WriteMode','replacefile');

% write all transitions data to the sit-to-stand master-file
writetable(SiStFnl_T,fullfile(outDir,"Merged_data_sit_to_"+cal_mode+"_"+filt_mode+".csv"));
% update the status field
if doneFs==height(AP_MQCT)
    status="OK";
elseif doneFs>=1
    status="Check";
elseif doneFs==0
    status="Error";
end

end


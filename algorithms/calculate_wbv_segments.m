function status = calculate_wbv_segments(AP_folder,output_file,exclusions,uiPgDlg,rawDir)

%calculate_wbv_segments Predict WBV exposure for sitting segments

% INPUTS
% AP_folder [string]: Actipass project folder
% output_file [string]: Output table full-path
% exclusions [string]: None, NotOK or Check+NotOK
% UI progress dialog to be updated
% rawDir [string, optional]: folder with the raw accelerometer files, for older projects
%   whose master QC table has no FilePath column

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

finalOutT=[]; % empty table to accumulate WBV metrics
d2s = 24*3600; %datenum to seconds conversion
grvtK=9.821; % gravitational constant
min_sit_dur=60; % minimum sitting duration needed for WBV calculation

% iso2631 per axis weights for total vibration dose calculation
kx=1.4;
ky=1.4;
kz=1;

%dynamic range settings for saturation detection
% saturation value of AX3 for 10-bit resolution with 2LSB margin is:
% for 8g dynamic range: +7.953g (and -7.968g)
% for 16g dynamic range +15.906g (and -15.937g)
dRange_AXS=15.9; % absolute value for 16g range
dRange_AXT=7.95; % absolute value for 8g range

% the WBV variables we are interested in
WBV_basevars=["WBV_AV_probability","WBV_AV_prediction","WBV_A8_probability","WBV_A8_prediction", ...
    "aw_x","aw_y","aw_z","av","VDV_x","VDV_y","VDV_z", "CF_x", "CF_y", "CF_z","tx_sat","ty_sat","tz_sat"];
Dev_prefixes="AXT_";
WBV_vars=reshape(append(Dev_prefixes,WBV_basevars).',1,[]);

%% Load Actipass QC table
AP_QC_f=fullfile(AP_folder,"Actipass_QC_MasterFile.xlsx"); % exact case: file names are case sensitive on Linux/macOS
qcOpts=detectImportOptions(AP_QC_f);
qcOpts.VariableTypes(strcmp(qcOpts.VariableTypes,'char'))={'string'}; % text as string (was TextType)
% IDs and file names as text (numeric-looking IDs would otherwise be read as numbers)
qcOpts=setvartype(qcOpts,intersect(["SubjectID","Filename","FilePath"],qcOpts.VariableNames,'stable'),"string");
AP_QC_T=readtable(AP_QC_f,qcOpts);
% older projects: no FilePath column; the raw data files are in rawDir
if ~ismember("FilePath",AP_QC_T.Properties.VariableNames)
    if nargin>=5 && ~isempty(rawDir) && isfolder(rawDir)
        AP_QC_T.FilePath=fullfile(string(rawDir),AP_QC_T.Filename);
    else
        error("The master QC table has no file paths (older project): give the folder with the raw accelerometer files (rawDir).");
    end
end

if exclusions=="NotOK"
    %select only QC_Status~= NotOK
    AP_QC_T=AP_QC_T(AP_QC_T.QC_Status~="NotOK",:);
elseif exclusions=="Check+NotOK"
    %select only QC_Statu s== OK
    AP_QC_T=AP_QC_T(AP_QC_T.QC_Status=="OK",:);
else 
    
end

% keep track of files processed without errors
doneFs=0;

% iterate through thigh accelerometer files
for itrFs=1:height(AP_QC_T)

    %% check for cancelation
    if uiPgDlg.CancelRequested
        status="Cancelled";
        return;
    end


    %% Load time periods for each sitting_segments


    fprintf('Processing file %d of %d...\r', itrFs, height(AP_QC_T));

    % sitting segment file from transportation detection which are larger than 5-min
    f_sitsegs=fullfile(AP_folder,"IndividualOut",AP_QC_T.SubjectID(itrFs),AP_QC_T.SubjectID(itrFs)+" - seated_segments.csv");

    if ~isfile (f_sitsegs)
         error("Unable to locate seated_segemets.csv file(s) inside IndividualOut folders(s). Turn on ""Transport detection"" in advanced settings and reprocess");
    end
    sitsegTblOpt=detectImportOptions(f_sitsegs);
    sitsegTblOpt.VariableTypes=["datetime","datetime","string","double","double","double","double","double"];
    sitsegTblOpt.PreserveVariableNames=true;
    sitsegTbl=readtable(f_sitsegs,sitsegTblOpt);

    % find all sitting segments from 1-sec time series from binary mat file
    perSecF=fullfile(AP_folder,"IndividualOut",AP_QC_T.SubjectID(itrFs),AP_QC_T.SubjectID(itrFs)+" - Activity_per_s.mat");

    perSOBJ = load(perSecF,'-mat');
    perSecT=perSOBJ.aktTbl;

    % update progress dialog
    uiPgDlg.Value=(itrFs-1)/height(AP_QC_T);
    uiPgDlg.Message="Processing: ID: "+AP_QC_T.SubjectID(itrFs)+". File "+itrFs+" of "+height(AP_QC_T)+"..";


    % if any excluded time defined in diary, exclude them reassigning activity number -1
    RowsExcld=strcmpi(perSecT.Event,"X");
    perSecT.Activity(RowsExcld)=-1; % reclassify all seconds flagged as 'X' from diary as new activity -1
    % similarly reassign -1 to seconds flagged as sleep-interval
    perSecT.Activity(perSecT.SleepInterval)=-1; %  reclassify all seconds flagged as sleep-interval as new activity -1
    %Redefine activity time series (time and activity number) for easy access
    Activity=perSecT.Activity;
    DateTime=datetime(perSecT.DateTime,'ConvertFrom','datenum');

    % do a run length encoding for sitting segments
    aktNum=2; % activity number for sitting
    rle_Sit=rle(Activity==aktNum); % call rle function

    % these are the indices of RLE cellarray for sitting segments which are
    % at least min_sit_dur seconds long (default 60s). Duration is Stop-Start,
    % i.e. (number of 1-s samples - 1), so the run must have > min_sit_dur samples
    sitSects=find(rle_Sit{1}==1 & rle_Sit{2}>min_sit_dur);
    sitStartInds=rle_Sit{3}(sitSects); % the start of each sit section
    sitEndInds=rle_Sit{4}(sitSects); % the end of each sit section


    % 1. Define the split duration (5 minutes)
    splitDuration = minutes(5);

    % Preallocate cell arrays to hold the generated start and end datetimes
    numRows = length(sitSects);
    allStarts = cell(numRows, 1);
    allEnds = cell(numRows, 1);
    allTPFlags = cell(numRows, 1);
    allIDs = cell(numRows, 1);

    for i = 1:numRows
        tStart = DateTime(sitStartInds(i));
        tEnd = DateTime(sitEndInds(i));

        % Generate the step edges from Start to End
        edges = tStart : splitDuration : tEnd;

        % If the last edge doesn't reach the End, append the End time
        if isempty(edges) || edges(end) < tEnd
            % a leftover shorter than min_sit_dur is merged into the previous piece
            % (move the last edge to tEnd) instead of becoming its own tiny segment
            if length(edges) >= 2 && seconds(tEnd-edges(end)) < min_sit_dur
                edges(end) = tEnd;
            else
                edges = [edges, tEnd];
            end
        end

        % If the segment is too short to split, keep it as is
        if length(edges) < 2
            allStarts{i} = tStart;
            allEnds{i} = tEnd;
        else
            % Save the start and end of each sub-segment
            allStarts{i} = edges(1:end-1)';
            allEnds{i} = edges(2:end)';
        end

        % find the corresponding index for this segment in transportation detection table
        indTrns=find(isbetween(tStart+(tEnd-tStart)/2,sitsegTbl.Start,sitsegTbl.Stop));
        %add the transport flag from the original table
        if isempty(indTrns)
            transportFlag="";
        elseif ~isempty(indTrns) && ismissing(sitsegTbl.Transport(indTrns))
            transportFlag="";
        else
            transportFlag=sitsegTbl.Transport(indTrns);
        end

        allTPFlags{i}=repmat(transportFlag,length(allStarts{i}),1);
        %add the subject-ID from original table
        allIDs{i}=repmat(AP_QC_T.SubjectID(itrFs),length(allStarts{i}),1);
    end

    % 2. Vertically concatenate all the sub-segments into long datetime vectors
    splitStarts = vertcat(allStarts{:});
    splitEnds = vertcat(allEnds{:});
    splitTpFlags=vertcat(allTPFlags{:});
    splitIDs=vertcat(allIDs{:});
    splitDurs=round(seconds(splitEnds-splitStarts),1); % segement durations in seconds

    % 3. Create a clean, lightweight output table
    sit5minTbl = table(splitIDs,splitStarts, splitEnds,splitDurs,splitTpFlags, 'VariableNames', ["ID","Start", "Stop","Duration","Transport"]);

    n_rows=height(sit5minTbl); % find number of 5-min sitting_segments


    % add WBV_vars tp sitsegTbl
    outTbl=horzcat(sit5minTbl,table('Size',[n_rows,2+length(WBV_vars)],'VariableNames',["Errors","Messages",WBV_vars],...
        'VariableTypes',["string","string",repmat("double",1,length(WBV_vars))]));
    % set "Messages" and "Errors" column to ""
    outTbl.Messages=repmat("", height(sit5minTbl), 1);
    outTbl.Errors=repmat("", height(sit5minTbl), 1);

    % hold currently opened thigh axivity filename
    AXT_Fil=AP_QC_T.FilePath(itrFs);

    % flag to load AXT file only once
    loaded_axt=false;
    % flag for counting severe errors
    errCt=0;
    % Iterate through each 5-min segment and find WBV data from Svantek and Axivity accelerometers
    for itr=1:n_rows

        errAXT="";

        try


            %% read Axivity thigh file

            % only load if the file is not already loaded

            if ~loaded_axt && isfile(AXT_Fil)

                [~,~,t_1s_AXT,rms_AXT,vdv_AXT,Sat_AXT_1s,messages] = load_AX3_iso2631(AXT_Fil,grvtK,dRange_AXT,"",false);
                outTbl.Messages(itr)="Loaded Axvity file: "+AXT_Fil+"; "+ join(messages, "; ");

                loaded_axt=true;
                % fix axes orientation
                rms_AXT=[rms_AXT(:,2),rms_AXT(:,1),rms_AXT(:,3)];
                vdv_AXT=[vdv_AXT(:,2),vdv_AXT(:,1),vdv_AXT(:,3)];
                Sat_AXT_1s=[Sat_AXT_1s(:,2),Sat_AXT_1s(:,1),Sat_AXT_1s(:,3)];

            elseif ~loaded_axt && ~isfile(AXT_Fil)
                errAXT=errAXT+" Axivity CWA file: '"+AXT_Fil+"' not found";
                t_1s_AXT=[]; rms_AXT=[];vdv_AXT=[];Sat_AXT_1s=[];
                loaded_axt=true;

            elseif loaded_axt


            end


            %% Fill  WBV Table for Axivity sthigh

            if ~isempty(rms_AXT)
                [WBV_prob_1,prediction_1,WBV_prob_2,prediction_2, ...
                    aWx,aWy,aWz,av,VDVx,VDVy,VDVz,CFx,CFy,CFz,tx_sat,ty_sat,tz_sat]=deal(NaN);

                %find the start and end indices selected time-interval
                indx_start=find(t_1s_AXT>=sit5minTbl.Start(itr),1,'first');
                indx_end=find(t_1s_AXT<sit5minTbl.Stop(itr),1,'last');
                AX_rows=indx_start:indx_end;

                AX_t=t_1s_AXT(AX_rows);
                % outTbl.Measure_t(itr)= seconds(sitsegTbl.End_Time(itr)-sitsegTbl.Start_Time(itr));
                if length(AX_t)>1
                    seg_t= seconds(AX_t- AX_t(1));

                    seg_dur=seg_t(end)-seg_t(1)+1;
                    aWx=sqrt(trapz(seg_t,(rms_AXT(AX_rows,1).^ 2))/seg_dur);
                    aWy=sqrt(trapz(seg_t,(rms_AXT(AX_rows,2).^ 2))/seg_dur);
                    aWz=sqrt(trapz(seg_t,(rms_AXT(AX_rows,3).^ 2))/seg_dur);
                    av=sqrt((kx*aWx)^2 + (ky*aWy)^2+(kz*aWz)^2);

                    VDVx=(trapz(seg_t,(vdv_AXT(AX_rows,1).^ 4))) .^0.25;
                    VDVy=(trapz(seg_t,(vdv_AXT(AX_rows,2).^ 4))) .^0.25;
                    VDVz=(trapz(seg_t,(vdv_AXT(AX_rows,3).^ 4))) .^0.25;



                    CFx=max(abs(rms_AXT(AX_rows,1)))/aWx;
                    CFy=max(abs(rms_AXT(AX_rows,2)))/aWy;
                    CFz=max(abs(rms_AXT(AX_rows,3)))/aWz;

                    % calculated total saturated (overloaded) seconds for this segment
                    tx_sat=sum(Sat_AXT_1s(AX_rows,1));
                    ty_sat=sum(Sat_AXT_1s(AX_rows,2));
                    tz_sat=sum(Sat_AXT_1s(AX_rows,3));

                    %WBV prediction binary using logistic regression model

                    % Preprocessing
                    AXT_av_8h =av;

                    AXT_VDV_x_k = 1.4 * VDVx;
                    AXT_VDV_y_k = 1.4 * VDVy;
                    AXT_VDV_z_k = 1.0 * VDVz;

                    Total_Duration_h= seg_dur/3600;

                    AXT_VDV_x_8h = AXT_VDV_x_k * (8 / Total_Duration_h)^(0.25);
                    AXT_VDV_y_8h = AXT_VDV_y_k * (8 / Total_Duration_h)^(0.25);
                    AXT_VDV_z_8h = AXT_VDV_z_k * (8 / Total_Duration_h)^(0.25);

                    AXT_VDV_total_8h = (AXT_VDV_x_8h^4 + AXT_VDV_y_8h^4 + AXT_VDV_z_8h^4)^0.25;

                    % Logistic regression prediction model 1
                    logit_SV_AV = ...
                        -10.9111339161871...
                        + 22.2162269142757 * AXT_av_8h ...
                        - 2.08742453515428 * (AXT_av_8h^2) ...
                        - 0.354275625544402 * AXT_VDV_total_8h;

                    % find probability of WBV based on AV
                    WBV_prob_1 = 1 / (1 + exp(-logit_SV_AV));
                    % Binary classification (threshold = 0.5)
                    prediction_1 = (WBV_prob_1>=0.5);

                    % Logistic regression prediction model 2
                    logit_SV_A8 = ...
                        -9.46292549717376 ...
                        + 19.3525449372544 * AXT_av_8h ...
                        - 1.24809260552147 * (AXT_av_8h^2) ...
                        - 0.479760940026815 * AXT_VDV_total_8h;

                    % find probability of WBV based on A8
                    WBV_prob_2 = 1 / (1 + exp(-logit_SV_A8));
                    % Binary classification (threshold = 0.5)
                    prediction_2 = (WBV_prob_2>=0.5);

                else
                    errAXT=errAXT+" Measurement segment too short or time mismatch with Axivity thigh CWA file";
                    errCt=errCt+1;
                end

                outTbl{itr,WBV_vars}=[round(WBV_prob_1,3),prediction_1,round(WBV_prob_2,3),prediction_2, ...
                    aWx,aWy,aWz,av,VDVx,VDVy,VDVz,CFx,CFy,CFz,tx_sat,ty_sat,tz_sat];
            end

            outTbl.Errors(itr)=errAXT;



        catch ME
            outTbl.Errors(itr)=string(getReport(ME,'extended','hyperlinks','off'));
            fprintf("Error: "+ME.message+newline);
            errCt=errCt+1;
            continue;
        end

    end
    % if all rows could be processed increase doneFs count
    if errCt==0
        doneFs=doneFs+1;
    end

    if ~isempty(finalOutT)
        finalOutT=vertcat(finalOutT,outTbl); % vertically merge the current output with final output
    else
        finalOutT = outTbl; % Initialize final output table if empty
    end

    % check for cancelation
    if uiPgDlg.CancelRequested
        status="Cancelled";
        return;
    end
end

% Save the  accumulated WBVprediction for each sitting segments as CSV
writetable(finalOutT,output_file,'WriteMode','overwrite');

% update the status field
if doneFs==height(AP_QC_T)
    status="OK";
elseif doneFs>=1
    status="Check";
elseif doneFs==0
    status="Error";
end

end

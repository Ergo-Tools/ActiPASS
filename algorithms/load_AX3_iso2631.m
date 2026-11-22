function [t_DT,data,t_DT_1s,RMS_1s,VDV_1s,Sat_1s,messages,calStruct] = load_AX3_iso2631(fil_acc,grvtK,dRange,fil_mancal,returnFull)
%LOAD_AX3_ISO2631 Load Axivity CWA file, additional calibration data file and do frequency weighted filtering
%
%  open the *.cwa data files using the details found in the respective fileinfo objects
%  The three axes are processed one at a time (interpolate, weight, 1 s RMS/VDV,
%  saturation) so only one full-rate column is in memory at a time.
%  returnFull=false skips the full-rate outputs t_DT and data (returned as []),
%  which is what WBV segment calculation needs and saves most memory.

% Copyright (c) 2021-2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the ActiPASS repository (https://github.com/Ergo-Tools/ActiPASS).
arguments
    fil_acc
    grvtK double = 9.821 % gravitational constant
    % expected dynamic range for saturation detection, if zero no saturation is detected
    dRange double = 0
    fil_mancal string = ""   % optional string scalar, default ""
    returnFull logical = true % return full-rate time (t_DT) and weighted data (data)
end

% define empty vector of string messages
messages=strings(0);
%datenum to seconds conversion
d2s = 24*3600;

% Possible sample rates for Axivity AX3
AX3PosFreq=[12.25,25,50,100,200,400,800,1600,3200];

% stillness threshold for autocalibrtion for +- 16g, 13bit axivity devices
actThreshStill=0.04;

% manual cal data structure
calStruct=struct('DeviceID',{},'X_scale',{},'X_offst',{},'Y_scale',{},'Y_offst',{},'Z_scale',{},'Z_offst',{});

% ISO 2631 weighting per axis: Wd for x and y, Wk for z
wTypes={'Wd','Wd','Wk'};

try
    % get metadata from CWA file first
    info=CWA_readFile(fil_acc, 'info', 1,'useC', 1);

    DeviceID=info.deviceId;

    % load the CWA file
    cwadata = CWA_readFile(fil_acc,'packetInfo', info.packetInfo, 'useC', 1);
    rawAcc = cwadata.AXES;
    clear cwadata

    % get rid of bad timestamps
    rawAcc = rawAcc(diff(rawAcc(:,1))>0,:);

    %find sample-rate using 10000 points
    numSamples=min(10000,size(rawAcc,1));
    SampleInterval=mean(diff(rawAcc(1:numSamples,1)))*d2s; %sampel period T (it is not accurate)
    %finding true sampel T and sampel f
    Fs=round(1/SampleInterval);
    [~,index] = min(abs(AX3PosFreq-Fs));
    Fs=AX3PosFreq(index); %True f

    % fixed-rate time vector to interpolate to
    start = rawAcc(1,1);
    stop = rawAcc(end,1);
    t = linspace(start, stop, (stop-start)*d2s*Fs+1);

    % 1 s output grid (same as before: first/last whole second inside the data)
    start_T=dateshift(datetime(t(1),'ConvertFrom','datenum'),'end','second');
    end_T=dateshift(datetime(t(end),'ConvertFrom','datenum'),'start','second');
    t_DT_1s=linspace(start_T,end_T,seconds(end_T-start_T)+1);
    % interpolate in seconds from the first sample (datenum is too coarse for exact 1 s points)
    t0_DT=datetime(t(1),'ConvertFrom','datenum');
    t_1s=seconds(t_DT_1s-t0_DT);
    tSec=seconds(datetime(t,'ConvertFrom','datenum')-t0_DT); % sample times in s

    % optional manual calibration: needs the whole interpolated matrix
    Dcal=[];
    if isfile(fil_mancal)
        Dcal = interp1(rawAcc(:,1),rawAcc(:,2:4),t,'pchip',0);
        [Dcal,calStruct,calStatus] = applyManualCal([t',Dcal],calStruct,DeviceID,actThreshStill,fil_mancal,AX3PosFreq,d2s);
        Dcal = Dcal(:,2:4);
        if ~strcmpi(calStatus,"Fail")
            messages = [messages;"Calibrating successful"];
            writestruct(calStruct,fil_mancal+"_calibarion.json");
        else
            messages = [messages;"Calibrating unsuccessful. Continuing without calibration"];
        end
    else
        messages = [messages;"Continuing without additional device calibration"];
    end

    nOut=numel(t_1s);
    RMS_1s=zeros(nOut,3);
    VDV_1s=zeros(nOut,3);
    Sat_1s=zeros(nOut,3);
    if returnFull
        data=zeros(numel(t),3);
    else
        data=[];
    end

    for ax=1:3
        % saturation flag of the raw samples, carried to the fixed-rate grid
        satAx = interp1(rawAcc(:,1),double(abs(rawAcc(:,ax+1))>dRange),t,'nearest',0);
        satAx = movmax(satAx,Fs); % any saturation within the 1 s window
        Sat_1s(:,ax) = round(interp1(tSec,satAx,t_1s));
        clear satAx

        % equi-sampled acceleration of this axis
        if isempty(Dcal)
            accAx = interp1(rawAcc(:,1),rawAcc(:,ax+1),t,'pchip',0);
        else
            accAx = Dcal(:,ax).';
        end

        % frequency weighted acceleration
        aW = iso2631_wbv(grvtK*accAx(:),wTypes{ax},Fs);
        clear accAx

        % moving 1 s RMS and VDV, down-sampled to the 1 s grid
        RMS_1s(:,ax) = interp1(tSec,sqrt(movmean(aW.^2,Fs)),t_1s);
        VDV_1s(:,ax) = interp1(tSec,movmean(aW.^4,Fs).^0.25,t_1s);

        if returnFull
            data(:,ax)=aW;
        end
        clear aW
    end

    if returnFull
        t_DT=datetime(t(:),'ConvertFrom','datenum');
    else
        t_DT=[];
    end
catch ME
    error("CWA loading error: "+string(getReport(ME,'extended','hyperlinks','off')));
end

end

function [Acc,calStruct,calStatus] = applyManualCal(Acc,calStruct,DeviceID,actThreshStill,fil_mancal,AX3PosFreq,d2s)
% load the manual calibration CWA file, resample it and calibrate Acc with it
info=CWA_readFile(fil_mancal, 'info', 1,'useC', 1);
cwadata_cal = CWA_readFile(fil_mancal,'packetInfo', info.packetInfo, 'useC', 1);
cwadata_cal.AXES = cwadata_cal.AXES(diff(cwadata_cal.AXES(:,1))>0,:);

numSamples=min(10000,size(cwadata_cal.AXES,1));
sinterval_cal=mean(diff(cwadata_cal.AXES(1:numSamples,1)))*d2s;
Fs_cal=round(1/sinterval_cal);
[~,index] = min(abs(AX3PosFreq-Fs_cal));
Fs_cal=AX3PosFreq(index);

start_cal = cwadata_cal.AXES(1,1);
stop_cal = cwadata_cal.AXES(end,1);
t = linspace(start_cal, stop_cal, (stop_cal-start_cal)*d2s*Fs_cal+1);
Dintp=zeros(length(t),3);
for j=1:3
    Dintp(:,j) = interp1(cwadata_cal.AXES(:,1),cwadata_cal.AXES(:,j+1),t,'pchip',0);
end
[Acc,calStruct,calStatus] = CalibrateData(Acc,calStruct,DeviceID,actThreshStill,[t',Dintp]);
end

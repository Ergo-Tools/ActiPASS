function Lie = trunkLying(Acc,SF,LieThreshold)

% Detects lying position from acceleration data of the hip or trunk accelerometer
%
% Input:
% Acc [N,3]: Acceleratio of hip or trunk
% SF: sample frequency
% LieThreshold: Threshold angle for lying, normally 65° for the hip and 45° for the trunk (°)
%
% Output:
% Lie [n]: 0/1, 1 for lie (n=N/SF), 1 sec. time scale 

%Acc12 = Acc60(Acc,SF);
%  AccMean = double(squeeze(mean(Acc12))); %mean acceleration i 2 sec. windows (50% overlap)

% using movmean for faster processing. But if Scc contains blanks (NaN) will this work?
AccMean=movmean(Acc,SF*2,1); %moving mean of Acc for2s window taken for dim 1
AccMean=AccMean(1:SF:end,:); % moving mean of Acc for 2s window taken at each second


Lng = sqrt(AccMean(:,1).^2 + AccMean(:,2).^2 + AccMean(:,3).^2);
Inc = (180/pi)*acos(AccMean(:,1)./Lng); %Inclination of x-axis

Lie = zeros(length(Inc),1);
Lie(Inc>LieThreshold) = 1;  %ActiGraph using 65°
%Lie = medfilt1(Lie,29); 3/12-14: Lie (and Sit) are filtered in 'AnalyseAndPlot using 'AktFilt'


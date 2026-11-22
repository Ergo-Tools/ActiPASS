function [Acc,calStruct,status,warnings] = CalibrateData(Acc,calStruct,DeviceID,actThresh,AccManCal)
% CalibrateData calls AutoCalibrate.m to find manual calibration coefficents
% from AccManCal and then apply those coefficients to Acc and returns it
% Inputs:
%   Acc:
%   calStruct: actual accelerometer data
%   DeviceID:
%   actThresh
%   AccManCal: data from manual calibration
%
% Outputs:
%   Acc:
%   calStruct:
%   status
%
% Copyright (c) 2021, Pasan Hettiarachchi .
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


t_win=10; % time_window for aurtocalibrate moving filters
t_step=10; % time step for downsampling data

[~,scale,offset,cal_status,cal_warn]= AutoCalibrate(AccManCal,'actThresh',actThresh,'t_win',t_win,'t_step',t_step);
if isempty(cal_status)
    
    if ~isempty(cal_warn)
        warnings=cal_warn;
    end
    
    
    % Add Autocal data to calStruct
    if isfloat(DeviceID) && ~isnan(DeviceID)
        if ~isempty(calStruct) % if calStruct is not empty
            calRow=find([calStruct.DeviceID]==DeviceID); % check whether the DeviceID is already there
            % if DeviceID found concatenate calibration data to later find the mean values
            if ~isempty(calRow)
                calStruct(calRow).X_scale=mean([calStruct(calRow).X_scale,scale(1)]);
                calStruct(calRow).Y_scale=mean([calStruct(calRow).Y_scale,scale(2)]);
                calStruct(calRow).Z_scale=mean([calStruct(calRow).Z_scale,scale(3)]);
                calStruct(calRow).X_offst=mean([calStruct(calRow).X_offst,offset(1)]);
                calStruct(calRow).Y_offst=mean([calStruct(calRow).Y_offst,offset(2)]);
                calStruct(calRow).Z_offst=mean([calStruct(calRow).Z_offst,offset(3)]);
            else % if DeviceID is not found add Autocal data for the new DeviceID
                newL=length(calStruct)+1;
                calStruct(newL).DeviceID=DeviceID;
                calStruct(newL).X_scale=scale(1);
                calStruct(newL).Y_scale=scale(2);
                calStruct(newL).Z_scale=scale(3);
                calStruct(newL).X_offst=offset(1);
                calStruct(newL).Y_offst=offset(2);
                calStruct(newL).Z_offst=offset(3);
            end
        else % if calStruct is empty add Autocal data as the first element
            calStruct(1).DeviceID=DeviceID;
            calStruct(1).X_scale=scale(1);
            calStruct(1).Y_scale=scale(2);
            calStruct(1).Z_scale=scale(3);
            calStruct(1).X_offst=offset(1);
            calStruct(1).Y_offst=offset(2);
            calStruct(1).Z_offst=offset(3);
        end
    end
    % apply calibration data
    if ~isempty(calStruct)
        if isfloat(DeviceID) && ~isnan(DeviceID)
            calRow=find([calStruct.DeviceID]==DeviceID);
            if ~isempty(calRow)
                cal_offset=[calStruct(calRow).X_offst,calStruct(calRow).Y_offst,calStruct(calRow).Z_offst];
                cal_scale=[calStruct(calRow).X_scale,calStruct(calRow).Y_scale,calStruct(calRow).Z_scale];
                
                % apply calibration data
                Acc(:,2:4)=repmat(cal_offset,size(Acc,1),1) + (Acc(:,2:4) .* repmat(cal_scale,size(Acc,1),1));
                status="OK";
            else
                status="Fail";
            end
        else
            status="Fail";
        end
    else
        % if calStruct is also empty (no calibration file defined or empty)
        status="Fail";
    end
    

end


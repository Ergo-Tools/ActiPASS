function [Acc,scale,offset,status,warntxt,sens_err] = AutoCalibrate(Acc,varargin)

%AUTOCALIBRATE Automatically calibrate triaxial accelerometer data

%   Input:
%       Acc   [Nx4]    Resampled Acc data
%
%   Optional arguments ('name',value):
%       actThresh   double  Threshold for activity (default: 0.01 [g])
%       t_win       double  Duration of epoch (detault: 10 [s])
%       t_step      double  Time between epochs (default: 10 [s])
%       maxIter     double  Maximum number of iterations before giving up
%       convCrit    double  The convergence threshold of sum(scale)
%       verbode     double  Print verbode info
%       ptsPAxis    double  The number of pts for linear regression data
%                           per each axis in neg and pos direction.
%   Output:
%       Acc   [Nx4]  Calibrated Acc data
%       status      'char' the status message
%       scale       double 
%       offset      double
%       sens_err    possible sensor errors - VM of still periods too low or high

% this function is based on "estimateCalibration.m" implementation of Vincent van Hees' auto-calibration
% algorithm by OpenMovement Project
% https://github.com/digitalinteraction/openmovement/blob/master/Software/Analysis/Matlab/estimateCalibration.m

%   version 0.01 
%   Pasan Hettiarachchi (c), 2021
%   <pasan.hettiarachchi@medsci.uu.se>

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


% **********************************************************
% original copyright notice of "estimateCalibration.m"
% **********************************************************
% Copyright (c) 2014, Newcastle University, UK.
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met: 
% 1. Redistributions of source code must retain the above copyright notice, 
%    this list of conditions and the following disclaimer.
% 2. Redistributions in binary form must reproduce the above copyright notice, 
%    this list of conditions and the following disclaimer in the documentation 
%    and/or other materials provided with the distribution.
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
% 

options = inputParser;

% define optional arguments with default values
addOptional(options,'actThresh', 0.013, @isnumeric); % activity thresholds on std
addOptional(options,'t_win',10, @isnumeric); % epoch duration
addOptional(options,'t_step',10, @isnumeric); % step between epochs
addOptional(options,'maxIter', 1000, @isnumeric); % maximum iterations
addOptional(options,'convCrit', 1e-9, @isnumeric); % convergence threshold
addOptional(options,'verbose',0, @isnumeric); % logging level
addOptional(options,'ptsPAxis',500, @isnumeric); % number of data points per axis to use
% parse varargin
parse(options,varargin{:});
options = options.Results;

% assign options to variables
actThresh =  options.actThresh;
t_win = options.t_win;
t_step = options.t_step;
maxIter=options.maxIter;
convCrit=options.convCrit;
verbose=options.verbose;
ptsPAxis=options.ptsPAxis;
% empty status and warnings in the begining
status='';
warntxt='';
sens_err=false;
% initialise scale and offset to default values
scale = ones(1,3);
offset = zeros(1,3);

% find sample-interval and frequency using only 1000 samples
tmpEndInd=min(1000,size(Acc,1));
SampleInterval=86400*mean(diff(Acc(1:tmpEndInd,1)));% Find the sample interval, Acc time should already be evenly sampled
Fs=round(1/SampleInterval);

smplsTS=1:Fs*t_step:length(Acc(:,1)); % indexes at every t_step (for down sampling)
%svm_bukts=reshape(Acc(1:lastSmpl),[buktSize,bukts]);

% Finding means,SDs and median-filtering of ACC data
FiltWin=Fs*t_win; % the size of time-window as number of samples  ( 10s default)
% first find median filtered vector magnitude in XY plane. This will be
% used later for detecting sit periods
movMeanAcc=movmean(Acc(:,2:4),FiltWin,1);
movMeanAcc=movMeanAcc(smplsTS,:); % downsampling at t_step intervals
stdMeanAcc=movstd(Acc(:,2:4),FiltWin,1);
stdMeanAcc=stdMeanAcc(smplsTS,:); % downsampling at t_step intervals

smplsStill=sum(stdMeanAcc <= actThresh,2) == 3;
movMeanAcc=movMeanAcc(smplsStill,:); % only select the mean values of still points

SVM=sqrt(sum(movMeanAcc .^ 2, 2)); % VM of still periods
dif_percn_10_90=prctile(SVM,90)-prctile(SVM,10);
% for still periods there shouldn't be a big difference of vector magnitude. 
% But some faulty sensors (one or more axes faulty) this is not true
if dif_percn_10_90 > 0.70
    sens_err=true;
    warntxt='Possible Sensor Error';
end

%finding valid points for curve fitting where the acceleration is
%sufficiently large in both positive and negative direction for each axes
ptsPosValidX=find(movMeanAcc(:,1)>=0.3);
ptsPosValidY=find(movMeanAcc(:,2)>=0.3);
ptsPosValidZ=find(movMeanAcc(:,3)>=0.3);
ptsNegValidX=find(movMeanAcc(:,1)<= -0.3);
ptsNegValidY=find(movMeanAcc(:,2)<= -0.3);
ptsNegValidZ=find(movMeanAcc(:,3)<= -0.3);

% finding the number of such points for each axes for each polarity
lNegX=length(ptsNegValidX);
lPosX=length(ptsPosValidX);
lNegY=length(ptsNegValidY);
lPosY=length(ptsPosValidY);
lNegZ=length(ptsNegValidZ);
lPosZ=length(ptsPosValidZ);

validX= lNegX> 1 && lPosX > 1; % Valid pts in X-axis?
validY= lNegY > 1 && lPosY > 1; % Valid pts in Y-axis?
validZ= lNegZ > 1 && lPosZ > 1; % Valid pts in Z-axis?

if validX && validY && validZ % at least one valid point for each axis for each polarity
    
    % randomize those valid points. this is done to pick enough data points spreaded throughout the data
    ptsPosValidX=ptsPosValidX(randperm(lPosX));
    ptsNegValidX=ptsNegValidX(randperm(lNegX));
    ptsPosValidY=ptsPosValidY(randperm(lPosY));
    ptsNegValidY=ptsNegValidY(randperm(lNegY));
    ptsPosValidZ=ptsPosValidZ(randperm(lPosZ));
    ptsNegValidZ=ptsNegValidZ(randperm(lNegZ));
    
    % only select 'ptsPAxis' number of (default 500) points for each axes for each
    % polarity. If there are not points select all of them
    ptsPosValidX=ptsPosValidX(1:min(ptsPAxis,lPosX));
    ptsNegValidX=ptsNegValidX(1:min(ptsPAxis,lNegX));
    ptsPosValidY=ptsPosValidY(1:min(ptsPAxis,lPosY));
    ptsNegValidY=ptsNegValidY(1:min(ptsPAxis,lNegY));
    ptsPosValidZ=ptsPosValidZ(1:min(ptsPAxis,lPosZ));
    ptsNegValidZ=ptsNegValidZ(1:min(ptsPAxis,lNegZ));
    
    % concatenate all valid points of each axis for both polarities in to
    % one vector
    
    ptsValid=vertcat(ptsPosValidX,ptsNegValidX,ptsPosValidY,ptsNegValidY,...
        ptsPosValidZ,ptsNegValidZ);
    ptsValid=unique(ptsValid); % remove duplicate points
    
    
    % Now use only those points in linear regression
    D_in=movMeanAcc(ptsValid,:);
    N=length(ptsValid);
    % intialise the weights to ones, will be later adjusted based on data
    % points
    weights = ones(N,1);
    % main loop to estimate unit sphere
    for i=1:maxIter
        % scale input data with current parameters
        % model: offset + D_in* scale
        data  = repmat(offset,N,1) + (D_in .* repmat(scale,N,1));
        svm=sqrt(sum(data.^2,2));
        % targets: points on unit sphere
        target = data ./ repmat(svm,1,3);
        
        % initialise vars for optimisation
        gradient = zeros(1,3);
        off = zeros(1,3);
        
        % do linear regression per input axis to estimate scale offset
        % (and tempOffset)
        for j=1:3
            % IMPORTANT: Requires 'Statistics and Machine Learning Toolbox'
            
            mdl =fitlm(data(:,j), target(:,j), 'linear', 'Weights', weights);
            
            off(j) = mdl.Coefficients.Estimate(1);       % offset     = intersect
            gradient(j) = mdl.Coefficients.Estimate(2);  % scale      = gradient
            
        end
        
        % change current parameters
        scaleOld = scale; % save this for convergence comparison
        scale = scale .* gradient;  % adapt scaling
        offset = offset + off;% ./ scale; % adapt offset
        
        % weightings for linear regression
        % read: weight is large for samples with small error, small for big
        % error, and overall limited to a maximum of 100
        
        
        errors=abs(svm-1); % the error of VM respect to unit sphere
        weights = min([1 ./errors, repmat(100,N,1)],[],2);
        % no more scaling change -> assume it has converged
        convgE = sum(abs(scale-scaleOld));
        converged = convgE < convCrit;
        
        % find mean error of all samples
        
        meanE=mean(errors);
        if converged
            break % get out of this loop
        end
        if verbose
            fprintf('iteration %d\terror: %.4f\tconvergence: %.6f\n',i,meanE,convgE);
        end
        
    end
  
    if meanE>0.02 % if the error is above 0.01 (according to Van Hees)
        % calibration is not succesful
        status=sprintf('Calibration error too large: %s',meanE);
        
    else
        % otherwise apply the calibration coefficients to the raw-data
        Acc(:,2:4)=repmat(offset,length(Acc(:,1)),1) + (Acc(:,2:4) .* repmat(scale,length(Acc(:,1)),1));
        if i==maxIter
            % no convergence but assume that we are done anyway
            warntxt=sprintf('%s Maximum number of iterations reached. Error %.4f',warntxt,meanE);
        end
    end
else
    status='No valid data for calibration';
end
end
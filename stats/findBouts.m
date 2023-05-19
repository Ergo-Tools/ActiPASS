function [tBoutHigh,numBtsH,tBoutLow,numBtsL] = findBouts(varAkt,b_dur, b_break, b_thr, epoch, clsdBout)

%findBouts find bouts from a given activity, and bout duration
arguments
    varAkt (1,:) double % a logical vector representing the given variable
    b_dur  (1,1)double % the selected bout duration for finding bouts in seconds
    b_break (1,1) double = 20 % the time threshold for bout detection in seconds
    b_thr (1,1) double = 1 % the time threshold for bout detection (0 or 1 means it's not used)
    epoch (1,1) double = 1 % resolution of the variable in seconds
    clsdBout (1,1) logical = false % T/F flag indicating whether to fill gaps is found bouts or to keep the original data
end

% outputs:
%    tBoutHigh  - the time spent on bouts of at least b_dur
%    numBtsH  - the number of bouts of given length
%    numBtsL - the number of bouts shorter than given length
%    tBoutLow - the time spent on bouts shorter than b_dur.

% Copyright (c) 2023, Pasan Hettiarachchi & Matthew Ahmadi 
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

try
    
    b_break=b_break/epoch; % scale b_break and b_dur to epochs
    b_dur=b_dur/epoch;
    
    %adjusting too long bout-breaks for shorter bouts (Ex. 1-min bouts).
    if b_break > b_dur/2
        b_break=b_dur/2;
    end
    
    %make a copy of varAkt
    varAktOrig=varAkt;
    % following code is when a bout_threshold is given. This code run slow
    if b_thr>0 && b_thr<1
        
        btsClosed=false(size(varAkt)); % vector to hold closed bouts (with any gaps removed)
        varT=double(varAkt); % a copy of varAkt with data type double
        
        lenVarAkt=length(varAkt);
        indAkt=find(varAkt); % the indices where the given variable is true
        
        locBtNxt=1; % the location of next bout in indAkt vector intialise to 1
        
        numBtsH=0; % the number of bouts with b_dur or higher duration
        
        
        while (locBtNxt <= length(indAkt))
            
            locBtEnd = indAkt(locBtNxt) + b_dur; %the location of end of bout in varAkt vector
            if locBtEnd<=lenVarAkt
                if (sum(varAkt(indAkt(locBtNxt):locBtEnd)) > (b_dur * b_thr))
                    % Keep counting bout time as long as 1 minute break does not occur and b_thr is still met
                    %(this part is not needed, but is left to keep options open in the future)
                    
                    while locBtEnd <= lenVarAkt &&...
                            sum(varAkt(indAkt(locBtNxt):locBtEnd)) > ((locBtEnd - indAkt(locBtNxt))* b_thr) &&...
                            any(varAkt((locBtEnd - b_break):locBtEnd))
                        locBtEnd = locBtEnd + 1;
                    end
                    select = indAkt(locBtNxt:find(indAkt < locBtEnd,1,'last'));
                    jump = length(select); % the length of the jump to the end of bout
                    varT(select) = 2;
                    btsClosed(indAkt(locBtNxt):indAkt(find(indAkt < locBtEnd,1,'last'))) = 1;
                    numBtsH=numBtsH+1; %count the bouts
                else
                    % true epochs in start of this-bout + b_dur is less than 80%
                    jump = 1; % increase jump by one go to next iteration
                    varAkt(indAkt(locBtNxt)) = 0;
                    
                end
            else
                %  start of this-bout + b_dur falls after the end of given variable set the jump to one
                jump = 1;
                if (length(indAkt) > 1 && locBtNxt > 2)
                    % if the crrent bouts starts at least index 2, set the current epoch to previous epoch
                    varAkt(indAkt(locBtNxt)) = varAkt(indAkt(locBtNxt - 1));
                end
            end
            %increase the start of next bout by 'jump' number of true epochs
            locBtNxt = locBtNxt + jump;
        end
        if clsdBout
            varAkt = btsClosed; % of closed flag is given just assign btsClosed back to varAkt
        else
            varAkt(varT == 2) = 1; % all epochs within detected bouts are flagged true (is this needed?)
            
            varAkt(varT == 1) = 0; %any remaining true epochs of the variable but outside detected bouts are set to zero
        end
        
        tBoutHigh=sum(varAkt);
        varAktLow=varAktOrig & ~varAkt;
        tBoutLow=sum(varAktLow);
        numBtsL=length(find(diff([0,varAktLow])==1)); % the number of bouts with duraion lower than b_dur
        %calculate bouts only using bout breaks
        
    elseif b_thr==0 || b_thr==1
        
        runLs=rle(varAkt);
        varRun=repelem(runLs{2},runLs{2});
        % removing breaks in bouts
        varAkt(varAkt==0 & varRun<=b_break)=1;
        runLs=rle(varAkt);
        varRun=repelem(runLs{2},runLs{2});
        if ~clsdBout
            tBoutHigh =sum(varAktOrig==1 & varRun>=b_dur); % - the time spent on bouts of at least b_dur
            numBtsH = sum(runLs{1}==1 & runLs{2}>=b_dur); % - the number of bouts of given length
            numBtsL= sum(runLs{1}==1 & runLs{2}<b_dur);  % - the number of bouts shorter than given length
            tBoutLow =sum(varAktOrig==1 & varRun <b_dur); % - the time spent on bouts of at least b_dur %- the time spent on bouts shorter than b_dur.
        else
            tBoutHigh =sum(varAkt==1 & varRun>=b_dur); % - the time spent on bouts of at least b_dur
            numBtsH = sum(runLs{1}==1 & runLs{2}>=b_dur); % - the number of bouts of given length
            numBtsL= sum(runLs{1}==1 & runLs{2}<b_dur);  % - the number of bouts shorter than given length
            tBoutLow =sum(varAkt==1 & varRun <b_dur); % - the time spent on bouts of at least b_dur %- the time spent on bouts shorter than b_dur.
        end
    else
        % outputs:
        tBoutHigh =[]; % - the time spent on bouts of at least b_dur
        numBtsH =[]; % - the number of bouts of given length
        numBtsL= []; % - the number of bouts shorter than given length
        tBoutLow =[]; %- the time spent on bouts shorter than b_dur.
    end
  
    
catch ME
    % outputs:
    tBoutHigh =[]; % - the time spent on bouts of at least b_dur
    numBtsH =[]; % - the number of bouts of given length
    numBtsL= []; % - the number of bouts shorter than given length
    tBoutLow =[]; %- the time spent on bouts shorter than b_dur.
end

end


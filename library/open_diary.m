
function  [status,diaryStrct,diary_file] = open_diary(diary_file,subjectIDs,noDiary)
% OPEN_DIARY Opens ActiPASS formatted diary and read information for given subject IDs.
% Inputs:
%  diary_file: [string] last diary file - used in file-opening-dialog; ex. set to %USERPROFILE% first time
%  subjectIDs: [string][nx1]: String vector of subjectIDs
%  noDiary: [logical] if noDiary==true, then proceed without trying to open a diary
%
% Outputs:
%  status: [string] status of execution
%  diaryStrct: [struct][n x 1] a structure array containing diary data for given subjectIDs. See the source for more details
%     diaryStrct[n].ID - subjectID ;
%     diaryStrct[n].Ticks - all transitions times as Matlab datetime values;
%     diaryStrct[n].Events - all diary events names (work, leisure etc);
%     diaryStrct[n].Comments - all comments for each diary event
%     diaryStrct[n].StartT- the diary defined data start time;
%     diaryStrct[n].StopT - diary defined data stop time;
%     diaryStrct[n].RefTs - standing reference times defined in diary;
%     diaryStrct[n].rawData - the raw diary data for this subjectID as a table (including invalid entries)
%  diary_file: [string]: The diary file_selected. WE can save this for next round of processing

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

%VariableTypes expected from diary
VariableTypes={'string','datetime','duration','string','string'};
%VariableTypes for diary quality check output
VariableTypesQC={'string','string','string','string'};
%variable names for QC output
VariableNames={'ID','Date_Time','Event','Comment'};
%expected variable names of the ActiPASS formatted diary
varNamesOrig={'ID','Date','Time','Event','Comment'};

try
    %intialise diary structure array
    diaryStrct(length(subjectIDs),1) = struct();
    %open the diary file in FMT format
    if noDiary
        file=0;
    else
        if ~ispc, waitfor(msgbox('Select the diary in *.xls or *.xlsx format')); end
        [file,path] = uigetfile({'*.xlsx;*.xls','Excel files'},'Select the diary in *.xls or *.xlsx format',diary_file);
    end
    if ~isnumeric(file)
        diary_file=fullfile(path,file);

        impOpt = detectImportOptions(diary_file);
        if length (impOpt.VariableTypes) <4 || ~isequal(impOpt.VariableNames(1:4),varNamesOrig(1:4))
            for itr=1:length(subjectIDs)
                %ID=str2double(subjectIDs(itr));
                diaryStrct(itr).ID=subjectIDs(itr);
                diaryStrct(itr).Ticks=NaT;
                diaryStrct(itr).Events="";
                diaryStrct(itr).Comments="";
                diaryStrct(itr).StartT=NaT;
                diaryStrct(itr).StopT=NaT;
                diaryStrct(itr).RefT=NaT;
                diaryStrct(itr).rawData=table('Size',[0,4],'VariableTypes',VariableTypesQC,'VariableNames',VariableNames);
            end
            status="Not a valid diary file. Continuing with no diary data";
            return;
        elseif length (impOpt.VariableTypes) ==4
            % define variable types for the first four columns
            impOpt.VariableTypes(1:4)=VariableTypes(1:4);
            impOpt.VariableNames([1,2,4])=VariableNames([1,2,3]);
            impOpt.PreserveVariableNames=true;
            numColumn=4;
        elseif  length (impOpt.VariableTypes) >=5
            % define variable types for the first five columns
            impOpt.VariableTypes(1:5)=VariableTypes;
            impOpt.VariableNames([1,2,4,5])=VariableNames;
            impOpt.PreserveVariableNames=true;
            numColumn=5;
        end

        d_data = readtable(diary_file,impOpt); % read the diary file

        for itr=1:length(subjectIDs)
            %ID=str2double(subjectIDs(itr));
            ID=subjectIDs(itr);
            diaryStrct(itr).ID=ID;
            rows=(d_data.ID==ID); % the rows matching subjectIDs
            % Select only those rows as a table
            dataSubjct=d_data(rows,:);

            % merge the date and time into new variable Date_Time=date+time (time is 'duration' data)
            % formating output in order to keep the date_time in ISO format
            Date_Time=datetime(dataSubjct{:,2}+dataSubjct{:,3},'Format','yyyy-MM-dd HH:mm:ss');
            % remove the date and duration columns and add the merged Date_Time column
            dataSubjct=horzcat(dataSubjct(:,1),table(Date_Time),dataSubjct(:,4:numColumn));
            % save the raw data for QC into the struct
            diaryStrct(itr).rawData=dataSubjct;
            %find the time 'Start' event. In case more than one 'Start' exists, find the unique ones
            % diaryStrct(itr).StartT=dataSubjct{find(strcmpi(dataSubjct{:,3},"Start"),1,'first'),2};

            diaryStrct(itr).StartT=unique(dataSubjct{strcmpi(dataSubjct{:,3},"Start"),2});
            %find the time of 'Stop' event. In case more than one 'Stop' exists, find the unique ones
            %diaryStrct(itr).StopT=dataSubjct{find(strcmpi(dataSubjct{:,3},"Stop"),1,'last'),2};

            diaryStrct(itr).StopT=unique(dataSubjct{strcmpi(dataSubjct{:,3},"Stop"),2});
            if isempty(diaryStrct(itr).StartT), diaryStrct(itr).StartT=NaT; end % when there is no Start event
            if isempty(diaryStrct(itr).StopT), diaryStrct(itr).StopT=NaT; end % when there is no Stop event
            % find all diary rows with event marker 'Ref'. We can add multiple Ref types if needed in the future (like Ref_Thigh, Ref_HR, Ref_trunk etc)
            RefPosRows=find(strcmpi(dataSubjct{:,3},"Ref"));
            if ~isempty(RefPosRows)
                diaryStrct(itr).RefTs=dataSubjct{RefPosRows,2};
                %since we now know the Ref.Pos. Time delete those rows from the
                %table if exist
                dataSubjct(RefPosRows,:)=[];
            else
                diaryStrct(itr).RefTs=NaT;
            end

            [~,ind_d,~]=unique(dataSubjct(:,1:2),'last'); % find unique rows (the same date and time, when duplicates found keep the last row)
            dataSubjct=dataSubjct(ind_d,:); % only keep those rows
            dataSubjct=dataSubjct(~isnat([dataSubjct{:,2}]),:); % only keep rows where ticks are not NaT
            diaryStrct(itr).Ticks=dataSubjct{:,2};
            diaryStrct(itr).Events=dataSubjct{:,3};
            diaryStrct(itr).Events(ismissing(diaryStrct(itr).Events))=""; % instead of missing string values set empty events to ""
            if isempty(diaryStrct(itr).Ticks)
                diaryStrct(itr).Ticks=NaT;
                diaryStrct(itr).Events="";
            end
            % if the diary table had only 4 columns add the 5th called "Comments". Otherwise fill
            % Comments field with 5th column data
            if numColumn==4
                diaryStrct(itr).Comments=strings(size(diaryStrct(itr).Ticks));
            elseif numColumn==5
                diaryStrct(itr).Comments=dataSubjct{:,4};
                diaryStrct(itr).Comments(ismissing(diaryStrct(itr).Comments))="";
            end
        end

        status="Diary: '"+diary_file+"' opened.";

    else
        % if no diary file selected fill the structure with dummy data

        for itr=1:length(subjectIDs)
            %ID=str2double(subjectIDs(itr));
            ID=subjectIDs(itr);
            diaryStrct(itr).ID=ID;
            diaryStrct(itr).Ticks=NaT;
            diaryStrct(itr).Events="";
            diaryStrct(itr).Comments="";
            diaryStrct(itr).StartT=NaT;
            diaryStrct(itr).StopT=NaT;
            diaryStrct(itr).RefTs=NaT;
            diaryStrct(itr).rawData=table('Size',[0,4],'VariableTypes',VariableTypesQC,'VariableNames',VariableNames);
        end
        status="No diary file selected. Continuing with no diary data.";

    end

catch ME

    diaryStrct=[];
    status= "Error opening diary. "+getReport(ME,'extended','hyperlinks','off');
end
end
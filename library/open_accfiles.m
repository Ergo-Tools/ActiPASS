
function  [acc_files,subjectIDs,acc_filenames,rootfolder,ftype,trnk_files,status] = open_accfiles(rootfolder,maxfiles,IDInfo)
% open_accfiles Open accelerometer files using uigetfile and returns their information.

% Inputs:
%     rootfolder: [string] last accelerometer data folder - used in file-opening-dialog; tip. set to %USERPROFILE% first time
%     maxfiles: [double] maximum number of files allowed in a batch
%     IDInfo: [struct] structure with info about how to derive IDs from filenames
%
% Outputs:
%     acc_files[n] accelerometer files full path
%     subjectIDs[n] IDs of the selected accelerometer files
%     acc_filenames[n] only filenames of selected accelerometer files (including file-extension)
%     rootfolder- accelerometer data folder actually selected
%     ftype - accelerometer file type (brand)
%     trnk_files[n] - if a list of files with also trunk-files were selected, return the full path to them
%     status - execution status of the function


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

% intialise variables 
status="";
trnk_files=[];

% show appropriate file-opening dialog depending on OS
if ~ispc
    % for MacOS file opening dialog does not contain a title and file-type selection. Therefore display a seperate menu 
    fTypes=["*.cwa","Axivity AX3/AX6 CWA Files";"*.wav","Axivity AX3/AX6 WAV Files";"*.datx;*.dat","ActivPAL 3 DATX Files";....
        "*.csv","ActivPAL CSV files";"*.csv","Actigraph CSV Files";"*.bin","SENS Motion BIN file";"*.csv","Generic ActiPASS CSV file";"*.xlsx","List of Acc Files"];
    indFT=menu("Select Acc data file type to open a maximum of "+maxfiles+" Axivity, ActivPAL, Actigraph or SENS Files.",fTypes(:,2));
    ftype=indFT; % filetype index will be used in main script
    if indFT~=0 % if menu dialog is not closed by clicking x
        [files,path] = uigetfile(fTypes(indFT,:),("Select a maximum of "+maxfiles+" Axivity, ActivPAL, ActiGraph or SENS Files."),'MultiSelect', 'on',rootfolder );
    else
        acc_filenames=string([]);
        acc_files=string([]);
        subjectIDs="";
        status="No File(s) selected";
        return;
    end
else
    [files,path,ftype] = uigetfile(["*.cwa","Axivity AX3/AX6 CWA Files";"*.wav","Axivity AX3/AX6 WAV Files";...
        "*.datx;*.dat","ActivPAL 3 DATX Files";"*.csv;","ActivPAL CSV files";...
        "*.csv","Actigraph CSV Files";"*.bin","SENS Motion BIN Files";"*.csv","Generic ActiPASS CSV file";"*.xlsx","List of Acc Files"],...
        ("Select a maximum of "+maxfiles+" Axivity, ActivPAL, Actigraph or SENS Files."),'MultiSelect', 'on',rootfolder );
end

if isnumeric(files) % if no files selected (Cancel button pressed)
    acc_filenames=string([]);
    acc_files=string([]);
    subjectIDs="";
    status="No File(s) selected";
    return;
else % One or more file selected
    files=string(files);
    rootfolder=path;
    % the seventh option is a list of filenames in an Excel file.
    if ftype==8
        imptOpt=detectImportOptions(fullfile(path,files)); % detect the import options of the excel file
        % check whether the file is a single column worksheet with the column name 'Filenames'
        if (length(imptOpt.VariableNames)==1 && strcmpi(imptOpt.VariableNames(1),"Filenames")) || ...
                (length(imptOpt.VariableNames)>=2 && all(ismember(["ID","Filenames"],imptOpt.VariableNames)))
            imptOpt.VariableTypes(:)={'string'};
            
            listFsT=readtable(fullfile(path,files),imptOpt); % read the Excel file into a table
            listFsT=listFsT(isfile(listFsT.Filenames),:); %only keep rows with valid filenames
            % if no valid filenames found
            if isempty(listFsT.Filenames)
                acc_filenames=string([]);
                acc_files=string([]);
                subjectIDs="";
                status="No valid file(s) defined";
                return;
            else
                % check whether there are more than 'maxfiles' files
                if length(listFsT.Filenames)>maxfiles
                    status="Too many files selected. Only the first "+num2str(maxfiles)+" will be loaded.";
                    listFsT=listFsT(1:maxfiles,:); % only take first 'maxfiles' files
                end
                
                
                % seperate filenames into filename and extension
                [~,fnameonly,acc_filexts] = fileparts(listFsT.Filenames);
                acc_filenames=fnameonly+acc_filexts; % add extension back to filename
                % if there are different file types do not continue
                if length(unique(acc_filexts))>1
                    acc_filenames=string([]);
                    acc_files=string([]);
                    subjectIDs="";
                    status="Different types of accelerometer files given";
                    return;
                else
                    % acc_files iis the full file-path given in the table
                    acc_files=listFsT.Filenames;
                    
                    % depending on the extension define 'ftype'
                    if strcmpi(acc_filexts(1),".cwa")
                        ftype=1;
                    elseif strcmpi(acc_filexts(1),".wav")
                        ftype=2;
                    elseif strcmpi(acc_filexts(1),".dat") || strcmpi(acc_filexts(1),".datx")
                        ftype=3;
                    elseif strcmpi(acc_filexts(1),".csv")
                        fidTmp=fopen(listFsT.Filenames(1),'r');
                        headLines=fgetl(fidTmp);
                        fclose(fidTmp);
                        if contains(headLines,"ActiGraph",'IgnoreCase',true)
                            ftype=5;
                        elseif startsWith(headLines,"sep=;",'IgnoreCase',true)
                            ftype=4;
                        elseif startsWith(headLines,"ID=",'IgnoreCase',true)
                            ftype=7;    
                        else
                            acc_filenames=string([]);
                            acc_files=string([]);
                            subjectIDs="";
                            status="Unknown CSV filetype. Only ActivPAL, ActiGraph or Generic CSV files supported";
                            return;
                        end
                    elseif strcmpi(acc_filexts(1),".npy")
                        ftype=4;
                    elseif strcmpi(acc_filexts(1),".bin") || strcmpi(acc_filexts(1),".hex")
                        ftype=6;
                    else
                        acc_filenames=string([]);
                        acc_files=string([]);
                        subjectIDs="";
                        status="Unknown filetype. Only CWA, WAV, DAT, DATX, CSV, NPY or BIN files supported";
                        return;
                    end
                    % if the file list also contains the SubjectIDs we do not need to find them from filenames
                    % if the table has 
                    if ismember("ID",imptOpt.VariableNames)
                        subjectIDs=listFsT.ID;% find subjectIDs from the table, no need to analyse filenames
                        % also check for trunk filenames and load if they exist
                        if ismember("TrunkFilenames",imptOpt.VariableNames)
                            trnk_files=listFsT.TrunkFilenames;
                        end
                        % if duplicate SubjectIDs exist only select first unique cases
                        [~,iUnq]=unique(subjectIDs);
                        if length(iUnq)<length(subjectIDs) % if duplicates exist
                            subjectIDs=subjectIDs(iUnq); % only unique IDs
                            acc_filenames=acc_filenames(iUnq);
                            acc_files=acc_files(iUnq);
                            status="Duplicate IDs found. Only "+length(iUnq)+" unique IDs selected";
                        end
                        return;
                    end
             
                end
            end
        else
            % if the given excel file is not valid
            acc_filenames=string([]);
            acc_files=string([]);
            subjectIDs="";
            status="Invalid table of list of Acc filenames";
            return;
        end
    else
        % for ftype=1 to 7, the files are selected directly using the path and files returned
        % from uigetfile multi-select
        if length(files)>maxfiles
            status="Too many files selected. Only the first "+num2str(maxfiles)+" will be loaded.";
            files=files(1:maxfiles);
        end
        % convert filenames to strings. This works for a single file or
        % multiple files
        % convert filenames to column vectors
        
        acc_filenames=files'; %acc_filenames should be a column vector, so transpose
        acc_files=string(fullfile(path,files))';
    end
    
    % derive SubjectID from selected acc_files
    [~,~,acc_ext]=fileparts(acc_filenames(1)); % get the file extension of the first acc file
    extLength=strlength(acc_ext);
    if strcmpi(IDInfo.mode,"full-filename")
        subjectIDs = extractBetween(acc_filenames,1,strlength(acc_filenames)-extLength);
    elseif strcmpi(IDInfo.mode,"end")
        % find SubjectIDs from filenames
        subjectIDs = extractBetween(acc_filenames,max(strlength(acc_filenames)-IDInfo.length-extLength+1,1),strlength(acc_filenames)-extLength);
    elseif strcmpi(IDInfo.mode,"start")
        % find SubjectIDs from filenames
        subjectIDs = extractBetween(acc_filenames,1,min(strlength(acc_filenames)-extLength,IDInfo.length));
    elseif strcmpi(IDInfo.mode,"activpal")
        % find SubjectIDs from filenames
        subjectIDs=strings(length(acc_filenames),1);
        for itr=1:length(acc_filenames)
            [~,FileName,ext] = fileparts(acc_filenames(itr));
            
            if any(strcmpi(ext,[".dat",".datx",".csv",".npy"]))
                % parse ActivPAL filenames and find SubjectIDs
                patSN_ID = (textBoundary|"-")+alphanumericsPattern+"-AP" + digitsPattern(6) + whitespaceBoundary;
                textSN_ID=extract(FileName,patSN_ID);
                if ~isempty(textSN_ID)
                    
                    subjectIDs(itr)=extractBetween(textSN_ID,("-"|textBoundary),"-AP" + digitsPattern(6));
                else
                    warning('Unsupported ActivPAL filename: %s',FileName);
                    subjectIDs(itr)=FileName;
                end
                
            else
                warning('Unsupported ActivPAL filename: %s',FileName);
                subjectIDs(itr) = FileName;
            end
        end
    else
        % default mode is suffix with 10 numerals
        subjectIDs = extractBetween(acc_filenames,max(strlength(acc_filenames)-9-extLength,1),strlength(acc_filenames)-extLength);
    end
    % if duplicate SubjectIDs exist use full filename for those
    %first find the unique SubjectIDs
    [~,iA,iU]=unique(subjectIDs);
    if length(iA)<length(subjectIDs) % if duplicates exist
        %find the indices of duplicate entries
        [count,~,iCount]=histcounts(iU,length(iA));
        iNU=count(iCount)>1; %The indices of duplicate items
        subjectIDs(iNU)=extractBetween(acc_filenames(iNU),1,strlength(acc_filenames(iNU))-extLength); % replace the SUbjectIDs with full filename for duplicates
        status=status+" Filename is used instead of SubjectID for duplicate SubjectIDs";
    end
end
end
function [persT, status] = readPersonalData(persFile)
% readPersonalData  Read the personal data table used in stats generation.
%
%   [persT, status] = readPersonalData(persFile)
%
% persFile : CSV or Excel file with the columns SubjectID, Age (years), Sex (M/F),
%            Height (cm) and Weight (kg). Column names are not case-sensitive; other columns
%            are ignored. Subject IDs are read as text (matched like the diary IDs).
% persT    : table with SubjectID (string), Age, Height, Weight (double, NaN when missing or
%            out of range) and Sex ("M", "F" or missing; also accepts Male/Female, Man/Woman)
% status   : "OK", or a message why the file cannot be used. Values out of range (age 0-120,
%            height 50-250 cm, weight 10-300 kg) and duplicate IDs (the first row is used)
%            are reported as "OK: <warning>".
%
% Used by genStats: Height replaces the default height (170 cm) of the cadence based MET
% regression (O'Brien et al. 2020); Age, Sex, Height and Weight give the resting metabolic
% rate (Mifflin-St Jeor) for the individual PAEE cut-offs of the raw+posture algorithm.

% Copyright (c) 2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the ActiPASS repository (https://github.com/Ergo-Tools/ActiPASS).

persT = table();
status = "OK";
persFile = string(persFile);
if persFile == "" || ~isfile(persFile)
    status = "Personal data file not found: " + persFile;
    return;
end
try
    opts = detectImportOptions(persFile, 'VariableNamingRule', 'preserve');
    opts = setvartype(opts, opts.VariableNames, 'string');
    T = readtable(persFile, opts);
catch ME
    status = "Personal data file cannot be read: " + ME.message;
    return;
end

cols = ["SubjectID", "Age", "Sex", "Height", "Weight"];
names = string(T.Properties.VariableNames);
idx = zeros(size(cols));
for k = 1:numel(cols)
    i = find(strcmpi(strtrim(names), cols(k)), 1);
    if isempty(i)
        status = "Personal data file: column " + cols(k) + " not found (needed: " + join(cols, ", ") + ")";
        return;
    end
    idx(k) = i;
end

id = strtrim(T{:, idx(1)});
keep = ~ismissing(id) & id ~= "";
T = T(keep, :);
id = id(keep);
num = @(c, lo, hi) rangeCheck(str2double(strrep(T{:, c}, ",", ".")), lo, hi);
[age, badA] = num(idx(2), 0, 120);
[hgt, badH] = num(idx(4), 50, 250);
[weight, badW] = num(idx(5), 10, 300);
sexTxt = upper(strtrim(T{:, idx(3)}));
sex = strings(size(sexTxt));
sex(:) = missing;
sex(ismember(sexTxt, ["M", "MALE", "MAN"])) = "M";
sex(ismember(sexTxt, ["F", "FEMALE", "WOMAN"])) = "F";

persT = table(id, age, sex, hgt, weight, 'VariableNames', ["SubjectID", "Age", "Sex", "Height", "Weight"]);
[~, first] = unique(persT.SubjectID, 'stable');
warn = strings(0, 1);
if numel(first) < height(persT)
    dup = unique(persT.SubjectID(setdiff(1:height(persT), first)));
    warn(end+1) = "duplicate IDs (first row used): " + join(dup, ", ");
    persT = persT(first, :);
end
bad = [badA, badH, badW];
labels = ["age", "height", "weight"];
if any(bad(:))
    for k = find(any(bad, 1))
        warn(end+1) = labels(k) + " out of range for " + sum(bad(:, k)) + " ID(s), not used"; %#ok<AGROW>
    end
end
if ~isempty(warn)
    status = "OK: personal data file: " + join(warn, "; ");
end
end

function [v, bad] = rangeCheck(v, lo, hi)
% values outside [lo, hi] become NaN (bad marks them)
bad = ~isnan(v) & (v < lo | v > hi);
v(bad) = NaN;
end

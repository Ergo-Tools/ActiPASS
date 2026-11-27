function info = intensityPAEE(rawAcc, timeFull, aktFull, modelsFile, outFile)
% intensityPAEE  PAEE per 10 s window from raw thigh acceleration and the 1 s activities: the
% MATLAB version of IntensityCal.R (INT_ALG "raw+posture (M)").
%   info = intensityPAEE(rawAcc, timeFull, aktFull, modelsFile, outFile)
%   rawAcc     : [time x y z], time as datenum (the processed thigh data, 25 Hz in Actipass)
%   timeFull   : 1 s times (datenum); aktFull: activity per second
%   modelsFile : IntensityModels.json (written by exportIntensityModels.R from the .rds models)
%   outFile    : "<ID> - PAEE.bin" (writeAPBin) with the columns time (window start, datenum),
%                activity (most frequent per 10 s), paee (kJ/kg/min) and the features the models
%                use: the same file as IntensityCal.R writes. "" = do not write.
%   info       : struct with log (string lines for "<ID> - IntAlgOut.txt"), T (the output
%                table), nPred (windows per model) and Fs.
%
% The features are those of IntensityCal.R's extract.features(), computed over the magnitude
% spectrum (without DC) of each 10 s window of vm, x, y and z (16 per axis, named <feature>_<axis>);
% only the features the models use are computed. Differences from R are rounding only (FFT
% implementation, R's long-double sums in mean/sd/cor); PAEE agrees to ~1e-15 kJ/kg/min.
% No toolbox functions are used.
%
% EXPERIMENTAL: the raw+posture algorithm and its models (MARS models from a separate study, given
% in IntensityModels.json) are still being evaluated; check the results before you use them.
% The R version (IntensityCal.R, the .rds models and exportIntensityModels.R) is not part of the
% public Actipass repository.

% Copyright (c) 2026, Pasan Hettiarachchi and Peter Johansson
% SPDX-License-Identifier: BSD-3-Clause
% See LICENSES/BSD-3-Clause.txt of the Actipass repository (https://github.com/Ergo-Tools/ActiPASS).

tStart = tic;
M = jsondecode(fileread(modelsFile));
if ~isfield(M, 'format') || ~strcmp(M.format, 'Actipass intensity models 1')
    error('intensityPAEE:models', '%s: unknown model file format', modelsFile);
end
models = M.models;
if ~iscell(models), models = num2cell(models); end
lg = "intensityPAEE.m  " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')) + "  MATLAB " + version;
lg(end+1) = "  models:      " + modelsFile;

% sampling frequency as IntensityCal.R: from the first 2000 sample times
tSec = (rawAcc(1:min(2000, size(rawAcc,1)), 1) - 719529) * 86400;
Fs = round(1 / mean(diff(tSec)));
win = M.windowSec * Fs;
n = size(rawAcc, 1);
nWinRaw = ceil(n / win);
lg(end+1) = sprintf("  raw data:    %d samples at %d Hz -> %d windows of %d s", n, Fs, nWinRaw, M.windowSec);
if ~all(isfinite(rawAcc(:, 2:4)), 'all')
    error('intensityPAEE:data', 'rawAcc contains NaN/Inf values');
end

% features needed by the models, grouped by axis
vars = strings(0, 1);
for k = 1:numel(models)
    vars = [vars; string(models{k}.variables(:))]; %#ok<AGROW>
end
vars = unique(vars, 'stable');
axNames = ["vm" "x" "y" "z"];
F = struct();
for a = axNames
    need = extractBefore(vars(endsWith(vars, "_" + a)), "_" + a);
    if isempty(need), continue; end
    switch a
        case "vm", sig = sqrt(rawAcc(:,2).^2 + rawAcc(:,3).^2 + rawAcc(:,4).^2);
        case "x",  sig = rawAcc(:,2);
        case "y",  sig = rawAcc(:,3);
        case "z",  sig = rawAcc(:,4);
    end
    W = toWindows(sig, win);
    ms = abs(fft(W));                       % magnitude spectrum of each window (columns)
    A = ms(2:win/2+1, :);                   % without DC (R: ms[-1, ] of rows 1..win/2+1)
    vals = spectrumFeatures(A, Fs, need);
    for j = 1:numel(need)
        F.(need(j) + "_" + a) = vals{j};
    end
end
% NaN features -> 0 and infinite features -> NaN (R: NA), as IntensityCal.R
for v = vars'
    x = F.(v);
    iNaN = isnan(x);
    x(isinf(x)) = NaN;
    x(iNaN) = 0;
    F.(v) = x;
end

% window start times and the most frequent activity per 10 s (smallest code on ties)
tWin = rawAcc(1:win:n, 1);
if numel(timeFull) ~= numel(aktFull)   % timeFull is only checked: the windows start with the raw data
    error('intensityPAEE:data', 'timeFull and aktFull differ in length');
end
act = mode(toWindows(aktFull(:), M.windowSec), 1)';
lg(end+1) = sprintf("  activity:    %d s -> %d windows of %d s", numel(aktFull), numel(act), M.windowSec);
nWin = min(numel(act), nWinRaw);
if numel(act) ~= nWinRaw
    lg(end+1) = sprintf("  window counts differ (raw %d, activity %d): the first %d are used", nWinRaw, numel(act), nWin);
end
act = act(1:nWin);
tWin = tWin(1:nWin);
for v = vars'
    F.(v) = F.(v)(1:nWin);
end

% PAEE: the model of each activity, fixed values, else the default
paee = repmat(M.defaultPAEE, nWin, 1);
nPred = struct();
for k = 1:numel(models)
    m = models{k};
    e = ismember(act, m.activity);
    nPred.(m.name) = nnz(e);
    terms = m.terms;
    if ~iscell(terms), terms = num2cell(terms); end
    y = zeros(nnz(e), 1);
    for t = 1:numel(terms)
        b = ones(nnz(e), 1);
        tv = string(terms{t}.vars);
        for f = 1:numel(tv)
            x = F.(tv(f))(e);
            switch terms{t}.dirs(f)
                case 1,  h = max(0, x - terms{t}.cuts(f));
                case -1, h = max(0, terms{t}.cuts(f) - x);
                case 2,  h = x;
                otherwise, error('intensityPAEE:models', 'unsupported dirs value %g', terms{t}.dirs(f));
            end
            h(isnan(x)) = NaN;              % max() would drop the NaN (R: predict gives NA)
            b = b .* h;
        end
        y = y + terms{t}.coef * b;
    end
    paee(e) = y;
end
fixed = M.fixed;
if ~iscell(fixed), fixed = num2cell(fixed); end
for k = 1:numel(fixed)
    e = ismember(act, fixed{k}.activity);
    paee(e) = fixed{k}.paee;
    if isscalar(fixed), fName = "other"; else, fName = "fixed" + k; end
    nPred.(fName) = nnz(e);
end
fn = string(fieldnames(nPred))';
lg(end+1) = "  PAEE models: " + join(fn + " " + string(struct2cell(nPred))', ", ") + ...
    " windows (" + (nWin - sum(cell2mat(struct2cell(nPred)))) + " windows of the remaining activities: PAEE " + M.defaultPAEE + ")";

% output table: as IntensityCal.R (time, activity, paee, the model features)
Mout = [tWin, act, paee, zeros(nWin, numel(vars))];
for j = 1:numel(vars)
    Mout(:, 3+j) = F.(vars(j));
end
names = ["time" "activity" "paee" vars'];
if strlength(string(outFile)) > 0
    writeAPBin(string(outFile), Mout, names);
    [~, fName, fExt] = fileparts(string(outFile));
    lg(end+1) = sprintf("  saved:       %s (%d windows; %s) in %.1f s", fName + fExt, nWin, join(names, ", "), toc(tStart));
end
info = struct('log', lg', 'T', array2table(Mout, 'VariableNames', cellstr(names)), 'nPred', nPred, 'Fs', Fs);
end

function W = toWindows(x, win)
% Fold x into windows of win samples (one per column); the last, incomplete window is filled
% by recycling x from its start (as IntensityCal.R's toWindows / R's matrix()).
n = numel(x);
nwin = ceil(n / win);
idx = mod(0:win*nwin-1, n) + 1;
W = reshape(x(idx), win, nwin);
end

function vals = spectrumFeatures(A, Fs, need)
% The features of IntensityCal.R's extract.features() for the columns of A (the magnitude
% spectrum without DC, N = wind rows), only those named in need:
% Power253 Power1315 DomF253 DomF1315 Mean SD SigPow LAG1 Median MAD P10 P25 P75 P90 Shannon Sum1315
N = size(A, 1);
nw = size(A, 2);
vals = cell(1, numel(need));
S = []; P = []; i2 = []; i3 = [];
r2 = 1:floor(N/10);                                  % R: trunc(1:(wind/10))
r3 = fix((N/3+1) + (0:floor((N/2+1) - (N/3+1))));    % R: trunc((wind/3+1):(wind/2+1))
f = (0:floor(N/2)) / N;
for j = 1:numel(need)
    switch need(j)
        case {"Power253", "Power1315", "DomF253", "DomF1315", "Shannon", "Sum1315"}
            if isempty(P)
                mu = mean(A, 1);
                P = (4/N) * abs(fft(A - mu) / sqrt(N)).^2;   % periodogram of the spectrum
                [~, i2] = max(P(r2, :), [], 1);              % first maximum (R: max.col "first")
                [~, i3] = max(P(r3, :), [], 1);
            end
            switch need(j)
                case "Power253",  v = P(sub2ind(size(P), r2(i2), 1:nw));
                case "Power1315", v = P(sub2ind(size(P), r3(i3), 1:nw));
                case "DomF253",   v = Fs * f(r2(i2));
                case "DomF1315",  v = Fs * f(r3(i3));
                case "Shannon",   v = colShannon(P);
                case "Sum1315",   v = sum(P(r3, :), 1);
            end
        case "Mean"   % R: mean(A, trim = .05)
            if isempty(S), S = sort(A, 1); end
            lo = floor(N * 0.05) + 1;
            v = mean(S(lo:N+1-lo, :), 1);
        case "SD"
            v = std(A, 0, 1);
        case "SigPow"
            v = sum(A .* A, 1);
        case "LAG1"   % R: cor(A[1:(N-1)], A[2:N])
            x = A(1:N-1, :) - mean(A(1:N-1, :), 1);
            y = A(2:N, :) - mean(A(2:N, :), 1);
            v = sum(x .* y, 1) ./ sqrt(sum(x .* x, 1) .* sum(y .* y, 1));
        case "Median"
            if isempty(S), S = sort(A, 1); end
            v = colMedianSorted(S);
        case "MAD"    % R: 1.4826 * median(|x - median(x)|) of |A|
            X = abs(A);
            D = abs(X - colMedianSorted(sort(X, 1)));
            v = 1.4826 * colMedianSorted(sort(D, 1));
        case {"P10", "P25", "P75", "P90"}
            if isempty(S), S = sort(A, 1); end
            v = colQuantile7(S, str2double(extractAfter(need(j), "P")) / 100);
        otherwise
            error('intensityPAEE:features', 'unknown feature "%s"', need(j));
    end
    vals{j} = v(:);
end
end

function m = colMedianSorted(S)
% median of each column of the column-sorted S
n = size(S, 1);
h = floor((n + 1) / 2);
if mod(n, 2) == 1
    m = S(h, :);
else
    m = (S(h, :) + S(h+1, :)) / 2;
end
end

function q = colQuantile7(S, p)
% type-7 quantile (R's default) of each column of the column-sorted S, as IntensityCal.R
n = size(S, 1);
idx = 1 + max(n - 1, 0) * p;
lo = floor(idx);
hi = ceil(idx);
q = S(lo, :);
xh = S(hi, :);
h = idx - lo;
i = idx > lo & xh ~= q;
q(i) = (1 - h) * q(i) + h * xh(i);
end

function e = colShannon(P)
% entropy of each column of the non-negative P, as IntensityCal.R's colShannon
s = sum(P, 1);
Pn = P ./ s;
E = log2(Pn) .* Pn;
E(~(P > 0)) = 0;
e = -sum(E, 1);
e(any(isnan(P), 1) | any(P < 0, 1) | ~(s > 0)) = NaN;
end

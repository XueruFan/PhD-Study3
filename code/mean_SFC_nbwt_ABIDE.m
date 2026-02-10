%% ============================================================
%  Compute mean zSFC per subtype per step
%  Save full zSFC matrices as CSV
% ============================================================

clear; clc;

%% ----------------------------
% Paths
% ----------------------------
sfc_dir   = '/Volumes/Zuolab_XRF/data/abide/SFCnbtw';
csv_file  = '/Volumes/Zuolab_XRF/output/abide/sfc/sfc_participant_summary.csv';
out_dir   = '/Volumes/Zuolab_XRF/output/abide/sfc/stat/meanzSFC';

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

%% ----------------------------
% Load participant info
% ----------------------------
T = readtable(csv_file);

if ~isnumeric(T.Subject)
    T.Subject = str2double(string(T.Subject));
end

%% ----------------------------
% Scan SFC files
% ----------------------------
files = dir(fullfile(sfc_dir, '*.mat'));
files = files(~startsWith({files.name}, '._'));

fprintf('Found %d SFC files\n', numel(files));

%% ----------------------------
% Container: subtype × step
% ----------------------------
data = struct();

%% ----------------------------
% Loop over files
% ----------------------------
for i = 1:numel(files)

    fname = files(i).name;

    % ---- Extract subject ID (remove leading zeros) ----
    token_id = regexp(fname, '^0*(\d+)_', 'tokens');
    if isempty(token_id)
        warning('Cannot parse subject ID from %s', fname);
        continue;
    end
    subj_id = str2double(token_id{1}{1});

    % ---- Extract step ----
    token_step = regexp(fname, 'step(\d+)\.mat$', 'tokens');
    if isempty(token_step)
        warning('Cannot parse step from %s', fname);
        continue;
    end
    step = sprintf('step%02d', str2double(token_step{1}{1}));

    % ---- Match subject ----
    idx = find(T.Subject == subj_id, 1);
    if isempty(idx)
        fprintf('Subject %d not found in CSV, skipping\n', subj_id);
        continue;
    end

    subtype_raw = T.Subtype{idx};                  % 原始 subtype（如 'ASD-H'）
    subtype = matlab.lang.makeValidName(subtype_raw);  % 安全字段名（如 'ASD_H'）

    % ---- Load zSFC ----
    S = load(fullfile(files(i).folder, fname));

    if isfield(S, 'zSFC')
        zSFC = S.zSFC;
    else
        error('zSFC variable not found in %s', fname);
    end

    % ---- Initialize containers ----
    if ~isfield(data, subtype)
        data.(subtype) = struct();
    end
    if ~isfield(data.(subtype), step)
        data.(subtype).(step) = [];
    end

    % ---- Accumulate ----
    data.(subtype).(step) = cat(3, data.(subtype).(step), zSFC);

end

%% ----------------------------
% Compute mean & save matrices
% ----------------------------
subtypes = fieldnames(data);

for i = 1:numel(subtypes)

    st = subtypes{i};
    steps = fieldnames(data.(st));

    for j = 1:numel(steps)

        step = steps{j};
        z_all = data.(st).(step);

        if isempty(z_all)
            continue;
        end

        % Mean across subjects
        z_mean = mean(z_all, 3, 'omitnan');

        % Save full matrix
        out_file = fullfile(out_dir, sprintf('zSFC_mean_%s_%s.csv', st, step));

        writematrix(z_mean, out_file);

        fprintf('Saved matrix: %s\n', out_file);
    end
end

fprintf('All subtype × step zSFC matrices saved.\n');

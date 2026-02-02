% =========================================================
% rDCM pipeline for CKG and PEK datasets
% Using bilateral ROI time series
% Classic rDCM (no sparsity)
% =========================================================

clear; clc;

data_root = 'E:\PhDproject\Study3\data\timeseries\fsaverage5';

datasets = {'CKG', 'PEK'};

addpath(genpath('C:\matlab-toolbox\tapas'));

nROI = 15;

% ---- dataset-specific TR (seconds)
TR_map = containers.Map( ...
    {'CKG','PEK'}, ...
    {2.5 , 2.0 });

%% -------------------- rDCM without sparsity -------------------------

out_root  = 'E:\PhDproject\Study3\output\rDCM';

if ~exist(out_root, 'dir')
    mkdir(out_root);
end

for d = 1:numel(datasets)

    dataset = datasets{d};
%     fprintf('\n========== Dataset: %s ==========\n', dataset);

    if ~isKey(TR_map, dataset)
        error('No TR defined for dataset %s', dataset);
    end

    TR = TR_map(dataset);
    data_path = fullfile(data_root, dataset);

    sub_dirs = dir(fullfile(data_path, 'sub-*'));
    sub_dirs = sub_dirs([sub_dirs.isdir]);

%     fprintf('Found %d subject/session folders\n', numel(sub_dirs));

    for s = 1:numel(sub_dirs)

        sub_folder = fullfile(data_path, sub_dirs(s).name);
%         fprintf('\nSubject/session: %s\n', sub_dirs(s).name);

        ts_files = dir(fullfile(sub_folder, '*_network_ts.mat'));

        if isempty(ts_files)
            warning('No time series files in %s', sub_dirs(s).name);
            continue;
        end

        for f = 1:numel(ts_files)

            fn = ts_files(f).name;
            load(fullfile(sub_folder, fn));   % loads ROI_ts_bilat etc.

%             fprintf('  Run: %s\n', runName);

            if size(ROI_ts_bilat, 1) ~= nROI
                error('ROI number mismatch in %s', fn);
            end

            Y.y  = ROI_ts_bilat';   % [T x ROI]
            Y.dt = TR;

            DCM = tapas_rdcm_model_specification(Y, [], []);
            rDCM = tapas_rdcm_estimate(DCM, 'r', [], 1);

            EC = rDCM.Ep.A;

            out_sub = fullfile(out_root, dataset, sub_dirs(s).name);
            if ~exist(out_sub, 'dir')
                mkdir(out_sub);
            end

            out_fn = sprintf('%s_%s_rDCM.mat', sub_dirs(s).name, runName);
            save(fullfile(out_sub, out_fn), ...
                 'EC', 'dataset', 'runName', 'subName', 'TR');

        end
    end
end

fprintf('rDCM Done!\n');

%% -------------------- rDCM with sparsity -------------------------

out_root  = 'E:\PhDproject\Study3\output\srDCM';

if ~exist(out_root, 'dir')
    mkdir(out_root);
end

for d = 2%:numel(datasets)

    dataset = datasets{d};
%     fprintf('\n========== Dataset: %s ==========\n', dataset);

    if ~isKey(TR_map, dataset)
        error('No TR defined for dataset %s', dataset);
    end

    TR = TR_map(dataset);
    data_path = fullfile(data_root, dataset);

    sub_dirs = dir(fullfile(data_path, 'sub-*'));
    sub_dirs = sub_dirs([sub_dirs.isdir]);

%     fprintf('Found %d subject/session folders\n', numel(sub_dirs));

    for s = 1:numel(sub_dirs)

        sub_folder = fullfile(data_path, sub_dirs(s).name);
%         fprintf('\nSubject/session: %s\n', sub_dirs(s).name);

        ts_files = dir(fullfile(sub_folder, '*_network_ts.mat'));

        if isempty(ts_files)
            warning('No time series files in %s', sub_dirs(s).name);
            continue;
        end

        for f = 1:numel(ts_files)

            fn = ts_files(f).name;
            load(fullfile(sub_folder, fn));   % loads ROI_ts_bilat etc.

%             fprintf('  Run: %s\n', runName);

            if size(ROI_ts_bilat, 1) ~= nROI
                error('ROI number mismatch in %s', fn);
            end

            Y.y  = ROI_ts_bilat';   % [T x ROI]
            Y.dt = TR;

            DCM = tapas_rdcm_model_specification(Y, [], []);
            rDCM = tapas_rdcm_estimate(DCM, 'r', [], 2);

            EC = rDCM.Ep.A;

            out_sub = fullfile(out_root, dataset, sub_dirs(s).name);
            if ~exist(out_sub, 'dir')
                mkdir(out_sub);
            end

            out_fn = sprintf('%s_%s_srDCM.mat', sub_dirs(s).name, runName);
            save(fullfile(out_sub, out_fn), ...
                 'EC', 'dataset', 'runName', 'subName', 'TR');

        end
    end
end

fprintf('srDCM Done!\n');


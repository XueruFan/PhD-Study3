clear; clc;

ccnp_root = 'E:\PhDproject\Study3\output';
rdcm_root = fullfile(ccnp_root, 'rDCM');
stat_root = fullfile(ccnp_root, 'stats');

if ~exist(stat_root, 'dir')
    mkdir(stat_root);
end

out_xlsx = fullfile(stat_root, 'CCNP_rDCM_summary.xlsx');

datasets = {'CKG','PEK'};
nROI = 15;
nEC  = nROI * nROI;

% ==================================================
% 统计总行数（subject × run）
% ==================================================
nRow = 0;
for d = 1:numel(datasets)
    data_path = fullfile(rdcm_root, datasets{d});
    sub_dirs = dir(fullfile(data_path, 'sub-*'));
    sub_dirs = sub_dirs([sub_dirs.isdir]);
    for s = 1:numel(sub_dirs)
        mat_files = dir(fullfile(sub_dirs(s).folder, sub_dirs(s).name, '*_rDCM.mat'));
        nRow = nRow + numel(mat_files);
    end
end

fprintf('Total rows (subject × run): %d\n', nRow);

% ==================================================
% 预分配
% ==================================================
EC_all  = zeros(nRow, nEC);
subject = cell(nRow, 1);
site    = cell(nRow, 1);
run     = cell(nRow, 1);

row = 1;

% ==================================================
% 主循环
% ==================================================
for d = 1:numel(datasets)

    dataset = datasets{d};
    data_path = fullfile(rdcm_root, dataset);

    sub_dirs = dir(fullfile(data_path, 'sub-*'));
    sub_dirs = sub_dirs([sub_dirs.isdir]);

    for s = 1:numel(sub_dirs)

        sub_path = fullfile(data_path, sub_dirs(s).name);
        mat_files = dir(fullfile(sub_path, '*_rDCM.mat'));

        for f = 1:numel(mat_files)

            load(fullfile(sub_path, mat_files(f).name));

            subject{row} = subName;
            site{row}    = dataset;
            run{row}     = runName;

            % ------------------------------------------
            % EC(from, to) → row vector (from → to)
            % ------------------------------------------
            EC_all(row, :) = reshape(EC', 1, []);

            row = row + 1;
        end
    end
end

% ==================================================
% 列名（from → to）
% ==================================================
colNames = cell(1, nEC);
k = 1;
for from = 1:nROI
    for to = 1:nROI
        colNames{k} = sprintf('EC_%02d_to_%02d', from, to);
        k = k + 1;
    end
end

% ==================================================
% 写 CSV
% ==================================================
T = array2table(EC_all, 'VariableNames', colNames);
T = addvars(T, subject, site, run, 'Before', 1);

writetable(T, out_xlsx);

fprintf('Done!');

clear; clc;

%% =========================
% Paths (Windows)
data_root = 'E:\PhDproject\Study3\data\timeseries\fsaverage5';
out_root  = 'E:\PhDproject\Study3\output\SFC';

if ~exist(out_root, 'dir')
    mkdir(out_root);
end

% Toolboxes
% addpath(genpath('E:\toolbox\CCS-master'));              % CCS 工具箱路径
addpath(genpath('E:\DCM-Project-PhD-Study3-\code'));    % 你的工程代码路径

%% =========================
step_max = 8;      % 最大 SFC 步数
zflag    = true;   % 是否做 z-score

sites = {'CKG', 'PEK'};

%% =========================
for iSite = 1:numel(sites)

    site = sites{iSite};
    fprintf('\n===== Site: %s =====\n', site);

    site_dir = fullfile(data_root, site);
    subj_dirs = dir(fullfile(site_dir, 'sub-*'));
    subj_dirs = subj_dirs([subj_dirs.isdir]);

    for iSub = 1:numel(subj_dirs)

        subj_name = subj_dirs(iSub).name;
        subj_path = fullfile(site_dir, subj_name);

        fprintf('\nSubject: %s\n', subj_name);

        ts_files = dir(fullfile(subj_path, 'rest*_DU15_network_ts.mat'));

        for iRun = 1:numel(ts_files)

            ts_file = ts_files(iRun).name;
            ts_path = fullfile(subj_path, ts_file);

            fprintf('  Processing %s\n', ts_file);

            %% -------- Load time series --------
            load(ts_path, 'ROI_ts_bilat');

            N = size(ROI_ts_bilat, 1);

            %% -------- FC --------
            FC = corr(ROI_ts_bilat');
            FC(1:N+1:end) = 0;

            absFC = abs(FC);

            %% -------- 稀疏化：每个节点至少一条边 --------
            adj = zeros(N, N);

            for i = 1:N
                row = absFC(i,:);
                row(i) = 0;
                [~, idx] = max(row);
                adj(i, idx) = 1;
            end

            adj = max(adj, adj');  % 无向化

            %% -------- SFC --------
            for Sstep = 1:step_max

                SFC = ccs_core_graphwalk_old(adj, Sstep, 'normal');
                SFC(1:N+1:end) = 0;

                if zflag
                    mu  = mean(SFC, 2);
                    sig = std(SFC, 0, 2);
                    zSFC = (SFC - mu) ./ sig;
                    zSFC(isnan(zSFC)) = 0;
                else
                    zSFC = [];
                end

                tmp = zSFC;
                tmp(1:N+1:end) = NaN;
                Embedding = mean(tmp, 2, 'omitnan');

               %% -------- Parse names --------
                % subj_name: sub-CCNPCKG0004_ses01
                tokens = regexp(subj_name, 'sub-CCNP([A-Z]+)(\d+)_ses(\d+)', 'tokens');
                siteID = tokens{1}{1};   % CKG
                subID  = tokens{1}{2};   % 0004
                sesID  = tokens{1}{3};   % 01
                
                % runname: rest1_DU15_network_ts -> rest1_DU15
                [~, runname, ~] = fileparts(ts_file);
                run_clean = erase(runname, '_network_ts');

                %% -------- Save --------
                save_name = sprintf('%s%s_ses%s_%s_SFC_step%02d.mat', ...
                                    siteID, subID, sesID, run_clean, Sstep);
                
                save(fullfile(out_root, save_name), ...
                     'SFC', 'zSFC', 'Embedding');
                
                clear SFC zSFC Embedding mu sig tmp
            end

            clear ROI_ts_bilat FC absFC adj
        end
    end
end

fprintf('\n===== ALL DONE =====\n');

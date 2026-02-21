clear; clc;

%% =========================
% Paths
data_root = 'E:\PhDproject\Study3\data\timeseries\fslr10k';
out_root  = 'E:\PhDproject\Study3\output\zSFEI';

if ~exist(out_root, 'dir')
    mkdir(out_root);
end

addpath(genpath('E:\PhDproject\Study3\code'));

step_max = 7;

%% =========================
% 直接读取所有时间序列文件
ts_files = dir(fullfile(data_root, '*_DU15_network_ts.mat'));

fprintf('Found %d subjects\n', numel(ts_files));

%% =========================
for iFile = 1:numel(ts_files)

    ts_file = ts_files(iFile).name;
    ts_path = fullfile(data_root, ts_file);

    fprintf('\nProcessing %s\n', ts_file);

    %% -------- Load --------
    load(ts_path, 'ROI_ts');

    N = size(ROI_ts, 1);

    %% -------- FC --------
    FC = corr(ROI_ts');
    FC(1:N+1:end) = 0;

    absFC = abs(FC);

    %% -------- 稀疏化 --------
    adj = zeros(N, N);

    for i = 1:N
        row = absFC(i,:);
        row(i) = 0;
        [~, idx] = max(row);
        adj(i, idx) = 1;
    end

    adj = max(adj, adj');  % 无向化

    %% =====================================================
    %  Parse filename
    %  格式: CCNPPEK0007_01_rest01_DU15_network_ts.mat
    %% =====================================================
    tokens = regexp(ts_file, ...
        '(CCNP[A-Z]+\d+_\d+)_(rest\d+)_DU15_network_ts', ...
        'tokens');

    subjID = tokens{1}{1};   % CCNPPEK0007_01
    runID  = tokens{1}{2};   % rest01

    %% =====================================================
    %  SFC loop
    %% =====================================================
    for Sstep = 1:step_max
    
        % -------- SFC --------
        SFC = ccs_core_graphwalk_old(adj, Sstep, 'nbtw');
        SFC(1:N+1:end) = 0;
    
        % -------- 计算 SFEI（每行平均，去掉自连接）--------
        tmp = SFC;
        tmp(1:N+1:end) = NaN;
    
        SFEI = mean(tmp, 2, 'omitnan');   % 每个节点一个值
    
        % -------- step 内层级标准化 --------
        muS  = mean(SFEI);
        sigS = std(SFEI);
    
        zSFEI = (SFEI - muS) ./ sigS;
        zSFEI(isnan(zSFEI)) = 0;
    
        %% -------- Save --------
        save_name = sprintf('%s_%s_DU15_zSFEI_step%02d.mat', ...
                            subjID, runID, Sstep);
    
        save(fullfile(out_root, save_name), ...
             'SFC', 'SFEI', 'zSFEI');
    
        clear SFC SFEI zSFEI muS sigS tmp
    end

    clear ROI_ts FC absFC adj
end

fprintf('\n===== ALL DONE =====\n');

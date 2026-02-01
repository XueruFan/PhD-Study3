clear; clc;

%% =========================
data_root = '/Volumes/Zuolab_XRF/data/abide/timeseries';
cd(data_root)
out_root  = '/Volumes/Zuolab_XRF/data/abide/SFC';

if ~exist(out_root, 'dir')
    mkdir(out_root);
end

addpath(genpath('/Users/xuerufan/matlab-toolbox/CCS-master'));  % CCS 工具箱路径

files = dir(fullfile(data_root, '*_network_ts.mat'));
files = files(~startsWith({files.name}, '._'));

nSub  = length(files);

step_max  = 8;      % 最大步数
sparsity = 0.10;   % 卡10%阈值
zflag    = true;   % 是否做 z-score

%% =========================
for iSub = 1:nSub
    
    fprintf('Subject %d / %d\n', iSub, nSub);
    
    load(fullfile(data_root, files(iSub).name));
    
    N = size(ROI_ts,1); % ROI个数
    
    % -------- FC --------
    FC = corr(ROI_ts');
    FC(1:N+1:end) = 0; %自相关为0
    
    % -------- 稀疏化（按绝对值）--------
    absFC = abs(FC);
    edge_vec = sort(absFC(:), 'descend');
    nkeep = round(sparsity * N * (N - 1));
    thr = edge_vec(nkeep);
    
    adj = absFC >= thr;
    adj = triu(adj,1) + triu(adj,1)';   % 无向二值图
    
    % -------- SFC--------
    for S = 1:step_max
        
        SFC = ccs_core_graphwalk_old(adj, S, 'normal');
        SFC(1:N+1:end) = 0;
        
        if zflag
            mu  = mean(SFC, 2);
            sig = std(SFC, 0, 2);
            zSFC = (SFC - mu) ./ sig;
            zSFC(isnan(zSFC)) = 0;
        else
            zSFC = [];
        end
        
        [~, subname, ~] = fileparts(files(iSub).name);
        save_name = sprintf('%s_SFC_step%02d.mat', subname, S);
        save(fullfile(out_root, save_name), 'SFC', 'zSFC');
        
        clear SFC zSFC mu sig
    end
    
    clear ts FC absFC adj
end

fprintf('Done!\n');

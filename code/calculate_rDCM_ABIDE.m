% =========================================================
% rDCM analysis for ABIDE ROI time series
% Site-specific TR handling
% Classic rDCM (no sparsity)
% 用tapas工具包，计算每个被试、每个run的有效连接矩阵EC，没有进行sparsity约束
% 有没有 sparsity 的 rDCM，本质区别在于：是否“先验上相信大多数脑区之间是没有直接因果影响的”。
% 无 sparsity 的 rDCM 假设 所有脑区之间都可能存在有效连接
% 有 sparsity 的 rDCM 假设 真实有效连接是稀疏的，大多数连接应当为 0
% Xueru 16-Dec-2021 @BNU
% =========================================================

clear; clc;

%% -------------------- paths -----------------------------
data_root = '/Volumes/Zuolab_XRF/data/abide/';
ts_path   = fullfile(data_root, 'timeseries');
out_path  = fullfile(data_root, 'rDCM');

if ~exist(out_path, 'dir')
    mkdir(out_path);
end

addpath(genpath('/Users/xuerufan/matlab-toolbox/tapas'));

nROI = 15;

% ---- site-specific TR (seconds)
TR_map = containers.Map( ...
    {'IP','NYU','Pitt','TCD','USM'}, ...
    {2.7 , 2.0 , 1.5  , 2.0 , 2.0 });

%% -------------------- list files ------------------------
all_files = dir(fullfile(ts_path, '*_network_ts.mat'));
files = all_files(~startsWith({all_files.name}, '._'));

nFiles = numel(files);

% fprintf('Found %d time series files\n', nFiles);

%% -------------------- main loop -------------------------
for i = 1:nFiles

    % load data
    fn = files(i).name;
    load(fullfile(ts_path, fn));   % ROI_ts, siteName, subName

    fprintf('Processing subject %s (site %s)\n', subName, siteName);

    % sanity checks
    if size(ROI_ts, 1) ~= nROI
        error('ROI number mismatch in %s', fn);
    end

    if ~isKey(TR_map, siteName)
        error('Unknown siteName "%s" in %s', siteName, fn);
    end

    TR = TR_map(siteName);
    Y.y  = ROI_ts';     % [T x ROI]
    Y.dt = TR;

    DCM = tapas_rdcm_model_specification(Y, [], []);
    rDCM = tapas_rdcm_estimate(DCM, 'r', [], 1);

    EC = rDCM.Ep.A;

    out_fn = sprintf('%s_DU15_rDCM.mat', subName);
    save(fullfile(out_path, out_fn),'EC', 'siteName', 'subName', 'TR');

end

fprintf('Done!\n');

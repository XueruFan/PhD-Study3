%% ============================================================
%  Export fsLR32k ROI to Workbench metric (.func.gii)

%  把fsLR-32k网格上的ROI导出为Workbench的surface metric文件
%  文件类型：GIFTI surface metric；长度 = 32492个顶点；数值：1属于该网络ROI，0不属于
%  .func.gii：是 Connectome Workbench 的原生格式
%   可以直接用于：wb_command -metric-resample，sphere-based mapping
%   能够明确绑定到 fsLR-32k 的 midthickness / sphere

%  Xueru Fan  Jan 2026
% ============================================================

clear; clc;

projFolder = '/Users/xuerufan/DCM-Project-PhD-Study3-';
cd(fullfile(projFolder, 'output'))

load('DU15NET_connected_core_ROI.mat');

outdir = fullfile(pwd, 'ROI_fsLR32k');
if ~exist(outdir, 'dir')
    mkdir(outdir);
end

%% Load fsLR32k reference surface (LH / RH)
lh_surf_ft = ft_read_headshape( ...
    fullfile(projFolder, 'templet', 'fsLR32k', 'fs_LR.32k.L.midthickness.surf.gii'));

rh_surf_ft = ft_read_headshape( ...
    fullfile(projFolder, 'templet', 'fsLR32k', 'fs_LR.32k.R.midthickness.surf.gii'));

Nvert = size(lh_surf_ft.pos, 1);  % 32492

for net = 1:15
%     net = 1;

    % ---------- Left hemisphere ----------
    lh_metric = zeros(Nvert,1);
    if ~isempty(ROI(net).LH)
        lh_metric(ROI(net).LH) = 1;
    end

    gL = gifti;
    gL.cdata = lh_metric;   % 只写 cdata
    save(gL, fullfile(outdir, sprintf('lh.DU15Net%d_fsLR32k.func.gii', net)));

    % ---------- Right hemisphere ----------
    rh_metric = zeros(Nvert,1);
    ROI(net).RH = ROI(net).RH - 32492; % 左右半球是分开的
    if ~isempty(ROI(net).RH)
        rh_metric(ROI(net).RH) = 1;
    end

    gR = gifti;
    gR.cdata = rh_metric;
    save(gR, fullfile(outdir, sprintf('rh.DU15Net%d_fsLR32k.func.gii', net)));

end

disp('DONE!');

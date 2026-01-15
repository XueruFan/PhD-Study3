%% ============================================================
%  Connected core ROI definition for DCM (fsLR-32k)
%
%  - 不固定 ROI 大小
%  - 基于 probability 阈值
%  - 保证空间连通
%  - 可设置最大 ROI size（region growing）
%
%  Xueru Fan  Jan 11 2026  @DK
% ============================================================

clear; clc;

%% -------------------- 参数设置 --------------------

projFolder = '/Users/xuerufan/DCM-Project-PhD-Study3-';
cd(projFolder)

nNetworks    = 15;     % 网络数量
prob_thresh  = 0.8;    % probability 阈值
max_roi_size = 10;     % ROI 最大顶点数（可调）

%% -------------------- 文件路径 --------------------

tempFolder = fullfile(projFolder, 'templet');

consensus_file = fullfile(tempFolder, ...
    'DU15NET_consensus_fsLR_32k.dlabel.nii');

agreeprob_file = fullfile(tempFolder, ...
    'DU15NET_AgreeProb_fsLR_32k.dscalar.nii');

lh_surf_file = fullfile(tempFolder, ...
    'fs_LR.32k.L.white.surf.gii');

rh_surf_file = fullfile(tempFolder, ...
    'fs_LR.32k.R.white.surf.gii');

out_vis_file = fullfile(projFolder, 'visual', ...
    'DU15NET_connected_core_ROI_visual.dlabel.nii');

%% -------------------- 读取 CIFTI --------------------

consensus = cifti_read(consensus_file);
agreeprob = cifti_read(agreeprob_file);

network_label = consensus.cdata;    % 每个 vertex 的网络标签
probability   = agreeprob.cdata;    % 每个 vertex 的 probability

assert(numel(network_label) == numel(probability), ...
    'Consensus 与 probability 尺寸不一致');

%% -------------------- 半球定义 --------------------

N_LH    = 32492;
N_total = numel(network_label);

assert(N_total == 2*N_LH, ...
    'Unexpected number of vertices');

lh_idx = 1:N_LH;
rh_idx = (N_LH+1):N_total;

% global -> local index 映射
lh_global2local = @(x) x;
rh_global2local = @(x) x - N_LH;

%% -------------------- 读取 surface 并构建邻接矩阵 --------------------

lh_surf = ft_read_headshape(lh_surf_file);
rh_surf = ft_read_headshape(rh_surf_file);

A_lh = triangulation2adjacency(lh_surf.tri, size(lh_surf.pos,1));
A_rh = triangulation2adjacency(rh_surf.tri, size(rh_surf.pos,1));

%% -------------------- ROI 容器 --------------------

ROI = struct;

%% -------------------- 主循环 --------------------

for net = 1:nNetworks

    % ---------- 左半球 ----------
    idx_lh = lh_idx( ...
        network_label(lh_idx) == net & ...
        probability(lh_idx)   >= prob_thresh );

    if ~isempty(idx_lh)
        ROI(net).LH = find_connected_core_fsLR( ...
            idx_lh, A_lh, lh_global2local, probability, max_roi_size);
    else
        ROI(net).LH = [];
    end

    % ---------- 右半球 ----------
    idx_rh = rh_idx( ...
        network_label(rh_idx) == net & ...
        probability(rh_idx)   >= prob_thresh );

    if ~isempty(idx_rh)
        ROI(net).RH = find_connected_core_fsLR( ...
            idx_rh, A_rh, rh_global2local, probability, max_roi_size);
    else
        ROI(net).RH = [];
    end

end

%% -------------------- 保存 ROI --------------------

save(fullfile(projFolder, 'output', ...
    'DU15NET_connected_core_ROI.mat'), 'ROI');

%% -------------------- Workbench 可视化 --------------------

roi_label = zeros(size(network_label));

for net = 1:nNetworks
    roi_label(ROI(net).LH) = net;
    roi_label(ROI(net).RH) = net;
end

roi_vis = consensus;
roi_vis.cdata = roi_label;
roi_vis.metadata = [];

cifti_write(roi_vis, out_vis_file);

%% ============================================================
%  ROI size + core probability 报告表（QC & Methods 用）
% ============================================================

roi_size_LH = zeros(nNetworks,1);
roi_size_RH = zeros(nNetworks,1);

roi_core_prob_LH = nan(nNetworks,1);   % 用 NaN 初始化，避免空 ROI 出错
roi_core_prob_RH = nan(nNetworks,1);

for net = 1:nNetworks

    % ---------- 左半球 ----------
    roi_size_LH(net) = numel(ROI(net).LH);

    if ~isempty(ROI(net).LH)
        % ROI 中的最大 probability（也就是 core seed 的值）
        roi_core_prob_LH(net) = max(probability(ROI(net).LH));
    end

    % ---------- 右半球 ----------
    roi_size_RH(net) = numel(ROI(net).RH);

    if ~isempty(ROI(net).RH)
        roi_core_prob_RH(net) = max(probability(ROI(net).RH));
    end
end

% 生成 table
ROI_report_table = table( ...
    (1:nNetworks)', ...
    roi_size_LH, ...
    roi_size_RH, ...
    roi_core_prob_LH, ...
    roi_core_prob_RH, ...
    'VariableNames', { ...
        'Network', ...
        'LH_ROI_size', ...
        'RH_ROI_size', ...
        'LH_core_prob_max', ...
        'RH_core_prob_max'} );

% 输出路径
roi_report_file = fullfile(projFolder, 'output', ...
    'DU15NET_connected_core_ROI_report.csv');

% 写出为 CSV
writetable(ROI_report_table, roi_report_file);

fprintf('DONE!');

%% ============================================================
%  函数 1：构建 surface 邻接矩阵
% ============================================================

function A = triangulation2adjacency(tri, n)
% tri : [Ntri x 3] 三角形顶点索引
% n   : vertex 总数

    A = sparse(n, n);

    for i = 1:size(tri,1)
        v = tri(i,:);
        A(v(1),v(2)) = 1;  A(v(2),v(1)) = 1;
        A(v(1),v(3)) = 1;  A(v(3),v(1)) = 1;
        A(v(2),v(3)) = 1;  A(v(3),v(2)) = 1;
    end
end

%% ============================================================
%  函数 2：连通 + 上限的 network core ROI
% ============================================================

function roi_global = find_connected_core_fsLR( ...
    idx_global, A, global2local, probability, max_roi_size)
% 在 probability >= 阈值的前提下：
% 1) 找最大连通分量
% 2) 以 probability 最大的点为中心
% 3) 沿 surface 邻接关系向外生长
% 4) ROI 大小达到 max_roi_size 即停止
%
% 输出 ROI 一定是连通的

    % ---------- global -> local ----------
    idx_local = arrayfun(global2local, idx_global);

    % ---------- 构建候选子图 ----------
    G = graph(A(idx_local, idx_local));

    % ---------- 连通分量 ----------
    bins = conncomp(G);
    comps = unique(bins);

    % ---------- 最大连通分量 ----------
    comp_sizes = zeros(numel(comps),1);
    for i = 1:numel(comps)
        comp_sizes(i) = sum(bins == comps(i));
    end

    [~, max_idx] = max(comp_sizes);
    main_comp = comps(max_idx);

    core_global = idx_global(bins == main_comp);
    core_local  = idx_local(bins == main_comp);

    % ---------- 选中心点（probability 最大） ----------
    core_prob = probability(core_global);
    [~, seed_idx] = max(core_prob);

    seed_local  = core_local(seed_idx);
    seed_global = core_global(seed_idx);

    % ---------- region growing ----------
    visited = false(numel(core_local),1);
    visited(seed_idx) = true;

    roi_local  = seed_local;
    roi_global = seed_global;

    % local index -> core index 映射
    local2core = containers.Map(core_local, 1:numel(core_local));

    frontier = seed_local;

    while numel(roi_local) < max_roi_size && ~isempty(frontier)

        new_frontier = [];

        for v = frontier

            nbrs = find(A(v,:));

            for n = nbrs(:)'
                if isKey(local2core, n)
                    idx = local2core(n);
                    if ~visited(idx)
                        visited(idx) = true;
                        roi_local(end+1)  = n; %#ok<AGROW>
                        roi_global(end+1) = core_global(idx); %#ok<AGROW>
                        new_frontier(end+1) = n; %#ok<AGROW>

                        if numel(roi_local) >= max_roi_size
                            break;
                        end
                    end
                end
            end

            if numel(roi_local) >= max_roi_size
                break;
            end
        end

        frontier = new_frontier;
    end

end

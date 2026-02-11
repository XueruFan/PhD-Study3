%% =========================================================
%  Extract DU15 network time series from fsLR10k CIFTI dtseries
%  NEW VERSION for CCNPPEK_fslr10k Windows data
%% =========================================================

clc; clear;

%% ---------------- Paths ----------------
roi_file = 'E:\PhDproject\Study3\output\roi\fslr10k\DU15Net_fsLR10k.dscalar.nii';
data_dir = 'F:\luo_fslr10k';
out_dir  = 'E:\PhDproject\Study3\data\timeseries\fslr10k';

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

nROI = 15;

%% ---------------- Load ROI ----------------
roi_cifti = ft_read_cifti(roi_file);
roi_vec   = roi_cifti.dscalar(:);   % [20484 × 1]

assert(numel(roi_vec) == 20484, 'Unexpected ROI size');

%% =========================================================
%  Find ALL restXX_Atlas_s4_10k.dtseries.nii recursively
%% =========================================================

files = dir(fullfile(data_dir, '**', 'rest*_Atlas_s4_10k.dtseries.nii'));

% -------- 排除 gs-removal ----------
keep_idx = ~contains({files.name}, 'gs-removal');
files = files(keep_idx);

fprintf('Total found: %d\n', numel(files));

%% =========================================================
for i = 1:numel(files)

    func_file = fullfile(files(i).folder, files(i).name);
    fprintf('Processing: %s\n', func_file);

    %% ---------------- Read CIFTI ----------------
    func_cifti = ft_read_cifti(func_file);
    full_data  = func_cifti.dtseries(1:20484, :);  % cortex only

    if size(full_data,1) ~= numel(roi_vec)
        error('Vertex mismatch: %s', files(i).name);
    end

    nTime = size(full_data, 2);
    ROI_ts = nan(nROI, nTime);

    %% =====================================================
    %  Network loop
    %% =====================================================
    for r = 1:nROI

        mask = (roi_vec == r);
        assert(any(mask), 'Empty DU15Net%d', r);

        ts = full_data(mask, :);          % [nVertex × nTime]
        ts_detrend = nan(size(ts));

        %% ---------- Vertex-wise detrend ----------
        for v = 1:size(ts,1)

            v_ts = ts(v,:);
            good = ~isnan(v_ts);

            if sum(good) <= 10
                continue;
            end

            v_valid = v_ts(good);

            if max(v_valid) == min(v_valid)
                continue;
            end

            v_ts_d = v_ts;
            v_ts_d(good) = detrend(v_valid, 'linear');
            ts_detrend(v,:) = v_ts_d;
        end

        %% ---------- Network average ----------
        ROI_ts(r,:) = nanmean(ts_detrend, 1);

    end

    %% =====================================================
    %  Parse subject + rest name
    %% =====================================================

    folder_parts = split(files(i).folder, filesep);

    % 找到被试名（以CCNPPEK开头的文件夹）
    sub_idx = find(startsWith(folder_parts, 'CCNPPEK'), 1);
    subName = folder_parts{sub_idx};

    % rest名称
    restName = files(i).name;
    restName = extractBefore(restName, '_Atlas');

    %% =====================================================
    %  Save
    %% =====================================================

    out_file = fullfile(out_dir, ...
        [subName '_' restName '_DU15_network_ts.mat']);

    save(out_file, 'ROI_ts', 'subName', 'restName');

end

fprintf('================ DONE ================\n');

%% ============================================================
%  Extract DU15 network time series (fsaverage5 surface) - WINDOWS
%  ROI mask preloaded (IO-safe)
%  Vertex-wise detrend (NaN-aware)
%  ROI average -> Bilateral network average
%% ============================================================

clear; clc;

%% ---------------- Paths ----------------
projDir = 'E:\PhDproject\Study3';
dataDir = fullfile(projDir, 'data');
roiDir  = fullfile(projDir, 'output', 'ROI_fsaverage5');
outRoot = fullfile(dataDir, 'timeseries', 'fsaverage5');

sites = {'CKG', 'PEK'};
runs  = {'rest1', 'rest2'};
hemi  = {'lh', 'rh'};
nROI  = 15;

%% ------------------------------------------------------------
for s = 1:numel(sites)

    siteName = sites{s};
    siteDir  = fullfile(dataDir, siteName);

    subList = dir(fullfile(siteDir, 'sub-*'));

    for sub = 1:numel(subList)

        subName = subList(sub).name;
        subDir  = fullfile(siteDir, subName);

        outDir = fullfile(outRoot, siteName, subName);
        if ~exist(outDir, 'dir')
            mkdir(outDir);
        end

        %% =====================================================
        %  PRELOAD ROI MASKS (ONCE PER SUBJECT)
        %% =====================================================
        ROI_mask = struct();
        ROI_mask.lh = cell(nROI,1);
        ROI_mask.rh = cell(nROI,1);

        for i = 1:nROI
            for h = 1:numel(hemi)

                hemiName = hemi{h};
                roiFile = fullfile(roiDir, ...
                    sprintf('%s.DU15Net%d_fsaverage5.nii.gz', hemiName, i));

                assert(exist(roiFile,'file')==2, ...
                    'ROI file missing: %s', roiFile);

                roi  = niftiread(roiFile);
                mask = squeeze(roi) > 0;

                assert(any(mask), ...
                    'Empty ROI: DU15Net%d %s', i, hemiName);

                ROI_mask.(hemiName){i} = mask;
            end
        end

        %% =====================================================
        %  RUN LOOP
        %% =====================================================
        for r = 1:numel(runs)

            runName = runs{r};
            fmri = struct();

            %% ---------- Load fMRI ----------
            for h = 1:numel(hemi)

                hemiName = hemi{h};

                fmriFile = dir(fullfile(subDir, ...
                    sprintf('%s.pp.*.fsaverage5.%s.nii', runName, hemiName)));

                if isempty(fmriFile)
                    fprintf('Missing %s %s in %s\n', ...
                        runName, hemiName, subName);
                    fmri = [];
                    break;
                end

                tmp = niftiread(fullfile( ...
                    fmriFile(1).folder, fmriFile(1).name));

                fmri.(hemiName) = squeeze(tmp);   % [10242 × T]
            end

            if isempty(fmri)
                continue;
            end

            nTime = size(fmri.lh, 2);

            %% ---------- Allocate ----------
            ROI_ts = struct();
            ROI_ts.lh = nan(nROI, nTime);
            ROI_ts.rh = nan(nROI, nTime);

            %% ---------- ROI loop ----------
            for i = 1:nROI

                for h = 1:numel(hemi)

                    hemiName = hemi{h};
                    mask = ROI_mask.(hemiName){i};

                    ts = fmri.(hemiName)(mask, :);   % [nVertex × nTime]
                    ts_detrend = nan(size(ts));

                    %% ----- Vertex-wise detrend -----
                    for v = 1:size(ts,1)

                        v_ts = ts(v,:);
                    
                        good = ~isnan(v_ts);
                    
                        % 至少需要足够多的有效时间点
                        if sum(good) <= 10
                            continue;
                        end
                    
                        v_valid = v_ts(good);
                    
                        % 手动零方差检查（避免 nanstd）
                        if max(v_valid) == min(v_valid)
                            continue;
                        end
                    
                        v_ts_d = v_ts;
                        v_ts_d(good) = detrend(v_valid, 'linear');
                        ts_detrend(v,:) = v_ts_d;
                    
                    end

                    ROI_ts.(hemiName)(i,:) = nanmean(ts_detrend, 1);
                end
            end

            %% ---------- Bilateral network average ----------
            ROI_ts_bilat = nan(nROI, nTime);
            for i = 1:nROI
                ROI_ts_bilat(i,:) = nanmean( ...
                    [ROI_ts.lh(i,:); ROI_ts.rh(i,:)], 1);
            end

            %% ---------- Save ----------
            outFile = fullfile(outDir, ...
                sprintf('%s_DU15_network_ts.mat', runName));

            save(outFile, ...
                'ROI_ts', ...
                'ROI_ts_bilat', ...
                'runName', 'siteName', 'subName');

        end
    end
end

fprintf('DONE!\n');

%% ============================================================
%  Extract DU15 network time series (fsaverage5 surface)
%  Vertex-wise detrend (NaN-aware)
%  ROI average -> Bilateral network average
%% ============================================================

clear; clc;
% addpath('/Applications/freesurfer/matlab');
% assert(exist('MRIread','file')==2, 'MRIread not found');

projDir = '/Users/xuerufan/DCM-Project-PhD-Study3-';
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

    subList = dir(fullfile(siteDir, 'sub-CCNP*'));

    for sub = 1:numel(subList)

        subName = subList(sub).name;
        subDir  = fullfile(siteDir, subName);

        outDir = fullfile(outRoot, siteName, subName);
        if ~exist(outDir, 'dir')
            mkdir(outDir);
        end

        for r = 1:numel(runs)

            runName = runs{r};
            fmri = struct();

            %% ---------- Load fMRI data ----------
            for h = 1:numel(hemi)

                hemiName = hemi{h};

                fmriFile = dir(fullfile(subDir, ...
                    sprintf('%s.pp.*.fsaverage5.%s.nii.gz', runName, hemiName)));

                if isempty(fmriFile)
                    fprintf('    Missing %s %s, skip.\n', runName, hemiName);
                    fmri = [];
                    break;
                end

                tmp = MRIread(fullfile(fmriFile(1).folder, fmriFile(1).name));
                fmri.(hemiName) = squeeze(tmp.vol);   % [10242 × T]
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

                roiName = sprintf('DU15Net%d', i);

                for h = 1:numel(hemi)

                    hemiName = hemi{h};

                    roiFile = fullfile(roiDir, ...
                        sprintf('%s.%s_fsaverage5.mgh', hemiName, roiName));

                    roi  = MRIread(roiFile);
                    mask = squeeze(roi.vol) > 0;

                    assert(any(mask), 'Empty ROI: %s %s', roiName, hemiName);

                    ts = fmri.(hemiName)(mask, :);   % [nVertex × nTime]

                    ts_detrend = nan(size(ts));

                    for v = 1:size(ts,1)
                    
                        v_ts = ts(v,:);
                    
                        if all(isnan(v_ts)) || nanstd(v_ts) == 0
                            continue;
                        end
                    
                        good = ~isnan(v_ts);
                    
                        if sum(good) > 2
                            v_ts_d = v_ts;
                            v_ts_d(good) = detrend(v_ts(good), 'linear');
                            ts_detrend(v,:) = v_ts_d;
                        end
                    end

                    ROI_ts.(hemiName)(i,:) = nanmean(ts_detrend, 1);

                end
            end

            %% ---------- Bilateral network average ----------
            ROI_ts_bilat = nan(nROI, nTime);

            for i = 1:nROI
                ROI_ts_bilat(i,:) = nanmean([ROI_ts.lh(i,:); ROI_ts.rh(i,:)], 1);
            end

            %% ---------- Save ----------
            outFile = fullfile(outDir, sprintf('%s_DU15_network_ts.mat', runName));
            save(outFile, ...
                'ROI_ts', ...          % hemisphere-specific (for QC)
                'ROI_ts_bilat', ...    % FINAL network-level time series
                'runName', 'siteName', 'subName');

        end
    end
end

fprintf('DONE!\n');

% plot(ROI_ts.lh(1,:));
% hold on; 
% plot(ROI_ts.rh(1,:));
% legend('lh','rh');
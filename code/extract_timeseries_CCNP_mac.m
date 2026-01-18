%% ============================================================
%  Extract DU15 ROI time series (fsaverage5 surface)
%  每个ROI取所有体素的均值
% ============================================================

clear; clc;
addpath('/Applications/freesurfer/matlab');
assert(exist('MRIread','file')==2, 'MRIread not found');

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
                fmri.(hemiName) = squeeze(tmp.vol);  % [10242 x T]
            end

            if isempty(fmri)
                continue;
            end

            nTime = size(fmri.lh, 2);

            ROI_ts = struct();
            ROI_ts.lh = zeros(nROI, nTime);
            ROI_ts.rh = zeros(nROI, nTime);

            for i = 1:nROI

                roiName = sprintf('DU15Net%d', i);

                for h = 1:numel(hemi)

                    hemiName = hemi{h};

                    roiFile = fullfile(roiDir, sprintf('%s.%s_fsaverage5.mgh', hemiName, roiName));

                    roi  = MRIread(roiFile);
                    mask = squeeze(roi.vol) > 0;

                    assert(any(mask), 'Empty ROI: %s %s', roiName, hemiName);

                    ROI_ts.(hemiName)(i,:) = mean(fmri.(hemiName)(mask,:), 1);
                end
            end

            ROI_ts.lh = detrend(ROI_ts.lh', 'linear')';
            ROI_ts.rh = detrend(ROI_ts.rh', 'linear')';

            outFile = fullfile(outDir, sprintf('%s_DU15_roi_ts.mat', runName));

            save(outFile, 'ROI_ts', 'runName', 'siteName', 'subName');

        end

    end

end

fprintf('DONE!');

% plot(ROI_ts.lh(1,:)); hold on;
% plot(ROI_ts.rh(1,:));
% legend('lh','rh');

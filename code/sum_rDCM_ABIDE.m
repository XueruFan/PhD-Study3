clear; clc;

abide_root = '/Volumes/Zuolab_XRF/data/abide';
rdcm_root  = fullfile(abide_root, 'rDCM');
stat_root  = fullfile(abide_root, 'stats');

if ~exist(stat_root, 'dir')
    mkdir(stat_root);
end

out_xlsx = fullfile(stat_root, 'ABIDE_rDCM_summary.xlsx');

nROI = 15;
nEC  = nROI * nROI;

mat_files = dir(fullfile(rdcm_root, '*_rDCM.mat'));
mat_files = mat_files(~startsWith({mat_files.name}, '._'));

nSub = numel(mat_files);
fprintf('Found %d ABIDE rDCM files\n', nSub);

EC_all   = zeros(nSub, nEC);
subject  = cell(nSub, 1);
site     = cell(nSub, 1);

for i = 1:nSub

    load(fullfile(rdcm_root, mat_files(i).name));  

    subject{i} = subName;
    site{i}    = siteName;

    EC_all(i, :) = reshape(EC', 1, []);

end


colNames = cell(1, nEC);
k = 1;
for from = 1:nROI
    for to = 1:nROI
        colNames{k} = sprintf('EC_%02d_to_%02d', from, to);
        k = k + 1;
    end
end

T = array2table(EC_all, 'VariableNames', colNames);
T = addvars(T, subject, site, 'Before', 1);

writetable(T, out_xlsx);
fprintf('Done!');

%% ============================================================
%  export ROI from fsLR-32k to labels
%  把ROI顶点索引导出为FreeSurfer.label文件，不涉及空间转换，只是格式转换。
%  Xueru Fan  Jan 12 2026  @DK
% ============================================================

clear; clc;

projFolder = '/Users/xuerufan/DCM-Project-PhD-Study3-';
cd(fullfile(projFolder, 'output'))

load('DU15NET_connected_core_ROI.mat');

outdir = fullfile(pwd, 'ROI_labels');
mkdir(outdir);

for net = 1:15
    for hemi = ["LH","RH"]
%         net = 1; hemi = 'RH';

        verts = ROI(net).(hemi);

        if isempty(verts)
            continue;
        end

        verts = verts - 1; % MATLAB -> FreeSurfer index

        fname = sprintf('%s.DU15_network%d_fsLR32k.label', lower(hemi), net);

        fid = fopen(fullfile(outdir, fname), 'w');

        fprintf(fid, '#!ascii label\n');
        fprintf(fid, '%d\n', numel(verts)); % 该ROI包含顶点数

        for v = verts'
            fprintf(fid, '%d 0 0 0 1\n', v);
        end

        fclose(fid);
    end
end

disp('DONE!');

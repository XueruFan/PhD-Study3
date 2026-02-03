clear; clc;

%% =========================
sfc_dir = 'E:\PhDproject\Study3\output\SFC';                 
out_dir = 'E:\PhDproject\Study3\output\SFC_Embedding';

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

nNet     = 15;
step_max = 8;

%% =========================
all_files = dir(fullfile(sfc_dir, '*_SFC_step*.mat'));

for S = 1:step_max
    
    fprintf('Exporting step %d ...\n', S);
    
    step_tag   = sprintf('step%02d', S);
    step_files = all_files(contains({all_files.name}, step_tag));
    
    nSub = length(step_files);
    
    % 预分配
    Site    = strings(nSub,1);
    Subject = strings(nSub,1);
    Session = strings(nSub,1);
    Run     = strings(nSub,1);
    Embed   = zeros(nSub, nNet);
    
    %% =========================
    for i = 1:nSub
        
        fname = step_files(i).name;
        fpath = fullfile(sfc_dir, fname);
        
        % 文件名示例：
        % CKG0004_ses01_rest1_DU15_SFC_step03.mat
        
        tokens = regexp(fname, ...
            '^([A-Z]+)(\d+)_ses(\d+)_rest(\d+)_DU\d+_SFC_step', 'tokens');
        
        if isempty(tokens)
            warning('Filename not matched, skipped: %s', fname);
            continue
        end
        
        Site(i)    = tokens{1}{1};   % CKG
        Subject(i) = tokens{1}{2};   % 0004
        Session(i) = tokens{1}{3};   % 01
        Run(i)     = tokens{1}{4};   % 1
        
        load(fpath, 'Embedding');
        Embed(i,:) = Embedding(:)';
        
        clear Embedding
    end

    varNames = ["Site", "Subject", "Session", "Run", ...
        arrayfun(@(x) sprintf("Net%02d", x), 1:nNet, 'UniformOutput', false)];
    
    T = array2table([Site, Subject, Session, Run, num2cell(Embed)], ...
        'VariableNames', varNames);
    
    out_name = sprintf('step%02d.xlsx', S);
    writetable(T, fullfile(out_dir, out_name));
    
end

fprintf('Done!\n');

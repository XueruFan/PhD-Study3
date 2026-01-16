# DCM-Project[PhD Study3]

## Step 0: 拷贝需要的静息态数据

`copy_CCNP_fsaverage5.ps1` 

## Step : 被试筛选

qc结果
年龄性别

## Step : 每个网络选取1个ROI

`select_ROI_fsLR32k`

## Step : 空间转换15个网络的ROI

将定义在 **fsLR-32k** 表面空间中的感兴趣区（regions of interest, ROIs），逐步转换到 **FreeSurfer 的 fsaverage5** 表面空间，从而与基于 fsaverage5 预处理的功能数据在**顶点层面实现精确对齐**。

1. `export_ROI_wb.m`  
**fsLR-32k ROI → Workbench metric** 该 MATLAB 脚本将以顶点索引形式存储的 ROI（fsLR-32k）导出为二值表面 metric 文件（`.func.gii`），作为后续 Workbench 重采样的输入。
output/ROI_metrics_fsLR32k/
lh.DU15network<N>_fsLR32k.func.gii
rh.DU15network<N>_fsLR32k.func.gii

2. `resample_fsLR32k_to_fsaverage164k.sh`  
**fsLR-32k → fsaverage-164k（Workbench）** 该 shell 脚本使用 Connectome Workbench 将 fsLR-32k ROI metric 重采样至 fsaverage 高分辨率表面（约 164k 顶点/半球）。
output/ROI_metrics_fsaverage164/
lh.DU15network<N>_fsaverage164k.func.gii
rh.DU15network<N>_fsaverage164k.func.gii

3. `resample_fsaverage164_to_fsaverage5.sh`  
**fsaverage-164k → fsaverage5（FreeSurfer）** 该脚本将 fsaverage-164k 的 ROI metric 转换为 FreeSurfer overlay，并映射到 fsaverage5 表面。
output/ROI_fsaverage5/
lh.DU15Net<N>_fsaverage5.mgh
rh.DU15Net<N>_fsaverage5.mgh

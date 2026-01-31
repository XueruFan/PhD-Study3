# DCM-Project[PhD Study3]


## Step 0: 拷贝需要的静息态数据

`copy_CCNP_fsaverage5.ps1` 
`unzip_CCNP.ps1`


## Step : 被试筛选

qc结果
年龄性别


## Step : 每个网络选取1个ROI

`select_ROI_fsLR32k`


## Step : 空间转换15个网络的ROI

将定义在 **fsLR-32k** 表面空间中的感兴趣区（regions of interest, ROIs），转换到 **FreeSurfer 的 fsaverage5** 表面空间，从而与基于 fsaverage5 预处理的功能数据在**顶点层面实现精确对齐**。

`export_ROI_wb.m`  
**fsLR-32k ROI → Workbench metric** 该 MATLAB 脚本将以顶点索引形式存储的 ROI（fsLR-32k）导出为二值表面 metric 文件（`.func.gii`），作为后续 Workbench 重采样的输入。
output/ROI_metrics_fsLR32k/
lh.DU15network<N>_fsLR32k.func.gii
rh.DU15network<N>_fsLR32k.func.gii

`resample_fsLR32k_to_fsLR10k.sh`
**fsLR-32k → fsLR-10k（Workbench）**
output/ROI_fslr10k/
lh.DU15Net<N>_fsLR10k.func.gii
rh.DU15Net<N>_fsLR10k.func.gii

`resample_fsLR32k_to_fsaverage164k.sh`  
**fsLR-32k → fsaverage-164k（Workbench）** 该 shell 脚本使用 Connectome Workbench 将 fsLR-32k ROI metric 重采样至 fsaverage 高分辨率表面（约 164k 顶点/半球）。
output/ROI_metrics_fsaverage164/
lh.DU15network<N>_fsaverage164k.func.gii
rh.DU15network<N>_fsaverage164k.func.gii

`resample_fsaverage164_to_fsaverage5.sh`  
**fsaverage-164k → fsaverage5（FreeSurfer）** 该脚本将 fsaverage-164k 的 ROI metric 转换为 FreeSurfer overlay，并映射到 fsaverage5 表面。
output/ROI_fsaverage5/
lh.DU15Net<N>_fsaverage5.mgh
rh.DU15Net<N>_fsaverage5.mgh

`convert_DU15ROI_to_nifti.sh`  
**fsaverage5(.mgh) → fsaverage5（nii.gz）** 格式转换，在windows电脑上（不使用hfreesurfer时）读数据需要。
output/ROI_fsaverage5/
lh.DU15Net<N>_fsaverage5.nii.gz
rh.DU15Net<N>_fsaverage5.nii.gz

将定义在 **fsLR-32k** 表面空间中的感兴趣区（regions of interest, ROIs），转换到 **fsLR-10k**表面空间。


## Step : 可视化ROI

`plot_Du15ROI_fsaverage5.py`
在 **fsaverage5 皮层表面空间** 上可视化 **DU15 功能网络（15 个 network）**。将左右半球的 DU15 ROI（`.mgz`）合并为网络标签图，按照DU定义的 RGB 颜色进行渲染，并在膨胀皮层表面上生成多个视角（外侧、内侧、前、后、上、下）的高分辨率图像。
visual/
DU15_fsaverage5_LH_anterior.png
...

`build_DU15Net_fsLR10k_dlabel.sh`
合并多个 ROI 为单一整数 surface metric
output/ROI_fslr10k/
lh.DU15Net_fsLR10k.func.gii
rh.DU15Net_fsLR10k.func.gii
由 surface metric 生成 1个包含所有ROI的CIFTI dense scalar（注意：这一步没有修改每个ROI的颜色和Du15一致，也没有输出ROI得截图，因为已经有fslr32k和fsaverage5两个空间的了，只是分辨率不一样，需要的话再用matlab搞一下吧）
output/ROI_fslr10k/
DU15Net_fsLR10k.dscalar.nii


## Step : 提取时间序列

`extract_timeseries_CCNP_mac`、`extract_timeseries_CCNP_wins.m`和`extract_timeseries_ABIDE.mac.m`
提取数据中ROI体素的时间序列，然后进行逐个时间序列的去均值和去线性漂移，两个半球的ROI内进行体素平均。
CCNP
data/timeseries/fsaverage/SITE/SUB/
rest1_DU15_roi_ts.mat
rest2_DU15_roi_ts.mat
ABIDE
data/abide/timeseries/
29096_DU15_network_ts.mat


## Step : rDCM 批处理

基于 **TAPAS toolbox**的有效连接估计，所有脚本均采用 **classic rDCM（无 sparsity 约束）** 和 **有sparsity 约束**两种方式，并显式指定采样间隔（TR）。


### 1️⃣ `calculate_rDCM_ABIDE.m`

- 每个被试一个时间序列文件，根据 `siteName` 自动匹配 TR


### 2️⃣ `calculate_rDCM_CCNP.m`

- 每个被试可包含多个 run（如 rest1 / rest2），CKG：2.5 s  ，PEK：2.0 s

### 输出结构示例

rDCM/
├── ABIDE/
│   └── sub-XXXX_rDCM.mat
├── CKG/
│   └── sub-XXXX_ses01/
│       └── sub-XXXX_rest1_rDCM.mat
└── PEK/
    └── sub-XXXX_ses01/
        └── sub-XXXX_rest1_rDCM.mat


## Step : 汇总rDCM结果
`sum_rDCM_ABIDE.m`
`sum_rDCM_CCNP.m`
CCNP_rDCM_summary.xlsx
ABIDE_rDCM_summary.xlsx


## Step : rDCM 组水平分析
`group_analysis_rDCM_ABIDE.R`
ABIDE有效连接参数的组水平统计分析代码。分析以男性、扫描时年龄小于 13 岁的被试为样本，采用逐连接的线性混合效应模型比较 ASD 与典型发育对照组在有效连接参数上的差异，并将采集站点作为随机截距以控制多站点数据的系统性偏移。所有连接的组效应结果均进行了假发现率校正，并辅以效应量分布与方向一致性分析，用于评估单连接层面是否存在稳健的组间差异。
结果文件：/Volumes/Zuolab_XRF/data/abide/stats/ABIDE_rDCM_group_effects_male_under13.csv

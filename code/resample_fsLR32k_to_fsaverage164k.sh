#!/bin/bash
# ============================================================
#  Batch resample ROI metrics: fsLR-32k  -->  fsaverage-164k
#
#  Xueru Fan / Jan 2026
# ============================================================

set -e  # 任一命令出错即停止

# -------- 项目根目录 --------
PROJ_DIR="/Users/xuerufan/DCM-Project-PhD-Study3-"

# -------- 输入 / 输出目录 --------
SRC_DIR="${PROJ_DIR}/output/ROI_fsLR32k"
OUT_DIR="${PROJ_DIR}/output/ROI_fsaverage164"

mkdir -p "${OUT_DIR}"

# -------- fsLR 32k spheres --------
SPHERE_LR_L="${PROJ_DIR}/templet/fsLR32k/fs_LR.32k.L.sphere.surf.gii"
SPHERE_LR_R="${PROJ_DIR}/templet/fsLR32k/fs_LR.32k.R.sphere.surf.gii"

# -------- fsLR -> fsaverage 164k crosswalk spheres --------
SPHERE_FSAVG_L="/Users/xuerufan/matlab-toolbox/CBIG/data/templates/surface/standard_mesh_atlases_20160827/fs_L/fs_L-to-fs_LR_fsaverage.L_LR.spherical_std.164k_fs_L.surf.gii"
SPHERE_FSAVG_R="/Users/xuerufan/matlab-toolbox/CBIG/data/templates/surface/standard_mesh_atlases_20160827/fs_R/fs_R-to-fs_LR_fsaverage.R_LR.spherical_std.164k_fs_R.surf.gii"


# -------- 网络数量 --------
N_NET=15

echo "=== fsLR32k -> fsaverage164k batch resampling ==="

for NET in $(seq 1 ${N_NET}); do
    echo "Processing network ${NET} ..."

    # ---------- Left hemisphere ----------
    wb_command -metric-resample \
      "${SRC_DIR}/lh.DU15Net${NET}_fsLR32k.func.gii" \
      "${SPHERE_LR_L}" \
      "${SPHERE_FSAVG_L}" \
      BARYCENTRIC \
      "${OUT_DIR}/lh.DU15Net${NET}_fsaverage164k.func.gii" \
      -largest

    # ---------- Right hemisphere ----------
    wb_command -metric-resample \
      "${SRC_DIR}/rh.DU15Net${NET}_fsLR32k.func.gii" \
      "${SPHERE_LR_R}" \
      "${SPHERE_FSAVG_R}" \
      BARYCENTRIC \
      "${OUT_DIR}/rh.DU15Net${NET}_fsaverage164k.func.gii" \
      -largest
done

echo "=== ALL NETWORKS DONE ==="


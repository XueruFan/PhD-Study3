#!/bin/bash
# ============================================================
#  fsaverage164k -> fsaverage5
#
#  Xueru Fan  Jan 2026
# ============================================================

set -e  # 任一命令出错立即停止

# -------- 项目目录 --------
PROJ_DIR="/Users/xuerufan/DCM-Project-PhD-Study3-"
OUT_DIR="${PROJ_DIR}/output"

SRC_DIR="${OUT_DIR}/ROI_fsaverage164"
TRG_DIR="${OUT_DIR}/ROI_fsaverage5"

mkdir -p "${TRG_DIR}"

# -------- 网络数量 --------
N_NET=15

echo "=== fsaverage164k -> fsaverage5 batch processing ==="

for NET in $(seq 1 ${N_NET}); do
  echo "Processing network ${NET} ..."

  for HEMI in lh rh; do

    echo "  ${HEMI} hemisphere"

    # ---------- Step 1: func.gii -> mgh ----------
    mri_convert \
      "${SRC_DIR}/${HEMI}.DU15Net${NET}_fsaverage164k.func.gii" \
      "${SRC_DIR}/${HEMI}.DU15Net${NET}_fsaverage164k.mgh"

    # ---------- Step 2: fsaverage -> fsaverage5 ----------
    mri_surf2surf \
      --srcsubject fsaverage \
      --trgsubject fsaverage5 \
      --hemi ${HEMI} \
      --sval "${SRC_DIR}/${HEMI}.DU15Net${NET}_fsaverage164k.mgh" \
      --tval "${TRG_DIR}/${HEMI}.DU15Net${NET}_fsaverage5.mgh"

  done
done

echo "=== ALL NETWORKS DONE ==="


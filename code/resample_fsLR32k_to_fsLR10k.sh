#!/bin/bash

# ============================================================
# Resample fsLR 32k ROI metrics to fsLR 10k
# + set correct cortex structure metadata
#
# Author: Xueru Fan
# ============================================================

# -------- paths --------
ROI_DIR=/Users/xuerufan/DCM-Project-PhD-Study3-/output/ROI_fsLR32k
OUT_DIR=/Users/xuerufan/DCM-Project-PhD-Study3-/output/ROI_fsLR10k

SPHERE_32K_DIR=/Users/xuerufan/DCM-Project-PhD-Study3-/templet/fsLR32k
SPHERE_10K_DIR=/Users/xuerufan/DCM-Project-PhD-Study3-/templet/fsLR10k

mkdir -p ${OUT_DIR}

# -------- resampling --------
for hemi in lh rh; do

  if [ ${hemi} == "lh" ]; then
    SRC_SPHERE=${SPHERE_32K_DIR}/fs_LR.32k.L.sphere.surf.gii
    TRG_SPHERE=${SPHERE_10K_DIR}/L.sphere.10k_fs_LR.surf.gii
  else
    SRC_SPHERE=${SPHERE_32K_DIR}/fs_LR.32k.R.sphere.surf.gii
    TRG_SPHERE=${SPHERE_10K_DIR}/R.sphere.10k_fs_LR.surf.gii
  fi

  for roi in ${ROI_DIR}/${hemi}.DU15Net*_fsLR32k.func.gii; do

    fname=$(basename ${roi})
    outname=${fname/fsLR32k/fsLR10k}

    wb_command -metric-resample \
      ${roi} \
      ${SRC_SPHERE} \
      ${TRG_SPHERE} \
      BARYCENTRIC \
      ${OUT_DIR}/${outname}

  done
done

# -------- set structure metadata --------

for f in ${OUT_DIR}/lh*.func.gii; do
  wb_command -set-structure ${f} CORTEX_LEFT
done

for f in ${OUT_DIR}/rh*.func.gii; do
  wb_command -set-structure ${f} CORTEX_RIGHT
done

echo "Done!"
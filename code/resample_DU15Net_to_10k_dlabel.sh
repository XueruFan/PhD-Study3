#!/bin/bash

WB=/Applications/workbench/bin_macosxub/wb_command

# -------- paths --------
ROI_DIR=/Users/xuerufan/PhD-Study3/output/ROI_fsLR32k
OUT_DIR=/Users/xuerufan/PhD-Study3/output/ROI_fsLR10k

SPHERE_32K_DIR=/Users/xuerufan/PhD-Study3/templet/fsLR32k
SPHERE_10K_DIR=/Users/xuerufan/PhD-Study3/templet/fsLR10k

LABEL_TABLE=/Users/xuerufan/PhD-Study3/supplement/DU15Net_colors_fixed.txt

mkdir -p ${OUT_DIR}

for hemi in lh rh; do

  if [ ${hemi} == "lh" ]; then
    SRC_SPHERE=${SPHERE_32K_DIR}/fs_LR.32k.L.sphere.surf.gii
    TRG_SPHERE=${SPHERE_10K_DIR}/L.sphere.10k_fs_LR.surf.gii
    STRUCT=CORTEX_LEFT
  else
    SRC_SPHERE=${SPHERE_32K_DIR}/fs_LR.32k.R.sphere.surf.gii
    TRG_SPHERE=${SPHERE_10K_DIR}/R.sphere.10k_fs_LR.surf.gii
    STRUCT=CORTEX_RIGHT
  fi

  for roi in ${ROI_DIR}/${hemi}.DU15Net*_fsLR32k.func.gii; do

    fname=$(basename ${roi})
    outname=${fname/fsLR32k/fsLR10k}
    outname=${outname/.func.gii/.label.gii}

    ${WB} -metric-label-import \
      ${roi} \
      ${LABEL_TABLE} \
      ${OUT_DIR}/tmp.label.gii

    ${WB} -label-resample \
      ${OUT_DIR}/tmp.label.gii \
      ${SRC_SPHERE} \
      ${TRG_SPHERE} \
      ADAP_BARY_AREA \
      ${OUT_DIR}/${outname}

    ${WB} -set-structure \
      ${OUT_DIR}/${outname} \
      ${STRUCT}

    rm ${OUT_DIR}/tmp.label.gii

  done
done

${WB} -cifti-create-label \
  ${OUT_DIR}/DU15Net_fsLR10k.dlabel.nii \
  -left-label  ${OUT_DIR}/lh.DU15Net_fsLR10k.label.gii \
  -right-label ${OUT_DIR}/rh.DU15Net_fsLR10k.label.gii

echo "Done: DU15Net_fsLR10k.dlabel.nii created"

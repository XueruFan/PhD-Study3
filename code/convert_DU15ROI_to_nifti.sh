#!/bin/bash

# ============================================================
# Convert DU15 ROI from .mgh to .nii.gz (fsaverage5)
# ============================================================

ROI_DIR="/Users/xuerufan/DCM-Project-PhD-Study3-/output/ROI_fsaverage5"

cd "$ROI_DIR" || {
  echo "Cannot access ROI directory: $ROI_DIR"
  exit 1
}

for hemi in lh rh; do
  for i in {1..15}; do

    in_file="${hemi}.DU15Net${i}_fsaverage5.mgh"
    out_file="${hemi}.DU15Net${i}_fsaverage5.nii.gz"

    if [ -f "$in_file" ]; then
      echo "Converting: $in_file -> $out_file"
      mri_convert "$in_file" "$out_file"
    else
      echo "Missing file: $in_file"
    fi

  done
done

echo "DONE: DU15 ROI conversion completed."


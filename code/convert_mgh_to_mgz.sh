#!/bin/bash
# Convert all fsaverage5 surface ROI files (.mgh) to (.mgz)


DIR="/Users/xuerufan/DCM-Project-PhD-Study3-/output/ROI_fsaverage5"

for mgh_file in "${DIR}"/{lh,rh}.DU15Net*_fsaverage5.mgh; do
    [ -e "$mgh_file" ] || continue

    base_name=$(basename "$mgh_file" .mgh)
    mgz_file="${DIR}/${base_name}.mgz"

    mri_convert "$mgh_file" "$mgz_file"
done

echo "Done!"

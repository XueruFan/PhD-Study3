# ============================================================
# Merge ABIDE cluster results
# Training clusters + Predicted clusters (non-overlapping)
# ============================================================

rm(list = ls())

library(tidyverse)
library(readr)

# ----------------------------
# 1. File paths
# ----------------------------
train_cluster_path <- "/Users/xuerufan/PhD-Study3/supplement/ABIDE_ClusterID.csv"
pred_cluster_path  <- "/Volumes/Zuolab_XRF/output/abide/abide_cluster_predictions_male.csv"

out_path <- "/Volumes/Zuolab_XRF/output/abide/ABIDE_cluster_all_subjects.csv"

# ----------------------------
# 2. Read training cluster results
# ----------------------------
cluster_train <- read_csv(train_cluster_path, show_col_types = FALSE) %>%
  transmute(
    participant = as.character(Participant),
    subtype = case_when(
      ClusterIndex == "L" ~ 1,
      ClusterIndex == "H" ~ 2),
    source      = "train"
  )

# ----------------------------
# 3. Read predicted cluster results
# ----------------------------
cluster_pred <- read_csv(pred_cluster_path, show_col_types = FALSE) %>%
  transmute(
    participant = as.character(participant),
    subtype)

# ----------------------------
# 4. Row-bind all subjects
# ----------------------------
cluster_all <- bind_rows(
  cluster_train,
  cluster_pred
) %>%
  arrange(subtype, participant)

# ----------------------------
# 5. Export
# ----------------------------
write_csv(cluster_all, out_path)

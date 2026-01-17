## =========================================================
##  被试筛选
# 要求qc
## =========================================================
library(readxl)
library(dplyr)

## =========================================================
##  File paths
## =========================================================
qc_file   <- "/Users/xuerufan/DCM-Project-PhD-Study3-/supplement/FXR_QCresult.xlsx"
data_file <- "/Users/xuerufan/DCM-Project-PhD-Study3-/supplement/data_sum.xlsx"

## =========================================================
##  Read data
## =========================================================
qc_df   <- read_excel(qc_file)
data_df <- read_excel(data_file)

## =========================================================
##  Step 1: subject-level QC decision
##  keep subject if ANY session qcFXR == 1 or 2
## =========================================================
subject_qc <- qc_df %>%
  group_by(Site, Participant) %>%
  summarise(
    has_valid_session = any(qcFXR %in% c(1, 2), na.rm = TRUE),
    .groups = "drop"
  )

## =========================================================
##  Step 2: keep only subjects with at least one valid session
## =========================================================
valid_subjects <- subject_qc %>%
  filter(has_valid_session) %>%
  select(Site, Participant)

## =========================================================
##  Step 3: filter data_sum by subject list
## =========================================================
data_valid <- data_df %>%
  inner_join(valid_subjects,
             by = c("Site", "Participant"))

## =========================================================
##  Step 4: export
## =========================================================
write.csv(
  data_valid,
  file = "/Users/xuerufan/DCM-Project-PhD-Study3-/supplement/data_sum_validSubjects_qcFXR_1_2.csv",
  row.names = FALSE
)

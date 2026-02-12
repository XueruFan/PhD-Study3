rm(list = ls())

library(readxl)
library(dplyr)
library(stringr)
library(writexl)

# ------------------ paths ------------------
qc_file <- "/Users/xuerufan/DCM-Project-PhD-Study3-/supplement/QC/ccnpckg_fd0.5.xlsx"
sfc_dir <- "/Users/xuerufan/DCM-Project-PhD-Study3-/output/CCNP/SFC_Embedding"

steps <- sprintf("%02d", 1:8)

# ------------------ QC table ------------------
qc <- read_xlsx(qc_file) %>%
  mutate(
    Subject = str_pad(Participant, 4, pad = "0"),
    Session = str_pad(Session, 2, pad = "0")
  )

# ------------------ loop over steps ------------------
for (s in steps) {
  
  message("Processing CKG step ", s)
  
  sfc <- read_xlsx(file.path(sfc_dir, paste0("step", s, ".xlsx"))) %>%
    filter(Site == "CKG")
  
  # 精确筛选：Subject × Session
  sfc_sel <- sfc %>%
    semi_join(qc, by = c("Subject", "Session"))
  
  merged <- sfc_sel %>%
    left_join(qc, by = c("Subject", "Session")) %>%
    select(Site, Subject, Sex, Age, Session, Run, starts_with("Net"))
  
  # 输出
  write_xlsx(
    merged,
    file.path(sfc_dir, paste0("ckg_step", s, "_fd0.5.xlsx"))
  )
}

############################################################
# Build Male TD Normative Dataset (with Site)
############################################################

rm(list = ls())

library(tidyverse)
library(readxl)
library(openxlsx)

############################################################
# 1. Paths
############################################################

ccnp_path  <- "/Volumes/Zuolab_XRF/output/ccnp/sfc/sfc_nbtw_embedding"
abide_path <- "/Volumes/Zuolab_XRF/output/abide/sfc/sfc_nbtw_embedding"

abide_demo_path <- "/Volumes/Zuolab_XRF/output/abide/sfc/sfc_participant_summary.csv"

############################################################
# 2. Read CCNP (sessionAvg files only)
############################################################

read_ccnp <- function(folder_path) {
  
  files <- list.files(
    folder_path,
    pattern = "^pek_.*_sessionAvg\\.xlsx$",
    full.names = TRUE
  )
  
  map_dfr(files, function(f) {
    
    step_num <- stringr::str_extract(basename(f), "\\d+")
    dat <- read.xlsx(f)
    
    dat$Step   <- as.numeric(step_num)
    dat$Cohort <- "CCNP"
    dat$Site   <- "PEK"   # CCNP 单站点
    
    dat
  })
}

ccnp_embedding <- read_ccnp(ccnp_path)

############################################################
# 3. Read ABIDE embedding
############################################################

read_abide <- function(folder_path) {
  
  files <- list.files(
    folder_path,
    pattern = "^step\\d+\\.xlsx$",
    full.names = TRUE
  )
  
  map_dfr(files, function(f) {
    
    step_num <- stringr::str_extract(basename(f), "\\d+")
    dat <- read.xlsx(f)
    
    dat$Step   <- as.numeric(step_num)
    dat$Cohort <- "ABIDE"
    
    dat
  })
}

abide_embedding <- read_abide(abide_path)

############################################################
# 4. Read ABIDE demo (site already included)
############################################################

abide_demo <- read.csv(abide_demo_path) %>%
  rename(ID = Subject) %>%
  mutate(
    ID   = as.integer(ID),
    Sex  = ifelse(Sex == "Male", 1, 2),
    Site = as.character(site)
  )

############################################################
# 5. Clean CCNP
############################################################

ccnp_clean <- ccnp_embedding %>%
  rename(ID = Participant) %>%
  mutate(
    ID  = as.character(ID),
    Sex = ifelse(Sex == "男", 1, 2)
  ) %>%
  filter(
    Sex == 1,
    Age <= 18,
    Step >= 1,
    Step <= 7
  )

############################################################
# 6. Clean ABIDE (直接 join demo)
############################################################

abide_clean <- abide_embedding %>%
  rename(ID = Subject) %>%
  mutate(ID = as.integer(ID)) %>%
  left_join(abide_demo, by = "ID") %>%
  filter(
    Subtype == "TD",
    Sex == 1,
    Age <= 18,
    Step >= 1,
    Step <= 7
  )

############################################################
# 7. Pivot long
############################################################

ccnp_long <- ccnp_clean %>%
  pivot_longer(
    cols = starts_with("Net"),
    names_to = "Network",
    values_to = "SFEI"
  ) %>%
  mutate(SFEI = as.numeric(SFEI)) %>%
  select(Cohort, ID, Site, Age, Step, Network, SFEI)

abide_long <- abide_clean %>%
  pivot_longer(
    cols = starts_with("Net"),
    names_to = "Network",
    values_to = "SFEI"
  ) %>%
  mutate(SFEI = as.numeric(SFEI),
         ID  = as.character(ID),) %>%
  select(Cohort, ID, Site, Age, Step, Network, SFEI)

############################################################
# 8. Merge
############################################################

normative_data <- bind_rows(ccnp_long, abide_long)

############################################################
# 9. Save
############################################################

output_file <- "/Volumes/Zuolab_XRF/output/normative/SFEI_normative_data.xlsx"

write.xlsx(normative_data, output_file, overwrite = TRUE)

cat("Finished.\nSaved to:\n", output_file)



############################################################
# Demographic summary statistics
# Observation-level & Subject-level
############################################################

library(dplyr)
library(openxlsx)

############################################################
# 1. Observation-level summary
############################################################

# 观测层级：每一行代表一个观测
obs_level <- normative_data %>%
  select(ID, Cohort, Site, Age) %>%
  distinct()  # 防止 Step × Network 重复

# ---- 按 Cohort ----
obs_cohort <- obs_level %>%
  group_by(Cohort) %>%
  summarise(
    N_obs = n(),
    Age_mean = mean(Age, na.rm = TRUE),
    Age_sd   = sd(Age, na.rm = TRUE),
    .groups = "drop"
  )

# ---- 按 Cohort × Site ----
obs_site <- obs_level %>%
  group_by(Cohort, Site) %>%
  summarise(
    N_obs = n(),
    Age_mean = mean(Age, na.rm = TRUE),
    Age_sd   = sd(Age, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(Cohort, Site)

############################################################
# 2. Subject-level summary
############################################################

# 每个受试者只算一次（纵向取平均年龄）
subj_level <- normative_data %>%
  group_by(ID, Cohort, Site) %>%
  summarise(
    Age = mean(Age, na.rm = TRUE),
    .groups = "drop"
  )

# ---- 按 Cohort ----
subj_cohort <- subj_level %>%
  group_by(Cohort) %>%
  summarise(
    N_subject = n(),
    Age_mean = mean(Age, na.rm = TRUE),
    Age_sd   = sd(Age, na.rm = TRUE),
    .groups = "drop"
  )

# ---- 按 Cohort × Site ----
subj_site <- subj_level %>%
  group_by(Cohort, Site) %>%
  summarise(
    N_subject = n(),
    Age_mean = mean(Age, na.rm = TRUE),
    Age_sd   = sd(Age, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(Cohort, Site)

############################################################
# 3. Save to Excel (multiple sheets)
############################################################

demo_output_file <- "/Volumes/Zuolab_XRF/output/normative/SFEI_normative_demographic.xlsx"

wb <- createWorkbook()

addWorksheet(wb, "Observation_Cohort")
writeData(wb, "Observation_Cohort", obs_cohort)

addWorksheet(wb, "Observation_Site")
writeData(wb, "Observation_Site", obs_site)

addWorksheet(wb, "Subject_Cohort")
writeData(wb, "Subject_Cohort", subj_cohort)

addWorksheet(wb, "Subject_Site")
writeData(wb, "Subject_Site", subj_site)

saveWorkbook(wb, demo_output_file, overwrite = TRUE)

cat("Demographic summary saved to:\n", demo_output_file)


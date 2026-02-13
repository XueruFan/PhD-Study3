############################################################
# ComBat harmonization for SFEI dataset
# Include TD + ASD, control Age + Diagnosis
############################################################

rm(list = ls())

library(tidyverse)
library(readxl)
library(openxlsx)
library(neuroCombat)
# 如果没有neuroCombat包，需要上github安装
# reference:https://doi.org/10.1016/j.neuroimage.2017.11.024
# library(devtools)
# install_github("jfortin1/neuroCombatData")
# install_github("jfortin1/neuroCombat_Rpackage")

############################################################
# 1. Load dataset (包含 TD + ASD)
############################################################

data_path <- "/Volumes/Zuolab_XRF/output/normative/SFEI_normative_data.xlsx"

normative_data <- read.xlsx(data_path)

############################################################
# 2. 预处理
############################################################

normative_data <- normative_data %>%
  mutate(
    # 合并 NYU2
    Site = recode(Site, "NYU2" = "NYU"),
    
    # 合并 ASD 亚型
    Diagnosis = case_when(
      Subtype == "TD" ~ "TD",
      Subtype %in% c("ASD-L", "ASD-H") ~ "ASD",
      TRUE ~ NA_character_
    ),
    
    Diagnosis = factor(Diagnosis),
    
    # 构建 Feature
    Feature = paste0("S", Step, "_", Network)
  )

############################################################
# 3. 转为宽格式 (ID × Feature)
############################################################

wide_data <- normative_data %>%
  select(Cohort, ID, Session, Site, Age, Subtype, Diagnosis, Feature, SFEI) %>%
  pivot_wider(
    names_from  = Feature,
    values_from = SFEI
  )

############################################################
# 4. 构建 ComBat 输入矩阵
############################################################

meta_data <- wide_data %>%
  select(Cohort, ID, Session, Site, Age, Subtype, Diagnosis)

feature_cols <- setdiff(
  colnames(wide_data),
  c("Cohort", "ID", "Session", "Site", "Age", "Subtype", "Diagnosis")
)

dat_matrix <- as.matrix(wide_data[, feature_cols])
dat_matrix <- t(dat_matrix)  # features × subjects

############################################################
# 5. 设置 batch 与协变量
############################################################

batch <- as.factor(meta_data$Site)

mod <- model.matrix(~ Age + Diagnosis, data = meta_data)

############################################################
# 6. 删除 constant features
############################################################

feature_sd <- apply(dat_matrix, 1, sd, na.rm = TRUE)
non_constant_idx <- which(feature_sd != 0)

cat("Removed", sum(feature_sd == 0), "constant features.\n")

dat_matrix   <- dat_matrix[non_constant_idx, ]
feature_cols <- feature_cols[non_constant_idx]

############################################################
# 7. 运行 ComBat
############################################################

combat_result <- neuroCombat(
  dat = dat_matrix,
  batch = batch,
  mod = mod,
  parametric = FALSE,
  eb = FALSE,
  mean.only = TRUE
)

############################################################
# 8. 获取 harmonized 数据
############################################################

dat_combat <- t(combat_result$dat.combat)
dat_combat <- as.data.frame(dat_combat)
colnames(dat_combat) <- feature_cols

harmonized_wide <- bind_cols(meta_data, dat_combat)

############################################################
# 9. 转回 long 格式
############################################################

harmonized_long <- harmonized_wide %>%
  pivot_longer(
    cols = all_of(feature_cols),
    names_to = "Feature",
    values_to = "SFEI_ComBat"
  ) %>%
  separate(
    Feature,
    into = c("Step", "Network"),
    sep = "_",
    remove = TRUE
  ) %>%
  mutate(
    Step = as.numeric(str_remove(Step, "S"))
  )

############################################################
# 11. 保存结果
############################################################

output_path <- "/Volumes/Zuolab_XRF/output/normative/SFEI_normative_data_combat.xlsx"

write.xlsx(harmonized_long, output_path, overwrite = TRUE)


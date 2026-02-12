############################################################
# ComBat harmonization for SFEI normative dataset
# Site correction (ABIDE multi-site + CCNP single site)
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
# 1. Load normative dataset
############################################################

data_path <- "/Volumes/Zuolab_XRF/output/normative/SFEI_normative_data.xlsx"

normative_data <- read.xlsx(data_path)

############################################################
# 2. 构建 feature = Step × Network
############################################################

normative_data <- normative_data %>%
  mutate(Feature = paste0("S", Step, "_", Network),
    Site = recode(Site, "NYU2" = "NYU"))

############################################################
# 3. 转为宽格式 (ID × Feature)
############################################################

wide_data <- normative_data %>%
  select(ID, Cohort, Site, Age, Feature, SFEI) %>%
  pivot_wider(
    names_from  = Feature,
    values_from = SFEI
  )

############################################################
# 4. 提取矩阵用于 ComBat
############################################################

# 保留人口学信息
meta_data <- wide_data %>%
  select(ID, Cohort, Site, Age)

# 提取 feature 列
feature_cols <- setdiff(colnames(wide_data),
                        c("ID", "Cohort", "Site", "Age"))

dat_matrix <- as.matrix(wide_data[, feature_cols])
dat_matrix <- t(dat_matrix)   # ComBat 需要 features × subjects

############################################################
# 5. 设置 batch 与协变量
############################################################

batch <- as.factor(meta_data$Site)     # 批变量：Site
age   <- meta_data$Age                # 生物学变量

mod <- model.matrix(~ age)            # 保留年龄效应

############################################################
# Remove constant features
############################################################

feature_sd <- apply(dat_matrix, 1, sd, na.rm = TRUE)

non_constant_idx <- which(feature_sd != 0)

dat_matrix <- dat_matrix[non_constant_idx, ]

feature_cols <- feature_cols[non_constant_idx]

############################################################
# 6. 运行 ComBat
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
# 7. 获取 harmonized 数据
############################################################

dat_combat <- t(combat_result$dat.combat)
dat_combat <- as.data.frame(dat_combat)
colnames(dat_combat) <- feature_cols

harmonized_wide <- bind_cols(meta_data, dat_combat)

############################################################
# 8. 转回 long 格式
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
# 9. 保存结果
############################################################

output_path <- "/Volumes/Zuolab_XRF/output/normative/SFEI_normative_data_combat.xlsx"

write.xlsx(harmonized_long, output_path, overwrite = TRUE)

cat("ComBat harmonization finished.\n")
cat("Saved to:\n", output_path)

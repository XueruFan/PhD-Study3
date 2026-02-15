############################################################
# ASD Individual Difference – Revised Version
# Step treated as structural factor (not core interaction)
############################################################

rm(list = ls())

library(tidyverse)
library(readxl)
library(openxlsx)
library(lme4)
library(lmerTest)
library(car)
library(ggplot2)

############################################################
# 路径
############################################################

data_path  <- "/Volumes/Zuolab_XRF/output/normative/gamlss_step1to5/ASD_centile_results.xlsx"
output_dir <- "/Volumes/Zuolab_XRF/output/normative/step_stat"

dir.create(output_dir, showWarnings = FALSE)

############################################################
# 读取数据
############################################################

df <- read_excel(data_path)

df <- df %>%
  mutate(
    Step = as.numeric(Step),
    Network = factor(Network),
    Subtype = factor(Subtype),
    abs_z = abs(z_score),
    abnormal = ifelse(abs_z > 2, 1, 0),
    extreme  = ifelse(abs_z > 3, 1, 0)
  )

############################################################
# 1️⃣ 整体偏离分布
############################################################

overall_summary <- df %>%
  summarise(
    N = n(),
    mean_z = mean(z_score),
    sd_z = sd(z_score),
    mean_abs_z = mean(abs_z),
    abnormal_rate = mean(abnormal),
    extreme_rate = mean(extreme)
  )

write.xlsx(overall_summary,
           file.path(output_dir, "01_overall_summary.xlsx"),
           overwrite = TRUE)

############################################################
# 2️⃣ 亚型整体差异
############################################################

model_subtype <- lmer(
  abs_z ~ Subtype + (1|ID),
  data = df,
  REML = FALSE
)

capture.output(summary(model_subtype),
               file = file.path(output_dir, "02_subtype_main_effect.txt"))

anova_subtype <- Anova(model_subtype, type = 3)

capture.output(anova_subtype,
               file = file.path(output_dir, "03_subtype_ANOVA.txt"))

############################################################
# 3️⃣ Step 主效应（不强调交互）
############################################################

model_step <- lmer(
  abs_z ~ Step + (1|ID) + (1|Network),
  data = df,
  REML = FALSE
)

capture.output(summary(model_step),
               file = file.path(output_dir, "04_step_main_effect.txt"))

anova_step <- Anova(model_step, type = 3)

capture.output(anova_step,
               file = file.path(output_dir, "05_step_ANOVA.txt"))

############################################################
# 4️⃣ Step × Subtype（仅报告，不作为核心）
############################################################

model_step_sub <- lmer(
  abs_z ~ Step * Subtype + (1|ID) + (1|Network),
  data = df,
  REML = FALSE
)

capture.output(summary(model_step_sub),
               file = file.path(output_dir, "06_step_subtype_model.txt"))

anova_step_sub <- Anova(model_step_sub, type = 3)

capture.output(anova_step_sub,
               file = file.path(output_dir, "07_step_subtype_ANOVA.txt"))

############################################################
# 5️⃣ Step 可视化（仅展示总体趋势）
############################################################

p_step <- ggplot(df,
                 aes(x = Step,
                     y = abs_z)) +
  stat_summary(fun = mean,
               geom = "line",
               linewidth = 1.2) +
  stat_summary(fun.data = mean_se,
               geom = "errorbar",
               width = 0.15) +
  theme_minimal(base_size = 14) +
  labs(
    y = "Mean |z|",
    x = "SFC Step"
  )

ggsave(file.path(output_dir, "08_step_main_effect_plot.png"),
       p_step,
       width = 6,
       height = 5,
       dpi = 300)

############################################################
# 完成
############################################################

cat("Revised step analysis completed.\n")

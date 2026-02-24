############################################################
# ASD Network-Focused Analysis (Statistically Complete)
############################################################

rm(list = ls())

library(tidyverse)
library(readxl)
library(openxlsx)
library(lme4)
library(lmerTest)
library(emmeans)
library(car)
library(ggplot2)

############################################################
# 路径
############################################################

data_path  <- "/Volumes/Zuolab_XRF/output/normative/centile/ASD_centile_results.xlsx"
output_dir <- "/Volumes/Zuolab_XRF/output/normative/centile/network_stat"

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
    # abs_z = abs(z_score) %  原始z值进行建模
  )

############################################################
# 1️⃣ 网络主效应模型
############################################################

model_net <- lmer(
  z_score ~ Network + (1|ID),
  data = df
)

# 保存summary
capture.output(summary(model_net),
               file = file.path(output_dir, "01_model_network_summary.txt"))

anova_net <- anova(model_net)

capture.output(anova_net,
               file = file.path(output_dir, "02_network_main_effect_ANOVA.txt"))

# 各网络均值
emm_net <- emmeans(model_net, ~ Network)
write.xlsx(as.data.frame(emm_net),
           file.path(output_dir, "03_network_means.xlsx"),
           overwrite = TRUE)

############################################################
# 2️⃣ 亚型 × 网络 交互模型
############################################################

model_net_sub <- lmer(
  z_score ~ Subtype * Network + (1|ID),
  data = df
)

capture.output(summary(model_net_sub),
               file = file.path(output_dir, "04_model_subtype_network_summary.txt"))

anova_net_sub <- anova(model_net_sub)

capture.output(anova_net_sub,
               file = file.path(output_dir, "05_subtype_network_ANOVA.txt"))

# 亚型在各网络的比较
emm_sub_net <- emmeans(model_net_sub, ~ Subtype | Network)

write.xlsx(as.data.frame(emm_sub_net),
           file.path(output_dir, "06_subtype_within_network.xlsx"),
           overwrite = TRUE)

############################################################
# 3️⃣ 三重交互模型（网络 × Step × 亚型）
############################################################

model_full <- lmer(
  z_score ~ Step * Subtype * Network + (1|ID),
  data = df
)

capture.output(summary(model_full),
               file = file.path(output_dir, "07_full_model_summary.txt"))

anova_full <- anova(model_full)

capture.output(anova_full,
               file = file.path(output_dir, "08_full_model_ANOVA.txt"))

############################################################
# 4️⃣ 各网络单独模型
############################################################

network_list <- levels(df$Network)

for (net in network_list) {
  
  sub_df <- df %>% filter(Network == net)
  
  model_single <- lmer(
    z_score ~ Step * Subtype + (1|ID),
    data = sub_df
  )
  
  capture.output(summary(model_single),
                 file = file.path(output_dir,
                                  paste0("09_", net, "_model_summary.txt")))
  
  anova_single <- anova(model_single)
  
  capture.output(anova_single,
                 file = file.path(output_dir,
                                  paste0("10_", net, "_ANOVA.txt")))
}

############################################################
# 5️⃣ 网络差异图
############################################################

p_net <- ggplot(df,
                aes(x = Network,
                    y = z_score,
                    fill = Subtype)) +
  stat_summary(fun = mean,
               geom = "bar",
               position = "dodge") +
  stat_summary(fun.data = mean_se,
               geom = "errorbar",
               position = position_dodge(width = 0.9),
               width = 0.2) +
  theme_minimal(base_size = 14) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(
    y = "z",
    x = "Functional Network"
  )

ggsave(file.path(output_dir, "11_network_difference_plot.png"),
       p_net,
       width = 8,
       height = 5,
       dpi = 300)

############################################################
# 6️⃣ 网络内层级图
############################################################

p_net_step <- ggplot(df,
                     aes(x = Step,
                         y = z_score,
                         color = Subtype)) +
  stat_summary(fun = mean,
               geom = "line") +
  facet_wrap(~Network) +
  theme_minimal(base_size = 12) +
  labs(
    y = "z",
    x = "Step"
  )

ggsave(file.path(output_dir, "12_network_step_profiles.png"),
       p_net_step,
       width = 12,
       height = 10,
       dpi = 300)

############################################################
# 完成
############################################################

cat("Network-focused statistically complete analysis finished.\n")

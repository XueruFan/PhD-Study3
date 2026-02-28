rm(list = ls())

library(tidyverse)
library(readxl)
library(openxlsx)
library(gamlss)
library(gamlss.add)
library(showtext)

set.seed(1234)

############################################################
# 字体
############################################################

font_add(
  family = "pingfang",
  regular = "/System/Library/Fonts/PingFang.ttc"
)
showtext_auto()
theme_set(theme_bw(base_family = "pingfang"))

############################################################
# 路径
############################################################

data_path  <- "/Volumes/Zuolab_XRF/output/ccnp/dcm/des/CCNP_RobustPCA_mechanism_full_summary.xlsx"
out_root   <- "/Volumes/Zuolab_XRF/output/ccnp/dcm/norm"
plot_dir   <- "/Volumes/Zuolab_XRF/output/ccnp/dcm/plot"

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

############################################################
# 读取 PCA 得分
############################################################

scores_rpca <- read_excel(data_path, sheet = "Scores")

scores_rpca <- scores_rpca %>%
  mutate(
    Age = as.numeric(Age),
    PC1 = as.numeric(PC1)
  ) %>%
  drop_na(Age, PC1)

############################################################
# 1️⃣ 构建 GAMLSS 模型
############################################################

model_pc1 <- gamlss(
  PC1 ~ pb(Age),            # 均值曲线
  sigma.formula = ~ pb(Age),# 方差曲线
  data = scores_rpca,
  family = NO()             # 正态分布
)

summary(model_pc1)

############################################################
# 2️⃣ 生成预测轨迹
############################################################

age_seq <- seq(
  min(scores_rpca$Age),
  max(scores_rpca$Age),
  length.out = 200
)

pred_df <- data.frame(Age = age_seq)

pred_mu    <- predict(model_pc1, newdata = pred_df, what = "mu", type="response")
pred_sigma <- predict(model_pc1, newdata = pred_df, what = "sigma", type="response")

pred_df$mu    <- pred_mu
pred_df$sigma <- pred_sigma

# 95% CI
pred_df$upper <- pred_mu + 1.96 * pred_sigma
pred_df$lower <- pred_mu - 1.96 * pred_sigma

############################################################
# 3️⃣ 计算个体 Z-score（normative deviation）
############################################################

mu_ind    <- predict(model_pc1, what="mu", type="response")
sigma_ind <- predict(model_pc1, what="sigma", type="response")

scores_rpca$Z_PC1 <- (scores_rpca$PC1 - mu_ind) / sigma_ind

############################################################
# 4️⃣ 可视化发育轨迹
############################################################

p_norm <- ggplot() +
  geom_point(data = scores_rpca,
             aes(x = Age, y = PC1),
             alpha = 0.4, size = 2) +
  geom_line(data = pred_df,
            aes(x = Age, y = mu),
            size = 1.5) +
  geom_ribbon(data = pred_df,
              aes(x = Age, ymin = lower, ymax = upper),
              alpha = 0.2) +
  theme_classic(base_size = 28) +
  labs(
    x = "年龄",
    y = "PC1 机制轴"
  )
p_norm

ggsave(
  file.path(plot_dir,"PC1_normative_trajectory.png"),
  p_norm,
  width = 3000,
  height = 2400,
  dpi = 300,
  units = "px"
)

############################################################
# 5️⃣ 保存结果
############################################################

wb <- createWorkbook()

addWorksheet(wb,"Normative_Trajectory")
writeData(wb,"Normative_Trajectory",pred_df)

addWorksheet(wb,"Individual_Z")
writeData(wb,"Individual_Z",scores_rpca)

saveWorkbook(
  wb,
  file.path(out_root,"PC1_normative_model.xlsx"),
  overwrite = TRUE
)
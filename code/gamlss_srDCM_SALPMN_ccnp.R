rm(list = ls())

library(tidyverse)
library(readxl)
library(openxlsx)
library(stringr)
library(neuroCombat)
library(gamlss)
library(gamlss.add)

set.seed(1234)

############################################################
# 读取 ABIDE
############################################################

abide_path  <- "/Volumes/Zuolab_XRF/output/abide/dcm/sum/ABIDE_srDCM_summary.xlsx"
abide_demo  <- "/Volumes/Zuolab_XRF/output/abide/sfc/des/zSFEI_abide_demo.csv"

abide_dcm <- read_excel(abide_path) %>%
  mutate(subject = as.character(as.numeric(subject)))

abide_demo_df <- read.csv(abide_demo) %>%
  mutate(subject = as.character(as.numeric(Subject))) %>%
  dplyr::select(-Subject)

abide_df <- left_join(abide_demo_df, abide_dcm, by="subject") %>%
  filter(
    Sex == "Male",
    Age <= 18,
    Subtype == "TD"
  ) %>%
  mutate(dataset = "ABIDE")

############################################################
# 读取 CCNP
############################################################

ccnp_path <- "/Volumes/Zuolab_XRF/output/ccnp/dcm/sum/pek_srdcm_fd0.3_sessionAvg.xlsx"

ccnp_df <- read_excel(ccnp_path) %>%
  filter(
    Sex == "男",
    Age <= 18
  ) %>%
  mutate(
    subject = Participant,
    Subtype = "TD",
    dataset = "CCNP"
  )

############################################################
# 统一列结构
############################################################

common_cols <- intersect(colnames(abide_df), colnames(ccnp_df))

td_df <- bind_rows(
  abide_df[, common_cols],
  ccnp_df[, common_cols]
)

############################################################
# 提取 SAL/PMN 边
############################################################

ec_cols <- grep("^EC_", colnames(td_df), value=TRUE)

sal_edges <- ec_cols[
  str_detect(ec_cols, "EC_14_to_") |
    str_detect(ec_cols, "_to_14")
]

# 删除自连接
sal_edges <- sal_edges[
  !str_detect(sal_edges, "EC_14_to_14")
]

############################################################
# ComBat
############################################################

ec_matrix <- as.matrix(td_df[, sal_edges])

combat_input <- t(ec_matrix)
batch <- as.factor(td_df$dataset)

mod <- model.matrix(~ Age, data=td_df)

combat_res <- neuroCombat(
  dat = combat_input,
  batch = batch,
  mod = mod,
  mean.only = TRUE
)

ec_combat <- t(combat_res$dat.combat)

############################################################
# GAMLSS
############################################################

norm_results <- list()

for(i in 1:ncol(ec_combat)){
  
  edge_name <- colnames(ec_combat)[i]
  
  data_tmp <- data.frame(
    Age  = td_df$Age,
    Edge = ec_combat[,i]
  )
  
  model <- gamlss(
    Edge ~ pb(Age),
    sigma.formula = ~ pb(Age),
    family = NO(),
    data = data_tmp
  )
  
  norm_results[[edge_name]] <- model
}

############################################################
#  保存模
############################################################

norm_dir <- "/Volumes/Zuolab_XRF/output/norm_rsDCM/SALPMN"
dir.create(norm_dir, recursive = TRUE, showWarnings = FALSE)

saveRDS(
  norm_results,
  file = file.path(norm_dir, "SALPMN_norm_models.rds")
)

############################################################
# 画图
############################################################

age_seq <- seq(
  min(td_df$Age, na.rm = TRUE),
  max(td_df$Age, na.rm = TRUE),
  length.out = 200
)

norm_curve_all <- data.frame()

for(edge in names(norm_results)){
  
  model <- norm_results[[edge]]
  
  # 预测
  mu <- predict(model,
                newdata = data.frame(Age = age_seq),
                what = "mu",
                type = "response")
  
  sigma <- predict(model,
                   newdata = data.frame(Age = age_seq),
                   what = "sigma",
                   type = "response")
  
  plot_df <- data.frame(
    Age   = age_seq,
    Mu    = mu,
    Sigma = sigma,
    Lower = mu - 2 * sigma,
    Upper = mu + 2 * sigma,
    Edge  = edge
  )
  
  norm_curve_all <- bind_rows(norm_curve_all, plot_df)
  
  ############################################################
  # 原始 TD 数据
  ############################################################
  
  raw_df <- data.frame(
    Age  = td_df$Age,
    Edge = ec_combat[, edge]
  )
  
  ############################################################
  # 绘图
  ############################################################
  
  p <- ggplot() +
    geom_point(data = raw_df,
               aes(x = Age, y = Edge),
               alpha = 0.3,
               size = 1.8) +
    geom_ribbon(data = plot_df,
                aes(x = Age,
                    ymin = Lower,
                    ymax = Upper),
                fill = "#86b5a1",
                alpha = 0.25) +
    geom_line(data = plot_df,
              aes(x = Age, y = Mu),
              color = "#e47159",
              size = 1.3) +
    theme_classic(base_size = 22) +
    labs(
      title = edge,
      x = "Age",
      y = "Effective Connectivity"
    )
  
  ggsave(
    filename = file.path(norm_dir, "plot",
                         paste0(edge, "_norm_curve.png")),
    plot = p,
    width = 2800,
    height = 2400,
    dpi = 300,
    units = "px"
  )
}

############################################################
# 保存所有预测曲线
############################################################

write.xlsx(
  norm_curve_all,
  file.path(norm_dir,
            "SALPMN_normative_curves_summary.xlsx"),
  overwrite = TRUE
)
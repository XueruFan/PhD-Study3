rm(list = ls())

library(tidyverse)
library(readxl)
library(openxlsx)
library(neuroCombat)
library(rrcov)
library(effectsize)
library(emmeans)
library(showtext)
library(reshape2)
library(broom)
library(dplyr)
library(stringr)
library(ggplot2)

set.seed(1205)

############################################################
font_add(
  family = "pingfang",
  regular = "/System/Library/Fonts/PingFang.ttc"
)
showtext_auto()
theme_set(theme_bw(base_family = "pingfang"))

############################################################
out_root <- "/Volumes/Zuolab_XRF/output/abide/dcm/des/rDCM/All"
plot_dir <- "/Volumes/Zuolab_XRF/output/abide/dcm/plot/rDCM/All"

############################################################

dcm_path  <- "/Volumes/Zuolab_XRF/output/abide/dcm/sum/ABIDE_rDCM_summary.xlsx"
demo_path <- "/Volumes/Zuolab_XRF/output/abide/sfc/des/zSFEI_abide_demo.csv"

dcm_df <- read_excel(dcm_path) %>%
  mutate(subject = as.character(as.numeric(subject)))

demo_df <- read.csv(demo_path) %>%
  mutate(subject = as.character(as.numeric(Subject))) %>%
  dplyr::select(-Subject)

df <- left_join(demo_df, dcm_df, by = "subject") %>%
  mutate(
    site = recode(site, "NYU2" = "NYU"),
    Subtype = factor(Subtype, levels = c("TD","ASD-L","ASD-H")),
    Diagnosis = case_when(
      Subtype == "TD" ~ "TD",
      Subtype %in% c("ASD-L", "ASD-H") ~ "ASD",
      TRUE ~ NA_character_
    ),
    Diagnosis = factor(Diagnosis),
  )

############################################################
# 提取有效连接
ec_cols <- grep("^EC_", colnames(df), value = TRUE)
ec_matrix <- as.matrix(df[, ec_cols])

############################################################
# ComBat

combat_input <- t(ec_matrix)
batch <- as.factor(df$site)
mod <- model.matrix(~ Age + Subtype, data = df)

combat_res <- neuroCombat(
  dat = combat_input,
  batch = batch,
  mod = mod,
  parametric = TRUE,
  eb = TRUE,
  mean.only = TRUE
)

ec_matrix_combat <- t(combat_res$dat.combat)

############################################################
# 删除零方差边
edge_variance <- apply(ec_matrix_combat, 2, var)
ec_matrix_combat <- ec_matrix_combat[, edge_variance > 0]

############################################################
# 标准化
ec_matrix_scaled <- scale(ec_matrix_combat)

############################################################
# Robust PCA
# n_samples  <- nrow(ec_matrix_scaled)
# n_features <- ncol(ec_matrix_scaled)
# k_max      <- min(n_samples - 1, n_features)

k_max <- 3

rpca_res <- PcaHubert(
  ec_matrix_scaled,
  k = k_max,
  scale = FALSE
)

# 提取得分
scores_rpca <- as.data.frame(rpca_res@scores)
scores_rpca <- scores_rpca %>% 
  mutate(subject = df$subject, 
          Subtype = df$Subtype, 
          Age = df$Age, 
          site = df$site )

############################################################
# 提取载荷
############################################################

loadings_rpca <- as.data.frame(rpca_res@loadings)
colnames(loadings_rpca) <- paste0("PC",1:ncol(loadings_rpca))
loadings_rpca$edge <- colnames(ec_matrix_scaled)

############################################################

# ===== 计算 classical explained variance =====

load_mat <- as.matrix(loadings_rpca[,1:k_max])

scores_classical <- as.matrix(ec_matrix_scaled) %*% load_mat

pc_variances <- apply(scores_classical, 2, var)

total_variance <- sum(apply(ec_matrix_scaled, 2, var))

variance_ratio <- pc_variances / total_variance

variance_df <- data.frame(
  PC = paste0("PC",1:k_max),
  PC_Variance = pc_variances,
  Variance_Explained = variance_ratio,
  Cumulative = cumsum(variance_ratio)
)

############################################################
# 对 PC1–PC5 全部做 LM + 事后比较
############################################################

wb <- createWorkbook()

# 保存基础数据
addWorksheet(wb,"Scores")
writeData(wb,"Scores",scores_rpca)

addWorksheet(wb,"Loadings")
writeData(wb,"Loadings",loadings_rpca)

addWorksheet(wb,"Variance")
writeData(wb,"Variance",variance_df)

############################################################

pcs <- paste0("PC",1:k_max)
  
for (pc in pcs) {
  
  formula_str <- as.formula(
    paste0(pc," ~ Subtype + Age + site")
  )
  
  lm_model <- lm(formula_str, data = scores_rpca)
  
  summary_df  <- broom::tidy(lm_model)
  anova_df    <- broom::tidy(anova(lm_model))
  eta_df      <- as.data.frame(eta_squared(lm_model))
  
  emm_res     <- emmeans(lm_model, pairwise ~ Subtype)
  emm_df      <- as.data.frame(emm_res$emmeans)
  contrast_df <- as.data.frame(emm_res$contrasts)
  
  # ===== 写入不同 sheet =====
  addWorksheet(wb,paste0(pc,"_LM"))
  writeData(wb,paste0(pc,"_LM"),summary_df)
  
  addWorksheet(wb,paste0(pc,"_ANOVA"))
  writeData(wb,paste0(pc,"_ANOVA"),anova_df)
  
  addWorksheet(wb,paste0(pc,"_EffectSize"))
  writeData(wb,paste0(pc,"_EffectSize"),eta_df)
  
  addWorksheet(wb,paste0(pc,"_EMMEANS"))
  writeData(wb,paste0(pc,"_EMMEANS"),emm_df)
  
  addWorksheet(wb,paste0(pc,"_Contrasts"))
  writeData(wb,paste0(pc,"_Contrasts"),contrast_df)
}

saveWorkbook(
  wb,
  file.path(out_root,"RobustPCA_AllComponents.xlsx"),
  overwrite = TRUE
)

############################################################
# 所有机制轴分布图
############################################################

for (pc in pcs) {
  
  p_axis <- ggplot(scores_rpca,
                   aes_string(x = "Subtype", y = pc, fill = "Subtype")) +
    geom_violin(trim = FALSE, alpha = 0.4) +
    geom_boxplot(width = 0.15, outlier.shape = NA) +
    geom_jitter(width = 0.08, alpha = 0.6) +
    scale_fill_manual(
      values = c(
        "TD"    = "white",
        "ASD-L" = "#86b5a1",
        "ASD-H" = "#f9ae78"
      )
    ) +
    theme_classic(base_size = 28) +
    theme(
      legend.position = "none",
      axis.title = element_blank(),
      axis.text  = element_text(size = 20)
    )
  
  ggsave(
    file.path(plot_dir,
              paste0("RobustPCA_",pc,"_axis.png")),
    p_axis,
    width = 3000,
    height = 2400,
    dpi = 300,
    units = "px"
  )
}

pc_pairs <- combn(pcs,2)

for (i in 1:ncol(pc_pairs)) {

  xpc <- pc_pairs[1,i]
  ypc <- pc_pairs[2,i]

  p_space <- ggplot(scores_rpca,
                    aes_string(x = xpc, y = ypc, color = "Subtype")) +
    geom_point(size = 4, alpha = 0.85) +
    scale_color_manual(
      values = c(
        "TD"    = "black",
        "ASD-L" = "#86b5a1",
        "ASD-H" = "#f9ae78"
      )
    ) +
    theme_classic(base_size = 28)

  ggsave(
    file.path(plot_dir,
              paste0("RobustPCA_",xpc,"_",ypc,"_space.png")),
    p_space,
    width = 3000,
    height = 2400,
    dpi = 300,
    units = "px"
  )
}
############################################################

network_labels_custom <- c(
  5,13,1,
  4,8,
  14,
  6,
  2,
  7,12,
  10,11,
  3,15,
  9
)

network_networks_custom <- c(
  "AUD",
  "VIS-C","VIS-P",
  "SMOT-B","SMOT-A",
  "SAL",
  "PM-PPr",
  "AN",
  "dATN-B","dATN-A",
  "FPN-B","FPN-A",
  "DN-B","DN-A",
  "LANG"
)

network_map_custom <- tibble(
  Label = network_labels_custom,
  Network = network_networks_custom
)

############################################################
# 热图函数
############################################################

make_heatmap <- function(pc_name){
  
  load_df <- loadings_rpca %>%
    mutate(
      From = as.integer(str_extract(edge,"(?<=EC_)\\d+")),
      To   = as.integer(str_extract(edge,"(?<=to_)\\d+"))
    ) %>%
    dplyr::select(From,To,!!sym(pc_name))
  
  colnames(load_df)[3] <- "Loading"

  load_df_full <- load_df %>%
    left_join(network_map_custom, by = c("From" = "Label")) %>%
    rename(FromNetwork = Network) %>%
    left_join(network_map_custom, by = c("To" = "Label")) %>%
    rename(ToNetwork = Network)
  
  load_df_full$FromNetwork <- factor(
    load_df_full$FromNetwork,
    levels = network_networks_custom
  )
  
  load_df_full$ToNetwork <- factor(
    load_df_full$ToNetwork,
    levels = network_networks_custom
  )
  
  p_heat <- ggplot(load_df_full,
                   aes(x=ToNetwork, y=FromNetwork, fill=Loading)) +
    geom_tile(color="lightgray",linewidth=0.4) +
    scale_fill_gradient2(low="#3d5c6f",
                         mid="white",
                         high="#e47159",
                         midpoint=0) +
    theme_bw(base_size=26) +
    theme(axis.text.x=element_text(angle=45,hjust=1))
  
  ggsave(
    file.path(plot_dir,
              paste0("RobustPCA_",pc_name,"_heatmap.png")),
    p_heat,
    width=3400,
    height=3000,
    dpi=300,
    units="px"
  )
}

make_heatmap("PC1")
make_heatmap("PC2")
make_heatmap("PC3")
# make_heatmap("PC4")
# make_heatmap("PC5")


############################################################
# 计算节点贡献函数
############################################################

compute_node_contribution <- function(pc_name){
  
  load_df <- loadings_rpca %>%
    mutate(
      From = as.integer(str_extract(edge,"(?<=EC_)\\d+")),
      To   = as.integer(str_extract(edge,"(?<=to_)\\d+"))
    ) %>%
    dplyr::select(From,To,!!sym(pc_name))
  
  colnames(load_df)[3] <- "Loading"
  
  load_df_full <- load_df %>%
    left_join(network_map_custom, by = c("From" = "Label")) %>%
    rename(FromNetwork = Network) %>%
    left_join(network_map_custom, by = c("To" = "Label")) %>%
    rename(ToNetwork = Network)
  
  load_df_full$FromNetwork <- factor(
    load_df_full$FromNetwork,
    levels = network_networks_custom
  )
  
  load_df_full$ToNetwork <- factor(
    load_df_full$ToNetwork,
    levels = network_networks_custom
  )
  
  node_df <- load_df_full %>%
    group_by(ToNetwork) %>%
    summarise(To_abs=sum(abs(Loading),na.rm=TRUE)) %>%
    rename(Node=ToNetwork) %>%
    left_join(
      load_df_full %>%
        group_by(FromNetwork) %>%
        summarise(From_abs=sum(abs(Loading),na.rm=TRUE)) %>%
        rename(Node=FromNetwork),
      by="Node"
    ) %>%
    mutate(
      To_z=as.numeric(scale(To_abs)),
      From_z=as.numeric(scale(From_abs))
    ) %>%
    left_join(network_map_custom,by=c("Node"="Network"))
  
  return(node_df)
}

node_pc1 <- compute_node_contribution("PC1")
node_pc2 <- compute_node_contribution("PC2")
node_pc3 <- compute_node_contribution("PC3")
# node_pc4 <- compute_node_contribution("PC4")
# node_pc5 <- compute_node_contribution("PC5")

key_pc1 <- node_pc1 %>% filter(abs(To_z)>2 | abs(From_z)>2)
key_pc2 <- node_pc2 %>% filter(abs(To_z)>2 | abs(From_z)>2)
key_pc3 <- node_pc3 %>% filter(abs(To_z)>2 | abs(From_z)>2)
# key_pc4 <- node_pc4 %>% filter(abs(To_z)>2 | abs(From_z)>2)
# key_pc5 <- node_pc5 %>% filter(abs(To_z)>2 | abs(From_z)>2)


############################################################
# 自动验证函数
############################################################

validate_axis <- function(pc_name, key_df){
  
  edge_info <- tibble(edge = colnames(ec_matrix_scaled)) %>%
    mutate(
      From = as.integer(str_extract(edge,"(?<=EC_)\\d+")),
      To   = as.integer(str_extract(edge,"(?<=to_)\\d+"))
    )
  
  results <- list()
  idx <- 1
  
  for(i in 1:nrow(key_df)){
    
    node_id   <- key_df$Label[i]
    node_name <- key_df$Node[i]
    
    # -------- incoming 方向 --------
    if(abs(key_df$To_z[i]) > 2){
      
      node_edges <- edge_info %>% 
        filter(To == node_id) %>% 
        pull(edge)
      
      node_strength <- ec_matrix_scaled[, node_edges, drop = FALSE] %>%
        as.data.frame() %>%
        mutate(Node_mean = rowMeans(.))
      
      data_tmp <- scores_rpca %>% bind_cols(node_strength)
      
      cor_res <- cor.test(
        data_tmp[[pc_name]],
        data_tmp$Node_mean
      )
      
      results[[idx]] <- data.frame(
        PC = pc_name,
        Network = node_name,
        Direction = "incoming",
        r = cor_res$estimate,
        p_value = cor_res$p.value
      )
      
      idx <- idx + 1
    }
    
    # -------- outgoing 方向 --------
    if(abs(key_df$From_z[i]) > 2){
      
      node_edges <- edge_info %>% 
        filter(From == node_id) %>% 
        pull(edge)
      
      node_strength <- ec_matrix_scaled[, node_edges, drop = FALSE] %>%
        as.data.frame() %>%
        mutate(Node_mean = rowMeans(.))
      
      data_tmp <- scores_rpca %>% bind_cols(node_strength)
      
      cor_res <- cor.test(
        data_tmp[[pc_name]],
        data_tmp$Node_mean
      )
      
      results[[idx]] <- data.frame(
        PC = pc_name,
        Network = node_name,
        Direction = "outgoing",
        r = cor_res$estimate,
        p_value = cor_res$p.value
      )
      
      idx <- idx + 1
    }
  }
  
  return(do.call(rbind, results))
}

cor_pc1 <- validate_axis("PC1",key_pc1)
cor_pc2 <- validate_axis("PC2",key_pc2)
cor_pc3 <- validate_axis("PC3",key_pc3)
# cor_pc4 <- validate_axis("PC4",key_pc4)
# cor_pc5 <- validate_axis("PC5",key_pc5)

############################################################
# 保存全部结果
############################################################

wb <- createWorkbook()

for (i in c(1,2,3)) {
  
  node_obj <- get(paste0("node_pc", i))
  key_obj  <- get(paste0("key_pc", i))
  cor_obj  <- get(paste0("cor_pc", i))
  
  addWorksheet(wb, paste0("Node_PC", i))
  writeData(wb, paste0("Node_PC", i), node_obj)
  
  addWorksheet(wb, paste0("Key_PC", i))
  writeData(wb, paste0("Key_PC", i), key_obj)
  
  addWorksheet(wb, paste0("Cor_PC", i))
  writeData(wb, paste0("Cor_PC", i), cor_obj)
}

saveWorkbook(
  wb,
  file.path(out_root,
            "RobustPCA_Correlations.xlsx"),
  overwrite=TRUE
)

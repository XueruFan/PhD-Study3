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
library(gamlss)
library(gamlss.add)

set.seed(1234)

############################################################
font_add(
  family = "pingfang",
  regular = "/System/Library/Fonts/PingFang.ttc"
)
showtext_auto()
theme_set(theme_bw(base_family = "pingfang"))

############################################################
out_root <- "/Volumes/Zuolab_XRF/output/ccnp/dcm/des"
plot_dir <- "/Volumes/Zuolab_XRF/output/ccnp/dcm/plot"

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

############################################################

dcm_path  <- "/Volumes/Zuolab_XRF/output/ccnp/dcm/sum/pek_srdcm_fd0.3_sessionAvg.xlsx"

df <- read_excel(dcm_path) %>%
  filter(Sex == "男",
         Age <= 18 ) %>% 
  dplyr::select(-Sex)

############################################################
# 提取有效连接

ec_cols <- grep("^EC_", colnames(df), value = TRUE)
ec_matrix <- as.matrix(df[, ec_cols])

############################################################
# 删除对角线边（From == To）
ec_cols_no_diag <- ec_cols[
  !str_detect(ec_cols, "EC_(\\d+)_to_\\1$")
]

ec_matrix <- as.matrix(df[, ec_cols_no_diag])

# 标准化
ec_matrix_scaled <- scale(ec_matrix)

############################################################
# Robust PCA（完整维度）
############################################################

n_samples  <- nrow(ec_matrix_scaled)
n_features <- ncol(ec_matrix_scaled)
k_max      <- min(n_samples - 1, n_features)

rpca_res <- PcaHubert(
  ec_matrix_scaled,
  k = k_max,
  scale = FALSE
)

############################################################
# 提取得分
############################################################

scores_rpca <- as.data.frame(rpca_res@scores)
colnames(scores_rpca) <- paste0("PC",1:ncol(scores_rpca))

scores_rpca <- scores_rpca %>%
  mutate(
    subject = df$Participant,
    Age     = as.numeric(df$Age)
  )

############################################################
# 提取载荷
############################################################

loadings_rpca <- as.data.frame(rpca_res@loadings)
colnames(loadings_rpca) <- paste0("PC",1:ncol(loadings_rpca))
loadings_rpca$edge <- colnames(ec_matrix_scaled)

############################################################
# 计算真实解释方差比例
############################################################

eigenvalues <- rpca_res@eigenvalues

# 原始总方差
total_variance <- sum(apply(ec_matrix_scaled, 2, var))

variance_ratio <- eigenvalues / total_variance

variance_df <- data.frame(
  PC = paste0("PC",1:length(eigenvalues)),
  Eigenvalue = eigenvalues,
  Variance_Explained = variance_ratio,
  Cumulative = cumsum(variance_ratio)
)

############################################################
# Scree Plot
############################################################

p_scree <- ggplot(variance_df,
                  aes(x = as.numeric(gsub("PC","",PC)),
                      y = Variance_Explained)) +
  geom_point(size=3) +
  geom_line() +
  theme_classic(base_size=24) +
  labs(x="主成分编号",
       y="解释原始总方差比例")

ggsave(
  file.path(plot_dir,"RobustPCA_ScreePlot_full.png"),
  p_scree,
  width=2400,
  height=2000,
  dpi=300,
  units="px"
)

############################################################
# 网络标签映射
############################################################

network_order_custom <- c(
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

network_labels_custom <- c(
  "AUD",
  "VIS-C","VIS-P",
  "SMOT-B","SMOT-A",
  "SAL/PMN",
  "PM-PPr",
  "AN",
  "dATN-B","dATN-A",
  "FPN-B","FPN-A",
  "DN-B","DN-A",
  "LANG"
)

network_map_custom <- tibble(
  Order = network_order_custom,
  Label = network_labels_custom
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
  
  full_grid <- expand.grid(
    From=1:15,
    To=1:15
  )
  
  load_df_full <- full_grid %>%
    left_join(load_df,by=c("From","To")) %>%
    left_join(network_map_custom,by=c("From"="Order")) %>%
    rename(FromLabel=Label) %>%
    left_join(network_map_custom,by=c("To"="Order")) %>%
    rename(ToLabel=Label)
  
  load_df_full$FromLabel <- factor(
    load_df_full$FromLabel,
    levels=rev(network_labels_custom)
  )
  
  load_df_full$ToLabel <- factor(
    load_df_full$ToLabel,
    levels=network_labels_custom
  )
  
  p_heat <- ggplot(load_df_full,
                   aes(x=ToLabel,y=FromLabel,fill=Loading)) +
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
  
  node_df <- load_df %>%
    group_by(To) %>%
    summarise(In_abs=sum(abs(Loading),na.rm=TRUE)) %>%
    rename(Node=To) %>%
    left_join(
      load_df %>%
        group_by(From) %>%
        summarise(Out_abs=sum(abs(Loading),na.rm=TRUE)) %>%
        rename(Node=From),
      by="Node"
    ) %>%
    mutate(
      In_z=as.numeric(scale(In_abs)),
      Out_z=as.numeric(scale(Out_abs))
    ) %>%
    left_join(network_map_custom,by=c("Node"="Order"))
  
  return(node_df)
}

node_pc1 <- compute_node_contribution("PC1")
node_pc2 <- compute_node_contribution("PC2")

key_pc1 <- node_pc1 %>% filter(abs(In_z)>2 | abs(Out_z)>2)
key_pc2 <- node_pc2 %>% filter(abs(In_z)>2 | abs(Out_z)>2)

############################################################
# 自动验证函数
############################################################

validate_axis <- function(pc_name,key_df){
  
  edge_info <- tibble(edge=colnames(ec_matrix_scaled)) %>%
    mutate(
      From=as.integer(str_extract(edge,"(?<=EC_)\\d+")),
      To=as.integer(str_extract(edge,"(?<=to_)\\d+"))
    )
  
  results <- list()
  
  for(i in 1:nrow(key_df)){
    
    node_id   <- key_df$Node[i]
    node_name <- key_df$Label[i]
    
    direction <- ifelse(abs(key_df$In_z[i]) >
                          abs(key_df$Out_z[i]),
                        "incoming","outgoing")
    
    if(direction=="incoming"){
      node_edges <- edge_info %>% filter(To==node_id) %>% pull(edge)
    }else{
      node_edges <- edge_info %>% filter(From==node_id) %>% pull(edge)
    }
    
    node_strength <- ec_matrix_scaled[,node_edges] %>%
      as.data.frame() %>%
      mutate(Node_mean=rowMeans(.))
    
    data_tmp <- scores_rpca %>% bind_cols(node_strength)
    
    cor_res <- cor.test(
      data_tmp[[pc_name]],
      data_tmp$Node_mean
    )
    
    cor_df <- data.frame(
      PC=pc_name,
      Network=node_name,
      Direction=direction,
      r=cor_res$estimate,
      p_value=cor_res$p.value
    )
    
    results[[i]] <- cor_df
  }
  
  return(do.call(rbind,results))
}

cor_pc1 <- validate_axis("PC1",key_pc1)
cor_pc2 <- validate_axis("PC2",key_pc2)

############################################################
# 保存全部结果
############################################################

wb <- createWorkbook()

addWorksheet(wb,"Scores")
writeData(wb,"Scores",scores_rpca)

addWorksheet(wb,"Loadings")
writeData(wb,"Loadings",loadings_rpca)

addWorksheet(wb,"Variance")
writeData(wb,"Variance",variance_df)

addWorksheet(wb,"Node_PC1")
writeData(wb,"Node_PC1",node_pc1)

addWorksheet(wb,"Key_PC1")
writeData(wb,"Key_PC1",key_pc1)

addWorksheet(wb,"Cor_PC1")
writeData(wb,"Cor_PC1",cor_pc1)

addWorksheet(wb,"Node_PC2")
writeData(wb,"Node_PC2",node_pc2)

addWorksheet(wb,"Key_PC2")
writeData(wb,"Key_PC2",key_pc2)

addWorksheet(wb,"Cor_PC2")
writeData(wb,"Cor_PC2",cor_pc2)

saveWorkbook(
  wb,
  file.path(out_root,
            "CCNP_RobustPCA_mechanism_full_summary.xlsx"),
  overwrite=TRUE
)
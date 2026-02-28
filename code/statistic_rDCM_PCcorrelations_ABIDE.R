############################################################
# PC1–PC5 × Cognition Correlation
# Stratified by Subtype (ASD-L / ASD-H)
# GLOBAL FDR correction
############################################################

rm(list = ls())

packages <- c(
  "tidyverse", "readxl", "openxlsx",
  "dplyr", "stats"
)
sapply(packages, require, character.only = TRUE)

set.seed(1205)

############################################################
# 路径
############################################################

pcFile     <- "/Volumes/Zuolab_XRF/output/abide/dcm/des/rDCM/All/RobustPCA_AllComponents.xlsx"
phenoFile  <- "/Volumes/Zuolab_XRF/supplement/abide/abide_A_all_240315.csv"

outDir <- "/Volumes/Zuolab_XRF/output/abide/dcm/stat/corr/rDCM/All"

############################################################
# 读取 PCA 得分
############################################################

scores <- read_excel(pcFile, sheet = "Scores")

scores <- scores %>%
  mutate(
    participant = as.character(subject),
    Subtype = factor(Subtype)
  )

############################################################
# 读取行为数据
############################################################

pheno <- read.csv(phenoFile, stringsAsFactors = FALSE)
colnames(pheno)[colnames(pheno) == "Participant"] <- "participant"
pheno$participant <- as.character(pheno$participant)

# 清理负值
pheno <- pheno %>%
  mutate(across(where(is.numeric), ~ ifelse(.x < 0, NA, .x)))

############################################################
# 行为变量
############################################################

names_cog_p <- c(
  "ADOS_2_SOCAFFECT", "ADOS_2_TOTAL",
  "ADI_R_SOCIAL_TOTAL_A", "ADI_R_RRB_TOTAL_C",
  "SRS_TOTAL_RAW", "SRS_COGNITION_RAW",
  "SRS_AWARENESS_RAW", "SRS_COMMUNICATION_RAW",
  "SRS_MOTIVATION_RAW", "SRS_MANNERISMS_RAW"
)

names_cog_s <- c("ADOS_2_RRB")

############################################################
# 合并数据
############################################################

data_all <- scores %>%
  left_join(pheno, by = "participant")

data_all$Site <- as.factor(data_all$site)

############################################################
# 主循环
############################################################

all_results <- list()

pcs <- paste0("PC", 1:3)

for (pc in pcs) {
  
  for (cl in c("ASD-L", "ASD-H")) {
    
    dat_sub <- data_all %>%
      filter(Subtype == cl)
    
    ########################################################
    ## ---------- Spearman ----------
    ########################################################
    
    for (cog in names_cog_s) {
      
      temp <- dat_sub[, c(pc, cog, "Site")]
      temp <- temp[complete.cases(temp), ]
      if (nrow(temp) < 40) next
      
      # 控制站点
      if (length(unique(temp$Site)) > 1) {
        y_lm <- lm(temp[[cog]] ~ Site, data = temp)
        x_lm <- lm(temp[[pc]] ~ Site, data = temp)
      } else {
        y_lm <- lm(temp[[cog]] ~ 1, data = temp)
        x_lm <- lm(temp[[pc]] ~ 1, data = temp)
      }
      
      cor_test <- cor.test(
        residuals(x_lm),
        residuals(y_lm),
        method = "spearman"
      )
      
      all_results[[length(all_results)+1]] <- data.frame(
        PC = pc,
        cluster = cl,
        name_cog = cog,
        coef = cor_test$estimate,
        p_value = cor_test$p.value,
        n = nrow(temp),
        df = df.residual(y_lm),
        method = "spearman"
      )
    }
    
    ########################################################
    ## ---------- Pearson ----------
    ########################################################
    
    for (cog in names_cog_p) {
      
      temp <- dat_sub[, c(pc, cog, "Site")]
      temp <- temp[complete.cases(temp), ]
      if (nrow(temp) < 40) next
      
      if (length(unique(temp$Site)) > 1) {
        y_lm <- lm(temp[[cog]] ~ Site, data = temp)
        x_lm <- lm(temp[[pc]] ~ Site, data = temp)
      } else {
        y_lm <- lm(temp[[cog]] ~ 1, data = temp)
        x_lm <- lm(temp[[pc]] ~ 1, data = temp)
      }
      
      cor_test <- cor.test(
        residuals(x_lm),
        residuals(y_lm),
        method = "pearson"
      )
      
      all_results[[length(all_results)+1]] <- data.frame(
        PC = pc,
        cluster = cl,
        name_cog = cog,
        coef = cor_test$estimate,
        p_value = cor_test$p.value,
        n = nrow(temp),
        df = df.residual(y_lm),
        method = "pearson"
      )
    }
  }
}

############################################################
# 合并结果 + FDR
############################################################

final_results <- bind_rows(all_results)
# 
# # global FDR（按 cluster 分组）
# final_results <- final_results %>%
#   group_by(cluster) %>%
#   mutate(P_adj_cluster = p.adjust(p_value, method = "fdr")) %>%
#   ungroup()

############################################################
# 保存完整结果
############################################################

write.csv(
  final_results,
  file.path(outDir, "PC_cognition_correlation.csv"),
  row.names = FALSE
)

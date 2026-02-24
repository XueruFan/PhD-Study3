############################################################
# Step × Network z_score × Cognition Correlation
# Stratified by Subtype (L / H)
# GLOBAL FDR correction
############################################################

rm(list = ls())

packages <- c(
  "tidyverse", "readxl", "openxlsx",
  "dplyr", "stats"
)
sapply(packages, require, character.only = TRUE)

############################################################
# 路径
############################################################

z_scoreFile <- "/Volumes/Zuolab_XRF/output/normative/centile/ASD_centile_results.xlsx"
phenoFile   <- "/Volumes/Zuolab_XRF/supplement/abide/abide_A_all_240315.csv"
clusterFile <- "/Volumes/Zuolab_XRF/output/abide/ABIDE_cluster_all_subjects.csv"

outDir <- "/Volumes/Zuolab_XRF/output/abide/sfc/stat/corr"
dir.create(outDir, showWarnings = FALSE)

############################################################
# 读取 z_score 数据
############################################################

z_score_data <- read_excel(z_scoreFile)

z_score_data <- z_score_data %>%
  mutate(
    participant = as.character(ID),
    Step = paste0("step", sprintf("%02d", as.numeric(Step))),
    Network = as.character(Network)
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
# 认知变量
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

data_all <- z_score_data %>%
  left_join(pheno, by = "participant")

data_all$Site <- as.factor(data_all$Site)
data_all$Subtype <- factor(data_all$Subtype)

############################################################
# 主循环
############################################################

all_results <- list()

steps <- unique(data_all$Step)
networks <- unique(data_all$Network)

for (st in steps) {
  for (net in networks) {
    # st <- "step02"
    # net <- "Net01"
    # cl <- "ASD-H"
    # cog <- "ADOS_2_RRB"
    sub_brain <- data_all %>%
      filter(Step == st, Network == net)
    
    for (cl in levels(data_all$Subtype)) {
      
      dat <- sub_brain %>%
        filter(Subtype == cl)
      
      ## ---------- Spearman ----------
      for (cog in names_cog_s) {
        
        temp <- dat[, c("z_score", cog, "Site")]
        temp <- temp[complete.cases(temp), ]
        if (nrow(temp) < 40) next
        
        # 控制站点
        if (length(unique(temp$Site)) > 1) {
          y_lm <- lm(temp[[cog]] ~ Site, data = temp)
          x_lm <- lm(temp$z_score ~ Site, data = temp)
        } else {
          y_lm <- lm(temp[[cog]] ~ 1, data = temp)
          x_lm <- lm(temp$z_score ~ 1, data = temp)
        }
        
        cor_test <- cor.test(residuals(x_lm),
                             residuals(y_lm),
                             method = "spearman")
        
        all_results[[length(all_results)+1]] <- data.frame(
          step = st,
          network = net,
          cluster = cl,
          name_cog = cog,
          coef = cor_test$estimate,
          p_value = cor_test$p.value,
          n = nrow(temp),
          df = df.residual(y_lm),
          method = "spearman"
        )
      }
      
      ## ---------- Pearson ----------
      for (cog in names_cog_p) {
        
        temp <- dat[, c("z_score", cog, "Site")]
        temp <- temp[complete.cases(temp), ]
        if (nrow(temp) < 40) next
        
        if (length(unique(temp$Site)) > 1) {
          y_lm <- lm(temp[[cog]] ~ Site, data = temp)
          x_lm <- lm(temp$z_score ~ Site, data = temp)
        } else {
          y_lm <- lm(temp[[cog]] ~ 1, data = temp)
          x_lm <- lm(temp$z_score ~ 1, data = temp)
        }
        
        cor_test <- cor.test(residuals(x_lm),
                             residuals(y_lm),
                             method = "pearson")
        
        all_results[[length(all_results)+1]] <- data.frame(
          step = st,
          network = net,
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
}

############################################################
# 合并结果 + FDR
############################################################

final_results <- bind_rows(all_results)

final_results <- final_results %>%
  group_by(cluster, step) %>%
  mutate(P_adj_subtype_step = p.adjust(p_value, method = "fdr")) %>%
  ungroup()

############################################################
# 保存完整结果
############################################################

write.csv(
  final_results,
  file.path(outDir, "z_score_correlation_LH.csv"),
  row.names = FALSE
)

############################################################
# 仅保留显著结果
############################################################

final_sig <- final_results %>%
  filter(p_value < 0.05) %>%
  arrange(p_value)

write.csv(
  final_sig,
  file.path(outDir, "z_score_correlation_LH_significant.csv"),
  row.names = FALSE
)

cat("z_score × Cognition correlation (GLOBAL FDR) finished.\n")

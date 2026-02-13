############################################################
# GAMLSS Normative Modeling
# Ultra-Stable + Safe Plot Version
# NO + BCCG
# Automatic AIC selection
# Sigma fallback
# Safe plotting
############################################################

rm(list = ls())

library(tidyverse)
library(readxl)
library(openxlsx)
library(gamlss)
library(gamlss.add)

#----------------------------------------------------------
# 0. 目录结构
#----------------------------------------------------------

root_dir <- "/Volumes/Zuolab_XRF/output/normative/gamlss"

dir.create(root_dir, showWarnings = FALSE)
dir.create(file.path(root_dir, "models"), showWarnings = FALSE)
dir.create(file.path(root_dir, "model_summaries"), showWarnings = FALSE)
dir.create(file.path(root_dir, "diagnostic_plots"), showWarnings = FALSE)
dir.create(file.path(root_dir, "diagnostic_plots/trajectories"), showWarnings = FALSE)
dir.create(file.path(root_dir, "diagnostic_plots/wormplots"), showWarnings = FALSE)
dir.create(file.path(root_dir, "logs"), showWarnings = FALSE)

#----------------------------------------------------------
# 1. 读取数据
#----------------------------------------------------------

data <- read_excel(
  "/Volumes/Zuolab_XRF/output/normative/SFEI_normative_data_combat.xlsx"
)

data <- data %>%
  mutate(
    Age = as.numeric(Age),
    Step = as.factor(Step),
    Network = as.factor(Network),
    SFEI_ComBat = as.numeric(SFEI_ComBat)
  )

td_data <- data %>%
  filter(Diagnosis == "TD",
         Site == "PEK")

#----------------------------------------------------------
# 2. 候选分布（精简且稳定）
#----------------------------------------------------------

candidate_families <- list(
  NO = NO,
  BCCG = BCCG
)

summary_table <- data.frame()
failure_log <- data.frame()

steps <- unique(td_data$Step)
networks <- unique(td_data$Network)

#----------------------------------------------------------
# 3. 主循环
#----------------------------------------------------------

for (s in steps) {
  for (n in networks) {
    
    cat("Fitting:", s, n, "\n")
    
    sub_data <- td_data %>%
      filter(Step == s,
             Network == n)
    
    if (nrow(sub_data) < 30) next
    
    best_aic <- Inf
    best_fit <- NULL
    best_family <- NA
    best_sigma_type <- NA
    
    dist_results <- data.frame()
    
    #------------------------------------------------------
    # 分布循环
    #------------------------------------------------------
    
    for (fam_name in names(candidate_families)) {
      
      fam <- candidate_families[[fam_name]]
      fit_try <- NULL
      sigma_type <- NA
      
      # ---- 尝试 sigma 平滑 ----
      fit_try <- tryCatch({
        gamlss(
          SFEI_ComBat ~ pb(Age),
          sigma.formula = ~ pb(Age),
          family = fam,
          data = sub_data,
          method = RS(),
          control = gamlss.control(n.cyc = 300, trace = FALSE)
        )
      }, error = function(e) NULL)
      
      sigma_type <- "pb(Age)"
      
      # ---- 若失败或未收敛 → fallback sigma=1 ----
      if (is.null(fit_try) || !fit_try$converged) {
        
        fit_try <- tryCatch({
          gamlss(
            SFEI_ComBat ~ pb(Age),
            sigma.formula = ~ 1,
            family = fam,
            data = sub_data,
            method = RS(),
            control = gamlss.control(n.cyc = 300, trace = FALSE)
          )
        }, error = function(e) NULL)
        
        sigma_type <- "constant"
      }
      
      # ---- 收敛检查 ----
      if (!is.null(fit_try) && fit_try$converged) {
        
        aic_val <- AIC(fit_try)
        bic_val <- BIC(fit_try)
        
        dist_results <- rbind(
          dist_results,
          data.frame(
            Distribution = fam_name,
            SigmaModel = sigma_type,
            AIC = aic_val,
            BIC = bic_val,
            Converged = TRUE
          )
        )
        
        if (aic_val < best_aic) {
          best_aic <- aic_val
          best_fit <- fit_try
          best_family <- fam_name
          best_sigma_type <- sigma_type
        }
        
      } else {
        
        dist_results <- rbind(
          dist_results,
          data.frame(
            Distribution = fam_name,
            SigmaModel = NA,
            AIC = NA,
            BIC = NA,
            Converged = FALSE
          )
        )
      }
    }
    
    #------------------------------------------------------
    # 若全部失败
    #------------------------------------------------------
    
    if (is.null(best_fit)) {
      
      failure_log <- rbind(
        failure_log,
        data.frame(Step = s, Network = n)
      )
      
      cat("All models failed:", s, n, "\n")
      next
    }
    
    model_name <- paste0("Step", s, "_", n)
    
    #------------------------------------------------------
    # 保存模型
    #------------------------------------------------------
    
    saveRDS(
      best_fit,
      file = file.path(root_dir, "models",
                       paste0(model_name, ".rds"))
    )
    
    #------------------------------------------------------
    # 保存分布比较
    #------------------------------------------------------
    
    write.csv(
      dist_results,
      file.path(root_dir,
                "model_summaries",
                paste0("DistComparison_", model_name, ".csv")),
      row.names = FALSE
    )
    
    #------------------------------------------------------
    # 汇总统计
    #------------------------------------------------------
    
    summary_table <- rbind(
      summary_table,
      data.frame(
        Step = s,
        Network = n,
        N = nrow(sub_data),
        BestFamily = best_family,
        SigmaModel = best_sigma_type,
        DF_total = best_fit$df.fit,
        AIC = AIC(best_fit),
        BIC = BIC(best_fit),
        GlobalDeviance = best_fit$G.deviance
      )
    )
    
    #------------------------------------------------------
    # 安全绘图
    #------------------------------------------------------
    
    if (best_fit$converged) {
      
      # ---- 轨迹图 ----
      try({
        pdf(file.path(root_dir,
                      "diagnostic_plots/trajectories",
                      paste0(model_name, "_trajectory.pdf")))
        plot(best_fit)
        dev.off()
      }, silent = TRUE)
      
      # ---- Worm plot ----
      try({
        pdf(file.path(root_dir,
                      "diagnostic_plots/wormplots",
                      paste0(model_name, "_wormplot.pdf")))
        wp(best_fit, ylim.all = 2)
        dev.off()
      }, silent = TRUE)
    }
  }
}

#----------------------------------------------------------
# 4. 保存总汇总与失败日志
#----------------------------------------------------------

write.csv(
  summary_table,
  file.path(root_dir,
            "model_summaries",
            "GAMLSS_model_summary_ultrastable.csv"),
  row.names = FALSE
)

write.xlsx(
  summary_table,
  file.path(root_dir,
            "model_summaries",
            "GAMLSS_model_summary_ultrastable.xlsx"),
  overwrite = TRUE
)

write.csv(
  failure_log,
  file.path(root_dir,
            "logs",
            "Model_Failures_ultrastable.csv"),
  row.names = FALSE
)

cat("Ultra-stable modeling completed successfully.\n")

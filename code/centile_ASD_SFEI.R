############################################################
# Compute ASD Centiles (Environment-safe version)
############################################################

rm(list = ls())

library(tidyverse)
library(readxl)
library(openxlsx)
library(gamlss)

############################################################
# Paths
############################################################

data_path  <- "/Volumes/Zuolab_XRF/output/normative/SFEI_normative_data_combat.xlsx"
model_dir  <- "/Volumes/Zuolab_XRF/output/normative/gamlss_step1to5/models"
output_dir <- "/Volumes/Zuolab_XRF/output/normative/gamlss_step1to5"

############################################################
# Load full dataset
############################################################

data_all <- read_excel(data_path)

data_all <- data_all %>%
  mutate(
    Age = as.numeric(Age),
    Step = as.numeric(as.character(Step)),
    Network = as.factor(Network),
    SFEI_ComBat = as.numeric(SFEI_ComBat)
  ) %>%
  filter(Step <= 5) %>%
  mutate(
    Step = as.factor(Step),
    SFEI_scaled = SFEI_ComBat * 1000
  )

############################################################
# Separate ASD and TD
############################################################

asd_data <- data_all %>%
  filter(Diagnosis == "ASD")

td_data <- data_all %>%
  filter(Diagnosis == "TD")

steps <- sort(unique(asd_data$Step))
networks <- sort(unique(asd_data$Network))

centile_results <- data.frame()

############################################################
# Main loop
############################################################

for (s in steps) {
  for (n in networks) {
    
    cat("Computing centile:", s, n, "\n")
    
    sub_asd <- asd_data %>%
      filter(Step == s,
             Network == n)
    
    if (nrow(sub_asd) == 0) next
    
    model_name <- paste0("Step", s, "_", n)
    model_file <- file.path(model_dir,
                            paste0(model_name, ".rds"))
    
    if (!file.exists(model_file)) next
    
    fit <- readRDS(model_file)
    
    ########################################################
    # 🔴 关键修复：重建 sub_data 供模型内部调用
    ########################################################
    
    sub_data <- td_data %>%
      filter(Step == s,
             Network == n)
    
    assign("sub_data", sub_data, envir = .GlobalEnv)
    
    ########################################################
    # Predict
    ########################################################
    
    pred <- predictAll(
      fit,
      newdata = sub_asd,
      type = "response"
    )
    
    mu_pred    <- pred$mu
    sigma_pred <- pred$sigma
    
    ########################################################
    # z-score
    ########################################################
    
    z_score <- (sub_asd$SFEI_scaled - mu_pred) / sigma_pred
    
    ########################################################
    # centile
    ########################################################
    
    centile <- pNO(
      q = sub_asd$SFEI_scaled,
      mu = mu_pred,
      sigma = sigma_pred
    )
    
    ########################################################
    # Store
    ########################################################
    
    tmp <- sub_asd %>%
      mutate(
        mu_pred = mu_pred,
        sigma_pred = sigma_pred,
        z_score = z_score,
        centile = centile
      )
    
    centile_results <- rbind(centile_results, tmp)
    
  }
}

############################################################
# Save
############################################################

write.xlsx(
  centile_results,
  file.path(output_dir, "ASD_centile_results.xlsx"),
  overwrite = TRUE
)

cat("ASD centile computation completed successfully.\n")

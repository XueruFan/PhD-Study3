# ============================================================
# ABIDE SFC embedding
# Pairwise contrasts vs TD
# 3-panel heatmap with raw-p significance
# Transparent background
# ============================================================

rm(list = ls())

# ----------------------------
# Libraries
# ----------------------------
library(tidyverse)
library(readxl)
library(emmeans)
library(showtext)

# ----------------------------
# Font (macOS, optional)
# ----------------------------
font_add(
  family = "pingfang",
  regular = "/System/Library/Fonts/PingFang.ttc"
)
showtext_auto()

# ----------------------------
# Paths
# ----------------------------
embedding_dir <- "/Volumes/Zuolab_XRF/data/abide/stats/SFC_Embedding"
demo_path     <- "/Volumes/Zuolab_XRF/supplement/abide_demo.xlsx"
site_dir      <- "/Volumes/Zuolab_XRF/data/abide/sublist"
cluster_path  <- "/Users/xuerufan/DCM-Project-PhD-Study3-/output/ABIDE/abide_cluster_predictions_male.csv"

out_dir <- "/Users/xuerufan/DCM-Project-PhD-Study3-/output/ABIDE"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

step_max <- 8
nNet     <- 15

# ----------------------------
# Network labels
# ----------------------------
network_map <- tibble(
  Network = c(
    "Net01","Net13","Net05",
    "Net08","Net04","Net06",
    "Net12","Net07","Net09",
    "Net02","Net11","Net10",
    "Net14","Net15","Net03"
  ),
  NetworkLabel = c(
    "VIS-P","VIS-C","AUD",
    "SMOT-A","SMOT-B","PM-PPr",
    "dATN-A","dATN-B","LANG",
    "CG-OP","FPN-A","FPN-B",
    "SAL/PMN","DN-A","DN-B"
  )
)

# ----------------------------
# Demographics
# ----------------------------
demo <- read_xlsx(demo_path) %>%
  transmute(
    Subject = as.character(Participant),
    AGE_AT_SCAN,
    SEX = factor(SEX, levels = c(1,2), labels = c("Male","Female"))
  )

# ----------------------------
# Subtype labels
# ----------------------------
cluster <- read_csv(cluster_path, show_col_types = FALSE) %>%
  transmute(
    Subject = as.character(participant),
    Group = factor(
      subtype,
      levels = c(0,1,2),
      labels = c("TD","L","H")
    )
  )

# ----------------------------
# 4. Build subject → site mapping
# ----------------------------
site_map <- list.files(
  site_dir,
  pattern = "^subjects_.*\\.list$",
  full.names = TRUE
) %>%
  map_dfr(function(f) {
    
    site <- basename(f) %>%
      str_remove("^subjects_") %>%
      str_remove("\\.list$") %>%
      toupper()
    
    subjects <- read_lines(f) %>%
      as.character() %>%
      as.integer() %>%
      as.character()
    
    tibble(
      Subject = subjects,
      site    = site
    )
  })

## ----------------------------
# 5. Read & merge embedding (all steps)
# ----------------------------
read_one_step <- function(step) {
  
  fname <- sprintf("step%02d.xlsx", step)
  fpath <- file.path(embedding_dir, fname)
  
  df <- read_excel(fpath)
  
  df %>%
    pivot_longer(
      cols = starts_with("Net"),
      names_to  = "Network",
      values_to = "Embedding"
    ) %>%
    mutate(
      Step    = step,
      Subject = as.character(as.integer(Subject)),
      Network = factor(Network, levels = sprintf("Net%02d", 1:nNet))
    )
}

embedding_long <- map_dfr(1:step_max, read_one_step)

# ----------------------------
# Merge all
# ----------------------------
data_all <- embedding_long %>%
  left_join(demo, by = "Subject") %>%
  left_join(cluster, by = "Subject") %>%
  left_join(site_map, by = "Subject") %>%
  filter(
    SEX == "Male",
    !is.na(Group),
    !is.na(site)
  ) %>%
  mutate(
    Group = relevel(Group, ref = "TD"),
    Embedding = as.numeric(Embedding)
  )

# ============================================================
# Construct merged ASD group
# ============================================================
data_all <- data_all %>%
  mutate(
    Group_ASD = case_when(
      Group == "TD"                 ~ "TD",
      Group %in% c("L","H") ~ "ASD"
    ),
    Group_ASD = factor(Group_ASD, levels = c("TD","ASD"))
  )

# ============================================================
# Pairwise contrast model functions
# ============================================================

library(emmeans)

fit_asd_vs_td <- function(df) {
  m <- lm(
    Embedding ~ Group_ASD + AGE_AT_SCAN + site,
    data = df
  )
  em <- emmeans(m, ~ Group_ASD)
  as.data.frame(
    contrast(em, "trt.vs.ctrl", ref = "TD")
  ) %>%
    mutate(Contrast = "ASD vs TD")
}

fit_subtype_vs_td <- function(df) {
  m <- lm(
    Embedding ~ Group + AGE_AT_SCAN + site,
    data = df
  )
  em <- emmeans(m, ~ Group)
  as.data.frame(
    contrast(em, "trt.vs.ctrl", ref = "TD")
  ) %>%
    filter(contrast %in% c("L - TD", "H - TD")) %>%
    mutate(
      Contrast = recode(
        contrast,
        "L - TD" = "L vs TD",
        "H - TD" = "H vs TD"
      )
    )
}

# ============================================================
# Run contrasts for all Network × Step
# ============================================================

stats <- bind_rows(
  
  data_all %>%
    group_by(Network, Step) %>%
    group_modify(~ fit_asd_vs_td(.x)),
  
  data_all %>%
    group_by(Network, Step) %>%
    group_modify(~ fit_subtype_vs_td(.x))
  
) %>%
  ungroup() %>%
  mutate(
    sig_raw = p.value < 0.05,
    Contrast = factor(
      Contrast,
      levels = c("ASD vs TD", "L vs TD", "H vs TD")
    )
  )

write_csv(stats, file.path(out_dir, "sfc_group_constrast.csv"))

# ============================================================
# Prepare data for plotting
# ============================================================

plot_data <- stats %>%
  left_join(network_map, by = "Network") %>%
  filter(!is.na(NetworkLabel)) %>%
  mutate(
    Step = factor(Step),
    NetworkLabel = factor(
      NetworkLabel,
      levels = network_map$NetworkLabel
    )
  )

# ============================================================
# Plot: 3-panel heatmap with raw-p significance
# ============================================================

p <- ggplot(
  plot_data,
  aes(
    x = Step,
    y = NetworkLabel,
    fill = estimate
  )
) +
  geom_tile(
    color = "white",
    linewidth = 0.4
  ) +
  geom_point(
    data = subset(plot_data, sig_raw),
    shape  = 21,
    size   = 2.6,
    stroke = 1,
    fill   = NA,
    color  = "black"
  ) +
  facet_wrap(
    ~ Contrast,
    nrow = 1
  ) +
  scale_fill_gradient2(
    low  = "#3B4CC0",
    mid  = "white",
    high = "#B40426",
    name = expression(Delta~Embedding)
  ) +
  theme_void(base_size = 18) +
  theme(
    strip.text   = element_text(size = 18, face = "bold"),
    axis.text.x  = element_text(size = 12),
    axis.text.y  = element_text(size = 14),
    legend.position = "right"
  )

# ============================================================
# Save figure (transparent background)
# ============================================================

ggsave(
  filename = file.path(out_dir, "plot/SFC_ABIDE_subtypes_contrasts.png"),
  plot     = p,
  width    = 3600,
  height   = 2000,
  dpi      = 300,
  units    = "px",
  bg       = "transparent"
)

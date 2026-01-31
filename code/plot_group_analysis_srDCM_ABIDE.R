# ============================================================
# Figure 2: Sparsity rDCM
# Forest plot of ALL significant connections (uncorrected p < 0.05)
# Ordered by source system -> target system -> effect size
# FINAL FULL SCRIPT
# ============================================================

rm(list = ls())

# ----------------------------
# 0. Libraries
# ----------------------------
library(tidyverse)
library(readr)
library(ggplot2)
library(stringr)

# ----------------------------
# 1. Paths
# ----------------------------
in_csv  <- "/Volumes/Zuolab_XRF/data/abide/stats/ABIDE_srDCM_logistic.csv"
out_png <- "/Volumes/Zuolab_XRF/data/abide/figures/ABIDE_srDCM_logistic.png"

# ----------------------------
# 2. Network lookup table (DU15)
# ----------------------------
net_lut <- tibble(
  index = sprintf("%02d", 1:15),
  abbr = c(
    "VIS-P",     # 01
    "CG-OP",     # 02
    "DN-B",      # 03
    "SMOT-B",    # 04
    "AUD",       # 05
    "PM-PPr",    # 06
    "dATN-B",    # 07
    "SMOT-A",    # 08
    "LANG",      # 09
    "FPN-B",     # 10
    "FPN-A",     # 11
    "dATN-A",    # 12
    "VIS-C",     # 13
    "SAL/PMN",   # 14
    "DN-A"       # 15
  )
)

# ----------------------------
# 3. Functional system definition
# ----------------------------
system_lut <- tribble(
  ~network,   ~system,
  "VIS-P",    "Visual",
  "VIS-C",    "Visual",
  
  "AUD",      "Sensorimotor",
  "SMOT-A",   "Sensorimotor",
  "SMOT-B",   "Sensorimotor",
  
  "dATN-A",   "Attention/Control",
  "dATN-B",   "Attention/Control",
  "FPN-A",    "Attention/Control",
  "FPN-B",    "Attention/Control",
  "CG-OP",    "Attention/Control",
  "SAL/PMN",  "Attention/Control",
  
  "DN-A",     "Default",
  "DN-B",     "Default",
  
  "PM-PPr",   "Other",
  "LANG",     "Other"
)

# Explicit system order (NOT alphabetical)
system_order <- c(
  "Visual",
  "Sensorimotor",
  "Attention/Control",
  "Default",
  "Other"
)

# ----------------------------
# 4. Read logistic regression results
# ----------------------------
df <- read_csv(in_csv, show_col_types = FALSE)

# Expected columns:
# connection | estimate | std.error | statistic | p.value | p_fdr

# ----------------------------
# 5. Compute OR and confidence intervals
# ----------------------------
df2 <- df %>%
  mutate(
    OR       = exp(estimate),
    CI_low  = exp(estimate - 1.96 * std.error),
    CI_high = exp(estimate + 1.96 * std.error),
    abs_eff = abs(estimate)
  )

# ----------------------------
# 6. Keep ALL uncorrected significant connections
# ----------------------------
df_plot <- df2 %>%
  filter(p.value < 0.05)

# ----------------------------
# 7. Parse source / target indices
# Format: EC_03_to_13
# ----------------------------
df_plot <- df_plot %>%
  mutate(
    source = str_match(connection, "EC_(\\d+)_to_(\\d+)")[, 2],
    target = str_match(connection, "EC_(\\d+)_to_(\\d+)")[, 3]
  )

# ----------------------------
# 8. Map indices to network abbreviations
# ----------------------------
df_plot <- df_plot %>%
  left_join(net_lut, by = c("source" = "index")) %>%
  rename(source_net = abbr) %>%
  left_join(net_lut, by = c("target" = "index")) %>%
  rename(target_net = abbr)

# ----------------------------
# 9. Add functional system labels (source + target)
# ----------------------------
df_plot <- df_plot %>%
  left_join(system_lut, by = c("source_net" = "network")) %>%
  rename(source_system = system) %>%
  left_join(system_lut, by = c("target_net" = "network")) %>%
  rename(target_system = system)

# Enforce system ordering
df_plot <- df_plot %>%
  mutate(
    source_system = factor(source_system, levels = system_order),
    target_system = factor(target_system, levels = system_order)
  )

# ----------------------------
# 10. Create labels and ordering
# ----------------------------
df_plot <- df_plot %>%
  mutate(
    label = paste0(source_net, " \u2192 ", target_net)
  ) %>%
  arrange(
    source_system,
    target_system,
    desc(abs_eff)
  ) %>%
  mutate(
    label = factor(label, levels = rev(unique(label)))
  )

# ----------------------------
# 11. Forest plot
# ----------------------------
p <- ggplot(df_plot, aes(x = OR, y = label)) +
  
  geom_vline(
    xintercept = 1,
    linetype = "dashed",
    color = "grey40"
  ) +
  
  geom_errorbarh(
    aes(xmin = CI_low, xmax = CI_high),
    height = 0.2,
    linewidth = 0.6
  ) +
  
  geom_point(
    size = 2.6,
    shape = 21,
    fill = "white",
    color = "black"
  ) +
  
  scale_x_log10(
    breaks = c(0.25, 0.5, 1, 2, 4),
    labels = c("0.25", "0.5", "1", "2", "4")
  ) +
  
  labs(
    title = "稀疏性rDCM：显著网络连接存在性的组别差异",
    subtitle = "按源网络系统 → 目标网络系统排序（未校正 p < 0.05，仅用于可视化）",
    x = "比值比（Odds Ratio，ASD / 对照组）",
    y = "网络连接（源 → 目标）"
  ) +
  
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    plot.title         = element_text(face = "bold", hjust = 0.5),
    plot.subtitle      = element_text(hjust = 0.5)
  )

# ----------------------------
# 12. Save figure
# ----------------------------
ggsave(
  filename = out_png,
  plot = p,
  width = 9.5,
  height = 7,
  dpi = 600
)

cat("Figure 2 saved to:\n", out_png, "\n")

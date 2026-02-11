# ============================================================
# FINAL PIPELINE
# Re-draw ALL network-level zSFC chord diagrams
# - One edge per network pair (upper triangle)
# - Correct network semantics
# - Consistent label size (similar to original example)
# ============================================================

rm(list = ls())
library(circlize)

# ------------------------------------------------------------
# 1. TRUE matrix order (atlas index 1–15, excluding NONE)
#    !!! DO NOT CHANGE !!!
# ------------------------------------------------------------
MatrixOrder <- c(
  "VIS-P","CG-OP","DN-B","SMOT-B","AUD",
  "PM-PPr","dATN-B","SMOT-A","LANG",
  "FPN-B","FPN-A","dATN-A","VIS-C","SAL/PMN","DN-A"
)

# ------------------------------------------------------------
# 2. Display order (paper logic)
#    CG-OP is DISPLAYED as AN
# ------------------------------------------------------------
NetworkLabel <- c(
  "VIS-C","VIS-P","SMOT-B","SMOT-A","AUD",
  "AN","dATN-B","dATN-A","PM-PPr","SAL/PMN",
  "FPN-B","FPN-A","DN-B","DN-A","LANG"
)

# ------------------------------------------------------------
# 3. Network colors
# ------------------------------------------------------------
net_colors <- c(
  "VIS-P"   = rgb(170,  70, 125, maxColorValue = 255),
  "AN"      = rgb(184,  89, 251, maxColorValue = 255),
  "DN-B"    = rgb(205,  61,  77, maxColorValue = 255),
  "SMOT-B"  = rgb( 27, 179, 242, maxColorValue = 255),
  "AUD"     = rgb(231, 215, 165, maxColorValue = 255),
  "PM-PPr"  = rgb( 66, 231, 206, maxColorValue = 255),
  "dATN-B"  = rgb( 98, 206,  61, maxColorValue = 255),
  "SMOT-A"  = rgb( 73, 145, 175, maxColorValue = 255),
  "LANG"    = rgb( 11,  47, 255, maxColorValue = 255),
  "FPN-B"   = rgb(228, 228,   0, maxColorValue = 255),
  "FPN-A"   = rgb(240, 147,  33, maxColorValue = 255),
  "dATN-A"  = rgb( 10, 112,  33, maxColorValue = 255),
  "VIS-C"   = rgb(119,  17, 133, maxColorValue = 255),
  "SAL/PMN" = rgb(254, 188, 235, maxColorValue = 255),
  "DN-A"    = rgb(100,  49,  73, maxColorValue = 255)
)


# ------------------------------------------------------------
# 4. Paths
# ------------------------------------------------------------
in_dir  <- "/Volumes/Zuolab_XRF/output/abide/sfc/stat/meanzSFC"
out_dir <- "/Volumes/Zuolab_XRF/output/abide/sfc/plot/meanzSFC"

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------
# 5. Scan input files
# ------------------------------------------------------------
files <- list.files(
  in_dir,
  pattern = "^zSFC_mean_.*_step[0-9]+\\.csv$",
  full.names = TRUE
)

cat("Found", length(files), "matrices\n")

# ------------------------------------------------------------
# 6. Main loop
# ------------------------------------------------------------
for (f in files) {
  
  fname <- basename(f)
  info <- regmatches(
    fname,
    regexec("zSFC_mean_(.*)_step([0-9]+)\\.csv", fname)
  )[[1]]
  
  subtype <- info[2]
  step    <- paste0("step", info[3])
  
  cat("Plotting:", subtype, step, "\n")
  
  # ---- Load matrix ----
  zmat <- as.matrix(read.csv(f, header = FALSE))
  
  stopifnot(
    nrow(zmat) == length(MatrixOrder),
    ncol(zmat) == length(MatrixOrder)
  )
  
  rownames(zmat) <- MatrixOrder
  colnames(zmat) <- MatrixOrder
  
  # ---- Rename CG-OP -> AN (label only) ----
  rownames(zmat)[rownames(zmat) == "CG-OP"] <- "AN"
  colnames(zmat)[colnames(zmat) == "CG-OP"] <- "AN"
  
  # ---- Build EDGE LIST (UPPER TRIANGLE ONLY) ----
  idx <- upper.tri(zmat, diag = FALSE)
  
  df <- data.frame(
    from  = rownames(zmat)[row(zmat)[idx]],
    to    = colnames(zmat)[col(zmat)[idx]],
    value = zmat[idx],
    stringsAsFactors = FALSE
  )
  
  df <- df[!is.na(df$value) & df$value != 0, ]
  
  if (nrow(df) == 0) next
  
  # enforce sector order
  df$from <- factor(df$from, levels = NetworkLabel)
  df$to   <- factor(df$to,   levels = NetworkLabel)
  
  # ---- Output ----
  out_file <- file.path(
    out_dir,
    paste0("zSFC_chord_", subtype, "_", step, ".png")
  )
  
  png(out_file, width = 2400, height = 2400, res = 300)
  
  circos.clear()
  circos.par(
    start.degree = 90,
    gap.after = setNames(rep(2, length(NetworkLabel)), NetworkLabel)
  )
  
  chordDiagram(
    df,
    order = NetworkLabel,
    grid.col = net_colors,
    col = net_colors,
    transparency = 0.45,
    directional = FALSE,
    annotationTrack = c("name", "grid"),
    annotationTrackHeight = c(0.04, 0.02)
  )
  
  circos.clear()
  dev.off()
}

cat("All chord diagrams re-drawn successfully.\n")

# run_all.R
# Run the complete analysis from raw STATS19 files.
#
# Requirements:
#   - final 2024 and 2025 collision, vehicle, and casualty CSV files
#     placed in data/raw/
#   - required R packages installed (see R/00_setup.R)
#
# Model fitting, SHAP, and bootstrap steps may take substantial time.

scripts <- c(
  "00_setup.R",
  "01_data_import.R",
  "02_data_linkage_cleaning.R",
  "03_descriptive_analysis.R",
  "04_model_development.R",
  "05_temporal_validation.R",
  "06_subgroup_analysis.R",
  "07_shap_analysis.R",
  "08_bootstrap_uncertainty.R",
  "09_final_tables_figures.R"
)

for (script in scripts) {
  message("\n========== Running ", script, " ==========")
  source(file.path("R", script))
}

message("\nFull STATS19 analysis completed.")

# 09_final_tables_figures.R
# Assemble publication tables, study-design figure, performance figure,
# numerical audit, and session information.

source(file.path("R", "00_setup.R"))

model24 <- readRDS(
  file.path(data_derived_dir, "model24.rds")
)

model25 <- readRDS(
  file.path(data_derived_dir, "model25.rds")
)

collision25_plot <- readRDS(
  file.path(data_derived_dir, "collision25_plot.rds")
)

temporal_results <- readRDS(
  file.path(data_derived_dir, "temporal_validation_results.rds")
)

bootstrap_results <- readRDS(
  file.path(data_derived_dir, "Collision_Bootstrap_2025.rds")
)

cv_performance <- read.csv(
  file.path(table_dir, "Grouped_CV_Performance_2024.csv"),
  stringsAsFactors = FALSE
)

test_performance <- temporal_results$test_performance
calibration_summary <- temporal_results$calibration_summary
threshold_selection <- temporal_results$threshold_selection
threshold_metrics_2025 <- temporal_results$threshold_metrics_2025

# ---- Bootstrap intervals for individual model metrics -----------------------

metric_ci <- function(x) {
  tibble::tibble(
    Bootstrap_Mean = mean(x),
    Lower_95 = quantile(
      x,
      0.025,
      names = FALSE
    ),
    Upper_95 = quantile(
      x,
      0.975,
      names = FALSE
    )
  )
}

performance_ci <- dplyr::bind_rows(
  metric_ci(
    bootstrap_results$Logistic_ROC
  ) %>%
    dplyr::mutate(
      Model = "Logistic regression",
      Metric = "ROC-AUC"
    ),

  metric_ci(
    bootstrap_results$RF_ROC
  ) %>%
    dplyr::mutate(
      Model = "Random Forest",
      Metric = "ROC-AUC"
    ),

  metric_ci(
    bootstrap_results$XGB_ROC
  ) %>%
    dplyr::mutate(
      Model = "XGBoost",
      Metric = "ROC-AUC"
    ),

  metric_ci(
    bootstrap_results$Logistic_PR
  ) %>%
    dplyr::mutate(
      Model = "Logistic regression",
      Metric = "PR-AUC"
    ),

  metric_ci(
    bootstrap_results$RF_PR
  ) %>%
    dplyr::mutate(
      Model = "Random Forest",
      Metric = "PR-AUC"
    ),

  metric_ci(
    bootstrap_results$XGB_PR
  ) %>%
    dplyr::mutate(
      Model = "XGBoost",
      Metric = "PR-AUC"
    ),

  metric_ci(
    bootstrap_results$Logistic_Brier
  ) %>%
    dplyr::mutate(
      Model = "Logistic regression",
      Metric = "Brier score"
    ),

  metric_ci(
    bootstrap_results$RF_Brier
  ) %>%
    dplyr::mutate(
      Model = "Random Forest",
      Metric = "Brier score"
    ),

  metric_ci(
    bootstrap_results$XGB_Brier
  ) %>%
    dplyr::mutate(
      Model = "XGBoost",
      Metric = "Brier score"
    )
) %>%
  dplyr::mutate(
    Model = factor(
      Model,
      levels = c(
        "Logistic regression",
        "Random Forest",
        "XGBoost"
      )
    )
  )

print(
  performance_ci,
  n = Inf
)

# ---- Final model-performance table -----------------------------------------

roc_ci <- performance_ci %>%
  dplyr::filter(Metric == "ROC-AUC") %>%
  dplyr::select(
    Model,
    ROC_Lower_95 = Lower_95,
    ROC_Upper_95 = Upper_95
  )

pr_ci <- performance_ci %>%
  dplyr::filter(Metric == "PR-AUC") %>%
  dplyr::select(
    Model,
    PR_Lower_95 = Lower_95,
    PR_Upper_95 = Upper_95
  )

brier_ci <- performance_ci %>%
  dplyr::filter(Metric == "Brier score") %>%
  dplyr::select(
    Model,
    Brier_Lower_95 = Lower_95,
    Brier_Upper_95 = Upper_95
  )

final_model_table <- test_performance %>%
  dplyr::select(
    Model,
    Test_ROC_2025 = ROC_AUC,
    Test_PR_AUC_2025 = PR_AUC,
    Brier_2025 = Brier
  ) %>%
  dplyr::left_join(
    cv_performance %>%
      dplyr::select(
        Model,
        CV_ROC_2024 = ROC
      ),
    by = "Model"
  ) %>%
  dplyr::left_join(
    roc_ci,
    by = "Model"
  ) %>%
  dplyr::left_join(
    pr_ci,
    by = "Model"
  ) %>%
  dplyr::left_join(
    brier_ci,
    by = "Model"
  ) %>%
  dplyr::select(
    Model,
    CV_ROC_2024,
    Test_ROC_2025,
    ROC_Lower_95,
    ROC_Upper_95,
    Test_PR_AUC_2025,
    PR_Lower_95,
    PR_Upper_95,
    Brier_2025,
    Brier_Lower_95,
    Brier_Upper_95
  )

print(final_model_table)

write.csv(
  final_model_table,
  file.path(table_dir, "Final_Model_Performance.csv"),
  row.names = FALSE
)

write.csv(
  performance_ci,
  file.path(table_dir, "Model_Performance_Bootstrap_CI.csv"),
  row.names = FALSE
)

# ---- Figure 1: study design -------------------------------------------------

ksi24_pct <- 100 * mean(model24$KSI_num)
ksi25_pct <- 100 * mean(model25$KSI_num)

boxes <- tibble::tribble(
  ~xmin, ~xmax, ~ymin, ~ymax, ~label,

  0.5, 3.5, 8.2, 9.4,
  paste0(
    "2024 STATS19\n",
    "100,927 collisions\n",
    "183,514 vehicles\n",
    scales::comma(nrow(model24)),
    " casualties"
  ),

  6.5, 9.5, 8.2, 9.4,
  paste0(
    "2025 STATS19\n",
    "101,525 collisions\n",
    "183,948 vehicles\n",
    scales::comma(nrow(model25)),
    " casualties"
  ),

  0.5, 3.5, 6.1, 7.3,
  "Casualty-level linkage\nCollision + vehicle + casualty records\n0 unmatched casualties",

  6.5, 9.5, 6.1, 7.3,
  paste0(
    "Untouched temporal test set\n",
    scales::comma(nrow(model25)),
    " casualties\n",
    sprintf("%.2f%% recorded KSI", ksi25_pct)
  ),

  0.5, 3.5, 4.0, 5.2,
  paste0(
    "2024 development sample\n18 primary predictors\n",
    sprintf("%.2f%% recorded KSI", ksi24_pct)
  ),

  0.5, 3.5, 1.9, 3.1,
  "5-fold grouped cross-validation\nGrouped by collision_index\n0 collision overlap",

  4.0, 6.0, 1.9, 3.1,
  "Models\nLogistic regression\nRandom Forest\nXGBoost",

  6.5, 9.5, 1.9, 3.1,
  "2025 evaluation\nROC-AUC · PR-AUC · Brier\nCalibration · threshold transfer",

  6.5, 9.5, 0.1, 1.2,
  "Interpretation and robustness\nSubgroups · grouped SHAP\nCollision-level bootstrap"
)

figure1 <- ggplot() +
  geom_rect(
    data = boxes,
    aes(
      xmin = xmin,
      xmax = xmax,
      ymin = ymin,
      ymax = ymax
    ),
    fill = "white",
    linewidth = 0.7
  ) +
  geom_text(
    data = boxes,
    aes(
      x = (xmin + xmax) / 2,
      y = (ymin + ymax) / 2,
      label = label
    ),
    size = 3.5,
    lineheight = 1.05
  ) +
  geom_segment(
    aes(x = 2, y = 8.2, xend = 2, yend = 7.3),
    arrow = grid::arrow(length = grid::unit(0.16, "cm"))
  ) +
  geom_segment(
    aes(x = 2, y = 6.1, xend = 2, yend = 5.2),
    arrow = grid::arrow(length = grid::unit(0.16, "cm"))
  ) +
  geom_segment(
    aes(x = 2, y = 4.0, xend = 2, yend = 3.1),
    arrow = grid::arrow(length = grid::unit(0.16, "cm"))
  ) +
  geom_segment(
    aes(x = 3.5, y = 2.5, xend = 4.0, yend = 2.5),
    arrow = grid::arrow(length = grid::unit(0.16, "cm"))
  ) +
  geom_segment(
    aes(x = 6.0, y = 2.5, xend = 6.5, yend = 2.5),
    arrow = grid::arrow(length = grid::unit(0.16, "cm"))
  ) +
  geom_segment(
    aes(x = 8, y = 8.2, xend = 8, yend = 7.3),
    arrow = grid::arrow(length = grid::unit(0.16, "cm"))
  ) +
  geom_segment(
    aes(x = 8, y = 6.1, xend = 8, yend = 3.1),
    arrow = grid::arrow(length = grid::unit(0.16, "cm"))
  ) +
  geom_segment(
    aes(x = 8, y = 1.9, xend = 8, yend = 1.2),
    arrow = grid::arrow(length = grid::unit(0.16, "cm"))
  ) +
  annotate(
    "text",
    x = 5,
    y = 9.9,
    label = "Study Design and Temporal Validation Framework",
    fontface = "bold",
    size = 5
  ) +
  coord_cartesian(
    xlim = c(0, 10),
    ylim = c(0, 10)
  ) +
  theme_void()

ggsave(
  file.path(figure_dir, "Figure_1_Study_Design.png"),
  figure1,
  width = 11,
  height = 8,
  dpi = 400
)

# ---- Figure 6: temporal-test performance with bootstrap uncertainty ---------

figure6 <- ggplot2::ggplot(
  performance_ci,
  ggplot2::aes(
    x = Bootstrap_Mean,
    y = Model
  )
) +
  ggplot2::geom_errorbar(
    ggplot2::aes(
      xmin = Lower_95,
      xmax = Upper_95
    ),
    orientation = "y",
    width = 0.15
  ) +
  ggplot2::geom_point(size = 3) +
  ggplot2::facet_wrap(
    ~ Metric,
    scales = "free_x",
    nrow = 1
  ) +
  ggplot2::labs(
    title = "Predictive Performance on the 2025 Temporal Test Set",
    subtitle = "Points show bootstrap mean estimates; bars show 95% collision-level bootstrap intervals",
    x = NULL,
    y = NULL,
    caption = paste(
      "Higher ROC-AUC and PR-AUC indicate better discrimination;",
      "lower Brier scores indicate better probability accuracy."
    )
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    strip.text = ggplot2::element_text(face = "bold"),
    plot.title = ggplot2::element_text(face = "bold"),
    panel.grid.minor = ggplot2::element_blank()
  )

ggplot2::ggsave(
  file.path(figure_dir, "Figure_6_Model_Performance_2025.png"),
  figure6,
  width = 11,
  height = 5.5,
  dpi = 400
)

# ---- Numerical manuscript audit --------------------------------------------

xgb_cv_roc <- cv_performance %>%
  dplyr::filter(Model == "XGBoost") %>%
  dplyr::pull(ROC)

xgb_test <- test_performance %>%
  dplyr::filter(Model == "XGBoost")

xgb_calibration <- calibration_summary %>%
  dplyr::filter(Model == "XGBoost")

manuscript_audit <- tibble::tibble(
  Quantity = c(
    "2024 casualties",
    "2025 casualties",
    "2024 recorded KSI",
    "2025 recorded KSI",
    "2024 recorded KSI prevalence",
    "2025 recorded KSI prevalence",
    "2025 collisions",
    "2025 KSI collisions",
    "2025 KSI-collision percentage",
    "XGBoost 2024 grouped CV ROC",
    "XGBoost 2025 ROC",
    "XGBoost 2025 PR-AUC",
    "XGBoost 2025 Brier",
    "XGBoost calibration intercept",
    "XGBoost calibration slope",
    "Locked threshold",
    "2025 threshold sensitivity",
    "2025 threshold specificity",
    "2025 threshold precision",
    "2025 threshold NPV",
    "2025 balanced accuracy"
  ),

  Value = c(
    nrow(model24),
    nrow(model25),
    sum(model24$KSI_num),
    sum(model25$KSI_num),
    mean(model24$KSI_num),
    mean(model25$KSI_num),
    nrow(collision25_plot),
    sum(collision25_plot$KSI_Collision),
    100 * mean(collision25_plot$KSI_Collision),
    xgb_cv_roc,
    xgb_test$ROC_AUC,
    xgb_test$PR_AUC,
    xgb_test$Brier,
    xgb_calibration$Calibration_Intercept,
    xgb_calibration$Calibration_Slope,
    threshold_selection$threshold[[1]],
    threshold_metrics_2025$Sensitivity,
    threshold_metrics_2025$Specificity,
    threshold_metrics_2025$Precision,
    threshold_metrics_2025$NPV,
    threshold_metrics_2025$Balanced_Accuracy
  )
)

print(
  manuscript_audit,
  n = Inf
)

write.csv(
  manuscript_audit,
  file.path(table_dir, "Manuscript_Numerical_Audit.csv"),
  row.names = FALSE
)

# ---- Session information ----------------------------------------------------

session_output <- capture.output(
  sessionInfo()
)

writeLines(
  session_output,
  file.path(session_dir, "sessionInfo.txt")
)

message("Final tables, figures, audit, and session information complete.")

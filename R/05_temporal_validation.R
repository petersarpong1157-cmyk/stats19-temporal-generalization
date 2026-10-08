# 05_temporal_validation.R
# Evaluate the 2024-developed models on the untouched 2025 temporal test set.

source(file.path("R", "00_setup.R"))

model24 <- readRDS(
  file.path(data_derived_dir, "model24.rds")
)

model25 <- readRDS(
  file.path(data_derived_dir, "model25.rds")
)

predictor_definitions <- readRDS(
  file.path(data_derived_dir, "predictor_definitions.rds")
)

primary_predictors <- predictor_definitions$primary_predictors

logit_fit <- readRDS(
  file.path(model_dir, "Final_Logistic_Model_2024.rds")
)

rf_fit <- readRDS(
  file.path(model_dir, "Final_RandomForest_Model_2024.rds")
)

xgb_fit <- readRDS(
  file.path(model_dir, "Final_XGBoost_Model_2024.rds")
)

test25 <- model25 %>%
  dplyr::select(
    KSI,
    dplyr::all_of(primary_predictors)
  )

# ---- Temporal test probabilities -------------------------------------------

logit_prob_2025 <- predict(
  logit_fit,
  newdata = test25,
  type = "prob"
)[, "KSI"]

rf_prob_2025 <- predict(
  rf_fit,
  newdata = test25,
  type = "prob"
)[, "KSI"]

xgb_prob_2025 <- predict(
  xgb_fit,
  newdata = test25,
  type = "prob"
)[, "KSI"]

y25 <- model25$KSI_num

model_metrics <- function(model_name, y, p) {
  tibble::tibble(
    Model = model_name,
    N = length(y),
    KSI_Prevalence = mean(y),
    ROC_AUC = safe_roc_auc(y, p),
    PR_AUC = safe_pr_auc(y, p),
    Brier = mean((p - y)^2)
  )
}

test_performance <- dplyr::bind_rows(
  model_metrics(
    "Logistic regression",
    y25,
    logit_prob_2025
  ),
  model_metrics(
    "Random Forest",
    y25,
    rf_prob_2025
  ),
  model_metrics(
    "XGBoost",
    y25,
    xgb_prob_2025
  )
)

print(test_performance)

# ---- Calibration ------------------------------------------------------------

calibration_parameters <- function(model_name, y, p) {
  p_clip <- pmin(
    pmax(p, 1e-6),
    1 - 1e-6
  )

  lp <- qlogis(p_clip)

  intercept_fit <- stats::glm(
    y ~ offset(lp),
    family = stats::binomial()
  )

  slope_fit <- stats::glm(
    y ~ lp,
    family = stats::binomial()
  )

  tibble::tibble(
    Model = model_name,
    Calibration_Intercept =
      unname(stats::coef(intercept_fit)[1]),
    Calibration_Slope =
      unname(stats::coef(slope_fit)["lp"])
  )
}

calibration_summary <- dplyr::bind_rows(
  calibration_parameters(
    "Logistic regression",
    y25,
    logit_prob_2025
  ),
  calibration_parameters(
    "Random Forest",
    y25,
    rf_prob_2025
  ),
  calibration_parameters(
    "XGBoost",
    y25,
    xgb_prob_2025
  )
)

print(calibration_summary)

calibration_deciles <- dplyr::bind_rows(
  tibble::tibble(
    Model = "Logistic regression",
    y = y25,
    p = logit_prob_2025
  ),
  tibble::tibble(
    Model = "Random Forest",
    y = y25,
    p = rf_prob_2025
  ),
  tibble::tibble(
    Model = "XGBoost",
    y = y25,
    p = xgb_prob_2025
  )
) %>%
  dplyr::group_by(Model) %>%
  dplyr::mutate(Bin = dplyr::ntile(p, 10)) %>%
  dplyr::group_by(Model, Bin) %>%
  dplyr::summarise(
    N = dplyr::n(),
    Mean_Predicted = mean(p),
    Observed_KSI = mean(y),
    .groups = "drop"
  )

calibration_plot <- ggplot2::ggplot(
  calibration_deciles,
  ggplot2::aes(
    x = Mean_Predicted,
    y = Observed_KSI,
    group = Model
  )
) +
  ggplot2::geom_abline(
    slope = 1,
    intercept = 0,
    linetype = "dashed"
  ) +
  ggplot2::geom_line() +
  ggplot2::geom_point() +
  ggplot2::facet_wrap(~ Model) +
  ggplot2::coord_equal() +
  ggplot2::labs(
    title = "Calibration on the 2025 Temporal Test Set",
    x = "Mean predicted KSI probability",
    y = "Observed KSI proportion"
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold"),
    panel.grid.minor = ggplot2::element_blank()
  )

ggplot2::ggsave(
  file.path(figure_dir, "Figure_Calibration_2025.png"),
  calibration_plot,
  width = 10,
  height = 4.5,
  dpi = 400
)

# ---- Threshold selected only from 2024 out-of-fold predictions -------------

xgb_oof <- xgb_fit$pred %>%
  tibble::as_tibble() %>%
  dplyr::arrange(rowIndex)

if (nrow(xgb_oof) != nrow(model24) ||
    anyDuplicated(xgb_oof$rowIndex)) {
  stop(
    "XGBoost out-of-fold predictions do not provide exactly one prediction per 2024 row."
  )
}

oof_roc <- pROC::roc(
  response = xgb_oof$obs,
  predictor = xgb_oof$KSI,
  levels = c("Slight", "KSI"),
  direction = "<",
  quiet = TRUE
)

threshold_selection <- pROC::coords(
  oof_roc,
  x = "best",
  best.method = "youden",
  ret = c(
    "threshold",
    "sensitivity",
    "specificity"
  ),
  transpose = FALSE
) %>%
  as.data.frame() %>%
  tibble::as_tibble() %>%
  dplyr::slice_head(n = 1)

locked_threshold <- threshold_selection$threshold[[1]]

predicted_2025 <- dplyr::if_else(
  xgb_prob_2025 >= locked_threshold,
  1L,
  0L
)

TP <- sum(
  predicted_2025 == 1 &
    y25 == 1
)

TN <- sum(
  predicted_2025 == 0 &
    y25 == 0
)

FP <- sum(
  predicted_2025 == 1 &
    y25 == 0
)

FN <- sum(
  predicted_2025 == 0 &
    y25 == 1
)

threshold_metrics_2025 <- tibble::tibble(
  Threshold = locked_threshold,
  TP = TP,
  TN = TN,
  FP = FP,
  FN = FN,
  Sensitivity = TP / (TP + FN),
  Specificity = TN / (TN + FP),
  Precision = TP / (TP + FP),
  NPV = TN / (TN + FN),
  Balanced_Accuracy = (
    TP / (TP + FN) +
      TN / (TN + FP)
  ) / 2
)

print(threshold_selection)
print(threshold_metrics_2025)

# ---- Save outputs -----------------------------------------------------------

temporal_predictions <- tibble::tibble(
  collision_index = model25$collision_index,
  KSI_num = y25,
  Logistic = logit_prob_2025,
  Random_Forest = rf_prob_2025,
  XGBoost = xgb_prob_2025
)

write.csv(
  test_performance,
  file.path(table_dir, "Temporal_Test_Performance_2025.csv"),
  row.names = FALSE
)

write.csv(
  calibration_summary,
  file.path(table_dir, "Calibration_Parameters_2025.csv"),
  row.names = FALSE
)

write.csv(
  calibration_deciles,
  file.path(table_dir, "Calibration_Deciles_2025.csv"),
  row.names = FALSE
)

write.csv(
  threshold_selection,
  file.path(table_dir, "Threshold_Selection_2024_OOF.csv"),
  row.names = FALSE
)

write.csv(
  threshold_metrics_2025,
  file.path(table_dir, "Threshold_Performance_2025.csv"),
  row.names = FALSE
)

saveRDS(
  temporal_predictions,
  file.path(data_derived_dir, "temporal_predictions_2025.rds")
)

saveRDS(
  list(
    test_performance = test_performance,
    calibration_summary = calibration_summary,
    threshold_selection = threshold_selection,
    threshold_metrics_2025 = threshold_metrics_2025
  ),
  file.path(data_derived_dir, "temporal_validation_results.rds")
)

message("Temporal validation complete.")

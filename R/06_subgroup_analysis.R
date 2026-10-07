# 06_subgroup_analysis.R
# Evaluate XGBoost performance and locked-threshold behavior across 2025 subgroups.

source(file.path("R", "00_setup.R"))

model25 <- readRDS(
  file.path(data_derived_dir, "model25.rds")
)

temporal_predictions <- readRDS(
  file.path(data_derived_dir, "temporal_predictions_2025.rds")
)

temporal_results <- readRDS(
  file.path(data_derived_dir, "temporal_validation_results.rds")
)

xgb_prob_2025 <- temporal_predictions$XGBoost
locked_threshold <-
  temporal_results$threshold_selection$threshold[[1]]

subgroup_performance <- function(
  data,
  probs,
  group_var,
  min_n = 500,
  min_positive = 50
) {
  group_name <- rlang::as_name(
    rlang::ensym(group_var)
  )

  tibble(
    Group = as.character(data[[group_name]]),
    y = data$KSI_num,
    p = probs
  ) %>%
    group_by(Group) %>%
    summarise(
      N = n(),
      KSI_N = sum(y == 1),
      KSI_Rate = mean(y),
      ROC_AUC = safe_roc_auc(y, p),
      PR_AUC = safe_pr_auc(y, p),
      Brier = mean((p - y)^2),
      .groups = "drop"
    ) %>%
    filter(
      N >= min_n,
      KSI_N >= min_positive,
      (N - KSI_N) >= min_positive
    ) %>%
    mutate(
      Variable = group_name,
      .before = 1
    )
}

threshold_subgroup <- function(
  data,
  probs,
  group_var,
  threshold,
  min_n = 500
) {
  group_name <- rlang::as_name(
    rlang::ensym(group_var)
  )

  tibble(
    Group = as.character(data[[group_name]]),
    y = data$KSI_num,
    p = probs
  ) %>%
    mutate(
      pred = if_else(
        p >= threshold,
        1L,
        0L
      )
    ) %>%
    group_by(Group) %>%
    summarise(
      N = n(),
      KSI_Rate = mean(y),
      TP = sum(pred == 1 & y == 1),
      TN = sum(pred == 0 & y == 0),
      FP = sum(pred == 1 & y == 0),
      FN = sum(pred == 0 & y == 1),
      .groups = "drop"
    ) %>%
    filter(N >= min_n) %>%
    mutate(
      Sensitivity = TP / (TP + FN),
      Specificity = TN / (TN + FP),
      Precision = TP / (TP + FP),
      Balanced_Accuracy =
        (Sensitivity + Specificity) / 2,
      Variable = group_name,
      .before = 1
    ) %>%
    select(
      Variable,
      Group,
      N,
      KSI_Rate,
      Sensitivity,
      Specificity,
      Precision,
      Balanced_Accuracy
    )
}

heterogeneity_results <- bind_rows(
  subgroup_performance(
    model25,
    xgb_prob_2025,
    casualty_class
  ),
  subgroup_performance(
    model25,
    xgb_prob_2025,
    age_band_of_casualty
  ),
  subgroup_performance(
    model25,
    xgb_prob_2025,
    urban_or_rural_area
  ),
  subgroup_performance(
    model25,
    xgb_prob_2025,
    speed_limit
  ),
  subgroup_performance(
    model25,
    xgb_prob_2025,
    road_type
  )
)

threshold_heterogeneity <- bind_rows(
  threshold_subgroup(
    model25,
    xgb_prob_2025,
    casualty_class,
    locked_threshold
  ),
  threshold_subgroup(
    model25,
    xgb_prob_2025,
    age_band_of_casualty,
    locked_threshold
  ),
  threshold_subgroup(
    model25,
    xgb_prob_2025,
    urban_or_rural_area,
    locked_threshold
  ),
  threshold_subgroup(
    model25,
    xgb_prob_2025,
    speed_limit,
    locked_threshold
  ),
  threshold_subgroup(
    model25,
    xgb_prob_2025,
    road_type,
    locked_threshold
  )
)

print(
  heterogeneity_results,
  n = Inf
)

print(
  threshold_heterogeneity,
  n = Inf
)

write.csv(
  heterogeneity_results,
  file.path(table_dir, "XGBoost_Subgroup_Performance_2025.csv"),
  row.names = FALSE
)

write.csv(
  threshold_heterogeneity,
  file.path(table_dir, "XGBoost_Threshold_Subgroups_2025.csv"),
  row.names = FALSE
)

saveRDS(
  list(
    heterogeneity_results = heterogeneity_results,
    threshold_heterogeneity = threshold_heterogeneity
  ),
  file.path(data_derived_dir, "subgroup_results_2025.rds")
)

message("Subgroup analysis complete.")

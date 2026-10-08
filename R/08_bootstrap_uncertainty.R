# 08_bootstrap_uncertainty.R
# Paired collision-level bootstrap for 2025 model-performance uncertainty.

source(file.path("R", "00_setup.R"))

model25 <- readRDS(
  file.path(data_derived_dir, "model25.rds")
)

temporal_predictions <- readRDS(
  file.path(data_derived_dir, "temporal_predictions_2025.rds")
)

B <- as.integer(
  Sys.getenv(
    "STATS19_BOOTSTRAP_B",
    "500"
  )
)

if (is.na(B) || B < 1) {
  stop("STATS19_BOOTSTRAP_B must be a positive integer.")
}

set.seed(20261007)

collision_rows <- split(
  seq_len(nrow(model25)),
  model25$collision_index
)

collision_ids <- names(collision_rows)
n_collisions <- length(collision_ids)

bootstrap_results <- vector(
  "list",
  B
)

for (b in seq_len(B)) {
  sampled_ids <- sample(
    collision_ids,
    size = n_collisions,
    replace = TRUE
  )

  idx <- unlist(
    collision_rows[sampled_ids],
    use.names = FALSE
  )

  y <- temporal_predictions$KSI_num[idx]

  p_logit <-
    temporal_predictions$Logistic[idx]

  p_rf <-
    temporal_predictions$Random_Forest[idx]

  p_xgb <-
    temporal_predictions$XGBoost[idx]

  auc_logit <- safe_roc_auc(y, p_logit)
  auc_rf <- safe_roc_auc(y, p_rf)
  auc_xgb <- safe_roc_auc(y, p_xgb)

  pr_logit <- safe_pr_auc(y, p_logit)
  pr_rf <- safe_pr_auc(y, p_rf)
  pr_xgb <- safe_pr_auc(y, p_xgb)

  brier_logit <- mean((p_logit - y)^2)
  brier_rf <- mean((p_rf - y)^2)
  brier_xgb <- mean((p_xgb - y)^2)

  bootstrap_results[[b]] <- tibble::tibble(
    Replicate = b,

    Logistic_ROC = auc_logit,
    RF_ROC = auc_rf,
    XGB_ROC = auc_xgb,

    Logistic_PR = pr_logit,
    RF_PR = pr_rf,
    XGB_PR = pr_xgb,

    Logistic_Brier = brier_logit,
    RF_Brier = brier_rf,
    XGB_Brier = brier_xgb,

    XGB_minus_Logit_ROC =
      auc_xgb - auc_logit,

    XGB_minus_RF_ROC =
      auc_xgb - auc_rf,

    XGB_minus_Logit_PR =
      pr_xgb - pr_logit,

    XGB_minus_RF_PR =
      pr_xgb - pr_rf
  )

  if (b %% 50 == 0) {
    message(
      "Completed ",
      b,
      " of ",
      B,
      " bootstrap replicates."
    )
  }
}

bootstrap_results <- dplyr::bind_rows(
  bootstrap_results
)

bootstrap_ci <- function(x) {
  tibble::tibble(
    Estimate_Mean = mean(x),
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

bootstrap_summary <- dplyr::bind_rows(
  bootstrap_ci(
    bootstrap_results$Logistic_ROC
  ) %>%
    dplyr::mutate(Metric = "Logistic ROC-AUC"),

  bootstrap_ci(
    bootstrap_results$RF_ROC
  ) %>%
    dplyr::mutate(Metric = "Random Forest ROC-AUC"),

  bootstrap_ci(
    bootstrap_results$XGB_ROC
  ) %>%
    dplyr::mutate(Metric = "XGBoost ROC-AUC"),

  bootstrap_ci(
    bootstrap_results$Logistic_PR
  ) %>%
    dplyr::mutate(Metric = "Logistic PR-AUC"),

  bootstrap_ci(
    bootstrap_results$RF_PR
  ) %>%
    dplyr::mutate(Metric = "Random Forest PR-AUC"),

  bootstrap_ci(
    bootstrap_results$XGB_PR
  ) %>%
    dplyr::mutate(Metric = "XGBoost PR-AUC"),

  bootstrap_ci(
    bootstrap_results$XGB_minus_Logit_ROC
  ) %>%
    dplyr::mutate(Metric = "XGBoost - Logistic ROC"),

  bootstrap_ci(
    bootstrap_results$XGB_minus_RF_ROC
  ) %>%
    dplyr::mutate(Metric = "XGBoost - RF ROC"),

  bootstrap_ci(
    bootstrap_results$XGB_minus_Logit_PR
  ) %>%
    dplyr::mutate(Metric = "XGBoost - Logistic PR"),

  bootstrap_ci(
    bootstrap_results$XGB_minus_RF_PR
  ) %>%
    dplyr::mutate(Metric = "XGBoost - RF PR")
) %>%
  dplyr::select(
    Metric,
    Estimate_Mean,
    Lower_95,
    Upper_95
  )

print(
  bootstrap_summary,
  n = Inf
)

write.csv(
  bootstrap_results,
  file.path(
    table_dir,
    paste0(
      "Collision_Level_Bootstrap_",
      B,
      ".csv"
    )
  ),
  row.names = FALSE
)

write.csv(
  bootstrap_summary,
  file.path(
    table_dir,
    "Bootstrap_Confidence_Intervals.csv"
  ),
  row.names = FALSE
)

saveRDS(
  bootstrap_results,
  file.path(
    data_derived_dir,
    "Collision_Bootstrap_2025.rds"
  )
)

saveRDS(
  bootstrap_summary,
  file.path(
    data_derived_dir,
    "Bootstrap_Summary_2025.rds"
  )
)

message("Collision-level bootstrap complete.")

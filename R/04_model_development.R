# 04_model_development.R
# Develop logistic regression, Random Forest, and XGBoost using 2024 data only.

if (!exists("model24")) {
  source(file.path("R", "00_setup.R"))

  model24 <- readRDS(
    file.path(data_derived_dir, "model24.rds")
  )

  predictor_definitions <- readRDS(
    file.path(data_derived_dir, "predictor_definitions.rds")
  )

  primary_predictors <- predictor_definitions$primary_predictors
}

train24 <- model24 %>%
  dplyr::select(
    KSI,
    dplyr::all_of(primary_predictors)
  )

set.seed(20261006)

group_folds <- caret::groupKFold(
  model24$collision_index,
  k = 5
)

# Confirm that no collision appears in both train and validation portions.
fold_audit <- purrr::map_dfr(
  seq_along(group_folds),
  function(i) {
    train_idx <- group_folds[[i]]
    valid_idx <- setdiff(seq_len(nrow(model24)), train_idx)

    train_collisions <- unique(model24$collision_index[train_idx])
    valid_collisions <- unique(model24$collision_index[valid_idx])

    tibble::tibble(
      Fold = i,
      Train_Rows = length(train_idx),
      Validation_Rows = length(valid_idx),
      Collision_Overlap = length(
        intersect(train_collisions, valid_collisions)
      ),
      Validation_KSI_Rate = mean(
        model24$KSI_num[valid_idx]
      )
    )
  }
)

print(fold_audit)

if (any(fold_audit$Collision_Overlap != 0)) {
  stop("Collision leakage detected in grouped cross-validation.")
}

ctrl_grouped <- caret::trainControl(
  method = "cv",
  number = 5,
  index = group_folds,
  classProbs = TRUE,
  summaryFunction = caret::twoClassSummary,
  savePredictions = "final",
  allowParallel = TRUE
)

saveRDS(
  ctrl_grouped,
  file.path(data_derived_dir, "grouped_train_control.rds")
)

# ---- Logistic regression ----------------------------------------------------

set.seed(20261006)

logit_fit <- caret::train(
  KSI ~ .,
  data = train24,
  method = "glm",
  family = stats::binomial(),
  metric = "ROC",
  trControl = ctrl_grouped
)

# Save immediately so a later reporting error does not require refitting.
saveRDS(
  logit_fit,
  file.path(model_dir, "Final_Logistic_Model_2024.rds")
)

# ---- Random Forest ----------------------------------------------------------

rf_grid <- expand.grid(
  mtry = c(5, 9, 13),
  splitrule = "gini",
  min.node.size = c(20, 100)
)

set.seed(20261006)

rf_fit <- caret::train(
  KSI ~ .,
  data = train24,
  method = "ranger",
  metric = "ROC",
  trControl = ctrl_grouped,
  tuneGrid = rf_grid,
  num.trees = 500,
  importance = "none"
)

saveRDS(
  rf_fit,
  file.path(model_dir, "Final_RandomForest_Model_2024.rds")
)

# ---- XGBoost ---------------------------------------------------------------

xgb_grid <- expand.grid(
  nrounds = c(300, 600),
  max_depth = c(3, 6),
  eta = 0.05,
  gamma = 0,
  colsample_bytree = 0.8,
  min_child_weight = 5,
  subsample = 0.8
)

set.seed(20261006)

xgb_fit <- caret::train(
  KSI ~ .,
  data = train24,
  method = "xgbTree",
  metric = "ROC",
  trControl = ctrl_grouped,
  tuneGrid = xgb_grid,
  verbose = FALSE
)

saveRDS(
  xgb_fit,
  file.path(model_dir, "Final_XGBoost_Model_2024.rds")
)

# ---- Cross-validation summaries --------------------------------------------
# Namespace dplyr explicitly because some modelling packages export functions
# named slice/select that can mask tidyverse verbs in interactive sessions.

logit_cv <- logit_fit$results %>%
  tibble::as_tibble() %>%
  dplyr::arrange(dplyr::desc(ROC)) %>%
  dplyr::slice_head(n = 1) %>%
  dplyr::mutate(Model = "Logistic regression")

rf_cv <- rf_fit$results %>%
  tibble::as_tibble() %>%
  dplyr::semi_join(
    tibble::as_tibble(rf_fit$bestTune),
    by = names(rf_fit$bestTune)
  ) %>%
  dplyr::mutate(Model = "Random Forest")

xgb_cv <- xgb_fit$results %>%
  tibble::as_tibble() %>%
  dplyr::semi_join(
    tibble::as_tibble(xgb_fit$bestTune),
    by = names(xgb_fit$bestTune)
  ) %>%
  dplyr::mutate(Model = "XGBoost")

cv_performance <- dplyr::bind_rows(
  logit_cv %>%
    dplyr::transmute(Model, ROC, Sens, Spec),
  rf_cv %>%
    dplyr::transmute(Model, ROC, Sens, Spec),
  xgb_cv %>%
    dplyr::transmute(Model, ROC, Sens, Spec)
)

print(cv_performance)
print(rf_fit$bestTune)
print(xgb_fit$bestTune)

write.csv(
  fold_audit,
  file.path(table_dir, "Grouped_CV_Fold_Audit.csv"),
  row.names = FALSE
)

write.csv(
  cv_performance,
  file.path(table_dir, "Grouped_CV_Performance_2024.csv"),
  row.names = FALSE
)

write.csv(
  rf_fit$results,
  file.path(table_dir, "Random_Forest_Tuning_2024.csv"),
  row.names = FALSE
)

write.csv(
  xgb_fit$results,
  file.path(table_dir, "XGBoost_Tuning_2024.csv"),
  row.names = FALSE
)

message("Model development complete.")

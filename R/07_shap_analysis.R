# 07_shap_analysis.R
# Grouped SHAP interpretation, directional summaries, road-user heterogeneity,
# and a sensitivity model without casualty_type.

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

xgb_fit <- readRDS(
  file.path(model_dir, "Final_XGBoost_Model_2024.rds")
)

ctrl_grouped <- readRDS(
  file.path(data_derived_dir, "grouped_train_control.rds")
)

test25 <- model25 %>%
  dplyr::select(
    KSI,
    dplyr::all_of(primary_predictors)
  )

# ---- Reconstruct exact 2025 XGBoost matrix ---------------------------------

xgb_features <- xgb_fit$finalModel$feature_names

xgb_matrix_2025 <- model.matrix(
  KSI ~ .,
  data = test25
)

xgb_matrix_2025 <- xgb_matrix_2025[
  ,
  colnames(xgb_matrix_2025) != "(Intercept)",
  drop = FALSE
]

if (!identical(
  colnames(xgb_matrix_2025),
  xgb_features
)) {
  stop(
    "Reconstructed 2025 model matrix does not match fitted XGBoost features."
  )
}

# ---- Exactly 50,000 prevalence-preserving SHAP observations ----------------

set.seed(20261006)

n_shap <- 50000
ksi_share <- mean(model25$KSI_num)

n_ksi_shap <- round(
  n_shap * ksi_share
)

n_slight_shap <- n_shap - n_ksi_shap

ksi_indices <- sample(
  which(model25$KSI_num == 1),
  n_ksi_shap
)

slight_indices <- sample(
  which(model25$KSI_num == 0),
  n_slight_shap
)

shap_indices <- sort(
  c(
    ksi_indices,
    slight_indices
  )
)

shap_dmatrix <- xgboost::xgb.DMatrix(
  data = xgb_matrix_2025[
    shap_indices,
    ,
    drop = FALSE
  ]
)

shap_raw <- predict(
  xgb_fit$finalModel,
  newdata = shap_dmatrix,
  predcontrib = TRUE
)

colnames(shap_raw) <- c(
  xgb_features,
  "BIAS"
)

shap_values <- shap_raw[
  ,
  xgb_features,
  drop = FALSE
]

# ---- Group dummy-level SHAP back to original predictors --------------------

get_feature_columns <- function(variable_name) {
  which(
    colnames(shap_values) == variable_name |
      startsWith(
        colnames(shap_values),
        variable_name
      )
  )
}

grouped_shap_signed <- sapply(
  primary_predictors,
  function(v) {
    idx <- get_feature_columns(v)

    if (length(idx) == 0) {
      stop(
        "No SHAP columns found for: ",
        v
      )
    }

    rowSums(
      shap_values[
        ,
        idx,
        drop = FALSE
      ]
    )
  }
)

# Cyclical components represent one conceptual feature each.
conceptual_shap <- cbind(
  grouped_shap_signed[
    ,
    setdiff(
      colnames(grouped_shap_signed),
      c(
        "hour_sin",
        "hour_cos",
        "month_sin",
        "month_cos"
      )
    ),
    drop = FALSE
  ],

  time_of_day =
    grouped_shap_signed[, "hour_sin"] +
    grouped_shap_signed[, "hour_cos"],

  seasonality =
    grouped_shap_signed[, "month_sin"] +
    grouped_shap_signed[, "month_cos"]
)

grouped_shap_final <- tibble::tibble::tibble(
  Variable = colnames(conceptual_shap),
  Mean_Absolute_SHAP =
    colMeans(abs(conceptual_shap))
) %>%
  dplyr::arrange(dplyr::desc(Mean_Absolute_SHAP))

print(
  grouped_shap_final,
  n = Inf
)

# ---- Directional SHAP summaries --------------------------------------------

shap_sample_data <- model25[
  shap_indices,
  ,
  drop = FALSE
]

casualty_type_labels <- c(
  "-1" = "Missing / out of range",
  "0"  = "Pedestrian",
  "1"  = "Cyclist",
  "2"  = "Motorcycle 50cc and under rider/passenger",
  "3"  = "Motorcycle 125cc and under rider/passenger",
  "4"  = "Motorcycle >125cc to 500cc rider/passenger",
  "5"  = "Motorcycle over 500cc rider/passenger",
  "8"  = "Taxi/private hire car occupant",
  "9"  = "Car occupant",
  "10" = "Minibus occupant",
  "11" = "Bus or coach occupant",
  "16" = "Horse rider",
  "17" = "Agricultural vehicle occupant",
  "18" = "Tram occupant",
  "19" = "Van/goods ≤3.5t occupant",
  "20" = "Goods vehicle >3.5t to <7.5t occupant",
  "21" = "Goods vehicle ≥7.5t occupant",
  "22" = "Mobility scooter rider",
  "23" = "Electric motorcycle rider/passenger",
  "33" = "Personal Powered Transporter rider",
  "90" = "Other vehicle occupant",
  "97" = "Motorcycle – unknown cc rider/passenger",
  "98" = "Goods vehicle – unknown weight occupant",
  "99" = "Unknown vehicle type"
)

age_band_labels <- c(
  "-1" = "Missing / out of range",
  "1" = "0–5",
  "2" = "6–10",
  "3" = "11–15",
  "4" = "16–20",
  "5" = "21–25",
  "6" = "26–35",
  "7" = "36–45",
  "8" = "46–55",
  "9" = "56–65",
  "10" = "66–75",
  "11" = "Over 75"
)

casualty_type_shap <- tibble::tibble(
  casualty_type =
    as.character(
      shap_sample_data$casualty_type
    ),
  KSI_num =
    shap_sample_data$KSI_num,
  SHAP =
    conceptual_shap[, "casualty_type"]
) %>%
  dplyr::group_by(casualty_type) %>%
  dplyr::summarise(
    SHAP_Sample_N = n(),
    Mean_SHAP = mean(SHAP),
    Mean_Absolute_SHAP = mean(abs(SHAP)),
    .groups = "drop"
  )

casualty_type_full_2025 <- model25 %>%
  dplyr::mutate(
    casualty_type =
      as.character(casualty_type)
  ) %>%
  dplyr::group_by(casualty_type) %>%
  dplyr::summarise(
    N_2025 = n(),
    KSI_N_2025 = sum(KSI_num == 1),
    KSI_Rate_2025 = mean(KSI_num),
    .groups = "drop"
  )

casualty_type_final <- casualty_type_shap %>%
  dplyr::left_join(
    casualty_type_full_2025,
    by = "casualty_type"
  ) %>%
  dplyr::mutate(
    Casualty_Type_Label =
      unname(
        casualty_type_labels[casualty_type]
      )
  ) %>%
  dplyr::arrange(desc(Mean_SHAP))

casualty_type_publication <- casualty_type_final %>%
  dplyr::filter(N_2025 >= 500) %>%
  dplyr::transmute(
    Casualty_Type = Casualty_Type_Label,
    N = N_2025,
    KSI = KSI_N_2025,
    KSI_Percent =
      round(100 * KSI_Rate_2025, 1),
    Mean_SHAP =
      round(Mean_SHAP, 3),
    Mean_Absolute_SHAP =
      round(Mean_Absolute_SHAP, 3)
  )

age_shap <- tibble::tibble(
  age_band =
    as.character(
      shap_sample_data$age_band_of_casualty
    ),
  SHAP =
    conceptual_shap[
      ,
      "age_band_of_casualty"
    ]
) %>%
  dplyr::group_by(age_band) %>%
  dplyr::summarise(
    Mean_SHAP = mean(SHAP),
    Mean_Absolute_SHAP = mean(abs(SHAP)),
    .groups = "drop"
  )

age_full_2025 <- model25 %>%
  dplyr::mutate(
    age_band =
      as.character(age_band_of_casualty)
  ) %>%
  dplyr::group_by(age_band) %>%
  dplyr::summarise(
    N_2025 = n(),
    KSI_N_2025 = sum(KSI_num == 1),
    KSI_Rate_2025 = mean(KSI_num),
    .groups = "drop"
  )

age_publication <- age_shap %>%
  dplyr::left_join(
    age_full_2025,
    by = "age_band"
  ) %>%
  dplyr::mutate(
    Age_Band =
      unname(age_band_labels[age_band])
  ) %>%
  dplyr::arrange(as.numeric(age_band)) %>%
  dplyr::transmute(
    Age_Band,
    N = N_2025,
    KSI = KSI_N_2025,
    KSI_Percent =
      round(100 * KSI_Rate_2025, 1),
    Mean_SHAP =
      round(Mean_SHAP, 3),
    Mean_Absolute_SHAP =
      round(Mean_Absolute_SHAP, 3)
  )

speed_shap <- tibble::tibble(
  speed_limit =
    as.character(
      shap_sample_data$speed_limit
    ),
  KSI_num =
    shap_sample_data$KSI_num,
  SHAP =
    conceptual_shap[, "speed_limit"]
) %>%
  dplyr::group_by(speed_limit) %>%
  dplyr::summarise(
    SHAP_Sample_N = n(),
    KSI_Rate_SHAP_Sample = mean(KSI_num),
    Mean_SHAP = mean(SHAP),
    Mean_Absolute_SHAP = mean(abs(SHAP)),
    .groups = "drop"
  ) %>%
  dplyr::arrange(as.numeric(speed_limit))

# ---- SHAP within casualty class --------------------------------------------

class_labels <- c(
  "1" = "Driver or rider",
  "2" = "Passenger",
  "3" = "Pedestrian"
)

within_group_shap <- lapply(
  c("1", "2", "3"),
  function(g) {
    idx <- as.character(
      shap_sample_data$casualty_class
    ) == g

    subgroup_data <- shap_sample_data[
      idx,
      ,
      drop = FALSE
    ]

    varying_vars <- setdiff(
      colnames(conceptual_shap),
      "casualty_class"
    )

    if (
      dplyr::n_distinct(
        subgroup_data$casualty_type
      ) <= 1
    ) {
      varying_vars <- setdiff(
        varying_vars,
        "casualty_type"
      )
    }

    tibble::tibble(
      Casualty_Class =
        unname(class_labels[g]),
      Variable = varying_vars,
      Mean_Absolute_SHAP =
        colMeans(
          abs(
            conceptual_shap[
              idx,
              varying_vars,
              drop = FALSE
            ]
          )
        ),
      N = sum(idx)
    ) %>%
      arrange(desc(Mean_Absolute_SHAP)) %>%
      mutate(Rank = row_number())
  }
) %>%
  dplyr::bind_rows()

top_within_group <- within_group_shap %>%
  dplyr::group_by(Casualty_Class) %>%
  slice_min(
    order_by = Rank,
    n = 8
  ) %>%
  dplyr::ungroup()

# ---- Robustness: remove casualty_type ---------------------------------------

reduced_predictors <- setdiff(
  primary_predictors,
  "casualty_type"
)

reduced24 <- model24 %>%
  dplyr::select(
    KSI,
    dplyr::all_of(reduced_predictors)
  )

reduced25 <- model25 %>%
  dplyr::select(
    KSI,
    dplyr::all_of(reduced_predictors)
  )

set.seed(20261006)

# Save the primary SHAP products before the robustness refit so that a later
# model-fitting/reporting error does not discard the expensive SHAP calculation.
saveRDS(
  grouped_shap_final,
  file.path(data_derived_dir, "Grouped_SHAP_2025.rds")
)

saveRDS(
  list(
    shap_indices = shap_indices,
    conceptual_shap = conceptual_shap,
    within_group_shap = within_group_shap
  ),
  file.path(data_derived_dir, "SHAP_Derived_2025.rds")
)

xgb_reduced <- caret::train(
  KSI ~ .,
  data = reduced24,
  method = "xgbTree",
  metric = "ROC",
  trControl = ctrl_grouped,
  tuneGrid = xgb_fit$bestTune,
  verbose = FALSE
)

reduced_prob_2025 <- predict(
  xgb_reduced,
  newdata = reduced25,
  type = "prob"
)[, "KSI"]

reduced_results <- tibble::tibble(
  Model = "XGBoost without casualty_type",
  CV_ROC_2024 =
    xgb_reduced$results$ROC[[1]],
  ROC_AUC =
    safe_roc_auc(
      model25$KSI_num,
      reduced_prob_2025
    ),
  PR_AUC =
    safe_pr_auc(
      model25$KSI_num,
      reduced_prob_2025
    ),
  Brier =
    mean(
      (
        reduced_prob_2025 -
          model25$KSI_num
      )^2
    )
)

print(casualty_type_publication, n = Inf)
print(age_publication, n = Inf)
print(top_within_group, n = Inf)
print(reduced_results)

# ---- Publication figures ----------------------------------------------------

figure8 <- ggplot(
  grouped_shap_final,
  aes(
    x = reorder(
      Variable,
      Mean_Absolute_SHAP
    ),
    y = Mean_Absolute_SHAP
  )
) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Predictor Contributions to XGBoost KSI Predictions",
    subtitle = "Grouped SHAP contributions, 2025 temporal test sample",
    x = NULL,
    y = "Mean absolute grouped SHAP contribution"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

figure9 <- ggplot(
  top_within_group,
  aes(
    x = Mean_Absolute_SHAP,
    y = reorder(
      Variable,
      Mean_Absolute_SHAP
    )
  )
) +
  geom_col() +
  facet_wrap(
    ~ Casualty_Class,
    scales = "free_y",
    nrow = 1
  ) +
  labs(
    title = "Predictor Contributions Within Road-User Groups",
    subtitle = "Grouped SHAP contributions, 2025 temporal test sample",
    x = "Mean absolute grouped SHAP contribution",
    y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    strip.text = element_text(size = 10),
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

ggsave(
  file.path(figure_dir, "Figure_8_Global_Grouped_SHAP_Publication.png"),
  figure8,
  width = 9,
  height = 6,
  dpi = 400
)

ggsave(
  file.path(figure_dir, "Figure_9_SHAP_Within_Road_User_Groups_Publication.png"),
  figure9,
  width = 14,
  height = 6,
  dpi = 400
)

# ---- Save tables and objects ------------------------------------------------

write.csv(
  grouped_shap_final,
  file.path(table_dir, "Grouped_SHAP_Importance_2025.csv"),
  row.names = FALSE
)

write.csv(
  casualty_type_publication,
  file.path(table_dir, "Casualty_Type_SHAP_2025.csv"),
  row.names = FALSE
)

write.csv(
  age_publication,
  file.path(table_dir, "Age_SHAP_2025.csv"),
  row.names = FALSE
)

write.csv(
  speed_shap,
  file.path(table_dir, "Speed_Limit_SHAP_2025.csv"),
  row.names = FALSE
)

write.csv(
  within_group_shap,
  file.path(table_dir, "SHAP_Within_Road_User_Groups_2025.csv"),
  row.names = FALSE
)

write.csv(
  reduced_results,
  file.path(table_dir, "Robustness_Remove_Casualty_Type.csv"),
  row.names = FALSE
)

saveRDS(
  grouped_shap_final,
  file.path(data_derived_dir, "Grouped_SHAP_2025.rds")
)

saveRDS(
  list(
    shap_indices = shap_indices,
    conceptual_shap = conceptual_shap,
    within_group_shap = within_group_shap
  ),
  file.path(data_derived_dir, "SHAP_Derived_2025.rds")
)

saveRDS(
  xgb_reduced,
  file.path(model_dir, "XGBoost_Without_Casualty_Type.rds")
)

message("SHAP and sensitivity analyses complete.")

# 02_data_linkage_cleaning.R
# Join collision, vehicle, and casualty records and construct the modelling data.

if (!exists("cas24")) {
  source(file.path("R", "01_data_import.R"))
}

collision_vars <- c(
  "collision_index",
  "number_of_vehicles",
  "date",
  "day_of_week",
  "time",
  "road_type",
  "speed_limit",
  "junction_detail",
  "junction_control",
  "pedestrian_crossing",
  "light_conditions",
  "weather_conditions",
  "road_surface_conditions",
  "urban_or_rural_area"
)

vehicle_vars <- c(
  "collision_index",
  "vehicle_reference",
  "vehicle_type",
  "vehicle_manoeuvre",
  "junction_location",
  "skidding_and_overturning",
  "vehicle_leaving_carriageway",
  "first_point_of_impact",
  "sex_of_driver",
  "age_band_of_driver"
)

check_key_uniqueness <- function(collision, vehicle, casualty, year) {
  duplicate_collision <- collision %>%
    count(collision_index) %>%
    filter(n > 1)

  duplicate_vehicle <- vehicle %>%
    count(collision_index, vehicle_reference) %>%
    filter(n > 1)

  duplicate_casualty <- casualty %>%
    count(collision_index, casualty_reference) %>%
    filter(n > 1)

  if (nrow(duplicate_collision) > 0 ||
      nrow(duplicate_vehicle) > 0 ||
      nrow(duplicate_casualty) > 0) {
    stop("Duplicate linkage keys detected in ", year, ".")
  }

  invisible(TRUE)
}

check_key_uniqueness(col24, veh24, cas24, 2024)
check_key_uniqueness(col25, veh25, cas25, 2025)

check_linkage <- function(collision, vehicle, casualty, year) {
  unmatched_collision <- casualty %>%
    anti_join(
      collision %>% distinct(collision_index),
      by = "collision_index"
    )

  unmatched_vehicle <- casualty %>%
    anti_join(
      vehicle %>%
        distinct(collision_index, vehicle_reference),
      by = c("collision_index", "vehicle_reference")
    )

  if (nrow(unmatched_collision) > 0 ||
      nrow(unmatched_vehicle) > 0) {
    stop(
      "Unmatched casualty records detected in ", year,
      ": collision=", nrow(unmatched_collision),
      ", vehicle=", nrow(unmatched_vehicle)
    )
  }

  invisible(TRUE)
}

check_linkage(col24, veh24, cas24, 2024)
check_linkage(col25, veh25, cas25, 2025)

build_analysis_data <- function(casualty, collision, vehicle) {
  casualty %>%
    left_join(
      collision %>%
        select(all_of(collision_vars)),
      by = "collision_index"
    ) %>%
    left_join(
      vehicle %>%
        select(all_of(vehicle_vars)),
      by = c("collision_index", "vehicle_reference")
    ) %>%
    mutate(
      KSI_num = case_when(
        casualty_severity %in% c(1, 2) ~ 1L,
        casualty_severity == 3 ~ 0L,
        TRUE ~ NA_integer_
      ),
      KSI = factor(
        if_else(KSI_num == 1L, "KSI", "Slight"),
        levels = c("KSI", "Slight")
      ),
      crash_date = parse_stats19_date(date),
      hour = extract_hour(time),
      month = as.integer(format(crash_date, "%m")),
      hour_sin = sin(2 * pi * hour / 24),
      hour_cos = cos(2 * pi * hour / 24),
      month_sin = sin(2 * pi * month / 12),
      month_cos = cos(2 * pi * month / 12)
    ) %>%
    filter(!is.na(KSI_num))
}

analysis_2024 <- build_analysis_data(
  cas24,
  col24,
  veh24
)

analysis_2025 <- build_analysis_data(
  cas25,
  col25,
  veh25
)

primary_predictors <- c(
  "casualty_class",
  "sex_of_casualty",
  "age_band_of_casualty",
  "casualty_type",
  "day_of_week",
  "hour_sin",
  "hour_cos",
  "month_sin",
  "month_cos",
  "road_type",
  "speed_limit",
  "light_conditions",
  "weather_conditions",
  "urban_or_rural_area",
  "number_of_vehicles",
  "vehicle_type",
  "sex_of_driver",
  "age_band_of_driver"
)

categorical_predictors <- c(
  "casualty_class",
  "sex_of_casualty",
  "age_band_of_casualty",
  "casualty_type",
  "day_of_week",
  "road_type",
  "speed_limit",
  "light_conditions",
  "weather_conditions",
  "urban_or_rural_area",
  "vehicle_type",
  "sex_of_driver",
  "age_band_of_driver"
)

for (v in categorical_predictors) {
  analysis_2024[[v]] <- factor(analysis_2024[[v]])

  analysis_2025[[v]] <- factor(
    analysis_2025[[v]],
    levels = levels(analysis_2024[[v]])
  )

  if (anyNA(analysis_2025[[v]])) {
    stop(
      "2025 contains unseen or missing aligned levels for predictor: ",
      v
    )
  }
}

model24 <- analysis_2024 %>%
  select(
    collision_index,
    KSI_num,
    KSI,
    all_of(primary_predictors)
  )

model25 <- analysis_2025 %>%
  select(
    collision_index,
    KSI_num,
    KSI,
    all_of(primary_predictors)
  )

severity_summary <- bind_rows(
  analysis_2024 %>%
    count(casualty_severity, name = "N") %>%
    mutate(Year = 2024),
  analysis_2025 %>%
    count(casualty_severity, name = "N") %>%
    mutate(Year = 2025)
) %>%
  select(Year, casualty_severity, N)

ksi_summary <- tibble(
  Year = c(2024, 2025),
  Casualties = c(nrow(model24), nrow(model25)),
  Recorded_KSI = c(sum(model24$KSI_num), sum(model25$KSI_num)),
  Recorded_KSI_Prevalence = c(
    mean(model24$KSI_num),
    mean(model25$KSI_num)
  )
)

print(ksi_summary)

write.csv(
  severity_summary,
  file.path(table_dir, "Recorded_Severity_Counts.csv"),
  row.names = FALSE
)

write.csv(
  ksi_summary,
  file.path(table_dir, "Recorded_KSI_Summary.csv"),
  row.names = FALSE
)

saveRDS(
  analysis_2024,
  file.path(data_derived_dir, "analysis_2024.rds")
)

saveRDS(
  analysis_2025,
  file.path(data_derived_dir, "analysis_2025.rds")
)

saveRDS(
  model24,
  file.path(data_derived_dir, "model24.rds")
)

saveRDS(
  model25,
  file.path(data_derived_dir, "model25.rds")
)

saveRDS(
  list(
    primary_predictors = primary_predictors,
    categorical_predictors = categorical_predictors
  ),
  file.path(data_derived_dir, "predictor_definitions.rds")
)

message("Linkage and feature construction complete.")

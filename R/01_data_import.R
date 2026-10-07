# 01_data_import.R
# Import final 2024 and 2025 STATS19 collision, vehicle, and casualty files.

if (!exists("find_stats19_file")) {
  source(file.path("R", "00_setup.R"))
}

read_stats19 <- function(record_type, year) {
  path <- find_stats19_file(record_type, year)

  message("Reading ", basename(path))

  readr::read_csv(
    path,
    show_col_types = FALSE,
    progress = FALSE
  )
}

col24 <- read_stats19("collision", 2024)
veh24 <- read_stats19("vehicle", 2024)
cas24 <- read_stats19("casualty", 2024)

col25 <- read_stats19("collision", 2025)
veh25 <- read_stats19("vehicle", 2025)
cas25 <- read_stats19("casualty", 2025)

require_columns(
  col24,
  c(
    "collision_index", "number_of_vehicles", "date", "day_of_week",
    "time", "road_type", "speed_limit", "junction_detail",
    "junction_control", "pedestrian_crossing_physical_facilities",
    "light_conditions", "weather_conditions",
    "road_surface_conditions", "urban_or_rural_area"
  ),
  "2024 collision data"
)

require_columns(
  col25,
  c(
    "collision_index", "number_of_vehicles", "date", "day_of_week",
    "time", "road_type", "speed_limit", "junction_detail",
    "junction_control", "pedestrian_crossing_physical_facilities",
    "light_conditions", "weather_conditions",
    "road_surface_conditions", "urban_or_rural_area"
  ),
  "2025 collision data"
)

require_columns(
  veh24,
  c(
    "collision_index", "vehicle_reference", "vehicle_type",
    "vehicle_manoeuvre", "junction_location",
    "skidding_and_overturning", "vehicle_leaving_carriageway",
    "first_point_of_impact", "sex_of_driver", "age_band_of_driver"
  ),
  "2024 vehicle data"
)

require_columns(
  veh25,
  c(
    "collision_index", "vehicle_reference", "vehicle_type",
    "vehicle_manoeuvre", "junction_location",
    "skidding_and_overturning", "vehicle_leaving_carriageway",
    "first_point_of_impact", "sex_of_driver", "age_band_of_driver"
  ),
  "2025 vehicle data"
)

require_columns(
  cas24,
  c(
    "collision_index", "vehicle_reference", "casualty_reference",
    "casualty_class", "sex_of_casualty", "age_band_of_casualty",
    "casualty_type", "casualty_severity"
  ),
  "2024 casualty data"
)

require_columns(
  cas25,
  c(
    "collision_index", "vehicle_reference", "casualty_reference",
    "casualty_class", "sex_of_casualty", "age_band_of_casualty",
    "casualty_type", "casualty_severity"
  ),
  "2025 casualty data"
)

source_dimensions <- tibble(
  Year = c(2024, 2024, 2024, 2025, 2025, 2025),
  Record_Type = c(
    "Collision", "Vehicle", "Casualty",
    "Collision", "Vehicle", "Casualty"
  ),
  Rows = c(
    nrow(col24), nrow(veh24), nrow(cas24),
    nrow(col25), nrow(veh25), nrow(cas25)
  )
)

print(source_dimensions)

write.csv(
  source_dimensions,
  file.path(table_dir, "Source_Record_Counts.csv"),
  row.names = FALSE
)

saveRDS(
  list(
    col24 = col24,
    veh24 = veh24,
    cas24 = cas24,
    col25 = col25,
    veh25 = veh25,
    cas25 = cas25
  ),
  file.path(data_derived_dir, "imported_stats19_2024_2025.rds")
)

message("Data import complete.")

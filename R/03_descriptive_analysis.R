# 03_descriptive_analysis.R
# Collision-level timing, environmental, road-type, and junction summaries for 2025.

if (!exists("analysis_2025") || !exists("col25")) {
  source(file.path("R", "00_setup.R"))

  imported <- readRDS(
    file.path(data_derived_dir, "imported_stats19_2024_2025.rds")
  )

  col24 <- imported$col24
  col25 <- imported$col25

  analysis_2025 <- readRDS(
    file.path(data_derived_dir, "analysis_2025.rds")
  )
}

ksi_by_collision_2025 <- analysis_2025 %>%
  group_by(collision_index) %>%
  summarise(
    Number_of_Casualties = n(),
    KSI_Casualties = sum(KSI_num == 1, na.rm = TRUE),
    KSI_Collision = as.integer(any(KSI_num == 1)),
    .groups = "drop"
  )

collision25_plot <- col25 %>%
  left_join(
    ksi_by_collision_2025,
    by = "collision_index"
  )

if (anyNA(collision25_plot$KSI_Collision)) {
  stop("At least one 2025 collision failed to match a casualty record.")
}

overall_ksi_collision_rate <- 100 *
  mean(collision25_plot$KSI_Collision)

collision25_plot <- collision25_plot %>%
  mutate(
    hour = extract_hour(time),

    Day_of_Week = factor(
      day_of_week,
      levels = 1:7,
      labels = c(
        "Sunday", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday"
      )
    ),

    Time_Period = case_when(
      hour >= 5 & hour <= 7 ~ "Early morning (05:00–07:59)",
      hour >= 8 & hour <= 11 ~ "Morning (08:00–11:59)",
      hour >= 12 & hour <= 16 ~ "Afternoon (12:00–16:59)",
      hour >= 17 & hour <= 20 ~ "Evening (17:00–20:59)",
      hour >= 21 | hour <= 4 ~ "Night (21:00–04:59)",
      TRUE ~ NA_character_
    ),

    Time_Period = factor(
      Time_Period,
      levels = c(
        "Early morning (05:00–07:59)",
        "Morning (08:00–11:59)",
        "Afternoon (12:00–16:59)",
        "Evening (17:00–20:59)",
        "Night (21:00–04:59)"
      )
    ),

    Light_Condition = factor(
      as.character(light_conditions),
      levels = c("1", "4", "5", "6", "7", "-1"),
      labels = c(
        "Daylight",
        "Darkness – lights lit",
        "Darkness – lights unlit",
        "Darkness – no lighting",
        "Darkness – lighting unknown",
        "Missing / out of range"
      )
    ),

    Weather_Condition = factor(
      as.character(weather_conditions),
      levels = c(
        "1", "2", "3", "4", "5",
        "6", "7", "8", "9", "-1"
      ),
      labels = c(
        "Fine, no high winds",
        "Raining, no high winds",
        "Snowing, no high winds",
        "Fine + high winds",
        "Raining + high winds",
        "Snowing + high winds",
        "Fog or mist",
        "Other",
        "Unknown",
        "Missing / out of range"
      )
    ),

    Road_Surface = factor(
      as.character(road_surface_conditions),
      levels = c("1", "2", "3", "4", "5", "6", "7", "9", "-1"),
      labels = c(
        "Dry",
        "Wet or damp",
        "Snow",
        "Frost or ice",
        "Flood over 3 cm deep",
        "Oil or diesel",
        "Mud",
        "Unknown",
        "Missing / out of range"
      )
    ),

    Road_Type = factor(
      as.character(road_type),
      levels = c("1", "2", "3", "6", "7", "9", "12", "-1"),
      labels = c(
        "Roundabout",
        "One way street",
        "Dual carriageway",
        "Single carriageway",
        "Slip road",
        "Unknown",
        "One way street / Slip road",
        "Missing / out of range"
      )
    ),

    Junction_Detail = factor(
      as.character(junction_detail),
      levels = c("0", "13", "16", "17", "18", "19", "99", "-1"),
      labels = c(
        "Not at junction / within 20 m",
        "T or staggered junction",
        "Crossroads",
        "More than four arms",
        "Private drive or entrance",
        "Other junction",
        "Unknown",
        "Missing / out of range"
      )
    )
  )

# ---- Temporal summaries -----------------------------------------------------

hour_stats <- collision25_plot %>%
  filter(!is.na(hour), between(hour, 0, 23)) %>%
  group_by(hour) %>%
  summarise(
    Collisions = n(),
    KSI_Collisions = sum(KSI_Collision),
    KSI_Collision_Percent = 100 * mean(KSI_Collision),
    .groups = "drop"
  )

daypart_stats <- collision25_plot %>%
  filter(!is.na(Time_Period)) %>%
  group_by(Time_Period) %>%
  summarise(
    Collisions = n(),
    KSI_Collisions = sum(KSI_Collision),
    KSI_Collision_Percent = 100 * mean(KSI_Collision),
    .groups = "drop"
  )

day_hour_stats <- collision25_plot %>%
  filter(!is.na(hour), !is.na(Day_of_Week), between(hour, 0, 23)) %>%
  group_by(Day_of_Week, hour) %>%
  summarise(
    Collisions = n(),
    KSI_Collisions = sum(KSI_Collision),
    KSI_Collision_Percent = 100 * mean(KSI_Collision),
    .groups = "drop"
  )

# ---- Environment and road-context summaries --------------------------------

environment_summary <- function(data, variable, context_name) {
  data %>%
    filter(!is.na({{ variable }})) %>%
    group_by(Category = {{ variable }}) %>%
    summarise(
      Collisions = n(),
      KSI_Collisions = sum(KSI_Collision),
      KSI_Collision_Percent = 100 * mean(KSI_Collision),
      .groups = "drop"
    ) %>%
    mutate(Context = context_name)
}

environment_results <- bind_rows(
  environment_summary(
    collision25_plot,
    Light_Condition,
    "Light conditions"
  ),
  environment_summary(
    collision25_plot,
    Weather_Condition,
    "Weather conditions"
  ),
  environment_summary(
    collision25_plot,
    Road_Surface,
    "Road surface"
  )
)

road_context_results <- bind_rows(
  environment_summary(
    collision25_plot,
    Road_Type,
    "Road type"
  ),
  environment_summary(
    collision25_plot,
    Junction_Detail,
    "Junction type"
  )
)

environment_main <- environment_results %>%
  filter(
    !Category %in% c("Unknown", "Missing / out of range"),
    Collisions >= 100
  ) %>%
  mutate(
    Difference_pp =
      KSI_Collision_Percent - overall_ksi_collision_rate
  ) %>%
  rowwise() %>%
  mutate(
    CI = list(wilson_ci(KSI_Collisions, Collisions)),
    Lower_95 = CI$Lower,
    Upper_95 = CI$Upper
  ) %>%
  ungroup() %>%
  select(-CI)

road_main <- road_context_results %>%
  filter(
    !Category %in% c("Unknown", "Missing / out of range"),
    Collisions >= 100
  ) %>%
  mutate(
    Difference_pp =
      KSI_Collision_Percent - overall_ksi_collision_rate
  ) %>%
  rowwise() %>%
  mutate(
    CI = list(wilson_ci(KSI_Collisions, Collisions)),
    Lower_95 = CI$Lower,
    Upper_95 = CI$Upper
  ) %>%
  ungroup() %>%
  select(-CI)

# ---- Validation checks ------------------------------------------------------

surface_2024_check <- col24 %>%
  count(road_surface_conditions, sort = TRUE) %>%
  mutate(
    Percent = round(100 * n / sum(n), 3)
  )

junction_crosscheck <- collision25_plot %>%
  count(
    junction_detail,
    junction_control,
    name = "Collisions"
  ) %>%
  arrange(
    junction_detail,
    desc(Collisions)
  )

# ---- Figures ---------------------------------------------------------------

hour_figure_data <- bind_rows(
  hour_stats %>%
    transmute(
      hour,
      Metric = "Number of collisions",
      Value = Collisions
    ),
  hour_stats %>%
    transmute(
      hour,
      Metric = "Collisions with ≥1 KSI casualty (%)",
      Value = KSI_Collision_Percent
    )
)

figure2 <- ggplot(
  hour_figure_data,
  aes(x = hour, y = Value)
) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.8) +
  facet_wrap(~ Metric, scales = "free_y", ncol = 1) +
  scale_x_continuous(breaks = 0:23) +
  labs(
    title = "Hourly Distribution of Police-Reported Injury Collisions",
    subtitle = "Great Britain, 2025",
    x = "Hour of day",
    y = NULL,
    caption = paste(
      "KSI collision = collision containing at least one casualty",
      "recorded as fatal or serious."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

figure3 <- ggplot(
  day_hour_stats,
  aes(x = hour, y = Day_of_Week, fill = Collisions)
) +
  geom_tile() +
  scale_x_continuous(breaks = seq(0, 23, by = 2)) +
  labs(
    title = "When Do Injury Collisions Occur?",
    subtitle = "Collision frequency by day of week and hour, Great Britain, 2025",
    x = "Hour of day",
    y = NULL,
    fill = "Collisions"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid = element_blank(),
    plot.title = element_text(face = "bold")
  )

figure4 <- ggplot(
  environment_main,
  aes(
    x = reorder(Category, KSI_Collision_Percent),
    y = KSI_Collision_Percent
  )
) +
  geom_hline(
    yintercept = overall_ksi_collision_rate,
    linetype = "dashed",
    linewidth = 0.6
  ) +
  geom_errorbar(
    aes(ymin = Lower_95, ymax = Upper_95),
    width = 0.15
  ) +
  geom_point(
    aes(size = Collisions)
  ) +
  coord_flip() +
  facet_wrap(
    ~ Context,
    scales = "free_y",
    ncol = 1
  ) +
  scale_y_continuous(
    labels = function(x) paste0(round(x, 1), "%")
  ) +
  scale_size_continuous(
    labels = scales::label_comma()
  ) +
  labs(
    title = "KSI Collision Proportion Across Environmental Conditions",
    subtitle = "Points show observed proportions; error bars show 95% Wilson confidence intervals",
    x = NULL,
    y = "Collisions containing at least one KSI casualty (%)",
    size = "Number of\ncollisions",
    caption = paste0(
      "Great Britain, 2025. Dashed line = overall KSI-collision proportion (",
      round(overall_ksi_collision_rate, 2),
      "%). Categories with fewer than 100 collisions omitted."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold")
  )

figure5 <- ggplot(
  road_main,
  aes(
    x = reorder(Category, KSI_Collision_Percent),
    y = KSI_Collision_Percent
  )
) +
  geom_hline(
    yintercept = overall_ksi_collision_rate,
    linetype = "dashed",
    linewidth = 0.6
  ) +
  geom_errorbar(
    aes(ymin = Lower_95, ymax = Upper_95),
    width = 0.15
  ) +
  geom_point(
    aes(size = Collisions)
  ) +
  coord_flip() +
  facet_wrap(
    ~ Context,
    scales = "free_y",
    ncol = 1
  ) +
  scale_y_continuous(
    labels = function(x) paste0(round(x, 1), "%")
  ) +
  scale_size_continuous(
    labels = scales::label_comma()
  ) +
  labs(
    title = "KSI Collision Proportion Across Road and Junction Contexts",
    subtitle = "Points show observed proportions; error bars show 95% Wilson confidence intervals",
    x = NULL,
    y = "Collisions containing at least one KSI casualty (%)",
    size = "Number of\ncollisions",
    caption = paste0(
      "Great Britain, 2025. Dashed line = overall KSI-collision proportion (",
      round(overall_ksi_collision_rate, 2),
      "%)."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold")
  )

ggsave(
  file.path(figure_dir, "Figure_2_Hourly_Collision_Pattern_2025.png"),
  figure2,
  width = 9,
  height = 7,
  dpi = 400
)

ggsave(
  file.path(figure_dir, "Figure_3_Day_Hour_Collision_Heatmap_2025.png"),
  figure3,
  width = 10,
  height = 5.5,
  dpi = 400
)

ggsave(
  file.path(figure_dir, "Figure_4_Environmental_Conditions_2025.png"),
  figure4,
  width = 11,
  height = 10,
  dpi = 400
)

ggsave(
  file.path(figure_dir, "Figure_5_Road_Junction_2025.png"),
  figure5,
  width = 11,
  height = 8,
  dpi = 400
)

# ---- Tables ----------------------------------------------------------------

write.csv(
  hour_stats,
  file.path(table_dir, "Hourly_Collision_Pattern_2025.csv"),
  row.names = FALSE
)

write.csv(
  daypart_stats,
  file.path(table_dir, "Time_Period_Collision_Pattern_2025.csv"),
  row.names = FALSE
)

write.csv(
  day_hour_stats,
  file.path(table_dir, "Day_Hour_Collision_Pattern_2025.csv"),
  row.names = FALSE
)

write.csv(
  environment_main,
  file.path(table_dir, "Environmental_Conditions_2025.csv"),
  row.names = FALSE
)

write.csv(
  road_main,
  file.path(table_dir, "Road_Junction_Context_2025.csv"),
  row.names = FALSE
)

write.csv(
  surface_2024_check,
  file.path(table_dir, "Road_Surface_Code_Check_2024.csv"),
  row.names = FALSE
)

write.csv(
  junction_crosscheck,
  file.path(table_dir, "Junction_Control_Crosscheck_2025.csv"),
  row.names = FALSE
)

saveRDS(
  collision25_plot,
  file.path(data_derived_dir, "collision25_plot.rds")
)

message("Descriptive analysis complete.")

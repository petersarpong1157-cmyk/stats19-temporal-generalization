# 00_setup.R
# Project-wide setup for the STATS19 temporal-generalization analysis.

required_packages <- c(
  "tidyverse",
  "caret",
  "ranger",
  "xgboost",
  "pROC",
  "PRROC",
  "readxl"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Install required packages before continuing: ",
    paste(missing_packages, collapse = ", ")
  )
}

suppressPackageStartupMessages({
  library(tidyverse)
  library(caret)
  library(ranger)
  library(xgboost)
  library(pROC)
  library(PRROC)
  library(readxl)
})

set.seed(20261006)

data_raw_dir <- file.path("data", "raw")
data_derived_dir <- file.path("data", "derived")
model_dir <- "models"
table_dir <- file.path("outputs", "tables")
figure_dir <- file.path("outputs", "figures")
session_dir <- "session"

for (d in c(
  data_raw_dir,
  data_derived_dir,
  model_dir,
  table_dir,
  figure_dir,
  session_dir
)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

find_stats19_file <- function(record_type, year) {
  csvs <- list.files(
    data_raw_dir,
    pattern = "\\.csv$",
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (!record_type %in% c("collision", "vehicle", "casualty")) {
    stop(
      "record_type must be one of: collision, vehicle, casualty."
    )
  }

  # Match the record type only in the final filename component.
  # Every DfT filename begins with 'dft-road-casualty-statistics-',
  # so a broad grepl('casualty', filename) incorrectly matches all files.
  expected_pattern <- paste0(
    "statistics-",
    record_type,
    "-",
    year,
    "\\.csv$"
  )

  hits <- csvs[
    grepl(
      expected_pattern,
      basename(csvs),
      ignore.case = TRUE
    )
  ]

  if (length(hits) != 1) {
    stop(
      "Expected exactly one ", record_type, " CSV for ", year,
      " in ", data_raw_dir, "; found ", length(hits),
      ". Files present: ",
      paste(basename(csvs), collapse = ", ")
    )
  }

  hits
}

require_columns <- function(data, required, object_name) {
  missing <- setdiff(required, names(data))

  if (length(missing) > 0) {
    stop(
      object_name,
      " is missing required columns: ",
      paste(missing, collapse = ", ")
    )
  }

  invisible(TRUE)
}

parse_stats19_date <- function(x) {
  x_chr <- as.character(x)

  parsed <- as.Date(
    x_chr,
    tryFormats = c("%d/%m/%Y", "%Y-%m-%d")
  )

  parsed
}

extract_hour <- function(x) {
  suppressWarnings(
    as.integer(
      substr(as.character(x), 1, 2)
    )
  )
}

safe_roc_auc <- function(y, p) {
  if (length(unique(y)) < 2) return(NA_real_)

  as.numeric(
    pROC::auc(
      pROC::roc(
        response = y,
        predictor = p,
        levels = c(0, 1),
        direction = "<",
        quiet = TRUE
      )
    )
  )
}

safe_pr_auc <- function(y, p) {
  if (sum(y == 1, na.rm = TRUE) == 0 ||
      sum(y == 0, na.rm = TRUE) == 0) {
    return(NA_real_)
  }

  PRROC::pr.curve(
    scores.class0 = p[y == 1],
    scores.class1 = p[y == 0],
    curve = FALSE
  )$auc.integral
}

wilson_ci <- function(x, n, z = 1.96) {
  p <- x / n
  denominator <- 1 + (z^2 / n)

  centre <- (
    p + (z^2 / (2 * n))
  ) / denominator

  half_width <- (
    z *
      sqrt(
        (p * (1 - p) / n) +
          (z^2 / (4 * n^2))
      )
  ) / denominator

  tibble(
    Lower = 100 * (centre - half_width),
    Upper = 100 * (centre + half_width)
  )
}

message("Setup complete.")

# Reproducibility audit

This repository was audited against the six official STATS19 CSV files used in the analysis and the 2025 Road Safety Open Dataset Data Guide.

## Source files checked

- 2024 collision: 100,927 rows
- 2024 vehicle: 183,514 rows
- 2024 casualty: 128,272 rows
- 2025 collision: 101,525 rows
- 2025 vehicle: 183,948 rows
- 2025 casualty: 127,883 rows

## Schema and linkage checks

The source headers were checked directly against the import and linkage scripts.

Two repository issues were identified and corrected during the audit:

1. the public collision files contain `pedestrian_crossing`, not `pedestrian_crossing_physical_facilities`;
2. the original file-discovery helper matched the substring `casualty` too broadly because every DfT filename begins with `dft-road-casualty-statistics-`. The helper now matches the record type at the end of the filename.

`collision_index` is now forced to character during import so that linkage is stable across readers and across all six files.

With linkage keys treated consistently:

- collision identifiers are unique in each collision file;
- `collision_index + vehicle_reference` is unique in each vehicle file;
- `collision_index + casualty_reference` is unique in each casualty file;
- no casualty record is unmatched to its collision;
- no casualty record is unmatched to its associated vehicle.

## Clean-run verification completed so far

A clean local checkout of the public repository has now successfully executed:

- `R/00_setup.R`
- `R/01_data_import.R`
- `R/02_data_linkage_cleaning.R`

against fresh copies of the six source CSV files placed in `data/raw/`.

The clean run reproduced the expected source dimensions exactly:

| Year | Record type | Rows |
|---|---|---:|
| 2024 | Collision | 100,927 |
| 2024 | Vehicle | 183,514 |
| 2024 | Casualty | 128,272 |
| 2025 | Collision | 101,525 |
| 2025 | Vehicle | 183,948 |
| 2025 | Casualty | 127,883 |

The linkage/feature-construction stage also reproduced:

- 2024 casualties: 128,272
- 2024 recorded KSI: 27,642
- 2024 recorded KSI prevalence: approximately 0.215
- 2025 casualties: 127,883
- 2025 recorded KSI: 29,296
- 2025 recorded KSI prevalence: approximately 0.229

This verifies the public repository through data import, linkage, outcome construction, and primary feature preparation. The modelling, SHAP, bootstrap, and final-output stages still require clean-run verification before a release is tagged.

## Outcome checks

Raw casualty-severity counts used by the analysis were verified as:

| Year | Fatal | Serious | Slight | Recorded KSI |
|---|---:|---:|---:|---:|
| 2024 | 1,602 | 26,040 | 100,630 | 27,642 |
| 2025 | 1,538 | 27,758 | 98,587 | 29,296 |

The manuscript and repository intentionally distinguish these individual-record KSI values from DfT's severity-adjusted national KSI series.

## Temporal compatibility of primary predictors

No 2025 categorical level absent from 2024 was found for the primary categorical predictors:

- casualty class
- casualty sex
- casualty age band
- casualty type
- day of week
- road type
- speed limit
- light conditions
- weather conditions
- urban/rural area
- vehicle type
- driver sex
- driver age band

## Variables excluded for temporal data-quality reasons

Two fields were checked specifically because of strong year-to-year availability changes:

- `age_of_vehicle`: every 2025 vehicle record is coded `-1`; this field is excluded from the primary model.
- `special_conditions_at_site`: the `-1` category accounts for about 58.8% of 2024 collision records and 86.5% of 2025 collision records; this field is excluded from the primary model.

Severity-derived fields such as `collision_severity`, enhanced severity, and adjusted severity are also excluded from predictors to avoid target leakage.

## Data-guide note: casualty type 23 vs 33

The 2025 data guide contains an internal inconsistency in the `2024_code_list` sheet: casualty type code 23 appears for both:

- Electric motorcycle rider or passenger
- Personal Powered Transporter

The guide's `2011_to_2024_conversion` sheet instead maps Personal Powered Transporter to code **33**, and the 2025 casualty data contain code 33.

For this repository, labels are therefore handled as:

- 23 = Electric motorcycle rider/passenger
- 33 = Personal Powered Transporter rider

This decision is documented rather than silently inferred.

## Road-surface categories

Codes 6 (Oil or diesel) and 7 (Mud) are absent from both the 2024 and 2025 collision files used in the study. They are not reported as zero-risk categories.

## Validation status

The repository includes a GitHub Actions syntax-check workflow and a complete `R/run_all.R` driver.

The import and linkage stages have now passed a clean-run test. The remaining reproducibility work is to execute the descriptive, model-development, temporal-validation, subgroup, SHAP, bootstrap, and final-output scripts from the same clean checkout and confirm that they reproduce the manuscript audit values.

Final release status should not be assigned until that full clean run succeeds.

## Audit principle

This audit documents source-file structure, linkage behavior, coding decisions, and known data-quality constraints. It does not convert predictive or SHAP results into causal claims.

# Data

Raw Department for Transport STATS19 data are not redistributed here.

## Required files

Download the final **2024** and **2025** versions of all three STATS19 record types:

- collision
- vehicle
- casualty

Source: https://www.gov.uk/government/statistical-data-sets/road-safety-open-data

Place all six CSV files in:

```text
data/raw/
```

The analysis also uses the official road-safety open-dataset data guide to interpret coded categorical values. Keep the guide outside version control or place it in a local reference folder if desired.

## Expected source structure verified during development

| Year | Collision records | Vehicle records | Casualty records |
|---|---:|---:|---:|
| 2024 | 100,927 | 183,514 | 128,272 |
| 2025 | 101,525 | 183,948 | 127,883 |

The scripts stop if required fields are missing or if a casualty fails to match a collision or associated vehicle.

## Data policy

Do not commit raw CSV files to this repository. The public source should remain the authoritative distribution point.

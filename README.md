# Temporal Generalization, Calibration, and Road-User Heterogeneity in STATS19 Injury-Severity Models

Reproducible R analysis for a manuscript studying casualty-level killed-or-seriously-injured (KSI) prediction in Great Britain using final 2024 and 2025 Department for Transport STATS19 data.

## Research question

How accurately can statistical and machine-learning models classify KSI outcomes among police-recorded road casualties, which road-user, vehicle, temporal, and traffic-environment characteristics contribute to those predictions, and how well do the models generalize from 2024 to 2025?

## Study design

- **Development year:** 2024
- **Temporal test year:** 2025
- **Unit of analysis:** casualty
- **2024 casualty records:** 128,272
- **2025 casualty records:** 127,883
- **Primary outcome:** recorded fatal or serious casualty vs slight casualty
- **Validation:** five-fold cross-validation grouped by `collision_index`
- **Models:** logistic regression, Random Forest, XGBoost
- **Uncertainty:** paired collision-level bootstrap
- **Interpretability:** grouped SHAP analysis
- **Heterogeneity:** casualty class, age, speed-limit environment, road type, urban/rural context, and road-user-specific SHAP structure

The 2025 data are kept out of model fitting, hyperparameter selection, and probability-threshold selection. Schema and data-availability checks are documented separately in `AUDIT.md`.

## Verified headline results

| Model | 2024 grouped CV ROC-AUC | 2025 ROC-AUC | 2025 PR-AUC | 2025 Brier |
|---|---:|---:|---:|---:|
| Logistic regression | 0.697 | 0.695 | 0.413 | 0.160 |
| Random Forest | 0.701 | 0.699 | 0.417 | 0.160 |
| XGBoost | **0.706** | **0.702** | **0.422** | **0.159** |

For XGBoost, the 2025 calibration intercept was approximately 0.057 and the calibration slope approximately 1.01. A threshold selected exclusively from 2024 out-of-fold predictions (0.2186) yielded 2025 sensitivity 65.4%, specificity 63.4%, precision 34.7%, negative predictive value 86.1%, and balanced accuracy 64.4%.

These results are predictive, not causal.

## Repository structure

```text
.
├── .github/
│   └── workflows/
│       └── r-syntax.yml
├── R/
│   ├── 00_setup.R
│   ├── 01_data_import.R
│   ├── 02_data_linkage_cleaning.R
│   ├── 03_descriptive_analysis.R
│   ├── 04_model_development.R
│   ├── 05_temporal_validation.R
│   ├── 06_subgroup_analysis.R
│   ├── 07_shap_analysis.R
│   ├── 08_bootstrap_uncertainty.R
│   ├── 09_final_tables_figures.R
│   └── run_all.R
├── data/
│   ├── raw/
│   ├── derived/
│   └── README.md
├── manuscript/
│   └── README.md
├── models/
├── outputs/
│   ├── tables/
│   ├── figures/
│   └── README.md
├── session/
│   └── README.md
├── .gitignore
├── AUDIT.md
├── CITATION.cff
└── stats19-temporal-generalization.Rproj
```

## Data

Raw STATS19 files are **not redistributed in this repository**. Download the final 2024 and 2025 collision, vehicle, and casualty CSV files from the UK Department for Transport Road Safety Open Data collection:

https://www.gov.uk/government/statistical-data-sets/road-safety-open-data

Place the six CSV files in `data/raw/`. The import script identifies files by year and record type, so the downloaded filenames can be retained.

The official 2025 road-safety open-dataset data guide is used for categorical labels. A coding inconsistency involving casualty-type codes 23 and 33, and the rule used in this analysis, are documented in `AUDIT.md`.

## Reproducibility

The simplest route is:

```r
source("R/run_all.R")
```

Alternatively, run the numbered scripts in order:

```r
source("R/00_setup.R")
source("R/01_data_import.R")
source("R/02_data_linkage_cleaning.R")
source("R/03_descriptive_analysis.R")
source("R/04_model_development.R")
source("R/05_temporal_validation.R")
source("R/06_subgroup_analysis.R")
source("R/07_shap_analysis.R")
source("R/08_bootstrap_uncertainty.R")
source("R/09_final_tables_figures.R")
```

Model fitting, SHAP calculation, and the collision-level bootstrap can take substantial time.

The complete workflow has been clean-run verified end to end from the six raw STATS19 CSV files through model fitting, temporal validation, subgroup analysis, SHAP, the 500-replicate collision-level bootstrap, and final publication outputs. The verified run reproduced `outputs/tables/Manuscript_Numerical_Audit.csv` and the manuscript headline values. See `AUDIT.md` for details and non-fatal warnings observed during the run.

## Reproducibility audit

The source CSV schemas, record counts, linkage keys, outcome counts, temporal category compatibility, selected data-guide coding decisions, model-development workflow, temporal validation, subgroup analyses, SHAP calculations, bootstrap uncertainty analysis, and final-output generation have been checked against the exact files used to develop the manuscript.

See **[AUDIT.md](AUDIT.md)** for the audit record.

The audit found and corrected one repository schema error before release preparation: the current 2024/2025 collision files use `pedestrian_crossing`, not `pedestrian_crossing_physical_facilities`. The import now also forces `collision_index` to character to avoid inconsistent key inference across readers.

## Important interpretation notes

1. STATS19 contains police-reported personal-injury collisions on public roads; it does not represent every road collision in Great Britain.
2. The primary outcome uses the individual recorded `casualty_severity` field. It is not the Department for Transport's severity-adjusted national KSI series.
3. The model predicts severity **conditional on a casualty being present in STATS19**. It does not estimate exposure-adjusted crash risk or crash occurrence.
4. SHAP values describe the fitted prediction model and must not be interpreted as causal effects.
5. Collision-level descriptive KSI proportions are unadjusted comparisons.

## Continuous checks

A GitHub Actions workflow parses every R script after code changes. This is a syntax check, not a substitute for the full data-dependent reproducibility run.

## Citation

Citation metadata are provided in `CITATION.cff`. A DOI will be added only if the repository is archived in a DOI-issuing service.

## Manuscript status

Manuscript in preparation. The working manuscript file is intentionally not committed here until the author chooses to make it public.

## License

No software/content license has been selected yet. A license should be chosen before public reuse is invited.

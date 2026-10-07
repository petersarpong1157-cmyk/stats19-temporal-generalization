# Clean-run reproducibility checklist

Use this checklist before tagging a release or archiving the repository.

## 1. Start from a clean clone

Clone the public repository into a new directory. Do not reuse objects from the manuscript-development R session.

## 2. Download the six official source CSV files

Place the final 2024 and 2025 collision, vehicle, and casualty files in:

```text
data/raw/
```

Do not rename columns or pre-process the files manually.

## 3. Install required R packages

The setup script checks for:

- tidyverse
- caret
- ranger
- xgboost
- pROC
- PRROC
- readxl

Do not create an `renv.lock` file until the workflow has been run successfully from a clean environment and the package versions used for the verified run are known.

## 4. Run the full workflow

From the repository root:

```r
source("R/run_all.R")
```

For a faster development-only bootstrap check, an environment variable can temporarily reduce the number of replicates, for example:

```r
Sys.setenv(STATS19_BOOTSTRAP_B = 50)
source("R/run_all.R")
```

For the manuscript release, use the default 500-replicate bootstrap or the final number stated in the manuscript.

## 5. Verify source-file counts

Expected record counts:

| Year | Collision | Vehicle | Casualty |
|---|---:|---:|---:|
| 2024 | 100,927 | 183,514 | 128,272 |
| 2025 | 101,525 | 183,948 | 127,883 |

The linkage script should report no duplicate linkage keys and no unmatched casualty-to-collision or casualty-to-vehicle records.

## 6. Verify the recorded KSI outcome

Expected raw casualty-severity totals:

| Year | Fatal | Serious | Slight | Recorded KSI |
|---|---:|---:|---:|---:|
| 2024 | 1,602 | 26,040 | 100,630 | 27,642 |
| 2025 | 1,538 | 27,758 | 98,587 | 29,296 |

Expected recorded KSI prevalence:

- 2024: approximately 0.2155
- 2025: approximately 0.2291

## 7. Verify grouped cross-validation

The grouped-CV audit should show:

- 5 folds
- zero collision overlap in every fold
- approximately 25,500 validation casualties per fold

Expected selected 2024 ROC-AUC values are approximately:

- Logistic regression: 0.6968
- Random Forest: 0.7013
- XGBoost: 0.7056

Selected Random Forest specification:

- mtry = 9
- splitrule = gini
- min.node.size = 100
- 500 trees

Selected XGBoost specification:

- nrounds = 600
- max_depth = 3
- eta = 0.05
- gamma = 0
- colsample_bytree = 0.8
- min_child_weight = 5
- subsample = 0.8

## 8. Verify untouched 2025 temporal performance

Expected point estimates are approximately:

| Model | ROC-AUC | PR-AUC | Brier |
|---|---:|---:|---:|
| Logistic regression | 0.6947 | 0.4129 | 0.1604 |
| Random Forest | 0.6990 | 0.4174 | 0.1598 |
| XGBoost | 0.7019 | 0.4217 | 0.1592 |

Expected XGBoost calibration:

- intercept: approximately 0.0566
- slope: approximately 1.01

## 9. Verify the locked threshold

Expected 2024 out-of-fold Youden threshold:

- approximately 0.2186

Expected 2025 performance at that unchanged threshold:

- sensitivity: approximately 0.654
- specificity: approximately 0.634
- precision: approximately 0.347
- NPV: approximately 0.861
- balanced accuracy: approximately 0.644

## 10. Verify SHAP matrix construction

Expected checks:

- XGBoost encoded feature count: 112
- reconstructed 2025 model matrix: 127,883 × 112
- exact column-name identity with fitted XGBoost feature names
- SHAP sample size: 50,000
- SHAP sample KSI prevalence: approximately 0.2291
- conceptual grouped SHAP matrix: 50,000 × 16

The strongest global grouped SHAP contribution should be `casualty_type`, followed by predictors including number of vehicles, casualty age band, speed limit, road type, and time of day.

## 11. Verify robustness model

Removing `casualty_type` should leave performance nearly unchanged.

Expected 2024 grouped CV ROC-AUC:

- approximately 0.7055

Expected 2025 performance:

- ROC-AUC approximately 0.702
- PR-AUC approximately 0.420
- Brier approximately 0.159

## 12. Verify bootstrap comparison

With 500 collision-level bootstrap replicates, expected paired differences are approximately:

- XGBoost − Logistic ROC-AUC: +0.0072
- XGBoost − Random Forest ROC-AUC: +0.0029
- XGBoost − Logistic PR-AUC: +0.0089
- XGBoost − Random Forest PR-AUC: +0.0043

The previously observed 95% percentile intervals excluded zero for all four differences.

Because bootstrap estimates depend on the fixed repository seed, a clean run should be reproducible under compatible package versions.

## 13. Inspect final audit file

Review:

```text
outputs/tables/Manuscript_Numerical_Audit.csv
```

Do not tag a release if the values materially disagree with the manuscript.

## 14. Archive the environment

After the successful clean run:

1. retain `session/sessionInfo.txt`;
2. record the operating system and R version;
3. create an `renv.lock` file from the verified environment if desired;
4. commit selected publication tables and figures;
5. tag the release only after the manuscript-number audit passes.

## 15. Release rule

A public repository is not automatically a reproducible release. The release should be tagged only after the complete clean run succeeds using the public code and freshly downloaded source files.

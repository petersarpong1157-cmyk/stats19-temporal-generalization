# v3.2.6 — Verified STATS19 Temporal Generalization Analysis

This release provides the verified reproducible R workflow for casualty-level KSI prediction and temporal generalization analysis using final 2024 and 2025 Great Britain STATS19 data.

## Reproducibility status

The full workflow was clean-run verified end to end from the six raw STATS19 CSV files through:

- data import and linkage;
- descriptive analysis;
- five-fold grouped cross-validation by collision;
- logistic regression, Random Forest, and XGBoost model development;
- untouched 2025 temporal validation;
- calibration and locked-threshold transfer;
- subgroup performance analysis;
- grouped SHAP interpretation;
- reduced-model robustness analysis;
- 500-replicate paired collision-level bootstrap;
- final publication tables, figures, numerical audit, and session information.

## Verified headline results

- XGBoost 2024 grouped-CV ROC-AUC: 0.70559265
- XGBoost 2025 ROC-AUC: 0.70192661
- XGBoost 2025 PR-AUC: 0.42174420
- XGBoost 2025 Brier score: 0.15917844
- Calibration intercept: 0.056578325
- Calibration slope: 1.0119602
- Locked 2024 OOF threshold: 0.21857471
- 2025 sensitivity at locked threshold: 0.65387766
- 2025 specificity at locked threshold: 0.63445485

## Included publication artifacts

- manuscript numerical audit table;
- study-design figure;
- 2025 model-performance figure;
- global grouped SHAP figure;
- within-road-user grouped SHAP figure.

## Data

Raw STATS19 files are not redistributed. Users should download the final 2024 and 2025 collision, vehicle, and casualty CSV files from the UK Department for Transport Road Safety Open Data collection and place them in `data/raw/`.

## Manuscript

The working manuscript remains private and is not included in this release.

## License

Repository code is released under the MIT License.

## Important interpretation note

The models are predictive, not causal. SHAP values describe the fitted prediction model and should not be interpreted as causal effects.

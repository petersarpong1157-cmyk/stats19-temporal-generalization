# Verified analysis environment

The full end-to-end clean run was completed successfully on **2026-10-08** using the public repository code and the six raw 2024/2025 STATS19 CSV files.

## Core recorded versions

- R 4.5.2 (2025-10-31 ucrt)
- caret 7.0-1
- xgboost 1.7.11.1
- ranger 0.18.0
- pROC 1.19.0.1
- dplyr 1.2.1
- Matrix 1.7-4

The workflow-generated `session/sessionInfo.txt` should be retained with any formal release because it provides the broader package/session record from the verified run.

## Verification status

The verified clean run executed:

```r
source("R/run_all.R")
```

from raw inputs through:

- data import and linkage;
- descriptive analysis;
- grouped model development;
- untouched 2025 temporal validation;
- subgroup analysis;
- grouped SHAP analysis;
- reduced-model robustness analysis;
- 500-replicate paired collision-level bootstrap;
- final tables, figures, numerical audit, and session information.

The final numerical audit reproduced the manuscript headline values.

## Non-fatal warnings observed

The verified run emitted warnings associated with:

- rank-deficient logistic-regression prediction fits;
- `UseMethod("depth")` on a NULL object after completed computations.

These warnings did not stop the workflow and did not prevent reproduction of the verified outputs. They are retained in `AUDIT.md` for transparency.

## Dependency freezing

No hand-written `renv.lock` is committed. If the author chooses to freeze the environment for a formal release, generate the lockfile from the verified local R installation rather than reconstructing dependency versions manually.

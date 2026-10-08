# Release preparation checklist

The analysis workflow has passed a full end-to-end clean run. This file tracks the remaining decisions before creating a formal tagged release or DOI archive.

## Completed

- [x] Public repository created.
- [x] Raw-data redistribution excluded.
- [x] File discovery and schema issues corrected.
- [x] Factor-level ordering made explicit for reproducible XGBoost encoding.
- [x] Grouped cross-validation checked for zero collision overlap.
- [x] 2025 temporal validation reproduced.
- [x] Locked 2024 threshold reproduced.
- [x] Subgroup analyses reproduced.
- [x] Grouped SHAP and robustness analyses reproduced.
- [x] 500-replicate collision-level bootstrap reproduced.
- [x] Final tables and figures regenerated successfully.
- [x] Numerical manuscript audit reproduced.
- [x] Session information generated.
- [x] End-to-end `R/run_all.R` clean run completed.
- [x] R syntax-check workflow verified successful for the current analysis-code series.
- [x] Citation metadata includes the author ORCID.

## Decisions still required before a formal release

- [ ] Choose a repository license. No license has been selected automatically.
- [ ] Decide whether selected generated tables/figures should be committed.
- [ ] Decide whether the working manuscript should remain private or be included.
- [ ] Optionally generate `renv.lock` from the verified local R environment.
- [ ] Choose a release version/tag, for example `v1.0.0`.
- [ ] If desired, archive the tagged release with a DOI-issuing service and then add the DOI to `CITATION.cff`.
- [ ] Update manuscript Data/Code Availability text with the final tagged release and DOI, if one is created.

Do not add a license, publish the manuscript, create a formal tag, or claim a DOI until the author explicitly chooses those items.

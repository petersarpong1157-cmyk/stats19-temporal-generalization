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

## Published release

- [x] GitHub release `v3.2.6` published on 2026-10-08.
- [x] Release marked as the latest release.
- [x] Working manuscript excluded from the release.
- [x] Zenodo DOI `10.5281/zenodo.23240708` minted for the release.

## Remaining post-release decisions

- [x] Choose a repository license: MIT License.
- [x] Decide whether selected generated tables/figures should be committed: yes.
- [x] Commit exact selected PNG outputs from the verified clean run (Figure 1, Figure 6, Figure 8, Figure 9).
- [x] Working manuscript will remain private and will not be included in the repository.
- [ ] Optionally generate `renv.lock` from the verified local R environment.
- [x] Release version/tag chosen and published: `v3.2.6`.
- [x] Archive tagged release with Zenodo. DOI: `10.5281/zenodo.23240708`.
- [x] Update the private manuscript Data/Code Availability text with release `v3.2.6` and DOI `10.5281/zenodo.23240708`.

Do not publish the manuscript, create a formal tag, or claim a DOI until the author explicitly chooses those items.

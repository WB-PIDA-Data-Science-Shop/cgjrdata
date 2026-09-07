# `data-raw/source/`

| Script | Reads | Produces |
|---|---|---|
| `00a-prepare-country-list.R` | `../input/CLASS_2025_10_07.xlsx` | `wbcountries` |
| `00b-cgjr-taxonomy-crosswalk.R` | `../input/cgjr_taxonomy.csv`, `../input/cgjr_crosswalk.csv` | `cgjr_taxonomy`, `cgjr_crosswalk` |

`analysis/00-build_all_datasets.r` runs both.
`analysis/01-build-tidy-data.R` then builds the three long tibbles
(`cgjr_ctf`, `cgjr_scores`, `cgjr_raw`) from `cgjr_crosswalk` + live
`cliaretl` via `build_ctf_tbl()` / `roll_up_scores()` / `build_raw_tbl()` /
`aggregate_to_groups()`.

## Editing the taxonomy

The taxonomy and each indicator's placement in it are the two CSV files in
`data-raw/input/`. **Edit those**, not any R code — in Google Sheets or a
CSV-aware editor. Avoid Excel (it coerces codes to dates, strips leading
zeros, and mangles UTF-8).

`00b-...R` reads them with an explicit column spec, runs
`check_crosswalk_schema()` (structure — hard `stop()` on any violation), then
annotates the crosswalk with `build_crosswalk()` (taxonomy names/numbers +
`cliaretl` catalogue metadata + eligibility flags), prints an eligibility
summary via `validate_crosswalk()`, and saves the two `.rda` objects. It
writes no output CSV.

Re-run both `analysis/` scripts after editing to propagate changes through
`cgjr_ctf` / `cgjr_scores` / `cgjr_raw`.

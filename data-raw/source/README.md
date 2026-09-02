# `data-raw/source/`

| Script | Reads | Produces |
|---|---|---|
| `00a-prepare-country-list.R` | `../input/CLASS_2025_10_07.xlsx` | `wbcountries` |
| `00b-cgjr-taxonomy-crosswalk.R` | `../crosswalk/cgjr_taxonomy.csv`, `../crosswalk/cgjr_crosswalk.csv` | `cgjr_taxonomy`, `cgjr_crosswalk` (+ `../output/cgjr_crosswalk_validation.csv`) |

`analysis/00-build_all_datasets.r` runs both. `analysis/01-combine-lazyload.R`
then builds every other lazyloaded object directly from `cgjr_crosswalk` via
`build_rawdata_list()` / `build_ctfdata_list()` / `build_metadata_tbl()`.

## Editing the taxonomy

The taxonomy and each indicator's placement in it are the two CSV files in
`data-raw/crosswalk/`. **Edit those**, not any R code — in Google Sheets or a
CSV-aware editor. Avoid Excel (it coerces codes to dates, strips leading
zeros, and mangles UTF-8).

`00b-...R` reads them with an explicit column spec, runs
`check_crosswalk_schema()` (structure) then `validate_crosswalk()` (codes vs
live `cliaretl`), and saves the `.rda` objects. Re-run the two `analysis/`
scripts afterwards to propagate changes into the rest of the package data.

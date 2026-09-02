# `data-raw/source/`

| Script | Produces |
|---|---|
| `00a-prepare-country-list.R` | `wbcountries` |
| `00b-cgjr-taxonomy-crosswalk.R` | `cgjr_taxonomy`, `cgjr_crosswalk` (+ `../output/cgjr_crosswalk_validation.csv`) |

`analysis/00-build_all_datasets.r` runs both. `analysis/01-combine-lazyload.R`
then builds every other lazyloaded object directly from `cgjr_crosswalk` via
`build_rawdata_list()` / `build_ctfdata_list()` / `build_metadata_tbl()`.
The taxonomy and each indicator's placement in it are defined entirely by
`00b-cgjr-taxonomy-crosswalk.R` — there are no per-subcluster scripts.

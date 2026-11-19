# cgjrdata — simplification plan and record

Rebuild cgjrdata as a thin mapping from the CGJR taxonomy onto `cliaretl`:
one build script, five small tested functions, and contract tests on the
shipped data. Supersedes the 2026-09 "tidy-tibble rewrite" (crosswalk
classification, `cgjr_scores` rollup, region / income-group aggregates).

Status (2026-11-19): **Part 1 complete** (cgjrdata). Part 2 (cgjrapp) next.

---

## 1. Decisions

| # | Decision | Why |
|---|---|---|
| 1 | Drop `cgjr_scores`. | cgjrapp never reads it; it computes every composite live. |
| 2 | Drop region / income-group rows from `cgjr_ctf`. | cgjrapp only used them to fill the group pickers, then expanded each group to its member countries. Groups now come from `wbcountries`. |
| 3 | `cgjr_ctf` / `cgjr_raw` hold real countries only (`wbcountries`). | 17 World Bank aggregates leaked in as "countries"; cgjrapp filtered them out with `cliaretl::wb_country_list`. |
| 4 | Respect CLIAR's benchmarking flags: dynamic needs `benchmark_dynamic_indicator == "Yes"`, static needs `benchmarked_ctf == "Yes"`, on top of being a panel column. | A shared indicator must look identical in the CLIAR app and cgjrapp. Both panels carry 23–30 columns CLIAR does not flag. |
| 5 | CTF values are copied unchanged, never clipped. | Same reason as 4. Dynamic values can fall just outside [0, 1] (`cliaretl` behaviour). |
| 6 | A variable may sit on several leaves (one row per leaf). | Methodology may reuse an indicator. |
| 7 | Variables need not come from `cliaretl`. Missing catalogue entry, CTF values or raw dataset is a warning, not an error. | Future indicators may be sourced elsewhere. |
| 8 | Raw values are located by column name across an ordered list of `cliaretl` datasets, not by `etl_source`. | `etl_source` is wrong for some variables (SPI says `wdi`; five `wb_api` variables moved to their own datasets in 0.2.6). |
| 9 | `cgjr_raw` keeps observed values only. | 84% of the old rows were `NA` from wide joins. `cgjr_ctf` keeps its `NA` rows: cgjrapp's missing-for-base screen needs them. |
| 10 | Country names come from `wbcountries$economy`. | One name source; fixes `NA` names for CUB / PRK. |
| 11 | `cliaretl` moves to `Suggests`. | Installing cgjrdata (and so cgjrapp) no longer installs `cliaretl`. |

## 2. Shape of the package

- `data-raw/cgjr.R` builds `cgjr_taxonomy`, `cgjr_crosswalk`, `cgjr_ctf`,
  `cgjr_raw`; `data-raw/wbcountries.R` builds `wbcountries`.
- `R/`: `check_cgjr_mapping()`, `flag_ctf_eligibility()`,
  `locate_raw_variables()`, `pivot_wide_to_long_cgjr()`,
  `check_duplicate_obs()`, plus `data.R`. Checks print a green ✔ on pass,
  stop with a red ✖ or warn with ! on fail.
- `tests/testthat/test-data.R`: contract tests on the shipped data, including
  cell-by-cell equality with `cliaretl` (skipped when the installed
  `cliaretl` differs from `attr(cgjr_ctf, "cliaretl_version")`).

## 3. Verification

- On `cliaretl` 0.2.5 the new build reproduced the old one exactly: all
  239,112 real-country CTF rows and 264,619 observed raw rows, zero value
  differences. Differences were only the intended ones (decisions 2, 3, 9,
  10, plus the two SPI variables the old build missed).
- Rebuilt on `cliaretl` 0.2.6 (`87eed34`): 58 tests pass, `R CMD check`
  0/0/0.

## 4. Open items

**cgjrapp (Part 2)**
- Build the Regions / Income groups pickers from `wbcountries`; drop the
  aggregate filter (`.country_codes()`), the `cgjr_raw` phantom-row filter
  and the income-group slug workaround.
- Remove `cliaretl` from cgjrapp's `Imports`; bump its lockfile.
- Year slider is hard-coded to 2013–2024 (`.YEAR_MIN` / `.YEAR_MAX`,
  `report_evidence.R`); 0.2.6 data run to 2025. Derive the range from
  `cgjr_ctf`.
- Update the app's schema test, which still expects `cgjr_scores`.

**Upstream in `cliaretl`**
- Dynamic CTF values outside [0, 1] at the window edges (44 cells for CGJR
  variables in 0.2.6, years 2013, 2024 and 2025).
- `etl_source` does not match the dataset holding the variable for the two
  SPI variables (`wdi`, but in `spi`).
- 0.2.5's dynamic panel carried a 2026 year; fixed in 0.2.6 (2025).

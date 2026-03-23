# Context for `cgjrapp` — Shiny Dashboard Development

> **Generated:** 2026-03-23  
> **Source package:** `cgjrdata` (R package, `~/GitProjects/cgjrdata`)  
> **Destination app:** `cgjrapp` (Shiny dashboard, to be created)  
> **Purpose:** Full context briefing for an AI agent developing `cgjrapp` from scratch.

---

## 1. Project Overview

The **Country Jobs and Growth Report (CGJR)** is a World Bank analytical framework that assesses the quality of a country's institutional and policy environment relevant to jobs and growth. The assessment covers 135 indicators grouped into **4 clusters** and **13 subclusters**.

The data preparation pipeline is the R package **`cgjrdata`**. It:
1. Pulls indicator data from the `cliaretl` package (a separate internal WB data package)
2. Processes and organises it into structured nested lists
3. Computes Closeness-to-Frontier (CTF) subcluster, cluster, and overall scores
4. Exposes everything as lazyloaded package objects for consumption by the Shiny app

The Shiny app **`cgjrapp`** will consume these objects to build an interactive dashboard showing country performance across the CGJR framework.

---

## 2. Analytical Framework — Clusters and Subclusters

The framework has 4 clusters, each with subclusters (13 total). These map directly to the nested list keys used throughout `cgjrdata`.

| Cluster (key) | # | Subcluster (key) | # indicators |
|---|---|---|---|
| `institutional_environment` | 1 | `degree_of_integrity` | 5 |
| | | `transparency_and_accountability` | 5 |
| | | `justice_and_rule_of_law` | 14 |
| | | `social_cohesion_norms_and_cooperation` | 7 |
| `political_institutions` | 2 | `political_institutions` | 20 |
| `center_of_government` | 3 | `public_financial_management` | 27 |
| | | `public_sector_hrm` | 12 |
| | | `digital_and_data` | 9 |
| `sectors_service_delivery` | 4 | `business_environment` | 13 |
| | | `service_delivery` | 5 |
| | | `soe_corporate_governance` | 5 |
| | | `labor_and_social_protection` | 9 |
| | | `energy_and_environment` | 16 |

All keys are **snake_case**. They are used as-is when accessing lists:
```r
ctfdata_list$institutional_environment$degree_of_integrity
rawdata_list$sectors_service_delivery$energy_and_environment
```

---

## 3. Source Data — `cliaretl` Package

`cgjrdata` imports from `cliaretl`, a separate internal R package. The key datasets are:

| Object | Description | Key columns |
|---|---|---|
| `cliaretl::db_variables_final` | Variable catalogue (440 rows × 17 cols) | `variable`, `etl_source`, `cluster`, `subcluster`, `family_name`, `description`, `source` |
| `cliaretl::closeness_to_frontier_dynamic` | CTF dynamic panel (2796 × 118) | `country_code`, `country_name`, `year` + 115 indicator cols |
| `cliaretl::closeness_to_frontier_static` | CTF static cross-section | `country_code`, `country_name` + indicator cols |
| `cliaretl::wb_country_list` | Country metadata | `country_code`, `country_name` — **has duplicate `country_code` rows**, always use `distinct(country_code, .keep_all = TRUE)` before joining |
| `cliaretl::d360_efi_data` | WB API / D360 raw data | `etl_source = "wb_api"` |
| `cliaretl::vdem_data` | V-Dem raw | `etl_source = "vdem"` |
| `cliaretl::wdi_indicators` | WDI raw | `etl_source = "wdi"` |
| `cliaretl::pefa_assessments` | PEFA raw | `etl_source = "pefa"` |
| `cliaretl::fraser` | Fraser Institute | `etl_source = "fraser"` |
| `cliaretl::heritage` | Heritage Foundation | `etl_source = "heritage"` |
| `cliaretl::gfdb` | Global Findex / debt | `etl_source = "gfdb"` |
| `cliaretl::romelli` | Romelli CBI dataset | `etl_source = "romelli"` |
| `cliaretl::debt_transparency` | Debt transparency index | `etl_source = "debt_transparency"` |
| `cliaretl::epl` | OECD EPL | `etl_source = "oecd_epl"` |
| `cliaretl::pmr` | OECD PMR | `etl_source = "oecd_pmr"` |
| `cliaretl::wbl_data` | WBL data | `etl_source = "wb_wbl"` |

**RISE energy data** is stored locally (not in `cliaretl`) at:
`data-raw/input/RISE_20102021.dta` — read with `haven::read_dta()`, columns are **uppercase** and must be lowercased with `rename_with(tolower)`. This covers 140 countries × 12 years (2010–2021), 16 RISE indicators.

---

## 4. `extract_cliar_data()` — The Core Function

```r
extract_cliar_data(variables = NULL, type = c("dynamic", "static", "raw"), id_vars = NULL)
```

**What it does:** API-style accessor over `cliaretl` data. Pass variable names matching `db_variables_final$variable`.

- `type = "dynamic"`: returns from `closeness_to_frontier_dynamic` (CTF-scaled, country_code × year panel)
- `type = "static"`: returns from `closeness_to_frontier_static` (CTF-scaled, country_code cross-section, no year)
- `type = "raw"`: routes each variable via its `etl_source` to the raw source dataset, then full-joins on `country_code` + `year`
- `variables = NULL`: returns all available columns for the chosen type
- Warns (does not error) on unrecognised or absent variables
- Errors when no valid variables remain after filtering

**Location:** `R/extract_cliar_data.R`  
**Tests:** `tests/testthat/test-extract_cliar_data.R` (33 tests, all passing)

---

## 5. Lazyloaded Package Objects

These four objects are available immediately after `library(cgjrdata)` (or `devtools::load_all()`):

### 5.1 `rawdata_list`

```r
rawdata_list[[cluster]][[subcluster]]  # → tibble
```

- Nested list, same 4-cluster / 13-subcluster structure
- Each tibble: `country_code`, `country_name`, `year`, + raw (un-transformed) indicator values in original source units
- Built by `analysis/00-build_all_datasets.r` → `analysis/01-combine-lazyload.R`
- Raw values are **NOT** CTF-scaled; they are the original numbers from source datasets
- PEFA: stored as `assessment_date` (year of assessment), not a panel
- RISE: joined from local `.dta` file

### 5.2 `ctfdata_list`

```r
ctfdata_list[[cluster]][[subcluster]]  # → tibble
```

- Same structure as `rawdata_list`
- Each tibble: `country_code`, `country_name`, `year`, + CTF-scaled indicator columns, **plus** three appended score columns:

| Column | Type | Description |
|---|---|---|
| `score` | `dbl` | `rowMeans` of all indicator columns, `na.rm = TRUE`. `NA` when every indicator is `NA` for that row. |
| `var_count` | `int` | Total number of indicator columns (constant per subcluster). |
| `nonna_count` | `int` | Count of non-`NA` indicator values used for `score` on each row. |

- CTF scores are normalised 0–1 (0 = worst, 1 = best frontier)
- **Known gaps:** `public_financial_management` and `soe_corporate_governance` subclusters have no CTF dynamic coverage (variables not in `closeness_to_frontier_dynamic`) → their CTF tibbles contain only id columns (and thus `score = NA`, `var_count = 0`)

### 5.3 `metadata_tbl`

```r
metadata_tbl  # → single tibble, one row per indicator
```

- Row-bound combination of all 13 subcluster metadata tibbles
- Key columns for dashboard use:

| Column | Description |
|---|---|
| `variable` | Snake-case column name (matches `rawdata_list` / `ctfdata_list` columns) |
| `var_name` | Human-readable name |
| `description_short` | One-sentence description |
| `source` | Data source name |
| `cluster` | Cluster name (human-readable) |
| `cluster_num` | 1–4 |
| `subcluster` | Subcluster name (human-readable) |
| `subcluster_num` | Position within cluster |
| `etl_source` | Source dataset key |
| `benchmarked_ctf` | `"Yes"` / `"No"` |

### 5.4 `institutional_averages_tbl`

```r
institutional_averages_tbl  # → wide tibble
```

- One row per `country_code × country_name × year`
- **This is the primary dataset for the dashboard overview page**
- Columns:

| Column | Description |
|---|---|
| `country_code` | ISO 3-letter code |
| `country_name` | Country name |
| `year` | Calendar year |
| `institutional_environment_score` | Mean of 4 subcluster scores (equal weight) |
| `political_institutions_score` | Score for 1 subcluster (same as subcluster score) |
| `center_of_government_score` | Mean of 3 subcluster scores |
| `sectors_service_delivery_score` | Mean of 5 subcluster scores |
| `overall_score` | Mean of the 4 cluster scores (`na.rm = TRUE`) |

**Aggregation logic (Option A — equal weight per subcluster):**
1. Each subcluster score = `rowMeans` of its indicator CTF columns
2. Each cluster score = `mean` of its subcluster scores
3. Overall score = `mean` of 4 cluster scores

---

## 6. Score Computation Functions

Defined in `R/compute_scores.R`. All three are exported.

### `add_subcluster_score(tbl, id_cols = c("country_code", "country_name", "year"))`
Appends `score`, `var_count`, `nonna_count` to a single subcluster CTF tibble.

### `score_ctfdata_list(ctfdata_list, id_cols = ...)`
Applies `add_subcluster_score()` to every leaf tibble in the nested list. Returns the enriched list.

### `compute_cluster_averages(ctfdata_list, id_cols = ...)`
Takes a **scored** `ctfdata_list` (output of `score_ctfdata_list()`), computes cluster and overall scores, returns `institutional_averages_tbl`.

---

## 7. Build Pipeline

To fully rebuild all package data from scratch:

```r
# Step 1: Generate all raw + CTF .rds files (writes to data-raw/output/)
source("analysis/00-build_all_datasets.r")

# Step 2: Combine into 4 lazyloaded objects (writes to data/)
source("analysis/01-combine-lazyload.R")

# Step 3: Regenerate documentation
devtools::document()

# Step 4: Check (target: 0 errors, 0 warnings, 0 notes)
devtools::check()
```

### `analysis/00-build_all_datasets.r`
Sources all 13 data-raw scripts in chapter order. Opens with `devtools::load_all()`. Writes `.rds` files to `data-raw/output/`.

### `analysis/01-combine-lazyload.R`
Reads all `.rds` files, assembles the 4 package objects, scores `ctfdata_list`, computes `institutional_averages_tbl`, calls `usethis::use_data(..., overwrite = TRUE)` for each.

### `data-raw/source/` scripts (13 scripts)
Each script builds `raw{x}_tbl`, `dynamic{x}_tbl`, `meta{x}_tbl` and saves them as `.rds` to `data-raw/output/`. They use `devtools::load_all()` (via `00-build_all_datasets.r`) so `extract_cliar_data()` is available.

---

## 8. Data Coverage Notes

| Issue | Detail |
|---|---|
| **ASPIRE variables missing** | `wb_aspire_coverage` and `wb_aspire_adequacy_benefits` labelled `etl_source = "wdi"` but absent from `wdi_indicators`. They appear in neither raw nor CTF datasets. Handle gracefully in dashboard (show as unavailable). |
| **PFM — no CTF dynamic** | All 27 PFM variables are not in `closeness_to_frontier_dynamic`. `ctfdata_list$center_of_government$public_financial_management` has only id columns. |
| **SOE — no CTF dynamic** | All 5 OECD PMR variables are not in CTF dynamic. `ctfdata_list$sectors_service_delivery$soe_corporate_governance` has only id columns. |
| **`rise_ee_4_3` — no CTF dynamic** | Only RISE variable missing from CTF dynamic. |
| **OECD PMR — only 2 raw years** | 2018 and 2023 only. |
| **GTMI — sparse** | `wb_gtmi_dcei`, `wb_gtmi_pfm_mis`, `wb_gtmi_psdi`: 1 year (2022). `wb_gtmi_cgsi`, `wb_gtmi_gtei`: 2 years (2020, 2022). |
| **PEFA — assessment dates** | PEFA data are `assessment_date`-based, not calendar years. Coverage 2015–2025. |
| **RISE — ends 2021** | Local file `RISE_20102021.dta` covers 2010–2021 only. |
| **V-Dem — richest coverage** | 1990–2024, 35 years. |

---

## 9. File Structure

```
cgjrdata/
├── R/
│   ├── extract_cliar_data.R   # Main exported function
│   ├── compute_scores.R       # add_subcluster_score(), score_ctfdata_list(),
│   │                          #   compute_cluster_averages()
│   ├── data.R                 # Roxygen docs for 4 lazyloaded objects
│   └── zzz.R                  # globalVariables()
├── data/
│   ├── rawdata_list.rda
│   ├── ctfdata_list.rda
│   ├── metadata_tbl.rda
│   └── institutional_averages_tbl.rda
├── data-raw/
│   ├── input/
│   │   └── RISE_20102021.dta  # Local RISE energy data (not in cliaretl)
│   ├── output/                # .rds intermediates (gitignored)
│   └── source/
│       ├── 1.institutional_environment/
│       │   ├── degree_of_integrity
│       │   ├── transparency_and_accountability
│       │   ├── justice_and_rule_of_law
│       │   └── social_cohesion_norms_and_cooperation
│       ├── 2.political_institutions/
│       ├── 3.center_of_government/
│       │   ├── public_financial_management
│       │   ├── public_sector_hrm
│       │   └── digital_and_data
│       └── 4.sectors_or_service_delivery/
│           ├── business_environment
│           ├── service_delivery
│           ├── soe_corporate_governance
│           ├── labor_and_social_protection
│           └── energy_and_environment
├── analysis/
│   ├── 00-build_all_datasets.r   # Sources all 13 data-raw scripts
│   └── 01-combine-lazyload.R     # Assembles 4 lazyloaded objects
├── tests/testthat/
│   ├── test-extract_cliar_data.R # 33 tests
│   └── test-compute-scores.R     # ~25 tests
├── man/
│   ├── extract_cliar_data.Rd
│   ├── add_subcluster_score.Rd
│   ├── score_ctfdata_list.Rd
│   ├── compute_cluster_averages.Rd
│   ├── rawdata_list.Rd
│   ├── ctfdata_list.Rd
│   ├── metadata_tbl.Rd
│   └── institutional_averages_tbl.Rd
├── copilot_logs/
│   └── CONTEXT_FOR_CGJRAPP.md    # This file
├── DESCRIPTION
├── NAMESPACE
└── renv.lock
```

---

## 10. DESCRIPTION / Dependencies

```
Package: cgjrdata
Version: 0.0.0.9000
License: MIT
Imports:
  cliaretl,
  dplyr,
  purrr
Suggests:
  testthat (>= 3.0.0)
Config/testthat/edition: 3
```

`cliaretl` must be installed. It is an internal WB package. `renv` is used for reproducibility.

---

## 11. Design Decisions for Dashboard Developer

### Access pattern
```r
library(cgjrdata)

# Overview page — country × year scorecard
institutional_averages_tbl

# Cluster-level drill-down (e.g. Institutional Environment)
ctfdata_list$institutional_environment$degree_of_integrity
# → each subcluster has: country_code, country_name, year, [indicators...],
#                         score, var_count, nonna_count

# Raw values for a specific indicator
rawdata_list$institutional_environment$degree_of_integrity

# Variable metadata (names, descriptions, sources)
metadata_tbl |> dplyr::filter(subcluster == "Degree of Integrity")
```

### CTF scores are 0–1 (higher = better)
All values in `ctfdata_list` are Closeness-to-Frontier scores normalised 0–1. Direction has already been corrected (e.g. corruption indicators are inverted). Raw values in `rawdata_list` are in original source units.

### Suggested dashboard pages
Based on the analytical framework, the dashboard likely needs:

| Page | Primary data object |
|---|---|
| **Overview / Scorecard** | `institutional_averages_tbl` — one row per country × year |
| **Cluster deep-dive** (×4) | `ctfdata_list[[cluster]]` — subcluster scores + individual indicators |
| **Country profile** | Filter all objects to a single `country_code` |
| **Indicator explorer** | `rawdata_list` + `metadata_tbl` |
| **Benchmarking** | `ctfdata_list` — compare countries on a specific indicator |

### Country filtering
Use `country_code` (ISO 3-letter) as the primary filter key. `country_name` is a display label. The universe is the set of countries in `cliaretl::wb_country_list` (214 rows but deduplicate before joining — see Section 3).

### Year filtering
Coverage varies widely by indicator (see Section 8). `institutional_averages_tbl` will have sparse coverage in early years. Recommend defaulting to the most recent complete year.

### Missing data / NAs
All score columns use `na.rm = TRUE` — a country can still receive a cluster score even if some subclusters are missing. Use `nonna_count` from `ctfdata_list` to show users how many indicators contributed to a given score.

---

## 12. Known Issues / Pending Work

| # | Issue | Status |
|---|---|---|
| 1 | `wb_aspire_coverage` and `wb_aspire_adequacy_benefits` have zero data coverage | ⚠️ Unresolved — handle as unavailable in dashboard |
| 2 | `public_financial_management` and `soe_corporate_governance` CTF subclusters are empty (only id cols) | ⚠️ By design — these variables not in CTF dynamic dataset |
| 3 | `data-raw/output/` `.rds` files not yet generated | ⏳ Run `00-build_all_datasets.r` |
| 4 | `data/` not yet populated with 4 new `.rda` files | ⏳ Run `01-combine-lazyload.R` after step 3 |
| 5 | `devtools::document()` not yet re-run with new roxygen | ⏳ Run after step 4 |
| 6 | `devtools::check()` not yet run on final state | ⏳ Target: 0 errors, 0 warnings, 0 notes |

---

## 13. Test Suite Summary

### `test-extract_cliar_data.R` (33 tests)
Covers: return type, dynamic/static/raw happy paths, NULL variables, warnings for unrecognised/absent variables, errors when nothing remains, custom `id_vars`, column ordering, `match.arg` validation.

### `test-compute-scores.R` (~25 tests)
Covers:
- `add_subcluster_score()`: column presence, correct `rowMeans` arithmetic, `var_count`, `nonna_count`, NaN → NA coercion, zero-indicator edge case, custom `id_cols`, single-indicator edge case, non-data-frame error
- `score_ctfdata_list()`: list structure preserved, all leaves enriched, id columns untouched, non-list error
- `compute_cluster_averages()`: tibble return, expected columns, Option A arithmetic (mean of subcluster scores), overall score arithmetic, NA (not NaN) when all-NA cluster, error when `score` column missing, unnamed list error, sort order, multi-year handling

---

## 14. Glossary

| Term | Meaning |
|---|---|
| CTF | Closeness to Frontier — 0-to-1 normalised score (1 = best practice frontier) |
| Cluster | Top-level CGJR analytical grouping (4 total) |
| Subcluster | Second-level grouping within a cluster (13 total) |
| `rawdata_list` | Nested list of raw (un-normalised) indicator values |
| `ctfdata_list` | Nested list of CTF-normalised indicator values + subcluster scores |
| `metadata_tbl` | Flat variable catalogue with descriptions and source metadata |
| `institutional_averages_tbl` | Aggregated scores at subcluster → cluster → overall level |
| `cliaretl` | Internal WB R package supplying raw source datasets and CTF panels |
| RISE | Regulatory Indicators for Sustainable Energy (World Bank) |
| PEFA | Public Expenditure and Financial Accountability (World Bank) |
| GTMI | GovTech Maturity Index (World Bank) |
| V-Dem | Varieties of Democracy project |
| WJP | World Justice Project Rule of Law Index |
| OECD PMR | OECD Product Market Regulation indicators |
| OECD EPL | OECD Employment Protection Legislation indicators |
| WBL | Women, Business and the Law (World Bank) |

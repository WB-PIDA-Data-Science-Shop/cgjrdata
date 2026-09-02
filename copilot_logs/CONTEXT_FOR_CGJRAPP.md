# Context for `cgjrapp` — Shiny Dashboard Development

> **Updated:** 2026-09-02 (rewritten for the new CGJR taxonomy)
> **Source package:** `cgjrdata` (R package, `~/GitProjects/cgjrdata`)
> **Destination app:** `cgjrapp` (Shiny dashboard, to be created)
> **Purpose:** Full context briefing for an AI agent developing `cgjrapp` from scratch.

---

## 1. Project Overview

The **Country Jobs and Growth Report (CGJR)** is a World Bank analytical
framework assessing the quality of a country's institutional and policy
environment relevant to jobs and growth.

The data preparation pipeline is the R package **`cgjrdata`**. It:

1. Defines the CGJR taxonomy and every indicator's place in it as a single
   **crosswalk table** (`cgjr_crosswalk`), with each indicator's `cliaretl`
   variable code resolved against the live catalogue.
2. Validates that crosswalk against `cliaretl`'s own eligibility flags.
3. Slices `cliaretl` panels into nested lists following the taxonomy.
4. Computes Closeness-to-Frontier (CTF) subcluster, cluster and overall
   scores.
5. Exposes everything as lazyloaded package objects.

`cgjrapp` consumes those objects to build an interactive dashboard of country
performance across the framework.

---

## 2. Analytical Framework — Clusters and Leaf Nodes

4 clusters, 11 subclusters, 14 **leaf nodes** (Public Financial Management is
a three-level branch with 4 sub-subclusters). Keys are snake_case and are the
list keys used throughout `cgjrdata`.

| Cluster key | # | Subcluster key | Sub-subcluster keys | CTF status |
|---|---|---|---|---|
| `institutional_environment` | 1 | `degree_of_integrity` | — | populated (5 ind.) |
| | | `transparency_and_accountability` | — | populated (5) |
| | | `justice_and_rule_of_law` | — | populated (16) |
| `core_governance_functions` | 2 | `public_financial_management` | `budget_cycle_and_fiscal_planning`, `domestic_revenue_mobilization`, `public_procurement`, `public_investment_management` | **all empty** — see §5.3 |
| | | `public_sector_hrm` | — | populated (5) |
| | | `digital_and_data` | — | populated (5) but family-aggregate-ineligible — see §5.3 |
| `beyond_core_governance_functions` | 3 | `market_regulatory_institutions` | — | populated (6), family-aggregate-ineligible |
| | | `service_delivery` | — | populated (11), family-aggregate-ineligible |
| | | `soe_governance` | — | **empty** — see §5.3 |
| `context` | 4 | `political_institutions_and_social_cohesion` | — | populated (21) |
| | | `social_cohesion_norms_and_cooperation` | — | populated (5) |

`cgjr_taxonomy` (lazyloaded) is the machine-readable version of this table:
one row per leaf node with `cluster` / `cluster_num` / `cluster_name` /
`subcluster` / ... / `sub_subcluster_name`.

Access patterns:

```r
ctfdata_list$institutional_environment$degree_of_integrity            # 2-level
ctfdata_list$core_governance_functions$public_financial_management$budget_cycle_and_fiscal_planning  # 3-level
```

---

## 3. Source Data — `cliaretl` Package

| Object | Description | Key columns |
|---|---|---|
| `cliaretl::db_variables_final` | Variable catalogue (440 × 17) | `variable`, `etl_source`, `family_name`, `description`, `description_short`, `benchmark_dynamic_indicator`, `benchmark_dynamic_family_aggregate` |
| `cliaretl::closeness_to_frontier_dynamic` | CTF dynamic panel (2796 × 118) | `country_code`, `country_name`, `year` + indicator cols |
| `cliaretl::closeness_to_frontier_static` | CTF static cross-section | `country_code`, `country_name` + indicator cols |
| `cliaretl::wb_country_list` | Country metadata — **has duplicate `country_code` rows**, always `distinct(country_code, .keep_all = TRUE)` before joining | `country_code`, `country_name` |
| `cliaretl::vdem_data`, `d360_efi_data`, `wdi_indicators`, `pefa_assessments`, `pmr`, `gfdb`, `wbl_data`, ... | Raw source datasets, routed by `etl_source` | — |

The `wjp` corrected WJP pull referenced in `reconfiguration.md` is **not**
present in this `cliaretl` — see §8.

RISE energy data is no longer used (the new taxonomy has no energy
subcluster).

---

## 4. The Crosswalk and Its Builders

### `cgjr_crosswalk` (lazyloaded)

One row per indicator (110 rows). Columns: `cluster`, `subcluster`,
`sub_subcluster`, `indicator_num`, `indicator` (display name), `source`
(as stated by the team), `variable` (resolved `cliaretl` code, or `NA` if
unresolved), `note` (how it was resolved / outstanding caveats).

### `validate_crosswalk(crosswalk = cgjr_crosswalk)` — exported

Classifies every row and warns. Returns a tibble with a `check` column:

| `check` | meaning | current count |
|---|---|---|
| `ok` | in panel, `benchmark_dynamic_indicator == "Yes"`, family-aggregate `Yes`/`Partial` | 57 |
| `not_family_aggregate_eligible` | valid panel column but `benchmark_dynamic_family_aggregate == "No"` — **included** in `ctfdata_list`, but the subcluster score is not sanctioned by `cliaretl` | 22 |
| `not_dynamic_eligible` | not a column of the dynamic panel — **excluded** from `ctfdata_list` | 27 |
| `unresolved` | `variable` is `NA` — **excluded** | 4 |

### `build_ctfdata_list()`, `build_rawdata_list()`, `build_metadata_tbl()` — exported

Build the nested objects directly from `cgjr_crosswalk` + `cgjr_taxonomy`.
There are no per-subcluster scripts any more.

---

## 5. Lazyloaded Package Objects

`library(cgjrdata)` attaches: `cgjr_taxonomy`, `cgjr_crosswalk`,
`rawdata_list`, `ctfdata_list`, `metadata_tbl`, `institutional_averages_tbl`,
`wbcountries`, `regionctf_list`, `incomectf_list`, `regionrawdata_list`,
`incomerawdata_list`.

### 5.1 `rawdata_list`

`rawdata_list[[cluster]][[subcluster]]` (or `[[...]][[sub_subcluster]]` for
PFM) → tibble of `country_code`, `country_name`, `year` + raw source values.

Raw coverage is **independent** of the `benchmark_dynamic_*` flags: PFM and
SOE governance carry real raw PEFA / OECD-PMR data here even though their CTF
leaves are empty (e.g. `rawdata_list$core_governance_functions$public_financial_management$budget_cycle_and_fiscal_planning`
is 8939 × 27). A leaf whose indicators resolve to no raw source is a zero-row
tibble with id columns only.

### 5.2 `ctfdata_list`

Same nesting as `rawdata_list`. Each populated leaf: `country_code`,
`country_name`, `year`, one CTF-scaled column per **dynamic-eligible**
indicator, plus three columns appended by `score_ctfdata_list()`:

| Column | Type | Description |
|---|---|---|
| `score` | `dbl` | row mean of indicator columns, `na.rm = TRUE`; `NA` when all-NA |
| `var_count` | `int` | number of indicator columns |
| `nonna_count` | `int` | non-NA indicator values used per row |

CTF scores are 0–1 (1 = frontier); direction already corrected upstream.

### 5.3 Empty and caveated leaves — **dashboard must handle**

| Leaf | State | Why |
|---|---|---|
| `core_governance_functions$public_financial_management$*` (all 4) | **zero-row** tibble | every PFM indicator (BTI/CLIAR/GTMI + 21 PEFA) is `benchmark_dynamic_indicator = "No"` / absent from the dynamic panel |
| `beyond_core_governance_functions$soe_governance` | **zero-row** tibble | OECD PMR codes are static-only; 3 of 6 SOE indicators unresolved |
| `core_governance_functions$digital_and_data` | populated, **flagged** | all 5 indicators `benchmark_dynamic_family_aggregate = "No"` |
| `beyond_core_governance_functions$market_regulatory_institutions` | populated, **flagged** | all 6 indicators family-aggregate `"No"` |
| `beyond_core_governance_functions$service_delivery` | populated, **flagged** | all 11 indicators family-aggregate `"No"` |

For an empty leaf: `nrow == 0`. Render "Indicators coming soon". For a
flagged leaf: the `score` column is populated but its family-aggregate
validity is disputed — surface `metadata_tbl$family_aggregate_eligible`
(all `FALSE` for those three subclusters) so users know.

### 5.4 `metadata_tbl`

One row per `cgjr_crosswalk` row (110 × 32). Every taxonomy indicator,
including unresolved ones. Key columns: `cluster`/`subcluster`/`sub_subcluster`
(+ `_num`, `_name`), `indicator`, `indicator_num`, `source`, `variable`,
`note`, catalogue columns from `db_variables_final` (`var_name`,
`description_short`, `family_name`, `benchmark_dynamic_indicator`,
`benchmark_dynamic_family_aggregate`, ...), plus derived flags
`dynamic_indicator_eligible` and `family_aggregate_eligible`.

### 5.5 `institutional_averages_tbl`

**Primary dataset for the overview page.** One row per
`country_code × country_name × year` (2796 rows; years 2013–2024;
233 countries). Columns:

| Column | Description |
|---|---|
| `country_code`, `country_name`, `year` | keys |
| `institutional_environment_score` | mean of its 3 subcluster scores |
| `core_governance_functions_score` | mean of its subcluster scores (PFM empty → does not contribute) |
| `beyond_core_governance_functions_score` | mean of its subcluster scores (SOE empty → does not contribute) |
| `context_score` | mean of its 2 subcluster scores |
| `overall_score` | mean of the 4 cluster scores (`na.rm = TRUE`) |

**Aggregation (equal weight per child at every level):**
1. leaf score = row mean of its CTF indicator columns
2. branch score = mean of its immediate children's scores (PFM = mean of its
   4 sub-subcluster scores)
3. cluster score = mean of its subcluster/branch scores
4. overall = mean of the cluster scores

### 5.6 `regionctf_list` / `incomectf_list` / `regionrawdata_list` / `incomerawdata_list`

Same nested shape as `ctfdata_list` / `rawdata_list`, with country rows
replaced by `region × year` or `income_group × year` means (WB aggregate
codes dropped, `var_count` / `nonna_count` dropped, `score` recomputed).
Empty leaves stay empty. Built by `aggregate_data_list()`.

### 5.7 `wbcountries`

WB country classifications (218 × 6): `economy`, `country_code`,
`income_group`, `lending_category`, `region_code`, `region`. Sub-Saharan
Africa is split into AFE / AFW.

---

## 6. Score Computation Functions (exported, `R/compute_scores.R`)

All handle **arbitrary nesting depth** — a leaf is any `data.frame`.

- `add_subcluster_score(tbl, id_cols = c("country_code","country_name","year"))`
  — appends `score` / `var_count` / `nonna_count`. Zero-row and
  zero-indicator inputs are handled (not errors).
- `score_ctfdata_list(ctfdata_list, id_cols = ...)` — recurses over every leaf.
- `compute_cluster_averages(ctfdata_list, id_cols = ...)` — recursive
  equal-weight aggregation → `institutional_averages_tbl`.

Group aggregation (`R/aggregate_groups.R`): `aggregate_data_list(data_list,
group_col = c("region","income_group"), wbcountries)` — also recursive.

Accessor (`R/extract_cliar_data.R`): `extract_cliar_data(variables, type =
c("dynamic","static","raw"), id_vars = NULL)` — unchanged; still the raw-data
router used by `build_rawdata_list()`.

---

## 7. Build Pipeline

```r
# 1. wbcountries + cgjr_taxonomy + cgjr_crosswalk
#    (writes data-raw/output/cgjr_crosswalk_validation.csv; emits eligibility warnings)
source("analysis/00-build_all_datasets.r")

# 2. Assemble every lazyloaded object from the crosswalk
source("analysis/01-combine-lazyload.R")

# 3. Docs + check
devtools::document()
devtools::check()   # currently 0 errors / 0 warnings / 0 notes
```

`data-raw/source/`:
- `00a-prepare-country-list.R` → `wbcountries` (from `data-raw/input/CLASS_2025_10_07.xlsx`)
- `00b-cgjr-taxonomy-crosswalk.R` → `cgjr_taxonomy`, `cgjr_crosswalk`

`data-raw/output/` is git-ignored (regenerated).

---

## 8. Known Issues / Pending Team Decisions

| # | Issue | Status |
|---|---|---|
| 1 | **PFM & SOE governance have no CTF-dynamic indicators.** All PFM (24) + 3 resolved SOE codes fail `benchmark_dynamic_indicator`. Both build as empty leaves. Raw data *is* available. | ⚠️ by design; dashboard shows "coming soon" |
| 2 | **`digital_and_data`, `market_regulatory_institutions`, `service_delivery` are entirely `benchmark_dynamic_family_aggregate = "No"`.** Scored anyway (they are valid panel columns) but `validate_crosswalk()` warns. | ⚠️ team decision: score or treat as "coming soon"? |
| 3 | **4 unresolved indicators** (no `cliaretl` code): "Criminal adjudication system is timely and effective" (JRL); "Scope of SOE", "Governance of SOE", "Use of command-and-control regulation" (SOE governance). | ⚠️ excluded; `variable = NA` in crosswalk |
| 4 | **`wjp_rol_8_2` mislabel trap.** In this `cliaretl` its text = "criminal investigation system" (duplicates `wjp_rol_8_1`). The corrected standalone `wjp` pull is not available. | ⚠️ excluded row 13 of JRL |
| 5 | **`wjp_rol_7_1`** ("People can access and afford civil justice"): in this `cliaretl` build the description is the narrow subfactor (looks corrected, not the Factor-7 composite the doc warns about). Included, flagged in `note`. | ⚠️ verify against `wjp` pull if available |
| 6 | `wb_pefa_pi_2016_28` — `cliaretl` docstring appears copy-pasted from PI-27; verify contents. | ⚠️ raw only |
| 7 | Region/income means: individual indicator columns can be `NaN` (all-NA group). `score` is coerced to `NA` but indicator columns are not. Pre-existing `aggregate_groups.R` behaviour. | minor |

Full per-row detail: `data-raw/output/cgjr_crosswalk_validation.csv` (regenerate
with the build) or `validate_crosswalk(cgjr_crosswalk)`.

---

## 9. Test Suite

`tests/testthat/` — ~80 `test_that` blocks, all passing:

- `test-extract_cliar_data.R` (19) — the raw/dynamic/static accessor
- `test-compute-scores.R` (26) — scoring incl. 3-level nesting + empty leaves
- `test-aggregate-groups.R` (26) — region/income aggregation incl. nesting
- `test-crosswalk.R` (9) — `validate_crosswalk()` + the builders + the shipped crosswalk

---

## 10. Suggested Dashboard Pages

| Page | Primary object |
|---|---|
| Overview / Scorecard | `institutional_averages_tbl` |
| Cluster deep-dive (×4) | `ctfdata_list[[cluster]]` — subcluster scores + indicators; handle empty/flagged leaves per §5.3 |
| Country profile | filter all objects to one `country_code` |
| Indicator explorer | `rawdata_list` + `metadata_tbl` |
| Benchmarking | `ctfdata_list`, `regionctf_list`, `incomectf_list` |

- Filter key: `country_code` (ISO-3). `country_name` is display only.
- `nonna_count` (in `ctfdata_list`) tells users how many indicators backed a score.
- Default to the most recent year with good coverage.

# Context for `cgjrapp` — Shiny dashboard development

> **Updated:** 2026-09-07 (rewritten for the tidy-tibble build)
> **Source package:** `cgjrdata` (R package, `~/GitProjects/cgjrdata`)
> **Destination app:** `cgjrapp` (Shiny dashboard, to be created)
> **Methodology reference:** `cliarappak` (the CLIAR benchmarking dashboard)
> **Purpose:** full context briefing for an agent building `cgjrapp` from scratch.

---

## 1. What `cgjrdata` produces

The **Country Jobs and Growth Report (CGJR)** assesses the quality of a
country's institutional environment for jobs and growth. `cgjrdata`:

1. Defines the CGJR taxonomy and every indicator's place in it as two editable
   CSVs, assembled into one annotated **crosswalk** (`cgjr_crosswalk`) with
   each indicator's `cliaretl` variable code resolved and validated.
2. Slices `cliaretl`'s Closeness-to-Frontier (CTF) panels for every eligible
   indicator → **`cgjr_ctf`** (long, indicator grain).
3. Rolls those values up the taxonomy by equal-weight averaging →
   **`cgjr_scores`** (long, node grain).
4. Pulls raw provider values → **`cgjr_raw`** (long, indicator grain, country
   only).
5. Adds region / income-group rows to `cgjr_ctf` and `cgjr_scores` by taking
   the **median across the group's countries**.

Everything ships as **long tidy tibbles** — no nested lists, no per-object
score columns. The app filters and joins; it does not recompute.

---

## 2. Taxonomy — clusters, subclusters, leaves

**4 clusters, 11 subclusters, 14 leaf nodes.** Public Financial Management is
the only branching subcluster (4 sub-subclusters); the other 10 subclusters
are themselves leaves. All keys are snake_case.

| Cluster key | # | Subcluster key | Leaf(s) | dynamic CTF | static CTF |
|---|---|---|---|---|---|
| `institutional_environment` | 1 | `degree_of_integrity` | (self) | 5 ind. | 5 |
| | | `transparency_and_accountability` | (self) | 5 | 5 |
| | | `justice_and_rule_of_law` | (self) | 16 | 16 |
| `core_governance_functions` | 2 | `public_financial_management` | `budget_cycle_and_fiscal_planning` | **0** | 24 |
| | | | `domestic_revenue_mobilization` | **0** | **0** |
| | | | `public_procurement` | **0** | **0** |
| | | | `public_investment_management` | **0** | **0** |
| | | `public_sector_hrm` | (self) | 5 | 5 |
| | | `digital_and_data` | (self) | 5 | 5 |
| `beyond_core_governance_functions` | 3 | `market_regulatory_institutions` | (self) | 6 | 6 |
| | | `service_delivery` | (self) | 11 | 11 |
| | | `soe_governance` | (self) | **0** | 3 |
| `context` | 4 | `political_institutions_and_social_cohesion` | (self) | 21 | 21 |
| | | `social_cohesion_norms_and_cooperation` | (self) | 5 | 5 |

`cgjr_taxonomy` (14 rows) is the machine-readable version: `cluster`,
`cluster_num`, `cluster_name`, `subcluster`, `subcluster_num`,
`subcluster_name`, `sub_subcluster`, `sub_subcluster_num`,
`sub_subcluster_name`. The derived **leaf** key is
`dplyr::coalesce(sub_subcluster, subcluster)` (exported as `resolve_leaf()`).

**Empty leaves — the app must handle these:**

- **Dynamic:** the four PFM sub-subclusters + `soe_governance` have no
  dynamic-eligible indicators. In `cgjr_scores` they appear with `score = NA`,
  `n_inputs = 0` for every unit / year. Render "coming soon", not "0".
- **Static:** the three PFM sub-subclusters other than
  `budget_cycle_and_fiscal_planning` have no indicators at all (no crosswalk
  rows yet).

---

## 3. Source data — `cliaretl`

| Object | What | Notes |
|---|---|---|
| `cliaretl::db_variables_final` | variable catalogue (440 × ~30) | `variable`, `etl_source`, `family_var`, `family_name`, `description`, `benchmark_dynamic_indicator`, `benchmark_dynamic_family_aggregate`, … |
| `cliaretl::closeness_to_frontier_dynamic` | CTF dynamic panel (2796 × 118; 233 countries × 2013–2024) | indicator cols + `vars_*_avg` family-aggregate cols + GDP |
| `cliaretl::closeness_to_frontier_static` | CTF static cross-section (233 × ~150) | **no `year` column**; snapshot |
| `cliaretl::vdem_data`, `d360_efi_data`, `wdi_indicators`, `pefa_assessments`, `pmr`, `epl`, `wbl_data`, … | raw provider datasets, routed by `etl_source` | — |
| `cliaretl` `extdata/compiled_indicators.rds` | the CLIAR app's assembled raw panel | `cgjr_raw` agrees with it cell-for-cell |

CTF direction, windows and indicator eligibility are all enforced **upstream**
in `cliaretl`. `cgjrdata` only slices columns and averages.

---

## 4. The three long tibbles

### 4.1 `cgjr_ctf` — indicator-grain CTF

One row per **`unit_level` × `unit_code` × `unit_name` × `year` × `ctf_type` ×
`cluster` × `subcluster` × `sub_subcluster` × `leaf` × `indicator` ×
`variable`**, value column `ctf`.

| column | notes |
|---|---|
| `unit_level` | `"country"` / `"region"` / `"income_group"` |
| `unit_code` | ISO3 / WB `region_code` (e.g. `"AFE"`) / income-group slug (e.g. `"high_income"`) |
| `year` | integer for `ctf_type == "dynamic"`; **`NA` for `"static"`** |
| `ctf_type` | `"dynamic"` / `"static"` |
| `ctf` | numeric, ~[0, 1] but **can exceed 1** (a country ahead of the frontier — observed max ≈ 1.13) |
| `n_inputs`, `n_inputs_obs` | `NA` on country rows; on group rows, # of the group's countries present / with a non-NA value |

- Country rows: an **exact slice** of the CTF panel (verified byte-for-byte).
- Group rows: `median` across the group's countries of the indicator's
  country-level `ctf`, per row.
- Only `dynamic_eligible` / `static_eligible` crosswalk variables appear.
  Unresolved / ineligible indicators produce no rows.
- Join `cgjr_taxonomy` for cluster/subcluster numbers and display names.

### 4.2 `cgjr_scores` — node-grain rollup

One row per **unit × year × ctf_type × node**.

| column | notes |
|---|---|
| `node_level` | `"subcluster"` / `"sub_subcluster"` / `"cluster"` / `"overall"` |
| `node` | the operative key: subcluster key / sub_subcluster key / cluster key / `"overall"` |
| `cluster`, `subcluster`, `sub_subcluster` | ancestry, filled to the node's depth, `NA` deeper |
| `score` | numeric, ~[0, 1] |
| `n_inputs` | # of the node's immediate children (indicators for a finest-grain node; sub_subclusters for PFM's subcluster row; subclusters for a cluster; clusters for `overall`) |
| `n_inputs_obs` | of those, # with a non-`NA` value (on group rows, # of countries) |

**Rollup (order ii, within country):**

```
leaf score          = mean(indicator ctf,      na.rm = TRUE)
PFM subcluster score = mean(sub_subcluster score, na.rm = TRUE)   # only PFM
cluster score       = mean(subcluster score,    na.rm = TRUE)
overall score       = mean(cluster score,       na.rm = TRUE)
```

Lenient (`na.rm = TRUE`) at every stage; all-children-missing → `NA` (never
`NaN`). Every taxonomy leaf is scaffolded in first, so a zero-indicator leaf
gets a row (`score = NA`, `n_inputs = 0`) rather than vanishing.

**No stored "is this the finest grain" flag.** Every plain subcluster reports
once, at `node_level == "subcluster"`, and *is* the finest grain for its
branch. Only PFM also has `node_level == "sub_subcluster"` rows. To select
every finest-grain node regardless of depth:

```r
branching <- unique(cgjr_scores$subcluster[cgjr_scores$node_level == "sub_subcluster"])
finest <- cgjr_scores |>
  dplyr::filter(node_level %in% c("subcluster", "sub_subcluster"),
                !(node_level == "subcluster" & subcluster %in% branching))
```

**Group rows:** `median` across the group's countries of each node's
country-level `score` — taken *after* the within-country rollup (order ii).
Because `median` is non-linear, a region's `cgjr_scores` rows will **not**
arithmetically reconcile with a recomputation from its `cgjr_ctf` rows. This
is expected.

### 4.3 `cgjr_raw` — raw source values

Same columns as `cgjr_ctf` minus `ctf_type` / `n_inputs` / `n_inputs_obs`,
with `value` instead of `ctf`. **Country grain only** — `unit_level` is always
`"country"`. `value` is on the provider's native scale (heterogeneous:
indices, %, ordinal). No group aggregation — a regional median of mixed units
is meaningless. `year` runs 1990–2025. Raw coverage is independent of CTF
eligibility (PFM and SOE carry raw PEFA / PMR values here even though their
dynamic CTF leaves are empty).

---

## 5. `cgjr_crosswalk` — the annotated crosswalk

One row per (indicator × leaf), ~110 rows, **every CSV row kept** including
the 4 currently unresolved. Built by `build_crosswalk()`.

Key columns beyond the CSV (`cluster`, `subcluster`, `sub_subcluster`,
`indicator_num`, `indicator`, `source`, `variable`, `note`):

| column | meaning |
|---|---|
| `leaf` | `coalesce(sub_subcluster, subcluster)` |
| `cluster_num` … `sub_subcluster_name` | from `cgjr_taxonomy` |
| `var_name`, `description`, `family_var`, `family_name`, `benchmark_dynamic_indicator`, `benchmark_dynamic_family_aggregate`, … | from `cliaretl::db_variables_final` (`NA` for unresolved) |
| `in_cliaretl`, `in_dynamic_panel`, `in_static_panel` | membership booleans |
| `dynamic_eligible` | `in_dynamic_panel & benchmark_dynamic_indicator == "Yes"` — **79 variables** |
| `static_eligible` | `in_static_panel` (no static indicator flag exists) — **106 variables** |
| `cliaretl_status` | `"resolved"` (106) / `"unresolved"` (4) / `"not_in_cliaretl"` (0) |

`validate_crosswalk(cgjr_crosswalk)` re-runs the build-time eligibility report
(warns, row by row, on anything that will contribute no CTF data).

**Eligibility gate rationale** (see `qcheck/qa-report.md` F3): for real
indicators, `benchmark_dynamic_indicator == "Yes"` and dynamic-panel
membership are the *same* 79 variables; the only unflagged panel columns are
`vars_*_avg` aggregates and GDP. `cliarappak` gates families on the same flag.
`benchmark_dynamic_family_aggregate` (Yes/Partial/No) is **not** a gate — in
`cliarappak` it only decides which family dots to *draw*. It is carried on
`cgjr_crosswalk` for any consumer that wants to filter further.

---

## 6. Relationship to the CLIAR dashboard (`cliarappak`)

CGJR **matches** CLIAR where the taxonomy aligns and **extends** it where it
doesn't. From the QA audit (`qcheck/qa-report.md`):

| | CLIAR (`cliarappak`) | CGJR (`cgjr_scores`) |
|---|---|---|
| family / leaf average | lenient `mean(na.rm = TRUE)`, `NaN→NA`, drop `gdp` (`cliaretl::compute_family_average(require_complete = FALSE)`) | **same** — leaf scores match cell-for-cell for the 6 leaves whose indicator set equals a CLIAR `family_var` |
| above family level | **nothing** — CLIAR has no cluster / pillar / overall | CGJR adds `sub_subcluster` / `cluster` / `overall`, equal-weight mean of children |
| dynamic years | **even years only** (`year %% 2 == 0`) | every year — filter to even years for strict parity |
| cross-country | `median` plot overlay | `median` across countries, order ii |

**Deliberate taxonomy departures** (`cgjr_scores` leaves that pool indicators
differently from a single CLIAR `family_var` — confirm each with the CGJR
team):

- `justice_and_rule_of_law` — 16 of 17 `vars_leg` members (omits `wjp_rol_8_2`).
- `political_institutions_and_social_cohesion` — **merges** `vars_pol` + `vars_social` (21 indicators).
- `social_cohesion_norms_and_cooperation` — a 5-indicator **subset** of `vars_pol`.

---

## 7. Build pipeline

```r
# 1. wbcountries + cgjr_taxonomy + cgjr_crosswalk (reads data-raw/input/*.csv)
source("analysis/00-build_all_datasets.r")

# 2. cgjr_ctf + cgjr_scores + cgjr_raw
source("analysis/01-build-tidy-data.R")

# 3. docs + check
devtools::document()
devtools::check()   # 0 errors / 0 warnings / 0 notes
```

- `data-raw/input/cgjr_taxonomy.csv`, `cgjr_crosswalk.csv` — the **only**
  files to edit when the methodology changes (see `data-raw/input/README.md`).
- `data-raw/source/00a-prepare-country-list.R` → `wbcountries`.
- `data-raw/source/00b-cgjr-taxonomy-crosswalk.R` → `cgjr_taxonomy`,
  `cgjr_crosswalk`.
- The cross-country aggregation function is a single `agg` argument in
  `analysis/01-build-tidy-data.R` — `stats::median` by default, switch to
  `mean` there.

---

## 8. Exported functions

| function | role |
|---|---|
| `check_crosswalk_schema(crosswalk, taxonomy)` | structural check on the CSV pair (`cliaretl`-free, batched `stop()`) |
| `classify_crosswalk(crosswalk, catalogue, ctf_dynamic, ctf_static)` | per-row eligibility flag tibble |
| `validate_crosswalk(...)` | `classify_crosswalk()` + a single warning listing rows that contribute no CTF |
| `resolve_leaf(sub_subcluster, subcluster)` | the `coalesce()` leaf key |
| `build_crosswalk(crosswalk, taxonomy, catalogue)` | assemble the annotated `cgjr_crosswalk` |
| `build_ctf_tbl(crosswalk, ctf_dynamic, ctf_static, id_cols)` | country-level `cgjr_ctf` |
| `build_raw_tbl(crosswalk, id_cols)` | country-level `cgjr_raw` |
| `roll_up_scores(ctf_tbl, taxonomy)` | country-level `cgjr_scores` |
| `aggregate_to_groups(tbl, wbcountries, value_col, agg, min_n)` | region + income-group rows |
| `join_wb_classifications(tbl, wbcountries)` | left-join region / income onto country rows |
| `extract_cliar_data(variables, type, id_vars)` | raw / dynamic / static accessor into `cliaretl` |

---

## 9. Test suite

`tests/testthat/` — all passing:

| file | covers |
|---|---|
| `test-extract_cliar_data.R` | the raw / dynamic / static accessor |
| `test-schema.R` | `check_crosswalk_schema()` |
| `test-eligibility.R` | `classify_crosswalk()` / `validate_crosswalk()` |
| `test-crosswalk.R` | `build_crosswalk()` + the shipped CSV |
| `test-ctf.R` | `build_ctf_tbl()` shape, both `ctf_type`s, eligibility gating |
| `test-raw.R` | `build_raw_tbl()` |
| `test-scores.R` | `roll_up_scores()` — every tier, NA/NaN, `n_inputs`, PFM branch, the finest-grain recipe |
| `test-aggregate.R` | `aggregate_to_groups()` — median, `mean` switch, `min_n`, order-ii property |
| `test-integration.R` | the six built objects — columns, `unit_level` domain, taxonomy coverage, value bounds |

`qcheck/qa-report.Rmd` is the deeper audit against `cliaretl` + `cliarappak`
(see `qcheck/README.md`).

---

## 10. Suggested dashboard structure

| Page | Primary object | Filter |
|---|---|---|
| Overview / scorecard | `cgjr_scores` where `node_level == "overall"` | `unit_level`, `ctf_type`, `year` |
| Cluster deep-dive (×4) | `cgjr_scores` for that `cluster` (all `node_level`s) + `cgjr_ctf` for the indicators | `cluster`, `unit_code` |
| Country profile | all three tibbles filtered to one `unit_code` | `unit_code` |
| Indicator explorer | `cgjr_raw` + `cgjr_crosswalk` (metadata) | `leaf`, `indicator` |
| Benchmarking | `cgjr_scores` / `cgjr_ctf` across `unit_level`s | `node`, `year`, `ctf_type` |

- **Filter key:** `unit_code` (ISO3, or `region_code` / income slug).
  `unit_name` is display only.
- **`n_inputs` / `n_inputs_obs`** tell users how many indicators (or
  countries) backed a score — surface them so thin aggregates are visible.
- **`ctf_type` toggle:** dynamic (over time, 2013–2024, even years for family
  parity with CLIAR) vs static (latest snapshot, `year == NA`).
- **Empty leaves:** `score == NA & n_inputs == 0` → "coming soon", not zero.
- Default to `ctf_type == "dynamic"`, the latest year, `unit_level == "country"`.

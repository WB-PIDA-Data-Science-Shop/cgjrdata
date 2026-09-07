
<!-- README.md is generated from README.Rmd. Please edit that file -->

# cgjrdata

<!-- badges: start -->

[![R-CMD-check](https://github.com/WB-PIDA-Data-Science-Shop/cgjrdata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/WB-PIDA-Data-Science-Shop/cgjrdata/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/WB-PIDA-Data-Science-Shop/cgjrdata/graph/badge.svg)](https://app.codecov.io/gh/WB-PIDA-Data-Science-Shop/cgjrdata)
<!-- badges: end -->

`cgjrdata` is the data-preparation package for the **World Bank Country
Jobs and Growth Report (CGJR)**. It resolves every CGJR indicator
against the `cliaretl` source package, slices the Closeness-to-Frontier
(CTF) panels along the CGJR taxonomy, rolls those values up to node
scores, and ships everything as **long tidy tibbles** for the `cgjrapp`
Shiny dashboard.

## Analytical framework

Every indicator’s place in the taxonomy lives in a single crosswalk
table (`cgjr_crosswalk`), annotated and validated against `cliaretl`’s
own eligibility flags at build time. The taxonomy has **4 clusters**,
**11 subclusters** and **14 leaf nodes** (Public Financial Management
branches into four sub-subclusters; the other 10 subclusters are
themselves leaves):

| \# | Cluster (key) | Subclusters |
|----|----|----|
| 1 | `institutional_environment` | Degree of Integrity, Transparency & Accountability, Justice & Rule of Law |
| 2 | `core_governance_functions` | Public Financial Management *(→ Budget Cycle & Fiscal Planning, Domestic Revenue Mobilization, Public Procurement, Public Investment Management)*, Public Sector HRM, Digital & Data |
| 3 | `beyond_core_governance_functions` | Market Regulatory Institutions, Service Delivery, SOE Governance |
| 4 | `context` | Political Institutions & Social Cohesion, Social Cohesion Norms & Cooperation |

**Current coverage.** Under the shipped `cliaretl`, the four Public
Financial Management sub-subclusters and SOE Governance have **no
dynamic-panel indicators** — their `cgjr_scores` dynamic rows carry
`score = NA`, `n_inputs = 0` (“coming soon”). Budget Cycle & Fiscal
Planning (24 indicators) and SOE Governance (3) do have static CTF
coverage.

## Installation

`cgjrdata` depends on `cliaretl`, an internal World Bank package on
GitHub. Install both with:

``` r
# install.packages("pak")
pak::pak("WB-PIDA-Data-Science-Shop/cliaretl")
pak::pak("WB-PIDA-Data-Science-Shop/cgjrdata")
```

You will need a GitHub Personal Access Token with access to the
`WB-PIDA-Data-Science-Shop` organisation.

## Shipped objects

`library(cgjrdata)` lazy-loads six objects. Three are inputs /
reference; three are the long tibbles the dashboard consumes.

| object | grain | rows |
|----|----|----|
| `cgjr_taxonomy` | one row per leaf node | 14 |
| `cgjr_crosswalk` | one row per (indicator × leaf), annotated + validated | ~110 |
| `wbcountries` | WB country classifications (region, income group) | 218 |
| `cgjr_ctf` | unit × year × ctf_type × leaf × indicator | ~258k |
| `cgjr_scores` | unit × year × ctf_type × node (equal-weight rollup) | ~64k |
| `cgjr_raw` | country × year × leaf × indicator (raw source values) | ~962k |

``` r
library(cgjrdata)
```

### `cgjr_ctf` — Closeness-to-Frontier values, indicator grain

One row per **unit × year × ctf_type × leaf × indicator**. `ctf` is an
exact slice of `cliaretl::closeness_to_frontier_dynamic` / `_static` —
no transformation. `unit_level` is `"country"`, `"region"` or
`"income_group"` (group rows are the `median` across the group’s
countries). `year` is `NA` for `ctf_type == "static"`.

``` r
library(dplyr)
cgjr_ctf |>
  filter(unit_level == "country", unit_code == "KEN", ctf_type == "dynamic",
         leaf == "degree_of_integrity")
```

### `cgjr_scores` — equal-weight rollup, node grain

One row per **unit × year × ctf_type × node**, where `node_level` is a
real taxonomy tier: `"subcluster"`, `"sub_subcluster"` (Public Financial
Management only), `"cluster"` or `"overall"`. A leaf score is the
lenient mean (`na.rm = TRUE`) of its indicators’ `ctf`; each tier above
is the equal-weight mean of its immediate children. Every row carries
`n_inputs` and `n_inputs_obs`.

``` r
# overall CTF score, all countries, latest year
cgjr_scores |>
  filter(unit_level == "country", node_level == "overall", ctf_type == "dynamic",
         year == max(year))

# every finest-grain node, regardless of depth
branching <- unique(cgjr_scores$subcluster[cgjr_scores$node_level == "sub_subcluster"])
cgjr_scores |>
  filter(node_level %in% c("subcluster", "sub_subcluster"),
         !(node_level == "subcluster" & subcluster %in% branching))
```

### `cgjr_raw` — raw source values

One row per **country × year × leaf × indicator**, `value` on the
provider’s native scale (V-Dem 0–1, PMR 0–6, …). No `ctf_type`,
**country grain only** — raw values are for display / download, never
benchmarking.

### `cgjr_crosswalk` — the annotated crosswalk

One row per (indicator × leaf), every CSV row kept (including the 4
currently unresolved). Carries the taxonomy keys/names, `cliaretl`
catalogue metadata, and the eligibility flags (`in_dynamic_panel`,
`dynamic_eligible`, `static_eligible`, `cliaretl_status`, …).

``` r
validate_crosswalk(cgjr_crosswalk)   # re-run the build-time eligibility report
```

## Exported functions

| function | role |
|----|----|
| `check_crosswalk_schema()` | structural check on the two source CSVs (`cliaretl`-free) |
| `classify_crosswalk()` / `validate_crosswalk()` | per-row `cliaretl` eligibility flags + a warning report |
| `resolve_leaf()` / `build_crosswalk()` | assemble the annotated `cgjr_crosswalk` |
| `build_ctf_tbl()` | country-level `cgjr_ctf` from the crosswalk + CTF panels |
| `build_raw_tbl()` | country-level `cgjr_raw` |
| `roll_up_scores()` | country-level `cgjr_scores` (order-ii equal-weight rollup) |
| `aggregate_to_groups()` / `join_wb_classifications()` | add region / income-group rows (median default) |
| `extract_cliar_data()` | raw / dynamic / static accessor into `cliaretl` |

## Rebuilding the data

``` r
# 1. wbcountries + cgjr_taxonomy + cgjr_crosswalk (reads the two editable CSVs)
source("analysis/00-build_all_datasets.r")

# 2. cgjr_ctf + cgjr_scores + cgjr_raw
source("analysis/01-build-tidy-data.R")

# 3. docs
devtools::document()
```

The two editable CSVs in `data-raw/input/` (`cgjr_taxonomy.csv`,
`cgjr_crosswalk.csv`) are the only source of truth for the taxonomy —
see `data-raw/input/README.md`.

## Quality assurance

`qcheck/qa-report.Rmd` is a reproducible audit of the six shipped
objects against `cliaretl` and the `cliarappak` methodology
(`qcheck/qa-report.md` is the knit output). Regenerate with
`rmarkdown::render("qcheck/qa-report.Rmd")`.

## Data sources

| Source | Coverage | Key indicators |
|----|----|----|
| V-Dem | 1990–2024 | Democracy, corruption, rule of law |
| WJP Rule of Law Index | multiple years | Rule of law, civil / criminal justice |
| PEFA | 2015–2025 | Public financial management (raw + static) |
| OECD PMR / EPL | 2018, 2023 | Product-market / SOE regulation, employment protection |
| Freedom House / RSF Press Freedom | multiple years | Political & civil rights |
| Bertelsmann Transformation Index | multiple years | Governance, competition, fiscal |
| WDI / WBL / GTMI / SPI | multiple years | Service delivery, digital, gender |

## Related packages

- [`cliaretl`](https://github.com/WB-PIDA-Data-Science-Shop/cliaretl) —
  upstream ETL / source-data package
- [`cliarappak`](https://github.com/WB-PIDA-Data-Science-Shop/cliarappak)
  — the CLIAR benchmarking dashboard (methodology reference)
- `cgjrapp` — the CGJR Shiny dashboard consuming this package *(in
  development)*

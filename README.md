
<!-- README.md is generated from README.Rmd. Please edit that file -->

# cgjrdata

<!-- badges: start -->

[![R-CMD-check](https://github.com/WB-PIDA-Data-Science-Shop/cgjrdata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/WB-PIDA-Data-Science-Shop/cgjrdata/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/WB-PIDA-Data-Science-Shop/cgjrdata/graph/badge.svg)](https://app.codecov.io/gh/WB-PIDA-Data-Science-Shop/cgjrdata)
<!-- badges: end -->

`cgjrdata` packages the indicators of the **World Bank Country Jobs and
Growth Report (CGJR)** institutional framework for the `cgjrapp` Shiny
dashboard. A hand-edited crosswalk maps each indicator to a leaf of the
CGJR taxonomy; the build joins that mapping onto the CLIAR data in
[`cliaretl`](https://github.com/WB-PIDA-Data-Science-Shop/cliaretl) and
ships the result as long tables.

Closeness-to-Frontier (CTF) values are copied **unchanged** from
`cliaretl`, and an indicator is benchmarked only where CLIAR benchmarks
it, so a country’s score on an indicator shared with the CLIAR app is
identical in both apps. cgjrapp computes every composite score live,
from the member countries of the selection.

The current data were built from `cliaretl` 0.2.6.

## Installation

``` r
# install.packages("pak")
pak::pak("WB-PIDA-Data-Science-Shop/cgjrdata")
```

You need a GitHub Personal Access Token with access to the
`WB-PIDA-Data-Science-Shop` organisation. `cliaretl` is needed only to
rebuild the data or to run the checks against it; using the shipped data
does not need it.

## Shipped objects

| object | grain | rows |
|:---|:---|:---|
| `cgjr_taxonomy` | one row per taxonomy leaf | 14 |
| `cgjr_crosswalk` | indicator x leaf, annotated against cliaretl | 110 |
| `cgjr_ctf` | country x year x ctf_type x variable x leaf | 239,112 |
| `cgjr_raw` | country x year x variable x leaf (observed values only) | 292,633 |
| `wbcountries` | one row per country: region, income group | 218 |

`cgjr_ctf` and `cgjr_raw` hold **real countries only** (`wbcountries`);
World Bank aggregates such as `AFE` or `WLD` are dropped. Region and
income-group comparisons are made from member countries using
`wbcountries`. `year` is `NA` for static CTF rows.

``` r
# Kenya's dynamic CTF on the Degree of Integrity indicators
cgjr_ctf |>
  filter(unit_code == "KEN", ctf_type == "dynamic", leaf == "degree_of_integrity")
```

## Taxonomy and coverage

The taxonomy has 4 clusters, 11 subclusters and 14 leaves: Public
Financial Management branches into four sub-subclusters, and every other
subcluster is its own leaf. Indicators per leaf, and how many have
dynamic CTF, static CTF and raw values:

| cluster | leaf | indicators | dynamic | static | raw |
|:---|:---|---:|---:|---:|---:|
| Institutional Environment | Degree of Integrity | 5 | 5 | 5 | 5 |
| Institutional Environment | Transparency and Accountability | 5 | 5 | 5 | 5 |
| Institutional Environment | Justice and Rule of Law | 17 | 16 | 16 | 16 |
| Efficiency and Effectiveness of Core Governance Functions | Budget Cycle and Fiscal Planning | 24 | 0 | 24 | 24 |
| Efficiency and Effectiveness of Core Governance Functions | Domestic Revenue Mobilization | 0 | 0 | 0 | 0 |
| Efficiency and Effectiveness of Core Governance Functions | Public Procurement | 0 | 0 | 0 | 0 |
| Efficiency and Effectiveness of Core Governance Functions | Public Investment Management (PIM) | 0 | 0 | 0 | 0 |
| Efficiency and Effectiveness of Core Governance Functions | Public Sector HRM | 5 | 5 | 5 | 5 |
| Efficiency and Effectiveness of Core Governance Functions | Digital and Data | 5 | 5 | 5 | 5 |
| Efficiency and Effectiveness beyond Core Governance Functions | Market Regulatory Institutions | 6 | 5 | 6 | 6 |
| Efficiency and Effectiveness beyond Core Governance Functions | Service Delivery | 11 | 11 | 11 | 11 |
| Efficiency and Effectiveness beyond Core Governance Functions | State-Owned Enterprises Governance | 6 | 0 | 3 | 3 |
| Context | Political Institutions and Social Cohesion | 21 | 20 | 21 | 21 |
| Context | Social Cohesion, Norms and Cooperation | 5 | 5 | 5 | 5 |

`dynamic` and `static` count the indicators CLIAR benchmarks in that
panel (see `flag_ctf_eligibility()`). A leaf with no indicators yet has
zeros.

Raw values come from these `cliaretl` datasets:

| raw_dataset       | indicators |
|:------------------|-----------:|
| vdem_data         |         30 |
| pefa_assessments  |         21 |
| wjp               |         20 |
| d360_efi_data     |         13 |
| wdi_indicators    |          8 |
| (no variable yet) |          4 |
| pmr               |          3 |
| freedom_house     |          2 |
| spi               |          2 |
| wbl_data          |          2 |
| debt_transparency |          1 |
| gfdb              |          1 |
| gsod              |          1 |
| obs               |          1 |
| press_freedom     |          1 |

## Rebuilding the data

The two CSVs in `data-raw/input/` are the only source of truth for the
taxonomy; see `data-raw/input/README.md`. After editing them, or after
updating `cliaretl`, run from the package root:

``` r
source("data-raw/cgjr.R")   # rebuilds cgjr_taxonomy, cgjr_crosswalk, cgjr_ctf, cgjr_raw
devtools::test()            # data contract tests: every value equals cliaretl's
```

The build prints a checklist, a green ✔ for each check that passes:

    ✔ No duplicate taxonomy leaves.
    ✔ Every crosswalk row sits on a taxonomy leaf.
    ✔ Every variable is in the cliaretl catalogue.
    ✔ Every variable has CTF values in at least one panel.
    ✔ Every variable was found in a raw dataset.
    ✔ No duplicate observations on ctf_type / unit_code / year / variable / leaf.
    ✔ No duplicate observations on unit_code / year / variable / leaf.

A duplicate leaf, a crosswalk row off the taxonomy or a duplicate
observation stops the build (red ✖). A variable outside the `cliaretl`
catalogue, without CTF values, or found in no raw dataset only warns
(!), because an indicator may come from outside `cliaretl`.

`data-raw/wbcountries.R` rebuilds `wbcountries`; run it only when the
World Bank classification file changes.

## Exported functions

The build steps, exported so they are documented and tested:

| function | answers |
|----|----|
| `check_cgjr_mapping()` | Is the crosswalk consistent with the taxonomy and `cliaretl`? |
| `flag_ctf_eligibility()` | Does CLIAR benchmark this variable, dynamic and static? |
| `locate_raw_variables()` | Which dataset holds this variable’s raw values? |
| `pivot_wide_to_long_cgjr()` | Wide country table to CGJR’s long, labelled form. |
| `check_duplicate_obs()` | Does any observation appear twice? |

## Related packages

- [`cliaretl`](https://github.com/WB-PIDA-Data-Science-Shop/cliaretl):
  the upstream CLIAR data
- [`cliarappak`](https://github.com/WB-PIDA-Data-Science-Shop/cliarappak):
  the CLIAR benchmarking dashboard
- `cgjrapp`: the CGJR dashboard that uses this package

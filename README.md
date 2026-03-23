
<!-- README.md is generated from README.Rmd. Please edit that file -->

# cgjrdata

<!-- badges: start -->

[![R-CMD-check](https://github.com/WB-PIDA-Data-Science-Shop/cgjrdata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/WB-PIDA-Data-Science-Shop/cgjrdata/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/WB-PIDA-Data-Science-Shop/cgjrdata/graph/badge.svg)](https://app.codecov.io/gh/WB-PIDA-Data-Science-Shop/cgjrdata)
<!-- badges: end -->

`cgjrdata` is the data preparation package for the **World Bank Country
Jobs and Growth Report (CGJR)**. It pulls, processes and packages
indicator data from the `cliaretl` source package into four structured,
lazyloaded objects ready for consumption by the `cgjrapp` Shiny
dashboard.

## Analytical Framework

The CGJR framework covers **135 indicators** organised into **4
clusters** and **13 subclusters**:

| \# | Cluster | Subclusters |
|----|----|----|
| 1 | Institutional Environment | Degree of Integrity, Transparency & Accountability, Justice & Rule of Law, Social Cohesion Norms & Cooperation |
| 2 | Political Institutions | Political Institutions |
| 3 | Center of Government | Public Financial Management, Public Sector HRM, Digital & Data |
| 4 | Sectors / Service Delivery | Business Environment, Service Delivery, SOE Corporate Governance, Labor & Social Protection, Energy & Environment |

## Installation

`cgjrdata` depends on `cliaretl`, an internal World Bank package hosted
on GitHub. Install both with:

``` r
# install.packages("pak")
pak::pak("WB-PIDA-Data-Science-Shop/cliaretl")
pak::pak("WB-PIDA-Data-Science-Shop/cgjrdata")
```

You will need a GitHub Personal Access Token (PAT) with access to the
`WB-PIDA-Data-Science-Shop` organisation.

## Package Objects

Four objects are lazyloaded when you attach the package:

``` r
library(cgjrdata)
```

### `rawdata_list`

Nested list of raw (un-normalised) source panels, keyed by cluster and
subcluster:

``` r
# Access a specific subcluster
rawdata_list$institutional_environment$degree_of_integrity
```

### `ctfdata_list`

Nested list of Closeness-to-Frontier (CTF) dynamic scores (0–1 scale,
higher = closer to best-practice frontier). Each subcluster tibble also
carries three computed columns:

- `score` — row mean of all indicator columns (`na.rm = TRUE`)
- `var_count` — total number of indicators in the subcluster
- `nonna_count` — number of non-NA indicators used per row

``` r
ctfdata_list$institutional_environment$degree_of_integrity
```

### `metadata_tbl`

A single combined tibble with one row per indicator, containing variable
names, descriptions, sources, cluster/subcluster assignments and
benchmarking flags.

``` r
metadata_tbl |> dplyr::filter(subcluster == "Degree of Integrity")
```

### `institutional_averages_tbl`

The primary dataset for the dashboard overview page. One row per
`country_code × country_name × year`, with cluster scores and an overall
score:

``` r
institutional_averages_tbl
#> # A tibble: ...
#> country_code  country_name  year  institutional_environment_score
#>   political_institutions_score  center_of_government_score
#>   sectors_service_delivery_score  overall_score
```

**Aggregation logic (equal weight per subcluster):**

1.  Subcluster score = row mean of its CTF indicator columns
2.  Cluster score = mean of its subcluster scores
3.  Overall score = mean of the four cluster scores

## Score Computation Functions

Three exported helper functions power the aggregation:

``` r
# Add score/var_count/nonna_count to a single subcluster tibble
add_subcluster_score(tbl)

# Apply to all subclusters in ctfdata_list
ctfdata_list <- score_ctfdata_list(ctfdata_list)

# Compute cluster + overall averages → institutional_averages_tbl
institutional_averages_tbl <- compute_cluster_averages(ctfdata_list)
```

## Rebuilding the Data

To regenerate all package data from source:

``` r
# 1. Build all raw + CTF .rds files
source("analysis/00-build_all_datasets.r")

# 2. Combine into lazyloaded package objects
source("analysis/01-combine-lazyload.R")

# 3. Regenerate documentation
devtools::document()
```

## Data Sources

| Source                | Coverage       | Key indicators                     |
|-----------------------|----------------|------------------------------------|
| V-Dem                 | 1990–2024      | Democracy, corruption, rule of law |
| WJP Rule of Law Index | Multiple years | Rule of law, governance            |
| PEFA                  | 2015–2025      | Public financial management        |
| RISE                  | 2010–2021      | Energy regulation                  |
| OECD PMR / EPL        | 2018, 2023     | Product & labour market regulation |
| Fraser Institute      | Multiple years | Economic freedom                   |
| Heritage Foundation   | Multiple years | Economic freedom                   |
| WDI / WBL / GTMI      | Multiple years | Various                            |

## Related Packages

- [`cliaretl`](https://github.com/WB-PIDA-Data-Science-Shop/cliaretl) —
  upstream source data package
- `cgjrapp` — Shiny dashboard consuming this package *(in development)*

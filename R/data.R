# ============================================================================
# Package data documentation
# ============================================================================
# The five lazyloaded objects shipped by cgjrdata:
#
#   cgjr_taxonomy   the leaf-node hierarchy of the CGJR analytical taxonomy
#   cgjr_crosswalk  every indicator's placement in it, annotated against cliaretl
#   cgjr_ctf        long Closeness-to-Frontier values, country grain
#   cgjr_raw        long raw source values, country grain
#   wbcountries     World Bank country classifications (regions, income groups)
#
# All but wbcountries are built by data-raw/cgjr.R; wbcountries by
# data-raw/wbcountries.R.


#' CGJR taxonomy - leaf nodes
#'
#' @description
#' One row per **leaf** of the CGJR analytical taxonomy: the finest level at
#' which indicators are grouped. For most subclusters the leaf is the
#' subcluster itself; for Public Financial Management the leaves are its four
#' sub-subclusters. The table lists the *full* hierarchy, including leaves
#' that have no indicators yet. Row order is display order.
#'
#' `cluster`, `subcluster` and `sub_subcluster` are snake_case keys used by
#' every other CGJR table. A leaf's single key, `leaf`, is
#' `dplyr::coalesce(sub_subcluster, subcluster)` and is unique.
#'
#' @format A tibble with one row per leaf (14 rows) and 9 columns:
#' \describe{
#'   \item{`cluster`}{Cluster key: `institutional_environment`,
#'     `core_governance_functions`, `beyond_core_governance_functions` or
#'     `context`.}
#'   \item{`cluster_num`}{Cluster number, 1-4 (integer).}
#'   \item{`cluster_name`}{Cluster display name.}
#'   \item{`subcluster`}{Subcluster key.}
#'   \item{`subcluster_num`}{Subcluster number within its cluster (integer).}
#'   \item{`subcluster_name`}{Subcluster display name.}
#'   \item{`sub_subcluster`}{Sub-subcluster key; `NA` except for the four
#'     Public Financial Management leaves.}
#'   \item{`sub_subcluster_num`}{Sub-subcluster number (integer), or `NA`.}
#'   \item{`sub_subcluster_name`}{Sub-subcluster display name, or `NA`.}
#' }
#'
#' @seealso `cgjr_crosswalk` for the indicators on each leaf.
#' @source `data-raw/input/cgjr_taxonomy.csv`, via `data-raw/cgjr.R`.
#'
#' @examples
#' # Leaves per cluster
#' dplyr::count(cgjr_taxonomy, cluster_name)
"cgjr_taxonomy"


#' CGJR indicator crosswalk - each indicator's place in the taxonomy
#'
#' @description
#' One row per **indicator x leaf**: which variable measures each CGJR
#' indicator and where it sits in the taxonomy. It is the hand-edited
#' `data-raw/input/cgjr_crosswalk.csv`, checked with [check_cgjr_mapping()]
#' and annotated with taxonomy names, `cliaretl` descriptions, CLIAR
#' benchmarking eligibility ([flag_ctf_eligibility()]) and the dataset holding
#' each variable's raw values ([locate_raw_variables()]).
#'
#' Every CSV row is kept, including indicators with no confirmed variable
#' yet (`variable = NA`); `cgjr_ctf` and `cgjr_raw` simply have no rows for
#' them. A variable may sit on more than one leaf; it then appears once per
#' leaf here and in the long tables.
#'
#' The crosswalk, not `cliaretl`'s own family grouping, defines the
#' taxonomy: an indicator can sit under a subcluster that differs from its
#' CLIAR family.
#'
#' @format A tibble with one row per indicator x leaf and 20 columns:
#' \describe{
#'   \item{`cluster`, `subcluster`, `sub_subcluster`}{Taxonomy keys, as in
#'     `cgjr_taxonomy`.}
#'   \item{`leaf`}{`coalesce(sub_subcluster, subcluster)`.}
#'   \item{`indicator_num`}{Position within the leaf (integer).}
#'   \item{`indicator`}{Indicator name, as the methodology specifies it.}
#'   \item{`source`}{Data source as stated in the specification (free text).}
#'   \item{`variable`}{Variable code, or `NA` if none is confirmed.}
#'   \item{`note`}{Free-text note on how the code was resolved.}
#'   \item{`cluster_num`, `cluster_name`, `subcluster_num`,
#'     `subcluster_name`, `sub_subcluster_num`, `sub_subcluster_name`}{From
#'     `cgjr_taxonomy`.}
#'   \item{`description`, `description_short`}{From
#'     [cliaretl::db_variables_final]; `NA` for variables not in it.}
#'   \item{`in_dynamic`, `in_static`}{Logical: CLIAR benchmarks the variable
#'     in the dynamic / static CTF panel, so `cgjr_ctf` has rows for it. See
#'     [flag_ctf_eligibility()].}
#'   \item{`raw_dataset`}{Name of the `cliaretl` dataset holding the raw
#'     values, or `NA` if none does.}
#' }
#'
#' @seealso `cgjr_taxonomy`, `cgjr_ctf`, `cgjr_raw`
#' @source `data-raw/input/cgjr_crosswalk.csv` + `cgjr_taxonomy` + `cliaretl`,
#'   via `data-raw/cgjr.R`.
#'
#' @examples
#' # Indicators per leaf, and how many CLIAR benchmarks dynamically
#' dplyr::summarise(cgjr_crosswalk, indicators = dplyr::n(),
#'                  dynamic = sum(in_dynamic), .by = leaf)
"cgjr_crosswalk"


#' CGJR Closeness-to-Frontier values - long, country grain
#'
#' @description
#' Closeness-to-Frontier (CTF) values for every benchmarked CGJR indicator,
#' one row per **country x year x ctf_type x variable x leaf**. Higher means
#' closer to the best observed performance. Values are copied unchanged from
#' [cliaretl::closeness_to_frontier_dynamic] and
#' [cliaretl::closeness_to_frontier_static], so cgjrapp shows exactly what
#' the CLIAR app shows for a shared indicator.
#'
#' Only variables CLIAR benchmarks in a panel appear for that panel
#' (`cgjr_crosswalk$in_dynamic` / `in_static`), and only real countries
#' (`wbcountries`): World Bank aggregates are dropped. Region and income-group
#' comparisons are made from the member countries, using `wbcountries`.
#'
#' Each panel is complete: every country-year in it has a row for every
#' eligible variable, with `ctf = NA` where the value is missing. Keep those
#' rows; cgjrapp's screen for indicators missing for the base country relies
#' on them.
#'
#' Static values lie in `[0, 1]`. Dynamic values usually do, but `cliaretl`
#' produces a few just outside at the edges of its window (between about
#' -0.11 and 1.13 in 2013 and 2024).
#'
#' @format A tibble with 12 columns:
#' \describe{
#'   \item{`unit_level`}{Always `"country"`.}
#'   \item{`unit_code`}{ISO3 country code.}
#'   \item{`unit_name`}{Country name, from `wbcountries$economy`.}
#'   \item{`year`}{Integer year for `ctf_type == "dynamic"`; `NA` for
#'     `"static"`, which is a single cross-section.}
#'   \item{`ctf_type`}{`"dynamic"` or `"static"`.}
#'   \item{`cluster`, `subcluster`, `sub_subcluster`, `leaf`}{Taxonomy keys.
#'     Join `cgjr_taxonomy` for numbers and display names.}
#'   \item{`indicator`}{Indicator name, from `cgjr_crosswalk`.}
#'   \item{`variable`}{Variable code.}
#'   \item{`ctf`}{CTF value (double), `NA` when missing.}
#' }
#'
#' The tibble carries an attribute, `cliaretl_version`, recording the
#' `cliaretl` version it was built from.
#'
#' @seealso `cgjr_raw`, `cgjr_crosswalk`, [pivot_wide_to_long_cgjr()]
#' @source The `cliaretl` CTF panels + `cgjr_crosswalk`, via `data-raw/cgjr.R`.
#'
#' @examples
#' # Ghana's static CTF on the Degree of Integrity indicators
#' dplyr::filter(cgjr_ctf, unit_code == "GHA", ctf_type == "static",
#'               leaf == "degree_of_integrity")
"cgjr_ctf"


#' CGJR raw source values - long, country grain
#'
#' @description
#' Raw (not rescaled) values of every CGJR indicator, in each source's own
#' units, one row per **country x year x variable x leaf**. They are for
#' display and download in cgjrapp, never for benchmarking: units differ
#' across indicators (indices, percentages, counts), so they are not
#' aggregated across countries.
#'
#' Each variable is read from the `cliaretl` dataset named in
#' `cgjr_crosswalk$raw_dataset`. Only observed values for real countries
#' (`wbcountries`) are kept: no `NA` rows, no World Bank aggregates. Raw
#' coverage does not depend on CTF eligibility, so an indicator with no CTF
#' values can still have raw values here.
#'
#' @format A tibble with 11 columns: the columns of `cgjr_ctf` without
#'   `ctf_type`, and `value` in place of `ctf`.
#' \describe{
#'   \item{`unit_level`}{Always `"country"`.}
#'   \item{`unit_code`, `unit_name`}{ISO3 code and country name, from
#'     `wbcountries`.}
#'   \item{`year`}{Integer year.}
#'   \item{`cluster`, `subcluster`, `sub_subcluster`, `leaf`}{Taxonomy keys.}
#'   \item{`indicator`}{Indicator name, from `cgjr_crosswalk`.}
#'   \item{`variable`}{Variable code.}
#'   \item{`value`}{Raw value (double), in the indicator's own units.}
#' }
#'
#' @seealso `cgjr_ctf`, `cgjr_crosswalk`, [locate_raw_variables()]
#' @source `cliaretl` source datasets + `cgjr_crosswalk`, via `data-raw/cgjr.R`.
#'
#' @examples
#' # Kenya's most recent raw value per indicator on Public Sector HRM
#' hrm <- dplyr::filter(cgjr_raw, unit_code == "KEN", leaf == "public_sector_hrm")
#' dplyr::slice_max(hrm, year, by = variable)
"cgjr_raw"


#' World Bank country classifications
#'
#' @description
#' The World Bank's classification of economies by income group, lending
#' category and region, using the regional structure that splits Sub-Saharan
#' Africa into Africa Eastern and Southern (AFE) and Africa Western and
#' Central (AFW). It defines which codes count as countries in `cgjr_ctf` and
#' `cgjr_raw`, and which countries make up each region and income group when
#' cgjrapp compares a country with a group.
#'
#' @format A tibble with 218 rows and 6 columns:
#' \describe{
#'   \item{`economy`}{Name of the economy or territory.}
#'   \item{`country_code`}{Three-letter ISO3 code, unique.}
#'   \item{`income_group`}{`"Low income"`, `"Lower middle income"`,
#'     `"Upper middle income"`, `"High income"`, or `NA` where the World Bank
#'     gives none.}
#'   \item{`lending_category`}{`"IDA"`, `"IBRD"`, `"Blend"`, or `NA` for
#'     economies not eligible for lending.}
#'   \item{`region_code`}{`AFE`, `AFW`, `EAP`, `ECA`, `LAC`, `MENAAP`, `SAR`
#'     or `NAC`.}
#'   \item{`region`}{Region name for `region_code`.}
#' }
#'
#' @source World Bank Country and Lending Groups Classification (October
#'   2025), `data-raw/input/CLASS_2025_10_07.xlsx`, via
#'   `data-raw/wbcountries.R`.
#'
#' @examples
#' # Countries per region
#' dplyr::count(wbcountries, region_code)
"wbcountries"

# ============================================================================
# Package data documentation
# ============================================================================
# The six lazyloaded objects shipped by cgjrdata:
#
#   cgjr_taxonomy   the leaf-node hierarchy of the CGJR analytical taxonomy
#   cgjr_crosswalk  every indicator's placement in it, annotated + validated
#   wbcountries     World Bank country classifications (regions, income groups)
#   cgjr_ctf        long, indicator-grain Closeness-to-Frontier values
#   cgjr_scores     long, node-grain equal-weight rollup scores
#   cgjr_raw        long, indicator-grain raw source values (country only)
#
# cgjr_taxonomy / cgjr_crosswalk are built by
# data-raw/source/00b-cgjr-taxonomy-crosswalk.R; the three long tibbles by
# analysis/01-build-tidy-data.R. See PLAN.md for the full column spec.


#' CGJR taxonomy - leaf nodes
#'
#' @description
#' One row per **leaf node** of the CGJR analytical taxonomy: the finest level
#' at which indicators are grouped. For most subclusters the leaf is the
#' subcluster itself; for Public Financial Management the leaves are its four
#' sub-subclusters. The table enumerates the *full* hierarchy, including nodes
#' that are intentionally still empty ("coming soon").
#'
#' `cluster`, `subcluster` and `sub_subcluster` are snake_case keys - they are
#' the join keys used throughout `cgjr_ctf`, `cgjr_scores` and `cgjr_raw`. The
#' derived leaf key used by the build is
#' `dplyr::coalesce(sub_subcluster, subcluster)` (see [resolve_leaf()]).
#'
#' @format A tibble with one row per leaf node (14 rows) and the columns:
#' \describe{
#'   \item{`cluster`}{snake_case cluster key: `institutional_environment`,
#'     `core_governance_functions`, `beyond_core_governance_functions`,
#'     `context`.}
#'   \item{`cluster_num`}{Cluster number 1-4.}
#'   \item{`cluster_name`}{Cluster display name.}
#'   \item{`subcluster`}{snake_case subcluster key.}
#'   \item{`subcluster_num`}{Subcluster number within the cluster.}
#'   \item{`subcluster_name`}{Subcluster display name.}
#'   \item{`sub_subcluster`}{snake_case sub-subcluster key, or `NA` for every
#'     leaf except the four Public Financial Management sub-subclusters.}
#'   \item{`sub_subcluster_num`}{Sub-subcluster number, or `NA`.}
#'   \item{`sub_subcluster_name`}{Sub-subcluster display name, or `NA`.}
#' }
#'
#' @seealso `cgjr_crosswalk`, [resolve_leaf()], [check_crosswalk_schema()]
#' @source `data-raw/input/cgjr_taxonomy.csv` via
#'   `data-raw/source/00b-cgjr-taxonomy-crosswalk.R`.
"cgjr_taxonomy"


#' CGJR taxonomy - annotated indicator crosswalk
#'
#' @description
#' The single source of truth for the CGJR taxonomy: one row per
#' (indicator x leaf node) assignment. Maintained as a human-editable CSV,
#' `data-raw/input/cgjr_crosswalk.csv` (edit in a spreadsheet; the build reads
#' it, checks its structure with [check_crosswalk_schema()], annotates it with
#' [build_crosswalk()], and reports eligibility gaps with
#' [validate_crosswalk()]).
#'
#' Every CSV row is kept, including the handful the team specified but for
#' which no `cliaretl` code has been confirmed (`variable = NA`,
#' `cliaretl_status == "unresolved"`) - so the table stays a complete record
#' of the taxonomy. `cgjr_ctf` / `cgjr_raw` simply produce no rows for those.
#' This object absorbs what used to be a separate `metadata_tbl`; it is the
#' single per-(indicator x leaf) reference.
#'
#' An indicator may appear under a subcluster that is **not** its `cliaretl`
#' `family_name` - the crosswalk, not `cliaretl`'s family column, defines the
#' taxonomy.
#'
#' @format A tibble with one row per crosswalk assignment. Columns, by source:
#' \describe{
#'   \item{CSV}{`cluster`, `subcluster`, `sub_subcluster` (snake_case taxonomy
#'     keys; `sub_subcluster` is `NA` outside Public Financial Management),
#'     `indicator_num` (position within the leaf), `indicator` (human name),
#'     `source` (source as stated in the specification), `variable` (the
#'     `cliaretl` code, or `NA` if unresolved), `note` (free-text caveat).}
#'   \item{derived}{`leaf` = `dplyr::coalesce(sub_subcluster, subcluster)`.}
#'   \item{join to `cgjr_taxonomy`}{`cluster_num`, `cluster_name`,
#'     `subcluster_num`, `subcluster_name`, `sub_subcluster_num`,
#'     `sub_subcluster_name`.}
#'   \item{join to [cliaretl::db_variables_final]}{`var_name`, `var_level`,
#'     `family_var`, `family_name`, `family_order`, `processing`,
#'     `description`, `description_short`, `etl_source`, `benchmarked_ctf`,
#'     `benchmark_dynamic_indicator`, `benchmark_dynamic_family_aggregate`,
#'     `benchmark_static_family_aggregate_download` - all `NA` for unresolved
#'     rows.}
#'   \item{eligibility flags ([classify_crosswalk()])}{`in_cliaretl`,
#'     `in_dynamic_panel`, `in_static_panel`, `dynamic_eligible`
#'     (`in_dynamic_panel` and `benchmark_dynamic_indicator == "Yes"`),
#'     `static_eligible` (`in_static_panel`), `cliaretl_status`
#'     (`"resolved"` / `"unresolved"` / `"not_in_cliaretl"`).}
#' }
#'
#' @seealso `cgjr_taxonomy`, [build_crosswalk()], [classify_crosswalk()],
#'   [validate_crosswalk()], [build_ctf_tbl()], [build_raw_tbl()]
#' @source `data-raw/input/cgjr_crosswalk.csv` + `cgjr_taxonomy` +
#'   [cliaretl::db_variables_final], via
#'   `data-raw/source/00b-cgjr-taxonomy-crosswalk.R`.
"cgjr_crosswalk"


#' CGJR Closeness-to-Frontier values - long, indicator grain
#'
#' @description
#' Long tidy tibble of Closeness-to-Frontier (CTF) values, one row per
#' **unit x year x ctf_type x leaf x indicator**. Higher = closer to best
#' observed practice. Built by [build_ctf_tbl()] (country rows, sliced from the
#' `cliaretl` CTF panels for every `dynamic_eligible` / `static_eligible`
#' crosswalk variable) with region / income-group rows appended by
#' [aggregate_to_groups()].
#'
#' CTF windows, direction and indicator eligibility are already enforced
#' upstream in [cliaretl::closeness_to_frontier_dynamic] /
#' [cliaretl::closeness_to_frontier_static]; this object only slices and
#' reshapes. Values are *mostly* in `[0, 1]` but not strictly - a country
#' ahead of the reference frontier can exceed 1 (observed range runs to
#' ~1.13).
#'
#' Crosswalk rows that are unresolved, not in `cliaretl`, or not eligible for
#' a given `ctf_type` contribute no rows for that type. A `variable` reused
#' across two leaves fans out to one row per `(leaf, indicator)`.
#'
#' @format A tibble, one row per unit x year x ctf_type x leaf x indicator:
#' \describe{
#'   \item{`unit_level`}{`"country"`, `"region"`, or `"income_group"`.}
#'   \item{`unit_code`}{ISO3 country code, World Bank `region_code` (e.g.
#'     `"AFE"`), or an income-group slug (e.g. `"high_income"`).}
#'   \item{`unit_name`}{Country / region / income-group display name.}
#'   \item{`year`}{Integer calendar year for `ctf_type == "dynamic"`; **`NA`
#'     for `ctf_type == "static"`** (the static panel is a year-less
#'     snapshot).}
#'   \item{`ctf_type`}{`"dynamic"` or `"static"`.}
#'   \item{`cluster`, `subcluster`, `sub_subcluster`, `leaf`}{snake_case
#'     taxonomy keys (`sub_subcluster` is `NA` outside Public Financial
#'     Management; `leaf` = `coalesce(sub_subcluster, subcluster)`). Join
#'     `cgjr_taxonomy` for numbers / display names.}
#'   \item{`indicator`}{Human-readable indicator name (from `cgjr_crosswalk`).}
#'   \item{`variable`}{The `cliaretl` variable code.}
#'   \item{`ctf`}{CTF value (numeric, ~`[0, 1]`).}
#'   \item{`n_inputs`, `n_inputs_obs`}{`NA` on country rows; on region /
#'     income-group rows, the number of the group's countries present in the
#'     table and, of those, how many had a non-`NA` `ctf`.}
#' }
#'
#' Region / income-group rows are `agg()` (default [stats::median], for CLIAR
#' fidelity) across the group's countries of the indicator's country-level
#' `ctf`, computed independently per row - not derived from any node score.
#'
#' @seealso `cgjr_scores`, `cgjr_raw`, [build_ctf_tbl()],
#'   [aggregate_to_groups()], [cliaretl::closeness_to_frontier_dynamic]
#' @source `cgjr_crosswalk` + the `cliaretl` CTF panels, via
#'   `analysis/01-build-tidy-data.R`.
"cgjr_ctf"


#' CGJR rollup scores - long, node grain
#'
#' @description
#' Long tidy tibble of equal-weight rollup scores, one row per
#' **unit x year x ctf_type x node**, where a node is a real taxonomy tier
#' (`subcluster` / `sub_subcluster` / `cluster` / `overall`). Built by
#' [roll_up_scores()] from the country rows of `cgjr_ctf`, with region /
#' income-group rows appended by [aggregate_to_groups()].
#'
#' **Rollup (order ii, within country).** A leaf's score is the mean of its
#' indicators' `ctf` values; a branching subcluster's score (Public Financial
#' Management only) is the mean of its `sub_subcluster` scores; a cluster's
#' score is the mean of its subclusters' scores; `overall` is the mean of the
#' cluster scores. `NA` is lenient (`na.rm = TRUE`) at every stage; all
#' children missing yields `NA` (never `NaN`). The finest grain is scaffolded
#' against every `cgjr_taxonomy` leaf first, so a leaf with zero eligible
#' indicators for a `ctf_type` still gets a row (`score = NA`, `n_inputs = 0`)
#' rather than silently vanishing.
#'
#' **There is no stored "is this the finest grain" flag.** Every plain
#' subcluster reports once, at `node_level == "subcluster"`, and *is* the
#' finest grain for its branch; only Public Financial Management also carries
#' `node_level == "sub_subcluster"` rows one level finer. To select every
#' finest-grain node regardless of depth:
#'
#' ```r
#' branching <- unique(cgjr_scores$subcluster[cgjr_scores$node_level == "sub_subcluster"])
#' finest <- cgjr_scores[cgjr_scores$node_level %in% c("subcluster", "sub_subcluster") &
#'                       !(cgjr_scores$node_level == "subcluster" &
#'                         cgjr_scores$subcluster %in% branching), ]
#' ```
#'
#' @format A tibble, one row per unit x year x ctf_type x node:
#' \describe{
#'   \item{`unit_level`, `unit_code`, `unit_name`, `year`, `ctf_type`}{as
#'     `cgjr_ctf` (`year` is `NA` for `ctf_type == "static"`).}
#'   \item{`node_level`}{`"subcluster"`, `"sub_subcluster"` (Public Financial
#'     Management only), `"cluster"`, or `"overall"`.}
#'   \item{`node`}{The operative key at that level: the subcluster key, the
#'     sub_subcluster key, the cluster key, or the literal `"overall"`.}
#'   \item{`cluster`, `subcluster`, `sub_subcluster`}{Ancestry, filled to the
#'     node's depth and `NA` deeper (`overall` rows have all three `NA`).}
#'   \item{`score`}{Rollup score (numeric, ~`[0, 1]`).}
#'   \item{`n_inputs`}{Count of the node's immediate children (indicators for
#'     a finest-grain node; sub_subclusters for PFM's subcluster row;
#'     subclusters for a cluster; clusters for `overall`).}
#'   \item{`n_inputs_obs`}{Of those, how many had a non-`NA` value for this
#'     row. On region / income-group rows, `n_inputs` / `n_inputs_obs` count
#'     the group's countries instead.}
#' }
#'
#' Because the cross-country step takes a median (not a linear function) of
#' each node's country-level `score`, a region's `cgjr_scores` rows will not
#' arithmetically reconcile with a recomputation from its `cgjr_ctf` rows.
#' That is expected.
#'
#' @seealso `cgjr_ctf`, [roll_up_scores()], [aggregate_to_groups()]
#' @source Rolled up from the country rows of `cgjr_ctf`, via
#'   `analysis/01-build-tidy-data.R`.
"cgjr_scores"


#' CGJR raw source values - long, indicator grain, country only
#'
#' @description
#' Long tidy tibble of raw (un-normalised) source values, one row per
#' **country x year x leaf x indicator**. Built by [build_raw_tbl()], which
#' pulls every resolved crosswalk `variable` from its original provider
#' dataset via [extract_cliar_data()] with `type = "raw"`.
#'
#' There is **no `ctf_type`** (raw has none) and **no group aggregation**: raw
#' values are for display / download in `cgjrapp`, never benchmarking, and
#' their units are heterogeneous (indices, percentages, counts) so a regional
#' median of them would be meaningless. `unit_level` is always `"country"`
#' (kept for schema parity with `cgjr_ctf`).
#'
#' Raw coverage is independent of CTF eligibility: a leaf that is empty in
#' `cgjr_ctf` (e.g. Public Financial Management, SOE governance) can still
#' carry raw PEFA / OECD-PMR values here. Variables with no dedicated raw
#' source (family aggregates, some static-only codes) are dropped.
#'
#' @format A tibble, one row per country x year x leaf x indicator - the same
#'   columns as `cgjr_ctf` minus `ctf_type` / `n_inputs` / `n_inputs_obs`,
#'   with `value` in place of `ctf`:
#' \describe{
#'   \item{`unit_level`}{always `"country"`.}
#'   \item{`unit_code`, `unit_name`}{ISO3 code and country name.}
#'   \item{`year`}{Integer calendar year.}
#'   \item{`cluster`, `subcluster`, `sub_subcluster`, `leaf`}{snake_case
#'     taxonomy keys.}
#'   \item{`indicator`}{Human-readable indicator name.}
#'   \item{`variable`}{The `cliaretl` variable code.}
#'   \item{`value`}{Raw source value, in the indicator's own units.}
#' }
#'
#' @seealso `cgjr_ctf`, [build_raw_tbl()], [extract_cliar_data()]
#' @source `cgjr_crosswalk` + `cliaretl` raw source datasets, via
#'   `analysis/01-build-tidy-data.R`.
"cgjr_raw"


#' World Bank country classifications
#'
#' @description
#' The World Bank's official classification of economies: income group,
#' lending category and region. Uses the updated regional structure that
#' splits Sub-Saharan Africa into Africa Eastern and Southern (AFE) and Africa
#' Western and Central (AFW). Supplies the region / income-group membership
#' [aggregate_to_groups()] uses to build the non-country rows of `cgjr_ctf`
#' and `cgjr_scores`.
#'
#' @format A tibble with 218 rows and 6 variables:
#' \describe{
#'   \item{`economy`}{Full name of the economy or territory.}
#'   \item{`country_code`}{Three-letter ISO3 code.}
#'   \item{`income_group`}{`"Low income"`, `"Lower middle income"`,
#'     `"Upper middle income"`, or `"High income"`.}
#'   \item{`lending_category`}{`"IDA"`, `"IBRD"`, `"Blend"`, or `NA` for
#'     high-income economies not eligible for lending.}
#'   \item{`region_code`}{`AFE`, `AFW`, `EAP`, `ECA`, `LAC`, `MENAAP`, `SAR`,
#'     or `NAC`.}
#'   \item{`region`}{Full region name corresponding to `region_code`.}
#' }
#'
#' @seealso [aggregate_to_groups()], [join_wb_classifications()]
#' @source World Bank Country and Lending Groups Classification (October
#'   2025), `data-raw/input/CLASS_2025_10_07.xlsx`, via
#'   `data-raw/source/00a-prepare-country-list.R`.
#'
#' @examples
#' dplyr::filter(wbcountries, region_code == "AFE")
#' dplyr::count(wbcountries, region)
"wbcountries"

# ============================================================================
# Package data documentation
# ============================================================================

#' CGJR taxonomy — leaf nodes
#'
#' @description
#' One row per **leaf node** of the CGJR analytical taxonomy: the level at
#' which indicators are grouped and scored. For most subclusters the leaf is
#' the subcluster itself; for Public Financial Management the leaves are its
#' four sub-subclusters. The table enumerates the *full* hierarchy, including
#' nodes that are intentionally empty ("coming soon").
#'
#' The `cluster`, `subcluster` and `sub_subcluster` columns are snake_case
#' keys — they are the list keys used to index `rawdata_list`, `ctfdata_list`
#' and the region/income aggregates.
#'
#' @format A tibble with one row per leaf node and the columns:
#' \describe{
#'   \item{`cluster`}{snake_case cluster key: `institutional_environment`,
#'     `core_governance_functions`, `beyond_core_governance_functions`,
#'     `context`.}
#'   \item{`cluster_num`}{Cluster number 1–4.}
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
#' @seealso `cgjr_crosswalk`, [validate_crosswalk()], [build_ctfdata_list()]
#' @source `data-raw/source/00b-cgjr-taxonomy-crosswalk.R`
"cgjr_taxonomy"


#' CGJR taxonomy — indicator crosswalk
#'
#' @description
#' The single source of truth for the CGJR taxonomy: one row per
#' (indicator × leaf node) assignment. Maintained as a human-editable CSV,
#' `data-raw/crosswalk/cgjr_crosswalk.csv` (edit in a spreadsheet; the build
#' reads it, checks its structure with [check_crosswalk_schema()], and
#' validates the codes with [validate_crosswalk()]). Every `variable` is
#' resolved against live [cliaretl::db_variables_final] text — codes are never
#' guessed. Indicators the team specified but for which no `cliaretl` code
#' could be confirmed are kept with `variable = NA` so the table stays a
#' complete record of the taxonomy; the build functions drop these rows and
#' [validate_crosswalk()] reports them.
#'
#' An indicator may appear under a subcluster that is **not** its `cliaretl`
#' `family_name` (e.g. the Digital Citizen Engagement Index sits in
#' Transparency and Accountability). This is expected — the crosswalk, not
#' `cliaretl`'s family column, defines the taxonomy.
#'
#' @format A tibble with one row per crosswalk assignment and the columns:
#' \describe{
#'   \item{`cluster`, `subcluster`, `sub_subcluster`}{snake_case taxonomy
#'     keys (join keys into `cgjr_taxonomy`). `sub_subcluster` is `NA` outside
#'     Public Financial Management.}
#'   \item{`indicator_num`}{Indicator's position within its leaf node.}
#'   \item{`indicator`}{Human-readable indicator name as specified by the team.}
#'   \item{`source`}{Data source as stated in the taxonomy specification.}
#'   \item{`variable`}{Resolved `cliaretl` variable code, or `NA` if unresolved.}
#'   \item{`status`}{Editor's judgement: `"ok"` (code confirmed), `"verify"`
#'     (code assigned but a caveat in `note` remains), or `"unresolved"` (no
#'     code — `variable` is `NA`). Distinct from
#'     `validate_crosswalk()$check`, which is computed against `cliaretl`.}
#'   \item{`note`}{Free-text caveat: how the code was resolved, an outstanding
#'     check, or why a row is unresolved.}
#' }
#'
#' @seealso `cgjr_taxonomy`, [validate_crosswalk()], [build_ctfdata_list()],
#'   [build_rawdata_list()], [build_metadata_tbl()]
#' @source `data-raw/source/00b-cgjr-taxonomy-crosswalk.R`
"cgjr_crosswalk"


#' Raw indicator data — all clusters
#'
#' @description
#' A nested list of country-year panels of raw (un-normalised) source values,
#' one leaf per node of `cgjr_taxonomy`. Assembled from the underlying
#' provider datasets via [extract_cliar_data()] with `type = "raw"`, driven by
#' `cgjr_crosswalk`.
#'
#' The list follows the taxonomy hierarchy. Most paths are two levels,
#' `rawdata_list[[cluster]][[subcluster]]`; Public Financial Management is
#' three, `rawdata_list[["core_governance_functions"]][["public_financial_management"]][[sub_subcluster]]`:
#'
#' \describe{
#'   \item{`institutional_environment`}{`degree_of_integrity`,
#'     `transparency_and_accountability`, `justice_and_rule_of_law`}
#'   \item{`core_governance_functions`}{`public_financial_management`
#'     (→ `budget_cycle_and_fiscal_planning`, `domestic_revenue_mobilization`,
#'     `public_procurement`, `public_investment_management`),
#'     `public_sector_hrm`, `digital_and_data`}
#'   \item{`beyond_core_governance_functions`}{`market_regulatory_institutions`,
#'     `service_delivery`, `soe_governance`}
#'   \item{`context`}{`political_institutions_and_social_cohesion`,
#'     `social_cohesion_norms_and_cooperation`}
#' }
#'
#' Each leaf is a tibble of `country_code`, `country_name`, `year` and one
#' column per indicator that resolves to a raw source. Unlike `ctfdata_list`,
#' raw coverage does not depend on the `benchmark_dynamic_*` flags — Public
#' Financial Management and SOE governance carry raw PEFA / OECD-PMR values
#' here even though their CTF leaves are empty. A leaf whose indicators
#' resolve to no raw source is a zero-row tibble with identifier columns only.
#'
#' @seealso `ctfdata_list`, `metadata_tbl`, `cgjr_crosswalk`
#' @source Assembled from `cliaretl` raw source datasets via
#'   [build_rawdata_list()]. See [cliaretl::db_variables_final] for provenance.
"rawdata_list"


#' CTF dynamic scores — all clusters
#'
#' @description
#' A nested list of Closeness-to-Frontier (CTF) dynamic scores (0–1, higher =
#' closer to best practice), one leaf per node of `cgjr_taxonomy`. Values are
#' sliced from [cliaretl::closeness_to_frontier_dynamic] by
#' [build_ctfdata_list()], driven by `cgjr_crosswalk`.
#'
#' Same hierarchy as `rawdata_list` (two levels, three for Public Financial
#' Management). Each leaf is a tibble with `country_code`, `country_name`,
#' `year`, one CTF column per **dynamic-panel-eligible** indicator, and three
#' summary columns appended by [score_ctfdata_list()]:
#'
#' \describe{
#'   \item{`score`}{Row mean of all indicator columns (`na.rm = TRUE`); `NA`
#'     when every indicator is `NA` for that row.}
#'   \item{`var_count`}{Number of indicator columns in the leaf.}
#'   \item{`nonna_count`}{Number of non-`NA` indicator values used per row.}
#' }
#'
#' **Empty leaves.** A leaf whose indicators are all dynamic-ineligible is a
#' zero-row tibble (`score`, `var_count`, `nonna_count` present but empty).
#' Under the current `cliaretl` this is the case for all four Public Financial
#' Management sub-subclusters and for `soe_governance` — none of their
#' indicators are columns of `closeness_to_frontier_dynamic`.
#'
#' **Family-aggregate caveat.** Every indicator in `digital_and_data`,
#' `market_regulatory_institutions` and `service_delivery` is flagged
#' `benchmark_dynamic_family_aggregate = "No"` in
#' [cliaretl::db_variables_final]. They are included here (they are valid
#' panel columns) but [validate_crosswalk()] warns about them; treat those
#' three subcluster `score` values with caution. See `metadata_tbl$family_aggregate_eligible`.
#'
#' @seealso `rawdata_list`, `metadata_tbl`, `institutional_averages_tbl`,
#'   `cgjr_crosswalk`, [validate_crosswalk()]
#' @source [cliaretl::closeness_to_frontier_dynamic] via [build_ctfdata_list()].
"ctfdata_list"


#' Variable metadata — all clusters
#'
#' @description
#' One row per `cgjr_crosswalk` assignment, joined to `cgjr_taxonomy` and to
#' [cliaretl::db_variables_final]. Every crosswalk row is kept, including
#' unresolved indicators (`variable == NA`) and dynamic-ineligible ones, so
#' the table is a complete record of the taxonomy. Produced by
#' [build_metadata_tbl()].
#'
#' @format A tibble with one row per crosswalk row. Key columns:
#' \describe{
#'   \item{`cluster`, `subcluster`, `sub_subcluster`}{snake_case taxonomy keys.}
#'   \item{`cluster_num`, `subcluster_num`, `sub_subcluster_num`}{Numeric order.}
#'   \item{`cluster_name`, `subcluster_name`, `sub_subcluster_name`}{Display names.}
#'   \item{`indicator`, `indicator_num`}{Indicator name and position.}
#'   \item{`source`}{Source as stated in the taxonomy; `source_cliar` is the
#'     catalogue's own source string.}
#'   \item{`variable`}{Resolved `cliaretl` code, or `NA`.}
#'   \item{`status`}{Editor's judgement from the crosswalk: `"ok"` /
#'     `"verify"` / `"unresolved"`.}
#'   \item{`note`}{Resolution caveat from the crosswalk.}
#'   \item{`var_name`, `description`, `description_short`, `family_name`,
#'     `etl_source`, `benchmarked_ctf`, `benchmark_dynamic_indicator`,
#'     `benchmark_dynamic_family_aggregate`, ...}{Columns carried from
#'     [cliaretl::db_variables_final] (`NA` for unresolved rows).}
#'   \item{`dynamic_indicator_eligible`}{`TRUE` iff
#'     `benchmark_dynamic_indicator == "Yes"` — i.e. the variable can enter
#'     the dynamic panel.}
#'   \item{`family_aggregate_eligible`}{`TRUE` iff
#'     `benchmark_dynamic_family_aggregate` is `"Yes"` or `"Partial"` — i.e.
#'     `cliaretl` sanctions averaging it into a subcluster score.}
#' }
#'
#' @seealso `cgjr_crosswalk`, `ctfdata_list`, [build_metadata_tbl()]
#' @source `cgjr_crosswalk` + [cliaretl::db_variables_final].
"metadata_tbl"


#' Cluster and overall CTF score averages
#'
#' @description
#' A wide tibble of aggregated Closeness-to-Frontier scores at the cluster and
#' overall level, one row per `country_code × country_name × year` present in
#' `ctfdata_list`. Produced by [compute_cluster_averages()].
#'
#' **Aggregation (equal weight per child at every level):**
#' 1. Leaf `score` = row mean of that leaf's CTF indicator columns
#'    (`na.rm = TRUE`), from [add_subcluster_score()].
#' 2. A branch's score = mean of its immediate children's scores. For Public
#'    Financial Management this is the mean of its four sub-subcluster scores;
#'    empty leaves contribute nothing.
#' 3. Cluster score = mean of its subcluster (or branch) scores.
#' 4. `overall_score` = mean of the cluster scores (`na.rm = TRUE`).
#'
#' @format A tibble with one row per `country_code × country_name × year` and:
#' \describe{
#'   \item{`country_code`}{ISO 3-letter country code.}
#'   \item{`country_name`}{Country name.}
#'   \item{`year`}{Calendar year.}
#'   \item{`institutional_environment_score`}{Mean of the Degree of Integrity,
#'     Transparency & Accountability, and Justice & Rule of Law subcluster
#'     scores.}
#'   \item{`core_governance_functions_score`}{Mean of the Public Financial
#'     Management, Public Sector HRM and Digital & Data subcluster scores.
#'     Public Financial Management is currently empty and does not contribute.}
#'   \item{`beyond_core_governance_functions_score`}{Mean of the Market
#'     Regulatory Institutions, Service Delivery and SOE Governance subcluster
#'     scores. SOE Governance is currently empty and does not contribute.}
#'   \item{`context_score`}{Mean of the Political Institutions & Social
#'     Cohesion and Social Cohesion, Norms & Cooperation subcluster scores.}
#'   \item{`overall_score`}{Mean of the four cluster scores (`na.rm = TRUE`).}
#' }
#'
#' @seealso `ctfdata_list`, [score_ctfdata_list()], [compute_cluster_averages()]
#' @source Derived from `ctfdata_list` via [compute_cluster_averages()].
"institutional_averages_tbl"


#' World Bank Country Classifications
#'
#' A dataset containing the World Bank's official country classifications including
#' economy names, country codes, income groups, lending categories, and regional
#' assignments. This dataset uses the World Bank's updated regional classification
#' that splits Sub-Saharan Africa into Eastern/Southern and Western/Central regions.
#'
#' @format A tibble with 218 rows and 6 variables:
#' \describe{
#' \item{economy}{Full name of the economy or territory.}
#' \item{country_code}{Three-letter ISO3 country code.}
#' \item{income_group}{World Bank income classification: "Low income",
#' "Lower middle income", "Upper middle income", or "High income".}
#' \item{lending_category}{World Bank lending category: "IDA" (International Development Association),
#' "IBRD" (International Bank for Reconstruction and Development), "Blend" (IDA and IBRD),
#' or \code{NA} for high-income countries not eligible for lending.}
#' \item{region_code}{Three-letter code for the World Bank region:
#' \itemize{
#'   \item AFE - Africa Eastern and Southern
#'   \item AFW - Africa Western and Central
#'   \item EAP - East Asia & Pacific
#'   \item ECA - Europe & Central Asia
#'   \item LAC - Latin America & Caribbean
#'   \item MENAAP - Middle East, North Africa, Afghanistan & Pakistan
#'   \item SAR - South Asia
#'   \item NAC - North America
#' }}
#' \item{region}{Full name of the World Bank region corresponding to the region_code.}
#' }
#'
#' @details
#' This dataset reflects the World Bank's current operational classification of countries
#' and territories. The regional classification follows the World Bank's updated structure
#' that divides Sub-Saharan Africa into two regions: Africa Eastern and Southern (AFE)
#' and Africa Western and Central (AFW). This provides more granular regional analysis
#' for governance and development indicators.
#'
#' The lending categories reflect eligibility for different World Bank financing instruments:
#' \itemize{
#'   \item IDA countries are eligible for concessional financing
#'   \item IBRD countries can borrow at market-based terms
#'   \item Blend countries are eligible for both IDA and IBRD financing
#'   \item High-income countries typically have \code{NA} for lending category
#' }
#'
#' @source
#' World Bank Country and Lending Groups Classification (October 2025).
#' File: CLASS_2025_10_07.xlsx
#'
#' @examples
#' data(wbcountries)
#' # View all Africa Eastern and Southern countries
#' dplyr::filter(wbcountries, region_code == "AFE")
#'
#' # View all low-income IDA countries
#' dplyr::filter(wbcountries, income_group == "Low income", lending_category == "IDA")
#'
#' # Count countries by region
#' dplyr::count(wbcountries, region)
"wbcountries"


# ============================================================================
# Group-aggregated lists
# ============================================================================

#' CTF dynamic scores aggregated to World Bank region
#'
#' @description
#' `ctfdata_list` with country-level rows replaced by World Bank region-level
#' averages, same nested taxonomy structure. Produced by
#' [aggregate_data_list()].
#'
#' **Per leaf:** WB classification columns are joined via `country_code`; rows
#' for WB aggregate codes with no match in `wbcountries` are dropped; every
#' numeric indicator column is averaged within `region × year`
#' (`na.rm = TRUE`); `score` is recomputed as the row mean of those averages;
#' `var_count` / `nonna_count` are dropped. Empty leaves stay empty.
#'
#' @format A nested list matching `ctfdata_list`. Each populated leaf tibble
#'   has `region`, `region_code`, `year`, region-mean indicator columns, and a
#'   recomputed `score`.
#'
#' @seealso `ctfdata_list`, `wbcountries`, [aggregate_data_list()]
#' @source Derived from `ctfdata_list` and `wbcountries` via [aggregate_data_list()].
"regionctf_list"


#' CTF dynamic scores aggregated to World Bank income group
#'
#' @description
#' `ctfdata_list` with country-level rows replaced by World Bank income-group
#' averages. Identical logic to `regionctf_list` but grouped by `income_group`.
#'
#' @format A nested list matching `ctfdata_list`. Each populated leaf tibble
#'   has `income_group`, `year`, income-group-mean indicator columns, and a
#'   recomputed `score`.
#'
#' @seealso `ctfdata_list`, `wbcountries`, [aggregate_data_list()]
#' @source Derived from `ctfdata_list` and `wbcountries` via [aggregate_data_list()].
"incomectf_list"


#' Raw indicator data aggregated to World Bank region
#'
#' @description
#' `rawdata_list` with country-level rows replaced by World Bank region-level
#' averages. Identical logic to `regionctf_list` applied to raw source values;
#' because raw leaves carry no scoring artefacts, all numeric columns are
#' averaged and `score` is computed fresh.
#'
#' @format A nested list matching `rawdata_list`. Each populated leaf tibble
#'   has `region`, `region_code`, `year`, region-mean indicator columns, and a
#'   `score`.
#'
#' @seealso `rawdata_list`, `wbcountries`, [aggregate_data_list()]
#' @source Derived from `rawdata_list` and `wbcountries` via [aggregate_data_list()].
"regionrawdata_list"


#' Raw indicator data aggregated to World Bank income group
#'
#' @description
#' `rawdata_list` with country-level rows replaced by World Bank income-group
#' averages. Identical logic to `incomectf_list` applied to raw source values.
#'
#' @format A nested list matching `rawdata_list`. Each populated leaf tibble
#'   has `income_group`, `year`, income-group-mean indicator columns, and a
#'   `score`.
#'
#' @seealso `rawdata_list`, `wbcountries`, [aggregate_data_list()]
#' @source Derived from `rawdata_list` and `wbcountries` via [aggregate_data_list()].
"incomerawdata_list"

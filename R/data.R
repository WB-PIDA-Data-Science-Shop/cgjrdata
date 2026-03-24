# ============================================================================
# Package data documentation
# ============================================================================

#' Raw indicator data — all chapters
#'
#' @description
#' A nested list containing country-year panels of raw source values for every
#' subcluster in the Country Jobs and Growth Report (CGJR) analytical
#' framework. Data are sourced from the underlying provider datasets via
#' [extract_cliar_data()] with `type = "raw"`, except for RISE energy
#' indicators which are sourced from `data-raw/input/RISE_20102021.dta`.
#'
#' The list is structured as `rawdata_list[[cluster]][[subcluster]]`, where
#' both `cluster` and `subcluster` keys use snake_case names. The four
#' top-level clusters and their subclusters are:
#'
#' \describe{
#'   \item{`institutional_environment`}{`degree_of_integrity`,
#'     `transparency_and_accountability`, `justice_and_rule_of_law`,
#'     `social_cohesion_norms_and_cooperation`}
#'   \item{`political_institutions`}{`political_institutions`}
#'   \item{`center_of_government`}{`public_financial_management`,
#'     `public_sector_hrm`, `digital_and_data`}
#'   \item{`sectors_service_delivery`}{`business_environment`,
#'     `service_delivery`, `soe_corporate_governance`,
#'     `labor_and_social_protection`, `energy_and_environment`}
#' }
#'
#' Each element is a tibble with at minimum the columns `country_code`,
#' `country_name`, `year`, and one column per indicator. See `metadata_tbl`
#' for full variable descriptions.
#'
#' @seealso `ctfdata_list`, `metadata_tbl`
#'
#' @source
#' Assembled from `cliaretl` raw source datasets and
#' `data-raw/input/RISE_20102021.dta`. See [cliaretl::db_variables_final]
#' for full variable provenance.
"rawdata_list"


#' CTF dynamic scores — all chapters
#'
#' @description
#' A nested list containing Closeness-to-Frontier (CTF) dynamic scores for
#' every subcluster in the Country Jobs and Growth Report (CGJR) analytical
#' framework. Values are drawn from [cliaretl::closeness_to_frontier_dynamic]
#' via [extract_cliar_data()] with `type = "dynamic"`.
#'
#' The list has the same structure as `rawdata_list`:
#' `ctfdata_list[[cluster]][[subcluster]]`. The four top-level clusters and
#' their subclusters are:
#'
#' \describe{
#'   \item{`institutional_environment`}{`degree_of_integrity`,
#'     `transparency_and_accountability`, `justice_and_rule_of_law`,
#'     `social_cohesion_norms_and_cooperation`}
#'   \item{`political_institutions`}{`political_institutions`}
#'   \item{`center_of_government`}{`public_financial_management`,
#'     `public_sector_hrm`, `digital_and_data`}
#'   \item{`sectors_service_delivery`}{`business_environment`,
#'     `service_delivery`, `soe_corporate_governance`,
#'     `labor_and_social_protection`, `energy_and_environment`}
#' }
#'
#' Each element is a tibble with columns `country_code`, `country_name`,
#' `year`, one CTF-scaled column per indicator, and three summary columns
#' appended by [score_ctfdata_list()]:
#'
#' \describe{
#'   \item{`score`}{Row mean of all indicator columns (`na.rm = TRUE`). `NA`
#'     when every indicator is `NA` for that row.}
#'   \item{`var_count`}{Total number of indicator columns in the subcluster
#'     (constant for every row).}
#'   \item{`nonna_count`}{Number of non-`NA` indicator values used to compute
#'     `score` for each row.}
#' }
#'
#' @seealso `rawdata_list`, `metadata_tbl`, `institutional_averages_tbl`
#'
#' @source [cliaretl::closeness_to_frontier_dynamic]
"ctfdata_list"


#' Variable metadata — all chapters
#'
#' @description
#' A single combined tibble containing variable-level metadata for every
#' indicator included in the CGJR analytical framework. Created by
#' row-binding the per-subcluster metadata tables produced by the data-raw
#' scripts.
#'
#' @format A tibble with one row per indicator and the following columns
#' (all fields from [cliaretl::db_variables_final] plus four added by
#' this package):
#' \describe{
#'   \item{var_name}{Human-readable indicator name.}
#'   \item{api_id}{API identifier (where available).}
#'   \item{variable}{Snake-case variable name used as column names in
#'     `rawdata_list` and `ctfdata_list`.}
#'   \item{var_level}{Level of aggregation (`"indicator"` or `"aggregate"`).}
#'   \item{family_var}{Short identifier for the indicator family.}
#'   \item{family_name}{Full name of the indicator family.}
#'   \item{family_order}{Display order of the family.}
#'   \item{processing}{Any processing applied to the raw value (e.g.
#'     `"Invert. 100 - X"`).}
#'   \item{description}{Full variable description from the source.}
#'   \item{description_short}{One-sentence description.}
#'   \item{source}{Data source name.}
#'   \item{benchmarked_ctf}{Whether the variable is benchmarked in the CTF
#'     framework (`"Yes"` / `"No"`).}
#'   \item{benchmark_static_family_aggregate_download}{Included in static
#'     family aggregate download (`"Yes"` / `"No"`).}
#'   \item{benchmark_dynamic_indicator}{Included in dynamic indicator
#'     benchmark (`"Yes"` / `"No"`).}
#'   \item{benchmark_dynamic_family_aggregate}{Included in dynamic family
#'     aggregate benchmark (`"Yes"` / `"No"`).}
#'   \item{rank_id}{Numeric rank identifier.}
#'   \item{etl_source}{Key identifying the raw source dataset used in ETL.}
#'   \item{cluster}{CGJR chapter name.}
#'   \item{cluster_num}{CGJR chapter number (1–4).}
#'   \item{subcluster}{CGJR subcluster name.}
#'   \item{subcluster_num}{CGJR subcluster number within the chapter.}
#' }
#'
#' @seealso `rawdata_list`, `ctfdata_list`
#'
#' @source [cliaretl::db_variables_final]
"metadata_tbl"


#' Subcluster, cluster and overall CTF score averages
#'
#' @description
#' A wide tibble containing aggregated Closeness-to-Frontier (CTF) scores at
#' the subcluster, cluster and overall level for every
#' `country_code × country_name × year` combination present in
#' `ctfdata_list`.
#'
#' **Aggregation hierarchy:**
#'
#' 1. **Subcluster score** (`score` column within each leaf of `ctfdata_list`):
#'    row mean of all CTF indicator columns for that subcluster
#'    (`na.rm = TRUE`). Computed by [add_subcluster_score()].
#'
#' 2. **Cluster score**: mean of its constituent subcluster scores
#'    (equal weight per subcluster, `na.rm = TRUE`). Computed by
#'    [compute_cluster_averages()].
#'
#' 3. **Overall score**: mean of the four cluster scores (`na.rm = TRUE`).
#'
#' @format A tibble with one row per `country_code × country_name × year` and
#'   the following columns:
#' \describe{
#'   \item{`country_code`}{ISO 3-letter country code.}
#'   \item{`country_name`}{Country name.}
#'   \item{`year`}{Calendar year.}
#'   \item{`institutional_environment_score`}{Mean of the four Institutional
#'     Environment subcluster scores: `degree_of_integrity`,
#'     `transparency_and_accountability`, `justice_and_rule_of_law`,
#'     `social_cohesion_norms_and_cooperation`.}
#'   \item{`political_institutions_score`}{Score for the Political
#'     Institutions cluster (single subcluster).}
#'   \item{`center_of_government_score`}{Mean of the three Center of
#'     Government subcluster scores: `public_financial_management`,
#'     `public_sector_hrm`, `digital_and_data`.}
#'   \item{`sectors_service_delivery_score`}{Mean of the five Sectors /
#'     Service Delivery subcluster scores: `business_environment`,
#'     `service_delivery`, `soe_corporate_governance`,
#'     `labor_and_social_protection`, `energy_and_environment`.}
#'   \item{`overall_score`}{Mean of the four cluster scores above
#'     (`na.rm = TRUE`).}
#' }
#'
#' @seealso `ctfdata_list`, [add_subcluster_score()], [score_ctfdata_list()],
#'   [compute_cluster_averages()]
#'
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
#' A nested list with the same cluster/subcluster structure as `ctfdata_list`
#' (`list[[cluster]][[subcluster]]`), but with country-level rows replaced by
#' World Bank region-level averages.
#'
#' **Aggregation logic (per subcluster):**
#' 1. World Bank classification columns (`region`, `region_code`) are joined
#'    onto `ctfdata_list` via `country_code` using [aggregate_data_list()].
#' 2. Rows for WB aggregate codes (e.g. `"WLD"`, `"SSA"`) that have no match
#'    in `wbcountries` are dropped.
#' 3. For each `region × year` group, every CTF indicator column is averaged
#'    across countries (`na.rm = TRUE`).
#' 4. `score` is recomputed as the row mean of the resulting averaged indicator
#'    columns (`na.rm = TRUE`); `NaN` is coerced to `NA`.
#' 5. `var_count` and `nonna_count` are dropped (not meaningful at group level).
#'
#' @format A nested list `[[cluster]][[subcluster]]`. Each leaf tibble contains:
#' \describe{
#'   \item{`region`}{Full World Bank region name.}
#'   \item{`region_code`}{Three-letter WB region code (e.g. `"AFE"`, `"ECA"`).}
#'   \item{`year`}{Calendar year.}
#'   \item{`<indicator columns>`}{Region-mean of each CTF indicator
#'     (`na.rm = TRUE`).}
#'   \item{`score`}{Row mean of the region-averaged indicator columns
#'     (`na.rm = TRUE`); `NA` when all indicators are `NA`.}
#' }
#'
#' @seealso `ctfdata_list`, `wbcountries`, [aggregate_data_list()]
#'
#' @source Derived from `ctfdata_list` and `wbcountries` via
#'   [aggregate_data_list()].
"regionctf_list"


#' CTF dynamic scores aggregated to World Bank income group
#'
#' @description
#' A nested list with the same cluster/subcluster structure as `ctfdata_list`,
#' but with country-level rows replaced by World Bank income-group averages.
#'
#' **Aggregation logic:** identical to `regionctf_list` but grouped by
#' `income_group` instead of `region`. See [aggregate_data_list()] for full
#' details.
#'
#' @format A nested list `[[cluster]][[subcluster]]`. Each leaf tibble contains:
#' \describe{
#'   \item{`income_group`}{World Bank income classification: `"Low income"`,
#'     `"Lower middle income"`, `"Upper middle income"`, or `"High income"`.}
#'   \item{`year`}{Calendar year.}
#'   \item{`<indicator columns>`}{Income-group mean of each CTF indicator
#'     (`na.rm = TRUE`).}
#'   \item{`score`}{Row mean of the income-group-averaged indicator columns
#'     (`na.rm = TRUE`); `NA` when all indicators are `NA`.}
#' }
#'
#' @seealso `ctfdata_list`, `wbcountries`, [aggregate_data_list()]
#'
#' @source Derived from `ctfdata_list` and `wbcountries` via
#'   [aggregate_data_list()].
"incomectf_list"


#' Raw indicator data aggregated to World Bank region
#'
#' @description
#' A nested list with the same cluster/subcluster structure as `rawdata_list`,
#' but with country-level rows replaced by World Bank region-level averages.
#'
#' **Aggregation logic:** identical to `regionctf_list` but applied to
#' `rawdata_list` (raw source values rather than CTF scores). Because
#' `rawdata_list` leaves do not carry `score`/`var_count`/`nonna_count`
#' columns, all numeric columns are averaged and `score` is freshly computed
#' as the row mean of those averages. See [aggregate_data_list()] for full
#' details.
#'
#' @format A nested list `[[cluster]][[subcluster]]`. Each leaf tibble contains:
#' \describe{
#'   \item{`region`}{Full World Bank region name.}
#'   \item{`region_code`}{Three-letter WB region code.}
#'   \item{`year`}{Calendar year.}
#'   \item{`<indicator columns>`}{Region-mean of each raw indicator
#'     (`na.rm = TRUE`).}
#'   \item{`score`}{Row mean of the region-averaged indicator columns
#'     (`na.rm = TRUE`); `NA` when all indicators are `NA`.}
#' }
#'
#' @seealso `rawdata_list`, `wbcountries`, [aggregate_data_list()]
#'
#' @source Derived from `rawdata_list` and `wbcountries` via
#'   [aggregate_data_list()].
"regionrawdata_list"


#' Raw indicator data aggregated to World Bank income group
#'
#' @description
#' A nested list with the same cluster/subcluster structure as `rawdata_list`,
#' but with country-level rows replaced by World Bank income-group averages.
#'
#' **Aggregation logic:** identical to `incomerawdata_list` but applied to
#' `rawdata_list`. See [aggregate_data_list()] for full details.
#'
#' @format A nested list `[[cluster]][[subcluster]]`. Each leaf tibble contains:
#' \describe{
#'   \item{`income_group`}{World Bank income classification: `"Low income"`,
#'     `"Lower middle income"`, `"Upper middle income"`, or `"High income"`.}
#'   \item{`year`}{Calendar year.}
#'   \item{`<indicator columns>`}{Income-group mean of each raw indicator
#'     (`na.rm = TRUE`).}
#'   \item{`score`}{Row mean of the income-group-averaged indicator columns
#'     (`na.rm = TRUE`); `NA` when all indicators are `NA`.}
#' }
#'
#' @seealso `rawdata_list`, `wbcountries`, [aggregate_data_list()]
#'
#' @source Derived from `rawdata_list` and `wbcountries` via
#'   [aggregate_data_list()].
"incomerawdata_list"

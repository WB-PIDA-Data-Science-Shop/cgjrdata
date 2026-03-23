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

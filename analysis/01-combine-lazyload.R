##############################################################################
################### COMBINE OUTPUTS INTO LAZYLOADED LISTS ###################
##############################################################################
# Reads all .rds files written by the data-raw/source scripts and assembles
# four package-level objects:
#
#   rawdata_list             — nested list of raw source panels, keyed by
#                              cluster / subcluster
#   ctfdata_list             — nested list of CTF dynamic panels, same
#                              structure; each subcluster tibble is enriched
#                              with score, var_count, nonna_count columns
#   metadata_tbl             — single combined metadata tibble (all
#                              subclusters row-bound)
#   institutional_averages_tbl — wide tibble of subcluster, cluster and
#                              overall CTF scores per country_code × year
#
# Run this script after 00-build_all_datasets.r has populated data-raw/output/.
##############################################################################

library(dplyr)
devtools::load_all()
here::i_am("analysis/01-combine-lazyload.R")
out <- function(...) here::here("data-raw", "output", ...)

# ============================================================================
# 1.  rawdata_list
# ============================================================================
rawdata_list <- list(
  institutional_environment = list(
    degree_of_integrity              = readRDS(out("rawdoi_tbl.rds")),
    transparency_and_accountability  = readRDS(out("rawta_tbl.rds")),
    justice_and_rule_of_law          = readRDS(out("rawjrl_tbl.rds")),
    social_cohesion_norms_and_cooperation = readRDS(out("rawscnc_tbl.rds"))
  ),
  political_institutions = list(
    political_institutions           = readRDS(out("rawpol_tbl.rds"))
  ),
  center_of_government = list(
    public_financial_management      = readRDS(out("rawpfm_tbl.rds")),
    public_sector_hrm                = readRDS(out("rawhrm_tbl.rds")),
    digital_and_data                 = readRDS(out("rawdigital_tbl.rds"))
  ),
  sectors_service_delivery = list(
    business_environment             = readRDS(out("rawbe_tbl.rds")),
    service_delivery                 = readRDS(out("rawsd_tbl.rds")),
    soe_corporate_governance         = readRDS(out("rawsoe_tbl.rds")),
    labor_and_social_protection      = readRDS(out("rawlab_tbl.rds")),
    energy_and_environment           = readRDS(out("rawee_tbl.rds"))
  )
)

# ============================================================================
# 2.  ctfdata_list
# ============================================================================
ctfdata_list <- list(
  institutional_environment = list(
    degree_of_integrity              = readRDS(out("dynamicdoi_tbl.rds")),
    transparency_and_accountability  = readRDS(out("dynamicta_tbl.rds")),
    justice_and_rule_of_law          = readRDS(out("dynamicjrl_tbl.rds")),
    social_cohesion_norms_and_cooperation = readRDS(out("dynamicscnc_tbl.rds"))
  ),
  political_institutions = list(
    political_institutions           = readRDS(out("dynamicpol_tbl.rds"))
  ),
  center_of_government = list(
    public_financial_management      = readRDS(out("dynamicpfm_tbl.rds")),
    public_sector_hrm                = readRDS(out("dynamichrm_tbl.rds")),
    digital_and_data                 = readRDS(out("dynamicdigital_tbl.rds"))
  ),
  sectors_service_delivery = list(
    business_environment             = readRDS(out("dynamicbe_tbl.rds")),
    service_delivery                 = readRDS(out("dynamicsd_tbl.rds")),
    soe_corporate_governance         = readRDS(out("dynamicsoe_tbl.rds")),
    labor_and_social_protection      = readRDS(out("dynamiclab_tbl.rds")),
    energy_and_environment           = readRDS(out("dynamicee_tbl.rds"))
  )
)

# ============================================================================
# 3.  metadata_tbl
# ============================================================================
metadata_tbl <- Reduce(
  "rbind",
  list(
    # Institutional Environment
    readRDS(out("metadoi_tbl.rds")),
    readRDS(out("metata_tbl.rds")),
    readRDS(out("metajrl_tbl.rds")),
    readRDS(out("metascnc_tbl.rds")),
    # Political Institutions
    readRDS(out("metapol_tbl.rds")),
    # Center of Government
    readRDS(out("metapfm_tbl.rds")),
    readRDS(out("metahrm_tbl.rds")),
    readRDS(out("metadigital_tbl.rds")),
    # Sectors / Service Delivery
    readRDS(out("metabe_tbl.rds")),
    readRDS(out("metasd_tbl.rds")),
    readRDS(out("metasoe_tbl.rds")),
    readRDS(out("metalab_tbl.rds")),
    readRDS(out("metaee_tbl.rds"))
  )
)

# ============================================================================
# 4.  Enrich ctfdata_list with subcluster scores
# ============================================================================
# Each leaf tibble gets three appended columns:
#   score       — rowMeans of indicator cols (na.rm = TRUE); NA when all NA
#   var_count   — total number of indicator columns (constant per subcluster)
#   nonna_count — number of non-NA indicator values used per row
ctfdata_list <- score_ctfdata_list(ctfdata_list)

# ============================================================================
# 5.  institutional_averages_tbl
# ============================================================================
# Wide tibble: one row per country_code × country_name × year
# Cluster score = mean of its subclusters' scores (equal-weight, na.rm = TRUE)
# Overall score = mean of the four cluster scores (na.rm = TRUE)
institutional_averages_tbl <- compute_cluster_averages(ctfdata_list)

# ============================================================================
# 6.  Save as package lazyload data
# ============================================================================
usethis::use_data(rawdata_list,             overwrite = TRUE)
usethis::use_data(ctfdata_list,             overwrite = TRUE)
usethis::use_data(metadata_tbl,             overwrite = TRUE)
usethis::use_data(institutional_averages_tbl, overwrite = TRUE)

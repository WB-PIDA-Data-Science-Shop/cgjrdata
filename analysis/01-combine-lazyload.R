##############################################################################
################### COMBINE OUTPUTS INTO LAZYLOADED OBJECTS #################
##############################################################################
# Assembles every lazyloaded package object from the CGJR crosswalk
# (`cgjr_taxonomy` + `cgjr_crosswalk`) and `cliaretl`. No per-subcluster
# intermediates are read — the crosswalk is the single source of truth.
#
#   rawdata_list               — nested raw source panels (taxonomy shape)
#   ctfdata_list               — nested CTF dynamic panels (taxonomy shape),
#                                each leaf enriched with score / var_count /
#                                nonna_count
#   metadata_tbl               — one row per taxonomy indicator + catalogue
#                                metadata + eligibility flags
#   institutional_averages_tbl — wide cluster + overall CTF scores per
#                                country_code x country_name x year
#   regionctf_list / incomectf_list       — ctfdata_list by WB region / income
#   regionrawdata_list / incomerawdata_list — rawdata_list by WB region / income
#
# Run after analysis/00-build_all_datasets.r.
##############################################################################

library(dplyr)
devtools::load_all()
here::i_am("analysis/01-combine-lazyload.R")

# ============================================================================
# 1.  Nested raw + CTF data lists (built directly from the crosswalk)
# ============================================================================
rawdata_list <- build_rawdata_list(cgjr_crosswalk, cgjr_taxonomy)
ctfdata_list <- build_ctfdata_list(cgjr_crosswalk, cgjr_taxonomy)  # warns on ineligible rows

# ============================================================================
# 2.  Enrich ctfdata_list with subcluster scores
# ============================================================================
#   score       — rowMeans of indicator cols (na.rm = TRUE); NA when all NA
#   var_count   — number of indicator columns (constant per leaf)
#   nonna_count — number of non-NA indicator values used per row
ctfdata_list <- score_ctfdata_list(ctfdata_list)

# ============================================================================
# 3.  metadata_tbl
# ============================================================================
metadata_tbl <- build_metadata_tbl(cgjr_crosswalk, cgjr_taxonomy)

# ============================================================================
# 4.  institutional_averages_tbl
# ============================================================================
# Cluster score = recursive equal-weight mean of child scores
# Overall score = mean of the cluster scores (na.rm = TRUE)
institutional_averages_tbl <- compute_cluster_averages(ctfdata_list)

# ============================================================================
# 5.  Region and income-group aggregated lists
# ============================================================================
regionctf_list     <- aggregate_data_list(ctfdata_list, "region",       wbcountries)
incomectf_list     <- aggregate_data_list(ctfdata_list, "income_group", wbcountries)
regionrawdata_list <- aggregate_data_list(rawdata_list, "region",       wbcountries)
incomerawdata_list <- aggregate_data_list(rawdata_list, "income_group", wbcountries)

# ============================================================================
# 6.  Save as package lazyload data
# ============================================================================
usethis::use_data(rawdata_list,               overwrite = TRUE)
usethis::use_data(ctfdata_list,               overwrite = TRUE)
usethis::use_data(metadata_tbl,               overwrite = TRUE)
usethis::use_data(institutional_averages_tbl, overwrite = TRUE)
usethis::use_data(regionctf_list,             overwrite = TRUE)
usethis::use_data(incomectf_list,             overwrite = TRUE)
usethis::use_data(regionrawdata_list,         overwrite = TRUE)
usethis::use_data(incomerawdata_list,         overwrite = TRUE)

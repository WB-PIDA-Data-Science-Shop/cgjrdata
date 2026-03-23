##############################################################################
################### PUBLIC SECTOR HRM INDICATORS ############################
##############################################################################

library(dplyr)

### Center of Government chapter (cluster 3), subcluster 2:
### Public Sector Human Resource Management.

rawhrm_vars <- c(
  "vdem_core_v2clrspct",       # rigorous and impartial public administration (V-DEM)
  "bs_bti_q15_1",              # efficient use of assets (BTI)
  "vdem_core_v2stcritrecadm",  # criteria for appointment decisions in state admin (V-DEM)
  "vdem_core_v2peasjpol",      # access to state jobs by political group (V-DEM)
  "vdem_core_v2peasjsoecon"    # access to state jobs by socioeconomic position (V-DEM)
)

rawhrm_tbl <- extract_cliar_data(variables = rawhrm_vars, type = "raw")

dynamichrm_tbl <- extract_cliar_data(variables = rawhrm_vars, type = "dynamic")

metahrm_tbl <-
  cliaretl::db_variables_final |>
  dplyr::filter(variable %in% rawhrm_vars) |>
  mutate(
    cluster        = "Center of Government",
    cluster_num    = 3,
    subcluster     = "Public Sector HRM",
    subcluster_num = 2
  )

saveRDS(rawhrm_tbl,     here::here("data-raw", "output", "rawhrm_tbl.rds"))
saveRDS(dynamichrm_tbl, here::here("data-raw", "output", "dynamichrm_tbl.rds"))
saveRDS(metahrm_tbl,    here::here("data-raw", "output", "metahrm_tbl.rds"))

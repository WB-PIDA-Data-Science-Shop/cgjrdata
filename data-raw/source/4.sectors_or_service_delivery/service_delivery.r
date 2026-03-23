##############################################################################
#################### SERVICE DELIVERY INDICATORS ############################
##############################################################################

library(dplyr)

### Sectors / Service Delivery chapter (cluster 4), subcluster 2:
### Service Delivery Institutions.

rawsd_vars <- c(
  "vdem_core_v2peapspol",   # access to public services by political group (V-DEM)
  "vdem_core_v2peapsecon",  # access to public services by socioeconomic position (V-DEM)
  "vdem_core_v2peapsgen",   # access to public services by gender (V-DEM)
  "wdi_shstaanvczs",        # pregnant women receiving prenatal care % (WDI)
  "wdi_shstabrtczs",        # births attended by skilled health staff % (WDI)
  "wdi_spregbrthzs",        # completeness of birth registration % (WDI)
  "wdi_seprmenrltczs",      # pupil-teacher ratio, primary (WDI)
  "wdi_sesecenrltczs",      # pupil-teacher ratio, secondary (WDI)
  "wdi_sepretcaqzs",        # trained teachers in preprimary education % (WDI)
  "wdi_seprmtcaqzs",        # trained teachers in primary education % (WDI)
  "wdi_sesectcaqzs"         # trained teachers in secondary education % (WDI)
)

rawsd_tbl <- extract_cliar_data(variables = rawsd_vars, type = "raw")

dynamicsd_tbl <- extract_cliar_data(variables = rawsd_vars, type = "dynamic")

metasd_tbl <-
  cliaretl::db_variables_final |>
  dplyr::filter(variable %in% rawsd_vars) |>
  mutate(
    cluster        = "Sectors / Service Delivery",
    cluster_num    = 4,
    subcluster     = "Service Delivery",
    subcluster_num = 2
  )

saveRDS(rawsd_tbl,     here::here("data-raw", "output", "rawsd_tbl.rds"))
saveRDS(dynamicsd_tbl, here::here("data-raw", "output", "dynamicsd_tbl.rds"))
saveRDS(metasd_tbl,    here::here("data-raw", "output", "metasd_tbl.rds"))

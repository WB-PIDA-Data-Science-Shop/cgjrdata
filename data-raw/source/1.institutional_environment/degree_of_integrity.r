#############################################################################
#################### THE DEGREE OF INTEGRITY INDICATORS #####################
#############################################################################

library(dplyr)

### integrating the degree of integrity indicators from cliaretl package
### into this package: The indicators are: 
### (1) absence of corruption (WJP), 
### (2) public sector corruption (V-DEM), 
### (3) executive corruption (V-DEM), 
### (4) legislative corruption (V-DEM), 
### (5) government regulations are applied and enforced without improper influence (WJP)

rawdoi_vars <- c("wjp_rol_2", "vdem_core_v2x_pubcorr", "vdem_core_v2x_execorr", 
                 "vdem_core_v2lgcrrpt", "wjp_rol_6_2")

rawdoi_tbl <- extract_cliar_data(variables = rawdoi_vars, type = "raw")

dynamicdoi_tbl <- extract_cliar_data(variables = rawdoi_vars, type = "dynamic")


metadoi_tbl <- 
  cliaretl::db_variables_final |>
  dplyr::filter(variable %in% rawdoi_vars) |>
  mutate(cluster = "Institutional Environment",
         cluster_num = 1,
         subcluster = "Degree of Integrity",
         subcluster_num = 1)

saveRDS(rawdoi_tbl,     here::here("data-raw", "output", "rawdoi_tbl.rds"))
saveRDS(dynamicdoi_tbl, here::here("data-raw", "output", "dynamicdoi_tbl.rds"))
saveRDS(metadoi_tbl,    here::here("data-raw", "output", "metadoi_tbl.rds"))
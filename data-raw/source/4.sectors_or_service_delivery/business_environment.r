##############################################################################
#################### BUSINESS ENVIRONMENT INDICATORS ########################
##############################################################################

library(dplyr)

### Sectors / Service Delivery chapter (cluster 4), subcluster 1:
### Business Environment.

rawbe_vars <- c(
  "vdem_core_v2xcl_prpty",      # property rights (V-DEM)
  "bs_bti_q7_2",                # competition policy (BTI)
  "wjp_rol_6",                  # regulatory enforcement (WJP)
  "wb_lpi_lp_lpi_cust_xq",      # efficiency of the clearance process (WB LPI)
  "wb_gfdb_oi_01",              # bank concentration % (GFDB)
  "wb_wbl_entrepreneurship"     # women, business and law entrepreneurship index (WBL)
)

rawbe_tbl <- extract_cliar_data(variables = rawbe_vars, type = "raw")

dynamicbe_tbl <- extract_cliar_data(variables = rawbe_vars, type = "dynamic")

metabe_tbl <-
  cliaretl::db_variables_final |>
  dplyr::filter(variable %in% rawbe_vars) |>
  mutate(
    cluster        = "Sectors / Service Delivery",
    cluster_num    = 4,
    subcluster     = "Business Environment",
    subcluster_num = 1
  )

saveRDS(rawbe_tbl,     here::here("data-raw", "output", "rawbe_tbl.rds"))
saveRDS(dynamicbe_tbl, here::here("data-raw", "output", "dynamicbe_tbl.rds"))
saveRDS(metabe_tbl,    here::here("data-raw", "output", "metabe_tbl.rds"))

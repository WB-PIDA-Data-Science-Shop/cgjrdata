##############################################################################
############## LABOR AND SOCIAL PROTECTION INDICATORS ########################
##############################################################################

library(dplyr)

### Sectors / Service Delivery chapter (cluster 4), subcluster 4:
### Labor and Social Protection Institutions.

rawlab_vars <- c(
  "wjp_rol_4_8",            # fundamental labor rights effectively guaranteed (WJP)
  "idea_gsod_v_22_16",      # workers' rights index (IDEA Global State of Democracy)
  "oecd_epl_regular",       # employment protection for regular workers (OECD EPL)
  "oecd_epl_temporary",     # employment protection for temporary workers (OECD EPL)
  "wb_wbl_labor",           # women's labor equality index (WBL/CLIAR)
  "wb_aspire_coverage",     # social protection coverage (ASPIRE/WDI)
  "wb_aspire_adequacy_benefits" # adequacy of social protection benefits (ASPIRE/WDI)
)

rawlab_tbl <- extract_cliar_data(variables = rawlab_vars, type = "raw")

dynamiclab_tbl <- extract_cliar_data(variables = rawlab_vars, type = "dynamic")

metalab_tbl <-
  cliaretl::db_variables_final |>
  dplyr::filter(variable %in% rawlab_vars) |>
  mutate(
    cluster        = "Sectors / Service Delivery",
    cluster_num    = 4,
    subcluster     = "Labor and Social Protection",
    subcluster_num = 4
  )

saveRDS(rawlab_tbl,     here::here("data-raw", "output", "rawlab_tbl.rds"))
saveRDS(dynamiclab_tbl, here::here("data-raw", "output", "dynamiclab_tbl.rds"))
saveRDS(metalab_tbl,    here::here("data-raw", "output", "metalab_tbl.rds"))

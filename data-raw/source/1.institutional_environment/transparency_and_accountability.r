##############################################################################
################ TRANSPARENCY AND ACCOUNTABILITY INDICATORS ##################
##############################################################################

library(dplyr)

### Integrating the Transparency and Accountability indicators from the
### cliaretl package into this package. The indicators are:
### (1) right to information (WJP)
### (2) publicized laws and government data (WJP)
### (3) Open Budget Index (Open Budget Survey)
### (4) complaint mechanisms (WJP)
### (5) Digital Citizen Engagement Index score (GTMI)

rawta_vars <- c(
  "wjp_rol_3_2",   # right to information
  "wjp_rol_3_1",   # publicized laws and government data
  "ibp_obs_obi",   # open budget index
  "wjp_rol_3_4",   # complaint mechanisms
  "wb_gtmi_dcei"   # digital citizen engagement index score
)

rawta_tbl <- extract_cliar_data(variables = rawta_vars, type = "raw")

dynamicta_tbl <- extract_cliar_data(variables = rawta_vars, type = "dynamic")

metata_tbl <-
  cliaretl::db_variables_final |>
  dplyr::filter(variable %in% rawta_vars) |>
  mutate(
    cluster       = "Institutional Environment",
    cluster_num   = 1,
    subcluster    = "Transparency and Accountability",
    subcluster_num = 2
  )

saveRDS(rawta_tbl,     here::here("data-raw", "output", "rawta_tbl.rds"))
saveRDS(dynamicta_tbl, here::here("data-raw", "output", "dynamicta_tbl.rds"))
saveRDS(metata_tbl,    here::here("data-raw", "output", "metata_tbl.rds"))

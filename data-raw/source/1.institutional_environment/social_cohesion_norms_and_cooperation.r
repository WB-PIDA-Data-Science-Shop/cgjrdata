##############################################################################
############## SOCIAL COHESION, NORMS AND COOPERATION INDICATORS #############
##############################################################################

library(dplyr)

### Integrating the Social Cohesion, Norms and Cooperation indicators from
### the cliaretl package into this package. The indicators cover:
### - Power distributed by socioeconomic position (VDEM)
### - Power distributed by social group (VDEM)
### - Power distributed by gender (VDEM)
### - Share of women in legislature (VDEM)
### - Women political empowerment index (VDEM)

rawscnc_vars <- c(
  "vdem_core_v2pepwrses",  # power distributed by socioeconomic position
  "vdem_core_v2pepwrsoc",  # power distributed by social group
  "vdem_core_v2pepwrgen",  # power distributed by gender
  "vdem_core_v2lgqugen",   # share of women in legislature
  "vdem_core_v2x_gender"   # women political empowerment index
)

rawscnc_tbl <- extract_cliar_data(variables = rawscnc_vars, type = "raw")

dynamicscnc_tbl <- extract_cliar_data(variables = rawscnc_vars, type = "dynamic")

metascnc_tbl <-
  cliaretl::db_variables_final |>
  dplyr::filter(variable %in% rawscnc_vars) |>
  mutate(
    cluster        = "Institutional Environment",
    cluster_num    = 1,
    subcluster     = "Social Cohesion Norms and Cooperation",
    subcluster_num = 4
  )

saveRDS(rawscnc_tbl,     here::here("data-raw", "output", "rawscnc_tbl.rds"))
saveRDS(dynamicscnc_tbl, here::here("data-raw", "output", "dynamicscnc_tbl.rds"))
saveRDS(metascnc_tbl,    here::here("data-raw", "output", "metascnc_tbl.rds"))

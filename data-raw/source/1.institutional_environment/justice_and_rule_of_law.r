##############################################################################
#################### JUSTICE AND RULE OF LAW INDICATORS #####################
##############################################################################

library(dplyr)

### Integrating the Justice and Rule of Law indicators from the cliaretl
### package into this package. The indicators cover:
### - Judicial accountability, independence, and access to justice (VDEM)
### - Justice system quality (Bertelsmann Transformation Index)
### - Legal empowerment and access (WJP, IDEA)
### - Civil and criminal justice (WJP)
### - Gender equality in access to justice (VDEM)

rawjrl_vars <- c(
  "vdem_core_v2juaccnt",  # judicial accountability
  "bs_bti_q3_2",          # judiciary independence (BTI)
  "vdem_core_v2juhcind",  # high court independence
  "wjp_rol_2_2",          # absence of corruption in judiciary (WJP)
  "vdem_core_v2juncind",  # lower court independence
  "idea_gsod_v_21_05",    # judicial independence (IDEA)
  "wjp_rol_6_6",          # alternative dispute resolution (WJP)
  "wjp_rol_4_3",          # civil justice - free of discrimination
  "wjp_rol_7_7",          # criminal justice - due process
  "wjp_rol_7_1",          # criminal justice - effective investigation
  "wjp_rol_7_6",          # criminal justice - impartial/effective
  "wjp_rol_7_5",          # criminal justice - absence of corruption
  "wjp_rol_8_2",          # informal justice - timeliness
  "wjp_rol_8_1",          # informal justice - accessibility
  "wjp_rol_8_4",          # informal justice - impartiality
  "vdem_core_v2clacjstm", # access to justice for men
  "vdem_core_v2clacjstw"  # access to justice for women
)

rawjrl_tbl <- extract_cliar_data(variables = rawjrl_vars, type = "raw")

dynamicjrl_tbl <- extract_cliar_data(variables = rawjrl_vars, type = "dynamic")

metajrl_tbl <-
  cliaretl::db_variables_final |>
  dplyr::filter(variable %in% rawjrl_vars) |>
  mutate(
    cluster        = "Institutional Environment",
    cluster_num    = 1,
    subcluster     = "Justice and Rule of Law",
    subcluster_num = 3
  )

saveRDS(rawjrl_tbl,     here::here("data-raw", "output", "rawjrl_tbl.rds"))
saveRDS(dynamicjrl_tbl, here::here("data-raw", "output", "dynamicjrl_tbl.rds"))
saveRDS(metajrl_tbl,    here::here("data-raw", "output", "metajrl_tbl.rds"))

##############################################################################
####################### POLITICAL INSTITUTIONS INDICATORS ####################
##############################################################################

library(dplyr)

### Political Institutions chapter (cluster 2). No subclusters; the cluster
### and subcluster share the same name and number.
###
### Variables drawn from two cliaretl families:
###   "Political Institutions" — core governance/accountability indicators
###   "Social Institutions"    — civil liberties, media, civil society

rawpol_vars <- c(
  # --- Political Institutions family ---
  "wjp_rol_1",             # constraints on government powers (WJP)
  "bs_bti_q3_1",           # separation of powers (BTI)
  "vdem_core_v2xlg_legcon", # legislative constraints on the executive index (V-DEM)
  "bs_bti_q2_1",           # free and fair elections (BTI)
  "fh_fiw_pr_rating",      # political rights (Freedom House)

  # --- Social Institutions family ---
  "fh_fiw_cl_rating",      # civil liberties (Freedom House)
  "bs_bti_q2_3",           # association and assembly rights (BTI)
  "vdem_core_v2cacamps",   # political polarization (V-DEM)
  "rwb_pfi_index",         # press freedom index (Reporters Without Borders)
  "vdem_core_v2x_cspart",  # civil society participation (V-DEM)
  "vdem_core_v2cseeorgs",  # CSO entry and exit (V-DEM)
  "vdem_core_v2csreprss",  # CSO repression (V-DEM)
  "vdem_core_v2dlengage",  # engaged society (V-DEM)
  "wjp_rol_4_7",           # freedom of assembly and association (WJP)
  "vdem_core_v2clacfree",  # freedom of academic and cultural expression (V-DEM)
  "wjp_rol_4_5",           # freedom of belief and religion (WJP)
  "wjp_rol_4_4",           # freedom of opinion and expression (WJP)
  "wjp_rol_4_6",           # freedom from arbitrary interference with privacy (WJP)
  "vdem_core_v2cldiscm",   # freedom of discussion for men (V-DEM)
  "vdem_core_v2cldiscw",   # freedom of discussion for women (V-DEM)
  "wb_wbl_social"          # women's social equality index (CLIAR/WBL)
)

rawpol_tbl <- extract_cliar_data(variables = rawpol_vars, type = "raw")

dynamicpol_tbl <- extract_cliar_data(variables = rawpol_vars, type = "dynamic")

metapol_tbl <-
  cliaretl::db_variables_final |>
  dplyr::filter(variable %in% rawpol_vars) |>
  mutate(
    cluster        = "Political Institutions",
    cluster_num    = 2,
    subcluster     = "Political Institutions",
    subcluster_num = 1
  )

saveRDS(rawpol_tbl,     here::here("data-raw", "output", "rawpol_tbl.rds"))
saveRDS(dynamicpol_tbl, here::here("data-raw", "output", "dynamicpol_tbl.rds"))
saveRDS(metapol_tbl,    here::here("data-raw", "output", "metapol_tbl.rds"))

##############################################################################
################### PUBLIC FINANCIAL MANAGEMENT INDICATORS ###################
##############################################################################

library(dplyr)

### Center of Government chapter (cluster 3), subcluster 1:
### Public Financial Management.

rawpfm_vars <- c(
  "bs_bti_q8_2",           # fiscal stability (BTI)
  "wb_debt_transp_index",  # debt transparency index (CLIAR)
  "wb_gtmi_pfm_mis",       # PFM management information systems (GTMI/CLIAR)

  # PEFA indicators
  "wb_pefa_pi_2016_05",    # budget documentation
  "wb_pefa_pi_2016_07",    # transfers to subnational governments
  "wb_pefa_pi_2016_08",    # performance information for service delivery
  "wb_pefa_pi_2016_10",    # fiscal risk reporting
  "wb_pefa_pi_2016_11",    # public investment management
  "wb_pefa_pi_2016_12",    # public asset management
  "wb_pefa_pi_2016_13",    # debt management
  "wb_pefa_pi_2016_14",    # macroeconomic and fiscal forecasting
  "wb_pefa_pi_2016_15",    # fiscal strategy
  "wb_pefa_pi_2016_16",    # medium-term perspective in expenditure budgeting
  "wb_pefa_pi_2016_17",    # budget preparation process
  "wb_pefa_pi_2016_18",    # legislative scrutiny of budgets
  "wb_pefa_pi_2016_19",    # revenue administration
  "wb_pefa_pi_2016_20",    # accounting for revenues
  "wb_pefa_pi_2016_21",    # predictability of in-year resource allocation
  "wb_pefa_pi_2016_22",    # expenditure arrears
  "wb_pefa_pi_2016_23",    # payroll controls
  "wb_pefa_pi_2016_24",    # procurement
  "wb_pefa_pi_2016_25",    # internal controls on non-salary expenditure
  "wb_pefa_pi_2016_26",    # internal audit effectiveness
  "wb_pefa_pi_2016_27",    # financial data integrity
  "wb_pefa_pi_2016_28",    # in-year budget reports
  "wb_pefa_pi_2016_29",    # annual financial reports
  "wb_pefa_pi_2016_30"     # external audit
)

rawpfm_tbl <- extract_cliar_data(variables = rawpfm_vars, type = "raw")

dynamicpfm_tbl <- extract_cliar_data(variables = rawpfm_vars, type = "dynamic")

metapfm_tbl <-
  cliaretl::db_variables_final |>
  dplyr::filter(variable %in% rawpfm_vars) |>
  mutate(
    cluster        = "Center of Government",
    cluster_num    = 3,
    subcluster     = "Public Financial Management",
    subcluster_num = 1
  )

saveRDS(rawpfm_tbl,     here::here("data-raw", "output", "rawpfm_tbl.rds"))
saveRDS(dynamicpfm_tbl, here::here("data-raw", "output", "dynamicpfm_tbl.rds"))
saveRDS(metapfm_tbl,    here::here("data-raw", "output", "metapfm_tbl.rds"))

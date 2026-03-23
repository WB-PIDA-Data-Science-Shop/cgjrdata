##############################################################################
#################### DIGITAL AND DATA INDICATORS ############################
##############################################################################

library(dplyr)

### Center of Government chapter (cluster 3), subcluster 3:
### Digital and Data Institutions.

rawdigital_vars <- c(
  "wb_gtmi_cgsi",                 # core government systems index (GTMI)
  "wb_gtmi_gtei",                 # GovTech enablers index (GTMI)
  "wb_gtmi_psdi",                 # public service delivery index (GTMI)
  "wb_spi_census_and_survey_index", # censuses and surveys (SPI)
  "wb_spi_std_and_methods"        # standards and methods (SPI)
)

rawdigital_tbl <- extract_cliar_data(variables = rawdigital_vars, type = "raw")

dynamicdigital_tbl <- extract_cliar_data(variables = rawdigital_vars, type = "dynamic")

metadigital_tbl <-
  cliaretl::db_variables_final |>
  dplyr::filter(variable %in% rawdigital_vars) |>
  mutate(
    cluster        = "Center of Government",
    cluster_num    = 3,
    subcluster     = "Digital and Data",
    subcluster_num = 3
  )

saveRDS(rawdigital_tbl,     here::here("data-raw", "output", "rawdigital_tbl.rds"))
saveRDS(dynamicdigital_tbl, here::here("data-raw", "output", "dynamicdigital_tbl.rds"))
saveRDS(metadigital_tbl,    here::here("data-raw", "output", "metadigital_tbl.rds"))

##############################################################################
################# SOE CORPORATE GOVERNANCE INDICATORS ########################
##############################################################################

library(dplyr)

### Sectors / Service Delivery chapter (cluster 4), subcluster 3:
### State-Owned Enterprises Corporate Governance.

### The catalogue has two distinct PMR variables for "government involvement":
###   2_2_1 = network sectors (telecoms, electricity, gas, etc.)
###   2_2_2 = services sectors
### Both are included per the analytical framework.
rawsoe_vars <- c(
  "oecd_pmr_2018_2_2_1",  # government involvement in network sectors (OECD PMR)
  "oecd_pmr_2018_2_2_2",  # government involvement in services sectors (OECD PMR)
  "oecd_pmr_2018_1_3",    # direct control over business enterprises (OECD PMR)
  "oecd_pmr_2018_1_4",    # governance of state-owned enterprises (OECD PMR)
  "oecd_pmr_2018_2_1"     # price controls (OECD PMR)
)

rawsoe_tbl <- extract_cliar_data(variables = rawsoe_vars, type = "raw")

dynamicsoe_tbl <- extract_cliar_data(variables = rawsoe_vars, type = "dynamic")

metasoe_tbl <-
  cliaretl::db_variables_final |>
  dplyr::filter(variable %in% rawsoe_vars) |>
  mutate(
    cluster        = "Sectors / Service Delivery",
    cluster_num    = 4,
    subcluster     = "SOE Corporate Governance",
    subcluster_num = 3
  )

saveRDS(rawsoe_tbl,     here::here("data-raw", "output", "rawsoe_tbl.rds"))
saveRDS(dynamicsoe_tbl, here::here("data-raw", "output", "dynamicsoe_tbl.rds"))
saveRDS(metasoe_tbl,    here::here("data-raw", "output", "metasoe_tbl.rds"))

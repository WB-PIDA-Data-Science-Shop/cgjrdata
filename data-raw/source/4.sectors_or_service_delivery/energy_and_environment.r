##############################################################################
############## ENERGY AND ENVIRONMENT INDICATORS #############################
##############################################################################

library(dplyr)
library(haven)

### Sectors / Service Delivery chapter (cluster 4), subcluster 5:
### Energy and Environment Institutions.
###
### NOTE on raw data: RISE variables have etl_source = "wb_api" in the
### cliaretl catalogue but are NOT stored in d360_efi_data. They are sourced
### from a separate Stata file (data-raw/input/RISE_20102021.dta). The raw
### table is therefore assembled by joining the local RISE data with the
### extract_cliar_data() output for the single non-RISE variable (bs_bti_q12_1).

rawee_vars <- c(
  "bs_bti_q12_1",  # environmental policy (BTI)
  "rise_ee_1",     # national energy efficiency planning (RISE)
  "rise_ee_2",     # energy efficiency entities (RISE)
  "rise_ee_3",     # incentives and mandates: industrial and commercial end users (RISE)
  "rise_ee_4",     # incentives and mandates: public sector (RISE)
  "rise_ee_5",     # incentives and mandates: energy utility programs (RISE)
  "rise_ee_6",     # financing mechanisms for energy efficiency (RISE)
  "rise_ee_7",     # minimum energy efficiency performance standards (RISE)
  "rise_ee_8",     # energy labeling systems (RISE)
  "rise_ee_9",     # building energy codes (RISE)
  "rise_re_1",     # legal framework for renewable energy (RISE)
  "rise_re_2",     # planning for renewable energy expansion (RISE)
  "rise_re_3",     # incentives and regulatory support for renewable energy (RISE)
  "rise_re_4",     # attributes of financial and regulatory incentives (RISE)
  "rise_re_7",     # carbon pricing and monitoring (RISE)
  "rise_ee_4_3"    # public procurement of energy efficiency products (RISE)
)

rise_vars <- rawee_vars[startsWith(rawee_vars, "rise_")]
non_rise_vars <- rawee_vars[!startsWith(rawee_vars, "rise_")]

# --- Read the local RISE file and standardise column names to lowercase ---
rise_tbl <- read_dta(here::here("data-raw", "input", "RISE_20102021.dta")) |>
  rename_with(tolower) |>
  select(country_code, year, all_of(rise_vars))

# --- Extract the non-RISE variable via the standard API --------------------
bti_env_tbl <- extract_cliar_data(variables = non_rise_vars, type = "raw")

# --- Join the two raw pieces together -------------------------------------
rawee_tbl <-
  full_join(bti_env_tbl, rise_tbl, by = c("country_code", "year")) |>
  relocate(country_code, country_name, year)

# --- Dynamic CTF table (RISE vars are present in the CTF dataset) ---------
dynamicee_tbl <- extract_cliar_data(variables = rawee_vars, type = "dynamic")

# --- Metadata table -------------------------------------------------------
metaee_tbl <-
  cliaretl::db_variables_final |>
  dplyr::filter(variable %in% rawee_vars) |>
  mutate(
    cluster        = "Sectors / Service Delivery",
    cluster_num    = 4,
    subcluster     = "Energy and Environment",
    subcluster_num = 5
  )

saveRDS(rawee_tbl,     here::here("data-raw", "output", "rawee_tbl.rds"))
saveRDS(dynamicee_tbl, here::here("data-raw", "output", "dynamicee_tbl.rds"))
saveRDS(metaee_tbl,    here::here("data-raw", "output", "metaee_tbl.rds"))

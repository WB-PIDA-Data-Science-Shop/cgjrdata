##############################################################################
## Build the CGJR package data from cliaretl
##############################################################################
## cgjr_crosswalk.csv maps each variable to a leaf of the CGJR taxonomy
## (cgjr_taxonomy.csv). This script joins that mapping onto the cliaretl CTF
## panels and raw source datasets and saves:
##
##   cgjr_taxonomy   leaf-node hierarchy, straight from the CSV
##   cgjr_crosswalk  the mapping + taxonomy names + cliaretl descriptions,
##                   CLIAR eligibility flags and raw source dataset
##   cgjr_ctf        country x year x ctf_type x variable x leaf CTF values
##   cgjr_raw        country x year x variable x leaf raw source values
##
## Run from the package root. Rebuild wbcountries first (data-raw/wbcountries.R)
## only when the World Bank classification file changes.
##############################################################################

devtools::load_all()

library(dplyr)
library(tidyr)
library(readr)

# --- 1. Read the two CSVs ---------------------------------------------------
cgjr_taxonomy <- read_csv("data-raw/input/cgjr_taxonomy.csv",
                          col_types = "cicciccic", na = "")
crosswalk_csv <- read_csv("data-raw/input/cgjr_crosswalk.csv",
                          col_types = "cccicccc", na = "")
stopifnot(nrow(problems(cgjr_taxonomy)) == 0, nrow(problems(crosswalk_csv)) == 0)
cgjr_taxonomy <- tibble::as_tibble(cgjr_taxonomy)
crosswalk_csv <- tibble::as_tibble(crosswalk_csv)

# --- 2. Check the mapping against the taxonomy and cliaretl ----------------
catalogue   <- cliaretl::db_variables_final
ctf_dynamic <- cliaretl::closeness_to_frontier_dynamic
ctf_static  <- cliaretl::closeness_to_frontier_static

check_cgjr_mapping(crosswalk_csv, cgjr_taxonomy, catalogue, ctf_dynamic, ctf_static)

# --- 3. Where each variable's raw values live -------------------------------
# A variable is read from the first dataset below that has it as a column.
# pefa_assessments comes before d360_efi_data, which also carries PEFA columns.
raw_datasets <- c("pefa_assessments", "vdem_data", "wjp", "wdi_indicators",
                  "spi", "gfdb", "debt_transparency", "pmr", "wbl_data",
                  "fraser", "heritage", "romelli", "epl",
                  "obs", "gsod", "freedom_house", "press_freedom",
                  "d360_efi_data")
raw_sources <- sapply(raw_datasets, \(d) getExportedValue("cliaretl", d),
                      simplify = FALSE)

raw_home <- locate_raw_variables(crosswalk_csv$variable, raw_sources)

# --- 4. Annotated crosswalk -------------------------------------------------
descriptions <- catalogue |>
  filter(!is.na(variable)) |>
  distinct(variable, .keep_all = TRUE) |>
  select(variable, description, description_short)

cgjr_crosswalk <- crosswalk_csv |>
  mutate(leaf = coalesce(sub_subcluster, subcluster), .after = sub_subcluster) |>
  left_join(cgjr_taxonomy, by = c("cluster", "subcluster", "sub_subcluster"),
            relationship = "many-to-one") |>
  left_join(descriptions, by = "variable", relationship = "many-to-one") |>
  mutate(flag_ctf_eligibility(variable, catalogue, ctf_dynamic, ctf_static)) |>
  left_join(raw_home, by = "variable", relationship = "many-to-one")

# --- 5. Long tables ---------------------------------------------------------
mapping <- filter(cgjr_crosswalk, !is.na(variable))

cgjr_ctf <- bind_rows(
  dynamic = pivot_wide_to_long_cgjr(ctf_dynamic, filter(mapping, in_dynamic), wbcountries, "ctf"),
  static  = pivot_wide_to_long_cgjr(ctf_static,  filter(mapping, in_static),  wbcountries, "ctf"),
  .id = "ctf_type"
) |>
  relocate(ctf_type, .after = year)
attr(cgjr_ctf, "cliaretl_version") <- as.character(utils::packageVersion("cliaretl"))

cgjr_raw <- lapply(unique(raw_home$raw_dataset), \(d) {
  pivot_wide_to_long_cgjr(raw_sources[[d]], filter(mapping, raw_dataset == d),
                          wbcountries, "value")
}) |>
  bind_rows() |>
  filter(!is.na(value))

# --- 6. Final checks + save -------------------------------------------------
check_duplicate_obs(cgjr_ctf, c("ctf_type", "unit_code", "year", "variable", "leaf"))
check_duplicate_obs(cgjr_raw, c("unit_code", "year", "variable", "leaf"))

usethis::use_data(cgjr_taxonomy, cgjr_crosswalk, cgjr_ctf, cgjr_raw, overwrite = TRUE)

message("cgjr_crosswalk: ", nrow(cgjr_crosswalk), " rows (",
        sum(cgjr_crosswalk$in_dynamic), " dynamic, ", sum(cgjr_crosswalk$in_static), " static)",
        "\ncgjr_ctf: ", nrow(cgjr_ctf), " rows | cgjr_raw: ", nrow(cgjr_raw), " rows")

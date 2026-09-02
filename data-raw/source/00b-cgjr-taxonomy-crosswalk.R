##############################################################################
################## CGJR TAXONOMY CROSSWALK (single source of truth) ###########
##############################################################################
# The taxonomy and every indicator's place in it are maintained as two
# human-editable CSV files:
#
#   data-raw/crosswalk/cgjr_taxonomy.csv    one row per LEAF node
#   data-raw/crosswalk/cgjr_crosswalk.csv   one row per (indicator x leaf)
#
# Edit those in a spreadsheet (Google Sheets, or any CSV-aware editor - avoid
# Excel, which mangles encoding and coerces codes). This script only reads
# them, asserts their structure, validates the resolved variable codes
# against live `cliaretl`, and saves the two lazyloaded package objects.
#
# cgjr_crosswalk columns:
#   cluster, subcluster, sub_subcluster  snake_case taxonomy keys
#                                        (sub_subcluster blank outside PFM)
#   indicator_num                        position within the leaf
#   indicator                            human-readable name (team-specified)
#   source                               stated data source
#   variable                             resolved cliaretl code, blank if none
#   status                               ok | verify | unresolved
#   note                                 free-text caveat / how it was resolved
#
# `status` is the editor's judgement; `validate_crosswalk()$check` is the
# machine verdict against cliaretl. Both are carried into `metadata_tbl`.
#
# See reconfiguration.md for the taxonomy specification.
##############################################################################

library(readr)
library(here)

tax_path <- here::here("data-raw", "crosswalk", "cgjr_taxonomy.csv")
xw_path  <- here::here("data-raw", "crosswalk", "cgjr_crosswalk.csv")

# --- 1. Read the CSVs with an explicit column spec (never guess) ----------
cgjr_taxonomy <- readr::read_csv(
  tax_path,
  col_types = readr::cols(
    cluster             = readr::col_character(),
    cluster_num         = readr::col_integer(),
    cluster_name        = readr::col_character(),
    subcluster          = readr::col_character(),
    subcluster_num      = readr::col_integer(),
    subcluster_name     = readr::col_character(),
    sub_subcluster      = readr::col_character(),
    sub_subcluster_num  = readr::col_integer(),
    sub_subcluster_name = readr::col_character()
  ),
  na = ""
)

cgjr_crosswalk <- readr::read_csv(
  xw_path,
  col_types = readr::cols(
    cluster        = readr::col_character(),
    subcluster     = readr::col_character(),
    sub_subcluster = readr::col_character(),
    indicator_num  = readr::col_integer(),
    indicator      = readr::col_character(),
    source         = readr::col_character(),
    variable       = readr::col_character(),
    status         = readr::col_character(),
    note           = readr::col_character()
  ),
  na = ""
)

if (nrow(readr::problems(cgjr_taxonomy)) > 0L ||
    nrow(readr::problems(cgjr_crosswalk)) > 0L) {
  print(readr::problems(cgjr_taxonomy))
  print(readr::problems(cgjr_crosswalk))
  stop("CSV parsing problems - see above.")
}

cgjr_taxonomy  <- tibble::as_tibble(cgjr_taxonomy)
cgjr_crosswalk <- tibble::as_tibble(cgjr_crosswalk)

# --- 2. Structural integrity (cliaretl-free) ------------------------------
devtools::load_all(quiet = TRUE)
check_crosswalk_schema(cgjr_crosswalk, cgjr_taxonomy)

# --- 3. Validate resolved codes against live cliaretl --------------------
validation <- validate_crosswalk(cgjr_crosswalk)   # emits warnings for failures

utils::write.csv(
  validation,
  here::here("data-raw", "output", "cgjr_crosswalk_validation.csv"),
  row.names = FALSE
)

message(
  "\ncgjr_crosswalk: ", nrow(cgjr_crosswalk), " rows | ",
  sum(validation$check == "ok"), " fully eligible | ",
  sum(validation$check == "not_family_aggregate_eligible"), " in-panel but family-aggregate ineligible | ",
  sum(validation$check == "not_dynamic_eligible"), " not in dynamic panel | ",
  sum(validation$check == "unresolved"), " unresolved (no variable)"
)

# --- 4. Persist as package data -----------------------------------------
usethis::use_data(cgjr_taxonomy,  overwrite = TRUE)
usethis::use_data(cgjr_crosswalk, overwrite = TRUE)

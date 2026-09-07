##############################################################################
################## CGJR TAXONOMY CROSSWALK (single source of truth) ###########
##############################################################################
# The taxonomy and every indicator's place in it are maintained as two
# human-editable CSV files:
#
#   data-raw/input/cgjr_taxonomy.csv    one row per LEAF node
#   data-raw/input/cgjr_crosswalk.csv   one row per (indicator x leaf)
#
# Edit those in a spreadsheet (Google Sheets, or any CSV-aware editor - avoid
# Excel, which mangles encoding and coerces codes). This script only reads
# them, asserts their structure (check_crosswalk_schema), annotates the
# crosswalk against live `cliaretl` (build_crosswalk), reports eligibility
# gaps (validate_crosswalk), and saves the two lazyloaded package objects:
#
#   cgjr_taxonomy   the leaf-node hierarchy, straight from the CSV
#   cgjr_crosswalk  the annotated crosswalk - CSV columns + `leaf` + taxonomy
#                   numbers/names + cliaretl catalogue metadata + eligibility
#                   flags (in_cliaretl / in_dynamic_panel / in_static_panel /
#                   dynamic_eligible / static_eligible / cliaretl_status).
#                   This object absorbs the former `metadata_tbl`.
#
# See PLAN.md for the full column spec.
##############################################################################
devtools::load_all()

library(readr)
library(here)

tax_path <- here::here("data-raw", "input", "cgjr_taxonomy.csv")
xw_path  <- here::here("data-raw", "input", "cgjr_crosswalk.csv")

# --- 1. Read the CSVs with an explicit column spec (never guess) ----------
taxonomy_csv <- readr::read_csv(
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

crosswalk_csv <- readr::read_csv(
  xw_path,
  col_types = readr::cols(
    cluster        = readr::col_character(),
    subcluster     = readr::col_character(),
    sub_subcluster = readr::col_character(),
    indicator_num  = readr::col_integer(),
    indicator      = readr::col_character(),
    source         = readr::col_character(),
    variable       = readr::col_character(),
    note           = readr::col_character()
  ),
  na = ""
)

# --- 2. Guard against CSV parsing problems -------------------------------
if (nrow(readr::problems(taxonomy_csv)) > 0L ||
    nrow(readr::problems(crosswalk_csv)) > 0L) {
  print(readr::problems(taxonomy_csv))
  print(readr::problems(crosswalk_csv))
  stop("CSV parsing problems - see above.")
}

taxonomy_csv  <- tibble::as_tibble(taxonomy_csv)
crosswalk_csv <- tibble::as_tibble(crosswalk_csv)

# --- 3. Structural schema check (cliaretl-free) -------------------------
check_crosswalk_schema(crosswalk_csv, taxonomy_csv)

# --- 4. Taxonomy ships as-is ------------------------------------------
cgjr_taxonomy <- taxonomy_csv

# --- 5. Annotate the crosswalk against live cliaretl -------------------
cgjr_crosswalk <- build_crosswalk(
  crosswalk_csv,
  taxonomy  = cgjr_taxonomy,
  catalogue = cliaretl::db_variables_final
)

# --- 6. Report eligibility gaps (emits warnings) ----------------------
validation <- validate_crosswalk(cgjr_crosswalk)

message(
  "\ncgjr_crosswalk: ", nrow(cgjr_crosswalk), " rows | ",
  sum(validation$cliaretl_status == "resolved"),        " resolved, ",
  sum(validation$cliaretl_status == "not_in_cliaretl"), " not in cliaretl, ",
  sum(validation$cliaretl_status == "unresolved"),      " unresolved | ",
  sum(validation$dynamic_eligible), " dynamic-eligible, ",
  sum(validation$static_eligible),  " static-eligible"
)

# --- 7. Persist as package data ---------------------------------------
usethis::use_data(cgjr_taxonomy,  overwrite = TRUE)
usethis::use_data(cgjr_crosswalk, overwrite = TRUE)

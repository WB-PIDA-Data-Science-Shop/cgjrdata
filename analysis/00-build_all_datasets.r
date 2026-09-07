##############################################################################
########################## BUILD SOURCE DATA OBJECTS #########################
##############################################################################
# Under the new CGJR taxonomy the package no longer has one hand-written
# script per subcluster. All indicator -> cluster/subcluster assignments live
# in a single crosswalk table; this script just (re)builds the two inputs the
# assembly step needs:
#
#   wbcountries    — World Bank country classifications (regions, income)
#   cgjr_taxonomy  — the leaf-node hierarchy of the new taxonomy
#   cgjr_crosswalk — every indicator's placement in that hierarchy, with its
#                    resolved `cliaretl` variable code
#
# Run from the package root, then run analysis/01-build-tidy-data.R.
##############################################################################

devtools::load_all()

# --- 1. World Bank country list (regions with AFE/AFW split, income groups) --
source("data-raw/source/00a-prepare-country-list.R")

# --- 2. CGJR taxonomy + indicator crosswalk --------------------------------
#     Reads the two editable CSVs, checks their structure, annotates the
#     crosswalk against live `cliaretl`, and prints an eligibility summary
#     (warns on rows that will contribute no CTF data).
source("data-raw/source/00b-cgjr-taxonomy-crosswalk.R")

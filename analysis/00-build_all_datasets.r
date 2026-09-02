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
# Run from the package root, then run analysis/01-combine-lazyload.R.
##############################################################################

devtools::load_all()

# --- 1. World Bank country list (regions with AFE/AFW split, income groups) --
source("data-raw/source/00a-prepare-country-list.R")

# --- 2. CGJR taxonomy + indicator crosswalk --------------------------------
#     Emits eligibility warnings and writes
#     data-raw/output/cgjr_crosswalk_validation.csv for review.
source("data-raw/source/00b-cgjr-taxonomy-crosswalk.R")

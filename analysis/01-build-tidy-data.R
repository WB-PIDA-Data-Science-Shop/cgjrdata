##############################################################################
###################### BUILD THE THREE LONG TIDY TIBBLES #####################
##############################################################################
# Assembles cgjr_ctf, cgjr_scores and cgjr_raw from the annotated
# cgjr_crosswalk (built by analysis/00-build_all_datasets.r) and live
# `cliaretl`, and saves them as lazyloaded package data.
#
#   cgjr_ctf     one row per unit x year x ctf_type x leaf x indicator
#   cgjr_scores  one row per unit x year x ctf_type x node (equal-weight rollup)
#   cgjr_raw     one row per country x year x leaf x indicator (country only)
#
# Run analysis/00-build_all_datasets.r first (it rebuilds cgjr_taxonomy /
# cgjr_crosswalk / wbcountries). See PLAN.md for the full column spec.
##############################################################################

devtools::load_all()
library(dplyr)

# --- 1. Country-level tibbles -------------------------------------------
ctf_country   <- build_ctf_tbl(cgjr_crosswalk)
raw_country   <- build_raw_tbl(cgjr_crosswalk)
score_country <- roll_up_scores(ctf_country, cgjr_taxonomy)

# --- 2. Cross-country aggregation --------------------------------------
#     `median` for CLIAR fidelity (see PLAN.md decisions). Switch the single
#     line below to `mean` if the app ever needs it - it is the only knob.
agg <- stats::median

cgjr_ctf <- bind_rows(
  ctf_country,
  aggregate_to_groups(ctf_country, wbcountries, "ctf", agg = agg)
)

cgjr_scores <- bind_rows(
  score_country,
  aggregate_to_groups(score_country, wbcountries, "score", agg = agg)
)

# cgjr_raw is country grain only - heterogeneous units make a regional
# median meaningless (PLAN.md decision Q5).
cgjr_raw <- raw_country

# --- 3. Persist as package data ---------------------------------------
usethis::use_data(cgjr_ctf,    overwrite = TRUE)
usethis::use_data(cgjr_scores, overwrite = TRUE)
usethis::use_data(cgjr_raw,    overwrite = TRUE)

# --- 4. Summary ------------------------------------------------------
message(
  "\ncgjr_ctf:    ", nrow(cgjr_ctf), " rows | ",
  paste(sort(unique(cgjr_ctf$unit_level)), collapse = "/"), " x ",
  paste(sort(unique(cgjr_ctf$ctf_type)), collapse = "/"),
  "\ncgjr_scores: ", nrow(cgjr_scores), " rows | node levels ",
  paste(sort(unique(cgjr_scores$node_level)), collapse = "/"),
  "\ncgjr_raw:    ", nrow(cgjr_raw), " rows | country only, ",
  length(unique(cgjr_raw$unit_code)), " countries"
)

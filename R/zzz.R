## Suppress R CMD check notes for bare column names used in dplyr verbs and
## for package data objects referenced as default argument values.
utils::globalVariables(c(
  "variable", "etl_source", "country_code", "country_name", "year",
  "cgjr_crosswalk", "cgjr_taxonomy"
))

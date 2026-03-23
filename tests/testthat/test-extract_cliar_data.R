## Tests for extract_cliar_data()
##
## Relies on cliaretl being installed (it is in Imports).  All tests use a
## small, stable set of variables so they run quickly and are not brittle.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

doi_vars <- cliaretl::db_variables_final |>
  dplyr::filter(family_name == "Degree of Integrity", !is.na(variable)) |>
  dplyr::pull(variable)

# A single variable known to exist in every type
one_dynamic_var <- "wjp_rol_2"      # in dynamic & static CTF and raw (d360)
one_static_only <- "wb_pefa_pi_2016_05"  # static CTF only, not dynamic
one_raw_var     <- "vdem_core_v2x_pubcorr"  # vdem raw source

# ---------------------------------------------------------------------------
# 1. Return type is always a tibble / data.frame
# ---------------------------------------------------------------------------

test_that("extract_cliar_data returns a tibble for all types", {
  expect_s3_class(extract_cliar_data(one_dynamic_var, type = "dynamic"), "data.frame")
  expect_s3_class(extract_cliar_data(one_dynamic_var, type = "static"),  "data.frame")
  expect_s3_class(extract_cliar_data(one_raw_var,     type = "raw"),     "data.frame")
})

# ---------------------------------------------------------------------------
# 2. Dynamic type – happy path
# ---------------------------------------------------------------------------

test_that("dynamic type returns country_code, country_name, year + requested var", {
  result <- extract_cliar_data(one_dynamic_var, type = "dynamic")
  expect_true(all(c("country_code", "country_name", "year", one_dynamic_var) %in% names(result)))
  expect_gt(nrow(result), 0L)
})

test_that("dynamic type with multiple vars returns all requested columns", {
  vars <- doi_vars[doi_vars %in% names(cliaretl::closeness_to_frontier_dynamic)]
  result <- suppressWarnings(extract_cliar_data(doi_vars, type = "dynamic"))
  expect_true(all(vars %in% names(result)))
})

# ---------------------------------------------------------------------------
# 3. Static type – happy path
# ---------------------------------------------------------------------------

test_that("static type returns country_code, country_name (no year) + requested var", {
  result <- extract_cliar_data(one_dynamic_var, type = "static")
  expect_true(all(c("country_code", "country_name", one_dynamic_var) %in% names(result)))
  expect_false("year" %in% names(result))
})

test_that("static type has one row per country", {
  result <- extract_cliar_data(one_dynamic_var, type = "static")
  expect_equal(nrow(result), dplyr::n_distinct(result$country_code))
})

# ---------------------------------------------------------------------------
# 4. Raw type – happy path
# ---------------------------------------------------------------------------

test_that("raw type returns country_code, year + requested var", {
  result <- extract_cliar_data(one_raw_var, type = "raw")
  expect_true(all(c("country_code", "year", one_raw_var) %in% names(result)))
  expect_gt(nrow(result), 0L)
})

test_that("raw type joins vars from multiple source datasets correctly", {
  multi_raw <- c("vdem_core_v2x_pubcorr", "wjp_rol_2")  # vdem + d360
  result <- extract_cliar_data(multi_raw, type = "raw")
  expect_true(all(multi_raw %in% names(result)))
  expect_true("country_code" %in% names(result))
  expect_true("year" %in% names(result))
})

# ---------------------------------------------------------------------------
# 5. NULL variables → returns all available columns for that type
# ---------------------------------------------------------------------------

test_that("NULL variables returns all columns for dynamic type", {
  result <- extract_cliar_data(variables = NULL, type = "dynamic")
  # Should contain all columns from closeness_to_frontier_dynamic
  expect_equal(names(result), names(cliaretl::closeness_to_frontier_dynamic))
})

test_that("NULL variables returns all columns for static type", {
  result <- extract_cliar_data(variables = NULL, type = "static")
  expect_equal(names(result), names(cliaretl::closeness_to_frontier_static))
})

# ---------------------------------------------------------------------------
# 6. Warning for unrecognised / unavailable variables
# ---------------------------------------------------------------------------

test_that("unrecognised variable names produce a warning and are silently dropped", {
  expect_warning(
    result <- extract_cliar_data(
      c(one_dynamic_var, "this_var_does_not_exist"),
      type = "dynamic"
    ),
    regexp = "not found in db_variables_final"
  )
  expect_true(one_dynamic_var %in% names(result))
  expect_false("this_var_does_not_exist" %in% names(result))
})

test_that("variable present in catalogue but absent from dynamic dataset produces a warning", {
  # wb_pefa_pi_2016_05 is in static and raw (pefa) but NOT in the dynamic dataset
  expect_warning(
    extract_cliar_data("wb_pefa_pi_2016_05", type = "dynamic"),
    regexp = "not present in the dynamic dataset"
  )
})

test_that("variable with no etl_source in raw type produces warning then error", {
  # vars_anticorruption_avg has no etl_source so no raw dataset can supply it.
  # The warning fires first, then an error because nothing remains.
  expect_error(
    suppressWarnings(extract_cliar_data("vars_anticorruption_avg", type = "raw")),
    regexp = "None of the requested variables were found in the raw source datasets"
  )
  expect_warning(
    tryCatch(
      extract_cliar_data("vars_anticorruption_avg", type = "raw"),
      error = function(e) NULL
    ),
    regexp = "not found in any raw source dataset"
  )
})

# ---------------------------------------------------------------------------
# 7. Error when no valid variables remain
# ---------------------------------------------------------------------------

test_that("all-unrecognised variables stops with an error", {
  expect_error(
    suppressWarnings(
      extract_cliar_data(c("nonexistent_a", "nonexistent_b"), type = "dynamic")
    ),
    regexp = "None of the requested variables were found"
  )
})

test_that("variable present in catalogue but absent from all raw datasets stops when alone", {
  expect_error(
    suppressWarnings(
      extract_cliar_data("vars_anticorruption_avg", type = "raw")
    ),
    regexp = "None of the requested variables were found in the raw source datasets"
  )
})

# ---------------------------------------------------------------------------
# 8. Custom id_vars
# ---------------------------------------------------------------------------

test_that("custom id_vars are honoured for dynamic type", {
  result <- extract_cliar_data(
    one_dynamic_var,
    type    = "dynamic",
    id_vars = c("country_code", "year")
  )
  expect_true(all(c("country_code", "year") %in% names(result)))
  expect_false("country_name" %in% names(result))
})

test_that("custom id_vars without year work for static type", {
  result <- extract_cliar_data(
    one_dynamic_var,
    type    = "static",
    id_vars = "country_code"
  )
  expect_true("country_code" %in% names(result))
  expect_false("country_name" %in% names(result))
  expect_false("year" %in% names(result))
})

# ---------------------------------------------------------------------------
# 9. Single-variable edge case
# ---------------------------------------------------------------------------

test_that("a single variable character scalar works (not just vectors)", {
  result <- extract_cliar_data(one_dynamic_var, type = "dynamic")
  expect_true(one_dynamic_var %in% names(result))
  expect_gt(nrow(result), 0L)
})

# ---------------------------------------------------------------------------
# 10. Column ordering – id_vars always come first
# ---------------------------------------------------------------------------

test_that("id_vars are always the leading columns", {
  result <- extract_cliar_data(one_dynamic_var, type = "dynamic")
  id_pos  <- which(names(result) %in% c("country_code", "country_name", "year"))
  data_pos <- which(names(result) == one_dynamic_var)
  expect_true(all(id_pos < data_pos))
})

# ---------------------------------------------------------------------------
# 11. match.arg rejects invalid type
# ---------------------------------------------------------------------------

test_that("invalid type argument raises an error", {
  expect_error(
    extract_cliar_data(one_dynamic_var, type = "invalid"),
    regexp = "should be one of"
  )
})

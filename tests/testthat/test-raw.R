## Tests for build_raw_tbl()
##
## build_raw_tbl() routes through extract_cliar_data(type = "raw"), which
## reads cliaretl source datasets directly - so these tests use the real
## cliaretl and a small, stable slice of the shipped crosswalk.

raw_cols <- c("unit_level", "unit_code", "unit_name", "year",
              "cluster", "subcluster", "sub_subcluster", "leaf",
              "indicator", "variable", "value")

# A couple of crosswalk rows with known raw sources (vdem, d360).
fx_crosswalk <- function() {
  tibble::tibble(
    variable       = c("vdem_core_v2x_pubcorr", "wjp_rol_2", "made_up_var"),
    cluster        = c("institutional_environment", "institutional_environment", "context"),
    subcluster     = c("degree_of_integrity", "degree_of_integrity", "s_x"),
    sub_subcluster = NA_character_,
    leaf           = c("degree_of_integrity", "degree_of_integrity", "s_x"),
    indicator      = c("Public sector corruption", "Absence of corruption", "Nonsense")
  )
}

test_that("build_raw_tbl returns the long tibble schema, country level only", {
  out <- build_raw_tbl(fx_crosswalk())
  expect_s3_class(out, "tbl_df")
  expect_identical(names(out), raw_cols)
  expect_true(all(out$unit_level == "country"))
  expect_type(out$year, "integer")
  expect_type(out$value, "double")
})

test_that("only variables with a raw source appear; the rest are dropped", {
  out <- build_raw_tbl(fx_crosswalk())
  expect_setequal(unique(out$variable),
                  c("vdem_core_v2x_pubcorr", "wjp_rol_2"))
  expect_false("made_up_var" %in% out$variable)
})

test_that("annotations are carried onto every row", {
  out <- build_raw_tbl(fx_crosswalk())
  pc <- out[out$variable == "vdem_core_v2x_pubcorr", ]
  expect_true(all(pc$leaf == "degree_of_integrity"))
  expect_true(all(pc$indicator == "Public sector corruption"))
})

test_that("a crosswalk with no resolvable raw variables yields a 0-row tibble", {
  xw <- fx_crosswalk()
  xw$variable <- c(NA, NA, NA)
  out <- build_raw_tbl(xw)
  expect_equal(nrow(out), 0L)
  expect_identical(names(out), raw_cols)
})

test_that("build_raw_tbl errors on a missing required column", {
  xw <- fx_crosswalk()
  xw$indicator <- NULL
  expect_error(build_raw_tbl(xw), regexp = "missing column\\(s\\): indicator")
})

test_that("build_raw_tbl runs on the full shipped crosswalk", {
  out <- build_raw_tbl(cgjr_crosswalk)
  expect_identical(names(out), raw_cols)
  expect_gt(nrow(out), 0L)
  expect_true(all(out$variable %in% cgjr_crosswalk$variable))
  # no ctf_type column - raw has none
  expect_false("ctf_type" %in% names(out))
})

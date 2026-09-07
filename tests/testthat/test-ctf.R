## Tests for build_ctf_tbl()

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

# Annotated-crosswalk shape (only the columns build_ctf_tbl needs).
fx_crosswalk <- function() {
  tibble::tibble(
    variable         = c("d1",  "d2",  "s1v", "x",   NA,    "d1"),
    cluster          = c("c1",  "c1",  "c1",  "c1",  "c2",  "c2"),
    subcluster       = c("s1",  "s1",  "s2",  "s2",  "s3",  "s4"),
    sub_subcluster   = NA_character_,
    leaf             = c("s1",  "s1",  "s2",  "s2",  "s3",  "s4"),
    indicator        = c("D1",  "D2",  "S1V", "X",   "None","D1 reuse"),
    dynamic_eligible = c(TRUE,  TRUE,  FALSE, FALSE, FALSE, TRUE),
    static_eligible  = c(FALSE, TRUE,  TRUE,  FALSE, FALSE, FALSE)
  )
}

fx_dynamic <- function() {
  tidyr::expand_grid(
    country_code = c("AAA", "BBB"),
    year         = c(2020L, 2021L)
  ) |>
    dplyr::mutate(
      country_name = ifelse(country_code == "AAA", "Aaa", "Bbb"),
      d1 = c(0.1, 0.2, 0.3, 0.4),
      d2 = c(0.5, NA,  0.7, 0.8),
      zzz = 9        # a column that must never appear in the output
    )
}

fx_static <- function() {
  tibble::tibble(
    country_code = c("AAA", "BBB"),
    country_name = c("Aaa", "Bbb"),
    d2   = c(0.55, 0.65),
    s1v  = c(0.11, 0.22),
    zzz  = 9
  )
}

build_fx <- function(xw = fx_crosswalk()) {
  build_ctf_tbl(xw, fx_dynamic(), fx_static())
}

ctf_cols <- c("unit_level", "unit_code", "unit_name", "year", "ctf_type",
              "cluster", "subcluster", "sub_subcluster", "leaf", "indicator",
              "variable", "ctf")

# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

test_that("build_ctf_tbl returns the long tibble schema", {
  out <- build_fx()
  expect_s3_class(out, "tbl_df")
  expect_identical(names(out), ctf_cols)
  expect_true(all(out$unit_level == "country"))
  expect_setequal(unique(out$ctf_type), c("dynamic", "static"))
})

test_that("both ctf_types are stacked with the expected row counts", {
  out <- build_fx()
  # dynamic: d1 -> leaves s1 & s4, d2 -> leaf s1; 4 country-years each
  #   => 4 * (d1:s1, d1:s4, d2:s1) = 12
  # static: d2 -> leaf s1, s1v -> leaf s2; 2 countries each => 4
  expect_equal(sum(out$ctf_type == "dynamic"), 12L)
  expect_equal(sum(out$ctf_type == "static"),  4L)
})

# ---------------------------------------------------------------------------
# Only *_eligible variables contribute
# ---------------------------------------------------------------------------

test_that("only eligible variables appear; ineligible and unresolved contribute nothing", {
  out <- build_fx()
  expect_setequal(unique(out$variable), c("d1", "d2", "s1v"))
  expect_false("x"  %in% out$variable)   # in crosswalk, eligible for neither type
  expect_false(anyNA(out$variable))      # the NA-variable row
})

test_that("a variable ineligible for one type still contributes to the other", {
  out <- build_fx()
  # d2 is dynamic- and static-eligible -> both; s1v static only
  expect_setequal(unique(out$ctf_type[out$variable == "d2"]), c("dynamic", "static"))
  expect_equal(unique(out$ctf_type[out$variable == "s1v"]), "static")
})

test_that("panel columns that are not crosswalk variables are dropped", {
  expect_false("zzz" %in% build_fx()$variable)
})

# ---------------------------------------------------------------------------
# year handling
# ---------------------------------------------------------------------------

test_that("static rows carry year = NA, dynamic rows carry the panel year", {
  out <- build_fx()
  expect_true(all(is.na(out$year[out$ctf_type == "static"])))
  expect_setequal(out$year[out$ctf_type == "dynamic"], c(2020L, 2021L))
  expect_type(out$year, "integer")
})

# ---------------------------------------------------------------------------
# cross-leaf variable reuse
# ---------------------------------------------------------------------------

test_that("a variable reused across leaves fans out to one row per (leaf, indicator)", {
  out <- build_fx()
  d1 <- out[out$variable == "d1" & out$ctf_type == "dynamic", ]
  expect_setequal(unique(d1$leaf), c("s1", "s4"))
  # AAA/2020 d1 = 0.1 should appear once per leaf
  aaa2020 <- d1[d1$unit_code == "AAA" & d1$year == 2020L, ]
  expect_equal(nrow(aaa2020), 2L)
  expect_true(all(aaa2020$ctf == 0.1))
})

# ---------------------------------------------------------------------------
# empty result
# ---------------------------------------------------------------------------

test_that("a crosswalk with no eligible rows yields a 0-row tibble with the schema", {
  xw <- fx_crosswalk()
  xw$dynamic_eligible <- FALSE
  xw$static_eligible  <- FALSE
  out <- build_ctf_tbl(xw, fx_dynamic(), fx_static())
  expect_equal(nrow(out), 0L)
  expect_identical(names(out), ctf_cols)
})

test_that("build_ctf_tbl errors on a missing required column", {
  xw <- fx_crosswalk()
  xw$leaf <- NULL
  expect_error(build_ctf_tbl(xw, fx_dynamic(), fx_static()),
               regexp = "missing column\\(s\\): leaf")
})

# ---------------------------------------------------------------------------
# End-to-end against the real cliaretl panels
# ---------------------------------------------------------------------------

test_that("build_ctf_tbl runs on the shipped crosswalk", {
  out <- build_ctf_tbl(cgjr_crosswalk)
  expect_identical(names(out), ctf_cols)
  expect_setequal(unique(out$ctf_type), c("dynamic", "static"))
  expect_true(all(out$year[out$ctf_type == "static"] |> is.na()))
  elig <- cgjr_crosswalk$variable[cgjr_crosswalk$dynamic_eligible |
                                    cgjr_crosswalk$static_eligible]
  expect_true(all(out$variable %in% elig))
  # every dynamic-eligible variable that is a panel column shows up
  dyn_vars <- intersect(
    cgjr_crosswalk$variable[cgjr_crosswalk$dynamic_eligible],
    names(cliaretl::closeness_to_frontier_dynamic)
  )
  expect_true(all(dyn_vars %in% out$variable[out$ctf_type == "dynamic"]))
})

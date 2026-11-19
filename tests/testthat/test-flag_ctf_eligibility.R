catalogue <- tibble::tibble(
  variable                    = c("a", "b", "c", "d", NA),
  benchmark_dynamic_indicator = c("Yes", "No", "Yes", NA, "Yes"),
  benchmarked_ctf             = c("Yes", "Yes", "No", NA, "Yes")
)
dynamic <- tibble::tibble(country_code = "GHA", year = 2020, a = 1, b = 1, d = 1)
static  <- tibble::tibble(country_code = "GHA", a = 1, b = 1, c = 1, d = 1)

flags <- function(v) flag_ctf_eligibility(v, catalogue, dynamic, static)

test_that("eligibility needs both the panel column and the CLIAR flag", {
  out <- flags(c("a", "b", "c", "d"))
  # a: in both panels, both flags Yes
  # b: in both panels, dynamic flag No
  # c: flagged dynamic but not a dynamic-panel column; static flag No
  # d: in both panels, flags missing
  expect_identical(out$in_dynamic, c(TRUE, FALSE, FALSE, FALSE))
  expect_identical(out$in_static,  c(TRUE, TRUE,  FALSE, FALSE))
})

test_that("returns one row per input, in input order, including NA and unknown variables", {
  out <- flags(c("b", NA, "zzz", "a"))
  expect_named(out, c("in_dynamic", "in_static"))
  expect_identical(nrow(out), 4L)
  expect_identical(out$in_dynamic, c(FALSE, FALSE, FALSE, TRUE))
  expect_identical(out$in_static,  c(TRUE,  FALSE, FALSE, TRUE))
})

test_that("an NA variable is never eligible, even if the catalogue flags an NA row", {
  expect_identical(unlist(flags(NA_character_)), c(in_dynamic = FALSE, in_static = FALSE))
})

test_that("zero-length input gives a zero-row result", {
  expect_identical(nrow(flags(character())), 0L)
})

test_that("bad inputs are rejected with typed errors", {
  expect_error(flags(1:3), class = "cgjrdata_error_bad_argument")
  expect_error(flag_ctf_eligibility("a", catalogue[c("variable", "benchmarked_ctf")],
                                    dynamic, static),
               class = "cgjrdata_error_missing_columns")
})

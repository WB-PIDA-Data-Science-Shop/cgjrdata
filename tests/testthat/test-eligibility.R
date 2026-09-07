## Tests for classify_crosswalk() / validate_crosswalk()
##
## Synthetic catalogue + dynamic/static panels so the eligibility logic is
## exercised without depending on the exact contents of the shipped cliaretl.
## One end-to-end check against the real defaults is kept at the bottom.

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

fx_catalogue <- function() {
  tibble::tibble(
    variable                    = c("d_yes", "d_no", "s_only", "no_panel"),
    benchmark_dynamic_indicator = c("Yes",   "No",   "No",     "Yes")
  )
}

# Only column *names* matter for panel membership.
fx_dynamic <- function() {
  tibble::tibble(country_code = character(), year = integer(),
                 d_yes = double(), d_no = double())
}
fx_static <- function() {
  tibble::tibble(country_code = character(),
                 d_no = double(), s_only = double())
}

fx_crosswalk <- function() {
  tibble::tibble(
    cluster        = c("c1", "c1", "c1", "c1", "c1", "c1"),
    subcluster     = c("s1", "s1", "s1", "s2", "s2", "s2"),
    sub_subcluster = NA_character_,
    indicator_num  = c(1L, 2L, 3L, 1L, 2L, 3L),
    indicator      = c("D yes", "D no", "S only", "No panel", "Ghost", "Missing"),
    source         = "src",
    variable       = c("d_yes", "d_no", "s_only", "no_panel", "ghost_var", NA),
    note           = NA_character_
  )
}

classify_fx <- function(xw = fx_crosswalk()) {
  classify_crosswalk(xw, fx_catalogue(), fx_dynamic(), fx_static())
}

# ---------------------------------------------------------------------------
# classify_crosswalk() – shape
# ---------------------------------------------------------------------------

test_that("classify_crosswalk returns one row per input row, in order", {
  xw  <- fx_crosswalk()
  cls <- classify_fx(xw)
  expect_s3_class(cls, "tbl_df")
  expect_equal(nrow(cls), nrow(xw))
  expect_identical(cls$indicator, xw$indicator)
  expect_identical(cls$variable, xw$variable)
})

test_that("classify_crosswalk emits exactly the documented columns", {
  expect_setequal(
    names(classify_fx()),
    c("cluster", "subcluster", "sub_subcluster", "indicator_num", "indicator",
      "variable", "in_cliaretl", "in_dynamic_panel", "in_static_panel",
      "dynamic_eligible", "static_eligible", "cliaretl_status")
  )
})

# ---------------------------------------------------------------------------
# classify_crosswalk() – per-row verdicts
# ---------------------------------------------------------------------------

test_that("membership and eligibility flags are correct per row", {
  cls <- classify_fx()
  # order: d_yes, d_no, s_only, no_panel, ghost_var, <NA>
  expect_equal(cls$in_cliaretl,      c(TRUE,  TRUE,  TRUE,  TRUE,  FALSE, FALSE))
  expect_equal(cls$in_dynamic_panel, c(TRUE,  TRUE,  FALSE, FALSE, FALSE, FALSE))
  expect_equal(cls$in_static_panel,  c(FALSE, TRUE,  TRUE,  FALSE, FALSE, FALSE))
  expect_equal(cls$dynamic_eligible, c(TRUE,  FALSE, FALSE, FALSE, FALSE, FALSE))
  expect_equal(cls$static_eligible,  c(FALSE, TRUE,  TRUE,  FALSE, FALSE, FALSE))
})

test_that("cliaretl_status separates resolved / not_in_cliaretl / unresolved", {
  cls <- classify_fx()
  expect_equal(
    cls$cliaretl_status,
    c("resolved", "resolved", "resolved", "resolved", "not_in_cliaretl", "unresolved")
  )
})

test_that("dynamic_eligible requires benchmark_dynamic_indicator == 'Yes'", {
  # d_no is in the dynamic panel but flagged 'No'
  cls <- classify_fx()
  i <- which(cls$variable == "d_no")
  expect_true(cls$in_dynamic_panel[i])
  expect_false(cls$dynamic_eligible[i])
})

test_that("static_eligible is pure static-panel membership (no benchmark flag)", {
  cls <- classify_fx()
  # s_only has benchmark_dynamic_indicator 'No' yet is static-eligible
  i <- which(cls$variable == "s_only")
  expect_true(cls$static_eligible[i])
  expect_false(cls$dynamic_eligible[i])
})

test_that("classify_crosswalk errors on a missing required column", {
  xw <- fx_crosswalk()
  xw$variable <- NULL
  expect_error(
    classify_crosswalk(xw, fx_catalogue(), fx_dynamic(), fx_static()),
    regexp = "missing column\\(s\\): variable"
  )
})

# ---------------------------------------------------------------------------
# validate_crosswalk()
# ---------------------------------------------------------------------------

test_that("validate_crosswalk warns about rows that yield no CTF data", {
  expect_warning(
    validate_crosswalk(fx_crosswalk(), fx_catalogue(), fx_dynamic(), fx_static()),
    regexp = "3 of 6 crosswalk rows will contribute no CTF data"
  )
})

test_that("validate_crosswalk warning names each category and the eligible counts", {
  w <- tryCatch(
    validate_crosswalk(fx_crosswalk(), fx_catalogue(), fx_dynamic(), fx_static()),
    warning = conditionMessage
  )
  expect_match(w, "1 unresolved")
  expect_match(w, "1 not in cliaretl")
  expect_match(w, "1 in cliaretl but in no CTF panel")
  expect_match(w, "1 dynamic-eligible")
  expect_match(w, "2 static-eligible only")
  expect_match(w, "\\[no_ctf_panel\\] no_panel :: No panel \\(c1 > s2\\)")
})

test_that("validate_crosswalk returns the classification invisibly", {
  expect_invisible(
    res <- suppressWarnings(
      validate_crosswalk(fx_crosswalk(), fx_catalogue(), fx_dynamic(), fx_static())
    )
  )
  expect_identical(res, classify_fx())
})

test_that("validate_crosswalk is silent when every row is CTF-eligible", {
  xw <- fx_crosswalk()[c(1, 3), ]   # d_yes (dynamic), s_only (static)
  expect_silent(
    validate_crosswalk(xw, fx_catalogue(), fx_dynamic(), fx_static())
  )
})

# ---------------------------------------------------------------------------
# End-to-end against the real cliaretl defaults
# ---------------------------------------------------------------------------

test_that("classify_crosswalk runs on the shipped crosswalk with cliaretl defaults", {
  cls <- classify_crosswalk(cgjr_crosswalk)
  expect_equal(nrow(cls), nrow(cgjr_crosswalk))
  expect_true(all(cls$cliaretl_status %in%
                    c("resolved", "not_in_cliaretl", "unresolved")))
  # unresolved rows are exactly the NA-variable rows
  expect_equal(
    which(cls$cliaretl_status == "unresolved"),
    which(is.na(cgjr_crosswalk$variable))
  )
})

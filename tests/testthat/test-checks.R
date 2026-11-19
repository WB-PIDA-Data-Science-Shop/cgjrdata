# ---- fixtures --------------------------------------------------------------

toy_taxonomy <- function() {
  tibble::tibble(
    cluster        = c("env", "env", "core", "core"),
    subcluster     = c("integrity", "justice", "pfm", "pfm"),
    sub_subcluster = c(NA, NA, "budget", "revenue")
  )
}

toy_crosswalk <- function() {
  tibble::tibble(
    cluster        = c("env", "env", "core", "core"),
    subcluster     = c("integrity", "justice", "pfm", "pfm"),
    sub_subcluster = c(NA, NA, "budget", "revenue"),
    indicator      = c("Corruption", "Courts", "Budget credibility", "Tax effort"),
    variable       = c("v_corr", "v_court", "v_budget", NA)
  )
}

toy_catalogue <- function() {
  tibble::tibble(
    variable                    = c("v_corr", "v_court", "v_budget", "v_family_avg"),
    benchmark_dynamic_indicator = c("Yes", "Yes", "No", "No"),
    benchmarked_ctf             = c("Yes", "Yes", "Yes", "No")
  )
}

toy_dynamic <- function() {
  tibble::tibble(country_code = "GHA", year = 2020, v_corr = 0.5, v_court = 0.4,
                 v_budget = 0.3, v_family_avg = 0.45)
}

toy_static <- function() {
  tibble::tibble(country_code = "GHA", v_corr = 0.5, v_court = 0.4,
                 v_budget = 0.3, v_family_avg = 0.45)
}

run_check <- function(crosswalk = toy_crosswalk(), taxonomy = toy_taxonomy(),
                      catalogue = toy_catalogue()) {
  check_cgjr_mapping(crosswalk, taxonomy, catalogue, toy_dynamic(), toy_static())
}

# ---- check_cgjr_mapping ----------------------------------------------------

test_that("a clean mapping passes every check and returns the crosswalk invisibly", {
  expect_snapshot(out <- run_check())
  expect_identical(out, toy_crosswalk())
  expect_invisible(suppressMessages(run_check()))
})

test_that("duplicate taxonomy leaves stop the build", {
  tax <- toy_taxonomy()
  tax$sub_subcluster[4] <- "budget"
  expect_error(suppressMessages(run_check(taxonomy = tax)),
               class = "cgjrdata_error_duplicate_leaves")
  expect_snapshot(run_check(taxonomy = tax), error = TRUE)
})

test_that("a subcluster key colliding with a sub_subcluster key is a duplicate leaf", {
  tax <- toy_taxonomy()
  tax$sub_subcluster[3] <- "integrity"
  expect_error(suppressMessages(run_check(taxonomy = tax)),
               class = "cgjrdata_error_duplicate_leaves")
})

test_that("crosswalk rows off the taxonomy stop the build and are named", {
  xw <- toy_crosswalk()
  xw$subcluster[2] <- "justise"
  expect_error(suppressMessages(run_check(crosswalk = xw)),
               class = "cgjrdata_error_orphan_leaves")
  expect_snapshot(run_check(crosswalk = xw), error = TRUE)
})

test_that("a missing sub_subcluster on a branching subcluster is an orphan", {
  xw <- toy_crosswalk()
  xw$sub_subcluster[3] <- NA
  expect_error(suppressMessages(run_check(crosswalk = xw)),
               class = "cgjrdata_error_orphan_leaves")
})

test_that("a variable on several leaves is allowed", {
  xw <- toy_crosswalk()
  xw$variable[2] <- "v_corr"
  expect_no_warning(suppressMessages(run_check(crosswalk = xw)))
  expect_no_error(suppressMessages(run_check(crosswalk = xw)))
})

test_that("variables outside the cliaretl catalogue warn but do not stop", {
  xw <- toy_crosswalk()
  xw$variable[4] <- "v_external"
  expect_warning(
    expect_warning(suppressMessages(run_check(crosswalk = xw)),
                   class = "cgjrdata_warning_not_in_catalogue"),
    class = "cgjrdata_warning_no_ctf"
  )
})

test_that("a variable CLIAR does not benchmark warns, even if it is a panel column", {
  xw <- toy_crosswalk()
  xw$variable[4] <- "v_family_avg"   # in both panels, both flags "No"
  w <- expect_warning(suppressMessages(run_check(crosswalk = xw)),
                      class = "cgjrdata_warning_no_ctf")
  expect_match(conditionMessage(w), "v_family_avg")
})

test_that("a static-only variable is fine", {
  # v_budget is flagged for static benchmarking only
  expect_no_warning(suppressMessages(run_check()))
})

test_that("unmapped rows (no variable) are not reported as gaps", {
  xw <- toy_crosswalk()
  xw$variable <- NA_character_
  expect_no_warning(suppressMessages(run_check(crosswalk = xw)))
})

test_that("missing input columns are reported by name", {
  xw <- toy_crosswalk()
  xw$variable <- NULL
  expect_error(run_check(crosswalk = xw), class = "cgjrdata_error_missing_columns")
  expect_error(run_check(crosswalk = xw), "variable")
  expect_error(run_check(taxonomy = toy_taxonomy()[1:2]),
               class = "cgjrdata_error_missing_columns")
})

# ---- check_duplicate_obs ---------------------------------------------------

toy_obs <- function() {
  tibble::tibble(
    ctf_type  = c("dynamic", "dynamic", "static", "static"),
    unit_code = "GHA",
    year      = c(2020L, 2021L, NA, NA),
    variable  = c("v_corr", "v_corr", "v_corr", "v_court"),
    ctf       = c(0.5, 0.6, 0.55, 0.4)
  )
}
obs_keys <- c("ctf_type", "unit_code", "year", "variable")

test_that("unique observations pass and the data come back invisibly", {
  expect_message(out <- check_duplicate_obs(toy_obs(), obs_keys),
                 "No duplicate observations")
  expect_identical(out, toy_obs())
  expect_invisible(suppressMessages(check_duplicate_obs(toy_obs(), obs_keys)))
})

test_that("duplicate observations stop the build and name the repeated keys", {
  dup <- rbind(toy_obs(), toy_obs()[1, ])
  expect_error(check_duplicate_obs(dup, obs_keys), class = "cgjrdata_error_duplicate_obs")
  expect_snapshot(check_duplicate_obs(dup, obs_keys), error = TRUE)
})

test_that("a missing year counts as a key value, not a wildcard", {
  # two static rows for the same variable are duplicates ...
  dup <- rbind(toy_obs(), toy_obs()[3, ])
  expect_error(check_duplicate_obs(dup, obs_keys), class = "cgjrdata_error_duplicate_obs")
  # ... but static rows for different variables are not
  expect_no_error(suppressMessages(check_duplicate_obs(toy_obs(), obs_keys)))
})

test_that("check_duplicate_obs rejects keys the data do not have", {
  expect_error(check_duplicate_obs(toy_obs(), c("unit_code", "leaf")),
               class = "cgjrdata_error_missing_columns")
})

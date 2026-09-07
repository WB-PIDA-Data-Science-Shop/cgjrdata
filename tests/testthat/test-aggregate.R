## Tests for join_wb_classifications() / aggregate_to_groups()

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
# Region R1 = AAA, BBB, CCC; region R2 = DDD, EEE.
# Income High = AAA, BBB; Low = CCC, DDD; EEE has no income classification
# (present in wbcountries with income_group = NA - still counts toward its
# region, but is excluded from income-group aggregation).
# WLD is a World Bank aggregate code with no row in wbcountries at all.

fx_wbcountries <- function() {
  tibble::tibble(
    country_code = c("AAA", "BBB", "CCC", "DDD", "EEE"),
    region       = c("R1", "R1", "R1", "R2", "R2"),
    region_code  = c("R1C", "R1C", "R1C", "R2C", "R2C"),
    income_group = c("High income", "High income", "Low income", "Low income", NA)
  )
}

fx_tbl <- function() {
  tibble::tribble(
    ~unit_code, ~node, ~ctf,
    "AAA", "n1", 0.1,
    "AAA", "n2", NA,
    "BBB", "n1", 0.2,
    "BBB", "n2", 0.5,
    "CCC", "n1", 0.9,
    "CCC", "n2", NA,
    "DDD", "n1", 0.3,
    "DDD", "n2", 0.7,
    "EEE", "n1", NA,
    "EEE", "n2", 0.6,
    "WLD", "n1", 0.99
  ) |>
    dplyr::mutate(unit_level = "country", unit_name = unit_code,
                  year = 2020L, ctf_type = "dynamic")
}

get_group <- function(out, unit_level, unit_code, node) {
  r <- out[out$unit_level == unit_level & out$unit_code == unit_code & out$node == node, ]
  expect_equal(nrow(r), 1L,
               info = paste(unit_level, unit_code, node, "should have exactly one row"))
  r
}

# ---------------------------------------------------------------------------
# join_wb_classifications()
# ---------------------------------------------------------------------------

test_that("join_wb_classifications adds region/income columns, NA for unmatched codes", {
  tbl <- tibble::tibble(unit_code = c("AAA", "WLD"))
  out <- join_wb_classifications(tbl, fx_wbcountries())
  expect_equal(out$region[out$unit_code == "AAA"], "R1")
  expect_true(is.na(out$region[out$unit_code == "WLD"]))
})

# ---------------------------------------------------------------------------
# aggregate_to_groups() - shape and dropped codes
# ---------------------------------------------------------------------------

test_that("aggregate_to_groups emits region and income_group rows only", {
  out <- aggregate_to_groups(fx_tbl(), fx_wbcountries(), "ctf")
  expect_setequal(unique(out$unit_level), c("region", "income_group"))
})

test_that("a World Bank aggregate code with no wbcountries match is dropped entirely", {
  out <- aggregate_to_groups(fx_tbl(), fx_wbcountries(), "ctf")
  # WLD's 0.99 must not leak into any region/income median
  expect_true(all(out$ctf != 0.99 | is.na(out$ctf)))
})

test_that("a country with NA income_group contributes to its region but not to any income group", {
  out <- aggregate_to_groups(fx_tbl(), fx_wbcountries(), "ctf")
  r2_n2 <- get_group(out, "region", "R2C", "n2")   # DDD=0.7, EEE=0.6
  expect_equal(r2_n2$n_inputs, 2L)   # EEE counted here
  # n_inputs counts presence (rows in the group), not non-NA - both AAA/BBB
  # (high) and both CCC/DDD (low) are present at n2 (CCC's value is NA, but
  # it still counts as a member of the group)
  income_n_inputs_total <- sum(out$n_inputs[out$unit_level == "income_group" & out$node == "n2"])
  expect_equal(income_n_inputs_total, 4L)   # EEE is the only one excluded (no income_group)
})

# ---------------------------------------------------------------------------
# Default agg = median
# ---------------------------------------------------------------------------

test_that("the default aggregation is the median across the group's countries", {
  out <- aggregate_to_groups(fx_tbl(), fx_wbcountries(), "ctf")
  # R1/n1 = AAA 0.1, BBB 0.2, CCC 0.9 -> median 0.2 (mean would be 0.4)
  r <- get_group(out, "region", "R1C", "n1")
  expect_equal(r$ctf, 0.2)
  expect_equal(r$n_inputs, 3L)
  expect_equal(r$n_inputs_obs, 3L)
})

test_that("agg can be switched to mean", {
  out <- aggregate_to_groups(fx_tbl(), fx_wbcountries(), "ctf", agg = mean)
  r <- get_group(out, "region", "R1C", "n1")
  expect_equal(r$ctf, 0.4)   # mean(0.1, 0.2, 0.9)
})

# ---------------------------------------------------------------------------
# min_n threshold
# ---------------------------------------------------------------------------

test_that("min_n = 1 (default) keeps a group value backed by a single country", {
  out <- aggregate_to_groups(fx_tbl(), fx_wbcountries(), "ctf")
  # R1/n2 = AAA NA, BBB 0.5, CCC NA -> only 1 observed
  r <- get_group(out, "region", "R1C", "n2")
  expect_equal(r$n_inputs_obs, 1L)
  expect_equal(r$ctf, 0.5)
})

test_that("raising min_n nulls a group value with too few contributing countries, row still present", {
  out <- aggregate_to_groups(fx_tbl(), fx_wbcountries(), "ctf", min_n = 2)
  r <- get_group(out, "region", "R1C", "n2")   # still only 1 country observed
  expect_true(is.na(r$ctf))
  expect_equal(r$n_inputs, 3L)
  expect_equal(r$n_inputs_obs, 1L)   # counts are untouched by min_n
})

# ---------------------------------------------------------------------------
# n_inputs / n_inputs_obs added even when tbl (cgjr_ctf-shaped) never had them
# ---------------------------------------------------------------------------

test_that("aggregate_to_groups adds n_inputs/n_inputs_obs even to a table that never had them", {
  expect_false("n_inputs" %in% names(fx_tbl()))
  out <- aggregate_to_groups(fx_tbl(), fx_wbcountries(), "ctf")
  expect_true(all(c("n_inputs", "n_inputs_obs") %in% names(out)))
})

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

test_that("aggregate_to_groups errors on a missing required tbl column", {
  tbl <- fx_tbl()
  tbl$unit_name <- NULL
  expect_error(aggregate_to_groups(tbl, fx_wbcountries(), "ctf"),
               regexp = "`tbl` is missing column\\(s\\): unit_name")
})

test_that("aggregate_to_groups errors when value_col does not exist", {
  expect_error(aggregate_to_groups(fx_tbl(), fx_wbcountries(), "score"),
               regexp = "`tbl` has no column `score`")
})

test_that("aggregate_to_groups errors on a missing required wbcountries column", {
  wb <- fx_wbcountries()
  wb$region_code <- NULL
  expect_error(aggregate_to_groups(fx_tbl(), wb, "ctf"),
               regexp = "`wbcountries` is missing column\\(s\\): region_code")
})

# ---------------------------------------------------------------------------
# Order-ii: group score is independent of aggregating indicators then
# re-rolling - they are not expected to reconcile, because median isn't
# linear.
# ---------------------------------------------------------------------------

test_that("group node score (order ii) differs from re-rolling group indicator medians", {
  wb <- tibble::tibble(
    country_code = c("X", "Y", "Z"),
    region = "R", region_code = "R1", income_group = "Inc"
  )
  taxonomy <- tibble::tibble(cluster = "c1", subcluster = "s1", sub_subcluster = NA_character_)

  ctf_tbl <- tibble::tribble(
    ~unit_code, ~variable, ~ctf,
    "X", "v1", 0.1,
    "X", "v2", 0.9,
    "Y", "v1", 0.2,
    "Y", "v2", 0.2,
    "Z", "v1", 0.9,
    "Z", "v2", 0.1
  ) |>
    dplyr::mutate(
      unit_level = "country", unit_name = unit_code, year = 2020L, ctf_type = "dynamic",
      cluster = "c1", subcluster = "s1", sub_subcluster = NA_character_,
      leaf = "s1", indicator = variable
    )

  scores_country <- roll_up_scores(ctf_tbl, taxonomy)
  region_scores  <- aggregate_to_groups(scores_country, wb, "score")
  # order ii (what the package does): median of each country's own leaf score
  #   X = mean(0.1, 0.9) = 0.5; Y = mean(0.2, 0.2) = 0.2; Z = mean(0.9, 0.1) = 0.5
  #   region = median(0.5, 0.2, 0.5) = 0.5
  # wb also has a valid income_group for every country, so region_scores /
  # region_ctf below each carry an income_group row too (identical
  # membership here, since there is only one region and one income group) -
  # restrict to unit_level == "region" throughout.
  region_leaf_score <- region_scores$score[region_scores$unit_level == "region" &
                                             region_scores$node_level == "subcluster" &
                                             region_scores$node == "s1"]
  expect_equal(region_leaf_score, 0.5)

  # the alternative (NOT what the package does): aggregate each indicator
  # across countries first, then average those region-level indicator values
  #   region v1 = median(0.1, 0.2, 0.9) = 0.2; region v2 = median(0.9, 0.2, 0.1) = 0.2
  #   "re-rolled" region leaf score = mean(0.2, 0.2) = 0.2
  region_ctf <- aggregate_to_groups(ctf_tbl, wb, "ctf")
  rerolled <- mean(region_ctf$ctf[region_ctf$unit_level == "region"])
  expect_equal(rerolled, 0.2)

  expect_false(isTRUE(all.equal(region_leaf_score, rerolled)))
})

# ---------------------------------------------------------------------------
# End-to-end against real cliaretl-derived data
# ---------------------------------------------------------------------------

test_that("aggregate_to_groups runs on real cgjr_ctf and cgjr_scores country rows", {
  ctf_country   <- build_ctf_tbl(cgjr_crosswalk)
  score_country <- roll_up_scores(ctf_country, cgjr_taxonomy)

  ctf_groups   <- aggregate_to_groups(ctf_country, wbcountries, "ctf")
  score_groups <- aggregate_to_groups(score_country, wbcountries, "score")

  expect_setequal(unique(ctf_groups$unit_level), c("region", "income_group"))
  expect_setequal(unique(score_groups$unit_level), c("region", "income_group"))
  expect_true(all(c("n_inputs", "n_inputs_obs") %in% names(ctf_groups)))
  expect_true(all(ctf_groups$n_inputs_obs <= ctf_groups$n_inputs))
  expect_true(all(score_groups$n_inputs_obs <= score_groups$n_inputs))
})

## Tests for aggregate_groups.R
##
## All tests use small self-contained synthetic data so they run without
## any external data dependencies and remain fast.

library(tibble)

# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

make_cls <- function() {
  tibble(
    country_code = c("AAA", "BBB", "CCC", "DDR"),  # DDR = WB aggregate
    country_name = c("Alpha", "Beta", "Gamma", "Aggregate"),
    year         = c(2020L, 2020L, 2020L, 2020L),
    ind_a        = c(0.2, 0.4, 0.6, 0.8),
    ind_b        = c(0.1, 0.3, NA,  0.5)
  )
}

make_cls_scored <- function() {
  tbl <- make_cls()
  tbl$score       <- c(0.15, 0.35, 0.6, 0.65)
  tbl$var_count   <- 2L
  tbl$nonna_count <- c(2L, 2L, 1L, 2L)
  tbl
}

make_wb <- function() {
  tibble(
    country_code  = c("AAA", "BBB", "CCC"),
    region        = c("Region X", "Region X", "Region Y"),
    region_code   = c("RX", "RX", "RY"),
    income_group  = c("Low income", "Low income", "High income")
  )
}

make_data_list <- function(scored = FALSE) {
  tbl <- if (scored) make_cls_scored() else make_cls()
  list(
    cluster_one = list(
      subcluster_a = tbl,
      subcluster_b = tbl
    ),
    cluster_two = list(
      subcluster_c = tbl
    )
  )
}

# ---------------------------------------------------------------------------
# join_wb_classifications
# ---------------------------------------------------------------------------

test_that("join_wb_classifications adds region, region_code, income_group", {
  result <- join_wb_classifications(make_cls(), make_wb())
  expect_true(all(c("region", "region_code", "income_group") %in% names(result)))
})

test_that("join_wb_classifications preserves original row count", {
  result <- join_wb_classifications(make_cls(), make_wb())
  expect_equal(nrow(result), nrow(make_cls()))
})

test_that("join_wb_classifications sets NA for unmatched country codes", {
  result <- join_wb_classifications(make_cls(), make_wb())
  # DDR is not in make_wb()
  ddr_row <- result[result$country_code == "DDR", ]
  expect_true(is.na(ddr_row$region))
  expect_true(is.na(ddr_row$income_group))
})

test_that("join_wb_classifications matches correct values", {
  result <- join_wb_classifications(make_cls(), make_wb())
  aaa_row <- result[result$country_code == "AAA", ]
  expect_equal(aaa_row$region, "Region X")
  expect_equal(aaa_row$income_group, "Low income")
})

# ---------------------------------------------------------------------------
# aggregate_tbl_by_group — basic structure
# ---------------------------------------------------------------------------

test_that("aggregate_tbl_by_group drops country_code and country_name", {
  tbl    <- join_wb_classifications(make_cls(), make_wb())
  result <- aggregate_tbl_by_group(tbl, group_cols = c("region", "region_code"))
  expect_false("country_code" %in% names(result))
  expect_false("country_name" %in% names(result))
})

test_that("aggregate_tbl_by_group drops score/var_count/nonna_count from scored input", {
  tbl    <- join_wb_classifications(make_cls_scored(), make_wb())
  result <- aggregate_tbl_by_group(tbl, group_cols = c("region", "region_code"))
  # old score is dropped; a fresh one is recomputed — but the column should exist
  # var_count and nonna_count should NOT be present (they were score artefacts)
  expect_false("var_count" %in% names(result))
  expect_false("nonna_count" %in% names(result))
})

test_that("aggregate_tbl_by_group returns one row per group x year", {
  tbl    <- join_wb_classifications(make_cls(), make_wb())
  result <- aggregate_tbl_by_group(tbl, group_cols = c("region", "region_code"))
  # AAA + BBB → Region X/2020; CCC → Region Y/2020; DDR dropped (NA region)
  expect_equal(nrow(result), 2L)
})

test_that("aggregate_tbl_by_group drops NA-group rows (WB aggregates)", {
  tbl    <- join_wb_classifications(make_cls(), make_wb())
  result <- aggregate_tbl_by_group(tbl, group_cols = c("region", "region_code"))
  expect_false(anyNA(result$region))
})

test_that("aggregate_tbl_by_group output contains group_cols and year", {
  tbl    <- join_wb_classifications(make_cls(), make_wb())
  result <- aggregate_tbl_by_group(tbl, group_cols = c("region", "region_code"))
  expect_true(all(c("region", "region_code", "year") %in% names(result)))
})

# ---------------------------------------------------------------------------
# aggregate_tbl_by_group — arithmetic correctness
# ---------------------------------------------------------------------------

test_that("aggregate_tbl_by_group computes correct column means", {
  tbl    <- join_wb_classifications(make_cls(), make_wb())
  result <- aggregate_tbl_by_group(tbl, group_cols = c("region", "region_code"))

  rx <- result[result$region == "Region X", ]
  # AAA: ind_a=0.2, BBB: ind_a=0.4 → mean = 0.3
  expect_equal(rx$ind_a, 0.3)
  # AAA: ind_b=0.1, BBB: ind_b=0.3 → mean = 0.2
  expect_equal(rx$ind_b, 0.2)
})

test_that("aggregate_tbl_by_group na.rm = TRUE when averaging indicators", {
  tbl    <- join_wb_classifications(make_cls(), make_wb())
  result <- aggregate_tbl_by_group(tbl, group_cols = c("region", "region_code"))

  # Region Y has only CCC: ind_b = NA → mean with na.rm = NaN → coerced to NA
  ry <- result[result$region == "Region Y", ]
  expect_true(is.na(ry$ind_b))
})

test_that("aggregate_tbl_by_group recomputes score as rowMeans of indicators", {
  tbl    <- join_wb_classifications(make_cls(), make_wb())
  result <- aggregate_tbl_by_group(tbl, group_cols = c("region", "region_code"))

  rx <- result[result$region == "Region X", ]
  # ind_a mean = 0.3, ind_b mean = 0.2 → score = mean(0.3, 0.2) = 0.25
  expect_equal(rx$score, 0.25)
})

test_that("aggregate_tbl_by_group score is NA (not NaN) when all indicators NA", {
  # Build a group where every indicator is NA
  tbl <- tibble(
    country_code = c("AAA", "BBB"),
    country_name = c("Alpha", "Beta"),
    year         = c(2020L, 2020L),
    ind_a        = c(NA_real_, NA_real_)
  )
  wb <- tibble(
    country_code = c("AAA", "BBB"),
    region       = c("Region X", "Region X"),
    region_code  = c("RX", "RX"),
    income_group = c("Low income", "Low income")
  )
  enriched <- join_wb_classifications(tbl, wb)
  result   <- aggregate_tbl_by_group(enriched, group_cols = c("region", "region_code"))
  expect_true(is.na(result$score))
  expect_false(is.nan(result$score))
})

test_that("aggregate_tbl_by_group works with income_group grouping", {
  tbl    <- join_wb_classifications(make_cls(), make_wb())
  result <- aggregate_tbl_by_group(tbl, group_cols = "income_group")
  expect_true("income_group" %in% names(result))
  # Low income: AAA + BBB; High income: CCC; DDR dropped
  expect_equal(nrow(result), 2L)
})

test_that("aggregate_tbl_by_group handles multiple years correctly", {
  tbl <- tibble(
    country_code = c("AAA", "BBB", "AAA", "BBB"),
    country_name = c("Alpha", "Beta", "Alpha", "Beta"),
    year         = c(2019L, 2019L, 2020L, 2020L),
    ind_a        = c(0.1, 0.3, 0.2, 0.4)
  )
  wb <- tibble(
    country_code = c("AAA", "BBB"),
    region       = c("Region X", "Region X"),
    region_code  = c("RX", "RX"),
    income_group = c("Low income", "Low income")
  )
  enriched <- join_wb_classifications(tbl, wb)
  result   <- aggregate_tbl_by_group(enriched, group_cols = c("region", "region_code"))
  # One row per region × year → 2 rows
  expect_equal(nrow(result), 2L)
  yr2019 <- result[result$year == 2019L, ]
  expect_equal(yr2019$ind_a, 0.2)  # mean(0.1, 0.3)
})

# ---------------------------------------------------------------------------
# aggregate_data_list — structure
# ---------------------------------------------------------------------------

test_that("aggregate_data_list returns a list with same cluster names", {
  dl     <- make_data_list()
  result <- aggregate_data_list(dl, "region", make_wb())
  expect_equal(names(result), names(dl))
})

test_that("aggregate_data_list returns same subcluster names", {
  dl     <- make_data_list()
  result <- aggregate_data_list(dl, "region", make_wb())
  expect_equal(names(result$cluster_one), names(dl$cluster_one))
  expect_equal(names(result$cluster_two), names(dl$cluster_two))
})

test_that("aggregate_data_list leaves are tibbles", {
  dl     <- make_data_list()
  result <- aggregate_data_list(dl, "region", make_wb())
  expect_s3_class(result$cluster_one$subcluster_a, "tbl_df")
})

test_that("aggregate_data_list region output has region and region_code columns", {
  dl     <- make_data_list()
  result <- aggregate_data_list(dl, "region", make_wb())
  leaf   <- result$cluster_one$subcluster_a
  expect_true(all(c("region", "region_code", "year") %in% names(leaf)))
})

test_that("aggregate_data_list income_group output has income_group column", {
  dl     <- make_data_list()
  result <- aggregate_data_list(dl, "income_group", make_wb())
  leaf   <- result$cluster_one$subcluster_a
  expect_true("income_group" %in% names(leaf))
  expect_false("region" %in% names(leaf))
})

test_that("aggregate_data_list output has score column", {
  dl     <- make_data_list()
  result <- aggregate_data_list(dl, "region", make_wb())
  expect_true("score" %in% names(result$cluster_one$subcluster_a))
})

test_that("aggregate_data_list drops var_count and nonna_count from scored input", {
  dl     <- make_data_list(scored = TRUE)
  result <- aggregate_data_list(dl, "region", make_wb())
  leaf   <- result$cluster_one$subcluster_a
  expect_false("var_count"   %in% names(leaf))
  expect_false("nonna_count" %in% names(leaf))
})

# ---------------------------------------------------------------------------
# aggregate_data_list — input validation
# ---------------------------------------------------------------------------

test_that("aggregate_data_list errors on invalid group_col", {
  expect_error(
    aggregate_data_list(make_data_list(), "bad_col", make_wb()),
    regexp = "group_col"
  )
})

test_that("aggregate_data_list errors when data_list is not a list", {
  expect_error(
    aggregate_data_list("not_a_list", "region", make_wb()),
    regexp = "is.list"
  )
})

# ---------------------------------------------------------------------------
# aggregate_data_list — arbitrary nesting depth + empty leaves
# ---------------------------------------------------------------------------

test_that("aggregate_data_list recurses into a three-level branch", {
  dl <- make_data_list()
  dl$cluster_one$subcluster_a <- list(
    ss_x = make_cls(),
    ss_y = make_cls()
  )
  result <- aggregate_data_list(dl, "region", make_wb())
  expect_true(is.list(result$cluster_one$subcluster_a))
  expect_s3_class(result$cluster_one$subcluster_a$ss_x, "tbl_df")
  expect_true(all(c("region", "region_code", "year") %in%
                    names(result$cluster_one$subcluster_a$ss_x)))
})

test_that("aggregate_data_list returns an empty shell for a zero-row leaf", {
  dl <- make_data_list()
  dl$cluster_two$subcluster_c <- tibble(
    country_code = character(0), country_name = character(0),
    year = integer(0)
  )
  result <- aggregate_data_list(dl, "region", make_wb())
  leaf <- result$cluster_two$subcluster_c
  expect_s3_class(leaf, "tbl_df")
  expect_equal(nrow(leaf), 0L)
  expect_true("score" %in% names(leaf))
})

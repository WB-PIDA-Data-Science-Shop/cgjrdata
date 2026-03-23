## Tests for compute_scores.R
##
## Tests use small synthetic tibbles so they run without any external data
## dependencies and remain fast.

library(tibble)

# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

# Minimal 3-row CTF subcluster tibble (2 indicators)
make_tbl <- function() {
  tibble::tibble(
    country_code = c("AAA", "BBB", "CCC"),
    country_name = c("Alpha", "Beta", "Gamma"),
    year         = c(2020L, 2020L, 2020L),
    ind_a        = c(0.2, 0.4, NA),
    ind_b        = c(0.6, NA, NA)
  )
}

# Minimal ctfdata_list with 2 clusters, 2 subclusters each
make_ctf_list <- function() {
  tbl1 <- tibble::tibble(
    country_code = c("AAA", "BBB"),
    country_name = c("Alpha", "Beta"),
    year         = c(2020L, 2020L),
    ind_a        = c(0.2, 0.8),
    ind_b        = c(0.4, 0.6)
  )
  tbl2 <- tibble::tibble(
    country_code = c("AAA", "BBB"),
    country_name = c("Alpha", "Beta"),
    year         = c(2020L, 2020L),
    ind_c        = c(0.1, 0.9)
  )
  tbl3 <- tibble::tibble(
    country_code = c("AAA", "BBB"),
    country_name = c("Alpha", "Beta"),
    year         = c(2020L, 2020L),
    ind_d        = c(0.5, 0.5)
  )
  tbl4 <- tibble::tibble(
    country_code = c("AAA", "BBB"),
    country_name = c("Alpha", "Beta"),
    year         = c(2020L, 2020L),
    ind_e        = c(0.3, 0.7),
    ind_f        = c(0.7, 0.3)
  )
  list(
    cluster_one = list(
      subcluster_a = tbl1,
      subcluster_b = tbl2
    ),
    cluster_two = list(
      subcluster_c = tbl3,
      subcluster_d = tbl4
    )
  )
}

# ============================================================================
# add_subcluster_score()
# ============================================================================

test_that("add_subcluster_score returns original columns plus score, var_count, nonna_count", {
  result <- add_subcluster_score(make_tbl())
  expect_true(all(c("score", "var_count", "nonna_count") %in% names(result)))
  expect_true(all(c("country_code", "country_name", "year", "ind_a", "ind_b") %in% names(result)))
})

test_that("add_subcluster_score computes correct rowMeans with na.rm", {
  result <- add_subcluster_score(make_tbl())
  # Row 1: mean(0.2, 0.6) = 0.4
  expect_equal(result$score[1], 0.4, tolerance = 1e-9)
  # Row 2: mean(0.4, NA, na.rm=TRUE) = 0.4
  expect_equal(result$score[2], 0.4, tolerance = 1e-9)
  # Row 3: all NA → score should be NA
  expect_true(is.na(result$score[3]))
})

test_that("add_subcluster_score sets var_count correctly", {
  result <- add_subcluster_score(make_tbl())
  expect_equal(unique(result$var_count), 2L)
})

test_that("add_subcluster_score sets nonna_count correctly", {
  result <- add_subcluster_score(make_tbl())
  expect_equal(result$nonna_count[1], 2L)   # both non-NA
  expect_equal(result$nonna_count[2], 1L)   # one non-NA
  expect_equal(result$nonna_count[3], 0L)   # all NA
})

test_that("add_subcluster_score returns NA (not NaN) when all indicators are NA", {
  tbl <- tibble::tibble(
    country_code = "AAA", country_name = "Alpha", year = 2020L,
    ind_a = NA_real_, ind_b = NA_real_
  )
  result <- add_subcluster_score(tbl)
  expect_true(is.na(result$score))
  expect_false(is.nan(result$score))
})

test_that("add_subcluster_score handles tibble with zero indicator columns", {
  id_only <- tibble::tibble(
    country_code = c("AAA"),
    country_name = c("Alpha"),
    year         = 2020L
  )
  result <- add_subcluster_score(id_only)
  expect_true(is.na(result$score))
  expect_equal(result$var_count, 0L)
  expect_equal(result$nonna_count, 0L)
})

test_that("add_subcluster_score respects custom id_cols", {
  tbl <- tibble::tibble(
    cc   = c("AAA", "BBB"),
    yr   = c(2020L, 2020L),
    ind1 = c(0.2, 0.8),
    ind2 = c(0.4, 0.6)
  )
  result <- add_subcluster_score(tbl, id_cols = c("cc", "yr"))
  # ind1 and ind2 should be treated as indicators
  expect_equal(unique(result$var_count), 2L)
  expect_equal(result$score[1], mean(c(0.2, 0.4)), tolerance = 1e-9)
})

test_that("add_subcluster_score errors on non-data-frame input", {
  expect_error(add_subcluster_score("not a dataframe"))
})

test_that("add_subcluster_score works with a single indicator column", {
  tbl <- tibble::tibble(
    country_code = c("AAA", "BBB"),
    country_name = c("Alpha", "Beta"),
    year         = c(2020L, 2020L),
    ind_solo     = c(0.5, NA)
  )
  result <- add_subcluster_score(tbl)
  expect_equal(result$score[1], 0.5, tolerance = 1e-9)
  expect_true(is.na(result$score[2]))
  expect_equal(unique(result$var_count), 1L)
})

# ============================================================================
# score_ctfdata_list()
# ============================================================================

test_that("score_ctfdata_list returns same nested list structure", {
  scored <- score_ctfdata_list(make_ctf_list())
  expect_equal(names(scored), c("cluster_one", "cluster_two"))
  expect_equal(names(scored$cluster_one), c("subcluster_a", "subcluster_b"))
  expect_equal(names(scored$cluster_two), c("subcluster_c", "subcluster_d"))
})

test_that("score_ctfdata_list adds score/var_count/nonna_count to every leaf tibble", {
  scored <- score_ctfdata_list(make_ctf_list())
  for (cluster in scored) {
    for (sub in cluster) {
      expect_true(all(c("score", "var_count", "nonna_count") %in% names(sub)))
    }
  }
})

test_that("score_ctfdata_list does not modify id columns", {
  scored <- score_ctfdata_list(make_ctf_list())
  sub <- scored$cluster_one$subcluster_a
  expect_true(all(c("country_code", "country_name", "year") %in% names(sub)))
  expect_equal(sub$country_code, c("AAA", "BBB"))
})

test_that("score_ctfdata_list errors on non-list input", {
  expect_error(score_ctfdata_list("not a list"))
})

# ============================================================================
# compute_cluster_averages()
# ============================================================================

test_that("compute_cluster_averages returns a tibble", {
  scored <- score_ctfdata_list(make_ctf_list())
  result <- compute_cluster_averages(scored)
  expect_s3_class(result, "tbl_df")
})

test_that("compute_cluster_averages returns expected columns", {
  scored <- score_ctfdata_list(make_ctf_list())
  result <- compute_cluster_averages(scored)
  expected_cols <- c(
    "country_code", "country_name", "year",
    "cluster_one_score", "cluster_two_score",
    "overall_score"
  )
  expect_true(all(expected_cols %in% names(result)))
})

test_that("compute_cluster_averages cluster score is mean of subcluster scores (Option A)", {
  scored <- score_ctfdata_list(make_ctf_list())
  result <- compute_cluster_averages(scored)

  # For AAA, cluster_one has subcluster_a and subcluster_b
  # subcluster_a: ind_a=0.2, ind_b=0.4 → score = 0.3
  # subcluster_b: ind_c=0.1 → score = 0.1
  # cluster_one_score = mean(0.3, 0.1) = 0.2
  aaa_row <- result[result$country_code == "AAA", ]
  expect_equal(aaa_row$cluster_one_score, 0.2, tolerance = 1e-9)
})

test_that("compute_cluster_averages overall_score is mean of cluster scores", {
  scored <- score_ctfdata_list(make_ctf_list())
  result <- compute_cluster_averages(scored)

  # For AAA:
  # cluster_one_score = mean(0.3, 0.1) = 0.2
  # cluster_two:
  #   subcluster_c: ind_d=0.5 → score = 0.5
  #   subcluster_d: ind_e=0.3, ind_f=0.7 → score = 0.5
  # cluster_two_score = mean(0.5, 0.5) = 0.5
  # overall_score = mean(0.2, 0.5) = 0.35
  aaa_row <- result[result$country_code == "AAA", ]
  expect_equal(aaa_row$overall_score, 0.35, tolerance = 1e-9)
})

test_that("compute_cluster_averages returns NA (not NaN) for all-NA cluster", {
  # Build a list where one cluster has all-NA scores
  na_tbl <- tibble::tibble(
    country_code = "AAA", country_name = "Alpha", year = 2020L,
    ind_z = NA_real_
  )
  na_scored <- add_subcluster_score(na_tbl)
  lst <- list(
    cluster_na  = list(subcluster_x = na_scored),
    cluster_ok  = list(subcluster_y = add_subcluster_score(
      tibble::tibble(country_code="AAA", country_name="Alpha", year=2020L, ind_a=0.5)
    ))
  )
  result <- compute_cluster_averages(lst)
  expect_true(is.na(result$cluster_na_score))
  expect_false(is.nan(result$cluster_na_score))
  # overall_score should still compute from cluster_ok only (na.rm=TRUE)
  expect_equal(result$overall_score, 0.5, tolerance = 1e-9)
})

test_that("compute_cluster_averages errors when score column is missing", {
  raw_ctf <- make_ctf_list()  # not yet scored
  expect_error(
    compute_cluster_averages(raw_ctf),
    regexp = "does not have a `score` column"
  )
})

test_that("compute_cluster_averages errors on unnamed list", {
  unnamed <- list(list(a = score_ctfdata_list(make_ctf_list())[[1]][[1]]))
  expect_error(compute_cluster_averages(unnamed))
})

test_that("compute_cluster_averages output is sorted by country_code then year", {
  # Build a list with two countries in reverse order
  tbl_unsorted <- tibble::tibble(
    country_code = c("ZZZ", "AAA"),
    country_name = c("Zeta", "Alpha"),
    year         = c(2020L, 2020L),
    ind_a        = c(0.1, 0.9)
  )
  lst <- list(cluster_one = list(subcluster_a = add_subcluster_score(tbl_unsorted)))
  result <- compute_cluster_averages(lst)
  expect_equal(result$country_code, sort(result$country_code))
})

test_that("compute_cluster_averages handles multiple years correctly", {
  tbl <- tibble::tibble(
    country_code = c("AAA", "AAA", "BBB", "BBB"),
    country_name = c("Alpha", "Alpha", "Beta", "Beta"),
    year         = c(2020L, 2021L, 2020L, 2021L),
    ind_a        = c(0.2, 0.4, 0.6, 0.8)
  )
  lst <- list(cluster_one = list(subcluster_a = add_subcluster_score(tbl)))
  result <- compute_cluster_averages(lst)
  expect_equal(nrow(result), 4L)
  expect_true(all(c(2020L, 2021L) %in% result$year))
})

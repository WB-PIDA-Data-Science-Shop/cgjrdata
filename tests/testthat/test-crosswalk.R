## Tests for crosswalk.R — validate_crosswalk() and the generic builders.
##
## The synthetic-fixture tests run without cliaretl. Tests that exercise the
## real crosswalk are guarded on cgjr_crosswalk / cliaretl being available.

library(tibble)

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

make_catalogue <- function() {
  tibble::tibble(
    variable = c("ok_var", "fa_no_var", "dyn_no_var", "static_var"),
    benchmark_dynamic_indicator        = c("Yes", "Yes", "No",  "Yes"),
    benchmark_dynamic_family_aggregate = c("Yes", "No",  "No",  "Partial")
  )
}

make_ctf <- function() {
  tibble::tibble(
    country_code = c("AAA", "BBB"),
    country_name = c("Alpha", "Beta"),
    year         = c(2020L, 2020L),
    ok_var       = c(0.2, 0.8),
    fa_no_var    = c(0.3, 0.7),
    dyn_no_var   = c(0.1, 0.9)   # present here but flagged "No" in catalogue
  )
}

make_xw <- function() {
  tibble::tibble(
    cluster        = "c1",
    subcluster     = c("s1", "s1", "s1", "s1", "s2"),
    sub_subcluster = NA_character_,
    indicator_num  = c(1L, 2L, 3L, 4L, 1L),
    indicator      = c("ok", "fa no", "dyn no", "not in cat", "unresolved"),
    source         = "src",
    variable       = c("ok_var", "fa_no_var", "dyn_no_var", "missing_var", NA),
    note           = NA_character_
  )
}

make_tax <- function() {
  tibble::tibble(
    cluster = "c1", cluster_num = 1L, cluster_name = "C1",
    subcluster = c("s1", "s2"), subcluster_num = c(1L, 2L),
    subcluster_name = c("S1", "S2"),
    sub_subcluster = NA_character_, sub_subcluster_num = NA_integer_,
    sub_subcluster_name = NA_character_
  )
}

# ---------------------------------------------------------------------------
# validate_crosswalk()
# ---------------------------------------------------------------------------

test_that("validate_crosswalk classifies each row correctly", {
  res <- suppressWarnings(
    validate_crosswalk(make_xw(), catalogue = make_catalogue(), ctf_dynamic = make_ctf())
  )
  checks <- setNames(res$check, res$indicator)
  expect_equal(unname(checks["ok"]),         "ok")
  expect_equal(unname(checks["fa no"]),      "not_family_aggregate_eligible")
  expect_equal(unname(checks["dyn no"]),     "not_dynamic_eligible")
  expect_equal(unname(checks["not in cat"]), "not_in_catalogue")
  expect_equal(unname(checks["unresolved"]), "unresolved")
})

test_that("validate_crosswalk warns about non-ok rows and returns invisibly", {
  expect_warning(
    validate_crosswalk(make_xw(), catalogue = make_catalogue(), ctf_dynamic = make_ctf()),
    regexp = "failed eligibility checks"
  )
})

test_that("validate_crosswalk errors on missing required columns", {
  expect_error(
    validate_crosswalk(tibble::tibble(variable = "x")),
    regexp = "missing required column"
  )
})

# ---------------------------------------------------------------------------
# check_crosswalk_schema()
# ---------------------------------------------------------------------------

test_that("check_crosswalk_schema passes a well-formed crosswalk/taxonomy pair", {
  expect_invisible(check_crosswalk_schema(make_xw(), make_tax()))
  expect_identical(check_crosswalk_schema(make_xw(), make_tax()), make_xw())
})

test_that("check_crosswalk_schema flags a leaf path missing from the taxonomy", {
  xw <- make_xw()
  xw$subcluster[1] <- "s_typo"
  expect_error(check_crosswalk_schema(xw, make_tax()),
               regexp = "not found in taxonomy")
})

test_that("check_crosswalk_schema flags duplicate indicator_num within a leaf", {
  xw <- make_xw()
  xw$indicator_num[2] <- 1L     # rows 1 and 2 are both s1 / indicator_num 1
  expect_error(check_crosswalk_schema(xw, make_tax()),
               regexp = "duplicate indicator_num")
})

test_that("check_crosswalk_schema flags a duplicate variable within a leaf", {
  xw <- make_xw()
  xw$variable[2] <- "ok_var"    # same as row 1, same leaf
  expect_error(check_crosswalk_schema(xw, make_tax()),
               regexp = "duplicate variable")
})

test_that("check_crosswalk_schema reports missing columns", {
  expect_error(
    check_crosswalk_schema(tibble::tibble(cluster = "c1"), make_tax()),
    regexp = "missing column"
  )
})

test_that("the shipped cgjr_crosswalk / cgjr_taxonomy pass the schema check", {
  skip_if_not(exists("cgjr_crosswalk") && exists("cgjr_taxonomy"))
  expect_invisible(check_crosswalk_schema(cgjr_crosswalk, cgjr_taxonomy))
})

# ---------------------------------------------------------------------------
# build_ctfdata_list()
# ---------------------------------------------------------------------------

test_that("build_ctfdata_list nests to the taxonomy shape and only keeps panel columns", {
  ctf <- suppressWarnings(
    build_ctfdata_list(make_xw(), make_tax(), ctf_dynamic = make_ctf(),
                       catalogue = make_catalogue(), validate = FALSE)
  )
  expect_named(ctf, "c1")
  expect_named(ctf$c1, c("s1", "s2"))
  # s1 keeps ok_var + fa_no_var (both real panel columns); drops dyn/missing/NA
  expect_true(all(c("ok_var", "fa_no_var") %in% names(ctf$c1$s1)))
  expect_false("dyn_no_var" %in% names(ctf$c1$s1))
  expect_false("missing_var" %in% names(ctf$c1$s1))
})

test_that("build_ctfdata_list returns a zero-row tibble for an all-ineligible leaf", {
  # s2's only indicator is unresolved (variable NA)
  ctf <- suppressWarnings(
    build_ctfdata_list(make_xw(), make_tax(), ctf_dynamic = make_ctf(),
                       catalogue = make_catalogue(), validate = FALSE)
  )
  expect_s3_class(ctf$c1$s2, "tbl_df")
  expect_equal(nrow(ctf$c1$s2), 0L)
  expect_true(all(c("country_code", "country_name", "year") %in% names(ctf$c1$s2)))
})

test_that("build_ctfdata_list supports a three-level (sub-subcluster) branch", {
  xw <- make_xw()
  xw$sub_subcluster[xw$subcluster == "s2"] <- "ss1"
  tax <- make_tax()
  tax$sub_subcluster[tax$subcluster == "s2"] <- "ss1"
  ctf <- suppressWarnings(
    build_ctfdata_list(xw, tax, ctf_dynamic = make_ctf(),
                       catalogue = make_catalogue(), validate = FALSE)
  )
  expect_s3_class(ctf$c1$s1, "tbl_df")
  expect_true(is.list(ctf$c1$s2) && !is.data.frame(ctf$c1$s2))
  expect_s3_class(ctf$c1$s2$ss1, "tbl_df")
})

# ---------------------------------------------------------------------------
# Real crosswalk (needs cliaretl + built data)
# ---------------------------------------------------------------------------

test_that("the shipped .rda objects match their source CSVs", {
  csv_dir <- testthat::test_path("..", "..", "data-raw", "input")
  skip_if_not(dir.exists(csv_dir))

  xw_csv <- utils::read.csv(
    file.path(csv_dir, "cgjr_crosswalk.csv"),
    colClasses = "character", na.strings = "", check.names = FALSE
  )
  tx_csv <- utils::read.csv(
    file.path(csv_dir, "cgjr_taxonomy.csv"),
    colClasses = "character", na.strings = "", check.names = FALSE
  )
  expect_equal(nrow(xw_csv), nrow(cgjr_crosswalk))
  expect_equal(nrow(tx_csv), nrow(cgjr_taxonomy))
  expect_setequal(names(xw_csv), names(cgjr_crosswalk))
  expect_setequal(names(tx_csv), names(cgjr_taxonomy))
  expect_equal(sort(stats::na.omit(xw_csv$variable)),
               sort(stats::na.omit(cgjr_crosswalk$variable)))
})

test_that("the shipped cgjr_crosswalk resolves every non-NA variable to cliaretl", {
  skip_if_not_installed("cliaretl")
  skip_if_not(exists("cgjr_crosswalk"))
  cat <- cliaretl::db_variables_final$variable
  resolved <- cgjr_crosswalk$variable[!is.na(cgjr_crosswalk$variable)]
  expect_true(all(resolved %in% cat))
})

test_that("every cgjr_taxonomy leaf has a node in the built ctfdata_list", {
  skip_if_not(exists("ctfdata_list") && exists("cgjr_taxonomy"))
  for (i in seq_len(nrow(cgjr_taxonomy))) {
    row  <- cgjr_taxonomy[i, ]
    node <- ctfdata_list[[row$cluster]][[row$subcluster]]
    if (!is.na(row$sub_subcluster)) node <- node[[row$sub_subcluster]]
    expect_s3_class(node, "tbl_df")
  }
})

test_that("populated ctfdata_list leaves have no all-NA indicator columns from a bad join", {
  skip_if_not(exists("ctfdata_list"))
  chk <- function(x) {
    if (is.data.frame(x)) {
      if (nrow(x) == 0L) return(invisible())
      ind <- setdiff(names(x), c("country_code", "country_name", "year",
                                 "score", "var_count", "nonna_count"))
      for (cc in ind) expect_gt(sum(!is.na(x[[cc]])), 0L)
    } else lapply(x, chk)
  }
  chk(ctfdata_list)
})

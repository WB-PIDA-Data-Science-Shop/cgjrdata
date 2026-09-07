## Tests for resolve_leaf() and build_crosswalk()

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

fx_taxonomy <- function() {
  tibble::tibble(
    cluster             = c("c1", "c2", "c2"),
    cluster_num         = c(1L, 2L, 2L),
    cluster_name        = c("C1", "C2", "C2"),
    subcluster          = c("s1", "s2", "s2"),
    subcluster_num      = c(1L, 1L, 1L),
    subcluster_name     = c("S1", "S2", "S2"),
    sub_subcluster      = c(NA, "ss1", "ss2"),
    sub_subcluster_num  = c(NA, 1L, 2L),
    sub_subcluster_name = c(NA, "SS1", "SS2")
  )
}

fx_crosswalk_csv <- function() {
  tibble::tibble(
    cluster        = c("c1", "c1", "c2", "c2"),
    subcluster     = c("s1", "s1", "s2", "s2"),
    sub_subcluster = c(NA, NA, "ss1", "ss2"),
    indicator_num  = c(1L, 2L, 1L, 1L),
    indicator      = c("Alpha", "Beta", "Gamma", "Delta"),
    source         = "SRC",
    variable       = c("v_ok", NA, "v_ok2", "ghost"),
    note           = NA_character_
  )
}

fx_catalogue <- function() {
  tibble::tibble(
    variable                           = c("v_ok", "v_ok2", "v_other"),
    var_name                           = c("V OK", "V OK 2", "V Other"),
    family_name                        = c("Fam A", "Fam B", "Fam C"),
    description                        = c("desc ok", "desc ok2", "desc other"),
    etl_source                         = c("vdem", "wdi", "vdem"),
    benchmark_dynamic_indicator        = c("Yes", "No", "Yes"),
    benchmark_dynamic_family_aggregate = c("Yes", "No", "Yes")
  )
}

fx_dynamic <- function() {
  tibble::tibble(country_code = character(), year = integer(), v_ok = double())
}
fx_static <- function() {
  tibble::tibble(country_code = character(), v_ok2 = double())
}

build_fx <- function() {
  build_crosswalk(fx_crosswalk_csv(), fx_taxonomy(), fx_catalogue(),
                  fx_dynamic(), fx_static())
}

# ---------------------------------------------------------------------------
# resolve_leaf()
# ---------------------------------------------------------------------------

test_that("resolve_leaf takes sub_subcluster where present, else subcluster", {
  expect_equal(
    resolve_leaf(c(NA, "public_procurement", NA), c("digital_and_data", "pfm", "hrm")),
    c("digital_and_data", "public_procurement", "hrm")
  )
})

test_that("resolve_leaf returns NA only when both inputs are NA", {
  expect_equal(resolve_leaf(NA_character_, NA_character_), NA_character_)
})

# ---------------------------------------------------------------------------
# build_crosswalk() – row preservation & leaf
# ---------------------------------------------------------------------------

test_that("build_crosswalk keeps every CSV row, in order", {
  out <- build_fx()
  expect_equal(nrow(out), nrow(fx_crosswalk_csv()))
  expect_identical(out$indicator, c("Alpha", "Beta", "Gamma", "Delta"))
})

test_that("build_crosswalk derives the leaf key", {
  expect_identical(build_fx()$leaf, c("s1", "s1", "ss1", "ss2"))
})

# ---------------------------------------------------------------------------
# build_crosswalk() – column schema
# ---------------------------------------------------------------------------

test_that("build_crosswalk emits the expected columns in order", {
  expect_identical(
    names(build_fx()),
    c("cluster", "subcluster", "sub_subcluster", "leaf",
      "indicator_num", "indicator", "source", "variable", "note",
      "cluster_num", "cluster_name", "subcluster_num", "subcluster_name",
      "sub_subcluster_num", "sub_subcluster_name",
      "var_name", "family_name", "description", "etl_source",
      "benchmark_dynamic_indicator", "benchmark_dynamic_family_aggregate",
      "in_cliaretl", "in_dynamic_panel", "in_static_panel",
      "dynamic_eligible", "static_eligible", "cliaretl_status")
  )
})

test_that("build_crosswalk errors if an expected column cannot be produced", {
  tx <- fx_taxonomy()
  tx$cluster_name <- NULL
  expect_error(
    build_crosswalk(fx_crosswalk_csv(), tx, fx_catalogue(), fx_dynamic(), fx_static()),
    regexp = "missing expected column\\(s\\): cluster_name"
  )
})

# ---------------------------------------------------------------------------
# build_crosswalk() – taxonomy join
# ---------------------------------------------------------------------------

test_that("build_crosswalk joins taxonomy numbers and names per leaf", {
  out <- build_fx()
  expect_equal(out$cluster_num, c(1L, 1L, 2L, 2L))
  expect_equal(out$subcluster_name, c("S1", "S1", "S2", "S2"))
  expect_equal(out$sub_subcluster_name, c(NA, NA, "SS1", "SS2"))
})

# ---------------------------------------------------------------------------
# build_crosswalk() – catalogue join, NA for unresolved / not-in-cliaretl
# ---------------------------------------------------------------------------

test_that("catalogue metadata is joined for resolved rows and NA otherwise", {
  out <- build_fx()
  # Alpha=v_ok (resolved), Beta=NA (unresolved), Gamma=v_ok2 (resolved), Delta=ghost (not in cliaretl)
  expect_equal(out$var_name,    c("V OK", NA, "V OK 2", NA))
  expect_equal(out$family_name, c("Fam A", NA, "Fam B", NA))
  expect_equal(out$description, c("desc ok", NA, "desc ok2", NA))
})

# ---------------------------------------------------------------------------
# build_crosswalk() – eligibility flags
# ---------------------------------------------------------------------------

test_that("build_crosswalk carries the classify_crosswalk flags", {
  out <- build_fx()
  expect_equal(out$cliaretl_status,
               c("resolved", "unresolved", "resolved", "not_in_cliaretl"))
  expect_equal(out$dynamic_eligible, c(TRUE, FALSE, FALSE, FALSE))
  expect_equal(out$static_eligible,  c(FALSE, FALSE, TRUE, FALSE))
  expect_equal(out$in_cliaretl,      c(TRUE, FALSE, TRUE, FALSE))
})

# ---------------------------------------------------------------------------
# End-to-end against the real input CSV (skipped when run off an installed
# package, where data-raw/ is absent)
# ---------------------------------------------------------------------------

test_that("build_crosswalk on the shipped CSV keeps every row and every leaf resolves", {
  csv_path <- file.path(testthat::test_path(), "..", "..",
                        "data-raw", "input", "cgjr_crosswalk.csv")
  skip_if_not(file.exists(csv_path), "input CSV not available")
  skip_if_not_installed("readr")

  xw <- readr::read_csv(
    csv_path,
    col_types = readr::cols(.default = readr::col_character(),
                            indicator_num = readr::col_integer()),
    na = ""
  )
  out <- build_crosswalk(tibble::as_tibble(xw), cgjr_taxonomy)

  expect_equal(nrow(out), nrow(xw))
  tax_leaves <- resolve_leaf(cgjr_taxonomy$sub_subcluster, cgjr_taxonomy$subcluster)
  expect_true(all(out$leaf %in% tax_leaves))
  expect_false(anyNA(out$cluster_num))   # every crosswalk row resolved to a taxonomy leaf
})

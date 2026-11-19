# Contract tests on the shipped data: what cgjrdata promises cgjrapp,
# independent of how data-raw/cgjr.R builds it.

# ---- helpers ---------------------------------------------------------------

types <- function(df) vapply(df, typeof, character(1))

taxonomy_leaves <- function() {
  dplyr::coalesce(cgjr_taxonomy$sub_subcluster, cgjr_taxonomy$subcluster)
}

# crosswalk rows that name a variable
mapped <- function() cgjr_crosswalk[!is.na(cgjr_crosswalk$variable), ]

label_cols <- c("cluster", "subcluster", "sub_subcluster", "leaf", "indicator")

# Value checks against cliaretl only make sense if the installed cliaretl is
# the one the data were built from.
skip_if_stale_cliaretl <- function() {
  skip_if_not_installed("cliaretl")
  built     <- attr(cgjr_ctf, "cliaretl_version")
  installed <- as.character(utils::packageVersion("cliaretl"))
  skip_if(!identical(built, installed),
          paste0("data built with cliaretl ", format(built), ", installed ", installed))
}

# Look each row up by indexing the wide cliaretl table directly - a different
# path from the build's pivot + join. `table_for(v)` returns the wide table
# holding variable `v`.
expected_cells <- function(rows, table_for) {
  out <- rep(NA_real_, nrow(rows))
  for (v in unique(rows$variable)) {
    sel <- which(rows$variable == v)
    tbl <- table_for(v)
    if ("year" %in% names(tbl)) {
      i <- match(paste(rows$unit_code[sel], rows$year[sel]),
                 paste(tbl$country_code, tbl$year))
    } else {
      i <- match(rows$unit_code[sel], tbl$country_code)
    }
    out[sel] <- tbl[[v]][i]
  }
  out
}

# ---- package ---------------------------------------------------------------

test_that("cgjrdata ships exactly the five documented objects", {
  shipped <- ls(getNamespaceInfo("cgjrdata", "lazydata"))
  expect_setequal(shipped, c("cgjr_taxonomy", "cgjr_crosswalk", "cgjr_ctf",
                             "cgjr_raw", "wbcountries"))
})

# ---- wbcountries -----------------------------------------------------------

test_that("wbcountries has one row per country with a known region and income group", {
  wb <- wbcountries
  expect_equal(anyDuplicated(wb$country_code), 0L)
  expect_true(all(grepl("^[A-Z]{3}$", wb$country_code)))
  expect_false(anyNA(wb$economy))
  expect_true(all(wb$region_code %in%
                    c("AFE", "AFW", "EAP", "ECA", "LAC", "MENAAP", "NAC", "SAR")))
  expect_true(all(wb$income_group %in% c("Low income", "Lower middle income",
                                         "Upper middle income", "High income", NA)))
  expect_equal(nrow(dplyr::distinct(wb, region_code, region)),
               dplyr::n_distinct(wb$region_code))
})

# ---- cgjr_taxonomy ---------------------------------------------------------

test_that("cgjr_taxonomy has one row per leaf with complete, consistent keys", {
  expect_identical(types(cgjr_taxonomy), c(
    cluster = "character", cluster_num = "integer", cluster_name = "character",
    subcluster = "character", subcluster_num = "integer", subcluster_name = "character",
    sub_subcluster = "character", sub_subcluster_num = "integer",
    sub_subcluster_name = "character"
  ))
  expect_equal(anyDuplicated(taxonomy_leaves()), 0L)
  expect_false(anyNA(cgjr_taxonomy[c("cluster", "cluster_num", "cluster_name",
                                     "subcluster", "subcluster_num", "subcluster_name")]))
  # sub_subcluster key, number and name are present together or absent together
  ss <- cgjr_taxonomy[c("sub_subcluster", "sub_subcluster_num", "sub_subcluster_name")]
  expect_true(all(rowSums(is.na(ss)) %in% c(0, 3)))
  # each cluster key has one number and one name
  expect_equal(nrow(dplyr::distinct(cgjr_taxonomy, cluster, cluster_num, cluster_name)),
               dplyr::n_distinct(cgjr_taxonomy$cluster))
})

# ---- cgjr_crosswalk --------------------------------------------------------

test_that("cgjr_crosswalk has the documented columns", {
  expect_named(cgjr_crosswalk, c(
    "cluster", "subcluster", "sub_subcluster", "leaf", "indicator_num",
    "indicator", "source", "variable", "note",
    "cluster_num", "cluster_name", "subcluster_num", "subcluster_name",
    "sub_subcluster_num", "sub_subcluster_name",
    "description", "description_short", "in_dynamic", "in_static", "raw_dataset"
  ))
})

test_that("cgjr_crosswalk places every row on a real taxonomy leaf", {
  xw <- cgjr_crosswalk
  expect_identical(xw$leaf, dplyr::coalesce(xw$sub_subcluster, xw$subcluster))
  expect_true(all(xw$leaf %in% taxonomy_leaves()))
  # names are joined on the full path, so a missing name means an orphan path
  expect_false(anyNA(xw$cluster_name))
  expect_false(anyNA(xw$subcluster_name))
  expect_equal(anyDuplicated(xw[c("leaf", "indicator_num")]), 0L)
  expect_equal(anyDuplicated(xw[c("leaf", "indicator")]), 0L)
})

test_that("a variable may sit on several leaves, but only once on each", {
  expect_equal(anyDuplicated(mapped()[c("variable", "leaf")]), 0L)
})

test_that("rows without a variable carry no cliaretl annotation", {
  un <- cgjr_crosswalk[is.na(cgjr_crosswalk$variable), ]
  expect_false(any(un$in_dynamic | un$in_static))
  expect_true(all(is.na(un$raw_dataset)))
})

test_that("cgjr_crosswalk eligibility follows the CLIAR benchmarking flags", {
  skip_if_stale_cliaretl()
  cat <- cliaretl::db_variables_final
  dyn_yes <- cat$variable[cat$benchmark_dynamic_indicator %in% "Yes"]
  sta_yes <- cat$variable[cat$benchmarked_ctf %in% "Yes"]
  v <- cgjr_crosswalk$variable
  expect_identical(cgjr_crosswalk$in_dynamic,
                   v %in% names(cliaretl::closeness_to_frontier_dynamic) & v %in% dyn_yes)
  expect_identical(cgjr_crosswalk$in_static,
                   v %in% names(cliaretl::closeness_to_frontier_static) & v %in% sta_yes)
})

test_that("raw_dataset names a cliaretl dataset that holds the variable", {
  skip_if_stale_cliaretl()
  m <- mapped()
  m <- m[!is.na(m$raw_dataset), ]
  has_col <- mapply(\(v, d) v %in% names(getExportedValue("cliaretl", d)),
                    m$variable, m$raw_dataset)
  expect_true(all(has_col))
  # PEFA values come from the dedicated dataset, not the copy in d360_efi_data
  pefa <- m$variable %in% names(cliaretl::pefa_assessments)
  expect_true(all(m$raw_dataset[pefa] == "pefa_assessments"))
})

# ---- cgjr_ctf --------------------------------------------------------------

test_that("cgjr_ctf has the documented columns and types", {
  expect_identical(types(cgjr_ctf), c(
    unit_level = "character", unit_code = "character", unit_name = "character",
    year = "integer", ctf_type = "character", cluster = "character",
    subcluster = "character", sub_subcluster = "character", leaf = "character",
    indicator = "character", variable = "character", ctf = "double"
  ))
})

test_that("cgjr_ctf holds real countries only, named as in wbcountries", {
  expect_identical(unique(cgjr_ctf$unit_level), "country")
  expect_true(all(cgjr_ctf$unit_code %in% wbcountries$country_code))
  expect_identical(cgjr_ctf$unit_name,
                   wbcountries$economy[match(cgjr_ctf$unit_code, wbcountries$country_code)])
})

test_that("cgjr_ctf static rows have no year; dynamic rows always do", {
  expect_setequal(unique(cgjr_ctf$ctf_type), c("dynamic", "static"))
  expect_true(all(is.na(cgjr_ctf$year[cgjr_ctf$ctf_type == "static"])))
  yrs <- cgjr_ctf$year[cgjr_ctf$ctf_type == "dynamic"]
  expect_false(anyNA(yrs))
  expect_true(all(yrs >= 1990L & yrs <= as.integer(format(Sys.Date(), "%Y"))))
})

test_that("cgjr_ctf values are finite; static scores lie in [0, 1]", {
  x <- cgjr_ctf$ctf[!is.na(cgjr_ctf$ctf)]
  expect_gt(length(x), 0)
  expect_true(all(is.finite(x)))
  # Dynamic CTF is NOT bounded: cliaretl's dynamic panel carries values just
  # outside [0, 1] at the edges of its window (e.g. -0.11, 1.13 in 2013/2024).
  # cgjrdata copies cliaretl unchanged so cgjrapp matches the CLIAR app; the
  # value-equality test below is the real guarantee.
  s <- cgjr_ctf$ctf[cgjr_ctf$ctf_type == "static" & !is.na(cgjr_ctf$ctf)]
  expect_true(all(s >= 0 & s <= 1))
})

test_that("cgjr_ctf is a balanced panel keyed by ctf_type x country x year x variable x leaf", {
  expect_equal(anyDuplicated(cgjr_ctf[c("ctf_type", "unit_code", "year",
                                        "variable", "leaf")]), 0L)
  per_unit <- dplyr::count(cgjr_ctf, ctf_type, unit_code, year)
  n_pairs  <- dplyr::summarise(
    dplyr::distinct(cgjr_ctf, ctf_type, variable, leaf),
    k = dplyr::n(), .by = ctf_type
  )
  expect_true(all(per_unit$n == n_pairs$k[match(per_unit$ctf_type, n_pairs$ctf_type)]))
})

test_that("cgjr_ctf covers exactly the crosswalk rows eligible for each panel", {
  xw <- cgjr_crosswalk
  for (type in c("dynamic", "static")) {
    flag <- xw[[paste0("in_", type)]]
    got  <- dplyr::distinct(cgjr_ctf[cgjr_ctf$ctf_type == type, c("variable", label_cols)])
    want <- xw[flag, c("variable", label_cols)]
    # same (variable x leaf) rows, carrying the crosswalk's taxonomy labels
    expect_equal(nrow(got), nrow(want), label = type)
    expect_equal(nrow(dplyr::anti_join(got, want, by = names(got))), 0L, label = type)
  }
})

test_that("cgjr_ctf values equal the cliaretl CTF panels, for every country in them", {
  skip_if_stale_cliaretl()
  panels <- list(dynamic = cliaretl::closeness_to_frontier_dynamic,
                 static  = cliaretl::closeness_to_frontier_static)
  for (type in names(panels)) {
    rows <- cgjr_ctf[cgjr_ctf$ctf_type == type, ]
    expect_identical(rows$ctf, expected_cells(rows, \(v) panels[[type]]), label = type)
    expect_setequal(unique(rows$unit_code),
                    intersect(panels[[type]]$country_code, wbcountries$country_code))
  }
})

# ---- cgjr_raw --------------------------------------------------------------

test_that("cgjr_raw has the documented columns and types", {
  expect_identical(types(cgjr_raw), c(
    unit_level = "character", unit_code = "character", unit_name = "character",
    year = "integer", cluster = "character", subcluster = "character",
    sub_subcluster = "character", leaf = "character", indicator = "character",
    variable = "character", value = "double"
  ))
})

test_that("cgjr_raw holds observed values for real countries only", {
  expect_identical(unique(cgjr_raw$unit_level), "country")
  expect_true(all(cgjr_raw$unit_code %in% wbcountries$country_code))
  expect_identical(cgjr_raw$unit_name,
                   wbcountries$economy[match(cgjr_raw$unit_code, wbcountries$country_code)])
  expect_false(anyNA(cgjr_raw$value))
  expect_false(anyNA(cgjr_raw$year))
  expect_equal(anyDuplicated(cgjr_raw[c("unit_code", "year", "variable", "leaf")]), 0L)
})

test_that("cgjr_raw rows come from crosswalk rows with a raw dataset, labelled as in the crosswalk", {
  # Not every such row has data: a source column can be entirely missing
  # (8 WDI columns are all NA in cliaretl 0.2.5). Completeness - every
  # observed source value present - is the "none are lost" test below.
  want <- cgjr_crosswalk[!is.na(cgjr_crosswalk$raw_dataset), c("variable", label_cols)]
  got  <- dplyr::distinct(cgjr_raw[c("variable", label_cols)])
  expect_gt(nrow(got), 0L)
  expect_equal(nrow(dplyr::anti_join(got, want, by = names(got))), 0L)
})

test_that("cgjr_raw values equal the source dataset, and none are lost", {
  skip_if_stale_cliaretl()
  m <- mapped()
  m <- m[!is.na(m$raw_dataset), ]
  table_for <- \(v) getExportedValue("cliaretl", m$raw_dataset[match(v, m$variable)])
  expect_identical(cgjr_raw$value, expected_cells(cgjr_raw, table_for))

  # every non-missing source value for a real country made it in, once per leaf
  vars <- unique(m$variable)
  n_source <- vapply(vars, \(v) {
    tbl <- table_for(v)
    sum(!is.na(tbl[[v]]) & tbl$country_code %in% wbcountries$country_code)
  }, integer(1))
  n_leaves <- as.integer(table(m$variable)[vars])
  n_raw <- tabulate(factor(cgjr_raw$variable, levels = vars), nbins = length(vars))
  expect_identical(n_raw, unname(n_source) * n_leaves)
})

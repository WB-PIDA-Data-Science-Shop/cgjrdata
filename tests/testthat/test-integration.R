## Integration tests over the six shipped objects.
##
## These check the *built* package data (data/*.rda), not a fixture - so they
## are skipped when the tidy tibbles have not been assembled yet
## (analysis/01-build-tidy-data.R). They are the "does the whole pipeline
## hang together" backstop for the per-function unit tests.

.shipped <- utils::data(package = "cgjrdata")$results[, "Item"]
skip_if_not(
  all(c("cgjr_ctf", "cgjr_scores", "cgjr_raw") %in% .shipped),
  "tidy tibbles not built - run analysis/01-build-tidy-data.R"
)

finest_grain <- function(tbl) {
  branching <- unique(tbl$subcluster[tbl$node_level == "sub_subcluster"])
  tbl[tbl$node_level %in% c("subcluster", "sub_subcluster") &
        !(tbl$node_level == "subcluster" & tbl$subcluster %in% branching), ]
}

# ---------------------------------------------------------------------------
# All six objects present and the right shape
# ---------------------------------------------------------------------------

test_that("the six documented objects are all shipped", {
  expect_true(all(
    c("cgjr_taxonomy", "cgjr_crosswalk", "wbcountries",
      "cgjr_ctf", "cgjr_scores", "cgjr_raw") %in% .shipped
  ))
  for (obj in c("cgjr_taxonomy", "cgjr_crosswalk", "wbcountries",
                "cgjr_ctf", "cgjr_scores", "cgjr_raw")) {
    expect_s3_class(get0(obj, inherits = TRUE), "tbl_df")
  }
})

test_that("cgjr_ctf has the documented columns and both ctf_types", {
  expect_identical(
    names(cgjr_ctf),
    c("unit_level", "unit_code", "unit_name", "year", "ctf_type",
      "cluster", "subcluster", "sub_subcluster", "leaf", "indicator",
      "variable", "ctf", "n_inputs", "n_inputs_obs")
  )
  expect_setequal(unique(cgjr_ctf$ctf_type), c("dynamic", "static"))
})

test_that("cgjr_scores has the documented columns and node levels", {
  expect_identical(
    names(cgjr_scores),
    c("unit_level", "unit_code", "unit_name", "year", "ctf_type",
      "node_level", "node", "cluster", "subcluster", "sub_subcluster",
      "score", "n_inputs", "n_inputs_obs")
  )
  expect_setequal(unique(cgjr_scores$node_level),
                  c("subcluster", "sub_subcluster", "cluster", "overall"))
})

test_that("cgjr_raw has the documented columns, no ctf_type, country only", {
  expect_identical(
    names(cgjr_raw),
    c("unit_level", "unit_code", "unit_name", "year",
      "cluster", "subcluster", "sub_subcluster", "leaf", "indicator",
      "variable", "value")
  )
  expect_equal(unique(cgjr_raw$unit_level), "country")
})

# ---------------------------------------------------------------------------
# unit_level domain
# ---------------------------------------------------------------------------

test_that("cgjr_ctf and cgjr_scores carry country + region + income_group rows", {
  for (tbl in list(cgjr_ctf, cgjr_scores)) {
    expect_setequal(unique(tbl$unit_level),
                    c("country", "region", "income_group"))
  }
})

test_that("region unit_codes are World Bank region codes; income slugs are slugs", {
  region_codes <- unique(cgjr_scores$unit_code[cgjr_scores$unit_level == "region"])
  expect_true(all(region_codes %in% wbcountries$region_code))

  income_codes <- unique(cgjr_scores$unit_code[cgjr_scores$unit_level == "income_group"])
  expect_true(all(grepl("^[a-z0-9_]+$", income_codes)))
})

# ---------------------------------------------------------------------------
# Taxonomy coverage
# ---------------------------------------------------------------------------

test_that("every taxonomy leaf appears in the finest-grain filter over cgjr_scores", {
  all_leaves <- resolve_leaf(cgjr_taxonomy$sub_subcluster, cgjr_taxonomy$subcluster)
  expect_setequal(unique(finest_grain(cgjr_scores)$node), all_leaves)
})

test_that("static rows carry year = NA; dynamic rows carry a real year", {
  expect_true(all(is.na(cgjr_ctf$year[cgjr_ctf$ctf_type == "static"])))
  expect_true(all(!is.na(cgjr_ctf$year[cgjr_ctf$ctf_type == "dynamic"])))
  expect_true(all(is.na(cgjr_scores$year[cgjr_scores$ctf_type == "static"])))
})

# ---------------------------------------------------------------------------
# Value sanity - loose bounds (CTF can run slightly past [0, 1])
# ---------------------------------------------------------------------------

test_that("ctf and score values sit within a loose sanity band", {
  expect_true(all(cgjr_ctf$ctf    >= -0.5 & cgjr_ctf$ctf    <= 1.5, na.rm = TRUE))
  expect_true(all(cgjr_scores$score >= -0.5 & cgjr_scores$score <= 1.5, na.rm = TRUE))
})

test_that("no indicator is all-NA across the whole panel (would signal a bad join)", {
  ctf_by_var <- tapply(cgjr_ctf$ctf, cgjr_ctf$variable,
                       function(x) any(!is.na(x)))
  expect_true(all(ctf_by_var),
              info = paste("all-NA variables:",
                           paste(names(which(!ctf_by_var)), collapse = ", ")))
})

test_that("every cgjr_ctf / cgjr_scores / cgjr_raw row resolves to a real taxonomy leaf/node", {
  leaves <- resolve_leaf(cgjr_taxonomy$sub_subcluster, cgjr_taxonomy$subcluster)
  expect_true(all(cgjr_ctf$leaf %in% leaves))
  expect_true(all(cgjr_raw$leaf %in% leaves))
  expect_true(all(stats::na.omit(cgjr_scores$cluster) %in% cgjr_taxonomy$cluster))
})

# ---------------------------------------------------------------------------
# n_inputs bookkeeping
# ---------------------------------------------------------------------------

test_that("n_inputs >= n_inputs_obs >= 0 wherever the counts are populated", {
  s <- cgjr_scores
  expect_true(all(s$n_inputs >= s$n_inputs_obs, na.rm = TRUE))
  expect_true(all(s$n_inputs_obs >= 0L, na.rm = TRUE))

  grp <- cgjr_ctf[cgjr_ctf$unit_level != "country", ]
  expect_true(all(grp$n_inputs >= grp$n_inputs_obs, na.rm = TRUE))
  expect_true(all(is.na(cgjr_ctf$n_inputs[cgjr_ctf$unit_level == "country"])))
})

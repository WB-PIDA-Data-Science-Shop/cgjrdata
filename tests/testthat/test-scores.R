## Tests for roll_up_scores()
##
## Fixture: 3 countries, 1 year, ctf_type "dynamic", 6 leaves under 2
## clusters. `pfm` branches into two sub-subcluster leaves (ss1, ss2) so the
## "mean of >1 leaf" path and the sub_subcluster tier are genuinely
## exercised; `s3` never has any indicator data for anyone, so it exercises
## the always-empty-leaf scaffold; `s1`/`s2`/`hrm` are plain (no
## sub_subcluster) so they report directly at node_level == "subcluster";
## CCC is missing entirely from several leaves, exercising a
## country-specific data gap the same way.
##
## There is no stored "is this the finest grain" column - the recipe from
## roll_up_scores()'s roxygen is used directly wherever tests need it.

fx_taxonomy <- function() {
  tibble::tribble(
    ~cluster, ~subcluster, ~sub_subcluster,
    "c1", "s1",  NA_character_,
    "c1", "s2",  NA_character_,
    "c1", "s3",  NA_character_,
    "c2", "pfm", "ss1",
    "c2", "pfm", "ss2",
    "c2", "hrm", NA_character_
  )
}

fx_ctf <- function() {
  tibble::tribble(
    ~unit_code, ~leaf, ~ctf,
    "AAA", "s1",  0.2,
    "AAA", "s1",  0.4,
    "AAA", "s1",  NA,
    "AAA", "s2",  0.6,
    "AAA", "ss1", 0.8,
    "AAA", "hrm", NA,
    "BBB", "s1",  1.0,
    "BBB", "s1",  0.0,
    "BBB", "s1",  0.5,
    "BBB", "s2",  NA,
    "BBB", "ss1", 0.4,
    "BBB", "ss2", 0.2,
    "BBB", "hrm", 0.9,
    "CCC", "ss1", 0.6,
    "CCC", "ss2", 0.2
  ) |>
    dplyr::mutate(
      unit_level     = "country",
      unit_name      = unit_code,
      year           = 2020L,
      ctf_type       = "dynamic",
      cluster        = ifelse(leaf %in% c("s1", "s2", "s3"), "c1", "c2"),
      subcluster     = dplyr::case_when(
        leaf %in% c("ss1", "ss2") ~ "pfm",
        leaf == "hrm"             ~ "hrm",
        TRUE                      ~ leaf
      ),
      sub_subcluster = ifelse(leaf %in% c("ss1", "ss2"), leaf, NA_character_)
    )
}

# The "get every finest-grain node" recipe from roll_up_scores()'s roxygen.
finest_grain <- function(tbl) {
  branching <- unique(tbl$subcluster[tbl$node_level == "sub_subcluster"])
  tbl[tbl$node_level %in% c("subcluster", "sub_subcluster") &
        !(tbl$node_level == "subcluster" & tbl$subcluster %in% branching), ]
}

out <- roll_up_scores(fx_ctf(), fx_taxonomy())

get_node <- function(unit_code, node_level, node, tbl = out) {
  r <- tbl[tbl$unit_code == unit_code & tbl$node_level == node_level & tbl$node == node, ]
  expect_equal(nrow(r), 1L,
               info = paste(unit_code, node_level, node, "should have exactly one row"))
  r
}

# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

test_that("roll_up_scores emits the documented columns - no stored is_leaf", {
  expect_identical(
    names(out),
    c("unit_level", "unit_code", "unit_name", "year", "ctf_type",
      "node_level", "node", "cluster", "subcluster", "sub_subcluster",
      "score", "n_inputs", "n_inputs_obs")
  )
})

test_that("node_level only takes real taxonomy tiers - no generic 'leaf' label", {
  expect_setequal(unique(out$node_level), c("subcluster", "sub_subcluster", "cluster", "overall"))
})

test_that("a plain subcluster reports exactly once, at node_level 'subcluster'", {
  s1_rows <- out[out$unit_code == "AAA" & out$node == "s1", ]
  expect_equal(nrow(s1_rows), 1L)
  expect_equal(s1_rows$node_level, "subcluster")
})

test_that("PFM's sub-subclusters report at node_level 'sub_subcluster' with full ancestry", {
  r <- get_node("AAA", "sub_subcluster", "ss1")
  expect_equal(r$cluster, "c2")
  expect_equal(r$subcluster, "pfm")
  expect_equal(r$sub_subcluster, "ss1")
})

test_that("PFM's own subcluster row is distinct from its sub-subclusters and not finest-grain", {
  r <- get_node("AAA", "subcluster", "pfm")
  expect_true(is.na(r$sub_subcluster))
  aaa_finest <- finest_grain(out[out$unit_code == "AAA", ])
  expect_false(any(aaa_finest$node_level == "subcluster" & aaa_finest$node == "pfm"))
})

test_that("cluster and overall rows never appear in the finest-grain filter", {
  aaa_finest <- finest_grain(out[out$unit_code == "AAA", ])
  expect_false(any(aaa_finest$node_level %in% c("cluster", "overall")))
})

test_that("every taxonomy leaf appears in the finest-grain filter, including one with zero indicators everywhere", {
  finest <- finest_grain(out)
  expect_setequal(unique(finest$node), c("s1", "s2", "s3", "ss1", "ss2", "hrm"))
  # s3 never has a single ctf_tbl row, for any of the 3 units
  s3_rows <- out[out$node == "s3", ]
  expect_equal(nrow(s3_rows), 3L)
  expect_true(all(is.na(s3_rows$score)))
  expect_true(all(s3_rows$n_inputs == 0L))
  expect_true(all(s3_rows$n_inputs_obs == 0L))
})

# ---------------------------------------------------------------------------
# Finest-grain score = mean of indicator CTFs
# ---------------------------------------------------------------------------

test_that("a plain subcluster's score is the mean of its indicator ctf values, na.rm", {
  r <- get_node("AAA", "subcluster", "s1")   # 0.2, 0.4, NA
  expect_equal(r$score, 0.3)
  expect_equal(r$n_inputs, 3L)
  expect_equal(r$n_inputs_obs, 2L)
})

test_that("a leaf that is all-NA scores NA, not NaN, with n_inputs_obs = 0", {
  r <- get_node("AAA", "subcluster", "hrm")
  expect_true(is.na(r$score))
  expect_false(is.nan(r$score))
  expect_equal(r$n_inputs, 1L)
  expect_equal(r$n_inputs_obs, 0L)
})

# ---------------------------------------------------------------------------
# Branching (PFM-like) subcluster = mean of its sub_subclusters
# ---------------------------------------------------------------------------

test_that("a branching subcluster's score is the mean of its sub_subclusters", {
  # BBB: ss1 = 0.4, ss2 = 0.2 -> both observed
  r <- get_node("BBB", "subcluster", "pfm")
  expect_equal(r$score, 0.3)
  expect_equal(r$n_inputs, 2L)
  expect_equal(r$n_inputs_obs, 2L)

  # AAA: ss1 = 0.8, ss2 = NA (never appears in ctf_tbl) -> na.rm mean
  r2 <- get_node("AAA", "subcluster", "pfm")
  expect_equal(r2$score, 0.8)
  expect_equal(r2$n_inputs, 2L)
  expect_equal(r2$n_inputs_obs, 1L)
})

# ---------------------------------------------------------------------------
# Cluster level
# ---------------------------------------------------------------------------

test_that("cluster score is the mean of its subclusters' scores", {
  # c1 for AAA: s1 = 0.3, s2 = 0.6, s3 = NA -> mean(0.3, 0.6, na.rm) = 0.45
  r <- get_node("AAA", "cluster", "c1")
  expect_equal(r$score, 0.45)
  expect_equal(r$n_inputs, 3L)
  expect_equal(r$n_inputs_obs, 2L)
  expect_true(is.na(r$subcluster))
})

test_that("a cluster with every subcluster NA scores NA, not NaN", {
  # CCC has no s1/s2/s3 data at all -> c1 cluster is all-NA
  r <- get_node("CCC", "cluster", "c1")
  expect_true(is.na(r$score))
  expect_false(is.nan(r$score))
  expect_equal(r$n_inputs, 3L)
  expect_equal(r$n_inputs_obs, 0L)
})

# ---------------------------------------------------------------------------
# Overall level
# ---------------------------------------------------------------------------

test_that("overall score is the mean of the cluster scores", {
  # AAA: c1 = 0.45, c2 = mean(pfm=0.8, hrm=NA, na.rm) = 0.8 -> overall = 0.625
  r <- get_node("AAA", "overall", "overall")
  expect_equal(r$score, 0.625)
  expect_equal(r$n_inputs, 2L)
  expect_equal(r$n_inputs_obs, 2L)
  expect_true(is.na(r$cluster))

  # CCC: c1 = NA, c2 = mean(pfm=0.4, hrm=NA, na.rm) = 0.4 -> overall = 0.4
  r2 <- get_node("CCC", "overall", "overall")
  expect_equal(r2$score, 0.4)
  expect_equal(r2$n_inputs, 2L)
  expect_equal(r2$n_inputs_obs, 1L)
})

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

test_that("roll_up_scores errors on a missing required ctf_tbl column", {
  xw <- fx_ctf()
  xw$leaf <- NULL
  expect_error(roll_up_scores(xw, fx_taxonomy()),
               regexp = "`ctf_tbl` is missing column\\(s\\): leaf")
})

test_that("roll_up_scores errors on a missing required taxonomy column", {
  tx <- fx_taxonomy()
  tx$subcluster <- NULL
  expect_error(roll_up_scores(fx_ctf(), tx),
               regexp = "`taxonomy` is missing column\\(s\\): subcluster")
})

# ---------------------------------------------------------------------------
# ctf_type independence + static year passthrough
# ---------------------------------------------------------------------------

test_that("ctf_types are scaffolded and rolled up independently", {
  ctf_both <- dplyr::bind_rows(
    fx_ctf(),
    tibble::tibble(
      unit_code = "AAA", leaf = "s1", ctf = 0.9,
      unit_level = "country", unit_name = "AAA", year = NA_integer_,
      ctf_type = "static", cluster = "c1", subcluster = "s1",
      sub_subcluster = NA_character_
    )
  )
  out2 <- roll_up_scores(ctf_both, fx_taxonomy())

  # AAA gets a full static scaffold (6 finest-grain nodes), only s1 has real data
  aaa_static_finest <- finest_grain(out2[out2$unit_code == "AAA" & out2$ctf_type == "static", ])
  expect_equal(nrow(aaa_static_finest), 6L)
  expect_equal(aaa_static_finest$score[aaa_static_finest$node == "s1"], 0.9)
  expect_true(all(is.na(aaa_static_finest$year)))
  expect_true(all(is.na(aaa_static_finest$score[aaa_static_finest$node != "s1"])))

  # BBB / CCC never appear with ctf_type == "static" -> no static rows for them
  expect_equal(nrow(out2[out2$unit_code %in% c("BBB", "CCC") & out2$ctf_type == "static", ]), 0L)

  # dynamic results are unaffected by the added static row
  expect_equal(
    get_node("AAA", "subcluster", "s1", tbl = out2[out2$ctf_type == "dynamic", ])$score,
    0.3
  )
})

# ---------------------------------------------------------------------------
# End-to-end against real cliaretl data
# ---------------------------------------------------------------------------

test_that("roll_up_scores runs on the real cgjr_ctf and covers every taxonomy leaf", {
  ctf_tbl <- build_ctf_tbl(cgjr_crosswalk)
  scores  <- roll_up_scores(ctf_tbl, cgjr_taxonomy)

  all_leaves <- resolve_leaf(cgjr_taxonomy$sub_subcluster, cgjr_taxonomy$subcluster)
  expect_setequal(unique(finest_grain(scores)$node), all_leaves)

  expect_setequal(unique(scores$node_level), c("subcluster", "sub_subcluster", "cluster", "overall"))
  expect_true(all(scores$n_inputs >= scores$n_inputs_obs, na.rm = TRUE))
  expect_true(all(scores$n_inputs_obs >= 0L))
  # exactly one subcluster row per (unit, year, ctf_type) is a branching
  # aggregate (i.e. NOT finest-grain): the PFM row
  n_combos <- nrow(dplyr::distinct(scores, unit_code, year, ctf_type))
  n_branching_subcluster_rows <- nrow(scores[scores$node_level == "subcluster", ]) -
    nrow(finest_grain(scores)[finest_grain(scores)$node_level == "subcluster", ])
  expect_equal(n_branching_subcluster_rows, n_combos)
})

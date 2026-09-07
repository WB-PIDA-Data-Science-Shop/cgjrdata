## Tests for check_crosswalk_schema()
##
## Structural, cliaretl-free. Fixtures below are a minimal well-formed
## taxonomy / crosswalk pair (one plain leaf, one two-leaf sub-subcluster
## branch, one leaf with an unresolved indicator). Each test mutates a copy
## to trip exactly one check.

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

good_taxonomy <- function() {
  tibble::tibble(
    cluster             = c("c1", "c1", "c1", "c2"),
    cluster_num         = c(1L, 1L, 1L, 2L),
    cluster_name        = c("C1", "C1", "C1", "C2"),
    subcluster          = c("s1", "s2", "s2", "s3"),
    subcluster_num      = c(1L, 2L, 2L, 1L),
    subcluster_name     = c("S1", "S2", "S2", "S3"),
    sub_subcluster      = c(NA, "ss1", "ss2", NA),
    sub_subcluster_num  = c(NA, 1L, 2L, NA),
    sub_subcluster_name = c(NA, "SS1", "SS2", NA)
  )
}

good_crosswalk <- function() {
  tibble::tibble(
    cluster        = c("c1", "c1", "c1", "c1", "c2", "c2"),
    subcluster     = c("s1", "s1", "s2", "s2", "s3", "s3"),
    sub_subcluster = c(NA, NA, "ss1", "ss2", NA, NA),
    indicator_num  = c(1L, 2L, 1L, 1L, 1L, 2L),
    indicator      = c("A", "B", "C", "D", "E", "F"),
    source         = c("src", "src", "src", "src", "src", "src"),
    variable       = c("v1", "v2", "v3", "v4", NA, "v5"),
    note           = NA_character_
  )
}

# ---------------------------------------------------------------------------
# 1. Happy path
# ---------------------------------------------------------------------------

test_that("a well-formed crosswalk / taxonomy pair passes and returns the crosswalk invisibly", {
  xw <- good_crosswalk()
  expect_silent(res <- check_crosswalk_schema(xw, good_taxonomy()))
  expect_identical(res, xw)
})

test_that("the shipped cgjr_crosswalk / cgjr_taxonomy pair passes", {
  expect_silent(check_crosswalk_schema(cgjr_crosswalk, cgjr_taxonomy))
})

# ---------------------------------------------------------------------------
# 2. Required columns
# ---------------------------------------------------------------------------

test_that("a missing crosswalk column is reported", {
  xw <- good_crosswalk()
  xw$variable <- NULL
  expect_error(check_crosswalk_schema(xw, good_taxonomy()),
               regexp = "crosswalk is missing column\\(s\\): variable")
})

test_that("a missing taxonomy column is reported", {
  tx <- good_taxonomy()
  tx$subcluster_name <- NULL
  expect_error(check_crosswalk_schema(good_crosswalk(), tx),
               regexp = "taxonomy is missing column\\(s\\): subcluster_name")
})

# ---------------------------------------------------------------------------
# 3. NA in structural columns
# ---------------------------------------------------------------------------

test_that("NA in a crosswalk structural column is reported", {
  xw <- good_crosswalk()
  xw$indicator[3] <- NA
  expect_error(check_crosswalk_schema(xw, good_taxonomy()),
               regexp = "NA `indicator`")
})

# ---------------------------------------------------------------------------
# 4. Leaf path not in the taxonomy
# ---------------------------------------------------------------------------

test_that("a crosswalk leaf path absent from the taxonomy is reported", {
  xw <- good_crosswalk()
  xw$subcluster[5:6] <- "s_typo"
  expect_error(check_crosswalk_schema(xw, good_taxonomy()),
               regexp = "not found in taxonomy: c2 > s_typo")
})

# ---------------------------------------------------------------------------
# 5. Taxonomy leaf-key uniqueness
# ---------------------------------------------------------------------------

test_that("a duplicated taxonomy leaf row is reported", {
  tx <- good_taxonomy()
  tx <- tx[c(1, 1, 2, 3, 4), ]
  expect_error(check_crosswalk_schema(good_crosswalk(), tx),
               regexp = "duplicate leaf key\\(s\\): c1 > s1")
})

# ---------------------------------------------------------------------------
# 6. Derived `leaf` uniqueness (subcluster key collides with sub_subcluster key)
# ---------------------------------------------------------------------------

test_that("a subcluster key that collides with a sub_subcluster key is reported", {
  tx <- good_taxonomy()
  tx$sub_subcluster[2] <- "s1"   # ss1 -> s1, now coalesce() is non-unique
  xw <- good_crosswalk()
  xw$sub_subcluster[3] <- "s1"
  expect_error(check_crosswalk_schema(xw, tx),
               regexp = "derived `leaf` key .* is not unique")
})

# ---------------------------------------------------------------------------
# 7. Within-leaf uniqueness
# ---------------------------------------------------------------------------

test_that("a duplicated indicator_num within a leaf is reported", {
  xw <- good_crosswalk()
  xw$indicator_num[2] <- 1L   # leaf c1 > s1 now has two indicator_num == 1
  expect_error(check_crosswalk_schema(xw, good_taxonomy()),
               regexp = "duplicate `indicator_num` within leaf\\(s\\): c1 > s1")
})

test_that("a duplicated indicator name within a leaf is reported", {
  xw <- good_crosswalk()
  xw$indicator[2] <- "A"      # leaf c1 > s1 now has two "A"
  expect_error(check_crosswalk_schema(xw, good_taxonomy()),
               regexp = "duplicate `indicator` within leaf\\(s\\): c1 > s1")
})

test_that("a duplicated variable within a leaf is reported", {
  xw <- good_crosswalk()
  xw$variable[2] <- "v1"      # leaf c1 > s1 now has v1 twice
  expect_error(check_crosswalk_schema(xw, good_taxonomy()),
               regexp = "duplicate `variable` within leaf\\(s\\): c1 > s1")
})

test_that("repeated NA variables within a leaf are allowed", {
  xw <- good_crosswalk()
  xw$variable[6] <- NA        # leaf c2 > s3 now has two NA variables
  expect_silent(check_crosswalk_schema(xw, good_taxonomy()))
})

test_that("the same variable in two different leaves is allowed (cross-leaf reuse)", {
  xw <- good_crosswalk()
  xw$variable[5] <- "v1"      # v1 in both c1 > s1 and c2 > s3
  expect_silent(check_crosswalk_schema(xw, good_taxonomy()))
})

# ---------------------------------------------------------------------------
# 8. Batched reporting
# ---------------------------------------------------------------------------

test_that("multiple violations are collected into one error", {
  xw <- good_crosswalk()
  xw$indicator_num[2] <- 1L    # dup indicator_num in c1 > s1
  xw$indicator[1]     <- "B"   # dup indicator name in c1 > s1
  err <- expect_error(check_crosswalk_schema(xw, good_taxonomy()))
  expect_match(conditionMessage(err), "2 problem\\(s\\)")
  expect_match(conditionMessage(err), "indicator_num")
  expect_match(conditionMessage(err), "indicator` within leaf")
})

countries <- tibble::tibble(
  country_code = c("GHA", "KEN"),
  economy      = c("Ghana", "Kenya")
)

mapping <- tibble::tibble(
  variable       = c("v_corr", "v_court"),
  cluster        = c("env", "env"),
  subcluster     = c("integrity", "justice"),
  sub_subcluster = NA_character_,
  leaf           = c("integrity", "justice"),
  indicator      = c("Corruption", "Courts")
)

panel <- tibble::tibble(
  country_code = c("GHA", "GHA", "KEN", "WLD"),
  year         = c(2020, 2021, 2020, 2020),
  v_corr       = c(0.5, 0.6, NA, 0.9),
  v_court      = c(0.4, 0.45, 0.3, 0.8),
  v_unmapped   = 1
)

documented_cols <- c("unit_level", "unit_code", "unit_name", "year", "cluster",
                     "subcluster", "sub_subcluster", "leaf", "indicator",
                     "variable", "ctf")

test_that("returns one row per country x year x mapped variable, in the documented shape", {
  out <- pivot_wide_to_long_cgjr(panel, mapping, countries, "ctf")
  expect_named(out, documented_cols)
  expect_identical(nrow(out), 3L * 2L)   # 3 country-years x 2 mapped variables
  expect_type(out$year, "integer")
  expect_type(out$ctf, "double")
  expect_identical(unique(out$unit_level), "country")
})

test_that("values and taxonomy labels land on the right rows", {
  out <- pivot_wide_to_long_cgjr(panel, mapping, countries, "ctf")
  row <- out[out$unit_code == "GHA" & out$year == 2021L & out$variable == "v_corr", ]
  expect_identical(row$ctf, 0.6)
  expect_identical(row$leaf, "integrity")
  expect_identical(row$indicator, "Corruption")
  expect_identical(row$unit_name, "Ghana")
})

test_that("aggregates and other non-country codes are dropped", {
  out <- pivot_wide_to_long_cgjr(panel, mapping, countries, "ctf")
  expect_false("WLD" %in% out$unit_code)
})

test_that("missing values are kept as rows", {
  out <- pivot_wide_to_long_cgjr(panel, mapping, countries, "ctf")
  expect_true(is.na(out$ctf[out$unit_code == "KEN" & out$variable == "v_corr"]))
})

test_that("unmapped columns are ignored, and mapped variables absent from the data are skipped", {
  extra <- rbind(mapping, transform(mapping[1, ], variable = "v_not_here"))
  out <- pivot_wide_to_long_cgjr(panel, extra, countries, "ctf")
  expect_setequal(unique(out$variable), c("v_corr", "v_court"))
})

test_that("a variable mapped to two leaves gives one row per leaf", {
  two <- rbind(mapping, transform(mapping[1, ], subcluster = "justice", leaf = "justice",
                                  indicator = "Corruption in courts"))
  out <- pivot_wide_to_long_cgjr(panel, two, countries, "ctf")
  gha <- out[out$unit_code == "GHA" & out$year == 2020L & out$variable == "v_corr", ]
  expect_setequal(gha$leaf, c("integrity", "justice"))
  expect_identical(gha$ctf, c(0.5, 0.5))
})

test_that("a table with no year column (a cross-section) gets a missing integer year", {
  static <- panel[panel$year == 2020, setdiff(names(panel), "year")]
  out <- pivot_wide_to_long_cgjr(static, mapping, countries, "ctf")
  expect_type(out$year, "integer")
  expect_true(all(is.na(out$year)))
  expect_identical(nrow(out), 2L * 2L)
})

test_that("integer source values come back as doubles under the chosen name", {
  raw <- tibble::tibble(country_code = "GHA", year = 2020L, v_corr = 3L)
  out <- pivot_wide_to_long_cgjr(raw, mapping, countries)
  expect_identical(names(out)[length(out)], "value")
  expect_identical(out$value, 3)
})

test_that("no mapped variables in the data gives a zero-row table of the same shape", {
  out <- pivot_wide_to_long_cgjr(panel[c("country_code", "year")], mapping, countries, "ctf")
  expect_identical(nrow(out), 0L)
  expect_named(out, documented_cols)
  expect_type(out$year, "integer")
  expect_type(out$ctf, "double")
})

test_that("the input table is not modified", {
  before <- panel
  pivot_wide_to_long_cgjr(panel, mapping, countries, "ctf")
  expect_identical(panel, before)
})

test_that("bad inputs are rejected with typed errors", {
  expect_error(pivot_wide_to_long_cgjr(panel[-1], mapping, countries),
               class = "cgjrdata_error_missing_columns")
  expect_error(pivot_wide_to_long_cgjr(panel, mapping[-6], countries),
               class = "cgjrdata_error_missing_columns")
  expect_error(pivot_wide_to_long_cgjr(panel, mapping, countries[1]),
               class = "cgjrdata_error_missing_columns")
  expect_error(pivot_wide_to_long_cgjr(panel, mapping, countries, c("a", "b")),
               class = "cgjrdata_error_bad_argument")
  dup <- rbind(countries, countries[1, ])
  expect_error(pivot_wide_to_long_cgjr(panel, mapping, dup), class = "cgjrdata_error_bad_argument")
})

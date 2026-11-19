sources <- list(
  pefa = tibble::tibble(country_code = "GHA", year = 2020, pefa_1 = 3),
  d360 = tibble::tibble(country_code = "GHA", year = 2020, pefa_1 = 3, wdi_1 = 7),
  spi  = tibble::tibble(country_code = "GHA", year = 2020, spi_1 = 60)
)

test_that("each variable is found in the first dataset that has it", {
  out <- suppressMessages(locate_raw_variables(c("wdi_1", "pefa_1", "spi_1"), sources))
  expect_named(out, c("variable", "raw_dataset"))
  expect_identical(out$raw_dataset[match(c("pefa_1", "wdi_1", "spi_1"), out$variable)],
                   c("pefa", "d360", "spi"))
})

test_that("dataset order decides ties", {
  out <- suppressMessages(locate_raw_variables("pefa_1", sources[c("d360", "pefa")]))
  expect_identical(out$raw_dataset, "d360")
})

test_that("all found gives a confirmation message", {
  expect_message(locate_raw_variables("pefa_1", sources), "raw dataset")
})

test_that("variables found nowhere warn, are named, and are left out", {
  w <- expect_warning(
    out <- suppressMessages(locate_raw_variables(c("pefa_1", "external_1"), sources)),
    class = "cgjrdata_warning_no_raw_dataset"
  )
  expect_match(conditionMessage(w), "external_1")
  expect_identical(out$variable, "pefa_1")
})

test_that("repeated and NA variables are located once and ignored, respectively", {
  out <- suppressMessages(locate_raw_variables(c("pefa_1", NA, "pefa_1"), sources))
  expect_identical(out$variable, "pefa_1")
})

test_that("zero variables gives a zero-row result", {
  out <- suppressMessages(locate_raw_variables(character(), sources))
  expect_identical(nrow(out), 0L)
  expect_named(out, c("variable", "raw_dataset"))
})

test_that("datasets must be a named list of data frames", {
  expect_error(locate_raw_variables("pefa_1", unname(sources)),
               class = "cgjrdata_error_bad_argument")
  expect_error(locate_raw_variables("pefa_1", list(a = 1:3)),
               class = "cgjrdata_error_bad_argument")
})

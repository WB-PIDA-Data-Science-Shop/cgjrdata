#' Reshape a wide country table into CGJR's long, taxonomy-labelled form
#'
#' Turns a wide table (one row per country, or per country-year, and one
#' column per variable) into the long shape of `cgjr_ctf` and `cgjr_raw`:
#' one row per country x year x variable x leaf, labelled with where the
#' variable sits in the CGJR taxonomy. The steps are:
#'
#' 1. Keep `country_code`, `year` and the columns named in
#'    `mapping$variable`; other columns are ignored, and mapped variables the
#'    table lacks are skipped.
#' 2. Stack those columns into `variable` and a value column named
#'    `value_col`. Missing values are kept as rows.
#' 3. Keep only countries listed in `countries` (this drops World Bank
#'    aggregates such as `AFE` or `WLD`) and name them from
#'    `countries$economy`.
#' 4. Attach the taxonomy labels from `mapping`. A variable mapped to two
#'    leaves gives two rows per cell, one per leaf, with the same value.
#'
#' A table without a `year` column (a cross-section, like the static CTF
#' panel) gets `year = NA`.
#'
#' The function only reshapes and labels: it does not filter by
#' eligibility, rescale or aggregate. Pass a `mapping` already restricted to
#' the variables you want (e.g. the rows with `in_dynamic`). Check the
#' stacked result with [check_duplicate_obs()].
#'
#' @param data Wide data frame with a `country_code` column (ISO3),
#'   optionally `year` (whole numbers), and one numeric column per variable.
#' @param mapping Data frame, one row per variable x leaf, with columns
#'   `variable`, `cluster`, `subcluster`, `sub_subcluster`, `leaf` and
#'   `indicator`, e.g. rows of `cgjr_crosswalk`. Other columns are ignored.
#' @param countries Data frame of real countries with columns `country_code`
#'   (unique) and `economy` (display name), normally `wbcountries`.
#' @param value_col Name of the value column in the result, a single
#'   string: `"ctf"` for CTF scores, `"value"` (default) for raw values.
#'
#' @return A tibble, one row per country x year x variable x leaf, with
#'   columns `unit_level` (always `"country"`), `unit_code`, `unit_name`,
#'   `year` (integer; `NA` for a cross-section), `cluster`, `subcluster`,
#'   `sub_subcluster`, `leaf`, `indicator`, `variable` (all character) and
#'   the double column named by `value_col`. Zero rows, same columns, when
#'   `data` holds none of the mapped variables.
#'
#' @section Errors:
#' * `cgjrdata_error_missing_columns`: an input lacks a required column.
#' * `cgjrdata_error_bad_argument`: `value_col` is not a single string, or
#'   `countries$country_code` repeats.
#'
#' @family build steps
#'
#' @examples
#' wide <- data.frame(
#'   country_code = c("GHA", "KEN", "WLD"),
#'   year         = 2020,
#'   wjp_rol_2    = c(0.41, 0.38, 0.55)
#' )
#' mapping <- cgjr_crosswalk[cgjr_crosswalk$variable %in% "wjp_rol_2", ]
#' # Two rows, GHA and KEN; WLD is an aggregate, not in wbcountries
#' pivot_wide_to_long_cgjr(wide, mapping, wbcountries, "ctf")
#'
#' @export
pivot_wide_to_long_cgjr <- function(data, mapping, countries, value_col = "value") {
  # Check the inputs carry the columns the reshape relies on
  check_columns(data, "country_code", "data")
  check_columns(mapping, c("variable", .cgjr_label_cols), "mapping")
  check_columns(countries, c("country_code", "economy"), "countries")
  if (!is.character(value_col) || length(value_col) != 1L || is.na(value_col)) {
    cli::cli_abort("{.arg value_col} must be a single string.",
                   class = c("cgjrdata_error_bad_argument", "cgjrdata_error"))
  }
  if (anyDuplicated(countries$country_code) > 0L) {
    cli::cli_abort("{.arg countries} must list each {.field country_code} once.",
                   class = c("cgjrdata_error_bad_argument", "cgjrdata_error"))
  }

  # A cross-section has no year; give it a missing one (on a local copy)
  if (!"year" %in% names(data)) data$year <- NA_integer_

  # 1. The mapped variables this table actually holds
  vars <- intersect(unique(mapping$variable), names(data))

  # 2. Stack them: one row per country x year x variable
  if (length(vars) > 0L) {
    long <- tidyr::pivot_longer(
      tibble::as_tibble(data[c("country_code", "year", vars)]),
      cols = dplyr::all_of(vars), names_to = "variable", values_to = "value"
    )
  } else {
    long <- tibble::tibble(country_code = character(), year = integer(),
                           variable = character(), value = double())
  }

  # 3. Real countries only, named as in `countries`
  names_tbl <- tibble::tibble(country_code = countries$country_code,
                              unit_name    = countries$economy)
  long <- dplyr::inner_join(long, names_tbl, by = "country_code",
                            relationship = "many-to-one")

  # 4. Taxonomy labels; a variable on several leaves yields one row per leaf
  long <- dplyr::inner_join(long, mapping[c("variable", .cgjr_label_cols)],
                            by = "variable", relationship = "many-to-many")

  # Assemble the documented columns, value last under its chosen name
  out <- tibble::tibble(
    unit_level     = rep("country", nrow(long)),
    unit_code      = long$country_code,
    unit_name      = long$unit_name,
    year           = as.integer(long$year),
    cluster        = long$cluster,
    subcluster     = long$subcluster,
    sub_subcluster = long$sub_subcluster,
    leaf           = long$leaf,
    indicator      = long$indicator,
    variable       = long$variable
  )
  out[[value_col]] <- as.double(long$value)
  out
}

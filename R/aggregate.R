# ============================================================================
# Cross-country group aggregation: region / income-group rows
# ============================================================================
# aggregate_to_groups() takes the country rows of a long tibble shaped like
# cgjr_ctf or cgjr_scores and produces the matching region / income-group
# rows: for each group x every other identity column present (year,
# ctf_type, and whichever taxonomy/node columns exist), agg() (default
# stats::median, for CLIAR fidelity) across the group's countries.
#
# This is "order ii": each country is rolled up fully first (build_ctf_tbl(),
# roll_up_scores()), and only then are countries aggregated across, at every
# node/indicator level independently. It is deliberately *not* the same as
# aggregating raw indicators and re-rolling - because median isn't linear,
# a region's cgjr_scores rows won't arithmetically reconcile with a
# recomputation from its cgjr_ctf rows. That is expected and documented.
#
# Every group row also reports n_inputs (countries in the group present in
# `tbl`) and n_inputs_obs (of those, how many had a non-NA value) - the
# min_n = 1 default emits every group regardless of coverage, on the
# expectation that a consumer thresholds on these counts rather than the
# package silently dropping thin aggregates.

#' Join World Bank region / income-group classifications onto country rows
#'
#' Left-joins `region`, `region_code`, and `income_group` from `wbcountries`
#' onto `tbl` by matching `tbl$unit_code` to `wbcountries$country_code`. Rows
#' whose `unit_code` does not appear in `wbcountries` (e.g. World Bank
#' aggregate codes such as `"WLD"`, `"SSA"`) receive `NA` in the three new
#' columns.
#'
#' @param tbl A tibble with a `unit_code` column of ISO3 country codes.
#' @param wbcountries The `wbcountries` classification tibble - must contain
#'   `country_code`, `region`, `region_code`, `income_group`.
#'
#' @return `tbl` with three additional columns: `region`, `region_code`,
#'   `income_group`.
#'
#' @seealso [aggregate_to_groups()]
#'
#' @export
join_wb_classifications <- function(tbl, wbcountries) {
  stopifnot(is.data.frame(tbl), is.data.frame(wbcountries))
  cls <- wbcountries[, c("country_code", "region", "region_code", "income_group"),
                     drop = FALSE]
  dplyr::left_join(tbl, cls, by = c("unit_code" = "country_code"),
                   relationship = "many-to-one")
}

# "High income" -> "high_income". Used as the unit_code for income-group
# rows (there is no separate income-group code system, unlike region_code).
#' @keywords internal
#' @noRd
.slugify_income_group <- function(x) {
  tolower(gsub("[^A-Za-z0-9]+", "_", trimws(x)))
}

# Group `cls` (already carrying region/income classifications) by
# (code_col, name_col, id_cols), aggregate `value_col` with `agg`, count
# n_inputs / n_inputs_obs, apply min_n, and relabel to unit_level / unit_code
# / unit_name.
#' @keywords internal
#' @noRd
.aggregate_one_group <- function(cls, code_col, name_col, unit_level_val,
                                 id_cols, value_col, agg, min_n) {
  fn_list <- list(
    agg          = ~ agg(.x, na.rm = TRUE),
    n_inputs     = ~ length(.x),
    n_inputs_obs = ~ sum(!is.na(.x))
  )
  names(fn_list)[1] <- value_col

  out <- cls |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(code_col, name_col, id_cols)))) |>
    dplyr::summarise(
      dplyr::across(dplyr::all_of(value_col), fn_list, .names = "{.fn}"),
      .groups = "drop"
    )

  out[[value_col]][is.nan(out[[value_col]])]   <- NA_real_
  out[[value_col]][out$n_inputs_obs < min_n]   <- NA_real_

  out$unit_level <- unit_level_val
  names(out)[names(out) == code_col] <- "unit_code"
  names(out)[names(out) == name_col] <- "unit_name"
  out
}

#' Aggregate country rows to region / income-group rows
#'
#' Takes the **country rows** of a long tibble shaped like `cgjr_ctf` or
#' `cgjr_scores` (`unit_level == "country"`; other `unit_level`s are
#' ignored) and produces the matching `"region"` and `"income_group"` rows:
#' for every combination of the identity columns present (everything except
#' `unit_level` / `unit_code` / `unit_name` / `value_col` / any existing
#' `n_inputs` / `n_inputs_obs`), `agg()` is applied across the group's
#' countries.
#'
#' World Bank aggregate codes that do not match a row of `wbcountries` (e.g.
#' `"WLD"`, `"SSA"`) are dropped before aggregating, as are the handful of
#' territories `wbcountries` has no `income_group` for (they still
#' contribute to their region).
#'
#' Every output row carries `n_inputs` (how many countries in the group
#' appear in `tbl`) and `n_inputs_obs` (how many of those had a non-`NA`
#' `value_col`) - added even when `tbl` had no such columns to begin with
#' (`cgjr_ctf`'s country rows carry neither; its region/income rows still
#' get both, so a consumer can always see how many countries backed a group
#' value). If `n_inputs_obs < min_n`, the aggregated value is set to `NA`
#' (the row is still emitted, with its counts intact) - the default
#' `min_n = 1` never trims a row on its own, since `agg(..., na.rm = TRUE)`
#' already yields `NA` once there is nothing left to aggregate.
#'
#' @param tbl A long tibble with `unit_level`, `unit_code`, `unit_name`, and
#'   `value_col` (plus whatever taxonomy/node/year/ctf_type columns identify
#'   a row).
#' @param wbcountries The `wbcountries` classification tibble.
#' @param value_col Name of the column to aggregate (e.g. `"ctf"` or
#'   `"score"`).
#' @param agg Aggregation function, applied as `agg(x, na.rm = TRUE)`.
#'   Defaults to [stats::median] (CLIAR fidelity); pass `mean` to switch.
#' @param min_n Minimum number of non-`NA` countries (`n_inputs_obs`)
#'   required for a group's aggregated value to be kept; below that the
#'   value is set to `NA`. Defaults to `1`.
#'
#' @return A tibble with the same identity columns as `tbl` (minus
#'   `unit_code` / `unit_name`, which are replaced by the group's own),
#'   `unit_level` `"region"` or `"income_group"`, `value_col`, `n_inputs`,
#'   `n_inputs_obs`. Region rows use `region_code` as `unit_code` and
#'   `region` as `unit_name`; income-group rows use a slug of `income_group`
#'   (e.g. `"high_income"`) as `unit_code` and `income_group` as `unit_name`.
#'
#' @seealso [join_wb_classifications()]
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' ctf_country <- build_ctf_tbl(cgjr_crosswalk)
#' aggregate_to_groups(ctf_country, wbcountries, "ctf")
#' }
#'
#' @export
aggregate_to_groups <- function(tbl, wbcountries, value_col,
                                agg = stats::median, min_n = 1) {
  stopifnot(is.data.frame(tbl), is.data.frame(wbcountries), is.function(agg),
            is.numeric(min_n), min_n >= 0)

  req <- c("unit_level", "unit_code", "unit_name")
  miss <- setdiff(req, names(tbl))
  if (length(miss)) {
    stop("aggregate_to_groups(): `tbl` is missing column(s): ",
         paste(miss, collapse = ", "), call. = FALSE)
  }
  if (!value_col %in% names(tbl)) {
    stop("aggregate_to_groups(): `tbl` has no column `", value_col, "`",
         call. = FALSE)
  }
  wb_req <- c("country_code", "region", "region_code", "income_group")
  wb_miss <- setdiff(wb_req, names(wbcountries))
  if (length(wb_miss)) {
    stop("aggregate_to_groups(): `wbcountries` is missing column(s): ",
         paste(wb_miss, collapse = ", "), call. = FALSE)
  }

  country_tbl <- tbl[tbl$unit_level == "country", , drop = FALSE]
  id_cols <- setdiff(
    names(country_tbl),
    c("unit_level", "unit_code", "unit_name", value_col, "n_inputs", "n_inputs_obs")
  )

  cls <- join_wb_classifications(country_tbl, wbcountries)
  cls$.income_slug <- .slugify_income_group(cls$income_group)

  region_rows <- .aggregate_one_group(
    cls[!is.na(cls$region_code), , drop = FALSE],
    code_col = "region_code", name_col = "region", unit_level_val = "region",
    id_cols = id_cols, value_col = value_col, agg = agg, min_n = min_n
  )
  income_rows <- .aggregate_one_group(
    cls[!is.na(cls$income_group), , drop = FALSE],
    code_col = ".income_slug", name_col = "income_group", unit_level_val = "income_group",
    id_cols = id_cols, value_col = value_col, agg = agg, min_n = min_n
  )

  col_order <- c("unit_level", "unit_code", "unit_name", id_cols,
                 value_col, "n_inputs", "n_inputs_obs")
  tibble::as_tibble(dplyr::bind_rows(region_rows, income_rows)[, col_order, drop = FALSE])
}

#' Find the source dataset holding each variable's raw values
#'
#' Answers "which dataset do I read this variable's raw (unbenchmarked)
#' values from?". Each variable is looked up in `datasets` in the order
#' given, and the first dataset with a column of that name wins. Order
#' therefore decides ties: put a dedicated source before a compilation that
#' repeats its columns (for example `pefa_assessments` before
#' `d360_efi_data`).
#'
#' Columns are matched by name only, so a variable is found wherever it
#' lives, whatever its catalogue `etl_source` says. Prints a green tick when
#' every variable is found. Variables found nowhere raise a warning listing
#' them and are left out of the result; the build carries on, because an
#' indicator may come from outside `cliaretl`.
#'
#' Next, reshape each dataset's variables with [pivot_wide_to_long_cgjr()].
#'
#' @param variables Character vector of variable codes. Repeats are located
#'   once; `NA` is ignored.
#' @param datasets A named list of wide data frames (one column per
#'   variable), in priority order. Names identify the datasets in the result,
#'   e.g. `list(pefa_assessments = cliaretl::pefa_assessments, ...)`.
#'
#' @return A tibble with one row per variable found:
#'   * `variable` (character): the variable code.
#'   * `raw_dataset` (character): name of the first dataset in `datasets`
#'     holding it.
#'
#' @section Errors and warnings:
#' * `cgjrdata_error_bad_argument`: `datasets` is not a named list of data
#'   frames.
#' * `cgjrdata_warning_no_raw_dataset`: some variables were found in no
#'   dataset.
#'
#' @family build steps
#'
#' @examples
#' sources <- list(
#'   pefa = data.frame(country_code = "GHA", year = 2020, pefa_1 = 3),
#'   d360 = data.frame(country_code = "GHA", year = 2020, pefa_1 = 3, wdi_1 = 7)
#' )
#' # pefa_1 is in both; the first listed dataset (pefa) wins
#' locate_raw_variables(c("pefa_1", "wdi_1"), sources)
#'
#' @export
locate_raw_variables <- function(variables, datasets) {
  # Check the datasets are a named list of tables
  ok <- is.list(datasets) && !is.data.frame(datasets) &&
    !is.null(names(datasets)) && all(nzchar(names(datasets))) &&
    all(vapply(datasets, is.data.frame, logical(1)))
  if (!ok) {
    cli::cli_abort("{.arg datasets} must be a named list of data frames.",
                   class = c("cgjrdata_error_bad_argument", "cgjrdata_error"))
  }

  # Each distinct named variable once
  vars <- unique(variables[!is.na(variables)])

  # For each variable, the first dataset (in priority order) with that column
  home <- vapply(vars, function(v) {
    has_it <- vapply(datasets, function(d) v %in% names(d), logical(1))
    if (any(has_it)) names(datasets)[which(has_it)[1]] else NA_character_
  }, character(1), USE.NAMES = FALSE)

  # Report variables found nowhere; they are left out of the result
  warn_if_any(
    vars[is.na(home)],
    fail  = "Variables found in no raw dataset (they get no raw values):",
    pass  = "Every variable was found in a raw dataset.",
    class = "cgjrdata_warning_no_raw_dataset"
  )

  tibble::tibble(variable = vars[!is.na(home)], raw_dataset = home[!is.na(home)])
}

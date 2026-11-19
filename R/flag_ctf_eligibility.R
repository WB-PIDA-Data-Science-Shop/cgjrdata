#' Which variables CLIAR benchmarks in each Closeness-to-Frontier panel
#'
#' Answers "will this variable get CTF values in cgjrapp, dynamic and
#' static?" using the same rule as the CLIAR app, so an indicator shared by
#' both apps is benchmarked identically. A variable is eligible for a panel
#' when both hold:
#'
#' * it is a column of that panel, and
#' * the catalogue flags it for that panel: `benchmark_dynamic_indicator ==
#'   "Yes"` for dynamic, `benchmarked_ctf == "Yes"` for static. These are
#'   the flags `cliaretl` itself uses to list its dynamic and static
#'   benchmarked variables.
#'
#' Panel membership alone is not enough: both `cliaretl` panels also carry
#' columns CLIAR does not flag, for example the family averages
#' (`vars_*_avg`) in the dynamic panel.
#'
#' @param variables Character vector of variable codes. `NA` is allowed and
#'   is never eligible.
#' @param catalogue The variable catalogue, with columns `variable`,
#'   `benchmark_dynamic_indicator` and `benchmarked_ctf` (`"Yes"` marks a
#'   benchmarked variable; anything else, including `NA`, does not).
#'   Defaults to [cliaretl::db_variables_final].
#' @param ctf_dynamic,ctf_static The wide CTF panels. Default to
#'   [cliaretl::closeness_to_frontier_dynamic] and
#'   [cliaretl::closeness_to_frontier_static].
#'
#' @return A tibble with one row per element of `variables`, in the same
#'   order, so it can sit beside them in `dplyr::mutate()`:
#'   * `in_dynamic` (logical): eligible for the dynamic panel.
#'   * `in_static` (logical): eligible for the static panel.
#'
#' @section Errors:
#' * `cgjrdata_error_bad_argument`: `variables` is not character.
#' * `cgjrdata_error_missing_columns`: `catalogue` lacks a flag column.
#'
#' @family build steps
#'
#' @examplesIf requireNamespace("cliaretl", quietly = TRUE)
#' # wjp_rol_2 is benchmarked in both panels; the anti-corruption family
#' # average is a dynamic-panel column CLIAR does not flag, so it is
#' # static-only; NA is never eligible.
#' flag_ctf_eligibility(c("wjp_rol_2", "vars_anticorruption_avg", NA))
#'
#' @export
flag_ctf_eligibility <- function(variables,
                                 catalogue   = cliaretl::db_variables_final,
                                 ctf_dynamic = cliaretl::closeness_to_frontier_dynamic,
                                 ctf_static  = cliaretl::closeness_to_frontier_static) {
  # Check the inputs
  if (!is.character(variables) && !all(is.na(variables))) {
    cli::cli_abort("{.arg variables} must be a character vector.",
                   class = c("cgjrdata_error_bad_argument", "cgjrdata_error"))
  }
  check_columns(catalogue,
                c("variable", "benchmark_dynamic_indicator", "benchmarked_ctf"),
                "catalogue")

  # Variables CLIAR benchmarks, per panel (`%in%` treats a missing flag as "not Yes")
  dynamic_yes <- catalogue$variable[catalogue$benchmark_dynamic_indicator %in% "Yes"]
  static_yes  <- catalogue$variable[catalogue$benchmarked_ctf %in% "Yes"]

  # Eligible = a panel column AND flagged for that panel; panel column names
  # are never NA, so an NA variable is never eligible
  tibble::tibble(
    in_dynamic = variables %in% intersect(names(ctf_dynamic), dynamic_yes),
    in_static  = variables %in% intersect(names(ctf_static), static_yes)
  )
}

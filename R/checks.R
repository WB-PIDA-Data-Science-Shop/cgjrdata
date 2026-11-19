# ============================================================================
# Build checks: pass with a green tick, fail with a red cross
# ============================================================================
# Every check reports in the same way so a build log reads as a checklist:
#   v  <what passed>                      (cli::cli_alert_success)
#   x  <what failed>: offending values    (error - the build stops)
#   !  <what is missing>: offending values (warning - the build carries on)

# Taxonomy label columns every long table and mapping carries.
.cgjr_label_cols <- c("cluster", "subcluster", "sub_subcluster", "leaf", "indicator")

#' Stop with a red cross if any offenders were found, else tick
#'
#' @param bad Character vector of offending values; empty means the check
#'   passed. Long vectors are truncated by cli after 20 values.
#' @param fail,pass Plain-text messages for the failing and passing case.
#' @param class Condition class added in front of `"cgjrdata_error"`.
#' @param call Environment of the function to name in the error.
#' @return `invisible(TRUE)` when `bad` is empty; otherwise signals an error.
#' @noRd
stop_if_any <- function(bad, fail, pass, class, call = parent.frame()) {
  # Nothing to report: confirm with a green tick
  if (length(bad) == 0L) {
    cli::cli_alert_success("{pass}")
    return(invisible(TRUE))
  }

  # Otherwise stop, listing the offenders under the red cross
  cli::cli_abort(c("x" = "{fail}", "i" = "{.val {bad}}"),
                 class = c(class, "cgjrdata_error"), call = call)
}

#' Warn if any offenders were found, else tick
#'
#' Same contract as `stop_if_any()`, but signals a warning of class
#' `c(class, "cgjrdata_warning")` and returns `invisible(FALSE)` so the
#' caller carries on.
#' @noRd
warn_if_any <- function(bad, fail, pass, class) {
  # Nothing to report: confirm with a green tick
  if (length(bad) == 0L) {
    cli::cli_alert_success("{pass}")
    return(invisible(TRUE))
  }

  # Otherwise warn, listing the offenders, and let the build continue
  cli::cli_warn(c("!" = "{fail}", "i" = "{.val {bad}}"),
                class = c(class, "cgjrdata_warning"))
  invisible(FALSE)
}

#' Assert that an argument is a data frame carrying the given columns
#'
#' @param df Object to check.
#' @param cols Character vector of required column names.
#' @param arg Argument name, for the message.
#' @param call Environment of the function to name in the error.
#' @return `invisible(df)`; errors with class `cgjrdata_error_bad_argument`
#'   (not a data frame) or `cgjrdata_error_missing_columns`.
#' @noRd
check_columns <- function(df, cols, arg, call = parent.frame()) {
  # The argument must be a table at all
  if (!is.data.frame(df)) {
    cli::cli_abort("{.arg {arg}} must be a data frame.",
                   class = c("cgjrdata_error_bad_argument", "cgjrdata_error"),
                   call = call)
  }

  # And it must carry every column the caller relies on
  missing <- setdiff(cols, names(df))
  if (length(missing) > 0L) {
    cli::cli_abort("{.arg {arg}} is missing column{?s} {.val {missing}}.",
                   class = c("cgjrdata_error_missing_columns", "cgjrdata_error"),
                   call = call)
  }
  invisible(df)
}


#' Check the CGJR crosswalk against the taxonomy and `cliaretl`
#'
#' Answers "is the crosswalk ready to build from?" before any data are
#' reshaped. It runs four checks in order and reports each one on its own
#' line, a green tick when it passes:
#'
#' 1. **Duplicate taxonomy leaves** (stops the build). A leaf is a row's
#'    `sub_subcluster` where it has one, otherwise its `subcluster`; the
#'    long tables use it as a join key, so it must be unique.
#' 2. **Crosswalk rows off the taxonomy** (stops the build). Every
#'    `(cluster, subcluster, sub_subcluster)` path in the crosswalk must be
#'    a row of the taxonomy. Offenders are listed as
#'    `indicator (cluster > subcluster > sub_subcluster)`.
#' 3. **Variables not in the `cliaretl` catalogue** (warning). These have no
#'    description and no CLIAR benchmarking flags.
#' 4. **Variables with no CTF values** (warning): neither eligible for the
#'    dynamic nor for the static Closeness-to-Frontier panel, as decided by
#'    [flag_ctf_eligibility()]. A variable eligible for only one panel is
#'    fine.
#'
#' Checks 3 and 4 only warn because a CGJR indicator need not come from
#' `cliaretl`: it can be sourced elsewhere and still be listed in the
#' crosswalk. Rows with no `variable` are skipped by both. A variable mapped
#' to several leaves is allowed.
#'
#' Run it in `data-raw/cgjr.R` straight after reading the CSVs. Next, locate
#' raw values with [locate_raw_variables()].
#'
#' @param crosswalk Data frame, one row per indicator x leaf, with columns
#'   `cluster`, `subcluster`, `sub_subcluster` (character, `NA` outside the
#'   Public Financial Management branch), `indicator` and `variable`
#'   (character, `NA` when no variable has been confirmed yet).
#' @param taxonomy Data frame, one row per leaf, with columns `cluster`,
#'   `subcluster` and `sub_subcluster`. Normally `cgjr_taxonomy`.
#' @param catalogue The variable catalogue, with columns `variable`,
#'   `benchmark_dynamic_indicator` and `benchmarked_ctf`. Defaults to
#'   [cliaretl::db_variables_final].
#' @param ctf_dynamic,ctf_static The wide Closeness-to-Frontier panels whose
#'   column names say which variables have CTF values. Default to
#'   [cliaretl::closeness_to_frontier_dynamic] and
#'   [cliaretl::closeness_to_frontier_static].
#'
#' @return `crosswalk`, invisibly and unchanged. Called for its messages,
#'   warnings and errors.
#'
#' @section Errors and warnings:
#' * `cgjrdata_error_missing_columns`: an input lacks a required column.
#' * `cgjrdata_error_duplicate_leaves`: check 1 failed.
#' * `cgjrdata_error_orphan_leaves`: check 2 failed.
#' * `cgjrdata_warning_not_in_catalogue`: check 3 found variables.
#' * `cgjrdata_warning_no_ctf`: check 4 found variables.
#'
#' All errors also carry class `cgjrdata_error`, all warnings
#' `cgjrdata_warning`.
#'
#' @family build steps
#' @seealso [flag_ctf_eligibility()] for the eligibility rule in check 4.
#'
#' @examplesIf requireNamespace("cliaretl", quietly = TRUE)
#' # The shipped crosswalk passes: four green ticks
#' check_cgjr_mapping(cgjr_crosswalk, cgjr_taxonomy)
#'
#' @export
check_cgjr_mapping <- function(crosswalk,
                               taxonomy,
                               catalogue   = cliaretl::db_variables_final,
                               ctf_dynamic = cliaretl::closeness_to_frontier_dynamic,
                               ctf_static  = cliaretl::closeness_to_frontier_static) {
  # Check the inputs carry the columns the checks rely on
  path_cols <- c("cluster", "subcluster", "sub_subcluster")
  check_columns(crosswalk, c(path_cols, "indicator", "variable"), "crosswalk")
  check_columns(taxonomy, path_cols, "taxonomy")
  check_columns(catalogue, "variable", "catalogue")

  # 1. Each taxonomy leaf appears once
  leaves <- dplyr::coalesce(taxonomy$sub_subcluster, taxonomy$subcluster)
  stop_if_any(
    unique(leaves[duplicated(leaves)]),
    fail  = "Duplicate taxonomy leaves:",
    pass  = "No duplicate taxonomy leaves.",
    class = "cgjrdata_error_duplicate_leaves"
  )

  # 2. Every crosswalk row sits on a taxonomy leaf (missing keys match missing)
  orphans <- dplyr::anti_join(crosswalk, taxonomy, by = path_cols)
  orphan_paths <- paste(orphans$cluster, orphans$subcluster, sep = " > ")
  orphan_paths <- ifelse(is.na(orphans$sub_subcluster), orphan_paths,
                         paste(orphan_paths, orphans$sub_subcluster, sep = " > "))
  stop_if_any(
    # sprintf(), unlike paste0(), returns nothing when there are no orphans
    sprintf("%s (%s)", orphans$indicator, orphan_paths),
    fail  = "Crosswalk rows whose leaf is not in the taxonomy:",
    pass  = "Every crosswalk row sits on a taxonomy leaf.",
    class = "cgjrdata_error_orphan_leaves"
  )

  # The remaining checks look at each named variable once
  vars <- unique(crosswalk$variable[!is.na(crosswalk$variable)])

  # 3. Variables the cliaretl catalogue knows
  warn_if_any(
    setdiff(vars, catalogue$variable),
    fail  = "Variables not in the cliaretl catalogue (no description or CLIAR benchmarking flags):",
    pass  = "Every variable is in the cliaretl catalogue.",
    class = "cgjrdata_warning_not_in_catalogue"
  )

  # 4. Variables with CTF values CLIAR benchmarks, in at least one panel
  eligible <- flag_ctf_eligibility(vars, catalogue, ctf_dynamic, ctf_static)
  warn_if_any(
    vars[!eligible$in_dynamic & !eligible$in_static],
    fail  = "Variables with no CTF values (not a CTF panel column, or not flagged for CLIAR benchmarking):",
    pass  = "Every variable has CTF values in at least one panel.",
    class = "cgjrdata_warning_no_ctf"
  )

  invisible(crosswalk)
}


#' Check that a long table has one row per observation
#'
#' Answers "does any key combination occur more than once?" for a finished
#' long table such as `cgjr_ctf` or `cgjr_raw`. A repeated key would
#' double-count an indicator wherever cgjrapp averages, so the build stops.
#' A missing value in a key column (the static panel's `year`) counts as a
#' value of its own, not as a wildcard: two static rows for the same
#' country, variable and leaf are duplicates.
#'
#' Prints a green tick when the keys are unique; otherwise stops and lists
#' the repeated key combinations, each as its key values joined by `" / "`.
#'
#' @param data A data frame, for example `cgjr_ctf`.
#' @param keys Character vector of the columns that together identify one
#'   observation, e.g. `c("ctf_type", "unit_code", "year", "variable",
#'   "leaf")` for `cgjr_ctf`.
#'
#' @return `data`, invisibly and unchanged.
#'
#' @section Errors:
#' * `cgjrdata_error_missing_columns`: `data` lacks one of `keys`.
#' * `cgjrdata_error_duplicate_obs`: some key combination repeats.
#'
#' Both also carry class `cgjrdata_error`.
#'
#' @family build steps
#'
#' @examples
#' # One row per taxonomy leaf: passes with a green tick
#' check_duplicate_obs(cgjr_taxonomy, c("cluster", "subcluster", "sub_subcluster"))
#'
#' @export
check_duplicate_obs <- function(data, keys) {
  # The key columns must exist
  check_columns(data, keys, "data")

  # Key combinations that occur more than once, written out for the message
  key_tbl  <- as.data.frame(data)[keys]
  repeated <- unique(key_tbl[duplicated(key_tbl), , drop = FALSE])
  repeated <- do.call(paste, c(unname(as.list(repeated)), sep = " / "))

  stop_if_any(
    repeated,
    fail  = paste0("Duplicate observations on ", paste(keys, collapse = " / "), ":"),
    pass  = paste0("No duplicate observations on ", paste(keys, collapse = " / "), "."),
    class = "cgjrdata_error_duplicate_obs"
  )
  invisible(data)
}

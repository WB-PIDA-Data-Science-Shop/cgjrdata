# ============================================================================
# CGJR crosswalk: cliaretl eligibility classification
# ============================================================================
# check_crosswalk_schema() (R/schema.R) asserts the *shape* of the two CSVs.
# The functions here answer the separate, cliaretl-dependent question: for
# each resolved `variable` code, is it a cliaretl variable, and is it eligible
# for the dynamic and/or static Closeness-to-Frontier panel?
#
# CTF windows / direction / indicator eligibility are already enforced
# upstream in cliaretl::closeness_to_frontier_dynamic / _static - a variable
# that survived into those panels is fair game. We only report membership and
# the one extra gate cliaretl exposes for the dynamic panel
# (benchmark_dynamic_indicator == "Yes"). There is no benchmark_static_indicator
# flag, so static eligibility *is* static-panel membership.

#' Classify every CGJR crosswalk row against `cliaretl`
#'
#' For each row of a CGJR crosswalk, resolve its `variable` code against the
#' `cliaretl` catalogue and the two Closeness-to-Frontier panels and derive a
#' set of membership / eligibility flags. The result has one row per input
#' row, in the same order, so it can be column-bound onto the crosswalk by
#' [build_crosswalk()].
#'
#' @param crosswalk A crosswalk tibble with at least `cluster`, `subcluster`,
#'   `sub_subcluster`, `indicator_num`, `indicator` and `variable` columns
#'   (e.g. `cgjr_crosswalk`).
#' @param catalogue The variable catalogue. Defaults to
#'   [cliaretl::db_variables_final].
#' @param ctf_dynamic The dynamic CTF panel whose columns define dynamic-panel
#'   membership. Defaults to [cliaretl::closeness_to_frontier_dynamic].
#' @param ctf_static The static CTF cross-section whose columns define
#'   static-panel membership. Defaults to
#'   [cliaretl::closeness_to_frontier_static].
#'
#' @return A tibble with one row per crosswalk row (same order) and columns:
#'   \describe{
#'     \item{`cluster`, `subcluster`, `sub_subcluster`, `indicator_num`,
#'       `indicator`, `variable`}{copied from `crosswalk`.}
#'     \item{`in_cliaretl`}{`variable` appears in `catalogue$variable` (the
#'       `cliaretl` variable catalogue).}
#'     \item{`in_dynamic_panel`}{`variable` is a column of `ctf_dynamic`.}
#'     \item{`in_static_panel`}{`variable` is a column of `ctf_static`.}
#'     \item{`dynamic_eligible`}{`in_dynamic_panel` and the catalogue flags the
#'       variable `benchmark_dynamic_indicator == "Yes"`.}
#'     \item{`static_eligible`}{`in_static_panel` (there is no separate static
#'       indicator flag in the catalogue).}
#'     \item{`cliaretl_status`}{`"unresolved"` (`variable` is `NA`),
#'       `"not_in_cliaretl"` (set but absent from the `cliaretl` catalogue),
#'       or `"resolved"`.}
#'   }
#'
#' @seealso [validate_crosswalk()], [check_crosswalk_schema()]
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' classify_crosswalk(cgjr_crosswalk)
#' }
#'
#' @export
classify_crosswalk <- function(crosswalk,
                               catalogue   = cliaretl::db_variables_final,
                               ctf_dynamic = cliaretl::closeness_to_frontier_dynamic,
                               ctf_static  = cliaretl::closeness_to_frontier_static) {
  stopifnot(is.data.frame(crosswalk), is.data.frame(catalogue))

  req <- c("cluster", "subcluster", "sub_subcluster", "indicator_num",
           "indicator", "variable")
  miss <- setdiff(req, names(crosswalk))
  if (length(miss)) {
    stop("classify_crosswalk(): `crosswalk` is missing column(s): ",
         paste(miss, collapse = ", "), call. = FALSE)
  }

  variable <- crosswalk$variable

  cat_variable <- catalogue$variable[!is.na(catalogue$variable)]
  m            <- match(variable, catalogue$variable)
  bench_dyn    <- catalogue$benchmark_dynamic_indicator[m]

  in_cliaretl      <- variable %in% cat_variable          # NA -> FALSE
  in_dynamic_panel <- variable %in% names(ctf_dynamic)    # NA -> FALSE
  in_static_panel  <- variable %in% names(ctf_static)     # NA -> FALSE

  dynamic_eligible <- in_dynamic_panel & !is.na(bench_dyn) & bench_dyn == "Yes"
  static_eligible  <- in_static_panel

  cliaretl_status <- ifelse(
    is.na(variable), "unresolved",
    ifelse(!in_cliaretl, "not_in_cliaretl", "resolved")
  )

  tibble::tibble(
    cluster          = crosswalk$cluster,
    subcluster       = crosswalk$subcluster,
    sub_subcluster   = crosswalk$sub_subcluster,
    indicator_num    = crosswalk$indicator_num,
    indicator        = crosswalk$indicator,
    variable         = variable,
    in_cliaretl      = in_cliaretl,
    in_dynamic_panel = in_dynamic_panel,
    in_static_panel  = in_static_panel,
    dynamic_eligible = dynamic_eligible,
    static_eligible  = static_eligible,
    cliaretl_status  = cliaretl_status
  )
}


#' Validate the CGJR crosswalk against `cliaretl` and warn on gaps
#'
#' Runs [classify_crosswalk()] and emits a single `warning()` listing every
#' row that will contribute **no** Closeness-to-Frontier data, grouped into:
#'
#' \describe{
#'   \item{`unresolved`}{`variable` is `NA` - the taxonomy names an indicator
#'     but no `cliaretl` code has been confirmed for it.}
#'   \item{`not_in_cliaretl`}{`variable` is set but does not appear in
#'     `db_variables_final$variable`.}
#'   \item{`no_ctf_panel`}{`variable` resolves to a `cliaretl` catalogue entry
#'     but is eligible for neither the dynamic nor the static CTF panel.}
#' }
#'
#' Rows that are static-eligible only (not dynamic) are **not** warned about -
#' they are fine, they simply produce static rows only. Their count is
#' included in the summary message for visibility.
#'
#' Rows are never silently dropped or included by this function - that is the
#' build's decision, informed by this report.
#'
#' @inheritParams classify_crosswalk
#'
#' @return Invisibly, the [classify_crosswalk()] tibble.
#'
#' @seealso [classify_crosswalk()], [check_crosswalk_schema()]
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' validate_crosswalk(cgjr_crosswalk)
#' }
#'
#' @export
validate_crosswalk <- function(crosswalk,
                               catalogue   = cliaretl::db_variables_final,
                               ctf_dynamic = cliaretl::closeness_to_frontier_dynamic,
                               ctf_static  = cliaretl::closeness_to_frontier_static) {
  cls <- classify_crosswalk(crosswalk, catalogue, ctf_dynamic, ctf_static)

  any_ctf <- cls$dynamic_eligible | cls$static_eligible

  category <- ifelse(
    cls$cliaretl_status == "unresolved", "unresolved",
    ifelse(cls$cliaretl_status == "not_in_cliaretl", "not_in_cliaretl",
    ifelse(!any_ctf, "no_ctf_panel", NA_character_))
  )

  flagged <- !is.na(category)
  static_only_n <- sum(cls$static_eligible & !cls$dynamic_eligible)

  if (any(flagged)) {
    path <- paste0(
      cls$cluster, " > ", cls$subcluster,
      ifelse(is.na(cls$sub_subcluster), "", paste0(" > ", cls$sub_subcluster))
    )
    lines <- sprintf(
      "  [%s] %s :: %s (%s)",
      category[flagged],
      ifelse(is.na(cls$variable[flagged]), "<no variable>", cls$variable[flagged]),
      cls$indicator[flagged],
      path[flagged]
    )
    warning(
      "validate_crosswalk(): ", sum(flagged), " of ", nrow(cls),
      " crosswalk rows will contribute no CTF data",
      " (", sum(category == "unresolved", na.rm = TRUE), " unresolved, ",
      sum(category == "not_in_cliaretl", na.rm = TRUE), " not in cliaretl, ",
      sum(category == "no_ctf_panel", na.rm = TRUE), " in cliaretl but in no CTF panel); ",
      sum(cls$dynamic_eligible), " dynamic-eligible, ",
      static_only_n, " static-eligible only:\n",
      paste(lines, collapse = "\n"),
      call. = FALSE
    )
  }

  invisible(cls)
}

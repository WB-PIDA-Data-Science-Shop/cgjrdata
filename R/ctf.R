# ============================================================================
# cgjr_ctf: long, indicator-grain Closeness-to-Frontier values (country level)
# ============================================================================
# build_ctf_tbl() slices the dynamic and static CTF panels for every
# crosswalk variable flagged `dynamic_eligible` / `static_eligible` and
# stacks them into one long tibble, one row per
#   country x year x ctf_type x leaf x indicator
# (`year` is NA for ctf_type == "static" - the static panel is a snapshot
# with no year column).
#
# CTF windows / direction / eligibility are already enforced upstream in
# cliaretl; this function only slices columns and reshapes.

#' @keywords internal
#' @noRd
.ctf_tbl_shell <- function() {
  tibble::tibble(
    unit_level     = character(),
    unit_code      = character(),
    unit_name      = character(),
    year           = integer(),
    ctf_type       = character(),
    cluster        = character(),
    subcluster     = character(),
    sub_subcluster = character(),
    leaf           = character(),
    indicator      = character(),
    variable       = character(),
    ctf            = double()
  )
}

#' Build the long, indicator-grain CTF table (country level)
#'
#' For each `ctf_type` (`"dynamic"`, `"static"`), take every annotated
#' crosswalk row flagged eligible for that type (`dynamic_eligible` /
#' `static_eligible`), slice its `variable` column out of the corresponding
#' `cliaretl` CTF panel, and reshape to long form. The two types are stacked
#' into one tibble.
#'
#' A `variable` reused across two leaves (allowed by
#' [check_crosswalk_schema()]) fans out to one row per `(leaf, indicator)`.
#' Crosswalk rows that are unresolved, not in `cliaretl`, or not eligible for
#' a given type simply contribute no rows for that type.
#'
#' Country rows only. Region / income-group rows are added afterwards by
#' `aggregate_to_groups()`.
#'
#' @param crosswalk The annotated crosswalk (`cgjr_crosswalk`) - needs
#'   `variable`, `cluster`, `subcluster`, `sub_subcluster`, `leaf`,
#'   `indicator`, `dynamic_eligible`, `static_eligible`.
#' @param ctf_dynamic,ctf_static The dynamic and static CTF panels. Default to
#'   the `cliaretl` objects.
#' @param id_cols Identifier columns to carry from each panel. Defaults to
#'   `c("country_code", "country_name", "year")` (the static panel has no
#'   `year`, so it is dropped there automatically).
#'
#' @return A tibble with columns `unit_level` (always `"country"`),
#'   `unit_code`, `unit_name`, `year`, `ctf_type`, `cluster`, `subcluster`,
#'   `sub_subcluster`, `leaf`, `indicator`, `variable`, `ctf`.
#'
#' @seealso [build_raw_tbl()]. The rollup to node scores is `roll_up_scores()`
#'   (R/scores.R).
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' build_ctf_tbl(cgjr_crosswalk)
#' }
#'
#' @export
build_ctf_tbl <- function(crosswalk   = cgjr_crosswalk,
                          ctf_dynamic = cliaretl::closeness_to_frontier_dynamic,
                          ctf_static  = cliaretl::closeness_to_frontier_static,
                          id_cols     = c("country_code", "country_name", "year")) {
  
  ## quick check to ensure we have a data.frame object as crosswalk
  stopifnot(is.data.frame(crosswalk))
  ## the set of required columns in the crosswalk 
  req <- c("variable", "cluster", "subcluster", "sub_subcluster", "leaf",
           "indicator", "dynamic_eligible", "static_eligible")
  miss <- setdiff(req, names(crosswalk)) ## check for missing required variables
  ## specify the columns needed but missing before stopping
  if (length(miss)) {
    stop("build_ctf_tbl(): `crosswalk` is missing column(s): ",
         paste(miss, collapse = ", "), call. = FALSE)
  }

  ann_cols <- c("variable", "cluster", "subcluster", "sub_subcluster",
                "leaf", "indicator")

  one_type <- function(ctf_type) {
    panel     <- if (ctf_type == "dynamic") ctf_dynamic else ctf_static
    elig_flag <- if (ctf_type == "dynamic") "dynamic_eligible" else "static_eligible"

    ann <- crosswalk[crosswalk[[elig_flag]] & !is.na(crosswalk$variable),
                     ann_cols, drop = FALSE]
    vars <- intersect(unique(ann$variable), names(panel))
    if (length(vars) == 0L) return(.ctf_tbl_shell())

    ids  <- intersect(id_cols, names(panel))
    wide <- tibble::as_tibble(panel)[, c(ids, vars), drop = FALSE]
    long <- tidyr::pivot_longer(
      wide, cols = dplyr::all_of(vars),
      names_to = "variable", values_to = "ctf"
    )
    long <- dplyr::inner_join(long, ann, by = "variable",
                              relationship = "many-to-many")

    year_vec <- if (ctf_type == "static" || !"year" %in% names(long)) {
      rep(NA_integer_, nrow(long))
    } else {
      as.integer(long$year)
    }

    tibble::tibble(
      unit_level     = "country",
      unit_code      = long$country_code,
      unit_name      = if ("country_name" %in% names(long)) long$country_name else NA_character_,
      year           = year_vec,
      ctf_type       = ctf_type,
      cluster        = long$cluster,
      subcluster     = long$subcluster,
      sub_subcluster = long$sub_subcluster,
      leaf           = long$leaf,
      indicator      = long$indicator,
      variable       = long$variable,
      ctf            = long$ctf
    )
  }

  dplyr::bind_rows(one_type("dynamic"), one_type("static"))
}

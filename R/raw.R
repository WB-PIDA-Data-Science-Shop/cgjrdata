# ============================================================================
# cgjr_raw: long, indicator-grain raw source values (country level only)
# ============================================================================
# build_raw_tbl() pulls every resolved crosswalk variable from its original
# source dataset via extract_cliar_data(type = "raw") and reshapes to long
# form, one row per
#   country x year x leaf x indicator
#
# There is no ctf_type (raw has none) and no group aggregation: raw values
# are for display / download in cgjrapp, never benchmarking, and their units
# are heterogeneous (indices, %, counts) so a regional median is meaningless.
# Raw coverage is independent of CTF eligibility - a leaf that is empty in
# cgjr_ctf (PFM, SOE governance) can still carry raw PEFA / OECD-PMR values
# here.

#' @keywords internal
#' @noRd
.raw_tbl_shell <- function() {
  tibble::tibble(
    unit_level     = character(),
    unit_code      = character(),
    unit_name      = character(),
    year           = integer(),
    cluster        = character(),
    subcluster     = character(),
    sub_subcluster = character(),
    leaf           = character(),
    indicator      = character(),
    variable       = character(),
    value          = double()
  )
}

#' Build the long, indicator-grain raw source table (country level)
#'
#' Pulls every resolved crosswalk `variable` from its original source dataset
#' via [extract_cliar_data()] with `type = "raw"` and reshapes to long form.
#' Variables with no raw source (family aggregates, static-only codes with no
#' dedicated raw dataset) are dropped. A `variable` reused across two leaves
#' fans out to one row per `(leaf, indicator)`.
#'
#' Country rows only - `cgjr_raw` has no group-aggregate rows.
#'
#' @param crosswalk The annotated crosswalk (`cgjr_crosswalk`) - needs
#'   `variable`, `cluster`, `subcluster`, `sub_subcluster`, `leaf`,
#'   `indicator`.
#' @param id_cols Identifier columns passed to [extract_cliar_data()].
#'   Defaults to `c("country_code", "country_name", "year")`.
#'
#' @return A tibble with columns `unit_level` (always `"country"`),
#'   `unit_code`, `unit_name`, `year`, `cluster`, `subcluster`,
#'   `sub_subcluster`, `leaf`, `indicator`, `variable`, `value`.
#'
#' @seealso [build_ctf_tbl()], [extract_cliar_data()]
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' build_raw_tbl(cgjr_crosswalk)
#' }
#'
#' @export
build_raw_tbl <- function(crosswalk = cgjr_crosswalk,
                          id_cols   = c("country_code", "country_name", "year")) {
  stopifnot(is.data.frame(crosswalk))
  req <- c("variable", "cluster", "subcluster", "sub_subcluster", "leaf", "indicator")
  miss <- setdiff(req, names(crosswalk))
  if (length(miss)) {
    stop("build_raw_tbl(): `crosswalk` is missing column(s): ",
         paste(miss, collapse = ", "), call. = FALSE)
  }

  ann_cols <- c("variable", "cluster", "subcluster", "sub_subcluster",
                "leaf", "indicator")
  ann  <- crosswalk[!is.na(crosswalk$variable), ann_cols, drop = FALSE]
  vars <- unique(ann$variable)
  if (length(vars) == 0L) return(.raw_tbl_shell())

  wide <- suppressWarnings(
    extract_cliar_data(vars, type = "raw", id_vars = id_cols)
  )
  got <- intersect(vars, names(wide))
  if (length(got) == 0L) return(.raw_tbl_shell())

  long <- tidyr::pivot_longer(
    wide, cols = dplyr::all_of(got),
    names_to = "variable", values_to = "value"
  )
  long <- dplyr::inner_join(long, ann, by = "variable",
                            relationship = "many-to-many")

  tibble::tibble(
    unit_level     = "country",
    unit_code      = long$country_code,
    unit_name      = if ("country_name" %in% names(long)) long$country_name else NA_character_,
    year           = if ("year" %in% names(long)) as.integer(long$year) else NA_integer_,
    cluster        = long$cluster,
    subcluster     = long$subcluster,
    sub_subcluster = long$sub_subcluster,
    leaf           = long$leaf,
    indicator      = long$indicator,
    variable       = long$variable,
    value          = long$value
  )
}

# ============================================================================
# CGJR crosswalk / taxonomy: structural schema check (cliaretl-free)
# ============================================================================
# The CGJR taxonomy is defined by two hand-edited CSVs read at build time:
#   data-raw/input/cgjr_taxonomy.csv    one row per LEAF node
#   data-raw/input/cgjr_crosswalk.csv   one row per (indicator x leaf)
#
# A malformed CSV can still parse into a well-typed tibble, so the *shape* of
# the pair has to be asserted explicitly. check_crosswalk_schema() does that
# and nothing else - whether a resolved `variable` code is actually eligible
# for a CTF panel is a separate, cliaretl-dependent question answered by
# validate_crosswalk() (see R/eligibility.R).

#' Check the structural integrity of the CGJR crosswalk and taxonomy
#'
#' A `cliaretl`-free sanity check on the two hand-edited tables
#' (`cgjr_crosswalk` and `cgjr_taxonomy`, read from `data-raw/input/*.csv` at
#' build time). Run it in `data-raw/source/00b-cgjr-taxonomy-crosswalk.R`
#' immediately after reading the CSVs and before [validate_crosswalk()].
#'
#' All violations are collected and reported together in a single `stop()`
#' (the check never fails on the first problem). The checks are:
#'
#' \enumerate{
#'   \item Both tables carry their required columns.
#'   \item No `NA` in the crosswalk's structural columns (`cluster`,
#'     `subcluster`, `indicator_num`, `indicator`). `sub_subcluster`,
#'     `variable` and `note` are legitimately blank.
#'   \item Every `(cluster, subcluster, sub_subcluster)` combination in the
#'     crosswalk exists as a leaf row in the taxonomy.
#'   \item Taxonomy leaf keys `(cluster, subcluster, sub_subcluster)` are
#'     unique - one row per leaf.
#'   \item The derived `leaf` key, `dplyr::coalesce(sub_subcluster,
#'     subcluster)`, is unique across the taxonomy. The tidy build uses bare
#'     `leaf` as a join key, so no `subcluster` key may collide with a
#'     `sub_subcluster` key.
#'   \item `indicator_num` is unique within each leaf.
#'   \item `indicator` is unique within each leaf. Together with (6) this
#'     guarantees a 1:1 `indicator_num` <-> `indicator` mapping within every
#'     leaf.
#'   \item Each non-`NA` `variable` appears at most once within a leaf.
#' }
#'
#' @param crosswalk The indicator crosswalk. Defaults to `cgjr_crosswalk`.
#' @param taxonomy The leaf-node taxonomy. Defaults to `cgjr_taxonomy`.
#'
#' @return Invisibly, `crosswalk`. Errors on the full batch of violations
#'   found.
#'
#' @seealso [validate_crosswalk()] and [classify_crosswalk()] for the
#'   `cliaretl`-dependent eligibility classification.
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' check_crosswalk_schema(cgjr_crosswalk, cgjr_taxonomy)
#' }
#'
#' @export
check_crosswalk_schema <- function(crosswalk = cgjr_crosswalk,
                                   taxonomy  = cgjr_taxonomy) {
  stopifnot(is.data.frame(crosswalk), is.data.frame(taxonomy))

  problems <- character(0)

  xw_req <- c("cluster", "subcluster", "sub_subcluster", "indicator_num",
              "indicator", "source", "variable", "note")
  tx_req <- c("cluster", "cluster_num", "cluster_name",
              "subcluster", "subcluster_num", "subcluster_name",
              "sub_subcluster", "sub_subcluster_num", "sub_subcluster_name")

  # --- 1. required columns ------------------------------------------------
  xw_missing <- setdiff(xw_req, names(crosswalk))
  tx_missing <- setdiff(tx_req, names(taxonomy))
  if (length(xw_missing)) {
    problems <- c(problems, paste0(
      "crosswalk is missing column(s): ", paste(xw_missing, collapse = ", ")))
  }
  if (length(tx_missing)) {
    problems <- c(problems, paste0(
      "taxonomy is missing column(s): ", paste(tx_missing, collapse = ", ")))
  }

  # Full leaf path, NA sub_subcluster rendered as "" (\r cannot occur in a
  # snake_case key, so it is a safe separator).
  leaf_path <- function(df) {
    paste(df$cluster, df$subcluster,
          ifelse(is.na(df$sub_subcluster), "", df$sub_subcluster),
          sep = "\r")
  }
  show_path <- function(x) gsub("\r", " > ", x)

  # Everything below assumes the crosswalk's required columns exist.
  if (length(xw_missing) == 0L) {

    # --- 2. no NA in structural columns ---------------------------------
    for (col in c("cluster", "subcluster", "indicator_num", "indicator")) {
      n_na <- sum(is.na(crosswalk[[col]]))
      if (n_na > 0L) {
        problems <- c(problems, paste0(
          n_na, " crosswalk row(s) have NA `", col, "`"))
      }
    }

    # --- 3-5. checks that also need the taxonomy columns ---------------
    if (length(tx_missing) == 0L) {

      # 3. every crosswalk leaf path is a taxonomy leaf
      orphans <- setdiff(unique(leaf_path(crosswalk)), unique(leaf_path(taxonomy)))
      if (length(orphans)) {
        problems <- c(problems, paste0(
          length(orphans), " crosswalk leaf path(s) not found in taxonomy: ",
          paste(show_path(orphans), collapse = "; ")))
      }

      # 4. taxonomy leaf keys unique
      tx_key <- leaf_path(taxonomy)
      dup_tx <- unique(tx_key[duplicated(tx_key)])
      if (length(dup_tx)) {
        problems <- c(problems, paste0(
          "taxonomy has duplicate leaf key(s): ",
          paste(show_path(dup_tx), collapse = "; ")))
      }

      # 5. derived `leaf` = coalesce(sub_subcluster, subcluster) unique
      leaf_derived <- ifelse(is.na(taxonomy$sub_subcluster),
                             taxonomy$subcluster, taxonomy$sub_subcluster)
      dup_leaf <- unique(leaf_derived[duplicated(leaf_derived)])
      if (length(dup_leaf)) {
        problems <- c(problems, paste0(
          "derived `leaf` key coalesce(sub_subcluster, subcluster) is not ",
          "unique in the taxonomy: ", paste(dup_leaf, collapse = "; ")))
      }
    }

    # --- 6-8. within-leaf uniqueness ----------------------------------
    xw_key <- leaf_path(crosswalk)
    dup_within_leaf <- function(values, drop_na = FALSE) {
      flags <- tapply(seq_along(values), xw_key, function(idx) {
        v <- values[idx]
        if (drop_na) v <- v[!is.na(v)]
        any(duplicated(v))
      })
      names(which(unlist(flags)))
    }

    for (spec in list(
      list(col = "indicator_num", drop_na = FALSE),
      list(col = "indicator",     drop_na = FALSE),
      list(col = "variable",      drop_na = TRUE)
    )) {
      hit <- dup_within_leaf(crosswalk[[spec$col]], drop_na = spec$drop_na)
      if (length(hit)) {
        problems <- c(problems, paste0(
          "duplicate `", spec$col, "` within leaf(s): ",
          paste(show_path(hit), collapse = "; ")))
      }
    }
  }

  if (length(problems)) {
    stop("check_crosswalk_schema(): ", length(problems), " problem(s):\n",
         paste0("  - ", problems, collapse = "\n"), call. = FALSE)
  }
  invisible(crosswalk)
}

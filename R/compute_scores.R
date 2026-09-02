# ============================================================================
# Score computation helpers
# ============================================================================

#' Add subcluster score columns to a CTF dynamic tibble
#'
#' Given a single subcluster tibble from `ctfdata_list`, computes a row-mean
#' score across all numeric indicator columns (i.e. everything that is not an
#' identifier column) and appends three new columns:
#'
#' \describe{
#'   \item{`score`}{Row mean of all numeric indicator columns, with
#'     `na.rm = TRUE` so partially-observed rows still receive a score.}
#'   \item{`var_count`}{Total number of indicator columns in this subcluster
#'     (constant for every row).}
#'   \item{`nonna_count`}{Number of non-`NA` indicator values used to compute
#'     `score` for each row.}
#' }
#'
#' Identifier columns (`country_code`, `country_name`, `year`) are never
#' treated as indicators, regardless of their class.
#'
#' @param tbl A tibble — one element of `ctfdata_list[[cluster]][[subcluster]]`.
#' @param id_cols Character vector of column names to treat as identifiers
#'   (excluded from scoring). Defaults to `c("country_code", "country_name",
#'   "year")`.
#'
#' @return The input tibble with three additional columns: `score`,
#'   `var_count`, and `nonna_count`.
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' scored <- add_subcluster_score(ctfdata_list$institutional_environment$degree_of_integrity)
#' }
#'
#' @export
add_subcluster_score <- function(tbl,
                                 id_cols = c("country_code", "country_name", "year")) {
  stopifnot(is.data.frame(tbl))

  indicator_cols <- setdiff(names(tbl), id_cols)

  if (length(indicator_cols) == 0L || nrow(tbl) == 0L) {
    tbl$score       <- rep(NA_real_, nrow(tbl))
    tbl$var_count   <- rep(length(indicator_cols), nrow(tbl))
    tbl$nonna_count <- rep(0L, nrow(tbl))
    return(tbl)
  }

  mat <- as.matrix(tbl[indicator_cols])

  tbl$score       <- rowMeans(mat, na.rm = TRUE)
  tbl$var_count   <- length(indicator_cols)
  tbl$nonna_count <- rowSums(!is.na(mat))

  # rowMeans returns NaN when ALL values are NA; coerce to NA
  tbl$score[is.nan(tbl$score)] <- NA_real_

  tbl
}


#' Enrich all leaf tibbles in a ctfdata_list with score columns
#'
#' Applies [add_subcluster_score()] to every leaf tibble in a nested
#' `ctfdata_list`, returning the same nested-list structure with `score`,
#' `var_count`, and `nonna_count` appended to each tibble.
#'
#' Nesting depth is arbitrary: two levels
#' (`list[[cluster]][[subcluster]]`) for most of the taxonomy, three
#' (`list[[cluster]][[subcluster]][[sub_subcluster]]`) for Public Financial
#' Management. A leaf is any `data.frame`; everything else is a container that
#' is recursed into.
#'
#' @param ctfdata_list A named nested list whose leaves are tibbles.
#' @param id_cols Passed through to [add_subcluster_score()].
#'
#' @return The input list with all leaf tibbles enriched with score columns.
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' ctfdata_list <- score_ctfdata_list(ctfdata_list)
#' }
#'
#' @export
score_ctfdata_list <- function(ctfdata_list,
                               id_cols = c("country_code", "country_name", "year")) {
  stopifnot(is.list(ctfdata_list), !is.data.frame(ctfdata_list))

  .cgjr_map_leaves(ctfdata_list, function(tbl) {
    add_subcluster_score(tbl, id_cols = id_cols)
  })
}


#' Compute cluster and overall averages from a scored ctfdata_list
#'
#' Takes a `ctfdata_list` that has already been enriched by
#' [score_ctfdata_list()] (i.e. every leaf tibble has a `score` column) and
#' computes:
#'
#' * One score per **cluster** (top-level list element) per
#'   `country_code x country_name x year`, defined recursively as the mean of
#'   its immediate children's scores — equal weight per child at every level.
#'   For a plain two-level cluster this is the mean of its subcluster scores;
#'   for Public Financial Management it is the mean of its sub-subcluster
#'   scores, each of which is itself a row-mean of that sub-subcluster's
#'   indicators.
#' * One `overall_score` per `country_code x country_name x year`, defined as
#'   the mean of the cluster scores (`na.rm = TRUE`).
#'
#' Empty leaves (zero-row tibbles) contribute nothing to the joins, so a
#' "coming soon" subcluster neither inflates nor deflates its cluster score.
#'
#' @param ctfdata_list A scored nested list (output of [score_ctfdata_list()]).
#'   Nesting depth may vary between clusters.
#' @param id_cols Character vector of identifier columns. Defaults to
#'   `c("country_code", "country_name", "year")`.
#'
#' @return A tibble with one row per `country_code x country_name x year`,
#'   an `<cluster>_score` column for each top-level list element, and an
#'   `overall_score` column (mean of the cluster scores, `na.rm = TRUE`).
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' ctfdata_list <- score_ctfdata_list(ctfdata_list)
#' institutional_averages_tbl <- compute_cluster_averages(ctfdata_list)
#' }
#'
#' @export
compute_cluster_averages <- function(ctfdata_list,
                                     id_cols = c("country_code", "country_name", "year")) {
  stopifnot(is.list(ctfdata_list), !is.data.frame(ctfdata_list))

  cluster_names <- names(ctfdata_list)
  if (is.null(cluster_names) || any(cluster_names == "")) {
    stop("`ctfdata_list` must be a fully named list.")
  }

  row_mean_na <- function(mat) {
    v <- rowMeans(mat, na.rm = TRUE)
    v[is.nan(v)] <- NA_real_
    v
  }

  # Recursively reduce a node to an id_cols + `score` tibble.
  node_score_tbl <- function(node, label) {
    if (is.data.frame(node)) {
      if (!"score" %in% names(node)) {
        stop("Leaf '", label, "' does not have a `score` column. ",
             "Run score_ctfdata_list() first.")
      }
      return(dplyr::as_tibble(node[c(id_cols, "score")]))
    }
    stopifnot(is.list(node))
    child_nm <- names(node)
    if (is.null(child_nm) || any(child_nm == "")) {
      stop("Node '", label, "' must be a fully named list.")
    }
    child_tbls <- Map(function(child, nm) {
      t <- node_score_tbl(child, paste0(label, " > ", nm))
      names(t)[names(t) == "score"] <- nm
      t
    }, node, child_nm)

    joined <- Reduce(
      function(x, y) dplyr::full_join(x, y, by = id_cols),
      child_tbls
    )
    sc_cols <- setdiff(names(joined), id_cols)
    joined$score <- row_mean_na(as.matrix(joined[sc_cols]))
    dplyr::as_tibble(joined[c(id_cols, "score")])
  }

  cluster_tbls <- Map(function(node, nm) {
    t <- node_score_tbl(node, nm)
    names(t)[names(t) == "score"] <- paste0(nm, "_score")
    t
  }, ctfdata_list, cluster_names)

  result <- Reduce(
    function(x, y) dplyr::full_join(x, y, by = id_cols),
    cluster_tbls
  )

  cluster_score_cols <- intersect(paste0(cluster_names, "_score"), names(result))
  result[["overall_score"]] <- row_mean_na(as.matrix(result[cluster_score_cols]))

  result <- dplyr::as_tibble(result)
  dplyr::arrange(result, country_code, year)
}

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

  if (length(indicator_cols) == 0L) {
    tbl$score       <- NA_real_
    tbl$var_count   <- 0L
    tbl$nonna_count <- 0L
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


#' Enrich all subclusters in a ctfdata_list with score columns
#'
#' Applies [add_subcluster_score()] to every subcluster tibble in a nested
#' `ctfdata_list`, returning the same nested-list structure with `score`,
#' `var_count`, and `nonna_count` appended to each tibble.
#'
#' @param ctfdata_list A named nested list structured as
#'   `list[[cluster]][[subcluster]]`, where each leaf is a tibble.
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
  stopifnot(is.list(ctfdata_list))

  lapply(ctfdata_list, function(cluster) {
    stopifnot(is.list(cluster))
    lapply(cluster, function(subcluster) {
      add_subcluster_score(subcluster, id_cols = id_cols)
    })
  })
}


#' Compute cluster and overall averages from a scored ctfdata_list
#'
#' Takes a `ctfdata_list` that has already been enriched by
#' [score_ctfdata_list()] (i.e. each subcluster tibble has a `score` column)
#' and computes:
#'
#' * One score per cluster per `country_code × country_name × year`, defined
#'   as the **mean of the subcluster scores** (Option A — equal weight per
#'   subcluster regardless of how many indicators it contains).
#' * One overall score per `country_code × country_name × year`, defined as
#'   the mean of the four cluster scores (`na.rm = TRUE`).
#'
#' @param ctfdata_list A scored nested list (output of [score_ctfdata_list()]).
#' @param id_cols Character vector of identifier columns. Defaults to
#'   `c("country_code", "country_name", "year")`.
#'
#' @return A tibble with one row per `country_code × country_name × year` and
#'   the following columns:
#'   \describe{
#'     \item{`country_code`}{ISO 3-letter country code.}
#'     \item{`country_name`}{Country name.}
#'     \item{`year`}{Calendar year.}
#'     \item{`institutional_environment_score`}{Mean of subcluster scores
#'       within the Institutional Environment cluster.}
#'     \item{`political_institutions_score`}{Mean of subcluster scores
#'       within the Political Institutions cluster.}
#'     \item{`center_of_government_score`}{Mean of subcluster scores
#'       within the Center of Government cluster.}
#'     \item{`sectors_service_delivery_score`}{Mean of subcluster scores
#'       within the Sectors / Service Delivery cluster.}
#'     \item{`overall_score`}{Mean of the four cluster scores per row
#'       (`na.rm = TRUE`).}
#'   }
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
  stopifnot(is.list(ctfdata_list))

  cluster_names <- names(ctfdata_list)
  if (is.null(cluster_names)) {
    stop("`ctfdata_list` must be a named list.")
  }

  # Helper: compute mean-of-subcluster-scores for one cluster
  cluster_score_tbl <- function(cluster_list, cluster_nm) {
    stopifnot(is.list(cluster_list))

    # Bind all subcluster score columns together on id cols
    # Each subcluster contributes exactly its `score` column
    subcluster_tbls <- lapply(names(cluster_list), function(sc_nm) {
      sc_tbl <- cluster_list[[sc_nm]]
      if (!"score" %in% names(sc_tbl)) {
        stop(
          "Subcluster '", sc_nm, "' in cluster '", cluster_nm,
          "' does not have a `score` column. ",
          "Run score_ctfdata_list() first."
        )
      }
      # Rename score to the subcluster name so we can average across them
      out <- sc_tbl[c(id_cols, "score")]
      names(out)[names(out) == "score"] <- sc_nm
      out
    })

    # Full-join all subclusters on id_cols
    joined <- Reduce(
      function(x, y) merge(x, y, by = id_cols, all = TRUE),
      subcluster_tbls
    )

    # Mean of subcluster columns (equal weight per subcluster)
    sc_cols  <- setdiff(names(joined), id_cols)
    score_nm <- paste0(cluster_nm, "_score")
    mat <- as.matrix(joined[sc_cols])
    joined[[score_nm]] <- rowMeans(mat, na.rm = TRUE)
    joined[[score_nm]][is.nan(joined[[score_nm]])] <- NA_real_

    # Return only id cols + cluster score
    joined[c(id_cols, score_nm)]
  }

  # Compute per-cluster score tables
  cluster_tbls <- lapply(cluster_names, function(nm) {
    cluster_score_tbl(ctfdata_list[[nm]], nm)
  })

  # Full-join all cluster score tables
  result <- Reduce(
    function(x, y) merge(x, y, by = id_cols, all = TRUE),
    cluster_tbls
  )

  # Overall score = mean of the four cluster score columns
  cluster_score_cols <- paste0(cluster_names, "_score")
  avail_cluster_cols <- intersect(cluster_score_cols, names(result))
  mat_cluster <- as.matrix(result[avail_cluster_cols])
  result[["overall_score"]] <- rowMeans(mat_cluster, na.rm = TRUE)
  result[["overall_score"]][is.nan(result[["overall_score"]])] <- NA_real_

  # Return as tibble, sorted
  result <- dplyr::as_tibble(result)
  result <- dplyr::arrange(result, country_code, year)
  result
}

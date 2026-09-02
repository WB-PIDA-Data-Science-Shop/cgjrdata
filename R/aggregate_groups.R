# ============================================================================
# Group aggregation helpers
# ============================================================================

#' Join World Bank country classifications onto a leaf tibble
#'
#' Performs a `left_join` of `region`, `region_code`, and `income_group` from
#' `wbcountries` onto a single subcluster tibble, matching on `country_code`.
#' Rows whose `country_code` does not appear in `wbcountries` (e.g. World Bank
#' aggregate codes such as `"WLD"`, `"SSA"`) receive `NA` in the three new
#' columns.
#'
#' @param tbl A tibble with at least a `country_code` column.
#' @param wbcountries The `wbcountries` classification tibble (must contain
#'   `country_code`, `region`, `region_code`, `income_group`).
#'
#' @return `tbl` with three additional columns: `region`, `region_code`,
#'   `income_group`.
#'
#' @keywords internal
#' @noRd
join_wb_classifications <- function(tbl, wbcountries) {
  cls <- wbcountries[c("country_code", "region", "region_code", "income_group")]
  dplyr::left_join(tbl, cls, by = "country_code")
}


#' Aggregate a single subcluster tibble to group-level averages
#'
#' Given a leaf tibble (one subcluster from `ctfdata_list` or `rawdata_list`)
#' that already has classification columns attached (via
#' `join_wb_classifications()`), this function:
#'
#' 1. Drops `country_code`, `country_name`, and — if present — `score`,
#'    `var_count`, `nonna_count` (CTF scoring artefacts that should not be
#'    carried forward).
#' 2. Removes rows where any element of `group_cols` is `NA` (i.e. WB
#'    aggregate codes that did not match `wbcountries`).
#' 3. Groups by `c(group_cols, "year")` and computes the column-wise mean of
#'    every remaining numeric column (`na.rm = TRUE`).
#' 4. Recomputes a `score` column as the row mean of the averaged indicator
#'    columns (`na.rm = TRUE`), with `NaN` coerced to `NA`.
#'
#' @param tbl A tibble with classification columns already joined.
#' @param group_cols Character vector of grouping column names (e.g.
#'   `c("region", "region_code")` or `"income_group"`).
#' @param id_cols Character vector of country-level identifier columns to drop
#'   before aggregating. Defaults to `c("country_code", "country_name")`.
#' @param score_drop Character vector of scoring artefact columns to drop
#'   before computing group means. Defaults to
#'   `c("score", "var_count", "nonna_count")`.
#'
#' @return A tibble with one row per unique `group_cols × year` combination,
#'   columns for the group identifiers, `year`, group-mean indicator columns,
#'   and a recomputed `score`.
#'
#' @keywords internal
#' @noRd
aggregate_tbl_by_group <- function(
    tbl,
    group_cols,
    id_cols    = c("country_code", "country_name"),
    score_drop = c("score", "var_count", "nonna_count")) {

  # Drop country-level identifiers and CTF scoring artefacts
  drop_cols <- intersect(names(tbl), c(id_cols, score_drop))
  tbl <- tbl[, setdiff(names(tbl), drop_cols), drop = FALSE]

  # Empty leaf (e.g. a "coming soon" subcluster): return an empty but
  # correctly-shaped tibble rather than erroring.
  if (nrow(tbl) == 0L) {
    shell <- tbl[, intersect(names(tbl), c(group_cols, "year")), drop = FALSE]
    for (gc in setdiff(c(group_cols, "year"), names(shell))) shell[[gc]] <- character(0)
    shell[["score"]] <- numeric(0)
    return(dplyr::as_tibble(shell))
  }

  # Remove rows where any group column is NA (WB aggregate codes)
  for (gc in group_cols) {
    tbl <- tbl[!is.na(tbl[[gc]]), , drop = FALSE]
  }

  # Group by group_cols + year, average all numeric indicator columns
  group_syms <- c(group_cols, "year")
  result <- tbl |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_syms))) |>
    dplyr::summarise(
      dplyr::across(where(is.numeric), \(x) mean(x, na.rm = TRUE)),
      .groups = "drop"
    )

  # Recompute score as row mean of the averaged indicator columns
  indicator_cols <- setdiff(names(result), group_syms)
  if (length(indicator_cols) > 0L) {
    mat <- as.matrix(result[indicator_cols])
    result[["score"]] <- rowMeans(mat, na.rm = TRUE)
    result[["score"]][is.nan(result[["score"]])] <- NA_real_
  } else {
    result[["score"]] <- NA_real_
  }

  dplyr::arrange(result, dplyr::across(dplyr::all_of(group_syms)))
}


#' Aggregate a nested data list to region or income-group averages
#'
#' Takes a nested list (either `ctfdata_list` or `rawdata_list`) and produces
#' a parallel list of the same shape where each country-level leaf tibble has
#' been replaced by a group-average tibble. Nesting depth is arbitrary — a
#' leaf is any `data.frame`, and the three-level Public Financial Management
#' branch is handled the same way as the two-level subclusters.
#'
#' **Aggregation logic (per subcluster):**
#'
#' 1. World Bank classifications (`region`, `region_code`, `income_group`) are
#'    joined onto each leaf tibble via `country_code`.
#' 2. Rows for WB aggregate codes (e.g. `"WLD"`, `"SSA"`) that do not match
#'    any row in `wbcountries` are **dropped**.
#' 3. The leaf is grouped by `c(group_cols, "year")` and all numeric indicator
#'    columns are averaged (`na.rm = TRUE`).
#' 4. A `score` column is recomputed as the row mean of the resulting
#'    averaged indicator columns (`na.rm = TRUE`). If the input was already a
#'    scored `ctfdata_list`, the old `score`, `var_count`, and `nonna_count`
#'    columns are dropped before averaging so they do not contaminate the
#'    indicator means.
#'
#' @param data_list A named nested list (`list[[cluster]][[subcluster]]`) where
#'   each leaf is a tibble with at least `country_code` and `year` columns.
#'   Both `ctfdata_list` and `rawdata_list` are acceptable inputs.
#' @param group_col One of `"region"` or `"income_group"`. Controls both the
#'   grouping variable and which identifier columns appear in the output:
#'   \describe{
#'     \item{`"region"`}{Groups by `region` + `region_code`; output contains
#'       both as identifier columns.}
#'     \item{`"income_group"`}{Groups by `income_group` alone.}
#'   }
#' @param wbcountries The `wbcountries` classification tibble exported by this
#'   package. Must contain `country_code`, `region`, `region_code`,
#'   `income_group`.
#'
#' @return A named nested list with the same cluster/subcluster structure as
#'   `data_list`. Each leaf tibble has group-identifier columns, `year`,
#'   group-mean indicator columns, and a recomputed `score` column.
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' regionctf_list    <- aggregate_data_list(ctfdata_list, "region",       wbcountries)
#' incomectf_list    <- aggregate_data_list(ctfdata_list, "income_group", wbcountries)
#' regionrawdata_list  <- aggregate_data_list(rawdata_list, "region",       wbcountries)
#' incomerawdata_list  <- aggregate_data_list(rawdata_list, "income_group", wbcountries)
#' }
#'
#' @importFrom dplyr where
#' @export
aggregate_data_list <- function(data_list, group_col, wbcountries) {
  stopifnot(is.list(data_list), !is.data.frame(data_list))
  stopifnot(
    is.character(group_col), length(group_col) == 1L,
    group_col %in% c("region", "income_group")
  )
  stopifnot(is.data.frame(wbcountries))

  group_cols <- if (group_col == "region") {
    c("region", "region_code")
  } else {
    "income_group"
  }

  .cgjr_map_leaves(data_list, function(leaf) {
    enriched <- join_wb_classifications(leaf, wbcountries)
    aggregate_tbl_by_group(enriched, group_cols = group_cols)
  })
}

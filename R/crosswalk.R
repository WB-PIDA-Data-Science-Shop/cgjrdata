# ============================================================================
# CGJR crosswalk: assemble the annotated cgjr_crosswalk
# ============================================================================
# build_crosswalk() takes the hand-edited crosswalk CSV (already read and
# schema-checked) and annotates every row with:
#   - the derived `leaf` key
#   - taxonomy numbers / names (join to cgjr_taxonomy)
#   - cliaretl catalogue metadata (join to db_variables_final)
#   - the eligibility flags from classify_crosswalk()
#
# It absorbs what used to be a separate `metadata_tbl`: the annotated
# cgjr_crosswalk is now the single per-(indicator x leaf) reference object.

#' Derive the `leaf` key for a crosswalk / taxonomy row
#'
#' A leaf node is identified by its `sub_subcluster` key where it has one
#' (only the Public Financial Management branch does), otherwise by its
#' `subcluster` key. `check_crosswalk_schema()` guarantees the result is
#' unique across the taxonomy, so `leaf` is a valid standalone join key for
#' the tidy build (`build_ctf_tbl()`, `build_raw_tbl()`, `roll_up_scores()`).
#'
#' @param sub_subcluster,subcluster Character vectors of equal length
#'   (e.g. `crosswalk$sub_subcluster`, `crosswalk$subcluster`).
#'
#' @return A character vector: `sub_subcluster` where non-`NA`, else
#'   `subcluster`.
#'
#' @examples
#' resolve_leaf(c(NA, "public_procurement"), c("digital_and_data", "public_financial_management"))
#'
#' @export
resolve_leaf <- function(sub_subcluster, subcluster) {
  dplyr::coalesce(sub_subcluster, subcluster)
}


#' Assemble the annotated CGJR crosswalk
#'
#' Takes the hand-edited crosswalk table (read from
#' `data-raw/input/cgjr_crosswalk.csv` and passed through
#' [check_crosswalk_schema()]) and returns the annotated `cgjr_crosswalk`
#' package object: one row per `(indicator x leaf)`, every CSV row kept
#' (including unresolved ones), with taxonomy metadata, `cliaretl` catalogue
#' metadata, and the [classify_crosswalk()] eligibility flags joined on.
#'
#' Rows whose `variable` is `NA` or not a `cliaretl` code keep `NA` in every
#' catalogue-metadata column; their flag columns are still populated
#' (`cliaretl_status` will be `"unresolved"` / `"not_in_cliaretl"`).
#'
#' @param crosswalk The crosswalk tibble (CSV columns `cluster`, `subcluster`,
#'   `sub_subcluster`, `indicator_num`, `indicator`, `source`, `variable`,
#'   `note`).
#' @param taxonomy The leaf-node taxonomy. Defaults to `cgjr_taxonomy`.
#' @param catalogue The `cliaretl` variable catalogue. Defaults to
#'   [cliaretl::db_variables_final].
#' @param ctf_dynamic,ctf_static The dynamic and static Closeness-to-Frontier
#'   panels, passed to [classify_crosswalk()]. Default to the `cliaretl`
#'   objects.
#'
#' @return A tibble - the annotated `cgjr_crosswalk`.
#'
#' @seealso [check_crosswalk_schema()], [classify_crosswalk()],
#'   [validate_crosswalk()], [resolve_leaf()]
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' cgjr_crosswalk <- build_crosswalk(crosswalk_csv, cgjr_taxonomy)
#' }
#'
#' @export
build_crosswalk <- function(crosswalk,
                            taxonomy    = cgjr_taxonomy,
                            catalogue   = cliaretl::db_variables_final,
                            ctf_dynamic = cliaretl::closeness_to_frontier_dynamic,
                            ctf_static  = cliaretl::closeness_to_frontier_static) {
  stopifnot(is.data.frame(crosswalk), is.data.frame(taxonomy),
            is.data.frame(catalogue))

  # --- 1. derived leaf key --------------------------------------------------
  crosswalk$leaf <- resolve_leaf(crosswalk$sub_subcluster, crosswalk$subcluster)

  # --- 2. taxonomy numbers / names ---------------------------------------
  tax_meta_cols <- c("cluster_num", "cluster_name",
                     "subcluster_num", "subcluster_name",
                     "sub_subcluster_num", "sub_subcluster_name")
  tax_meta <- taxonomy[, c("cluster", "subcluster", "sub_subcluster",
                           intersect(tax_meta_cols, names(taxonomy))),
                        drop = FALSE]
  out <- dplyr::left_join(
    crosswalk, tax_meta,
    by = c("cluster", "subcluster", "sub_subcluster"),
    relationship = "many-to-one"
  )

  # --- 3. cliaretl catalogue metadata ----------------------------------
  cat_meta_cols <- c("var_name", "var_level", "family_var", "family_name",
                     "family_order", "processing", "description",
                     "description_short", "etl_source", "benchmarked_ctf",
                     "benchmark_dynamic_indicator",
                     "benchmark_dynamic_family_aggregate",
                     "benchmark_static_family_aggregate_download")
  cat_meta <- catalogue[!is.na(catalogue$variable),
                        c("variable", intersect(cat_meta_cols, names(catalogue))),
                        drop = FALSE]
  cat_meta <- cat_meta[!duplicated(cat_meta$variable), , drop = FALSE]
  out <- dplyr::left_join(out, cat_meta, by = "variable",
                          relationship = "many-to-one")

  # --- 4. eligibility flags -------------------------------------------
  flag_cols <- c("in_cliaretl", "in_dynamic_panel", "in_static_panel",
                 "dynamic_eligible", "static_eligible", "cliaretl_status")
  flags <- classify_crosswalk(crosswalk, catalogue, ctf_dynamic, ctf_static)
  stopifnot(nrow(flags) == nrow(out))
  out <- dplyr::bind_cols(out, flags[, flag_cols, drop = FALSE])

  # --- 5. column order --------------------------------------------------
  col_order <- c(
    "cluster", "subcluster", "sub_subcluster", "leaf",
    "indicator_num", "indicator", "source", "variable", "note",
    tax_meta_cols,
    intersect(cat_meta_cols, names(out)),
    flag_cols
  )
  missing <- setdiff(col_order, names(out))
  if (length(missing)) {
    stop("build_crosswalk(): assembled table is missing expected column(s): ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  extra <- setdiff(names(out), col_order)
  tibble::as_tibble(out[, c(col_order, extra), drop = FALSE])
}

# ============================================================================
# CGJR taxonomy crosswalk: validation + generic data-list builders
# ============================================================================
# The new CGJR taxonomy is defined entirely by two data objects,
# `cgjr_taxonomy` (leaf nodes) and `cgjr_crosswalk` (indicator -> leaf
# assignments). These functions validate the crosswalk against `cliaretl`'s
# own eligibility flags and build the nested `rawdata_list` / `ctfdata_list`
# objects from it, replacing the retired per-subcluster scripts.

# ---------------------------------------------------------------------------
# Internal: nested-list helpers (arbitrary depth)
# ---------------------------------------------------------------------------

# A "leaf" is a data frame; a "node" is a named list of leaves and/or nodes.

#' @keywords internal
#' @noRd
.cgjr_map_leaves <- function(x, f) {
  if (is.data.frame(x)) return(f(x))
  stopifnot(is.list(x))
  out <- lapply(x, .cgjr_map_leaves, f = f)
  names(out) <- names(x)
  out
}

# Assign `value` at the nested `path` (character vector), creating
# intermediate named lists as needed. Insertion order is preserved.
#' @keywords internal
#' @noRd
.cgjr_assign <- function(lst, path, value) {
  if (length(path) == 1L) {
    lst[[path]] <- value
    return(lst)
  }
  if (is.null(lst[[path[1L]]])) lst[[path[1L]]] <- list()
  lst[[path[1L]]] <- .cgjr_assign(lst[[path[1L]]], path[-1L], value)
  lst
}

# Path (cluster -> subcluster -> [sub_subcluster]) for one taxonomy row.
#' @keywords internal
#' @noRd
.cgjr_leaf_path <- function(row) {
  p <- c(row$cluster, row$subcluster)
  if (!is.na(row$sub_subcluster)) p <- c(p, row$sub_subcluster)
  p
}

# Crosswalk rows belonging to one taxonomy leaf.
#' @keywords internal
#' @noRd
.cgjr_leaf_rows <- function(crosswalk, row) {
  same_ss <- if (is.na(row$sub_subcluster)) {
    is.na(crosswalk$sub_subcluster)
  } else {
    !is.na(crosswalk$sub_subcluster) & crosswalk$sub_subcluster == row$sub_subcluster
  }
  crosswalk[crosswalk$cluster == row$cluster &
              crosswalk$subcluster == row$subcluster &
              same_ss, , drop = FALSE]
}


# ---------------------------------------------------------------------------
# validate_crosswalk()
# ---------------------------------------------------------------------------

# Classify crosswalk rows without emitting a warning (shared by
# validate_crosswalk() and the builders). Returns the classification tibble.
.cgjr_classify_crosswalk <- function(crosswalk, catalogue, ctf_dynamic) {
  stopifnot(is.data.frame(crosswalk))
  req <- c("variable", "cluster", "subcluster", "sub_subcluster", "indicator")
  miss <- setdiff(req, names(crosswalk))
  if (length(miss)) {
    stop("`crosswalk` is missing required column(s): ", paste(miss, collapse = ", "))
  }

  cat_tbl  <- catalogue[!is.na(catalogue$variable), , drop = FALSE]
  m        <- match(crosswalk$variable, cat_tbl$variable)
  dyn_cols <- names(ctf_dynamic)

  out <- tibble::tibble(
    variable       = crosswalk$variable,
    cluster        = crosswalk$cluster,
    subcluster     = crosswalk$subcluster,
    sub_subcluster = crosswalk$sub_subcluster,
    indicator      = crosswalk$indicator,
    in_catalogue   = !is.na(m),
    in_dynamic_panel = crosswalk$variable %in% dyn_cols,
    benchmark_dynamic_indicator        = cat_tbl$benchmark_dynamic_indicator[m],
    benchmark_dynamic_family_aggregate = cat_tbl$benchmark_dynamic_family_aggregate[m]
  )

  out$check <- ifelse(
    is.na(out$variable), "unresolved",
    ifelse(!out$in_catalogue, "not_in_catalogue",
    ifelse(!out$in_dynamic_panel |
             is.na(out$benchmark_dynamic_indicator) |
             out$benchmark_dynamic_indicator != "Yes", "not_dynamic_eligible",
    ifelse(!out$benchmark_dynamic_family_aggregate %in% c("Yes", "Partial"),
           "not_family_aggregate_eligible", "ok"))))
  out
}

# Emit the standard eligibility warning for a classified crosswalk.
.cgjr_warn_ineligible <- function(classified, fn = "validate_crosswalk") {
  bad <- classified[classified$check != "ok", , drop = FALSE]
  if (nrow(bad) == 0L) return(invisible())
  path <- paste0(
    bad$cluster, " > ", bad$subcluster,
    ifelse(is.na(bad$sub_subcluster), "", paste0(" > ", bad$sub_subcluster))
  )
  lines <- sprintf("  [%s] %s :: %s (%s)",
                   bad$check,
                   ifelse(is.na(bad$variable), "<no variable>", bad$variable),
                   bad$indicator, path)
  warning(fn, "(): ", nrow(bad), " of ", nrow(classified),
          " crosswalk rows failed eligibility checks:\n",
          paste(lines, collapse = "\n"), call. = FALSE)
  invisible()
}

#' Validate the CGJR crosswalk against `cliaretl` eligibility flags
#'
#' Checks every row of a CGJR crosswalk table against
#' [cliaretl::db_variables_final] and
#' [cliaretl::closeness_to_frontier_dynamic], classifying each into one of:
#'
#' \describe{
#'   \item{`"ok"`}{Variable is in the catalogue, is a column of the dynamic
#'     CTF panel, has `benchmark_dynamic_indicator == "Yes"`, and has
#'     `benchmark_dynamic_family_aggregate` in `c("Yes", "Partial")` — safe to
#'     average into a subcluster score.}
#'   \item{`"unresolved"`}{`variable` is `NA` — the taxonomy lists an
#'     indicator but no `cliaretl` code could be confirmed for it.}
#'   \item{`"not_in_catalogue"`}{`variable` is not `NA` but does not appear in
#'     `db_variables_final$variable`.}
#'   \item{`"not_dynamic_eligible"`}{Variable is in the catalogue but is not a
#'     column of `closeness_to_frontier_dynamic`, or is flagged
#'     `benchmark_dynamic_indicator != "Yes"` — it cannot enter the dynamic
#'     panel at all.}
#'   \item{`"not_family_aggregate_eligible"`}{Variable is in the dynamic panel
#'     but `benchmark_dynamic_family_aggregate` is `"No"` — including it in a
#'     subcluster row-mean is not sanctioned by `cliaretl`'s own metadata.}
#' }
#'
#' A `warning` is emitted listing every non-`"ok"` row (variable, path, which
#' check failed). Rows are never silently dropped or silently included — that
#' is the caller's decision, informed by this report.
#'
#' @param crosswalk A crosswalk tibble with at least `variable`, `cluster`,
#'   `subcluster`, `sub_subcluster`, and `indicator` columns (e.g.
#'   `cgjr_crosswalk`).
#' @param catalogue The variable catalogue. Defaults to
#'   [cliaretl::db_variables_final].
#' @param ctf_dynamic The dynamic CTF panel whose columns define
#'   panel membership. Defaults to [cliaretl::closeness_to_frontier_dynamic].
#'
#' @return Invisibly, a tibble with one row per crosswalk row and the columns
#'   `variable`, `cluster`, `subcluster`, `sub_subcluster`, `indicator`,
#'   `in_catalogue`, `in_dynamic_panel`, `benchmark_dynamic_indicator`,
#'   `benchmark_dynamic_family_aggregate`, and `check`.
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
                               ctf_dynamic = cliaretl::closeness_to_frontier_dynamic) {
  out <- .cgjr_classify_crosswalk(crosswalk, catalogue, ctf_dynamic)
  .cgjr_warn_ineligible(out, "validate_crosswalk")
  invisible(out)
}


# ---------------------------------------------------------------------------
# check_crosswalk_schema()
# ---------------------------------------------------------------------------

#' Check the structural integrity of the CGJR crosswalk and taxonomy
#'
#' A `cliaretl`-free sanity check on the two hand-edited tables (`cgjr_crosswalk`
#' and `cgjr_taxonomy`, read from `data-raw/input/*.csv` at build time).
#' Run this immediately after reading the CSVs and before
#' [validate_crosswalk()]: a malformed CSV can still parse into a well-typed
#' data frame, so the shape has to be asserted explicitly.
#'
#' All violations are collected and reported together in a single `stop()`.
#' The checks are:
#'
#' \enumerate{
#'   \item Both tables carry their required columns.
#'   \item No `NA` in the crosswalk's structural columns (`cluster`,
#'     `subcluster`, `indicator_num`, `indicator`).
#'   \item Every `(cluster, subcluster, sub_subcluster)` combination in the
#'     crosswalk exists as a leaf row in the taxonomy.
#'   \item `indicator_num` is unique within each leaf.
#'   \item Each non-`NA` `variable` appears at most once within a leaf.
#'   \item Taxonomy leaf keys are unique.
#' }
#'
#' Whether a resolved `variable` code is actually eligible for the CTF
#' dynamic panel is a separate, `cliaretl`-dependent question answered by
#' [validate_crosswalk()].
#'
#' @param crosswalk The indicator crosswalk (e.g. `cgjr_crosswalk`).
#' @param taxonomy The leaf-node taxonomy (e.g. `cgjr_taxonomy`).
#'
#' @return Invisibly, `crosswalk`. Errors on the first batch of violations
#'   found.
#'
#' @seealso [validate_crosswalk()]
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' check_crosswalk_schema(cgjr_crosswalk, cgjr_taxonomy)
#' }
#'
#' @export
check_crosswalk_schema <- function(crosswalk, taxonomy) {
  stopifnot(is.data.frame(crosswalk), is.data.frame(taxonomy))

  problems <- character(0)
  add <- function(...) problems <<- c(problems, paste0(...))

  xw_req <- c("cluster", "subcluster", "sub_subcluster", "indicator_num",
              "indicator", "source", "variable", "note")
  tx_req <- c("cluster", "cluster_num", "cluster_name",
              "subcluster", "subcluster_num", "subcluster_name",
              "sub_subcluster", "sub_subcluster_num", "sub_subcluster_name")

  xw_missing <- setdiff(xw_req, names(crosswalk))
  tx_missing <- setdiff(tx_req, names(taxonomy))
  if (length(xw_missing)) add("crosswalk is missing column(s): ", paste(xw_missing, collapse = ", "))
  if (length(tx_missing)) add("taxonomy is missing column(s): ",  paste(tx_missing, collapse = ", "))

  # Everything below assumes the required columns exist.
  if (length(xw_missing) == 0L) {
    for (col in c("cluster", "subcluster", "indicator_num", "indicator")) {
      n_na <- sum(is.na(crosswalk[[col]]))
      if (n_na > 0L) add(n_na, " crosswalk row(s) have NA `", col, "`")
    }

    leaf_key <- function(df) {
      paste(df$cluster, df$subcluster,
            ifelse(is.na(df$sub_subcluster), "", df$sub_subcluster),
            sep = "\r")
    }

    if (length(tx_missing) == 0L) {
      orphans <- setdiff(unique(leaf_key(crosswalk)), unique(leaf_key(taxonomy)))
      if (length(orphans)) {
        add(length(orphans), " crosswalk leaf path(s) not found in taxonomy: ",
            paste(gsub("\r", " > ", orphans), collapse = "; "))
      }
      dup_tx <- leaf_key(taxonomy)[duplicated(leaf_key(taxonomy))]
      if (length(dup_tx)) {
        add("taxonomy has duplicate leaf key(s): ",
            paste(unique(gsub("\r", " > ", dup_tx)), collapse = "; "))
      }
    }

    key <- leaf_key(crosswalk)
    dup_num <- tapply(crosswalk$indicator_num, key,
                      function(x) any(duplicated(x)))
    if (any(unlist(dup_num))) {
      add("duplicate indicator_num within leaf(s): ",
          paste(gsub("\r", " > ", names(which(unlist(dup_num)))), collapse = "; "))
    }
    dup_var <- tapply(crosswalk$variable, key,
                      function(x) { x <- x[!is.na(x)]; any(duplicated(x)) })
    if (any(unlist(dup_var))) {
      add("duplicate variable within leaf(s): ",
          paste(gsub("\r", " > ", names(which(unlist(dup_var)))), collapse = "; "))
    }
  }

  if (length(problems)) {
    stop("check_crosswalk_schema(): ", length(problems), " problem(s):\n",
         paste0("  - ", problems, collapse = "\n"), call. = FALSE)
  }
  invisible(crosswalk)
}


# ---------------------------------------------------------------------------
# build_ctfdata_list()
# ---------------------------------------------------------------------------

#' Build the nested CTF dynamic data list from the crosswalk
#'
#' Pulls [cliaretl::closeness_to_frontier_dynamic] once and slices it into the
#' nested taxonomy structure defined by `cgjr_taxonomy` / `cgjr_crosswalk`.
#' The result mirrors the taxonomy's hierarchy: two levels for most
#' subclusters (`list[[cluster]][[subcluster]]`) and three for Public
#' Financial Management (`list[[cluster]][[subcluster]][[sub_subcluster]]`).
#'
#' Only rows that pass [validate_crosswalk()]'s dynamic-panel checks
#' contribute columns: rows with `check == "not_dynamic_eligible"`,
#' `"not_in_catalogue"`, or `"unresolved"` are excluded (their variables are
#' not columns of the panel). Rows flagged `"not_family_aggregate_eligible"`
#' *are* included as columns — they are valid panel columns — but
#' `validate_crosswalk()` warns about them so the caller can decide whether to
#' trust the resulting subcluster score.
#'
#' Leaf nodes with no contributing columns (e.g. PFM's empty sub-subclusters,
#' or a subcluster whose every indicator is dynamic-ineligible) are
#' represented as a zero-row tibble carrying only the identifier columns — a
#' valid, empty structure rather than an error.
#'
#' @param crosswalk Indicator -> leaf crosswalk (default `cgjr_crosswalk`).
#' @param taxonomy Leaf-node taxonomy (default `cgjr_taxonomy`).
#' @param ctf_dynamic The dynamic CTF panel. Defaults to
#'   [cliaretl::closeness_to_frontier_dynamic].
#' @param catalogue Variable catalogue used for the eligibility classification.
#'   Defaults to [cliaretl::db_variables_final].
#' @param id_cols Identifier columns to carry onto every leaf. Defaults to
#'   `c("country_code", "country_name", "year")`.
#' @param validate If `TRUE` (default), emit the [validate_crosswalk()]
#'   eligibility warning during the build.
#'
#' @return A named nested list following the taxonomy hierarchy; each leaf is
#'   a tibble of `id_cols` plus one CTF-scaled column per contributing
#'   indicator.
#'
#' @seealso [build_rawdata_list()], [validate_crosswalk()], [score_ctfdata_list()]
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' ctfdata_list <- build_ctfdata_list()
#' }
#'
#' @export
build_ctfdata_list <- function(crosswalk   = cgjr_crosswalk,
                               taxonomy    = cgjr_taxonomy,
                               ctf_dynamic = cliaretl::closeness_to_frontier_dynamic,
                               catalogue   = cliaretl::db_variables_final,
                               id_cols     = c("country_code", "country_name", "year"),
                               validate    = TRUE) {
  stopifnot(is.data.frame(crosswalk), is.data.frame(taxonomy))

  cls <- .cgjr_classify_crosswalk(crosswalk, catalogue, ctf_dynamic)
  if (validate) .cgjr_warn_ineligible(cls, "build_ctfdata_list")

  # Rows that may contribute a column: in the panel AND flagged
  # benchmark_dynamic_indicator == "Yes". Family-aggregate-ineligible rows
  # are kept (they are valid panel columns) but were warned about above.
  keep_vars <- cls$variable[cls$check %in% c("ok", "not_family_aggregate_eligible")]

  ctf     <- tibble::as_tibble(ctf_dynamic)
  id_cols <- intersect(id_cols, names(ctf))
  empty   <- ctf[0L, id_cols, drop = FALSE]

  out <- list()
  for (i in seq_len(nrow(taxonomy))) {
    row  <- taxonomy[i, , drop = FALSE]
    rows <- .cgjr_leaf_rows(crosswalk, row)
    vars <- intersect(
      unique(stats::na.omit(rows$variable)),
      intersect(keep_vars, names(ctf))
    )
    leaf <- if (length(vars) == 0L) empty else ctf[, c(id_cols, vars), drop = FALSE]
    out  <- .cgjr_assign(out, .cgjr_leaf_path(row), leaf)
  }
  out
}


# ---------------------------------------------------------------------------
# build_rawdata_list()
# ---------------------------------------------------------------------------

#' Build the nested raw source data list from the crosswalk
#'
#' The raw-data counterpart of [build_ctfdata_list()]. For each taxonomy leaf,
#' the assigned variables are fetched from their original source datasets via
#' [extract_cliar_data()] with `type = "raw"` and assembled into the same
#' nested hierarchy.
#'
#' Unlike the dynamic panel, raw coverage is independent of the
#' `benchmark_dynamic_*` flags: a leaf that is empty in `ctfdata_list` (PFM,
#' SOE governance) can still carry raw PEFA / OECD-PMR values here. Leaves
#' whose variables resolve to no raw source are returned as a zero-row tibble
#' with identifier columns only.
#'
#' @inheritParams build_ctfdata_list
#' @param id_cols Identifier columns. Defaults to `c("country_code",
#'   "country_name", "year")`.
#'
#' @return A named nested list following the taxonomy hierarchy; each leaf is
#'   a tibble of identifier columns plus one raw column per resolvable
#'   indicator.
#'
#' @seealso [build_ctfdata_list()], [extract_cliar_data()]
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' rawdata_list <- build_rawdata_list()
#' }
#'
#' @export
build_rawdata_list <- function(crosswalk = cgjr_crosswalk,
                               taxonomy  = cgjr_taxonomy,
                               id_cols   = c("country_code", "country_name", "year"),
                               validate  = FALSE) {
  stopifnot(is.data.frame(crosswalk), is.data.frame(taxonomy))
  if (validate) validate_crosswalk(crosswalk)

  empty <- tibble::tibble(
    country_code = character(0),
    country_name = character(0),
    year         = integer(0)
  )
  empty <- empty[, intersect(id_cols, names(empty)), drop = FALSE]

  out <- list()
  for (i in seq_len(nrow(taxonomy))) {
    row  <- taxonomy[i, , drop = FALSE]
    rows <- .cgjr_leaf_rows(crosswalk, row)
    vars <- unique(stats::na.omit(rows$variable))

    leaf <- empty
    if (length(vars) > 0L) {
      pulled <- tryCatch(
        suppressWarnings(extract_cliar_data(vars, type = "raw", id_vars = id_cols)),
        error = function(e) NULL
      )
      if (!is.null(pulled)) leaf <- tibble::as_tibble(pulled)
    }
    out <- .cgjr_assign(out, .cgjr_leaf_path(row), leaf)
  }
  out
}


# ---------------------------------------------------------------------------
# build_metadata_tbl()
# ---------------------------------------------------------------------------

#' Build the combined variable-metadata tibble from the crosswalk
#'
#' Joins the CGJR crosswalk to [cliaretl::db_variables_final] and to
#' `cgjr_taxonomy`, producing one row per taxonomy indicator with its display
#' name, stated source, resolved `cliaretl` variable, catalogue metadata,
#' cluster/subcluster/sub-subcluster keys and numbers, and two derived
#' eligibility flags.
#'
#' Every crosswalk row is kept — including unresolved indicators
#' (`variable == NA`) and dynamic-ineligible ones — so the table is a
#' complete record of the taxonomy. Consumers filter on
#' `dynamic_indicator_eligible` / `family_aggregate_eligible` as needed.
#'
#' @inheritParams build_ctfdata_list
#' @param catalogue Variable catalogue. Defaults to
#'   [cliaretl::db_variables_final].
#'
#' @return A tibble with one row per crosswalk row.
#'
#' @seealso [validate_crosswalk()]
#'
#' @export
build_metadata_tbl <- function(crosswalk = cgjr_crosswalk,
                               taxonomy  = cgjr_taxonomy,
                               catalogue = cliaretl::db_variables_final) {
  stopifnot(is.data.frame(crosswalk), is.data.frame(taxonomy))

  cat_tbl <- catalogue[!is.na(catalogue$variable), , drop = FALSE]

  tax_keys <- taxonomy[c("cluster", "cluster_num", "cluster_name",
                         "subcluster", "subcluster_num", "subcluster_name",
                         "sub_subcluster", "sub_subcluster_num",
                         "sub_subcluster_name")]

  out <- dplyr::left_join(
    crosswalk, tax_keys,
    by = c("cluster", "subcluster", "sub_subcluster")
  )
  out <- dplyr::left_join(out, cat_tbl, by = "variable", suffix = c("", "_cliar"))

  out$dynamic_indicator_eligible <-
    !is.na(out$benchmark_dynamic_indicator) &
    out$benchmark_dynamic_indicator == "Yes"
  out$family_aggregate_eligible <-
    !is.na(out$benchmark_dynamic_family_aggregate) &
    out$benchmark_dynamic_family_aggregate %in% c("Yes", "Partial")

  tibble::as_tibble(out)
}

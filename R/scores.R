# ============================================================================
# cgjr_scores: long, node-grain rollup (order ii, within-country)
# ============================================================================
# roll_up_scores() takes the country-level cgjr_ctf (indicator grain) and
# rolls it up to node scores at the taxonomy's real tiers - `subcluster`,
# `sub_subcluster` (Public Financial Management only), `cluster`, `overall`.
# At every stage: score = mean(child score, na.rm = TRUE); NaN (all children
# missing) is coerced back to NA; n_inputs / n_inputs_obs record how many
# children contributed and how many of those were non-NA.
#
# `node_level` deliberately mirrors the taxonomy's own column names
# (`subcluster`, `sub_subcluster`) rather than a generic "leaf" label that
# would mean different things in different branches (a subcluster in 10
# cases, a sub_subcluster in PFM's). There is no stored "is this the finest
# grain" flag - it is fully derivable, either from `taxonomy` (a subcluster
# is branching iff it has any non-NA sub_subcluster row) or from cgjr_scores
# alone:
#
#   branching <- unique(scores$subcluster[scores$node_level == "sub_subcluster"])
#   finest <- scores[scores$node_level %in% c("subcluster", "sub_subcluster") &
#                    !(scores$node_level == "subcluster" & scores$subcluster %in% branching), ]
#
# Storing that as a column would just be a second copy of a fact the
# taxonomy already owns - the same reasoning that keeps cgjr_ctf / cgjr_raw
# on snake taxonomy keys only, rather than also carrying denormalised names.
#
# The finest grain is *scaffolded* against `taxonomy` before any of this:
# some leaves have zero cliaretl-eligible indicators for a given (or every)
# ctf_type - e.g. three of the four PFM sub-subclusters currently have no
# crosswalk rows at all, and the fourth has none for ctf_type == "dynamic".
# Grouping cgjr_ctf directly would make those leaves simply never appear,
# indistinguishable from a bug. Instead every taxonomy leaf gets a row for
# every (unit, year, ctf_type) combination that occurs anywhere in cgjr_ctf,
# with score = NA / n_inputs = 0 where it has no data.

.rollup_unit_keys <- c("unit_level", "unit_code", "unit_name", "year", "ctf_type")

# Group `df` by `group_cols` and summarise `value_col` into score / n_inputs
# / n_inputs_obs. NaN scores (every child NA) are coerced to NA.
#' @keywords internal
#' @noRd
.rollup_level <- function(df, group_cols, value_col) {
  out <- df |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) |>
    dplyr::summarise(
      dplyr::across(
        dplyr::all_of(value_col),
        list(
          score        = ~ mean(.x, na.rm = TRUE),
          n_inputs     = ~ length(.x),
          n_inputs_obs = ~ sum(!is.na(.x))
        ),
        .names = "{.fn}"
      ),
      .groups = "drop"
    )
  out$score[is.nan(out$score)] <- NA_real_
  out
}

# Assemble one node level's rows in the cgjr_scores column order. `node`,
# `cluster`, `subcluster`, `sub_subcluster` are vectors (or length-1 values,
# recycled) aligned to `scores_tbl`'s rows.
#' @keywords internal
#' @noRd
.assemble_node_tbl <- function(scores_tbl, node_level, node,
                               cluster = NA_character_,
                               subcluster = NA_character_,
                               sub_subcluster = NA_character_) {
  tibble::tibble(
    unit_level     = scores_tbl$unit_level,
    unit_code      = scores_tbl$unit_code,
    unit_name      = scores_tbl$unit_name,
    year           = scores_tbl$year,
    ctf_type       = scores_tbl$ctf_type,
    node_level     = node_level,
    node           = node,
    cluster        = cluster,
    subcluster     = subcluster,
    sub_subcluster = sub_subcluster,
    score          = scores_tbl$score,
    n_inputs       = scores_tbl$n_inputs,
    n_inputs_obs   = scores_tbl$n_inputs_obs
  )
}

#' Roll up indicator-grain CTF values to node scores
#'
#' Rolls the country-level, indicator-grain `cgjr_ctf` up to node scores at
#' the taxonomy's real tiers by repeated equal-weight averaging: a leaf's
#' score = mean of its indicators' `ctf` values; a branching subcluster's
#' score (Public Financial Management only) = mean of its `sub_subcluster`
#' scores; a cluster's score = mean of its subclusters' scores (using each
#' plain subcluster's own score, or PFM's subcluster-level aggregate);
#' overall = mean of the cluster scores. `NA` is lenient (`na.rm = TRUE`) at
#' every stage, and every node row records `n_inputs` (how many immediate
#' children) and `n_inputs_obs` (how many of those were non-`NA`).
#'
#' The finest grain is completed against every row of `taxonomy` before
#' rolling further up, so a leaf with zero eligible indicators for a given
#' `ctf_type` (or for every `ctf_type`) still gets a row - `score = NA`,
#' `n_inputs = 0L` - for every `(unit, year, ctf_type)` combination present
#' in `ctf_tbl`, rather than silently not appearing.
#'
#' There is no stored "is this the finest grain" flag - every plain
#' subcluster reports once, at `node_level == "subcluster"`, and *is* the
#' finest grain for its branch; only Public Financial Management also has
#' `node_level == "sub_subcluster"` rows one level finer than its own
#' `subcluster` row. To get every finest-grain node regardless of depth:
#'
#' ```r
#' branching <- unique(scores$subcluster[scores$node_level == "sub_subcluster"])
#' finest <- scores[scores$node_level %in% c("subcluster", "sub_subcluster") &
#'                  !(scores$node_level == "subcluster" & scores$subcluster %in% branching), ]
#' ```
#'
#' @param ctf_tbl Country-level, indicator-grain CTF values (the country rows
#'   of `cgjr_ctf`, e.g. from [build_ctf_tbl()]). Needs `unit_level`,
#'   `unit_code`, `unit_name`, `year`, `ctf_type`, `leaf`, `ctf`.
#' @param taxonomy The leaf-node taxonomy. Defaults to `cgjr_taxonomy`.
#'
#' @return A tibble with one row per `unit x year x ctf_type x node`:
#'   `unit_level`, `unit_code`, `unit_name`, `year`, `ctf_type`, `node_level`
#'   (`"subcluster"` / `"sub_subcluster"` / `"cluster"` / `"overall"` - real
#'   taxonomy tiers, `"sub_subcluster"` occurring only under Public Financial
#'   Management), `node` (the operative key at that level, or `"overall"`),
#'   `cluster` / `subcluster` / `sub_subcluster` (ancestry filled to the
#'   node's depth, `NA` deeper), `score`, `n_inputs`, `n_inputs_obs`.
#'
#' @seealso [build_ctf_tbl()]
#'
#' @examples
#' \dontrun{
#' devtools::load_all()
#' roll_up_scores(build_ctf_tbl(cgjr_crosswalk), cgjr_taxonomy)
#' }
#'
#' @export
roll_up_scores <- function(ctf_tbl, taxonomy = cgjr_taxonomy) {
  stopifnot(is.data.frame(ctf_tbl), is.data.frame(taxonomy))

  req <- c(.rollup_unit_keys, "cluster", "subcluster", "sub_subcluster",
           "leaf", "ctf")
  miss <- setdiff(req, names(ctf_tbl))
  if (length(miss)) {
    stop("roll_up_scores(): `ctf_tbl` is missing column(s): ",
         paste(miss, collapse = ", "), call. = FALSE)
  }
  tax_req <- c("cluster", "subcluster", "sub_subcluster")
  tax_miss <- setdiff(tax_req, names(taxonomy))
  if (length(tax_miss)) {
    stop("roll_up_scores(): `taxonomy` is missing column(s): ",
         paste(tax_miss, collapse = ", "), call. = FALSE)
  }

  # --- finest grain: real scores from ctf_tbl, scaffolded against every
  #     taxonomy leaf ------------------------------------------------------
  leaf_real <- .rollup_level(ctf_tbl, c(.rollup_unit_keys, "leaf"), "ctf")

  units_grid <- dplyr::distinct(
    ctf_tbl, dplyr::across(dplyr::all_of(.rollup_unit_keys))
  )
  tax_leaf <- tibble::tibble(
    leaf           = resolve_leaf(taxonomy$sub_subcluster, taxonomy$subcluster),
    cluster        = taxonomy$cluster,
    subcluster     = taxonomy$subcluster,
    sub_subcluster = taxonomy$sub_subcluster
  )
  tax_leaf <- tax_leaf[!duplicated(tax_leaf$leaf), , drop = FALSE]

  scaffold <- dplyr::cross_join(units_grid, tax_leaf)
  finest <- dplyr::left_join(
    scaffold,
    leaf_real[, c(.rollup_unit_keys, "leaf", "score", "n_inputs", "n_inputs_obs")],
    by = c(.rollup_unit_keys, "leaf"),
    relationship = "one-to-one"
  )
  finest$n_inputs[is.na(finest$n_inputs)]         <- 0L
  finest$n_inputs_obs[is.na(finest$n_inputs_obs)] <- 0L

  # --- split the finest grain by its real taxonomy tier -------------------
  # A leaf with a sub_subcluster (PFM) reports at node_level "sub_subcluster";
  # every other leaf *is* its subcluster and reports at node_level
  # "subcluster" directly - no separate duplicate row.
  is_branch_leaf <- !is.na(finest$sub_subcluster)

  plain_nodes <- .assemble_node_tbl(
    finest[!is_branch_leaf, ], "subcluster", finest$subcluster[!is_branch_leaf],
    cluster    = finest$cluster[!is_branch_leaf],
    subcluster = finest$subcluster[!is_branch_leaf]
  )
  branch_leaf_nodes <- .assemble_node_tbl(
    finest[is_branch_leaf, ], "sub_subcluster", finest$sub_subcluster[is_branch_leaf],
    cluster        = finest$cluster[is_branch_leaf],
    subcluster     = finest$subcluster[is_branch_leaf],
    sub_subcluster = finest$sub_subcluster[is_branch_leaf]
  )

  # --- subcluster-tier aggregate for branching subclusters (PFM) ----------
  branch_subcluster_scores <- .rollup_level(
    finest[is_branch_leaf, ], c(.rollup_unit_keys, "cluster", "subcluster"), "score"
  )
  branch_subcluster_nodes <- .assemble_node_tbl(
    branch_subcluster_scores, "subcluster", branch_subcluster_scores$subcluster,
    cluster    = branch_subcluster_scores$cluster,
    subcluster = branch_subcluster_scores$subcluster
  )

  subcluster_nodes <- dplyr::bind_rows(plain_nodes, branch_subcluster_nodes)

  # --- cluster level -------------------------------------------------------
  cluster_scores <- .rollup_level(
    subcluster_nodes, c(.rollup_unit_keys, "cluster"), "score"
  )
  cluster_nodes <- .assemble_node_tbl(
    cluster_scores, "cluster", cluster_scores$cluster,
    cluster = cluster_scores$cluster
  )

  # --- overall level ---------------------------------------------------
  overall_scores <- .rollup_level(cluster_scores, .rollup_unit_keys, "score")
  overall_nodes <- .assemble_node_tbl(overall_scores, "overall", "overall")

  dplyr::bind_rows(branch_leaf_nodes, subcluster_nodes, cluster_nodes, overall_nodes)
}

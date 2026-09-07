# cgjrdata rewrite — tidy-tibble build

Rebuild `cgjrdata` so it ships **long tidy tibbles** for `cgjrapp` instead of
nested lists. The two editable CSVs stay the source of truth; everything
downstream is regenerated.

Status: **complete** (branch `rewrite-tidy-tibble`). All 6 phases done; the
package ships the 6 objects below, `devtools::check()` is 0/0/0, and
`qcheck/qa-report.md` audits the result against `cliaretl` + `cliarappak`.
Phases 1-5 + `qcheck/` are in commit `ad01fed`; phase-6 docs followed.

---

## 1. Locked decisions

| # | Decision |
|---|---|
| Format | Long tidy tibbles, not nested lists. |
| `ctf_type` | A column, values `"dynamic"` / `"static"`. One code path, one set of objects. |
| Within-country rollup | **Option B** — each node score is the **mean of its immediate children's scores** (equal weight per child). CLIAR computes a family CTF as the flat `mean()` of its member indicator CTFs; B extends that up the tree (leaf → subcluster → cluster → overall). |
| NA handling in rollup | Lenient (`na.rm = TRUE`); every node row carries coverage counts so the app can threshold. |
| Cross-country aggregation | **Median** across the group's countries (CLIAR fidelity), exposed as a single `agg` argument that swaps to `mean`. |
| Aggregation order | **Order ii** — roll up each country fully, *then* take the median across countries at every node level independently. |
| CTF windows / direction / eligibility for cliaretl variables | Already enforced upstream in `closeness_to_frontier_dynamic` / `_static`. We only slice columns + average over our taxonomy. |
| Non-cliaretl indicators | **Deferred.** No `ctf_source` column, no custom-frontier path in this rewrite. Revisit later. |
| `metadata_tbl` | Merged into the annotated `cgjr_crosswalk`. Not a separate object. |

---

## 2. Shipped objects (6)

### `cgjr_taxonomy` — unchanged
One row per leaf node (14 rows). Straight from `data-raw/input/cgjr_taxonomy.csv`.
Columns: `cluster`, `cluster_num`, `cluster_name`, `subcluster`,
`subcluster_num`, `subcluster_name`, `sub_subcluster`, `sub_subcluster_num`,
`sub_subcluster_name`.

### `wbcountries` — unchanged
WB country classifications (regions with AFE/AFW split, income groups).
Produced by `data-raw/source/00a-prepare-country-list.R`.

### `cgjr_crosswalk` — annotated (absorbs `metadata_tbl`)
One row per (indicator × leaf) — every row of the CSV kept, including
unresolved. CSV columns + taxonomy keys/names/numbers + `cliaretl` catalogue
metadata + eligibility flags.

| column | source |
|---|---|
| `cluster`, `subcluster`, `sub_subcluster`, `indicator_num`, `indicator`, `source`, `variable`, `note` | CSV |
| `leaf` | derived: `coalesce(sub_subcluster, subcluster)` — unique per schema |
| `cluster_num`, `cluster_name`, `subcluster_num`, `subcluster_name`, `sub_subcluster_num`, `sub_subcluster_name` | join to `cgjr_taxonomy` |
| `var_name`, `description`, `description_short`, `family_name`, `etl_source`, `benchmarked_ctf`, `benchmark_dynamic_indicator`, `benchmark_dynamic_family_aggregate`, `benchmark_static_family_aggregate_download`, … | join to `cliaretl::db_variables_final` (`NA` for unresolved rows) |
| `in_cliaretl` | `variable %in% db_variables_final$variable` |
| `in_dynamic_panel` | `variable %in% names(closeness_to_frontier_dynamic)` |
| `in_static_panel` | `variable %in% names(closeness_to_frontier_static)` |
| `dynamic_eligible` | `in_dynamic_panel & benchmark_dynamic_indicator == "Yes"` |
| `static_eligible` | `in_static_panel` (no `benchmark_static_indicator` flag exists in `db_variables_final`; panel membership *is* the eligibility) |
| `cliaretl_status` | `"resolved"` / `"unresolved"` (variable NA) / `"not_in_cliaretl"` (variable set, absent from `db_variables_final`) |

### `cgjr_ctf` — long, indicator-grain CTF values
One row per **unit × year × ctf_type × leaf × indicator**.

| column | notes |
|---|---|
| `unit_level` | `"country"` / `"region"` / `"income_group"` |
| `unit_code` | ISO3 / `region_code` / income-group slug |
| `unit_name` | country / region / income-group display name |
| `year` | integer; **`NA` for `ctf_type == "static"`** |
| `ctf_type` | `"dynamic"` / `"static"` |
| `cluster`, `subcluster`, `sub_subcluster`, `leaf` | taxonomy keys (snake); app joins `cgjr_taxonomy` for names/numbers |
| `indicator` | human name (from crosswalk) |
| `variable` | `cliaretl` code |
| `ctf` | numeric 0–1 |

- Country rows: sliced from the relevant CTF panel for every `*_eligible`
  crosswalk variable.
- Region / income rows: `agg()` (median) across that group's countries of the
  indicator's country-level `ctf`, computed independently per column.
- Indicators that are unresolved or not eligible for a given `ctf_type` simply
  don't produce rows for that `ctf_type` (documented).

### `cgjr_scores` — long, node-grain rollup
One row per **unit × year × ctf_type × node**.

| column | notes |
|---|---|
| `unit_level`, `unit_code`, `unit_name`, `year`, `ctf_type` | as `cgjr_ctf` |
| `node_level` | `"subcluster"` / `"sub_subcluster"` / `"cluster"` / `"overall"` — **real taxonomy tiers**, matching the taxonomy's own column names. `"sub_subcluster"` occurs only under Public Financial Management. |
| `node` | operative key: subcluster key / sub_subcluster key / cluster key / `"overall"` |
| `cluster`, `subcluster`, `sub_subcluster` | ancestry, filled to the node's depth, `NA` deeper (`overall` → all `NA`) |
| `score` | numeric 0–1 |
| `n_inputs` | count of immediate children (indicators for a finest-grain node; sub_subclusters for PFM's subcluster row; subclusters for cluster; clusters for overall) |
| `n_inputs_obs` | count of those with a non-`NA` value for this row |

- Country rows: order-ii rollup (§3).
- Region / income rows: `agg()` (median) across the group's countries of each
  node's country-level `score`.
- **No stored "is this the finest grain" column.** It's fully derivable —
  either from `taxonomy` (a subcluster is branching iff it has a non-`NA`
  `sub_subcluster` row) or from `cgjr_scores` alone:
  ```r
  branching <- unique(scores$subcluster[scores$node_level == "sub_subcluster"])
  finest <- scores[scores$node_level %in% c("subcluster", "sub_subcluster") &
                   !(scores$node_level == "subcluster" & scores$subcluster %in% branching), ]
  ```
  Storing it would just be a second copy of a fact `taxonomy` already owns —
  the same reasoning behind keeping `cgjr_ctf`/`cgjr_raw` on snake taxonomy
  keys only rather than also carrying denormalised names (Q2).
- **Revision history (2026-09-04, superseding the original `"leaf"`
  design):** the original plan gave every node a `node_level == "leaf"` row
  in addition to its real-tier row, so the 10 non-PFM subclusters produced
  two numerically identical rows differing only in that label — conflating
  "which taxonomy tier is this" with "is this the finest grain" into one
  overloaded value, and risking a consumer double-counting those 10
  subclusters if it grouped/plotted by `node` without also filtering
  `node_level`. First replaced with real tier names + a stored `is_leaf`
  flag; then `is_leaf` itself was dropped as redundant (above) — no
  duplicate rows, no stored derived column, same query power via the
  two-line filter.

### `cgjr_raw` — long, raw source values
One row per **country × year × leaf × indicator** (no `ctf_type` — raw has
none; **country grain only** — no region / income rows).

Same columns as `cgjr_ctf` minus `ctf_type`, with `value` instead of `ctf`.
Country rows from `extract_cliar_data(type = "raw")`. **No group aggregation:**
raw values are for display / download in `cgjrapp`, never benchmarking, and the
units are heterogeneous (indices, %, counts) — a regional median of them is
meaningless. `unit_level` is always `"country"` (kept for schema parity).
(Decision Q5, 2026-09-03.)

---

## 3. The rollup (order ii, within-country)

**The finest grain is scaffolded against `taxonomy` before rolling up.** Some
leaves have zero cliaretl-eligible indicators for a given (or every)
`ctf_type` — e.g. three of the four Public Financial Management
sub-subclusters currently have no crosswalk rows at all, and the fourth
(`budget_cycle_and_fiscal_planning`) has none for `ctf_type == "dynamic"`.
Grouping `cgjr_ctf` directly would make those leaves simply never appear —
indistinguishable from a bug, and violating "every taxonomy leaf appears in
the finest-grain filter over `cgjr_scores`" (§6). So:

```
cgjr_ctf (indicator)
  │  group_by(unit, year, ctf_type, leaf)                      leaf = coalesce(sub_subcluster, subcluster)
  ▼  score = mean(ctf, na.rm = TRUE);  n_inputs = n();  n_inputs_obs = sum(!is.na(ctf))
finest-grain scores actually observed
  │  cross_join( distinct(unit, year, ctf_type) present in cgjr_ctf,  every taxonomy leaf )
  │  left_join the observed scores onto that scaffold
  │  unmatched leaf x unit x year x ctf_type → score = NA, n_inputs = n_inputs_obs = 0L
  │  (cluster/subcluster/sub_subcluster ancestry comes from `taxonomy`, not from cgjr_ctf)
▼
finest grain, complete (every taxonomy leaf x every unit/year/ctf_type present anywhere)
  │  split by whether the leaf has a sub_subcluster (PFM) or not (everyone else)
  ├─ no sub_subcluster → emit directly as node_level "subcluster"   (no further rollup — this IS its subcluster; finest-grain)
  └─ has sub_subcluster → emit as node_level "sub_subcluster"   (finest-grain)
       │  group_by(unit, year, ctf_type, cluster, subcluster)
       ▼  score = mean(sub_subcluster score, na.rm = TRUE)
     PFM's own subcluster row, node_level "subcluster"   (branching aggregate, not finest-grain)
  │  (both branches' subcluster-tier rows combined)
  ▼
SUBCLUSTER-tier rows (11: 10 finest-grain, 1 PFM aggregate)
  │  group_by(unit, year, ctf_type, cluster)
  ▼  score = mean(subcluster score, na.rm = TRUE)
CLUSTER score
  │  group_by(unit, year, ctf_type)
  ▼  score = mean(cluster score, na.rm = TRUE)
OVERALL score
```

Once the finest grain is complete, the subcluster / cluster / overall tiers
need **no further scaffolding** — grouping a complete table naturally yields
one row per node that has at least one child underneath it, which (by
construction of `taxonomy`) is every node.

- `mean(..., na.rm = TRUE)`, `NaN → NA` (all children missing).
- Every stage records `n_inputs` / `n_inputs_obs`. At the finest grain, a
  zero-indicator leaf gets `n_inputs = n_inputs_obs = 0L`, not `NA` — it
  genuinely has zero children today.
- Bind all four tiers' rows into one long tibble.

Cross-country group step (order ii): take the **country-level `cgjr_scores`**
and, for each `group × year × ctf_type × node`, compute `agg(score)` across the
countries in the group. Independent of the indicator-level group medians in
`cgjr_ctf` — because `median` isn't linear the two won't reconcile
arithmetically; that is expected and documented.

---

## 4. Function inventory (`R/`)

| file | functions | replaces |
|---|---|---|
| `R/schema.R` | `check_crosswalk_schema(crosswalk, taxonomy)` — structural, `cliaretl`-free, batched `stop()` | old `check_crosswalk_schema` |
| `R/eligibility.R` | `classify_crosswalk(crosswalk, catalogue, ctf_dynamic, ctf_static)` → per-row flag tibble; `validate_crosswalk(crosswalk, …)` → warn + return classification invisibly | old `.cgjr_classify_crosswalk` / `validate_crosswalk` (extended for static) |
| `R/crosswalk.R` | `build_crosswalk(crosswalk_csv, taxonomy, catalogue)` → annotated `cgjr_crosswalk`; helper `resolve_leaf()` | old `build_metadata_tbl` |
| `R/ctf.R` | `build_ctf_tbl(crosswalk, ctf_dynamic, ctf_static, id_cols)` → country-level long `cgjr_ctf` (no `taxonomy` arg — crosswalk carries `leaf` + ancestry) | old `build_ctfdata_list` |
| `R/raw.R` | `build_raw_tbl(crosswalk, id_cols)` → country-level long `cgjr_raw` (no group step, no `taxonomy` arg) | old `build_rawdata_list` |
| `R/scores.R` | `roll_up_scores(ctf_tbl, taxonomy)` → country-level long `cgjr_scores` (order-ii rollup) | old `compute_scores.R` (whole file) |
| `R/aggregate.R` | `aggregate_to_groups(tbl, wbcountries, value_col, agg = stats::median, min_n = 1)` → region + income group rows; helper `join_wb_classifications()` | old `aggregate_groups.R` (whole file) |
| `R/extract_cliar_data.R` | **keep unchanged**; `build_ctf_tbl` / `build_raw_tbl` guard the zero-variable case at the call site instead | — |
| `R/zzz.R` | update `globalVariables()` | — |
| `R/data.R` | roxygen for the 6 shipped objects | old `R/data.R` |

**Gone for good:** `.cgjr_map_leaves`, `.cgjr_assign`, `.cgjr_leaf_path`,
`.cgjr_leaf_rows`, `add_subcluster_score`, `score_ctfdata_list`,
`compute_cluster_averages`, `build_ctfdata_list`, `build_rawdata_list`,
`aggregate_tbl_by_group`, `aggregate_data_list`. No recursion anywhere.

---

## 5. `data-raw/` and `analysis/`

- **`data-raw/source/00a-prepare-country-list.R`** — unchanged.
- **`data-raw/source/00b-cgjr-taxonomy-crosswalk.R`** — rewrite:
  1. read both CSVs with explicit `readr::cols()` spec, `na = ""`
  2. `readr::problems()` guard → `stop()` on parse issues
  3. `check_crosswalk_schema(crosswalk_csv, taxonomy_csv)`
  4. `cgjr_taxonomy <- as_tibble(taxonomy_csv)`
  5. `cgjr_crosswalk <- build_crosswalk(crosswalk_csv, cgjr_taxonomy, cliaretl::db_variables_final)`
  6. `validate_crosswalk(cgjr_crosswalk)` — warn + print summary line
  7. `usethis::use_data(cgjr_taxonomy, cgjr_crosswalk, overwrite = TRUE)`
  8. no output CSV
- **`analysis/00-build_all_datasets.r`** — unchanged (sources 00a + 00b).
- **`analysis/01-build-tidy-data.R`** — new:
  ```r
  devtools::load_all(); library(dplyr)

  ctf_country   <- build_ctf_tbl(cgjr_crosswalk)
  raw_country   <- build_raw_tbl(cgjr_crosswalk)
  score_country <- roll_up_scores(ctf_country, cgjr_taxonomy)

  agg <- stats::median   # <- switch to `mean` here if needed

  cgjr_ctf    <- bind_rows(ctf_country,   aggregate_to_groups(ctf_country,   wbcountries, "ctf",   agg))
  cgjr_raw    <- raw_country   # country grain only — no group aggregation (Q5)
  cgjr_scores <- bind_rows(score_country, aggregate_to_groups(score_country, wbcountries, "score", agg))

  usethis::use_data(cgjr_ctf, cgjr_raw, cgjr_scores, overwrite = TRUE)
  ```

---

## 6. Tests (`tests/testthat/`)

| file | covers |
|---|---|
| `test-extract_cliar_data.R` | **keep** (19 tests, accessor unchanged) |
| `test-schema.R` | `check_crosswalk_schema` — well-formed pair passes; missing column; leaf path not in taxonomy; dup `indicator_num`; dup `variable`; shipped pair passes |
| `test-eligibility.R` | `classify_crosswalk` / `validate_crosswalk` on synthetic catalogue + both panels — resolved/unresolved/not-in-cliaretl; dynamic-eligible vs static-only; warning fired |
| `test-crosswalk.R` | `build_crosswalk` — every CSV row survives; `leaf` resolution; annotated columns present; unresolved rows kept with `NA` metadata |
| `test-ctf.R` | `build_ctf_tbl` — long shape; both `ctf_type`s stacked; only `*_eligible` variables appear; static rows have `year = NA`; ineligible/unresolved produce no rows |
| `test-scores.R` | `roll_up_scores` — finest-grain score = mean of indicator CTFs; PFM's subcluster row = mean of its sub_subclusters (a branching aggregate, `node_level` "subcluster"); every plain subcluster reports once at `node_level` "subcluster" (no duplicate row); cluster = mean of subclusters; overall = mean of clusters; `n_inputs` / `n_inputs_obs`; all-`NA` → `NA` not `NaN`; the finest-grain filter recipe |
| `test-aggregate.R` | `aggregate_to_groups` — median across countries; WB aggregate codes dropped; `agg = mean` switch; `min_n` threshold; order-ii property (group score = median of country scores, not derived from group indicator medians) |
| `test-integration.R` | guarded on `cliaretl` + built data — 6 objects present; every taxonomy leaf appears in the finest-grain filter over `cgjr_scores`; `unit_level` domain; scores within a loose sanity bound (see the CTF-range finding below, real values run to ~1.13, not strictly [0, 1]); no all-`NA` indicator artefacts from a bad join |

---

## 7. `DESCRIPTION` / docs

- `Imports`: add `tidyr`. Keep `dplyr`, `tibble`, `cliaretl`, `purrr`
  (`purrr::reduce` still used in `extract_cliar_data`).
- `Description:` prose — rewrite to describe `cgjr_ctf` / `cgjr_scores` /
  `cgjr_raw`.
- `LazyData: true` — keep.
- `README.md` / `README.Rmd` — rewrite (Phase 6).
- `data-raw/source/README.md`, `data-raw/input/README.md` — refresh paths /
  function names (Phase 6).
- `copilot_logs/CONTEXT_FOR_CGJRAPP.md` — rewrite once the shape is final
  (Phase 6).
- Memory: update `project-overview`, retire `simplification-target-nesting`.

---

## 8. Implementation phases

| phase | work | milestone |
|---|---|---|
| **0** | `DESCRIPTION` Imports, `R/zzz.R` globals | `devtools::load_all()` clean |
| **1** | `R/schema.R`, `R/eligibility.R`, `R/crosswalk.R`; rewrite `00b`; `test-schema.R`, `test-eligibility.R`, `test-crosswalk.R` | `source("analysis/00-build_all_datasets.r")` → annotated `cgjr_crosswalk` + `cgjr_taxonomy` |
| **2** | `R/ctf.R`, `R/raw.R`; `test-ctf.R` | `build_ctf_tbl()` / `build_raw_tbl()` return correct country-level long tibbles |
| **3** | `R/scores.R`; `test-scores.R` | `roll_up_scores()` correct on fixture + real data |
| **4** | `R/aggregate.R`; `test-aggregate.R` | order-ii group rows, median default, mean switch |
| **5** | `analysis/01-build-tidy-data.R`, `R/data.R`, `devtools::document()`, `use_data()`; `test-integration.R` | 6 objects ship; `devtools::check()` clean |
| **6** | READMEs, `CONTEXT_FOR_CGJRAPP.md`, memory | docs match reality |

---

## 9. Small questions — RESOLVED 2026-09-03

1. **Static `year`** → **`NA`**, documented. Static panel carries no year.
2. **`cgjr_ctf` width** → **snake taxonomy keys only**; app joins
   `cgjr_taxonomy` for names/numbers. Revisit if the app makes this awkward
   (flagged as pivot-able).
3. **`min_n` for group aggregates** → **`min_n = 1`** (emit whatever is
   present). `cliaretl`'s ETL package has *no* cross-country group-aggregation
   convention — its coverage thresholds (`flag_minimum_coverage`: ≥10 countries
   in ≥2 years; `flag_country`: ≥100 countries, or ≥50 across all 7 regions)
   are *indicator-eligibility* flags, already enforced upstream. Region/income
   medians came from the CLIAR *dashboard*, not the package. The old cgjrdata
   used a plain `mean` with no minimum. So: keep `min_n = 1` and let the
   consumer threshold on the `n_inputs` / `n_inputs_obs` counts every group row
   already carries.
4. **`overall` when clusters missing** → **always compute**, expose `n_inputs`.
5. **`cgjr_raw` group aggregation** → **none.** `cgjr_raw` is country-grain
   only. Raw values are for display / download in `cgjrapp`, not benchmarking;
   heterogeneous units make a regional median meaningless.

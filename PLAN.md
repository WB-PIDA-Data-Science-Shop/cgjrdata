# cgjrdata rewrite — tidy-tibble build

Rebuild `cgjrdata` so it ships **long tidy tibbles** for `cgjrapp` instead of
nested lists. The two editable CSVs stay the source of truth; everything
downstream is regenerated.

Status: package scrubbed (branch `rewrite-tidy-tibble`, commit `2ec0d03`).
Surviving code: `R/extract_cliar_data.R`, `R/zzz.R`, `data-raw/source/00a`,
`data-raw/source/00b` (stub — rewritten in Phase 1). Surviving data:
`cgjr_taxonomy`, `cgjr_crosswalk`, `wbcountries`.

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
| `in_catalogue` | `variable %in% db_variables_final$variable` |
| `in_dynamic_panel` | `variable %in% names(closeness_to_frontier_dynamic)` |
| `in_static_panel` | `variable %in% names(closeness_to_frontier_static)` |
| `dynamic_eligible` | `in_dynamic_panel & benchmark_dynamic_indicator == "Yes"` |
| `static_eligible` | `in_static_panel` (no `benchmark_static_indicator` flag exists in `db_variables_final`; panel membership *is* the eligibility) |
| `cliaretl_status` | `"resolved"` / `"unresolved"` (variable NA) / `"not_in_catalogue"` |

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
| `node_level` | `"leaf"` / `"subcluster"` / `"cluster"` / `"overall"` |
| `node` | operative key: leaf key / subcluster key / cluster key / `"overall"` |
| `cluster`, `subcluster`, `sub_subcluster` | ancestry, filled to the node's depth, `NA` deeper (`overall` → all `NA`) |
| `score` | numeric 0–1 |
| `n_inputs` | count of immediate children (indicators for leaf; leaves for subcluster; subclusters for cluster; clusters for overall) |
| `n_inputs_obs` | count of those with a non-`NA` value for this row |

- Country rows: order-ii rollup (§3).
- Region / income rows: `agg()` (median) across the group's countries of each
  node's country-level `score`.
- For the 10 non-PFM subclusters the `leaf` row and the `subcluster` row are
  numerically identical — kept both so the app can always query
  `node_level == "subcluster"`.

### `cgjr_raw` — long, raw source values
One row per **unit × year × leaf × indicator** (no `ctf_type` — raw has none).

Same columns as `cgjr_ctf` minus `ctf_type`, with `value` instead of `ctf`.
Country rows from `extract_cliar_data(type = "raw")`; group rows via the same
`agg()`. Raw units are heterogeneous (indices, %, counts) — group aggregates
are provided for convenience; document the caveat.

---

## 3. The rollup (order ii, within-country)

For each `unit × year × ctf_type`:

```
cgjr_ctf (indicator)
  │  group_by(unit, year, ctf_type, cluster, subcluster, sub_subcluster, leaf)
  ▼  score = mean(ctf, na.rm = TRUE);  n_inputs = n();  n_inputs_obs = sum(!is.na(ctf))
LEAF score
  │  group_by(unit, year, ctf_type, cluster, subcluster)
  ▼  score = mean(leaf score);  (identity for non-PFM — one leaf per subcluster)
SUBCLUSTER score
  │  group_by(unit, year, ctf_type, cluster)
  ▼  score = mean(subcluster score)
CLUSTER score
  │  group_by(unit, year, ctf_type)
  ▼  score = mean(cluster score)
OVERALL score
```

- `mean(..., na.rm = TRUE)`, `NaN → NA` (all children missing).
- Every stage records `n_inputs` / `n_inputs_obs`.
- Bind the four levels into one long tibble.

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
| `R/ctf.R` | `build_ctf_tbl(crosswalk, taxonomy, ctf_dynamic, ctf_static, id_cols)` → country-level long `cgjr_ctf` | old `build_ctfdata_list` |
| `R/raw.R` | `build_raw_tbl(crosswalk, taxonomy, id_cols)` → country-level long `cgjr_raw` | old `build_rawdata_list` |
| `R/scores.R` | `roll_up_scores(ctf_tbl, taxonomy)` → country-level long `cgjr_scores` (order-ii rollup) | old `compute_scores.R` (whole file) |
| `R/aggregate.R` | `aggregate_to_groups(tbl, wbcountries, value_col, agg = stats::median, min_n = 1)` → region + income group rows; helper `join_wb_classifications()` | old `aggregate_groups.R` (whole file) |
| `R/extract_cliar_data.R` | **keep**; minor: return empty instead of `stop()` when zero variables resolve | — |
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

  ctf_country   <- build_ctf_tbl(cgjr_crosswalk, cgjr_taxonomy)
  raw_country   <- build_raw_tbl(cgjr_crosswalk, cgjr_taxonomy)
  score_country <- roll_up_scores(ctf_country, cgjr_taxonomy)

  agg <- stats::median   # <- switch to `mean` here if needed

  cgjr_ctf    <- bind_rows(ctf_country,   aggregate_to_groups(ctf_country,   wbcountries, "ctf",   agg))
  cgjr_raw    <- bind_rows(raw_country,   aggregate_to_groups(raw_country,   wbcountries, "value", agg))
  cgjr_scores <- bind_rows(score_country, aggregate_to_groups(score_country, wbcountries, "score", agg))

  usethis::use_data(cgjr_ctf, cgjr_raw, cgjr_scores, overwrite = TRUE)
  ```

---

## 6. Tests (`tests/testthat/`)

| file | covers |
|---|---|
| `test-extract_cliar_data.R` | **keep** (19 tests, accessor unchanged) |
| `test-schema.R` | `check_crosswalk_schema` — well-formed pair passes; missing column; leaf path not in taxonomy; dup `indicator_num`; dup `variable`; shipped pair passes |
| `test-eligibility.R` | `classify_crosswalk` / `validate_crosswalk` on synthetic catalogue + both panels — resolved/unresolved/not-in-catalogue; dynamic-eligible vs static-only; warning fired |
| `test-crosswalk.R` | `build_crosswalk` — every CSV row survives; `leaf` resolution; annotated columns present; unresolved rows kept with `NA` metadata |
| `test-ctf.R` | `build_ctf_tbl` — long shape; both `ctf_type`s stacked; only `*_eligible` variables appear; static rows have `year = NA`; ineligible/unresolved produce no rows |
| `test-scores.R` | `roll_up_scores` — leaf score = mean of indicator CTFs; PFM subcluster = mean of its 4 leaves; non-PFM subcluster == leaf; cluster = mean of subclusters; overall = mean of clusters; `n_inputs` / `n_inputs_obs`; all-`NA` → `NA` not `NaN` |
| `test-aggregate.R` | `aggregate_to_groups` — median across countries; WB aggregate codes dropped; `agg = mean` switch; `min_n` threshold; order-ii property (group score = median of country scores, not derived from group indicator medians) |
| `test-integration.R` | guarded on `cliaretl` + built data — 6 objects present; every taxonomy leaf appears in `cgjr_scores`; `unit_level` domain; scores within [0, 1]; no all-`NA` indicator artefacts from a bad join |

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

## 9. Small questions to settle in-flight

1. **Static `year`** — `NA` (recommended, documented) vs. the snapshot year of
   the static panel.
2. **`cgjr_ctf` / `cgjr_raw` width** — snake taxonomy keys only (recommended;
   app joins `cgjr_taxonomy`) vs. also carrying names/numbers.
3. **`min_n` for group aggregates** — emit a group value only if ≥ N countries
   contribute? Default `1`, likely raise to `3`.
4. **`overall` when clusters are missing** — compute regardless and expose
   `n_inputs` (recommended) vs. require all 4 clusters present.
5. **`cgjr_raw` group aggregation** — same `agg` as scores (recommended) vs.
   force `mean` for raw.

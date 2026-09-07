# CGJR taxonomy — editable source

These two CSVs define the CGJR taxonomy and every indicator's place in it.
They are the **only** files to edit when the methodology changes. Edit in
**Google Sheets** or a CSV-aware editor — **not Excel** (it coerces codes to
dates, strips leading zeros, and re-encodes text on save).

After editing, from the package root:

```r
source("analysis/00-build_all_datasets.r")   # re-reads the CSVs, validates, rebuilds cgjr_taxonomy / cgjr_crosswalk
source("analysis/01-build-tidy-data.R")       # rebuilds cgjr_ctf / cgjr_scores / cgjr_raw
devtools::document(); devtools::check()
```

`00b` will **stop** on a structural problem (`check_crosswalk_schema()`) and
**warn**, row by row, on any indicator that will contribute no CTF data
(`validate_crosswalk()` — unresolved, not in `cliaretl`, or in no CTF panel).

---

## `cgjr_taxonomy.csv` — one row per leaf node

The full hierarchy, including intentionally-empty nodes. Order here is the
display order.

| column | notes |
|---|---|
| `cluster` | snake_case key (list key). One of `institutional_environment`, `core_governance_functions`, `beyond_core_governance_functions`, `context`. |
| `cluster_num` | 1–4 |
| `cluster_name` | display name |
| `subcluster` | snake_case key |
| `subcluster_num` | order within the cluster |
| `subcluster_name` | display name |
| `sub_subcluster` | snake_case key — **blank** except for the four Public Financial Management rows |
| `sub_subcluster_num` | blank / order within the subcluster |
| `sub_subcluster_name` | blank / display name |

A leaf is a subcluster row (`sub_subcluster` blank) **or** a sub-subcluster
row. Public Financial Management contributes 4 leaf rows, not 1.

## `cgjr_crosswalk.csv` — one row per (indicator × leaf)

| column | notes |
|---|---|
| `cluster`, `subcluster`, `sub_subcluster` | must match a leaf in `cgjr_taxonomy.csv` (leave `sub_subcluster` blank unless the leaf is under PFM) |
| `indicator_num` | position within the leaf; unique within the leaf |
| `indicator` | human-readable name (as the methodology team specifies it) |
| `source` | stated data source (free text, e.g. `WJP`, `PEFA PI-5`) |
| `variable` | the `cliaretl` variable code. **Blank** if no code has been confirmed. Never guess — leave blank. |
| `note` | free text: how the code was resolved, what still needs checking, or why it is unresolved. Commas/quotes are fine (standard CSV quoting). Keep it to one line. |

`build_crosswalk()` annotates each row against live `cliaretl`: taxonomy
names/numbers, catalogue metadata (`var_name`, `description`, `family_var`,
`benchmark_dynamic_indicator`, …), and eligibility flags (`in_dynamic_panel`,
`in_static_panel`, `dynamic_eligible`, `static_eligible`, `cliaretl_status`).
`validate_crosswalk()` prints a summary and warns on any row that will
contribute no CTF data. The annotated table *is* `cgjr_crosswalk` — there is
no separate `metadata_tbl`.

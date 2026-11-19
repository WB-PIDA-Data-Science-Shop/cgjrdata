# CGJR taxonomy — editable source

These two CSVs define the CGJR taxonomy and every indicator's place in it.
They are the **only** files to edit when the methodology changes. Edit in
**Google Sheets** or a CSV-aware editor — **not Excel** (it coerces codes to
dates, strips leading zeros, and re-encodes text on save).

After editing, from the package root:

```r
source("data-raw/cgjr.R")   # rebuilds cgjr_taxonomy, cgjr_crosswalk, cgjr_ctf, cgjr_raw
devtools::test()            # the data contract tests in tests/testthat/test-data.R
```

The build prints a checklist. `check_cgjr_mapping()` **stops** (red ✖) on a
duplicate taxonomy leaf or a crosswalk row whose leaf is not in the taxonomy,
and **warns** (!) on variables that are not in the `cliaretl` catalogue or
have no CTF values CLIAR benchmarks. `locate_raw_variables()` warns on
variables found in no raw dataset. Everything that passes gets a green ✔.

`data-raw/wbcountries.R` rebuilds `wbcountries`; run it only when the World
Bank classification file (`CLASS_*.xlsx`) changes.

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
| `variable` | the variable code. **Blank** if no code has been confirmed. Never guess — leave blank. A variable may appear on more than one leaf. |
| `note` | free text: how the code was resolved, what still needs checking, or why it is unresolved. Commas/quotes are fine (standard CSV quoting). Keep it to one line. |

The build adds to each row: `leaf`, the taxonomy names and numbers, the
`cliaretl` `description` / `description_short`, `in_dynamic` / `in_static`
(CLIAR benchmarks the variable in that CTF panel — see
`flag_ctf_eligibility()`) and `raw_dataset` (the `cliaretl` dataset holding
its raw values). The result is the shipped `cgjr_crosswalk`.

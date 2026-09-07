# `qcheck/` — lazyload quality assurance

Independent verification that the six objects `cgjrdata` ships are faithful to
their upstream sources and to the CLIAR methodology (`cliarappak`).

| file | what it is |
|---|---|
| `qa-report.Rmd` | the reproducible audit — every number is recomputed from the installed `cgjrdata` + `cliaretl` at render time |
| `qa-report.md` | the knit output (read this) |

## Regenerate

From the package root, with `cliaretl` installed and `cgjrdata` either
installed or loadable from source:

```r
rmarkdown::render("qcheck/qa-report.Rmd")          # -> qa-report.md (+ .html)
knitr::knit("qcheck/qa-report.Rmd", "qcheck/qa-report.md")   # no pandoc needed
```

The report audits the **currently built** `data/*.rda`. If `cgjr_crosswalk`
or `cliaretl` has changed, rebuild the tibbles first:

```r
source("analysis/00-build_all_datasets.r")
source("analysis/01-build-tidy-data.R")
```

## What it covers

- **`cgjr_raw`** — every value equals the per-provider `cliaretl` object and
  `compiled_indicators.rds`, on the provider's native scale (not CTF).
- **`cgjr_ctf`** — country rows are an exact slice of
  `closeness_to_frontier_dynamic` / `_static`; the eligibility gate
  (`benchmark_dynamic_indicator`) is justified.
- **`cgjr_scores`** — each rollup tier recomputes from the tier below; the
  finest grain matches `cliaretl::compute_family_average(require_complete =
  FALSE, exclude_pattern = "gdp")` wherever a CGJR leaf equals a CLIAR
  family; deliberate taxonomy departures are enumerated; group rows are
  order-ii aggregates.

`qcheck/` is in `.Rbuildignore` — it ships with neither the package nor the
app.

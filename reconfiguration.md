# Reconfiguring `cgjrdata` for the new CGJR taxonomy

## Context

The team has replaced CGJR's cluster/subcluster structure entirely. This
document specifies the new taxonomy in full, the architectural approach for
rebuilding `cgjrdata` around it, and several traps found during prior
analysis that need to be designed around, not rediscovered the hard way.

**Read this whole document before writing any code.** Several sections later
on depend on decisions made earlier (the crosswalk-table approach in
particular supersedes the current file structure entirely).

## Why we are not just editing the existing 13 build scripts

`cgjrdata` currently has one hand-written `.r` script per subcluster in
`data-raw/source/<cluster>/<subcluster>.r`, each hardcoding a character
vector of `cliaretl` variable names and calling `extract_cliar_data()`
directly. That approach is being retired, for reasons found during a review
of the current package (not new to this task, but the motivating reason
we're restructuring rather than just relabeling):

- Six of the *current* subclusters' hand-picked indicator lists violate
  `cliaretl::db_variables_final`'s own `benchmark_dynamic_family_aggregate`
  eligibility flag — indicators flagged `"No"` for family/subcluster
  aggregation were included anyway, because the hardcoded vectors have no
  connection to that metadata at all.
- The old taxonomy happened to be a 1:1 relabeling of `cliaretl`'s own
  `family_name` column, which is **no longer true** of the new taxonomy (see
  below) — indicators now get split across subclusters, merged across old
  family boundaries, and in one case reused across two unrelated subclusters.
  A hardcoded-vector-per-script approach cannot express this cleanly or
  validate itself.

**The fix: one explicit crosswalk table, not per-subcluster scripts.**
Every indicator's assignment to a cluster/subcluster/(sub-subcluster) lives
in a single tibble, validated against `cliaretl`'s eligibility flags at
build time. See "Implementation plan" below.

## The new taxonomy, in full

Source: World Bank Governance CLIAR indicator catalogue (linked per-subcluster
below), as specified by the team. Indicator descriptions and source datasets
are as given; **variable codes marked `[VERIFY]` have not been confirmed
against live `cliaretl::db_variables_final` — match by fuzzy text search on
the `description`/`description_short` columns, do not guess a code.** Codes
without `[VERIFY]` were confirmed directly against `cliaretl` source earlier
in this project and can be trusted, but re-verify counts/completeness
against the live table regardless — CLIAR's own indicator descriptions have
at least one known internal inconsistency (flagged under PFM below).

### Cluster 1 — Institutional Environment

**Subcluster: Degree of Integrity**
| # | Indicator | Source | Variable (best-known) |
|---|---|---|---|
| 1 | Absence of corruption | WJP | `wjp_rol_2` |
| 2 | Public sector corruption | V-DEM | `vdem_core_v2x_pubcorr` |
| 3 | Executive corruption | V-DEM | `vdem_core_v2x_execorr` |
| 4 | Legislative corruption | V-DEM | `vdem_core_v2lgcrrpt` |
| 5 | Regulations applied/enforced without improper influence | WJP | `wjp_rol_6_2` |

**Subcluster: Transparency and Accountability**
| # | Indicator | Source | Variable (best-known) |
|---|---|---|---|
| 1 | Right to information | WJP | `wjp_rol_3_2` |
| 2 | Publicized laws and government data | WJP | `wjp_rol_3_1` |
| 3 | Open Budget Index | Open Budget Survey | `ibp_obs_obi` |
| 4 | Complaint mechanisms | WJP | `wjp_rol_3_4` |
| 5 | Digital Citizen Engagement Index | GTMI | `wb_gtmi_dcei` |

> **Note:** `wb_gtmi_dcei` belongs to `cliaretl`'s "Digital and Data
> Institutions" family, not any Transparency-related family. This is one of
> the taxonomy's genuine cross-family reuses — the crosswalk table must be
> able to represent one variable appearing in a subcluster that isn't its
> `cliaretl` family, and this is a real example, not a hypothetical to guard
> against.

**Subcluster: Justice and Rule of Law**
| # | Indicator | Source | Variable (best-known) |
|---|---|---|---|
| 1 | Judicial accountability | V-DEM | `vdem_core_v2juaccnt` |
| 2 | Independent judiciary | BTI | `bs_bti_q3_2` |
| 3 | High court independence | V-DEM | `vdem_core_v2juhcind` |
| 4 | Judicial branch corruption | WJP | `wjp_rol_2_2` |
| 5 | Lower court independence | V-DEM | `vdem_core_v2juncind` |
| 6 | Fair trial | Global State of Democracy | `idea_gsod_v_21_05` |
| 7 | Expropriation without lawful process/adequate compensation | WJP | `wjp_rol_6_6` (was numbered `6.6` in older WJP methodology; WJP has since renumbered this to `6.5` — confirm which version `cliaretl`'s current WJP pull uses) |
| 8 | Due process of law and rights of the accused | WJP | `[VERIFY]` — plausibly `wjp_rol_4_3`, NOT `wjp_rol_8_2` (see WJP warning below) |
| 9 | Alternative dispute resolution mechanisms | WJP | `wjp_rol_7_7` |
| 10 | People can access and afford civil justice | WJP | `wjp_rol_7_1` — **see WJP warning below, this one is dangerous** |
| 11 | Civil justice is effectively enforced | WJP | `wjp_rol_7_6` |
| 12 | Civil justice is not subject to unreasonable delays | WJP | `wjp_rol_7_5` |
| 13 | Criminal adjudication system is timely and effective | WJP | `wjp_rol_8_2` — **see WJP warning below, this one is dangerous** |
| 14 | Criminal investigation system is effective | WJP | `wjp_rol_8_1` |
| 15 | Criminal system is impartial | WJP | `wjp_rol_8_4` |
| 16 | Access to justice for men | V-DEM | `vdem_core_v2clacjstm` |
| 17 | Access to justice for women | V-DEM | `vdem_core_v2clacjstw` |

> ### ⚠️ WJP mislabeling warning — read before wiring up indicators 8, 10, 13
>
> Earlier work on this project found that `cliaretl::db_variables_final`'s
> **historical** entries for `wjp_rol_7_1` and `wjp_rol_8_2` are mislabeled:
> their `description` text is actually the **Factor 7 / Factor 8 overall
> composite score** (all subfactors concatenated), not the genuine narrow
> subfactor. A fresh WJP pull was built separately during this project (an
> object/table referred to as `wjp` in prior work, with roxygen docs already
> written for it) that has the **correct, narrow** subfactor-level values
> under these same column names.
>
> **Action required:** before using `wjp_rol_7_1` or `wjp_rol_8_2` (rows 10
> and 13 above) in the new crosswalk, confirm which version of these two
> columns `cliaretl`'s *current* `closeness_to_frontier_dynamic` panel
> actually contains — the old mislabeled composite, or the corrected narrow
> version. If `cliaretl` hasn't been updated with the corrected WJP pull yet,
> **do not use these two columns from `cliaretl` as-is** — they will not
> mean what the new taxonomy says they mean. Flag this back rather than
> silently wiring in a value that looks plausible but is the wrong
> granularity.
>
> Indicator 8 ("Due process of the law and rights of the accused") is
> **not** the WJP Factor 8 composite either (which is what old `wjp_rol_8_2`
> actually contained) — cross-check its wording against WJP's real subfactor
> list; `wjp_rol_4_3`'s description ("basic rights of criminal suspects...
> presumption of innocence...") is the closest textual match found so far,
> but this was not independently confirmed and needs verification.

### Cluster 2 — Efficiency and Effectiveness of Core Governance Functions

**Subcluster: Public Financial Management** *(three-level hierarchy — see
"PFM's extra nesting level" below)*

*Sub-subcluster: Budget Cycle and Fiscal Planning*
| # | Indicator | Source | Variable (best-known) |
|---|---|---|---|
| 1 | Fiscal stability | BTI | `bs_bti_q8_2` |
| 2 | Debt Transparency Index | CLIAR (own composite) | `wb_debt_transp_index` |
| 3 | PFM management information systems | CLIAR (own composite) | `wb_gtmi_pfm_mis` |
| 4 | Budget documentation | PEFA PI-5 | `wb_pefa_pi_2016_05` |
| 5 | Transfers to subnational governments | PEFA PI-7 | `wb_pefa_pi_2016_07` |
| 6 | Performance info for service delivery | PEFA PI-8 | `wb_pefa_pi_2016_08` |
| 7 | Fiscal risk reporting | PEFA PI-10 | `wb_pefa_pi_2016_10` |
| 9 | Public asset management | PEFA PI-12 | `wb_pefa_pi_2016_12` |
| 10 | Debt management | PEFA PI-13 | `wb_pefa_pi_2016_13` |
| 11 | Macro/fiscal forecasting | PEFA PI-14 | `wb_pefa_pi_2016_14` |
| 12 | Fiscal strategy | PEFA PI-15 | `wb_pefa_pi_2016_15` |
| 13 | Medium-term expenditure budgeting | PEFA PI-16 | `wb_pefa_pi_2016_16` |
| 14 | Budget preparation process | PEFA PI-17 | `wb_pefa_pi_2016_17` |
| 15 | Legislative scrutiny of budgets | PEFA PI-18 | `wb_pefa_pi_2016_18` |
| 18 | Predictability of in-year resource allocation | PEFA PI-21 `[VERIFY]` | `wb_pefa_pi_2016_21` |
| 19 | Expenditure arrears | PEFA PI-22 | `wb_pefa_pi_2016_22` |
| 20 | Payroll controls | PEFA PI-23 | `wb_pefa_pi_2016_23` |
| 21 | Procurement | PEFA PI-24 | `wb_pefa_pi_2016_24` |
| 22 | Internal controls on non-salary expenditure | PEFA PI-25 | `wb_pefa_pi_2016_25` |
| 23 | Internal audit effectiveness | PEFA PI-26 | `wb_pefa_pi_2016_26` |
| 24 | Financial data integrity | PEFA PI-27 `[VERIFY]` | `wb_pefa_pi_2016_27` |
| 25 | In-year budget reports | PEFA PI-28 `[VERIFY]` | `wb_pefa_pi_2016_28` |
| 26 | Annual financial reports | PEFA PI-29 | `wb_pefa_pi_2016_29` |
| 28 | External audit | PEFA PI-30 | `wb_pefa_pi_2016_30` |

> **Known documentation inconsistency:** `cliaretl`'s existing roxygen docs
> describe *both* `wb_pefa_pi_2016_27` and `wb_pefa_pi_2016_28` with nearly
> identical text about "treasury bank accounts... regularly reconciled" —
> that's the definition of standard PEFA PI-27 specifically, and PI-28 is
> normally "in-year budget reports," a different topic. This looks like a
> copy-paste error in `cliaretl`'s own documentation, not a data problem —
> but verify what `wb_pefa_pi_2016_28` actually *contains* (not just its
> docstring) before trusting the PI-28 mapping above.
>
> **Item numbering gaps (8, 16, 17, 27) are as given by the team, not a
> transcription error** — those PEFA indicators were apparently deliberately
> excluded from this sub-subcluster; do not try to fill them in.

*Sub-subcluster: Domestic Revenue Mobilization* — **no `cliaretl` indicators
exist for this topic.** Zero crosswalk rows. Dashboard should render this
sub-subtab with "Indicators coming soon" messaging (this is a `cgjrapp`-side
concern, not a `cgjrdata` one, but the crosswalk needs to represent an
intentionally-empty sub-subcluster cleanly, not error on it).

*Sub-subcluster: Public Procurement* — same as above, zero rows, no
`cliaretl` coverage.

*Sub-subcluster: Public Investment Management (PIM)* — same as above, zero
rows, no `cliaretl` coverage.

**Subcluster: Public Sector HRM**
| # | Indicator | Source | Variable (best-known) |
|---|---|---|---|
| 1 | Rigorous and impartial public administration | V-DEM | `vdem_core_v2clrspct` `[VERIFY]` |
| 2 | Efficient use of assets | BTI | `bs_bti_q15_1` `[VERIFY]` |
| 3 | Criteria for appointment decisions in state administration | V-DEM | `vdem_core_v2stcritrecadm` `[VERIFY]` |
| 4 | Access to state jobs by political group | V-DEM | `vdem_core_v2peasjpol` `[VERIFY]` |
| 5 | Access to state jobs by socioeconomic position | V-DEM | `vdem_core_v2peasjsoecon` `[VERIFY]` |

**Subcluster: Digital and Data**
| # | Indicator | Source | Variable (best-known) |
|---|---|---|---|
| 1 | Core Government Systems Index (CGSI) | GTMI | `wb_gtmi_cgsi` |
| 2 | GovTech Enablers Index (GTEI) | GTMI | `wb_gtmi_gtei` |
| 3 | Public Service Delivery Index (PSDI) | GTMI | `wb_gtmi_psdi` |
| 4 | Censuses and surveys | SPI | `[VERIFY]` — old `cliaretl` docs reference `wb_spi_census_and_survey_index`, but that variable was found missing from a recent extraction pull; confirm current status |
| 5 | Standards and methods | SPI | `[VERIFY]` — same caveat, old docs reference `wb_spi_std_and_methods` |

### Cluster 3 — Efficiency and Effectiveness beyond core governance functions

**Subcluster: Market Regulatory Institutions**
| # | Indicator | Source | Variable (best-known) |
|---|---|---|---|
| 1 | Property rights | V-DEM | `vdem_core_v2xcl_prpty` |
| 2 | Competition policy | BTI | `bs_bti_q7_2` |
| 3 | Regulatory enforcement | WJP | `wjp_rol_6` |
| 4 | Efficiency of the clearance process | WB LPI | `[VERIFY]` — old `cliaretl` docs reference `wb_lpi_lp_lpi_cust_xq`, but a recent extraction returned this under `wb_wdi_lp_lpi_cust_xq` instead (extra `wdi_` prefix) — confirm current column name and update `db_variables_final` to match if needed |
| 5 | Bank concentration (%) | GFDB | `[VERIFY]` |
| 6 | Women, Business and Law Entrepreneurship Index | WBL | `wb_wbl_entrepreneurship` |

**Subcluster: Service Delivery**
| # | Indicator | Source | Variable (best-known) |
|---|---|---|---|
| 1 | Access to public services by political group | V-DEM | `vdem_core_v2peapspol` |
| 2 | Access to public services by socioeconomic position | V-DEM | `vdem_core_v2peapsecon` |
| 3 | Access to public services by gender | V-DEM | `vdem_core_v2peapsgen` |
| 4 | Pregnant women receiving prenatal care (%) | WDI | `wdi_shstaanvczs` `[VERIFY]` |
| 5 | Births attended by skilled health staff (%) | WDI | `wdi_shstabrtczs` `[VERIFY]` |
| 6 | Completeness of birth registration (%) | WDI | `wdi_spregbrthzs` `[VERIFY]` |
| 7 | Pupil-teacher ratio, primary | WDI | `wdi_seprmenrltczs` `[VERIFY]` |
| 8 | Pupil-teacher ratio, secondary | WDI | `wdi_sesecenrltczs` `[VERIFY]` |
| 9 | Trained teachers, pre-primary (%) | WDI | `wdi_sepretcaqzs` `[VERIFY]` |
| 10 | Trained teachers, primary (%) | WDI | `wdi_seprmtcaqzs` `[VERIFY]` |
| 11 | Trained teachers, secondary (%) | WDI | `wdi_sesectcaqzs` `[VERIFY]` |

**Subcluster: State-Owned Enterprises Governance**
| # | Indicator | Source | Variable (best-known) |
|---|---|---|---|
| 1 | Scope of state-owned enterprises | OECD PMR | `[VERIFY]` |
| 2 | Government involvement in network sectors | OECD PMR | `[VERIFY]` |
| 3 | Direct control over business enterprises | OECD PMR | `[VERIFY]` |
| 4 | Governance of state-owned enterprises | OECD PMR | `oecd_pmr_2018_2_2_1` or `oecd_pmr_2018_2_2_2` `[VERIFY which]` |
| 5 | Price controls | OECD PMR | `[VERIFY]` |
| 6 | Use of command-and-control regulation | OECD PMR | `[VERIFY]` |

> Note: earlier project work found `oecd_pmr_2018_2_2_1` is flagged
> `benchmark_dynamic_indicator = "No"` in `db_variables_final` — if the
> "Governance of state-owned enterprises" indicator resolves to this code,
> it is **not eligible for the dynamic panel at all**. Flag this rather than
> silently including it; the sub-subcluster equivalent for SOE governance
> may need the same "coming soon" treatment as PFM's three empty
> sub-subclusters if none of its six indicators turn out to be dynamically
> eligible.

### Cluster 4 — Context

**Subcluster: Political Institutions and Social Cohesion**
| # | Indicator | Source | Variable (best-known) |
|---|---|---|---|
| 1 | Constraints on government powers | WJP | `wjp_rol_1` |
| 2 | Separation of powers | BTI | `bs_bti_q3_1` |
| 3 | Legislative constraints on the executive index | V-DEM | `vdem_core_v2xlg_legcon` `[VERIFY]` |
| 4 | Free and fair elections | BTI | `bs_bti_q2_1` |
| 5 | Political rights | Freedom House | `fh_fiw_pr_rating` |
| 6 | Civil liberties | Freedom House | `fh_fiw_cl_rating` |
| 7 | Association and assembly rights | BTI | `bs_bti_q2_3` |
| 8 | Political polarization | V-DEM | `vdem_core_v2cacamps` `[VERIFY]` |
| 9 | Press freedom | Press Freedom Index | `rwb_pfi_index` |
| 10 | Civil society participation | V-DEM | `vdem_core_v2x_cspart` `[VERIFY]` |
| 11 | CSO entry and exit | V-DEM | `vdem_core_v2cseeorgs` `[VERIFY]` |
| 12 | CSO repression | V-DEM | `vdem_core_v2csreprss` `[VERIFY]` |
| 13 | Engaged society | V-DEM | `vdem_core_v2dlengage` `[VERIFY]` |
| 14 | Freedom of assembly and association | WJP | `wjp_rol_4_7` |
| 15 | Freedom of academic and cultural expression | V-DEM | `[VERIFY]` |
| 16 | Freedom of belief and religion | WJP | `wjp_rol_4_5` |
| 17 | Freedom of opinion and expression | WJP | `[VERIFY]` — likely `wjp_rol_4_4`'s underlying concept but description differs slightly, confirm |
| 18 | Freedom from arbitrary interference with privacy | WJP | `wjp_rol_4_6` |
| 19 | Freedom of discussion for men | V-DEM | `vdem_core_v2cldiscm` `[VERIFY]` |
| 20 | Freedom of discussion for women | V-DEM | `vdem_core_v2cldiscw` `[VERIFY]` |
| 21 | Women's Social Equality Index | CLIAR (own composite) | `[VERIFY]` |

**Subcluster: Social Cohesion, Norms and Cooperation**
| # | Indicator | Source | Variable (best-known) |
|---|---|---|---|
| 1 | Power distributed by socioeconomic position | V-DEM | `vdem_core_v2pepwrses` |
| 2 | Power distributed by social group | V-DEM | `vdem_core_v2pepwrsoc` |
| 3 | Power distributed by gender | V-DEM | `vdem_core_v2pepwrgen` |
| 4 | Lower chamber gender quota | V-DEM | `vdem_core_v2lgqugen` |
| 5 | Women Political Empowerment Index | V-DEM | `vdem_core_v2x_gender` |

> Note: this subcluster's 5 indicators are the ones that stayed grouped
> together from the old "Social Institutions" family; the other 16 members
> of that same old family moved into "Political Institutions and Social
> Cohesion" above. This is the taxonomy's one confirmed **split** of a
> single old family across two new subclusters — worth double-checking no
> old-family member got dropped or double-counted across the two new
> groupings during the crosswalk build.

## PFM's extra nesting level

`cgjrdata`'s current data structure is `ctfdata_list[[cluster]][[subcluster]]`
— two levels. PFM now needs three: `ctfdata_list[[cluster]][[subcluster]][[sub_subcluster]]`.
Two ways to handle this, pick one deliberately rather than defaulting into
whichever is easiest to hack in:

1. **Genericize `compute_scores.R`'s functions to handle arbitrary nesting
   depth** — `add_subcluster_score()`, `score_ctfdata_list()`, and
   `compute_cluster_averages()` currently assume exactly two levels
   (`lapply` over cluster, then `lapply` over subcluster). Recursive nesting
   support is the more robust long-term fix if more sub-subclusters are
   likely to appear elsewhere later.
2. **Special-case PFM only** — keep the two-level functions as-is, and give
   PFM's tibble in `ctfdata_list` an extra internal structure specific to
   it (e.g. `ctfdata_list$core_governance$pfm` holds a *named list* of four
   sub-subcluster tibbles rather than a single tibble), with a PFM-specific
   scoring step layered on top. Simpler short-term, but creates an
   inconsistent shape other code has to special-case forever.

**Recommendation: option 1.** Given three of PFM's four sub-subclusters are
currently empty and may be populated later, and given no other cluster in
this taxonomy has this problem today but nothing guarantees that stays true,
generic recursive support is worth the one-time cost. But this is a real
design call — flag back if there's a reason to prefer option 2 (e.g. if PFM
is confirmed to be the *only* place this will ever be needed).

## Implementation plan

1. **Build the crosswalk table** as its own data object — e.g.
   `data-raw/source/00b-cgjr-taxonomy-crosswalk.R` producing a tibble with
   columns `variable`, `cluster`, `subcluster`, `sub_subcluster` (`NA` except
   for PFM rows). Populate from the tables above, resolving every `[VERIFY]`
   entry against live `cliaretl::db_variables_final$description`/
   `description_short` text — do not guess. Where an indicator's correct
   code genuinely cannot be found, leave it out and flag it rather than
   including a best-guess.

2. **Validate the crosswalk against eligibility flags at build time.** For
   every row, check `cliaretl::db_variables_final$benchmark_dynamic_indicator`
   (must be `"Yes"` for the variable to exist in the dynamic panel at all)
   and `benchmark_dynamic_family_aggregate` (must be `"Yes"` or `"Partial"`
   for it to be safely averaged into a subcluster score). Emit a clear
   warning (indicator, subcluster, which flag failed) for any row that
   fails either check — do not silently drop or silently include.

3. **Replace the 13 per-subcluster build scripts with one generic build
   script** that: pulls `cliaretl::closeness_to_frontier_dynamic` once,
   joins the crosswalk, and `group_by(cluster, subcluster, sub_subcluster)`
   + nests to produce `ctfdata_list`'s new shape. This replaces essentially
   all of `data-raw/source/1.institutional_environment/`,
   `2.political_institutions/`, `3.center_of_government/`,
   `4.sectors_or_service_delivery/` — confirm with the team before deleting
   the old scripts outright, but they should no longer be the source of
   truth once this is done.

4. **Update `compute_scores.R`** per the PFM nesting decision above.

5. **Update `R/data.R`** roxygen docs for `ctfdata_list`/`institutional_averages_tbl`
   to describe the new 4-cluster taxonomy and, if option 1 above is chosen,
   the optional third nesting level.

6. **Update `tests/testthat/`** — `test-compute-scores.R` and
   `test-aggregate-groups.R` currently assume the old two-level structure
   and the old cluster names; both need updating for the new taxonomy and
   (if applicable) three-level nesting.

7. **Leave `aggregate_groups.R` (region/income aggregation) structurally
   alone for now** — its logic doesn't depend on the taxonomy's specific
   cluster/subcluster names, just on `ctfdata_list`'s shape, so it should
   keep working once the nesting-depth question is resolved, but re-test it
   against the new structure regardless.

## What NOT to change

- `extract_cliar_data()` in `R/extract_cliar_data.R` — still a fine, simple
  accessor into `cliaretl` data by variable name; the crosswalk changes
  *what* gets requested, not how requests are made.
- `aggregate_groups.R`'s core logic (mean-based region/income aggregation) —
  out of scope for this task; a separate, still-open question about whether
  this should switch to median (matching `cliaretl`'s own
  `group_ctf_static`/`group_ctf_dynamic` convention) is tracked separately
  and not part of this restructuring.
- Package `DESCRIPTION`/dependency structure — no changes needed here.

## When done

Run the full test suite and confirm:
- Every crosswalk row resolves to a real, eligible `cliaretl` column (no
  silent NAs from a bad join).
- The three PFM "coming soon" sub-subclusters produce an empty-but-valid
  structure (not an error) when built.
- `devtools::check()` is clean.

Report back with: the final crosswalk table (for review — several rows are
marked `[VERIFY]` above and need eyes on them before being trusted), which
PFM nesting option was implemented and why, and a list of any indicators
from the taxonomy above that could not be resolved to a real `cliaretl`
column.
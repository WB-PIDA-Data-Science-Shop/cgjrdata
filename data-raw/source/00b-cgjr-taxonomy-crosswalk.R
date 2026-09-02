##############################################################################
################## CGJR TAXONOMY CROSSWALK (single source of truth) ###########
##############################################################################
# Builds two package data objects that together define the *new* CGJR
# taxonomy and every indicator's place in it:
#
#   cgjr_taxonomy   one row per LEAF node (subcluster, or sub-subcluster for
#                   PFM). Enumerates the full hierarchy — including
#                   intentionally-empty nodes — with display names and order.
#
#   cgjr_crosswalk  one row per (indicator x leaf node) assignment. Carries
#                   the human indicator name, the stated source, the resolved
#                   `cliaretl` variable code (NA when unresolved), and a note.
#
# Every `variable` is resolved against live
# `cliaretl::db_variables_final$description` / `description_short` — no codes
# are guessed. Rows that could not be resolved keep `variable = NA` and are
# recorded here so the taxonomy stays a complete record; the build functions
# drop NA-variable rows, and `validate_crosswalk()` reports them.
#
# See reconfiguration.md for the taxonomy specification and the traps this
# design works around.
##############################################################################

library(dplyr)
library(tibble)

# ---------------------------------------------------------------------------
# 1.  Leaf-node taxonomy
# ---------------------------------------------------------------------------
# snake_case keys are the list keys used in ctfdata_list / rawdata_list.
# `*_name` are display labels. `sub_subcluster` is NA for every leaf except
# the four Public Financial Management sub-subclusters.

cgjr_taxonomy <- tibble::tribble(
  ~cluster,                           ~cluster_num, ~cluster_name,
  ~subcluster,                        ~subcluster_num, ~subcluster_name,
  ~sub_subcluster,                    ~sub_subcluster_num, ~sub_subcluster_name,

  # --- Cluster 1: Institutional Environment --------------------------------
  "institutional_environment", 1L, "Institutional Environment",
  "degree_of_integrity", 1L, "Degree of Integrity",
  NA_character_, NA_integer_, NA_character_,

  "institutional_environment", 1L, "Institutional Environment",
  "transparency_and_accountability", 2L, "Transparency and Accountability",
  NA_character_, NA_integer_, NA_character_,

  "institutional_environment", 1L, "Institutional Environment",
  "justice_and_rule_of_law", 3L, "Justice and Rule of Law",
  NA_character_, NA_integer_, NA_character_,

  # --- Cluster 2: Efficiency & Effectiveness of Core Governance Functions --
  "core_governance_functions", 2L, "Efficiency and Effectiveness of Core Governance Functions",
  "public_financial_management", 1L, "Public Financial Management",
  "budget_cycle_and_fiscal_planning", 1L, "Budget Cycle and Fiscal Planning",

  "core_governance_functions", 2L, "Efficiency and Effectiveness of Core Governance Functions",
  "public_financial_management", 1L, "Public Financial Management",
  "domestic_revenue_mobilization", 2L, "Domestic Revenue Mobilization",

  "core_governance_functions", 2L, "Efficiency and Effectiveness of Core Governance Functions",
  "public_financial_management", 1L, "Public Financial Management",
  "public_procurement", 3L, "Public Procurement",

  "core_governance_functions", 2L, "Efficiency and Effectiveness of Core Governance Functions",
  "public_financial_management", 1L, "Public Financial Management",
  "public_investment_management", 4L, "Public Investment Management (PIM)",

  "core_governance_functions", 2L, "Efficiency and Effectiveness of Core Governance Functions",
  "public_sector_hrm", 2L, "Public Sector HRM",
  NA_character_, NA_integer_, NA_character_,

  "core_governance_functions", 2L, "Efficiency and Effectiveness of Core Governance Functions",
  "digital_and_data", 3L, "Digital and Data",
  NA_character_, NA_integer_, NA_character_,

  # --- Cluster 3: Efficiency & Effectiveness beyond core governance --------
  "beyond_core_governance_functions", 3L, "Efficiency and Effectiveness beyond Core Governance Functions",
  "market_regulatory_institutions", 1L, "Market Regulatory Institutions",
  NA_character_, NA_integer_, NA_character_,

  "beyond_core_governance_functions", 3L, "Efficiency and Effectiveness beyond Core Governance Functions",
  "service_delivery", 2L, "Service Delivery",
  NA_character_, NA_integer_, NA_character_,

  "beyond_core_governance_functions", 3L, "Efficiency and Effectiveness beyond Core Governance Functions",
  "soe_governance", 3L, "State-Owned Enterprises Governance",
  NA_character_, NA_integer_, NA_character_,

  # --- Cluster 4: Context -------------------------------------------------
  "context", 4L, "Context",
  "political_institutions_and_social_cohesion", 1L, "Political Institutions and Social Cohesion",
  NA_character_, NA_integer_, NA_character_,

  "context", 4L, "Context",
  "social_cohesion_norms_and_cooperation", 2L, "Social Cohesion, Norms and Cooperation",
  NA_character_, NA_integer_, NA_character_,
)


# ---------------------------------------------------------------------------
# 2.  Indicator -> leaf crosswalk
# ---------------------------------------------------------------------------
# Helper to keep the per-subcluster blocks terse. `sub_sub` defaults to NA.

xw <- function(cluster, subcluster, sub_subcluster = NA_character_, ...,
               .rows) {
  .rows |>
    dplyr::mutate(
      cluster        = cluster,
      subcluster     = subcluster,
      sub_subcluster = sub_subcluster,
      indicator_num  = dplyr::row_number()
    ) |>
    dplyr::relocate(cluster, subcluster, sub_subcluster, indicator_num)
}

r <- function(...) tibble::tribble(~indicator, ~source, ~variable, ~note, ...)

cgjr_crosswalk <- dplyr::bind_rows(

  # === Cluster 1 =========================================================

  xw("institutional_environment", "degree_of_integrity", .rows = r(
    "Absence of corruption",                                        "WJP",   "wjp_rol_2",              NA,
    "Public sector corruption",                                     "V-Dem", "vdem_core_v2x_pubcorr",  NA,
    "Executive corruption",                                         "V-Dem", "vdem_core_v2x_execorr",  NA,
    "Legislative corruption",                                       "V-Dem", "vdem_core_v2lgcrrpt",    NA,
    "Regulations applied/enforced without improper influence",      "WJP",   "wjp_rol_6_2",            NA
  )),

  xw("institutional_environment", "transparency_and_accountability", .rows = r(
    "Right to information",                                         "WJP",   "wjp_rol_3_2",  NA,
    "Publicized laws and government data",                          "WJP",   "wjp_rol_3_1",  NA,
    "Open Budget Index",                                            "Open Budget Survey", "ibp_obs_obi", NA,
    "Complaint mechanisms",                                         "WJP",   "wjp_rol_3_4",  NA,
    "Digital Citizen Engagement Index",                             "GTMI",  "wb_gtmi_dcei",
      "cliaretl family = 'Digital and Data Institutions' (cross-family reuse; benchmark_dynamic_family_aggregate = Yes)"
  )),

  xw("institutional_environment", "justice_and_rule_of_law", .rows = r(
    "Judicial accountability",                                      "V-Dem", "vdem_core_v2juaccnt",  NA,
    "Independent judiciary",                                        "BTI",   "bs_bti_q3_2",          NA,
    "High court independence",                                      "V-Dem", "vdem_core_v2juhcind",  NA,
    "Judicial branch corruption",                                   "WJP",   "wjp_rol_2_2",          NA,
    "Lower court independence",                                     "V-Dem", "vdem_core_v2juncind",  NA,
    "Fair trial",                                                   "Global State of Democracy", "idea_gsod_v_21_05", NA,
    "Expropriation without lawful process/adequate compensation",   "WJP",   "wjp_rol_6_6",
      "WJP renumbered 6.6 -> 6.5 in newer methodology; confirm cliaretl's current WJP pull vintage",
    "Due process of law and rights of the accused",                "WJP",   "wjp_rol_4_3",
      "Resolved by text match: var_name 'basic rights of criminal suspects... presumption of innocence... freedom from arbitrary arrest'. NOT wjp_rol_8_2.",
    "Alternative dispute resolution mechanisms",                    "WJP",   "wjp_rol_7_7",  NA,
    "People can access and afford civil justice",                   "WJP",   "wjp_rol_7_1",
      "WJP mislabel trap: historical db_variables_final entries carried the Factor 7 composite. In THIS cliaretl build var_name = 'People can access and afford civil justice' and the description is the narrow subfactor - appears corrected, but confirm against the standalone `wjp` pull (not present in this cliaretl).",
    "Civil justice is effectively enforced",                        "WJP",   "wjp_rol_7_6",  NA,
    "Civil justice is not subject to unreasonable delays",          "WJP",   "wjp_rol_7_5",  NA,
    "Criminal adjudication system is timely and effective",         "WJP",   NA_character_,
      "UNRESOLVED. reconfiguration.md flags wjp_rol_8_2 as dangerous; in this cliaretl var_name/description for wjp_rol_8_2 = 'criminal investigation system' (duplicates row 14). WJP 8.3 is not in closeness_to_frontier_dynamic. The corrected standalone `wjp` pull is not available in this cliaretl. Excluded pending team input.",
    "Criminal investigation system is effective",                   "WJP",   "wjp_rol_8_1",  NA,
    "Criminal system is impartial",                                 "WJP",   "wjp_rol_8_4",  NA,
    "Access to justice for men",                                    "V-Dem", "vdem_core_v2clacjstm", NA,
    "Access to justice for women",                                  "V-Dem", "vdem_core_v2clacjstw", NA
  )),

  # === Cluster 2 =========================================================

  xw("core_governance_functions", "public_financial_management",
     "budget_cycle_and_fiscal_planning", .rows = r(
    "Fiscal stability",                            "BTI",       "bs_bti_q8_2",          NA,
    "Debt Transparency Index",                     "CLIAR",     "wb_debt_transp_index", NA,
    "PFM management information systems",          "CLIAR/GTMI","wb_gtmi_pfm_mis",      NA,
    "Budget documentation",                        "PEFA PI-5", "wb_pefa_pi_2016_05",   NA,
    "Transfers to subnational governments",        "PEFA PI-7", "wb_pefa_pi_2016_07",   NA,
    "Performance info for service delivery",       "PEFA PI-8", "wb_pefa_pi_2016_08",   NA,
    "Fiscal risk reporting",                       "PEFA PI-10","wb_pefa_pi_2016_10",   NA,
    "Public asset management",                     "PEFA PI-12","wb_pefa_pi_2016_12",   NA,
    "Debt management",                             "PEFA PI-13","wb_pefa_pi_2016_13",   NA,
    "Macro/fiscal forecasting",                    "PEFA PI-14","wb_pefa_pi_2016_14",   NA,
    "Fiscal strategy",                             "PEFA PI-15","wb_pefa_pi_2016_15",   NA,
    "Medium-term expenditure budgeting",           "PEFA PI-16","wb_pefa_pi_2016_16",   NA,
    "Budget preparation process",                  "PEFA PI-17","wb_pefa_pi_2016_17",   NA,
    "Legislative scrutiny of budgets",             "PEFA PI-18","wb_pefa_pi_2016_18",   NA,
    "Predictability of in-year resource allocation","PEFA PI-21","wb_pefa_pi_2016_21",  NA,
    "Expenditure arrears",                         "PEFA PI-22","wb_pefa_pi_2016_22",   NA,
    "Payroll controls",                            "PEFA PI-23","wb_pefa_pi_2016_23",   NA,
    "Procurement",                                 "PEFA PI-24","wb_pefa_pi_2016_24",   NA,
    "Internal controls on non-salary expenditure", "PEFA PI-25","wb_pefa_pi_2016_25",   NA,
    "Internal audit effectiveness",                "PEFA PI-26","wb_pefa_pi_2016_26",   NA,
    "Financial data integrity",                    "PEFA PI-27","wb_pefa_pi_2016_27",
      "cliaretl docstrings for PI-27 and PI-28 are near-identical (both describe PI-27 reconciliation). Values not independently verified.",
    "In-year budget reports",                      "PEFA PI-28","wb_pefa_pi_2016_28",
      "See PI-27 note - cliaretl docstring for PI-28 appears to be a copy-paste of PI-27; verify contents.",
    "Annual financial reports",                    "PEFA PI-29","wb_pefa_pi_2016_29",   NA,
    "External audit",                              "PEFA PI-30","wb_pefa_pi_2016_30",   NA
  )),

  xw("core_governance_functions", "public_sector_hrm", .rows = r(
    "Rigorous and impartial public administration",                  "V-Dem", "vdem_core_v2clrspct",       NA,
    "Efficient use of assets",                                       "BTI",   "bs_bti_q15_1",             NA,
    "Criteria for appointment decisions in state administration",    "V-Dem", "vdem_core_v2stcritrecadm", NA,
    "Access to state jobs by political group",                       "V-Dem", "vdem_core_v2peasjpol",     NA,
    "Access to state jobs by socioeconomic position",               "V-Dem", "vdem_core_v2peasjsoecon",  NA
  )),

  xw("core_governance_functions", "digital_and_data", .rows = r(
    "Core Government Systems Index (CGSI)",  "GTMI", "wb_gtmi_cgsi",                  NA,
    "GovTech Enablers Index (GTEI)",         "GTMI", "wb_gtmi_gtei",                  NA,
    "Public Service Delivery Index (PSDI)",  "GTMI", "wb_gtmi_psdi",                  NA,
    "Censuses and surveys",                  "SPI",  "wb_spi_census_and_survey_index",
      "Present in this cliaretl's closeness_to_frontier_dynamic (earlier extraction had reported it missing).",
    "Standards and methods",                 "SPI",  "wb_spi_std_and_methods",        NA
  )),

  # === Cluster 3 =========================================================

  xw("beyond_core_governance_functions", "market_regulatory_institutions", .rows = r(
    "Property rights",                                       "V-Dem", "vdem_core_v2xcl_prpty",   NA,
    "Competition policy",                                    "BTI",   "bs_bti_q7_2",             NA,
    "Regulatory enforcement",                                "WJP",   "wjp_rol_6",               NA,
    "Efficiency of the clearance process",                   "WB LPI","wb_lpi_lp_lpi_cust_xq",
      "Resolved to wb_lpi_lp_lpi_cust_xq (in db_variables_final and closeness_to_frontier_dynamic). No `wb_wdi_` prefixed variant exists in this cliaretl.",
    "Bank concentration (%)",                                "GFDB",  "wb_gfdb_oi_01",
      "Resolved by text match: 'assets of the three largest commercial banks as a share of total commercial banking assets'.",
    "Women, Business and Law Entrepreneurship Index",        "WBL",   "wb_wbl_entrepreneurship", NA
  )),

  xw("beyond_core_governance_functions", "service_delivery", .rows = r(
    "Access to public services by political group",          "V-Dem", "vdem_core_v2peapspol",  NA,
    "Access to public services by socioeconomic position",   "V-Dem", "vdem_core_v2peapsecon", NA,
    "Access to public services by gender",                   "V-Dem", "vdem_core_v2peapsgen",  NA,
    "Pregnant women receiving prenatal care (%)",            "WDI",   "wdi_shstaanvczs",       NA,
    "Births attended by skilled health staff (%)",           "WDI",   "wdi_shstabrtczs",       NA,
    "Completeness of birth registration (%)",                "WDI",   "wdi_spregbrthzs",       NA,
    "Pupil-teacher ratio, primary",                          "WDI",   "wdi_seprmenrltczs",     NA,
    "Pupil-teacher ratio, secondary",                        "WDI",   "wdi_sesecenrltczs",     NA,
    "Trained teachers, pre-primary (%)",                     "WDI",   "wdi_sepretcaqzs",       NA,
    "Trained teachers, primary (%)",                         "WDI",   "wdi_seprmtcaqzs",       NA,
    "Trained teachers, secondary (%)",                       "WDI",   "wdi_sesectcaqzs",       NA
  )),

  xw("beyond_core_governance_functions", "soe_governance", .rows = r(
    "Scope of state-owned enterprises",                      "OECD PMR", NA_character_,
      "UNRESOLVED. No distinct 'scope of SOE' code isolated in this cliaretl. OECD PMR codes are static-only.",
    "Government involvement in network sectors",             "OECD PMR", "oecd_pmr_2018_2_2_1",
      "Static-only (not in closeness_to_frontier_dynamic). Text match: 'restrictions on key network sector firms'.",
    "Direct control over business enterprises",              "OECD PMR", "oecd_pmr_2018_1_3",
      "Static-only. Text match: 'special voting rights by the government... constraints to sale of government stakes'.",
    "Governance of state-owned enterprises",                 "OECD PMR", NA_character_,
      "UNRESOLVED. reconfiguration.md flags oecd_pmr_2018_2_2_1 as benchmark_dynamic_indicator = No; used above for a different indicator. No dedicated SOE-governance code isolated.",
    "Price controls",                                        "OECD PMR", "oecd_pmr_2018_2_1",
      "Static-only. Text match: 'whether tariffs are regulated and whether there are laws and regulations that limit competition'.",
    "Use of command-and-control regulation",                 "OECD PMR", NA_character_,
      "UNRESOLVED. No command-and-control-specific code isolated in this cliaretl."
  )),

  # === Cluster 4 =========================================================

  xw("context", "political_institutions_and_social_cohesion", .rows = r(
    "Constraints on government powers",                      "WJP",   "wjp_rol_1",               NA,
    "Separation of powers",                                  "BTI",   "bs_bti_q3_1",             NA,
    "Legislative constraints on the executive index",        "V-Dem", "vdem_core_v2xlg_legcon",  NA,
    "Free and fair elections",                               "BTI",   "bs_bti_q2_1",             NA,
    "Political rights",                                      "Freedom House", "fh_fiw_pr_rating", NA,
    "Civil liberties",                                       "Freedom House", "fh_fiw_cl_rating", NA,
    "Association and assembly rights",                       "BTI",   "bs_bti_q2_3",             NA,
    "Political polarization",                                "V-Dem", "vdem_core_v2cacamps",     NA,
    "Press freedom",                                         "Press Freedom Index", "rwb_pfi_index", NA,
    "Civil society participation",                           "V-Dem", "vdem_core_v2x_cspart",    NA,
    "CSO entry and exit",                                    "V-Dem", "vdem_core_v2cseeorgs",    NA,
    "CSO repression",                                        "V-Dem", "vdem_core_v2csreprss",    NA,
    "Engaged society",                                       "V-Dem", "vdem_core_v2dlengage",    NA,
    "Freedom of assembly and association",                   "WJP",   "wjp_rol_4_7",             NA,
    "Freedom of academic and cultural expression",           "V-Dem", "vdem_core_v2clacfree",    NA,
    "Freedom of belief and religion",                        "WJP",   "wjp_rol_4_5",             NA,
    "Freedom of opinion and expression",                     "WJP",   "wjp_rol_4_4",
      "Resolved to wjp_rol_4_4 (var_name 'Freedom of opinion and expression').",
    "Freedom from arbitrary interference with privacy",      "WJP",   "wjp_rol_4_6",             NA,
    "Freedom of discussion for men",                         "V-Dem", "vdem_core_v2cldiscm",     NA,
    "Freedom of discussion for women",                       "V-Dem", "vdem_core_v2cldiscw",     NA,
    "Women's Social Equality Index",                         "CLIAR", "wb_wbl_social",
      "Resolved to wb_wbl_social (var_name \"Women's social equality index\"). cliaretl family = 'Social Institutions'."
  )),

  xw("context", "social_cohesion_norms_and_cooperation", .rows = r(
    "Power distributed by socioeconomic position",           "V-Dem", "vdem_core_v2pepwrses", NA,
    "Power distributed by social group",                     "V-Dem", "vdem_core_v2pepwrsoc", NA,
    "Power distributed by gender",                           "V-Dem", "vdem_core_v2pepwrgen", NA,
    "Lower chamber gender quota",                            "V-Dem", "vdem_core_v2lgqugen",  NA,
    "Women Political Empowerment Index",                     "V-Dem", "vdem_core_v2x_gender", NA
  ))
)

cgjr_crosswalk <- tibble::as_tibble(cgjr_crosswalk)


# ---------------------------------------------------------------------------
# 3.  Validate against cliaretl eligibility flags (build-time gate)
# ---------------------------------------------------------------------------

devtools::load_all(quiet = TRUE)

validation <- validate_crosswalk(cgjr_crosswalk)   # emits warnings for failures

# Write the validation report next to the other build artefacts for review.
utils::write.csv(
  validation,
  here::here("data-raw", "output", "cgjr_crosswalk_validation.csv"),
  row.names = FALSE
)

message(
  "\ncgjr_crosswalk: ", nrow(cgjr_crosswalk), " rows | ",
  sum(validation$check == "ok"), " fully eligible | ",
  sum(validation$check == "not_family_aggregate_eligible"), " in-panel but family-aggregate ineligible | ",
  sum(validation$check == "not_dynamic_eligible"), " not in dynamic panel | ",
  sum(validation$check == "unresolved"), " unresolved (no variable)"
)


# ---------------------------------------------------------------------------
# 4.  Persist as package data
# ---------------------------------------------------------------------------

usethis::use_data(cgjr_taxonomy,  overwrite = TRUE)
usethis::use_data(cgjr_crosswalk, overwrite = TRUE)

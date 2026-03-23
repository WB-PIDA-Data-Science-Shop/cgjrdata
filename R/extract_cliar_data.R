#' Extract CLIAR indicator data
#'
#' An API-style accessor for variables stored in the `cliaretl` package. Pass
#' one or more variable names (as they appear in `cliaretl::db_variables_final$variable`)
#' and specify whether you want the raw source data, the closeness-to-frontier
#' dynamic panel, or the closeness-to-frontier static cross-section.
#'
#' @param variables Character vector of variable names to extract, matching
#'   the `variable` column of `cliaretl::db_variables_final`. If `NULL`
#'   (default), all variables available in the chosen `type` are returned.
#' @param type One of `"raw"`, `"dynamic"`, or `"static"` (default `"dynamic"`).
#'   \describe{
#'     \item{`"raw"`}{Returns data from the original source datasets, joined
#'       on `country_code` and `year`.}
#'     \item{`"dynamic"`}{Returns columns from
#'       `cliaretl::closeness_to_frontier_dynamic` (CTF-scaled panel data).}
#'     \item{`"static"`}{Returns columns from
#'       `cliaretl::closeness_to_frontier_static` (CTF-scaled cross-section).}
#'   }
#' @param id_vars Character vector of identifier columns to always include
#'   alongside the requested variables. Defaults to `c("country_code",
#'   "country_name", "year")` for `"raw"` and `"dynamic"` types, and
#'   `c("country_code", "country_name")` for `"static"`.
#'
#' @return A tibble containing the requested identifier columns and variables.
#'
#' @examples
#' # Degree of Integrity indicators from the dynamic CTF dataset
#' doi_vars <- cliaretl::db_variables_final |>
#'   dplyr::filter(family_name == "Degree of Integrity", !is.na(variable)) |>
#'   dplyr::pull(variable)
#'
#' extract_cliar_data(doi_vars, type = "dynamic")
#' extract_cliar_data(doi_vars, type = "static")
#' extract_cliar_data(doi_vars, type = "raw")
#'
#' @export
extract_cliar_data <- function(variables = NULL,
                               type = c("dynamic", "static", "raw"),
                               id_vars = NULL) {

  type <- match.arg(type)

  # --- resolve id_vars defaults -------------------------------------------
  if (is.null(id_vars)) {
    id_vars <- if (type == "static") {
      c("country_code", "country_name")
    } else {
      c("country_code", "country_name", "year")
    }
  }

  # --- resolve variables against db_variables_final -----------------------
  catalogue <- cliaretl::db_variables_final |>
    dplyr::filter(!is.na(variable))

  if (!is.null(variables)) {
    unrecognised <- setdiff(variables, catalogue$variable)
    if (length(unrecognised) > 0) {
      warning(
        "The following variable(s) were not found in db_variables_final and ",
        "will be ignored:\n  ", paste(unrecognised, collapse = ", ")
      )
    }
    variables <- intersect(variables, catalogue$variable)
    if (length(variables) == 0) {
      stop("None of the requested variables were found in db_variables_final.")
    }
  }

  # --- dispatch by type ---------------------------------------------------
  if (type %in% c("dynamic", "static")) {
    dataset <- if (type == "dynamic") {
      cliaretl::closeness_to_frontier_dynamic
    } else {
      cliaretl::closeness_to_frontier_static
    }

    # keep only variables that actually exist as columns in this dataset
    if (!is.null(variables)) {
      available <- intersect(variables, names(dataset))
      missing_cols <- setdiff(variables, names(dataset))
      if (length(missing_cols) > 0) {
        warning(
          "The following variable(s) are not present in the ", type,
          " dataset and will be omitted:\n  ",
          paste(missing_cols, collapse = ", ")
        )
      }
      select_cols <- c(intersect(id_vars, names(dataset)), available)
    } else {
      select_cols <- names(dataset)
    }

    return(dplyr::select(dataset, dplyr::all_of(select_cols)))
  }

  # --- raw type -----------------------------------------------------------
  # Map etl_source labels to the corresponding cliaretl raw dataset object.
  # wb_api covers many indicators; all are stored in d360_efi_data.
  # PEFA indicators appear in both pefa_assessments and d360_efi_data;
  # we prefer the dedicated pefa_assessments dataset (etl_source == "pefa").
  raw_source_lookup <- list(
    vdem              = cliaretl::vdem_data,
    wb_api            = cliaretl::d360_efi_data,
    wdi               = cliaretl::wdi_indicators,
    pefa              = cliaretl::pefa_assessments,
    fraser            = cliaretl::fraser,
    heritage          = cliaretl::heritage,
    gfdb              = cliaretl::gfdb,
    romelli           = cliaretl::romelli,
    debt_transparency = cliaretl::debt_transparency,
    oecd_epl          = cliaretl::epl,
    oecd_pmr          = cliaretl::pmr,
    wb_wbl            = cliaretl::wbl_data
  )

  # Build a variable -> dataset mapping driven by etl_source in the catalogue.
  # Variables with no etl_source (e.g. family averages) have no raw representation.
  var_source_map <- catalogue |>
    dplyr::filter(!is.na(etl_source), etl_source %in% names(raw_source_lookup)) |>
    dplyr::select(variable, etl_source)

  if (!is.null(variables)) {
    vars_to_fetch <- variables
  } else {
    vars_to_fetch <- var_source_map$variable
  }

  fetch_map <- var_source_map |>
    dplyr::filter(variable %in% vars_to_fetch)

  unmatched <- setdiff(vars_to_fetch, fetch_map$variable)
  if (length(unmatched) > 0) {
    warning(
      "The following variable(s) were not found in any raw source dataset ",
      "and will be omitted:\n  ", paste(unmatched, collapse = ", ")
    )
  }

  if (nrow(fetch_map) == 0) {
    stop("None of the requested variables were found in the raw source datasets.")
  }

  # Pull required columns from each source dataset, then full-join on keys
  source_chunks <- fetch_map |>
    dplyr::group_by(etl_source) |>
    dplyr::group_map(function(rows, key) {
      ds   <- raw_source_lookup[[key$etl_source]]
      cols <- intersect(c("country_code", "year", rows$variable), names(ds))
      dplyr::select(ds, dplyr::all_of(cols))
    })

  result <- purrr::reduce(
    source_chunks,
    function(x, y) dplyr::full_join(x, y, by = c("country_code", "year"))
  )

  # Attach country_name from the country list when requested.
  # wb_country_list can have multiple rows per country_code (e.g. group rows),
  # so deduplicate to country_code + country_name before joining.
  if ("country_name" %in% id_vars) {
    meta <- cliaretl::wb_country_list |>
      dplyr::select(dplyr::all_of(c("country_code", "country_name"))) |>
      dplyr::distinct(country_code, .keep_all = TRUE)
    result <- dplyr::left_join(result, meta, by = "country_code")
  }

  # Reorder: id_vars first, then the data columns
  lead_cols <- intersect(id_vars, names(result))
  rest_cols <- setdiff(names(result), lead_cols)
  dplyr::select(result, dplyr::all_of(c(lead_cols, rest_cols)))
}

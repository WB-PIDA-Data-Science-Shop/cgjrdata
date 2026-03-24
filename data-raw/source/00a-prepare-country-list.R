################################################################################
### PREPARE WORLD BANK COUNTRY LIST WITH SPLIT REGIONS AND INCOME GROUPS ######
################################################################################

library(dplyr)
library(readxl)
library(janitor)
library(cliaretl)


country_dt <- readxl::read_xlsx("data-raw/input/CLASS_2025_10_07.xlsx")

# Load the regional mapping from cliaretl
wb_regions <- cliaretl::wb_country_list |>
  dplyr::filter(group %in% c("Africa Eastern and Southern", "Africa Western and Central")) |>
  dplyr::select(country_code, region = group, region_code = group_code) |>
  dplyr::distinct()


country_dt <- 
  country_dt |> 
  janitor::clean_names() |> 
  # First, join with the Africa regional splits
  dplyr::left_join(wb_regions, by = c("code" = "country_code")) |>
  # If a country has an AFE or AFW assignment, use it; otherwise use the original region
  dplyr::mutate(
    region = dplyr::coalesce(region.y, region.x),
    region_code = case_when(
      !is.na(region_code) ~ region_code,  # Use AFE or AFW if available
      region == "East Asia & Pacific" ~ "EAP",
      region == "Europe & Central Asia" ~ "ECA",
      region == "Latin America & Caribbean" ~ "LAC",
      region == "Middle East, North Africa, Afghanistan & Pakistan" ~ "MENAAP",
      region == "South Asia" ~ "SAR",
      region == "North America" ~ "NAC",
      .default = NA_character_
    )
  ) |>
  dplyr::select(-region.x, -region.y) |>
  dplyr::filter(!is.na(region)) |> 
  rename(country_code = "code")

wbcountries <- country_dt

rm(country_dt)

usethis::use_data(wbcountries, overwrite = TRUE)
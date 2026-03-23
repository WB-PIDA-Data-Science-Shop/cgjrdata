##############################################################################
########################## BUILD ALL DATASETS ################################
##############################################################################
# Sources every data-raw script in chapter order. Run this from the package
# root after loading the package (devtools::load_all()) to regenerate all
# .rda files in data/.
##############################################################################

devtools::load_all()

library(dplyr)
library(haven)

# --- 1. Institutional Environment ----------------------------------------
source("data-raw/source/1.institutional_environment/degree_of_integrity.r")
source("data-raw/source/1.institutional_environment/transparency_and_accountability.r")
source("data-raw/source/1.institutional_environment/justice_and_rule_of_law.r")
source("data-raw/source/1.institutional_environment/social_cohesion_norms_and_cooperation.r")

# --- 2. Political Institutions --------------------------------------------
source("data-raw/source/2.political_institutions/political_institutions.r")

# --- 3. Center of Government ----------------------------------------------
source("data-raw/source/3.center_of_government/public_financial_management.r")
source("data-raw/source/3.center_of_government/public_sector_hrm.r")
source("data-raw/source/3.center_of_government/digital_and_data.r")

# --- 4. Sectors / Service Delivery ----------------------------------------
source("data-raw/source/4.sectors_or_service_delivery/business_environment.r")
source("data-raw/source/4.sectors_or_service_delivery/service_delivery.r")
source("data-raw/source/4.sectors_or_service_delivery/soe_governance.r")
source("data-raw/source/4.sectors_or_service_delivery/labor_and_social_protection.r")
source("data-raw/source/4.sectors_or_service_delivery/energy_and_environment.r")

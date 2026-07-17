#!/usr/bin/env Rscript

################################################################################
# MODULE: Get LAU human population data from Eurostat for inputted focus year. 
# Fetches LAU (Local Areal Unit) data from Eurostat for focus year.
################################################################################

# --- 1. DEPENDENCIES ---
library(giscoR)

source("src/utils_io.R")

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

VALID_LAU_YEARS <- c(
  "2024", "2023", "2022", "2021",
  "2020", "2019", "2018", "2017",
  "2016", "2015", "2014", "2013",
  "2012", "2011"
)

# --- 3. FUNCTION DEFINITION (Original Code) ---
get_lau_population <- function(pop_focus_year,
                               countrylist,
                               target_crs = "3035") {

  # GISCO's LAU boundaries don't cover every country for every year (e.g. the
  # UK is missing from the 2021 vintage). Fetch a single country/year combo,
  # treating an empty result the same as a fetch error.
  fetch_lau <- function(year, country) {
    result <- tryCatch(
      giscoR::gisco_get_lau(year = year, epsg = target_crs, country = country),
      error = function(e) NULL
    )
    if (is.null(result) || nrow(result) == 0) NULL else result
  }

  # Get data #LAU_ID #POP_2021
  lau_pop <- fetch_lau(pop_focus_year, countrylist)

  countries_found <- if (is.null(lau_pop)) character(0) else unique(lau_pop$CNTR_CODE)
  missing_countries <- setdiff(countrylist, countries_found)

  if (length(missing_countries) > 0) {

    # Candidate years, nearest to pop_focus_year first
    candidate_years <- setdiff(VALID_LAU_YEARS, as.character(pop_focus_year))
    candidate_years <- candidate_years[order(abs(as.integer(candidate_years) - as.integer(pop_focus_year)))]

    fallback_parts <- list()

    for (country in missing_countries) {
      for (candidate_year in candidate_years) {
        candidate <- fetch_lau(candidate_year, country)
        if (!is.null(candidate)) {
          message(sprintf(
            "Note: no LAU data available for country '%s' in year %s; using nearest available year %s instead.",
            country, pop_focus_year, candidate_year
          ))
          # Relabel this country's data as if it were pop_focus_year, so
          # downstream steps can always look for POP_<pop_focus_year> without
          # needing to know which year the data actually came from.
          names(candidate)[names(candidate) == paste0("POP_", candidate_year)] <- paste0("POP_", pop_focus_year)
          names(candidate)[names(candidate) == paste0("POP_DENS_", candidate_year)] <- paste0("POP_DENS_", pop_focus_year)
          candidate$YEAR <- as.integer(pop_focus_year)
          fallback_parts[[country]] <- candidate
          break
        }
      }
      if (is.null(fallback_parts[[country]])) {
        warning(sprintf(
          "No LAU data found for country '%s' in year %s or any nearby year.",
          country, pop_focus_year
        ))
      }
    }

    if (length(fallback_parts) > 0) {
      fallback_combined <- do.call(rbind, fallback_parts)
      lau_pop <- if (is.null(lau_pop)) fallback_combined else rbind(lau_pop, fallback_combined)
    }
  }

  if (is.null(lau_pop) || nrow(lau_pop) == 0) {
    stop(
      sprintf(
        "No LAU data found for any of the requested countries (%s) in year %s or any nearby year.",
        paste(countrylist, collapse = ", "), pop_focus_year
      ),
      call. = FALSE
    )
  }

  return(lau_pop)
}

################################################################################
# D2K WRAPPER
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 4) {
  stop("Usage: Rscript src/get_lau_data.R <countries_for_catchment> <focus_year> <output_lau_focus_rds_path> <output_focusyear_rds_path>", call. = FALSE)
}

countries_rds_path <- args[1]
focus_year <- args[2]
# validation (clean version)
focus_year <- as.character(focus_year)
if (!(focus_year %in% VALID_LAU_YEARS)) {
  stop(
    paste0(
      "Invalid focus year: ", focus_year,
      ". Allowed years are: ",
      paste(VALID_LAU_YEARS, collapse = ", ")
    ),
    call. = FALSE
  )
}

output_lau_focus_rds_path <- args[3]
output_focusyear_rds_path <- args[4]

message(paste("D2K Wrapper Started. Output will be saved to:", 
              output_lau_focus_rds_path))

tryCatch({
  
  countries_for_catchment <- read_rds_input(countries_rds_path)
  
  LAU_focus <- get_lau_population(
    pop_focus_year = focus_year,
    countrylist = countries_for_catchment
  )
  
  # Save as .rds for machine/subsequent steps
  saveRDS(LAU_focus, 
          file = output_lau_focus_rds_path)

  # Save as .rds for machine/subsequent steps
  saveRDS(focus_year, 
          file = output_focusyear_rds_path)

  message(paste("D2K Wrapper Finished. LAU population data saved to", 
                output_lau_focus_rds_path))
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})

#!/usr/bin/env Rscript

################################################################################
# MODULE: Get Eurostat census grid 2021 with human population data for inputted 
# analysis extent. Fetches Eurostat census grid 2021 from Eurostat and crops it 
# to analysis extent.
################################################################################

# --- 1. DEPENDENCIES ---
library(arrow)
library(sf)

source("src/utils_io.R")

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# grid_1km.parquet is ~175 MB; R's default 60s download timeout can be too
# short on slower connections, aborting the download partway through.
options(timeout = max(1800, getOption("timeout")))

# --- 3. FUNCTION DEFINITION (Original Code) ---
get_census_grid <- function(countries_for_catchment) {
  
  url <- "https://gisco-services.ec.europa.eu/grid/grid_1km.parquet"
  
  df_all <- arrow::read_parquet(url)
  
  df_dk <- df_all[df_all$CNTR_ID %in% countries_for_catchment, ]
  
  grid_poly <- sf::st_sf(
    df_dk,
    geometry = sf::st_sfc(
      lapply(seq_len(nrow(df_dk)), function(i) {
        
        x <- df_dk$X_LLC[i]
        y <- df_dk$Y_LLC[i]
        
        sf::st_polygon(list(
          matrix(
            c(
              x, y,
              x + 1000, y,
              x + 1000, y + 1000,
              x, y + 1000,
              x, y
            ),
            ncol = 2,
            byrow = TRUE
          )
        ))
      }),
      crs = 3035
    )
  )  
  
  grid_poly <- sf::st_make_valid(grid_poly)
  
  return(grid_poly)
}  

################################################################################
# D2K WRAPPER
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  stop("Usage: Rscript src/get_census_grid.R <countries_for_catchment> <output_censusgrid_rds_path>", call. = FALSE)
}

countries_rds_path <- args[1]
output_censusgrid_rds_path <- args[2]

message("D2K Wrapper Started for censusgrid retrieval.")

tryCatch({
  
  countries_for_catchment <- read_rds_input(countries_rds_path)
  
  censusgrid <- get_census_grid(countries_for_catchment = countries_for_catchment)
  
  # Save as .rds for machine/subsequent steps
  saveRDS(censusgrid, 
          file = output_censusgrid_rds_path)

  message(paste("D2K Wrapper Finished. Censusgrid population data saved to", 
                output_censusgrid_rds_path))
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})

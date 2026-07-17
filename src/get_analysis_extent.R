#!/usr/bin/env Rscript

################################################################################
# MODULE: Get spatial analysis extent based on countries overlapping the catchment
# in focus
#
# Calculates spatial analysis extent.
################################################################################

# --- 1. DEPENDENCIES ---
library(sf)

source("src/utils_io.R")

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

################################################################################
# D2K WRAPPER
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3) {
  stop("Usage: Rscript src/get_analysis_extent.R <lau_focus_selected_rds_path> <lau_reference_selected_rds_path> <output_analysis_extent_gpkg_path>", call. = FALSE)
}

lau_focus_selected_rds_path <- args[1]
lau_reference_selected_rds_path <- args[2]
output_analysis_extent_gpkg_path <- args[3]

message("D2K Wrapper Started to get analysis extent")

tryCatch({
  
  # Read spatial focus object
  lau_in_catchment_focus <- read_rds_input(lau_focus_selected_rds_path)
  
  # Read spatial reference object
  lau_in_catchment_reference <- read_rds_input(lau_reference_selected_rds_path)
  
  # Get analysis extent 
  if (nrow(lau_in_catchment_focus) > 0) {
    analysis_spatial_extent <- sf::st_union(lau_in_catchment_focus)
  } else if (nrow(lau_in_catchment_reference) > 0) {
    analysis_spatial_extent <- sf::st_union(lau_in_catchment_reference)
  } else {
    analysis_spatial_extent <- NA
  }

  # Save the output
  sf::st_write(analysis_spatial_extent, output_analysis_extent_gpkg_path, delete_layer = TRUE, quiet = TRUE)

  message(paste("D2K Wrapper Finished. Spatial analysis extent saved to", 
                output_analysis_extent_gpkg_path))
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})

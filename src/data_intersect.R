#!/usr/bin/env Rscript

################################################################################
# MODULE: Intersect input data with spatial analysis extent.
# Calculates a spatial intersection.
################################################################################

# --- 1. DEPENDENCIES ---
library(sf)

source("src/utils_io.R")

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# --- 3. FUNCTION DEFINITION (Original Code) ---
intersect_with_analysis_extent <- function(gpkg_focus, 
                                           analysis_extent
) {
  # Ensure both layers have the same CRS
  if (sf::st_crs(gpkg_focus) != sf::st_crs(analysis_extent)) {
    gpkg_focus <- sf::st_transform(gpkg_focus, sf::st_crs(analysis_extent))
  }
  
  # Keep only LAU polygons that intersect the catchment
  output_of_intersect <- gpkg_focus[sf::st_intersects(gpkg_focus, analysis_extent, sparse = FALSE), ]

  return(output_of_intersect)
}

################################################################################
# D2K WRAPPER
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3) {
  stop("Usage: Rscript src/data_intersect.R <focus_rds_pathh> <analysis_extent_gpkg_path> <output_rds_path>", call. = FALSE)
}

focus_rds_path <- args[1]
analysis_extent_gpkg_path <- args[2]
output_rds_path <- args[3]

message("D2K Wrapper Started for intersection.")

tryCatch({
  
  # Read spatial focus object
  sf_focus_rds <- read_rds_input(focus_rds_path)

  analysis_extent <- sf::st_read(analysis_extent_gpkg_path,
                                 quiet = TRUE)
  
  output_of_intersect <- intersect_with_analysis_extent(gpkg_focus = sf_focus_rds, 
                                                        analysis_extent = analysis_extent)
  
  # Save as .rds for machine/subsequent steps
  saveRDS(output_of_intersect, 
          file = output_rds_path)

  message(paste("D2K Wrapper Finished. Intersect result saved to", 
                output_rds_path))
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})

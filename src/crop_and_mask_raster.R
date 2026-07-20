#!/usr/bin/env Rscript

################################################################################
# MODULE: Crop existing Corine CLC dataset to input spatial analysis extent. 
################################################################################

# --- 1. DEPENDENCIES ---
library(terra)
library(sf)

source("src/utils_io.R")

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# --- 3. FUNCTION DEFINITION (Original Code) ---
get_raster_for_geometry <- function(raster_object,
                                    analysis_spatial_extent) 
{
  
  # Ensure the spatial extent is a SpatVector
  country_vect <- terra::vect(analysis_spatial_extent)
  
  # Crop CORINE raster to the country's extent
  raster_country_object <- terra::crop(raster_object, country_vect)
  
  # Mask raster to the exact country shape
  raster_country_object <- terra::mask(raster_country_object, country_vect)
  
  # Return
  return(raster_country_object)
  
}

################################################################################
# D2K WRAPPER
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3) {
  stop("Usage: Rscript src/crop_and_mask_raster.R <corineCLC_rds_path> <analysis_extent_gpkg_path> <output_corineCLC_cropped_rds_path>", call. = FALSE)
}

corineCLC_rds_path <- args[1]
analysis_extent_gpkg_path <- args[2]
output_corineCLC_cropped_rds_path <- args[3]

message("D2K Wrapper Started for cropping Corine CLC raster to input spatial analysis extent.")

tryCatch({
  
  # Read spatial focus object
  corCLC <- read_rds_input(corineCLC_rds_path)
  
  # Read spatial focus object
  analysis_extent <- sf::st_read(analysis_extent_gpkg_path,
                                 quiet = TRUE)
  
  corCLC_selected <- get_raster_for_geometry(corCLC,
                                             analysis_extent)
  
  # Save as .rds for machine/subsequent steps
  saveRDS(corCLC_selected, 
          file = output_corineCLC_cropped_rds_path)

  message(paste("D2K Wrapper Finished. Cropped Corine CLC raster saved to", 
                output_corineCLC_cropped_rds_path))
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})

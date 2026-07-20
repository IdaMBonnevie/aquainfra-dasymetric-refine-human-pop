#!/usr/bin/env Rscript

################################################################################
# MODULE: Keep only urbanised CORINE CLC clasess more specifically the classes 
# provided weights in the inputted weight table
#
################################################################################

# --- 1. DEPENDENCIES ---
library(terra)

source("src/utils_io.R")

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# --- 3. FUNCTION DEFINITION (Original Code) ---
get_only_valid_corine_categories_raster <- function(cor_rast_crop, 
                                                    cor_code_raster_columnname,
                                                    weight_table_final) 
{
  
  # keep only valid corine classes 
  valid_codes <- unique(weight_table_final[[cor_code_raster_columnname]])
  cor_rast_crop[!cor_rast_crop %in% valid_codes] <- NA
  
  return(cor_rast_crop)
  
}

################################################################################
# D2K WRAPPER
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 4) {
  stop("Usage: Rscript src/keep_only_valid_corineCLCclasses.R <corineCLC_rds_path> <corine_year_rds_path> <weight_table_rds_path> <output_corineCLC_valid_rds_path>", call. = FALSE) 
}

corineCLC_rds_path <- args[1]
corine_year_rds_path <- args[2]
corine_year <- read_rds_input(corine_year_rds_path)
corine_year <- as.character(corine_year)
if (!(corine_year == "2018")) {
  stop(
    paste0(
      "Invalid corine year: ", corine_year,
      ". Allowed year is only year 2018", 
      collapse = ", "
    ),
    call. = FALSE
  )
}

weight_table_rds_path <- args[3]
output_corineCLC_valid_rds_path <- args[4]

message("D2K Wrapper Started for selecting only urbanised Corine CLC classes valid for dasymetric refinement.")

tryCatch({
  
  # Read spatial focus object
  corCLC <- read_rds_input(corineCLC_rds_path)

  cor_code_raster_columnname <- paste0("CODE_", 
                                       substr(corine_year, 
                                              3, 4)) # e.g. "CODE_18"
  
  weight_table_final <- read_rds_input(weight_table_rds_path)
  
  corineCLC_valid <- get_only_valid_corine_categories_raster(cor_rast_crop = corCLC, 
                                                             cor_code_raster_columnname = cor_code_raster_columnname,
                                                             weight_table_final = weight_table_final)
    
  # Save as .rds for machine/subsequent steps
  saveRDS(corineCLC_valid, 
          file = output_corineCLC_valid_rds_path)
  
  message(paste("D2K Wrapper Finished. Valid Corine CLC raster saved to", 
                output_corineCLC_valid_rds_path))
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})

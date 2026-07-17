#!/usr/bin/env Rscript

################################################################################
# MODULE: Get CORINE CLC dataset covering European Union for CORINE year that 
# is closest to inputted focus year.
################################################################################

# --- 1. DEPENDENCIES ---
library(terra)

source("src/utils_io.R")

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

################################################################################
# D2K WRAPPER
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3) {
  stop("Usage: Rscript src/get_corineCLC.R <focus_year_rds_path> <output_corineCLC_rds_path> <corine_year_rds_path>", call. = FALSE)
}

focus_year_rds_path <- args[1]
focus_year <- read_rds_input(focus_year_rds_path)
focus_year <- as.character(focus_year)
valid_years <- c(
  "2024", "2023", "2022", "2021",
  "2020", "2019", "2018", "2017",
  "2016", "2015", "2014", "2013",
  "2012", "2011"
)
if (!(focus_year %in% valid_years)) {
  stop(
    paste0(
      "Invalid focus year: ", focus_year,
      ". Allowed years are: ",
      paste(valid_years, collapse = ", ")
    ),
    call. = FALSE
  )
}

output_corineCLC_rds_path <- args[2]
corine_year_rds_path <- args[3]

message("D2K Wrapper Started for corine CLC retrieval.")

tryCatch({
  
  years_2018 <- c(
    "2024", "2023", "2022", "2021",
    "2020", "2019", "2018", "2017",
    "2016", "2015"
  )
  years_2012 <- c(
    "2014", "2013",
    "2012", "2011"
  )
  
  if (focus_year %in% years_2018) {
    cor_rast_name <- "https://aquainfra-syke.a3s.fi/europe_clc_cog_raster/CLC2018ACC_V2018_20_cog.tif"
    corine_year <- "2018"
  } else if (focus_year %in% years_2012) {
    cor_rast_name <- "https://aquainfra-syke.a3s.fi/europe_clc_cog_raster/CLC2012ACC_V2018_20_cog.tif"
    corine_year <- "2012"
    # 2006: https://aquainfra-syke.a3s.fi/europe_clc_cog_raster/CLC2006ACC_V2018_20_cog.tif
    # 2000: https://aquainfra-syke.a3s.fi/europe_clc_cog_raster/CLC2000ACC_V2018_20_cog.tif
  } 
  
  # Load terra raster 
  cor_full <- terra::rast(cor_rast_name)

  # Save as .rds for machine/subsequent steps
  saveRDS(cor_full, 
          file = output_corineCLC_rds_path)

  # Save as .rds for machine/subsequent steps
  saveRDS(corine_year, 
          file = corine_year_rds_path)

  message(paste("D2K Wrapper Finished. CORINE CLC raster saved to", 
                output_corineCLC_rds_path))
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})

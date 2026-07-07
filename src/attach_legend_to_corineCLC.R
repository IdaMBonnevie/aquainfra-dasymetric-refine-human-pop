#!/usr/bin/env Rscript

################################################################################
# MODULE: Attach legend to Corine CLC raster and get urban values as list.
################################################################################

# --- 1. DEPENDENCIES ---
library(terra)

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

if (length(args) != 4) {
  stop("Usage: Rscript src/attach_legend_to_corineCLC.R <corine_year_rds_path> <corineCLC_rds_path> <cor_urban_values_rds_path> <clc_legend_rds_path>", call. = FALSE)
}

corine_year_rds_path <- args[1]
corine_year <- readRDS(corine_year_rds_path)
corine_year <- as.character(corine_year)
if (!(corine_year %in% c("2012", "2018"))) {
  stop(
    paste0(
      "Invalid corine year: ", corine_year,
      ". Allowed years are 2012 and 2018."
    ),
    call. = FALSE
  )
}

#print(args)
#print(corine_year)
#print(substr(corine_year, 3, 4))
print(paste0("CODE_", substr(corine_year, 3, 4)))



corineCLC_rds_path <- args[2]
cor_urban_values_rds_path <- args[3]
clc_legend_rds_path <- args[4]

message("D2K Wrapper Started for censusgrid retrieval.")

tryCatch({
  
  # Read spatial focus object
  corCLC <- readRDS(corineCLC_rds_path)
  
  cor_code_raster_columnname <- paste0("CODE_", substr(corine_year, 3, 4)) # e.g. "CODE_18"
  cor_name_raster_columnname <- "LABEL"    
  
  # Hardcoded CLC 2018 legend
  clc_legend <- data.frame(
    code = c(
      111,112,121,122,123,124,131,132,133,141,142,
      211,212,213,221,222,223,231,241,242,243,244,
      311,312,313,321,322,323,324,331,332,333,334,
      335,411,412,421,422,423,511,512,521,522,523,999
    ),
    label = c(
      "Continuous urban fabric",
      "Discontinuous urban fabric",
      "Industrial or commercial units",
      "Road and rail networks and associated land",
      "Port areas",
      "Airports",
      "Mineral extraction sites",
      "Dump sites",
      "Construction sites",
      "Green urban areas",
      "Sport and leisure facilities",
      "Non-irrigated arable land",
      "Permanently irrigated land",
      "Rice fields",
      "Vineyards",
      "Fruit trees and berry plantations",
      "Olive groves",
      "Pastures",
      "Annual crops associated with permanent crops",
      "Complex cultivation patterns",
      "Land principally occupied by agriculture, with significant areas of natural vegetation",
      "Agro-forestry areas",
      "Broad-leaved forest",
      "Coniferous forest",
      "Mixed forest",
      "Natural grasslands",
      "Moors and heathland",
      "Sclerophyllous vegetation",
      "Transitional woodland-shrub",
      "Beaches, dunes, sands",
      "Bare rocks",
      "Sparsely vegetated areas",
      "Burnt areas",
      "Glaciers and perpetual snow",
      "Inland marshes",
      "Peat bogs",
      "Salt marshes",
      "Salines",
      "Intertidal flats",
      "Water courses",
      "Water bodies",
      "Coastal lagoons",
      "Estuaries",
      "Sea and ocean",
      "NODATA"
    ),
    Red = c(
      0.9019608,1.0000000,0.8000000,0.8000000,0.9019608,0.9019608,0.6509804,
      0.6509804,1.0000000,1.0000000,1.0000000,1.0000000,1.0000000,0.9019608,
      0.9019608,0.9490196,0.9019608,0.9019608,1.0000000,1.0000000,0.9019608,
      0.9490196,0.5019608,0.0000000,0.3019608,0.8000000,0.6509804,0.6509804,
      0.6509804,0.9019608,0.8000000,0.8000000,0.0000000,0.6509804,0.6509804,
      0.3019608,0.8000000,0.9019608,0.6509804,0.0000000,0.5019608,0.0000000,
      0.6509804,0.9019608,1.0000000
    ),
    Green = c(
      0.0000000,0.0000000,0.3019608,0.0000000,0.8000000,0.8000000,0.0000000,
      0.3019608,0.3019608,0.6500000,0.9019608,1.0000000,1.0000000,0.9019608,
      0.5019608,0.6509804,0.6509804,0.9019608,0.9019608,0.9019608,0.8000000,
      0.8000000,1.0000000,0.6509804,1.0000000,0.9490196,1.0000000,0.9019608,
      0.9490196,0.9019608,0.8000000,1.0000000,0.0000000,0.9019608,0.6509804,
      0.3019608,0.8000000,0.9019608,0.6509804,0.8000000,0.9490196,1.0000000,
      1.0000000,0.9490196,1.0000000
    ),
    Blue = c(
      0.3019608,0.0000000,0.9490196,0.0000000,0.8000000,0.9019608,0.8000000,
      0.0000000,1.0000000,1.0000000,1.0000000,0.6588235,0.0000000,0.0000000,
      0.0000000,0.3019608,0.0000000,0.3019608,0.6509804,0.3019608,0.3019608,
      0.6509804,0.0000000,0.0000000,0.0000000,0.3019608,0.5019608,0.3019608,
      0.0000000,0.9019608,0.8000000,0.8000000,0.0000000,0.8000000,1.0000000,
      1.0000000,1.0000000,1.0000000,0.9019608,0.9490196,0.9019608,0.6509804,
      0.9019608,1.0000000,1.0000000
    )
  )
  # Apply flexible column names
  names(clc_legend)[names(clc_legend) == "code"] <- cor_code_raster_columnname
  names(clc_legend)[names(clc_legend) == "label"] <- cor_name_raster_columnname
  # Attach CODE_18 + LABEL to raster
  levels(corCLC) <- clc_legend[, c(cor_code_raster_columnname,cor_name_raster_columnname)]
  # Optional: check
  levels(corCLC)
  
  # Add colors to raster
  cols <- rgb(
    clc_legend$Red,
    clc_legend$Green,
    clc_legend$Blue
  )
  
  terra::coltab(corCLC) <- cbind(clc_legend[[cor_code_raster_columnname]], cols)
  
  # Save as .rds for machine/subsequent steps
  saveRDS(corCLC, 
          file = corineCLC_rds_path)
  
  #Find raster values where CODE_18 is between 100 and 199 #(inclusive lower, exclusive upper)
  cor_urban_values <- clc_legend[[cor_code_raster_columnname]][clc_legend[[cor_code_raster_columnname]] >= 100 & clc_legend[[cor_code_raster_columnname]] < 200]

  # Save as .rds for machine/subsequent steps
  saveRDS(cor_urban_values, 
          file = cor_urban_values_rds_path)
  
  # Save as .rds for machine/subsequent steps
  saveRDS(clc_legend, 
          file = clc_legend_rds_path)

    message(paste("D2K Wrapper Finished. CORINE CLC with legend saved to", 
                corineCLC_rds_path))
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})

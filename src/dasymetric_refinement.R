#!/usr/bin/env Rscript

################################################################################
# MODULE: Dasymetric refinement of LAU (Local Area Unit) human population for a 
# chosen year estimated finer to 1 km2 raster cells based on urban Corine classes
# and weights as given in inputted weight table as well as building footprint
# for cells with building count passing a fixed, supplied threshold. If simple is 
# chosen as refinement type, a binary distribution of human population to 
# urbanised Corine classes 111 and 112 is carried out.
################################################################################

# --- 1. DEPENDENCIES ---
library(terra)
library(dplyr)
library(sf)

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# --- 3. FUNCTION DEFINITION (Original Code) ---
dasymetric_refinement_raster <- function(cor_rast_geom,
                                         cor_code_raster_columnname,
                                         lau_in_catchment,
                                         source_id,
                                         source_value_col,
                                         pop_year,
                                         catchment,
                                         weight_table_final,
                                         refinement_type,
                                         buildings_vect = NULL,
                                         building_count_threshold = 1
) {
  
  # Ensure the spatial extent is a SpatVector
  lau_vect <- terra::vect(lau_in_catchment)
  
  # make numeric LAU ID column — LAU_ID isn't always numeric (e.g. UK's
  # alphanumeric ONS codes like "E07000064"), so as.integer() directly would
  # silently produce NA for every feature. Derive a safe sequential integer
  # per unique LAU_ID instead; only used internally as a join key, so its
  # actual value doesn't matter as long as it's unique per LAU unit.
  lau_ids <- terra::values(lau_vect)[[source_id]]
  lau_vect$LAU_ID_num <- as.integer(factor(lau_ids))
  
  # rasterize LAU IDs
  lau_raster <- terra::rasterize(
    lau_vect,
    cor_rast_geom,
    field = "LAU_ID_num",
    background = NA
  )
  
  # Mask LAU to valid corine classes
  lau_raster <- terra::mask(lau_raster, cor_rast_geom)
  
  if (refinement_type == "simple") {
    
    # Simple refinement is a binary distribution restricted to CLC 111/112 —
    # buildings are never incorporated here, regardless of the supplied
    # threshold, so no building processing is done at all in this branch.
    cor_artificial_plus_buildings <- cor_rast_geom
    cor_artificial_plus_buildings[!cor_artificial_plus_buildings %in% c(111, 112)] <- NA
    
  } else {

    # Keep only very urban CLC
    cor_urban_only <- cor_rast_geom
    cor_urban_only[!cor_urban_only %in% c(111, 112)] <- NA

    if (!is.null(buildings_vect)) {

      # Filter buildings to only those constructed in or before pop_year and buildings without construction year
      buildings_vect_filtered <- buildings_vect[
        is.na(buildings_vect$construction_year) |
          buildings_vect$construction_year <= pop_year,
      ]

      buildings_spatvect <- terra::vect(buildings_vect_filtered)
      buildings_centroids  <- terra::centroids(buildings_spatvect)

      # Count number of buildings per cell
      building_count <- terra::rasterize(
        buildings_centroids,
        cor_rast_geom,
        field = 1,
        fun = "length"     # counts how many points fall in each cell
      )

      # Treat "no buildings" (NA from rasterize) as a true 0, not a missing value —
      # otherwise NA > bt stays NA all the way through and these cells silently
      # drop out of the error checks below instead of counting as "fails threshold"
      building_count <- terra::ifel(is.na(building_count), 0, building_count)

      # Keep only cells with MORE than building_count_threshold buildings
      building_mask <- building_count > building_count_threshold

      # Convert the boolean mask into actual CLC values where buildings overlap
      building_values <- terra::mask(cor_rast_geom, building_mask, maskvalues = c(NA, FALSE))

      # Combine the two rasters
      cor_artificial_plus_buildings <- terra::cover(cor_urban_only, building_values)

    } else {

      # No buildings supplied: skip the building-count step entirely
      cor_artificial_plus_buildings <- cor_urban_only

    }

    }
  
  # join lau with normalised weights (independent of building_mask, computed once)
  lau_with_pop <- terra::as.data.frame(lau_vect)[, c("LAU_ID_num", source_value_col)]

  # encode both IDs in one raster
  combo_raster <- lau_raster * 1000 + cor_artificial_plus_buildings
    
  # frequencies
  freq_table <- terra::freq(combo_raster)
  
  # Count cells per LAU-CORINE class
  cell_counts <- freq_table |>
    dplyr::as_tibble() |>
    dplyr::mutate(
      LAU_ID = value %/% 1000,
      corine = value %% 1000,
      n_cells = count
    ) |>
    dplyr::select(LAU_ID, corine, n_cells)
    
  # for later statistics visualisation
  lau_cell_counts <- cell_counts
  
  # Join CORINE weights
  cell_counts <- cell_counts |>
    dplyr::left_join(
      weight_table_final,
      by = c("corine" = cor_code_raster_columnname)
    )
  
  # compute weighted area
  cell_counts <- cell_counts |>
    dplyr::mutate(
      weight = (percent/100) * n_cells
    )
    
  # normalize weights per LAU
  cell_counts <- cell_counts |>
    dplyr::group_by(LAU_ID) |>
    dplyr::mutate(
      weight_norm = weight / sum(weight, na.rm = TRUE)
    ) |>
    dplyr::ungroup()
  
  cell_counts <- cell_counts |>
    dplyr::left_join(
      lau_with_pop,
      by = c("LAU_ID" = "LAU_ID_num")
    )
    
  # Estimate population per CORINE class
  cell_counts <- cell_counts |>
    dplyr::mutate(
      pop_corine = .data[[source_value_col]] * weight_norm
    )
  
  # Build lookup table: population per cell and combo value of combined LAU and corine IDs
  cell_counts <- cell_counts %>%
    mutate(
      pop_per_cell = pop_corine / n_cells,
      combo_val = LAU_ID * 1000 + corine
    ) %>%
    select(combo_val, pop_per_cell)
    
  # Map population to raster
  raster_vals <- terra::values(combo_raster)
  pop_vals <- cell_counts$pop_per_cell[match(raster_vals, cell_counts$combo_val)]
  
  # make a pop raster in the first step based on combo IDs
  pop_raster <- combo_raster
  # and in the second step based on estimated population in raster cells
  terra::values(pop_raster) <- pop_vals
  
  # Replace NAs and zeros with NA
  pop_raster <- terra::ifel(is.na(pop_raster) | pop_raster == 0, NA, pop_raster)
  names(pop_raster) <- "pop_est"
    
  # crop raster to extent
  refinement_cropped <- pop_raster %>%
    terra::crop(catchment) %>%
    terra::mask(catchment)
  
  refinement_cropped_1dec <- terra::round(refinement_cropped, digits = 1)
  refinement_cropped_1dec[refinement_cropped_1dec == 0] <- NA
    
  list(refinement_cropped_1dec = refinement_cropped_1dec,
       cor_artificial_plus_buildings = cor_artificial_plus_buildings,
       lau_cell_counts = lau_cell_counts)
}

################################################################################
# D2K WRAPPER
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 13) {
  stop("Usage: Rscript src/dasymetric_refinement.R <refinement_type> <corineCLC_rds_path> <corine_year_rds_path> <lau_in_catchment_rds_path> <pop_focus_year_rds_path> <catchment_gpkg_path> <weight_table_rds_path> <buildings_rds_path|NA> <building_count_threshold|NA> <output_refinement_rds_path> <output_refinement_tif_path> <output_cell_statistics_rds_path> <output_corine_final_rds_path>", call. = FALSE)
}

refinement_type <- args[1]
if (!(refinement_type %in% c("simple", "weighted"))) {
  stop(
    paste0(
      "Invalid refinement type: ", 
      refinement_type,
      ". Allowed types are: 'simple' and 'weighted'"
    ),
    call. = FALSE
  )
}

corineCLC_rds_path <- args[2]
corine_year_rds_path <- args[3]
corine_year <- readRDS(corine_year_rds_path)
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

lau_in_catchment_rds_path <- args[4]
pop_focus_year_rds_path <- args[5]
pop_focus_year <- readRDS(pop_focus_year_rds_path)
pop_focus_year <- as.character(pop_focus_year)

catchment_gpkg_path <- args[6]
weight_table_rds_path <- args[7]
buildings_rds_path <- args[8]
building_count_threshold_arg <- args[9]
output_refinement_rds_path <- args[10]
output_refinement_tif_path <- args[11]
output_cell_statistics_rds_path <- args[12]
output_corine_final_rds_path <- args[13]

message("D2K Wrapper Started for dasymetric refinement.")

tryCatch({
  
  # Read spatial focus object
  corCLC <- readRDS(corineCLC_rds_path)
  
  cor_code_raster_columnname <- paste0("CODE_", 
                                       substr(corine_year, 
                                              3, 4)) # e.g. "CODE_18"
  
  weight_table_final <- readRDS(weight_table_rds_path)
  
  # if simple refinement all weights should be equal 
  # and only class 111 and 112 are accepted
  if (refinement_type == "simple") {
    weight_table_final$percent <- 1.
    weight_table_final <- weight_table_final[
      weight_table_final$CODE_18 %in% c(111, 112),
    ]
  }
  
  lau_in_catchment <- readRDS(lau_in_catchment_rds_path)

  if (nrow(lau_in_catchment) == 0) {
    stop(
      sprintf(
        "No LAU units found for this catchment for pop_focus_year %s; cannot perform dasymetric refinement.",
        pop_focus_year
      ),
      call. = FALSE
    )
  }

  lau_value_col_focus <- paste0("POP_",
                                pop_focus_year) #"values"
  
  # Read spatial focus object
  catchment_gpkg <- sf::st_read(catchment_gpkg_path,
                                quiet = TRUE)
  
  # Optional inputs: "NA" signals the input was not supplied
  buildings_vect <- if (identical(buildings_rds_path, "NA")) {
    NULL
  } else {
    readRDS(buildings_rds_path)
  }

  building_count_threshold <- if (identical(building_count_threshold_arg, "NA")) {
    1
  } else {
    as.numeric(building_count_threshold_arg)
  }

  outputs_dasymetric_refinement <- dasymetric_refinement_raster(cor_rast_geom = corCLC,
                                                                cor_code_raster_columnname = cor_code_raster_columnname,
                                                                lau_in_catchment = lau_in_catchment,
                                                                source_id = "LAU_ID",
                                                                source_value_col = lau_value_col_focus,
                                                                pop_year = pop_focus_year,
                                                                catchment = catchment_gpkg,
                                                                weight_table_final = weight_table_final,
                                                                refinement_type = refinement_type,
                                                                buildings_vect = buildings_vect,
                                                                building_count_threshold = building_count_threshold)
  refinement_cropped_1dec <- outputs_dasymetric_refinement$refinement_cropped_1dec
  lau_cell_counts <- outputs_dasymetric_refinement$lau_cell_counts
  cor_artificial_plus_buildings <- outputs_dasymetric_refinement$cor_artificial_plus_buildings
  
  # Save as .rds for machine/subsequent steps
  saveRDS(refinement_cropped_1dec, 
          file = output_refinement_rds_path)

  # Save as tif file
  terra::writeRaster(
    refinement_cropped_1dec,
    output_refinement_tif_path,
    overwrite = TRUE
  )
  
  # Save as .rds for machine/subsequent steps
  saveRDS(lau_cell_counts, 
          file = output_cell_statistics_rds_path)
  
  # Save as .rds for machine/subsequent steps
  saveRDS(cor_artificial_plus_buildings, 
          file = output_corine_final_rds_path)
  
  message(paste("D2K Wrapper Finished. Dasymetric refinement raster saved to", 
                output_refinement_tif_path))
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})

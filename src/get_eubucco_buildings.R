#!/usr/bin/env Rscript

################################################################################
# MODULE: Get EUBUCCO building data for a catchment extent.
# Fetches building footprints from the EUBUCCO v0.2 dataset
# (https://eubucco.com) for all NUTS2 regions overlapping a given catchment.
# Uses arrow s3_bucket — confirmed working with EUBUCCO's custom S3 endpoint.
# Geometry is already in EPSG:3035.
################################################################################

# --- 1. DEPENDENCIES ---
library(arrow)
library(sf)
library(dplyr)
library(giscoR)

source("src/utils_io.R")

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# --- 3. FUNCTION DEFINITION (Original Code) ---
get_eubucco_buildings <- function(catchment,
                                  countries_for_catchment,
                                  year_filter  = NULL,
                                  type_filter  = NULL,
                                  cache_dir    = NULL) {
  
  catchment_3035 <- sf::st_transform(catchment, 3035)
  catchment_union <- sf::st_union(catchment_3035)
  catchment_bbox <- sf::st_bbox(catchment_union)

  # Find overlapping NUTS2 regions (EUBUCCO v0.2 is partitioned by NUTS2)
  message("Fetching NUTS2 boundaries to find overlapping regions...")
  nuts2 <- giscoR::gisco_get_nuts(year = "2016", 
                                  epsg = "3035",
                                  resolution = "10", 
                                  country = countries_for_catchment, 
                                  nuts_level = "2")
  
  overlapping <- nuts2[sf::st_intersects(nuts2, catchment_union, sparse = FALSE)[, 1], ]

  if (nrow(overlapping) == 0) {
    # Fatal, not a warning: a silent NULL here is indistinguishable downstream
    # from "legitimately no buildings" - e.g. a transient giscoR/GISCO NUTS
    # fetch hiccup would otherwise save a useless NULL and exit 0, with no
    # visible failure anywhere in the pipeline.
    stop("No NUTS2 regions found overlapping this catchment.", call. = FALSE)
  }
  
  nuts2_ids <- overlapping$NUTS_ID
  message(sprintf("Found %d overlapping NUTS2 regions: %s",
                  length(nuts2_ids), paste(nuts2_ids, collapse = ", ")))
  
  # S3 connection — confirmed working pattern
  s3 <- arrow::s3_bucket(
    "eubucco",
    endpoint_override = "s3.eubucco.com",
    anonymous = TRUE
  )
  
  # Columns to keep — exclude list-of-list source ID columns that cause
  # rbind type conflicts between regions
  keep_cols <- c(
    "id", "region_id", "city_id",
    "type", "subtype", "subtype_raw",
    "height", "floors", "construction_year",
    "type_confidence", "subtype_confidence",
    "height_confidence_lower", "height_confidence_upper",
    "floors_confidence_lower", "floors_confidence_upper",
    "construction_year_confidence_lower", "construction_year_confidence_upper",
    "geometry_source", "type_source", "subtype_source",
    "height_source", "floors_source", "construction_year_source",
    "geometry"
  )
  
  all_buildings <- list()
  
  for (nuts_id in nuts2_ids) {

    parquet_path <- sprintf("v0.2/buildings/parquet/nuts_id=%s/%s.parquet",
                            nuts_id, nuts_id)
    
    tryCatch({

      # Push the catchment's bbox down to the parquet read via its "bbox"
      # struct column, instead of arrow::read_parquet()'ing the whole NUTS2
      # region — a single region can hold millions of buildings (e.g. DE94
      # needs ~5.7GB of R memory read whole, vs. ~70MB filtered), which was
      # silently OOM-killing this step in memory-constrained containers with
      # no visible R error at all.
      # NOTE: open_dataset() needs the plain path string + filesystem = s3
      # separately - passing s3$path(parquet_path) as the source (as if it
      # were a directory) fails with "Not a regular file".
      read_filtered <- function(path) {
        arrow::open_dataset(path, filesystem = s3, format = "parquet") |>
          dplyr::filter(
            bbox$xmin <= !!catchment_bbox[["xmax"]],
            bbox$xmax >= !!catchment_bbox[["xmin"]],
            bbox$ymin <= !!catchment_bbox[["ymax"]],
            bbox$ymax >= !!catchment_bbox[["ymin"]]
          ) |>
          dplyr::collect()
      }

      if (!is.null(cache_dir)) {
        dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
        local_path <- file.path(cache_dir, sprintf("%s.parquet", nuts_id))
        if (!file.exists(local_path)) {
          # Cache only the filtered (small) subset, not the whole region
          tbl <- read_filtered(parquet_path)
          arrow::write_parquet(tbl, local_path)
        } else {
          tbl <- arrow::read_parquet(local_path)
        }
      } else {
        tbl <- read_filtered(parquet_path)
      }
      
      # Apply filters on the arrow table (fast, before converting to sf)
      if (!is.null(type_filter)) tbl <- tbl |> dplyr::filter(type == type_filter)
      if (!is.null(year_filter)) tbl <- tbl |> dplyr::filter(construction_year == year_filter)
      
      if (nrow(tbl) == 0) {
        message(sprintf("    No buildings matching filters for %s.", nuts_id))
        next
      }
      
      # Keep only non-problematic columns
      available_cols <- intersect(keep_cols, names(tbl))
      tbl <- tbl |> dplyr::select(dplyr::all_of(available_cols))
      
      # Convert to data frame
      df <- as.data.frame(tbl)
      
      # Convert WKB geometry (stored as arrow blob/raw) to sfc
      df$geometry <- sf::st_as_sfc(
        structure(as.list(df$geometry), class = "WKB"),
        crs = 3035
      )
      buildings_sf <- sf::st_as_sf(df)
      
      message(sprintf("    %d buildings retrieved.", nrow(buildings_sf)))
      all_buildings[[nuts_id]] <- buildings_sf
      
    }, error = function(e) {
      warning(sprintf("    Failed for %s: %s", nuts_id, e$message))
    })
  }
  
  if (length(all_buildings) == 0) {
    warning("No buildings retrieved for any overlapping NUTS2 region.")
    return(NULL)
  }
  
  # Combine — rbind is safe now since list-of-list columns are excluded
  buildings_combined <- do.call(rbind, all_buildings)
  buildings_combined <- buildings_combined[!duplicated(buildings_combined$id), ]

  # Summary of construction year coverage
  n_with_year <- sum(!is.na(buildings_combined$construction_year))
  message(sprintf("  %d of %d buildings have construction_year (%.1f%%).",
                  n_with_year, nrow(buildings_combined),
                  100 * n_with_year / max(nrow(buildings_combined), 1)))
  
  return(buildings_combined)
}

################################################################################
# D2K WRAPPER
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3) {
  stop("Usage: Rscript src/get_eubucco_buildings.R <catchment_gpkg_path> <countries_rds_path> <output_buildings_rds_path>", call. = FALSE)
}

catchment_gpkg_path <- args[1]
countries_rds_path <- args[2]
output_buildings_rds_path <- args[3]

message("D2K Wrapper Started for eubucco buildings retrieval.")

tryCatch({
  
  catchment <- sf::st_read(catchment_gpkg_path, quiet = TRUE)
  
  countries_for_catchment <- read_rds_input(countries_rds_path)
  
  eubucco_buildings <- get_eubucco_buildings(catchment = catchment,
                                             countries_for_catchment = countries_for_catchment)
  
  # Save as .rds for machine/subsequent steps
  saveRDS(eubucco_buildings, 
          file = output_buildings_rds_path)
  
  message(paste("D2K Wrapper Finished. Eubucco buildings data saved to", 
                output_buildings_rds_path))
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})
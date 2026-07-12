#!/usr/bin/env Rscript

################################################################################
# MODULE: Get Specific Catchment by basin_id (Hydrography90m / GeoFRESH
# pygeoapi API + GISCO countries).
# Same input as get_hydro90m_catchment.R (a basin_id), but instead of looking
# up countries from the precomputed basin_to_countries.rds, it determines
# overlapping countries live by intersecting the fetched basin polygon
# against GISCO country boundaries (giscoR) - no bundled lookup file needed.
################################################################################

# --- 1. DEPENDENCIES ---
library(sf)
library(httr)
library(giscoR)

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

pygeoapi_base <- "https://aqua.igb-berlin.de/pygeoapi"

# --- 3. FUNCTION DEFINITION (Original Code) ---
################################################################################

call_pygeoapi_process <- function(process_id, inputs) {
  url <- paste0(pygeoapi_base, "/processes/", process_id, "/execution")

  resp <- httr::POST(
    url = url,
    body = list(inputs = inputs),
    encode = "json",
    httr::content_type_json()
  )

  if (httr::status_code(resp) >= 400) {
    stop(httr::content(resp, as = "text", encoding = "UTF-8"), call. = FALSE)
  }
  resp
}

get_basin_polygon <- function(basin_id, target_crs = 3035) {
  resp <- call_pygeoapi_process("get-basin-polygon", list(
    basin_id = as.integer(basin_id),
    geometry_only = FALSE
  ))
  geojson_text <- httr::content(resp, as = "text", encoding = "UTF-8")
  catchment_sf <- sf::st_read(geojson_text, quiet = TRUE)

  # Fix invalid geometries (only where needed)
  bad <- !sf::st_is_valid(catchment_sf)
  if (any(bad)) {
    message("Fixing invalid geometries...")
    catchment_sf[bad, ] <- sf::st_make_valid(catchment_sf[bad, ])
  }

  # Remove empty geometries
  catchment_sf <- catchment_sf[!sf::st_is_empty(catchment_sf), ]

  # Keep only polygon types (safe guard)
  catchment_sf <- catchment_sf[
    sf::st_geometry_type(catchment_sf) %in% c("POLYGON", "MULTIPOLYGON"),
  ]

  # Stop if empty
  if (nrow(catchment_sf) == 0) {
    stop("No valid catchment returned from API.")
  }

  # Enforce multipolygon
  catchment_sf <- sf::st_cast(catchment_sf, "MULTIPOLYGON")

  # Transform CRS
  sf::st_transform(catchment_sf, target_crs)
}

#' Determine which GISCO countries a geometry overlaps, computed live
#' (no hardcoded/precomputed lookup - queries giscoR's country boundaries
#' and spatially intersects them against the catchment).
#'
#' @param geom_sf sf object (the catchment polygon)
#' @param resolution GISCO boundary resolution: "01" (1:1M, most detailed) to
#'   "60" (1:60M, coarsest). "01" avoids the coastline/island mismatches we
#'   saw with coarser resolutions during the Europe-wide basin lookup.
get_countries_for_geometry <- function(geom_sf, resolution = "01") {
  countries <- giscoR::gisco_get_countries(resolution = resolution)
  countries <- sf::st_transform(countries, sf::st_crs(geom_sf))

  hits <- sf::st_filter(countries, geom_sf, .predicate = sf::st_intersects)

  if (nrow(hits) == 0) {
    stop("No GISCO country overlaps this catchment.", call. = FALSE)
  }

  hits$CNTR_ID
}

get_specific_catchment <- function(basin_id,
                                    target_crs = 3035,
                                    gisco_resolution = "01") {

  message("Fetching basin polygon for basin_id ", basin_id, "...")
  catchment_sf <- get_basin_polygon(basin_id, target_crs = target_crs)

  message("Determining overlapping countries via GISCO...")
  countries_for_catchment <- get_countries_for_geometry(catchment_sf, resolution = gisco_resolution)

  message("Catchment retrieval complete.")

  return(list(
    catchment = catchment_sf,
    countries = countries_for_catchment
  ))
}


################################################################################
# --- 4. D2K EXECUTABLE WRAPPER ---
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3) {
  stop("Usage: Rscript get_hydro90m_catchment_by_id_gisco.R <basin_id> <output_catchment_gpkg_path> <output_countries_rds_path>",
       call. = FALSE)
}

# Assign arguments
basin_id <- args[1]
id_num <- as.integer(basin_id)
if (is.na(id_num) || id_num < 1) {
  stop("basin_id must be a positive integer", call. = FALSE)
}
basin_id <- as.character(basin_id)

output_catchment_gpkg_path <- args[2]
output_countries_rds_path <- args[3]

message("D2K Wrapper Started for retrieving Hydrography90m basin catchment (live GISCO country lookup).")

tryCatch({

  result <- get_specific_catchment(
    basin_id = basin_id
  )
  catchment_sf <- result$catchment
  # Save the output (create parent dirs if they don't exist yet - GDAL/SQLite won't)
  dir.create(dirname(output_catchment_gpkg_path), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(output_countries_rds_path), recursive = TRUE, showWarnings = FALSE)
  sf::st_write(catchment_sf, output_catchment_gpkg_path, delete_layer = TRUE, quiet = TRUE)

  countries_for_catchment <- result$countries

  # Save as .rds for machine/subsequent steps
  saveRDS(countries_for_catchment,
          file = output_countries_rds_path)

  message(paste("D2K Wrapper Finished. Catchment saved to",
                output_catchment_gpkg_path,
                " and country list saved to ",
                output_countries_rds_path))

}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})

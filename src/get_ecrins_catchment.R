#!/usr/bin/env Rscript

################################################################################
# MODULE: Get Specific Catchment (ECRINS API).
# Queries ArcGIS REST service for selected catchment ID,
# converts response to sf, validates geometry, and transforms CRS.
################################################################################

# --- 1. DEPENDENCIES ---
library(sf)
library(httr)

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# Hardcoded lookup: catchment → countries
catchment_to_countries <- list(
  `1` = c("AT","SI","CH","FR","DE","ME","XK","DK","BE","ES","BG","EE","FI","AL","CY","EL","HR","UK","IT",
          "LV","MK","NL","MT","LT","RO","PT","NO","PL","IE","IS","SE","RS"),
  `2` = c("FR"),
  `3` = c("FR","ES","PT"),
  `4` = c("FR","ES","PT"),
  `5` = c("FR","ES","PT"),
  `6` = c("UK","IE"),
  `7` = c("UK","IE"),
  `8` = c("UK","IE"),
  `9` = c("FR","ES"),
  `10` = c("FR","ES","PT"),
  `11` = c("FR","ES","PT"),
  `12` = c("FR","ES","PT"),
  `13` = c("FR","ES","PT"),
  `14` = c("FR","ES","PT"),
  `15` = c("UK","IE"),
  `16` = c("FR","ES","PT"),
  `17` = c("FR","ES","PT"),
  `18` = c("FR","ES"),
  `19` = c("FI","NO","SE"),
  `20` = c("FI","NO","SE"),
  `21` = c("FI","NO","SE"),
  `22` = c("FI","NO"),
  `23` = c("UK"),
  `24` = c("FR","BE","UK"),
  `25` = c("UK","IE"),
  `26` = c("UK"),
  `27` = c("FR","UK"),
  `28` = c("UK","IE"),
  `29` = c("UK","IE"),
  `30` = c("UK"),
  `31` = c("UK"),
  `32` = c("FR","UK"),
  `33` = c("UK","IE"),
  `34` = c("NO","SE"),
  `35` = c("AT","CZ","FR","DE","PL"),
  `36` = c("FR","DE"),
  `37` = c("AT","CH","FR","DE","LU","BE","IT","NL","LI"),
  `38` = c("NO"),
  `39` = c("NO"),
  `40` = c("DE","DK","SE"),
  `41` = c("DE","DK"),
  `42` = c("DE","NL"),
  `43` = c("FR","DE","LU","BE","NL"),
  `44` = c("FR","BE","UK","NL"),
  `45` = c("FR","UK"),
  `46` = c("UK"),
  `47` = c("FI","NO"),
  `48` = c("UK"),
  `49` = c("UK"),
  `50` = c("UK"),
  `51` = c("UK"),
  `52` = c("FI","NO"),
  `53` = c("LV","LT","PL","SE"),
  `54` = c("CZ","SK","FR","LT","PL"),
  `55` = c("CZ","SK","FR","DE","PL"),
  `56` = c("DK","NO","SE"),
  `57` = c("FI","NO","SE"),
  `58` = c("FI","NO","SE"),
  `59` = c("FI","NO","SE"),
  `60` = c("EE","LV","NO"),
  `61` = c("EE","LV","LT","SE"),
  `62` = c("LV","LT","SE"),
  `63` = c("LT","PL"),
  `64` = c("DE","DK"),
  `65` = c("DE","DK"),
  `66` = c("FI","NO","SE"),
  `67` = c("FI","NO","SE"),
  `68` = c("FI","NO","SE"),
  `69` = c("EE","LV","NO","SE"),
  `70` = c("EE","LV","NO","SE"),
  `71` = c("EE","LV","LT","SE"),
  `72` = c("PL"),
  `73` = c("PL"),
  `74` = c("DK","NO","SE"),
  `75` = c("NO","SE"),
  `76` = c("DE","DK","SE"),
  `77` = c("DE","DK"),
  `78` = c("FI","NO","SE"),
  `79` = c("FR","ES"),
  `80` = c("FR","ES"),
  `81` = c("CH","FR","DE","ES","IT"),
  `82` = c("FR","HR","IT"),
  `83` = c("FR","ES"),
  `84` = c("FR","ES"),
  `85` = c("FR","ES"),
  `86` = c("FR","HR","IT"),
  `87` = c("FR","IT"),
  `88` = c("FR","IT"),
  `89` = c("FR","ES"),
  `90` = c("FR","IT"),
  `91` = c("FR","IT"),
  `92` = c("AT","CH","FR","IT"),
  `93` = c("FR","BG","EL"),
  `94` = c("FR","IT"),
  `95` = c("FR","BG","EL","MK","RS"),
  `96` = c("AT","SI","CH","FR","HR","IT"),
  `97` = c("AT","SI","FR","HR","IT"),
  `98` = c("FR","EL"),
  `99` = c("FR","AL","EL","MK"),
  `100` = c("FR","XK","BG","AL","EL","MK","RS"),
  `101` = c("FR","AL","EL"),
  `102` = c("FR","EL"),
  `103` = c("FR","EL"),
  `104` = c("FR","EL"),
  `105` = c("FR","EL"),
  `106` = c("FR","EL"),
  `107` = c("FR","EL"),
  `108` = c("FR","IT","MT"),
  `109` = c("FR","EL"),
  `110` = c("FR","EL"),
  `111` = c("FR","CY"),
  `112` = c("AT","CZ","SK","SI","CH","FR","DE","ME","XK","BG","AL","HU","HR","IT","MK","RO","PL","RS"),
  `113` = c("FR","BG","RO"),
  `114` = c("SK","FR","RO","PL"),
  `115` = c("FI","NO"),
  `116` = c("FI","NO","SE"),
  `117` = c("FR","ES","PT"),
  `118` = c("FR","ES")
)

# --- 3. FUNCTION DEFINITION (Original Code) ---
################################################################################

get_specific_catchment <- function(catchment_id,
                                   target_crs = 3035) {
  
  message("Querying ArcGIS catchment service...")
  base_url <- "https://water.discomap.eea.europa.eu/arcgis/rest/services/Ecrins/ECRINS_FunctionalElementaryCatchments/MapServer/0/query"
  
  resp <- httr::GET(
    url = base_url,
    query = list(
      objectIds = catchment_id,
      outFields = "*",
      f = "geojson"
    )
  )
  
  #httr::stop_for_status(resp)
  if (httr::status_code(resp) != 200) {
    stop(httr::content(resp, as = "text", encoding = "UTF-8"),
         call. = FALSE)
  }
  
  geojson_text <- httr::content(resp, "text", encoding = "UTF-8")
  
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
  catchment_sf <- sf::st_transform(catchment_sf, target_crs)
  
  # look up countries
  countries_for_catchment <- catchment_to_countries[[catchment_id]]
  
  if (is.null(countries_for_catchment)) {
    stop("No country mapping found for this catchment_id", call. = FALSE)
  }
  
  message("Catchment retrieval complete.")
  
  return(list(
    catchment = catchment_sf,
    countries = countries_for_catchment
  ))
  #return(catchment_sf)
}


################################################################################
# --- 4. D2K EXECUTABLE WRAPPER ---
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3) {
  stop("Usage: Rscript get_ecrins_catchment.R <catchment_id> <output_catchment_gpkg_path> <output_countries_rds_path>",
       call. = FALSE)
}

# Assign arguments
catchment_id <- args[1] 
# validation (clean version)
id_num <- as.integer(catchment_id)
# must be 1–118
if (is.na(id_num) || id_num < 1 || id_num > 118) {
  stop("catchment_id must be from 1 to 118", call. = FALSE)
}
catchment_id <- as.character(catchment_id)

output_catchment_gpkg_path <- args[2] 
output_countries_rds_path <- args[3]

message("D2K Wrapper Started for retrieving ECRINS catchment.")

tryCatch({
  
  result <- get_specific_catchment(
    catchment_id = catchment_id
  )
  catchment_sf <- result$catchment
  # Save the output
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

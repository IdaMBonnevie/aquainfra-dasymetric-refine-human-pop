#!/usr/bin/env Rscript

################################################################################
# MODULE: Calculate weights for dasymetric mapping. Calculate weights based on 
# overlapping Eurostat censusgrid containing human population of year 2021 
# with Corine CLC 2018 raster to deduce population density-based weights.
################################################################################

# --- 1. DEPENDENCIES ---
library(terra)
library(dplyr)
library(rlang)

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# --- 3. FUNCTION DEFINITION (Original Code) ---
calculate_weighting <- function(census_grid_geom,
                                cor_raster_geom,
                                cor_name_raster_columnname,
                                cor_code_raster_columnname,
                                clc_legend = clc_legend,
                                census_grid_value_col = "TOT_P_2021",
                                census_grid_value_col_fallback = "TOT_P_2018",
                                cor_urban_values = NULL,
                                additional_candidate_classes_to_consider = NA) {

  # get census_grid as terra vector
  census_vect <- terra::vect(census_grid_geom)
  n_census_cells_total <- length(census_vect)

  # A column "exists" (for our purposes) only if it's present AND has at
  # least one usable (positive) value — e.g. Eurostat's 2021 population grid
  # column is present but all-zero for the UK, which isn't usable either.
  col_has_usable_data <- function(col) {
    !is.null(col) &&
      col %in% names(census_vect) &&
      any(!is.na(census_vect[[col]]) & census_vect[[col]] > 0)
  }

  if (!col_has_usable_data(census_grid_value_col) &&
      col_has_usable_data(census_grid_value_col_fallback)) {
    message(sprintf(
      "Note: '%s' has no usable population data for this catchment; falling back to '%s'.",
      census_grid_value_col, census_grid_value_col_fallback
    ))
    census_grid_value_col <- census_grid_value_col_fallback
  }

  # Cells with no data (NA) and cells with a measured population of zero are
  # semantically different — NA means the census grid doesn't cover this cell,
  # zero means it was measured and genuinely nobody lives there (e.g. forest,
  # farmland). Count them separately before filtering so we can report them
  # separately rather than lumping "no data" together with "normal, uninhabited".
  n_census_cells_na <- sum(is.na(census_vect[[census_grid_value_col]]))
  n_census_cells_zero <- sum(
    !is.na(census_vect[[census_grid_value_col]]) &
      census_vect[[census_grid_value_col]] <= 0
  )

  # Only keep cells with positive population — avoids diluting the density
  # calculation with zero/NA-population cells further down (zonal mean, etc.)
  census_vect <- census_vect[
    !is.na(census_vect[[census_grid_value_col]]) &
      census_vect[[census_grid_value_col]] > 0,
  ]
  n_census_cells_valid <- length(census_vect)

  if (n_census_cells_valid == 0) {
    stop(
      sprintf(
        "No census grid cells with positive population found for this catchment (checked '%s'%s); cannot calculate weights. This may mean the catchment falls outside the census grid's coverage (e.g. the UK is not covered by Eurostat's 2021 census grid).",
        census_grid_value_col,
        if (!is.null(census_grid_value_col_fallback)) sprintf(" and fallback '%s'", census_grid_value_col_fallback) else ""
      ),
      call. = FALSE
    )
  } else if (n_census_cells_valid < n_census_cells_total) {
    exclusion_parts <- character(0)
    if (n_census_cells_na > 0) {
      exclusion_parts <- c(exclusion_parts, sprintf("%d with no data (NA)", n_census_cells_na))
    }
    if (n_census_cells_zero > 0) {
      exclusion_parts <- c(exclusion_parts, sprintf("%d with a measured population of zero", n_census_cells_zero))
    }
    message(sprintf(
      "Note: %d of %d census grid cells in this catchment are excluded from the weighting calculation using '%s' (%s). Proceeding with the remaining %d cell(s).",
      n_census_cells_total - n_census_cells_valid, n_census_cells_total, census_grid_value_col,
      paste(exclusion_parts, collapse = "; "), n_census_cells_valid
    ))
  }

  # FIRST: TREAT CATEGORY 111 CONTINUOUS URBAN
  # keep only urban corine classes in country specific corine raster
  cor_111 <- terra::classify(
    cor_raster_geom,
    rcl = matrix(c(111,111), ncol=2),
    others = NA
  )
  
  avg_111 <- NULL

  if (terra::global(!is.na(cor_111), "sum", na.rm = TRUE)[1,1] > 0) {

    avg_111 <- tryCatch({

      # Create raster with census grid population masked to
      # only be with values for artificial surface CORINE categories
      # (use max value if overlapping polygons within cell):
      census_raster_111_draft <- terra::rasterize(census_vect,
                                                  cor_111,
                                                  field = census_grid_value_col,
                                                  fun = "max") |> terra::mask(cor_111) # max value if overlaps

      # count number of cor_111 cells per polygon (feature)
      counts_111 <- terra::extract(
        cor_111,
        census_vect,
        fun = function(x, ...) sum(!is.na(x)),
        df = TRUE
      )
      census_vect$cell_111_count <- counts_111[,2]

      # Create raster with census grid population masked to
      # only be with values for artificial surface CORINE categories
      # (use max value if overlapping polygons within cell):
      census_raster_111_count_draft <- terra::rasterize(census_vect,
                                                        cor_111,
                                                        field = "cell_111_count",
                                                        fun = "max") |> terra::mask(cor_111) # max value if overlaps

      census_raster_111 <- census_raster_111_draft / census_raster_111_count_draft

      # Reattach factor levels
      levels(cor_111) <- clc_legend[, c("CODE_18","LABEL")]

      # Average population per 100x100 m per CORINE urban category:
      terra::zonal(census_raster_111, #_correctedF1,
                  cor_111, #cor_country_maskedF1,
                  fun = "mean",
                  na.rm = TRUE) # ignore NA values

    }, error = function(e) {
      message(sprintf(
        "Note: no census population data overlaps CORINE class 111 in this catchment; skipping this class (%s).",
        conditionMessage(e)
      ))
      NULL
    })
  }
  
  # SECOND: TREAT CATEGORY 111 CONTINUOUS URBAN
  # keep only urban corine classes in country specific corine raster
  cor_112 <- terra::classify(
    cor_raster_geom,
    rcl = matrix(c(112,112), ncol=2),
    others = NA
  )
  
  # extract raster values over polygons
  ex_111 <- terra::extract(cor_111, census_vect, df = TRUE)
  # which polygons have at least one non-NA raster value
  valid_ids_111 <- ex_111$ID[!is.na(ex_111[[2]])]
  # unique GRD_IDs for those polygons
  used_ids_111 <- unique(census_vect$GRD_ID[valid_ids_111])
  # mask out census
  census_masked_111 <- census_vect[!census_vect$GRD_ID %in% used_ids_111, ]
  
  avg_112 <- NULL

  if (terra::global(!is.na(cor_112), "sum", na.rm = TRUE)[1,1] > 0) {

    avg_112 <- tryCatch({

      # Create raster with census grid population masked to
      # only be with values for artificial surface CORINE categories
      # (use max value if overlapping polygons within cell):
      census_raster_112_draft <- terra::rasterize(census_masked_111,
                                                  cor_112,
                                                  field = census_grid_value_col,
                                                  fun = "max") |> terra::mask(cor_112) # max value if overlaps

      # count number of cor_112 cells per polygon (feature)
      counts_112 <- terra::extract(
        cor_112,
        census_masked_111,
        fun = function(x, ...) sum(!is.na(x)),
        df = TRUE
      )
      census_masked_111$cell_112_count <- counts_112[,2]

      # Create raster with census grid population masked to
      # only be with values for artificial surface CORINE categories
      # (use max value if overlapping polygons within cell):
      census_raster_112_count_draft <- terra::rasterize(census_masked_111,
                                                        cor_112,
                                                        field = "cell_112_count",
                                                        fun = "max") |> terra::mask(cor_112) # max value if overlaps

      census_raster_112 <- census_raster_112_draft / census_raster_112_count_draft

      # Reattach factor levels
      levels(cor_112) <- clc_legend[, c(cor_code_raster_columnname, cor_name_raster_columnname)]

      # Average population per 100x100 m per CORINE urban category:
      terra::zonal(census_raster_112, #_correctedF1,
                  cor_112, #cor_country_maskedF1,
                  fun = "mean",
                  na.rm = TRUE) # ignore NA values

    }, error = function(e) {
      message(sprintf(
        "Note: no census population data overlaps CORINE class 112 in this catchment; skipping this class (%s).",
        conditionMessage(e)
      ))
      NULL
    })
  }
  
  # extract raster values over polygons
  ex_112 <- terra::extract(cor_112, census_masked_111, df = TRUE)
  # which polygons have at least one non-NA raster value
  valid_ids_112 <- ex_112$ID[!is.na(ex_112[[2]])]
  # unique GRD_IDs for those polygons
  used_ids_112 <- unique(census_masked_111$GRD_ID[valid_ids_112])
  # mask out census
  census_masked_112_111 <- census_masked_111[!census_masked_111$GRD_ID %in% used_ids_112, ]
  
  # THIRD: TREAT OTHER CATEGORIES (optional)
  # Only run when the caller opted in via additional_candidate_classes_to_consider
  avg_other <- NULL

  if (!is.na(additional_candidate_classes_to_consider)) {

    if (additional_candidate_classes_to_consider == "all_artificial_surface_classes") {

      if (is.null(cor_urban_values)) {
        stop("cor_urban_values must be supplied when additional_candidate_classes_to_consider = 'all_artificial_surface_classes'", call. = FALSE)
      }

      # USE ONLY OTHER URBAN CORINE CLASSES:
      cor_urban_values_other <- cor_urban_values[!cor_urban_values %in% c(111, 112)]

      cor_other_artificial <- terra::classify(
        cor_raster_geom,
        rcl = cbind(cor_urban_values_other, cor_urban_values_other),
        others = NA
      )

    } else if (additional_candidate_classes_to_consider == "all_other_classes") {

      # USE OTHER CORINE CLASSES:
      cor_values_other <- clc_legend$CODE_18[!clc_legend$CODE_18 %in% c(111, 112)]

      cor_other_artificial <- terra::classify(
        cor_raster_geom,
        rcl = cbind(cor_values_other, cor_values_other),
        others = NA
      )

    } else {
      stop(
        paste0(
          "Invalid additional_candidate_classes_to_consider: ", additional_candidate_classes_to_consider,
          ". Allowed values are 'all_artificial_surface_classes', 'all_other_classes', or NA."
        ),
        call. = FALSE
      )
    }

    # Only proceed if this catchment actually has cells in these classes —
    # otherwise zonal() has nothing to aggregate and errors out.
    if (terra::global(!is.na(cor_other_artificial), "sum", na.rm = TRUE)[1,1] > 0) {

      avg_other <- tryCatch({

        # Create raster with census grid population masked to
        # only be with values for artificial surface CORINE categories
        # (use max value if overlapping polygons within cell):
        census_raster_other_draft <- terra::rasterize(census_masked_112_111,
                                                      cor_other_artificial,
                                                      field = census_grid_value_col,
                                                      fun = "max") |> terra::mask(cor_other_artificial) # max value if overlaps

        # count number of cor_112 cells per polygon (feature)
        counts_other <- terra::extract(
          cor_other_artificial,
          census_masked_112_111,
          fun = function(x, ...) sum(!is.na(x)),
          df = TRUE
        )
        census_masked_112_111$cell_other_count <- counts_other[,2]

        # Create raster with census grid population masked to
        # only be with values for artificial surface CORINE categories
        # (use max value if overlapping polygons within cell):
        census_raster_other_count_draft <- terra::rasterize(census_masked_112_111,
                                                            cor_other_artificial,
                                                            field = "cell_other_count",
                                                            fun = "max") |> terra::mask(cor_other_artificial) # max value if overlaps

        census_raster_other <- census_raster_other_draft / census_raster_other_count_draft

        # Reattach factor levels
        levels(cor_other_artificial) <- clc_legend[, c(cor_code_raster_columnname, cor_name_raster_columnname)]

        # Average population per 100x100 m per CORINE urban category:
        terra::zonal(census_raster_other, #_correctedF1,
                    cor_other_artificial, #cor_country_maskedF1,
                    fun = "mean",
                    na.rm = TRUE) # ignore NA values

      }, error = function(e) {
        message(sprintf(
          "Note: no census population data overlaps the additional candidate classes (%s) in this catchment; skipping this step (%s).",
          additional_candidate_classes_to_consider, conditionMessage(e)
        ))
        NULL
      })
    }
  }

  # Combine whichever of avg_111 / avg_112 / avg_other were successfully computed
  avg_tables <- Filter(Negate(is.null), list(avg_111, avg_112, avg_other))

  if (length(avg_tables) == 0) {
    stop(
      "No CORINE classes in this catchment had any overlapping census population data; cannot calculate weights.",
      call. = FALSE
    )
  }

  avg_pop_per_corineF1 <- do.call(rbind, avg_tables)

  avg_pop_per_corineF1 <- avg_pop_per_corineF1[!is.na(avg_pop_per_corineF1[[census_grid_value_col]]), ]
  
  # Summing the mean population density across all urban CORINE classes: 
  total_avg_sumF1 <- sum(avg_pop_per_corineF1[[census_grid_value_col]]) # sum(avg_pop_per_corineF1$T)
  
  # Add sum of all mean cases as column in statistics table: 
  avg_pop_per_corineF1$percent <- round(avg_pop_per_corineF1[[census_grid_value_col]] / total_avg_sumF1 * 100, 2)  

  # Filter on percent
  #avg_pop_per_corineF1 <- avg_pop_per_corineF1[
  #  avg_pop_per_corineF1$percent >= 1.0, 
  #]
  
  ####### COMBINED WEIGHTING 
  # Turn string into variable
  cor_name_raster_columnname_variable <- rlang::ensym(cor_name_raster_columnname)
  
  # Add CORINE descriptions to full weight table
  weight_table_full <- dplyr::left_join(
    avg_pop_per_corineF1,
    clc_legend, 
    by = rlang::as_string(cor_name_raster_columnname)  
  )
  
  # Select only CODE_18, percent, and LABEL columns 
  weight_table_final <- weight_table_full %>%
    dplyr::select(dplyr::all_of(cor_code_raster_columnname), 
                  percent, 
                  dplyr::all_of(cor_name_raster_columnname))
  
  return(weight_table_final)
  
}  


################################################################################
# D2K WRAPPER
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 7) {
  stop("Usage: Rscript src/calculate_weighting.R <censusgrid_selected_rds_path> <corineCLC_cropped_rds_path> <corine_year_rds_path> <clc_legend_rds_path> <cor_urban_values_rds_path|NA> <additional_candidate_classes_to_consider: all_artificial_surface_classes|all_other_classes|NA> <weight_table_rds_path>", call. = FALSE)
}

censusgrid_selected_rds_path <- args[1]
corineCLC_cropped_rds_path <- args[2]

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

clc_legend_rds_path <- args[4]
cor_urban_values_rds_path <- args[5]
additional_candidate_classes_to_consider_arg <- args[6]
weight_table_rds_path <- args[7]

message("D2K Wrapper Started for corine CLC retrieval.")

tryCatch({
  
  census_grid <- readRDS(censusgrid_selected_rds_path)
  
  corine2018_cropped <- readRDS(corineCLC_cropped_rds_path)
  
  cor_name_raster_columnname <- "LABEL"    
  cor_code_raster_columnname <- paste0("CODE_", substr(corine_year, 3, 4)) # e.g. "CODE_18"

  clc_legend <- readRDS(clc_legend_rds_path)

  # Optional inputs: "NA" signals the input was not supplied
  cor_urban_values <- if (identical(cor_urban_values_rds_path, "NA")) {
    NULL
  } else {
    readRDS(cor_urban_values_rds_path)
  }

  additional_candidate_classes_to_consider <- if (identical(additional_candidate_classes_to_consider_arg, "NA")) {
    NA
  } else {
    additional_candidate_classes_to_consider_arg
  }

  # calculate weighting
  weight_table_final <- calculate_weighting(census_grid_geom = census_grid,
                                            cor_raster_geom = corine2018_cropped,
                                            cor_name_raster_columnname = cor_name_raster_columnname,
                                            cor_code_raster_columnname = cor_code_raster_columnname,
                                            clc_legend = clc_legend,
                                            census_grid_value_col = "TOT_P_2021",
                                            cor_urban_values = cor_urban_values,
                                            additional_candidate_classes_to_consider = additional_candidate_classes_to_consider)

  # Save as .rds for machine/subsequent steps
  saveRDS(weight_table_final, 
          file = weight_table_rds_path)
  
  message(paste("D2K Wrapper Finished. Table with weights saved to", 
                weight_table_rds_path))
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})

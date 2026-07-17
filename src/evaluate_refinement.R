#!/usr/bin/env Rscript

################################################################################
# MODULE: Evaluate dasymetric refinement result. Create two evaluation datasets 
# respectively based on weighted refinement compared with census grid 2021 data 
# and on simple refinement also compared with census grid 2021. Metrics are 
# calculated to evaluate errors from the two datasets with census grid 2021 being
# perceived as observed true data (control data).
################################################################################

# --- 1. DEPENDENCIES ---
library(terra)
library(Metrics)
library(dplyr)
library(sf)

source("src/utils_io.R")

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# Prefer preferred_col; fall back to fallback_col if preferred_col has no
# usable (positive) values for this catchment — e.g. Eurostat's 2021 census
# grid doesn't cover the UK, but 2018 does.
resolve_census_grid_value_col <- function(census_grid, preferred_col = "TOT_P_2021", fallback_col = "TOT_P_2018") {
  col_has_usable_data <- function(col) {
    col %in% names(census_grid) &&
      any(!is.na(census_grid[[col]]) & census_grid[[col]] > 0)
  }
  if (!col_has_usable_data(preferred_col) && col_has_usable_data(fallback_col)) {
    message(sprintf(
      "Note: '%s' has no usable population data for this catchment; falling back to '%s'.",
      preferred_col, fallback_col
    ))
    return(fallback_col)
  }
  preferred_col
}

# --- 3. FUNCTION DEFINITION (Original Code) ---
add_evaluations_to_censusgrid <- function(refinement_reference_cropped,
                                          refinement_reference_simple,
                                          census_grid_geom_cropped,
                                          census_grid_value_col, 
                                          pop_reference_year = "2021"
) {
  # make a copy (so original is untouched)
  census_grid_eval1 <- census_grid_geom_cropped
  census_grid_eval2 <- census_grid_geom_cropped

  # make new comparison census grid 
  pop_census1 <- terra::extract(refinement_reference_cropped, census_grid_eval1, fun = sum, na.rm = TRUE)
  census_grid_eval1$pop_est_cell1 <- pop_census1[,2]
  
  pop_census2 <- terra::extract(refinement_reference_simple, census_grid_eval2, fun = sum, na.rm = TRUE)
  census_grid_eval2$pop_est_cell2 <- pop_census2[,2]
  
  # limit to grid cells with values 
  census_grid_eval1 <- census_grid_eval1[
    !(is.na(census_grid_eval1$pop_est_cell1) & is.na(census_grid_eval1[[census_grid_value_col]])),
  ]
  census_grid_eval1 <- census_grid_eval1[
    !((census_grid_eval1$pop_est_cell1 == 0) & is.na(census_grid_eval1[[census_grid_value_col]])),
  ]
  census_grid_eval1 <- census_grid_eval1[
    !((census_grid_eval1$pop_est_cell1 == 0) & (census_grid_eval1[[census_grid_value_col]] == 0)),
  ]
  census_grid_eval1 <- census_grid_eval1[
    !(is.na(census_grid_eval1$pop_est_cell1) & (census_grid_eval1[[census_grid_value_col]] == 0)),
  ]
  # limit to grid cells with values 
  census_grid_eval2 <- census_grid_eval2[
    !(is.na(census_grid_eval2$pop_est_cell2) & is.na(census_grid_eval2[[census_grid_value_col]])),
  ]
  census_grid_eval2 <- census_grid_eval2[
    !((census_grid_eval2$pop_est_cell2 == 0) & is.na(census_grid_eval2[[census_grid_value_col]])),
  ]
  census_grid_eval2 <- census_grid_eval2[
    !((census_grid_eval2$pop_est_cell2 == 0) & (census_grid_eval2[[census_grid_value_col]] == 0)),
  ]
  census_grid_eval2 <- census_grid_eval2[
    !(is.na(census_grid_eval2$pop_est_cell2) & (census_grid_eval2[[census_grid_value_col]] == 0)),
  ]
  
  # Replace NA or NaN in the estimated pop_est column
  census_grid_eval1$pop_est_cell1[is.na(census_grid_eval1$pop_est_cell1)] <- 0
  # Replace NA or NaN in the observed population column
  census_grid_eval1[[census_grid_value_col]][is.na(census_grid_eval1[[census_grid_value_col]])] <- 0
  # Replace NA or NaN in the estimated pop_est column
  census_grid_eval2$pop_est_cell2[is.na(census_grid_eval2$pop_est_cell2)] <- 0
  # Replace NA or NaN in the observed population column
  census_grid_eval2[[census_grid_value_col]][is.na(census_grid_eval2[[census_grid_value_col]])] <- 0
  
  # Calculate absolute difference of estimated population minus observed population
  census_grid_eval1$dif1 <- census_grid_eval1$pop_est_cell1 - census_grid_eval1[[census_grid_value_col]]
  # Calculate absolute difference of estimated population minus observed population
  census_grid_eval2$dif2 <- census_grid_eval2$pop_est_cell2 - census_grid_eval2[[census_grid_value_col]]

  # Calculate percentage difference of estimated population minus observed population
  census_grid_eval1$dif_perc1 <- abs((census_grid_eval1$dif1 / census_grid_eval1[[census_grid_value_col]]) * 100)
  # Replace NA or NaN in the dif_perc column
  census_grid_eval1$dif_perc1[is.na(census_grid_eval1$dif_perc1)] <- 0
  census_grid_eval1$dif_perc1[is.infinite(census_grid_eval1$dif_perc1)] <- 999
  # Calculate percentage difference of estimated population minus observed population
  census_grid_eval2$dif_perc2 <- abs((census_grid_eval2$dif2 / census_grid_eval2[[census_grid_value_col]]) * 100)
  # Replace NA or NaN in the dif_perc column
  census_grid_eval2$dif_perc2[is.na(census_grid_eval2$dif_perc2)] <- 0
  census_grid_eval2$dif_perc2[is.infinite(census_grid_eval2$dif_perc2)] <- 999
  
  #####
  # keep only for percentage
  ## excluding estimated cells where no observed values exist (dif_perc1 = 999)
  ## excluding observed cells where no estimated values exist
  idx_perc1 <- (                                    # keep only the combination of: 
    census_grid_eval1$pop_est_cell1 != 0. &          # estimated values
      !is.na(census_grid_eval1$pop_est_cell1) &      # that are not NA
      census_grid_eval1$dif_perc1 != 999.0           # and that are for areas with observed values (999 are infinite values)
  ) 
  # true perc subset
  true_perc1 <- census_grid_eval1[[census_grid_value_col]][idx_perc1]
  # predicted perc subset 
  pred_perc1 <- census_grid_eval1$pop_est_cell1[idx_perc1]
  
  # keep only for direct errors
  ## including estimated cells where no observed values exist (dif_perc1 = 999)
  ## including observed cells where no estimated values exist
  idx1 <- (                                          # keep only the combination of: 
    census_grid_eval1$pop_est_cell1 != 0. &           # estimated values
      !is.na(census_grid_eval1$pop_est_cell1)         # that are not NA
  ) |
    (
      census_grid_eval1[[census_grid_value_col]] != 0     # include also areas with observed values without estimated values
    )
  # true direct subset
  true1 <- census_grid_eval1[[census_grid_value_col]][idx1]
  # predicted direct subset 
  pred1 <- census_grid_eval1$pop_est_cell1[idx1]
  
  metrics <- data.frame(
    overall_perc_error = mean(abs(census_grid_eval1$dif_perc1[idx_perc1]), na.rm = TRUE),
    overall_error_avg  = mean(abs(census_grid_eval1$dif1[idx1]), na.rm = TRUE),
    number_of_wrong_cells_included = length(census_grid_eval1$dif_perc1[census_grid_eval1$dif_perc1 == 999.0]),
    number_of_correct_cells_excluded = length(census_grid_eval1$dif_perc1[census_grid_eval1$dif_perc1 == 100.0]),
    bias = Metrics::bias(true1, pred1), # Underestimation (-) or overestimation (+) trend
    mae = Metrics::mae(true1, pred1), # Mean Absolute Error: Predictions differ on average from the true values by X units
    mdae = Metrics::mdae(true1, pred1), # Median Absolute Error: Half of your predictions are within X units of the true value
    mse = Metrics::mse(true1, pred1), # Mean Squared Error: The average squared prediction error (large errors count more)
    rmse = Metrics::rmse(true1, pred1), # Root Mean Squared Error: The same units as your target variable, unlike MSE
    mape = Metrics::mape(true_perc1, pred_perc1), # Mean Absolute Percentage Error: 
    popyear = pop_reference_year
  )
  
  # keep only for percentage
  ## excluding estimated cells where no observed values exist (dif_perc1 = 999)
  ## excluding observed cells where no estimated values exist
  idx_perc2 <- (                                           # keep only the combination of: 
    census_grid_eval2$pop_est_cell2 != 0. &          # estimated values
      !is.na(census_grid_eval2$pop_est_cell2) &      # that are not NA
      census_grid_eval2$dif_perc2 != 999.0           # and that are for areas with observed values (999 are infinite values)
  ) 
  # true perc subset
  true_perc2 <- census_grid_eval2[[census_grid_value_col]][idx_perc2]
  # predicted perc subset 
  pred_perc2 <- census_grid_eval2$pop_est_cell2[idx_perc2]
  
  # keep only for direct errors
  ## including estimated cells where no observed values exist (dif_perc1 = 999)
  ## including observed cells where no estimated values exist
  idx2 <- (                                                   # keep only the combination of: 
    census_grid_eval2$pop_est_cell2 != 0. &             # estimated values
      !is.na(census_grid_eval2$pop_est_cell2)           # that are not NA
  ) |
    (
      census_grid_eval2[[census_grid_value_col]] != 0   # include also areas with observed values without estimated values
    )
  # true direct subset
  true2 <- census_grid_eval2[[census_grid_value_col]][idx2]
  # predicted direct subset 
  pred2 <- census_grid_eval2$pop_est_cell2[idx2]
  
  metrics_simple <- data.frame(
    overall_perc_error = mean(abs(census_grid_eval2$dif_perc2[idx_perc2]), na.rm = TRUE),
    overall_error_avg  = mean(abs(census_grid_eval2$dif2[idx2]), na.rm = TRUE),
    number_of_wrong_cells_included = length(census_grid_eval2$dif_perc2[census_grid_eval2$dif_perc2 == 999.0]),
    number_of_correct_cells_excluded = length(census_grid_eval2$dif_perc2[census_grid_eval2$dif_perc2 == 100.0]),
    bias = Metrics::bias(true2, pred2),
    mae = Metrics::mae(true2, pred2),
    mdae = Metrics::mdae(true2, pred2),
    mse = Metrics::mse(true2, pred2),
    rmse = Metrics::rmse(true2, pred2),
    mape = Metrics::mape(true_perc2, pred_perc2),
    popyear = pop_reference_year
  )

  return(list(result1 = census_grid_eval1,
              result2 = census_grid_eval2, 
              result3 = metrics, 
              result4 = metrics_simple))
  
} 

get_only_corineCLC_overlapping_positive_pop <- function(census_grid_geom,
                                                        cor_rast_geom, 
                                                        census_grid_value_col) 
  {
  
  popCensusNotZero <- census_grid_geom[census_grid_geom[[census_grid_value_col]] > 0, ]
  popCensusNotZero_vect <- terra::vect(popCensusNotZero)

  # corine raster geom overlapping census grid masked to river catchment 
  cor_rast_geom_obs <- cor_rast_geom %>%
    terra::mask(popCensusNotZero_vect)
}

################################################################################
# D2K WRAPPER
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 9) {
  stop("Usage: Rscript src/evaluate_refinement.R <refinement_weighted_reference_rds_path> <refinement_simple_reference_rds_path> <census_grid_rds_path> <corineCLC_rds_path> <output_evaluate_weighted_rds_path> <output_evaluate_simple_rds_path> <output_corineCLC_only_potisive_rds_path> <output_metrics_rds_path> <output_metrics_simple_rds_path>", call. = FALSE) 
}

refinement_weighted_reference_rds_path <- args[1]
refinement_simple_reference_rds_path <- args[2]
census_grid_rds_path <- args[3]
corineCLC_rds_path <- args[4]
output_evaluate_weighted_rds_path <- args[5]
output_evaluate_simple_rds_path <- args[6]
output_corineCLC_only_potisive_rds_path <- args[7]
output_metrics_rds_path <- args[8]
output_metrics_simple_rds_path <- args[9]

message("D2K Wrapper Started for creating evaluation datasets.")

tryCatch({
  
  # Read spatial focus object
  refinement_weighted <- read_rds_input(refinement_weighted_reference_rds_path)
  refinement_weighted <- terra::unwrap(refinement_weighted)
  
  # Read spatial focus object
  refinement_simple <- read_rds_input(refinement_simple_reference_rds_path)
  refinement_simple <- terra::unwrap(refinement_simple)

  # Read spatial focus object
  census_grid <- read_rds_input(census_grid_rds_path)

  census_grid_value_col_resolved <- resolve_census_grid_value_col(census_grid)
  pop_reference_year_resolved <- sub("^TOT_P_", "", census_grid_value_col_resolved)

  census_grid_evals <- add_evaluations_to_censusgrid(refinement_reference_cropped = refinement_weighted,
                                                     refinement_reference_simple = refinement_simple,
                                                     census_grid_geom_cropped = census_grid,
                                                     census_grid_value_col = census_grid_value_col_resolved,
                                                     pop_reference_year = pop_reference_year_resolved)
  census_grid_eval_weighted <- census_grid_evals$result1
  census_grid_eval_simple <- census_grid_evals$result2
  metrics_weighted <- census_grid_evals$result3
  metrics_simple <- census_grid_evals$result4
  
  # Save as .rds for machine/subsequent steps
  saveRDS(census_grid_eval_weighted, 
          file = output_evaluate_weighted_rds_path)
  
  # Save as .rds for machine/subsequent steps
  saveRDS(census_grid_eval_simple, 
          file = output_evaluate_simple_rds_path)
  
  # Save as .rds for machine/subsequent steps
  saveRDS(metrics_weighted, 
          file = output_metrics_rds_path)

  # Save as .rds for machine/subsequent steps
  saveRDS(metrics_simple, 
          file = output_metrics_simple_rds_path)

  # Read spatial focus object
  corineCLC <- read_rds_input(corineCLC_rds_path)
  
  corineCLC_overlapping_positive_pop <- get_only_corineCLC_overlapping_positive_pop(census_grid_geom = census_grid,
                                                                                     cor_rast_geom = corineCLC,
                                                                                     census_grid_value_col = census_grid_value_col_resolved)
  
  # Save as .rds for machine/subsequent steps
  saveRDS(corineCLC_overlapping_positive_pop, 
          file = output_corineCLC_only_potisive_rds_path)
  
  message(paste("D2K Wrapper Finished. Weighted evaluation dataset saved to", 
                output_evaluate_weighted_rds_path, 
                " and simple evaluation datasets saved to ", 
                output_evaluate_simple_rds_path, 
                " and Corine CLC 2018 overlapping positive 2021 census grid population is saved to ",
                output_corineCLC_only_potisive_rds_path))
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})

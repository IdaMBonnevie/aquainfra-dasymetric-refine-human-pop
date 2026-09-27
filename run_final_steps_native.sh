#!/bin/bash
# Re-runs Steps 10-12 with the local R installation instead of Docker, as in the
# August Elbe runs. Docker Desktop's memory cap is too small for the census grid
# map of large catchments (e.g. ECRINS 35, Hydrography90m 1294020).
# Usage: bash run_final_steps_native.sh <output folder> [thresholdval] [thresholdvalfortruth]
set -e
# Run R in a UTF-8 locale; in the plain "C" locale non-ASCII text such as the
# en dash in legend labels is written out as raw bytes (e.g. "0<80><93>50").
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
O=${1:?Usage: bash run_final_steps_native.sh <output folder> [thresholdval] [thresholdvalfortruth]}
T1=${2:-0}
T2=${3:-0}

echo "--- Step 10: Evaluate Refinement ---"
Rscript src/evaluate_refinement.R "$O/refinement_weighted_2021.rds" "$O/refinement_simple_2021.rds" "$O/censusgrid_catchment.rds" "$O/corine2018_cropped.rds" "$O/evaluate_weighted_2021.rds" "$O/evaluate_simple_2021.rds" "$O/corineCLC2018overlappingPositivePop2021.rds" "$O/metrics_weighted.rds" "$O/metrics_simple.rds"

echo "--- Step 11A: Crop and Mask Raster (Overlapping Positive Pop x Catchment) ---"
Rscript src/crop_and_mask_raster.R "$O/corineCLC2018overlappingPositivePop2021.rds" "$O/catchment.gpkg" "$O/corineCLC2018overlappingPosPop2021_catchment.rds"

echo "--- Step 11B: Crop and Mask Raster (Final CORINE x Catchment) ---"
Rscript src/crop_and_mask_raster.R "$O/corine2018_final.rds" "$O/catchment.gpkg" "$O/corine2018_final_catchment.rds"

echo "--- Step 12: Create Final Visualizations ---"
Rscript src/create_visualisations.R "$O/weight_table_final.rds" "$O/clc_legend.rds" "$O/coryear2018.rds" "$O/visual_input_weights_histogram.html" "$O/lau_cell_counts_weighted2018.rds" "$O/visual_cor_distribution_across_lau.html" "$O/censusgrid_catchment.rds" "$O/evaluate_weighted_2021.rds" "$O/catchment.gpkg" "$O/visual_census_grid_map.html" "$O/2018.rds" "$O/lau_2018_catchment.rds" "$O/visual_lau_in_catch_focus_map.html" "$O/lau_2021_catchment.rds" "$O/visual_lau_in_catch_reference_map.html" "$O/corine2018_final_catchment.rds" "$O/visual_corineCLC_valid_map.html" "$O/corineCLC2018overlappingPositivePop2021.rds" "$O/visual_corineCLCoverlappingPosCensusgrid_map.html" "$O/refinement_weighted_2018.rds" "$O/visual_refinement_map.html" "$O/visual_error_map.html" "$T1" "$T2" "$O/visual_binaryPercError_map.html" "$O/visual_histogram_errorsDistributedOnDensClasses.html" "$O/metrics_weighted.rds" "$O/metrics_simple.rds" "$O/visual_histogram_metrics.html"

echo "--- Final steps complete ---"

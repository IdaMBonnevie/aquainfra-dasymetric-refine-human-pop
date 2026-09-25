Write-Host "--- Step 1: Get ECRINS Catchment ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_ecrins_catchment.R dasymetric-population-mapping-image "115" "/out/catchment.gpkg" "/out/countries.rds"

Write-Host "--- Step 2A: Get LAU Data (Focus Year 2018) ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_lau_data.R dasymetric-population-mapping-image "/out/countries.rds" "2018" "/out/lau_2018.rds" "/out/2018.rds"

Write-Host "--- Step 2B: Get LAU Data (Reference Year 2021) ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_lau_data.R dasymetric-population-mapping-image "/out/countries.rds" "2021" "/out/lau_2021.rds" "/out/2021.rds"

Write-Host "--- Step 2C: Get Census Grid ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_census_grid.R dasymetric-population-mapping-image "/out/countries.rds" "/out/censusgrid.rds"

Write-Host "--- Step 2D: Get EUBUCCO buildings ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_eubucco_buildings.R dasymetric-population-mapping-image "/out/catchment.gpkg" "/out/countries.rds" "/out/buildings.rds"

Write-Host "--- Step 3A: Data Intersect (LAU 2018 x Catchment) ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=data_intersect.R dasymetric-population-mapping-image "/out/lau_2018.rds" "/out/catchment.gpkg" "/out/lau_2018_catchment.rds"

Write-Host "--- Step 3B: Data Intersect (LAU 2021 x Catchment) ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=data_intersect.R dasymetric-population-mapping-image "/out/lau_2021.rds" "/out/catchment.gpkg" "/out/lau_2021_catchment.rds"

Write-Host "--- Step 3C: Get CORINE CLC ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_corineCLC.R dasymetric-population-mapping-image "/out/2021.rds" "/out/corine2018.rds" "/out/coryear2018.rds"

Write-Host "--- Step 4: Get Analysis Extent ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_analysis_extent.R dasymetric-population-mapping-image "/out/lau_2018_catchment.rds" "/out/lau_2021_catchment.rds" "/out/analysis_spatial_extent.gpkg"

Write-Host "--- Step 5A: Data Intersect (Census Grid x Analysis Extent) ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=data_intersect.R dasymetric-population-mapping-image "/out/censusgrid.rds" "/out/analysis_spatial_extent.gpkg" "/out/censusgrid_covering_lau.rds"

Write-Host "--- Step 5B: Crop and Mask Raster (CORINE CLC x Analysis Extent) ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=crop_and_mask_raster.R dasymetric-population-mapping-image "/out/corine2018.rds" "/out/analysis_spatial_extent.gpkg" "/out/corine2018_cropped.rds"

Write-Host "--- Step 6A: Attach Legend to CORINE CLC ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=attach_legend_to_corineCLC.R dasymetric-population-mapping-image "/out/coryear2018.rds" "/out/corine2018_cropped.rds" "/out/urban_values.rds" "/out/clc_legend.rds" "/out/corine2018_cropped_with_legend.rds"

Write-Host "--- Step 6B: Data Intersect (Census Grid x Catchment) ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=data_intersect.R dasymetric-population-mapping-image "/out/censusgrid_covering_lau.rds" "/out/catchment.gpkg" "/out/censusgrid_catchment.rds"

Write-Host "--- Step 7: Calculate Weighting ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=calculate_weighting.R dasymetric-population-mapping-image "/out/censusgrid_covering_lau.rds" "/out/corine2018_cropped.rds" "/out/coryear2018.rds" "/out/clc_legend.rds" "NA" "all_other_classes" "/out/weight_table_final.rds"

Write-Host "--- Step 8: Keep Only Valid CORINE CLC Classes ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=keep_only_valid_corineCLCclasses.R dasymetric-population-mapping-image "/out/corine2018_cropped.rds" "/out/coryear2018.rds" "/out/weight_table_final.rds" "/out/corine2018_valid.rds"

Write-Host "--- Step 9A: Dasymetric Refinement (Weighted, 2021) ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=dasymetric_refinement.R dasymetric-population-mapping-image "weighted" "/out/corine2018_valid.rds" "/out/coryear2018.rds" "/out/lau_2021_catchment.rds" "/out/2021.rds" "/out/catchment.gpkg" "/out/weight_table_final.rds" "/out/buildings.rds" "5" "/out/refinement_weighted_2021.rds" "/out/refinement_weighted_2021.tif" "/out/lau_cell_counts_weighted2021.rds" "/out/corine2018_final.rds"

Write-Host "--- Step 9B: Dasymetric Refinement (Weighted, 2018) ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=dasymetric_refinement.R dasymetric-population-mapping-image "weighted" "/out/corine2018_valid.rds" "/out/coryear2018.rds" "/out/lau_2018_catchment.rds" "/out/2018.rds" "/out/catchment.gpkg" "/out/weight_table_final.rds" "/out/buildings.rds" "5" "/out/refinement_weighted_2018.rds" "/out/refinement_weighted_2018.tif" "/out/lau_cell_counts_weighted2018.rds" "/out/corine2018_extra1.rds"

Write-Host "--- Step 9C: Dasymetric Refinement (Simple, 2021) ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=dasymetric_refinement.R dasymetric-population-mapping-image "simple" "/out/corine2018_valid.rds" "/out/coryear2018.rds" "/out/lau_2021_catchment.rds" "/out/2021.rds" "/out/catchment.gpkg" "/out/weight_table_final.rds" "/out/buildings.rds" "5" "/out/refinement_simple_2021.rds" "/out/refinement_simple_2021.tif" "/out/lau_cell_counts_simple2021.rds" "/out/corine2018_extra2.rds"

Write-Host "--- Step 10: Evaluate Refinement ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=evaluate_refinement.R dasymetric-population-mapping-image "/out/refinement_weighted_2021.rds" "/out/refinement_simple_2021.rds" "/out/censusgrid_catchment.rds" "/out/corine2018_cropped.rds" "/out/evaluate_weighted_2021.rds" "/out/evaluate_simple_2021.rds" "/out/corineCLC2018overlappingPositivePop2021.rds" "/out/metrics_weighted.rds" "/out/metrics_simple.rds"

Write-Host "--- Step 11A: Crop and Mask Raster (Overlapping Positive Pop x Catchment) ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=crop_and_mask_raster.R dasymetric-population-mapping-image "/out/corineCLC2018overlappingPositivePop2021.rds" "/out/catchment.gpkg" "/out/corineCLC2018overlappingPosPop2021_catchment.rds"

Write-Host "--- Step 11B: Crop and Mask Raster (Final CORINE x Catchment) ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=crop_and_mask_raster.R dasymetric-population-mapping-image "/out/corine2018_final.rds" "/out/catchment.gpkg" "/out/corine2018_final_catchment.rds"

Write-Host "--- Step 12: Create Final Visualizations ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=create_visualisations.R dasymetric-population-mapping-image "/out/weight_table_final.rds" "/out/clc_legend.rds" "/out/coryear2018.rds" "/out/visual_input_weights_histogram.html" "/out/lau_cell_counts_weighted2018.rds" "/out/visual_cor_distribution_across_lau.html" "/out/censusgrid.rds" "/out/evaluate_weighted_2021.rds" "/out/catchment.gpkg" "/out/visual_census_grid_map.html" "/out/2018.rds" "/out/lau_2018_catchment.rds" "/out/visual_lau_in_catch_focus_map.html" "/out/lau_2021_catchment.rds" "/out/visual_lau_in_catch_reference_map.html" "/out/corine2018_final_catchment.rds" "/out/visual_corineCLC_valid_map.html" "/out/corineCLC2018overlappingPositivePop2021.rds" "/out/visual_corineCLCoverlappingPosCensusgrid_map.html" "/out/refinement_weighted_2018.rds" "/out/visual_refinement_map.html" "/out/visual_error_map.html" "50" "10" "/out/visual_binaryPercError_map.html" "/out/visual_histogram_errorsDistributedOnDensClasses.html" "/out/metrics_weighted.rds" "/out/metrics_simple.rds" "/out/visual_histogram_metrics.html"

Write-Host "--- Workflow Complete ---"

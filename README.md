## A Toolbox for Dasymetric Population Mapping for an EU river catchment

````markdown
aquainfra-dasymetric-refinement-human-population

This repository provides an R-based **Dasymetric Mapping Toolbox** for an EU river catchment of own choice, implementing a full workflow using **EUROSTAT LAU**, **CLC CORINE**, and **Eurostat 2021 Census** data.
It follows the **Data-to-Knowledge (D2K)** framework of the **AquaINFRA** project.
````
## 🚀 Launch in MyBinder (optional)

You can open this toolbox in an online RStudio environment (no installation needed) using **MyBinder**:

[![Launch RStudio on MyBinder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/<your-username>/human-population-d2k-toolbox/main?urlpath=rstudio)

Replace `<your-username>` with your GitHub username after pushing this repository.

---

## 🗺️ Data Sources

| Dataset | Description | URL |
|----------|--------------|-----|
| **LAU Data** | Local Administrative Units population data (Germany) | It is called directly from the Eurostat and GiscoR libraries |
| **Census Grid** | Census grid polygons | https://gisco-services.ec.europa.eu/grid/grid_1km.parquet |
| **EUBUCCO buildings** | Harmonised European building dataset (only residential buildings are used) | https://eubucco.com/files/v0.2 |
| **CORINE Raster** | CORINE Land Cover raster  2018/2006/2000| https://aquainfra-syke.a3s.fi/europe_clc_cog_raster/CLC2018ACC_V2018_20_cog.tif or https://aquainfra-syke.a3s.fi/europe_clc_cog_raster/CLC2006ACC_V2018_20_cog.tif or https://aquainfra-syke.a3s.fi/europe_clc_cog_raster/CLC2000ACC_V2018_20_cog.tif |
| **Subbasins** | ECRINS subbasin geometries for Elbe | https://water.discomap.eea.europa.eu/arcgis/rest/services/Ecrins/ECRINS_FunctionalElementaryCatchments/MapServer/0/query |

---

## 🐳 Run the Workflow with Docker

All scripts read from and write to the local `./out` folder.  
Make sure the folder exists before running.

### Build the Docker Image
```bash
docker build -t d2k-toolbox .
````

---

### Step 1: Get ECRINS Catchment


```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_ecrins_catchment.R d2k-toolbox "115" "/out/catchment.gpkg" "/out/countries.rds"
```

---

### Step 2A: Get LAU Data (Focus Year 2018)

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_lau_data.R d2k-toolbox "/out/countries.rds" "2018" "/out/lau_2018.rds" "/out/2018.rds"
```

---

### Step 2B: Get LAU Data (Reference Year 2021)

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_lau_data.R d2k-toolbox "/out/countries.rds" "2021" "/out/lau_2021.rds" "/out/2021.rds"
```

---

### Step 2C: Get Census Grid

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_census_grid.R d2k-toolbox "/out/countries.rds" "/out/censusgrid.rds"
```

---

### Step 2D: Get EUBUCCO residential buildings

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_eubucco_buildings.R d2k-toolbox "/out/catchment.gpkg" "/out/countries.rds" "/out/buildings.rds"
```

---

### Step 3A: Data Intersect (LAU 2018 x Catchment)

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=data_intersect.R d2k-toolbox "/out/lau_2018.rds" "/out/catchment.gpkg" "/out/lau_2018_catchment.rds"
```

---

### Step 3B: Data Intersect (LAU 2021 x Catchment)

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=data_intersect.R d2k-toolbox "/out/lau_2021.rds" "/out/catchment.gpkg" "/out/lau_2021_catchment.rds"
```

---

### Step 3C: Get CORINE CLC

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_corineCLC.R d2k-toolbox "/out/2021.rds" "/out/corine2018.rds" "/out/coryear2018.rds"
```

---

### Step 4: Get Analysis Extent

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_analysis_extent.R d2k-toolbox "/out/lau_2018_catchment.rds" "/out/lau_2021_catchment.rds" "/out/analysis_spatial_extent.gpkg"
```

---

### Step 5A: Data Intersect (Census Grid x Analysis Extent)

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=data_intersect.R d2k-toolbox "/out/censusgrid.rds" "/out/analysis_spatial_extent.gpkg" "/out/censusgrid_covering_lau.rds"
```

---

### Step 5B: Crop and Mask Raster (CORINE CLC x Analysis Extent)

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=crop_and_mask_raster.R d2k-toolbox "/out/corine2018.rds" "/out/analysis_spatial_extent.gpkg" "/out/corine2018_cropped.rds"
```

---

### Step 6A: Attach Legend to CORINE CLC

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=attach_legend_to_corineCLC.R d2k-toolbox "/out/coryear2018.rds" "/out/corine2018_cropped.rds" "/out/clc_legend.rds"
```

---

### Step 6B: Data Intersect (Census Grid x Catchment)

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=data_intersect.R d2k-toolbox "/out/censusgrid_covering_lau.rds" "/out/catchment.gpkg" "/out/censusgrid_catchment.rds"
```

---

### Step 7: Calculate Weighting

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=calculate_weighting.R d2k-toolbox "/out/censusgrid_covering_lau.rds" "/out/corine2018_cropped.rds" "/out/coryear2018.rds" "/out/clc_legend.rds" "/out/weight_table_final.rds"
```

---

### Step 8: Keep Only Valid CORINE CLC Classes

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=keep_only_valid_corineCLCclasses.R d2k-toolbox "/out/corine2018_cropped.rds" "/out/coryear2018.rds" "/out/weight_table_final.rds" "/out/corine2018_valid.rds"
```

---

### Step 9A: Dasymetric Refinement (Weighted, 2021)

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=dasymetric_refinement.R d2k-toolbox "weighted" "/out/corine2018_valid.rds" "/out/coryear2018.rds" "/out/lau_2021_catchment.rds" "/out/2021.rds" "/out/catchment.gpkg" "/out/weight_table_final.rds" "/out/buildings.rds" "/out/best_threshold.rds" "5" "/out/refinement_weighted_2021.tif" "/out/lau_cell_counts_weighted2021.rds" "/out/corine2018_final.rds" 
```

---

### Step 9B: Dasymetric Refinement (Weighted, 2018)

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=dasymetric_refinement.R d2k-toolbox "weighted" "/out/corine2018_valid.rds" "/out/coryear2018.rds" "/out/lau_2018_catchment.rds" "/out/2018.rds" "/out/catchment.gpkg" "/out/weight_table_final.rds" "/out/refinement_weighted_2018.rds" "/out/buildings.rds" "5" "/out/refinement_weighted_2018.tif" "/out/lau_cell_counts_weighted2018.rds" "/out/corine2018_extra1.rds" 
```

---

### Step 9C: Dasymetric Refinement (Simple, 2021)

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=dasymetric_refinement.R d2k-toolbox "simple" "/out/corine2018_valid.rds" "/out/coryear2018.rds" "/out/lau_2021_catchment.rds" "/out/2021.rds" "/out/catchment.gpkg" "/out/weight_table_final.rds" "/out/buildings.rds" "5" "/out/refinement_simple_2021.rds" "/out/refinement_simple_2021.tif" "/out/lau_cell_counts_simple2021.rds" "/out/corine2018_extra2.rds" 
```

---

### Step 9D: Crop and Mask Raster (Valid CORINE CLC x Catchment)

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=crop_and_mask_raster.R d2k-toolbox "/out/corine2018_valid.rds" "/out/catchment.gpkg" "/out/corine2018_valid_cropped.rds"
```

---

### Step 10: Evaluate Refinement

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=evaluate_refinement.R d2k-toolbox "/out/refinement_weighted_2021.rds" "/out/refinement_simple_2021.rds" "/out/censusgrid_catchment.rds" "/out/corine2018_cropped.rds" "/out/evaluate_weighted_2021.rds" "/out/evaluate_simple_2021.rds" "/out/corineCLC2018overlappingPositivePop2021.rds" "/out/metrics_weighted.rds" "/out/metrics_simple.rds"
```

---

### Step 11: Crop and Mask Raster (Overlapping Positive Pop x Catchment)

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=crop_and_mask_raster.R d2k-toolbox "/out/corineCLC2018overlappingPositivePop2021.rds" "/out/catchment.gpkg" "/out/corineCLC2018overlappingPosPop2021_catchment.rds"
```

---

### Step 12: Create Final Visualizations

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=process_create_visualizations.R d2k-toolbox "/out/weight_table_final.rds" "/out/clc_legend.rds" "/out/coryear2018.rds" "/out/visual_input_weights_histogram.html" "/out/lau_cell_counts_weighted2018.rds" "/out/visual_cor_distribution_across_lau.html" "/out/censusgrid.rds" "/out/evaluate_weighted_2021.rds" "/out/catchment.gpkg" "/out/visual_census_grid_map.html" "/out/2018.rds" "/out/lau_2018_catchment.rds" "/out/visual_lau_in_catch_focus_map.html" "/out/lau_2021_catchment.rds" "/out/visual_lau_in_catch_reference_map.html" "/out/corine2018_final.rds" "/out/visual_corineCLC_valid_map.html" "/out/corineCLC2018overlappingPositivePop2021.rds" "/out/visual_corineCLCoverlappingPosCensusgrid_map.html" "/out/refinement_weighted_2021.rds" "/out/visual_refinement_map.html" "/out/visual_error_map.html" "50" "10" "/out/visual_binaryPercError_map.html" "/out/visual_histogram_errorsDistributedOnDensClasses.html" "/out/metrics_weighted.rds" "/out/metrics_simple.rds" "/out/visual_histogram_metrics.html"
```

---

## 💻 Platform Notes

### 🪟 Windows CMD / PowerShell

* Use the commands **exactly as shown** (each on a single line).
* Volume paths like `./out:/out` work inside the same directory where you run Docker.
* Example:

  ```bash
  cd "C:\Users\YourName\Documents\human-population-toolbox"
  docker build -t human-population-toolbox .
  ```

### 🐧 Linux / macOS

Use the same commands, or replace paths with full directories if needed:

```bash
docker run -it --rm -v $(pwd)/out:/out -e R_SCRIPT=get_ecrins_catchment.R human-population-toolbox "115" "/out/catchment.gpkg" "/out/countries.rds"
```

---

## 🧪 Quick Test Run (Optional Sanity Check)

Before running the full workflow, verify that your **Docker image**, **R environment**, and **GDAL bindings** work correctly.

```bash
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_ecrins_catchment.R human-population-toolbox 115 "/out/catchment.gpkg" "/out/countries.rds"
```

Expected output (example):

```
Fetching ECRINS catchment for ID 115...
Writing catchment to /out/catchment.gpkg
Writing countries to /out/countries.rds
Done.
```

✅ If this runs without errors, your environment is correctly set up for the Elbe workflow.

---

## 🧾 How to Cite

> *Your Name(s). (Year). A Toolbox for Dasymetric Refinement of Human Population to River Catchment. Zenodo. DOI: XXXXXXXX*

---

## ⚖️ License

This repository is released under the **Apache License 2.0**.

---

## 🧠 Troubleshooting

| Issue | Cause | Solution |
|-------|--------|-----------|
| **exec /app/entrypoint.sh: no such file or directory** | 1. You created `entrypoint.sh` after building the image. <br> 2. (On Windows) Your editor used Windows (`\r\n`) line endings. | Rebuild the image (`docker build -t human-population-toolbox .`). The Dockerfile automatically copies the new file and fixes line endings. |
| **“URL using bad/illegal format” or “cannot open URL”** | The command is missing the `https://` prefix or has extra quotes. | Use plain URLs only with ` https://gisco-services.ec.europa.eu/grid/grid_1km.parquet`. |
| **File not found (e.g., `/out/...` missing)** | The `out` directory is not mounted or doesn’t exist locally. | Run `mkdir out` in your project folder before starting Docker. |
| **Eurostat download fails (Error 410 Gone)** | The Eurostat R package is outdated and using a dead API link. | Ensure you have the latest Dockerfile and `.binder/environment.yml`, then rebuild the image (`docker build ...`). |
| **“object not found” in R logs** | The previous step failed, so the input file for the current step was never created. | Check the log of the previous command. Fix the error and re-run that step. |
| **A step fails with a “corrupt file” or “empty geometry” error** | A previous failed run left a partial or empty file in `./out`. | Delete all files in `./out` (e.g., `rm -rf ./out/*`) and run the workflow again from Step 1. |
| **Final maps are empty or show wrong data on hover (e.g., 44733.33%)** | A bug in the R visualization or calculation scripts. | 1. Ensure your `src` scripts are up to date. <br> 2. Rebuild the image (`docker build ...`). <br> 3. Re-run the workflow . |
| **Changes to Dockerfile or R scripts don’t seem to work** | Docker is using old cached layers. | Force a clean rebuild:<br>`docker builder prune -af`<br>`docker rmi human-population-toolbox `<br>`docker build -t human-population-toolbox .` |
| **Permission denied on Windows** | Docker can’t access your drive. | Enable drive sharing in *Docker Desktop → Settings → Resources → File Sharing*. |
| **Performance slow or process killed** | Insufficient memory for GDAL or raster ops. | Increase Docker Desktop memory to ≥ 8 GB (*Settings → Resources → Memory*). |

---

## 💾 Saving and Automating Your Commands

You can capture Docker logs, run all workflow steps at once, or export your command history.

---

### 1. Save the *Output* of a Single Command

To save both normal output and error messages to a file, use `*>&1` redirection:

```powershell (Windows)
docker run -it --rm -v ./out:/out -e R_SCRIPT=get_ecrins_catchment.R human-population-toolbox "115" "/out/catchment.gpkg" "/out/countries.rds" *>&1 > step1_log.txt
````

```bash (macOS/Linux)
docker run -it --rm -v $(pwd)/out:/out -e R_SCRIPT=get_ecrins_catchment.R human-population-toolbox "115" "/out/catchment.gpkg" "/out/countries.rds" > step1_log.txt 2>&1
````

This stores all console messages from Step 1 in `step1_log.txt`.

---

### 2. Run All Steps Automatically

There is a PowerShell script named `run_workflow.ps1/sh` in your project folder :


Run the full pipeline in one go:

```powershell
.\run_workflow.ps1
```

If PowerShell blocks the script:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
macOS Terminal

```powershell
# Execute directly using bash
bash run_workflow.sh
```
---

### 3. Save Your Command History

To save all commands you typed in the current session:

Windows
```powershell
Get-History | Out-File -FilePath my_command_history.txt
```

macOS Terminal

```powershell
history > my_command_history.txt
```
---

This lets users capture logs, automate workflows, and archive terminal history in Windows environments.

```

---


## 🧩 Notes

* The `out/` directory stores all intermediate and final outputs.
* MyBinder sessions are **temporary**; for reproducible work, use **Docker locally**.
* Ensure stable internet when fetching large datasets (CORINE, Eurostat).
* You can chain Docker steps in a shell script for full automation.

---

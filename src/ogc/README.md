# Deploy on pygeoapi

This README is still work in progress.

## How to install pygeoapi

## How to deploy these processes

### `plugin.py`

Add this to `plugin.py` file, in the `'process'` section:

```
...
PLUGINS = {
    ...
    'process': {
        ...
        'AttachLegendToCorineCLCProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.attach_legend_to_corineCLC.AttachLegendToCorineCLCProcessor',
        'CalculateWeightingProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.calculate_weighting.CalculateWeightingProcessor',
        'CreateVisualisationsProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.create_visualisations.CreateVisualisationsProcessor',
        'CropAndMaskRasterProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.crop_and_mask_raster.CropAndMaskRasterProcessor',
        'DasymetricRefinementProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.dasymetric_refinement.DasymetricRefinementProcessor',
        'DataIntersectProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.data_intersect.DataIntersectProcessor',
        'EvaluateRefinementProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.evaluate_refinement.EvaluateRefinementProcessor',
        'GetAnalysisExtentProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.get_analysis_extent.GetAnalysisExtentProcessor',
        'GetCensusGridProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.get_census_grid.GetCensusGridProcessor',
        'GetCorineCLCProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.get_corineCLC.GetCorineCLCProcessor',
        'GetEcrinsCatchmentProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.get_ecrins_catchment.GetEcrinsCatchmentProcessor',
        'GetEubuccoBuildingsProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.get_eubucco_buildings.GetEubuccoBuildingsProcessor',
        'GetHydro90mCatchmentByIdGiscoProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.get_hydro90m_catchment_by_id_gisco.GetHydro90mCatchmentByIdGiscoProcessor',
        'GetHydrobasinsL7CatchmentProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.get_hydrobasinsL7_catchment.GetHydrobasinsL7CatchmentProcessor',
        'GetLauDataProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.get_lau_data.GetLauDataProcessor',
        'KeepOnlyValidCorineCLCclassesProcessor': 'pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.keep_only_valid_corineCLCclasses.KeepOnlyValidCorineCLCclassesProcessor',
    },
    ...
}
...
```

### `pygeoapi-config.yml`

Add this to `pygeoapi.yml` file, in the `resources` section:

```
resources:

    ...

    attach-legend-to-corineCLC:
        type: process
        processor:
            name: AttachLegendToCorineCLCProcessor

    calculate-weighting:
        type: process
        processor:
            name: CalculateWeightingProcessor

    create-visualisations:
        type: process
        processor:
            name: CreateVisualisationsProcessor

    crop-and-mask-raster:
        type: process
        processor:
            name: CropAndMaskRasterProcessor

    dasymetric-refinement:
        type: process
        processor:
            name: DasymetricRefinementProcessor

    data-intersect:
        type: process
        processor:
            name: DataIntersectProcessor

    evaluate-refinement:
        type: process
        processor:
            name: EvaluateRefinementProcessor

    get-analysis-extent:
        type: process
        processor:
            name: GetAnalysisExtentProcessor

    get-census-grid:
        type: process
        processor:
            name: GetCensusGridProcessor

    get-corineCLC:
        type: process
        processor:
            name: GetCorineCLCProcessor

    get-ecrins-catchment:
        type: process
        processor:
            name: GetEcrinsCatchmentProcessor

    get-eubucco-buildings:
        type: process
        processor:
            name: GetEubuccoBuildingsProcessor

    get-hydro90m-catchment-by-id-gisco:
        type: process
        processor:
            name: GetHydro90mCatchmentByIdGiscoProcessor

    get-hydrobasins-l7-catchment:
        type: process
        processor:
            name: GetHydrobasinsL7CatchmentProcessor

    get-lau-data:
        type: process
        processor:
            name: GetLauDataProcessor

    keep-only-valid-corineCLCclasses:
        type: process
        processor:
            name: KeepOnlyValidCorineCLCclassesProcessor
```

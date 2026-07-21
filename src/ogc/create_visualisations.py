import logging
import subprocess
import json
import os

from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

# how to import python modules containing a hyphen:
import importlib
docker_utils = importlib.import_module("pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.docker_utils")

'''
curl -X POST https://${PYSERVER}/processes/create-visualisations/execution \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "inputFile1_weightTable_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/weight_table_final.rds",
        "inputFile2_clcLegend_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/clc_legend.rds",
        "inputFile3_coryear2018_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/coryear2018.rds",
        "inputFile4_cellStatistics_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/out/lau_cell_counts_weighted2018.rds",
        "inputFile5_censusgrid_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/out/censusgrid.rds",
        "inputFile6_evaluateWeighted_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/evaluate_weighted_2021.rds",
        "inputFile7_catchment_gpkg": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/catchment.gpkg",
        "inputFile8_popFocusYear_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/2018.rds",
        "inputFile9_lauInCatchFocus_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/lau_2018_catchment.rds",
        "inputFile10_lauInCatchReference_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/lau_2021_catchment.rds",
        "inputFile11_corineCLCvalid_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/out/corine2018_valid.rds",
        "inputFile12_corineCLConlyPositive_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/out/corineCLC2018overlappingPositivePop2021.rds",
        "inputFile13_refinement_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/refinement_weighted_2021.rds",
        "thresholdval": "50",
        "thresholdvalfortruth": "10",
        "inputFile14_metrics_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/metrics_weighted.rds",
        "inputFile15_metricsSimple_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/metrics_simple.rds"
    }
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))


class CreateVisualisationsProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.process_id = self.metadata["id"]
        self.my_job_id = 'nothing-yet'
        self.image_name = 'dasymetric-population-mapping-image'
        self.script_name = 'create_visualisations.R'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<CreateVisualisationsProcessor> {self.name}'

    def execute(self, data, outputs=None):

        config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
        with open(config_file_path, 'r') as configFile:
            configJSON = json.load(configFile)
        self.docker_executable = configJSON["docker_executable"]
        self.download_dir = configJSON["download_dir"].rstrip('/')
        self.download_url = configJSON["download_url"].rstrip('/')

        # Where to store output data (will be mounted read-write into container):
        output_dir = f'{self.download_dir}/out/{self.process_id}/job_{self.my_job_id}'
        output_url = f'{self.download_url}/out/{self.process_id}/job_{self.my_job_id}'
        os.makedirs(output_dir, exist_ok=True)

        # User inputs (file paths)
        in_inputFile1_weightTable_rds = data.get('inputFile1_weightTable_rds')
        in_inputFile2_clcLegend_rds = data.get('inputFile2_clcLegend_rds')
        in_inputFile3_coryear2018_rds = data.get('inputFile3_coryear2018_rds')
        in_inputFile4_cellStatistics_rds = data.get('inputFile4_cellStatistics_rds')
        in_inputFile5_censusgrid_rds = data.get('inputFile5_censusgrid_rds')
        in_inputFile6_evaluateWeighted_rds = data.get('inputFile6_evaluateWeighted_rds')
        in_inputFile7_catchment_gpkg = data.get('inputFile7_catchment_gpkg')
        in_inputFile8_popFocusYear_rds = data.get('inputFile8_popFocusYear_rds')
        in_inputFile9_lauInCatchFocus_rds = data.get('inputFile9_lauInCatchFocus_rds')
        in_inputFile10_lauInCatchReference_rds = data.get('inputFile10_lauInCatchReference_rds')
        in_inputFile11_corineCLCvalid_rds = data.get('inputFile11_corineCLCvalid_rds')
        in_inputFile12_corineCLConlyPositive_rds = data.get('inputFile12_corineCLConlyPositive_rds')
        in_inputFile13_refinement_rds = data.get('inputFile13_refinement_rds')
        in_inputFile14_metrics_rds = data.get('inputFile14_metrics_rds')
        in_inputFile15_metricsSimple_rds = data.get('inputFile15_metricsSimple_rds')

        # User inputs (scalar parameters)
        in_thresholdval = data.get('thresholdval')
        in_thresholdvalfortruth = data.get('thresholdvalfortruth')

        # Check user inputs
        required = {
            'inputFile1_weightTable_rds': in_inputFile1_weightTable_rds,
            'inputFile2_clcLegend_rds': in_inputFile2_clcLegend_rds,
            'inputFile3_coryear2018_rds': in_inputFile3_coryear2018_rds,
            'inputFile4_cellStatistics_rds': in_inputFile4_cellStatistics_rds,
            'inputFile5_censusgrid_rds': in_inputFile5_censusgrid_rds,
            'inputFile6_evaluateWeighted_rds': in_inputFile6_evaluateWeighted_rds,
            'inputFile7_catchment_gpkg': in_inputFile7_catchment_gpkg,
            'inputFile8_popFocusYear_rds': in_inputFile8_popFocusYear_rds,
            'inputFile9_lauInCatchFocus_rds': in_inputFile9_lauInCatchFocus_rds,
            'inputFile10_lauInCatchReference_rds': in_inputFile10_lauInCatchReference_rds,
            'inputFile11_corineCLCvalid_rds': in_inputFile11_corineCLCvalid_rds,
            'inputFile12_corineCLConlyPositive_rds': in_inputFile12_corineCLConlyPositive_rds,
            'inputFile13_refinement_rds': in_inputFile13_refinement_rds,
            'thresholdval': in_thresholdval,
            'thresholdvalfortruth': in_thresholdvalfortruth,
            'inputFile14_metrics_rds': in_inputFile14_metrics_rds,
            'inputFile15_metricsSimple_rds': in_inputFile15_metricsSimple_rds,
        }
        for param_name, param_value in required.items():
            if param_value is None:
                raise ProcessorExecuteError(f'Missing parameter "{param_name}". Please provide a {param_name}.')

        # Where to store output data (12 HTML outputs)
        def out_path(name):
            filename = f'{name}-{self.my_job_id}.html'
            filepath = f'{output_dir}/{filename}'
            link = f'{output_url}/{filename}'
            return filepath, link

        input_weights_histogram_filepath, input_weights_histogram_link = out_path('input_weights_histogram')
        cor_distribution_across_lau_histogram_filepath, cor_distribution_across_lau_histogram_link = out_path('cor_distribution_across_lau_histogram')
        census_grid_map_filepath, census_grid_map_link = out_path('census_grid_map')
        lau_in_catch_focus_map_filepath, lau_in_catch_focus_map_link = out_path('lau_in_catch_focus_map')
        lau_in_catch_reference_map_filepath, lau_in_catch_reference_map_link = out_path('lau_in_catch_reference_map')
        corineCLC_valid_map_filepath, corineCLC_valid_map_link = out_path('corineCLC_valid_map')
        corineCLCoverlappingPosCensusgrid_map_filepath, corineCLCoverlappingPosCensusgrid_map_link = out_path('corineCLCoverlappingPosCensusgrid_map')
        refinement_map_filepath, refinement_map_link = out_path('refinement_map')
        error_map_filepath, error_map_link = out_path('error_map')
        binaryPercError_map_filepath, binaryPercError_map_link = out_path('binaryPercError_map')
        histogram_errorsDistributedOnDensClasses_filepath, histogram_errorsDistributedOnDensClasses_link = out_path('histogram_errorsDistributedOnDensClasses')
        histogram_metrics_filepath, histogram_metrics_link = out_path('histogram_metrics')

        # Assemble args for script (order must match the R script's commandArgs, 29 total):
        script_args = [
            in_inputFile1_weightTable_rds,
            in_inputFile2_clcLegend_rds,
            in_inputFile3_coryear2018_rds,
            input_weights_histogram_filepath,
            in_inputFile4_cellStatistics_rds,
            cor_distribution_across_lau_histogram_filepath,
            in_inputFile5_censusgrid_rds,
            in_inputFile6_evaluateWeighted_rds,
            in_inputFile7_catchment_gpkg,
            census_grid_map_filepath,
            in_inputFile8_popFocusYear_rds,
            in_inputFile9_lauInCatchFocus_rds,
            lau_in_catch_focus_map_filepath,
            in_inputFile10_lauInCatchReference_rds,
            lau_in_catch_reference_map_filepath,
            in_inputFile11_corineCLCvalid_rds,
            corineCLC_valid_map_filepath,
            in_inputFile12_corineCLConlyPositive_rds,
            corineCLCoverlappingPosCensusgrid_map_filepath,
            in_inputFile13_refinement_rds,
            refinement_map_filepath,
            error_map_filepath,
            str(in_thresholdval),
            str(in_thresholdvalfortruth),
            binaryPercError_map_filepath,
            histogram_errorsDistributedOnDensClasses_filepath,
            in_inputFile14_metrics_rds,
            in_inputFile15_metricsSimple_rds,
            histogram_metrics_filepath
        ]

        # Run docker container:
        returncode, stdout, stderr, user_err_msg = docker_utils.run_docker_container(
            LOGGER,
            self.docker_executable,
            self.image_name,
            self.script_name,
            output_dir,
            selg.my_job_id,
            script_args
        )

        if not returncode == 0:
            user_err_msg = "no message" if len(user_err_msg) == 0 else user_err_msg
            err_msg = 'Running docker container failed: %s' % user_err_msg
            raise ProcessorExecuteError(user_msg = err_msg)
        else:
            outputs_def = self.metadata['outputs']
            response_object = {
                "outputs": {
                    "input_weights_histogram": {
                        "title": outputs_def['input_weights_histogram']['title'],
                        "description": outputs_def['input_weights_histogram']['description'],
                        "href": f'{input_weights_histogram_link}'
                    },
                    "cor_distribution_across_lau_histogram": {
                        "title": outputs_def['cor_distribution_across_lau_histogram']['title'],
                        "description": outputs_def['cor_distribution_across_lau_histogram']['description'],
                        "href": f'{cor_distribution_across_lau_histogram_link}'
                    },
                    "census_grid_map": {
                        "title": outputs_def['census_grid_map']['title'],
                        "description": outputs_def['census_grid_map']['description'],
                        "href": f'{census_grid_map_link}'
                    },
                    "lau_in_catch_focus_map": {
                        "title": outputs_def['lau_in_catch_focus_map']['title'],
                        "description": outputs_def['lau_in_catch_focus_map']['description'],
                        "href": f'{lau_in_catch_focus_map_link}'
                    },
                    "lau_in_catch_reference_map": {
                        "title": outputs_def['lau_in_catch_reference_map']['title'],
                        "description": outputs_def['lau_in_catch_reference_map']['description'],
                        "href": f'{lau_in_catch_reference_map_link}'
                    },
                    "corineCLC_valid_map": {
                        "title": outputs_def['corineCLC_valid_map']['title'],
                        "description": outputs_def['corineCLC_valid_map']['description'],
                        "href": f'{corineCLC_valid_map_link}'
                    },
                    "corineCLCoverlappingPosCensusgrid_map": {
                        "title": outputs_def['corineCLCoverlappingPosCensusgrid_map']['title'],
                        "description": outputs_def['corineCLCoverlappingPosCensusgrid_map']['description'],
                        "href": f'{corineCLCoverlappingPosCensusgrid_map_link}'
                    },
                    "refinement_map": {
                        "title": outputs_def['refinement_map']['title'],
                        "description": outputs_def['refinement_map']['description'],
                        "href": f'{refinement_map_link}'
                    },
                    "error_map": {
                        "title": outputs_def['error_map']['title'],
                        "description": outputs_def['error_map']['description'],
                        "href": f'{error_map_link}'
                    },
                    "binaryPercError_map": {
                        "title": outputs_def['binaryPercError_map']['title'],
                        "description": outputs_def['binaryPercError_map']['description'],
                        "href": f'{binaryPercError_map_link}'
                    },
                    "histogram_errorsDistributedOnDensClasses": {
                        "title": outputs_def['histogram_errorsDistributedOnDensClasses']['title'],
                        "description": outputs_def['histogram_errorsDistributedOnDensClasses']['description'],
                        "href": f'{histogram_errorsDistributedOnDensClasses_link}'
                    },
                    "histogram_metrics": {
                        "title": outputs_def['histogram_metrics']['title'],
                        "description": outputs_def['histogram_metrics']['description'],
                        "href": f'{histogram_metrics_link}'
                    }
                }
            }
            return 'application/json', response_object

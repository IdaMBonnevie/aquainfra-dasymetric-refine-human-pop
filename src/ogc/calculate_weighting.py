import logging
import subprocess
import json
import os

from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

# how to import python modules containing a hyphen:
import importlib
docker_utils = importlib.import_module("pygeoapi.process.aquainfra-dasymetric-refine-human-pop.src.ogc.docker_utils")

'''
curl -X POST https://${PYSERVER/processes/calculate-weighting/execution \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_censusgridSelected_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/censusgrid_covering_lau.rds",
        "inputFile2_corineCLCcropped_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/corine2018_cropped.rds",
        "inputFile3_corineYear_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/coryear2018.rds",
        "inputFile4_clcLegend_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/clc_legend.rds",
        "inputFile5_corUrbanValues_rds": "NA",
        "additional_candidate_classes_to_consider": "all_other_classes"
    }
}'

curl -X POST https://${PYSERVER}/processes/calculate-weighting/execution \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_censusgridSelected_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/censusgrid_covering_lau.rds",
        "inputFile2_corineCLCcropped_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/corine2018_cropped.rds",
        "inputFile3_corineYear_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/coryear2018.rds",
        "inputFile4_clcLegend_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/clc_legend.rds",
        "inputFile5_corUrbanValues_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/out/urban_values.rds",
        "additional_candidate_classes_to_consider": "all_artificial_surface_classes"
    }
}'

curl -X POST https://${PYSERVER}/processes/calculate-weighting/execution \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_censusgridSelected_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/censusgrid_covering_lau.rds",
        "inputFile2_corineCLCcropped_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/corine2018_cropped.rds",
        "inputFile3_corineYear_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/coryear2018.rds",
        "inputFile4_clcLegend_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/clc_legend.rds",
        "inputFile5_corUrbanValues_rds": "NA",
        "additional_candidate_classes_to_consider": "NA"
    }
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))


class CalculateWeightingProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.process_id = self.metadata["id"]
        self.my_job_id = 'nothing-yet'
        self.image_name = 'dasymetric-population-mapping-image'
        self.script_name = 'calculate_weighting.R'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<CalculateWeightingProcessor> {self.name}'

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

        # User inputs
        in_inputFile1_censusgridSelected_rds = data.get('inputFile1_censusgridSelected_rds')
        in_inputFile2_corineCLCcropped_rds = data.get('inputFile2_corineCLCcropped_rds')
        in_inputFile3_corineYear_rds = data.get('inputFile3_corineYear_rds')
        in_inputFile4_clcLegend_rds = data.get('inputFile4_clcLegend_rds')
        # Optional inputs
        in_inputFile5_corUrbanValues_rds = data.get('inputFile5_corUrbanValues_rds')
        in_additionalCandidateClassesToConsider = data.get('additional_candidate_classes_to_consider')

        # Check user inputs
        if in_inputFile1_censusgridSelected_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile1_censusgridSelected_rds". Please provide a inputFile1_censusgridSelected_rds.')
        if in_inputFile2_corineCLCcropped_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile2_corineCLCcropped_rds". Please provide a inputFile2_corineCLCcropped_rds.')
        if in_inputFile3_corineYear_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile3_corineYear_rds". Please provide a inputFile3_corineYear_rds.')
        if in_inputFile4_clcLegend_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile4_clcLegend_rds". Please provide a inputFile4_clcLegend_rds.')

        # Where to store output data
        weight_table_filename = 'weight_table-%s.rds' % self.my_job_id
        weight_table_filepath = f'{output_dir}/{weight_table_filename}'
        weight_table_link = f'{output_url}/{weight_table_filename}'

        # Assemble args for script (order must match the R script's commandArgs):
        # <censusgrid_selected_rds_path> <corineCLC_cropped_rds_path> <corine_year_rds_path>
        # <clc_legend_rds_path> <cor_urban_values_rds_path|NA> <additional_candidate_classes_to_consider|NA>
        # <weight_table_rds_path>
        script_args = [
            in_inputFile1_censusgridSelected_rds,
            in_inputFile2_corineCLCcropped_rds,
            in_inputFile3_corineYear_rds,
            in_inputFile4_clcLegend_rds,
            in_inputFile5_corUrbanValues_rds if in_inputFile5_corUrbanValues_rds is not None else 'NA',
            in_additionalCandidateClassesToConsider if in_additionalCandidateClassesToConsider is not None else 'NA',
            weight_table_filepath
        ]

        # Run docker container:
        returncode, stdout, stderr, user_err_msg = docker_utils.run_docker_container(
            LOGGER,
            self.docker_executable,
            self.image_name,
            self.script_name,
            output_dir,
            self.my_job_id,
            script_args
        )

        if not returncode == 0:
            user_err_msg = "no message" if len(user_err_msg) == 0 else user_err_msg
            err_msg = 'Running docker container failed: %s' % user_err_msg
            raise ProcessorExecuteError(user_msg = err_msg)
        else:
            response_object = {
                "outputs": {
                    "weight_table": {
                        "title": self.metadata['outputs']['weight_table']['title'],
                        "description": self.metadata['outputs']['weight_table']['description'],
                        "href": f'{weight_table_link}'
                    }
                }
            }
            return 'application/json', response_object

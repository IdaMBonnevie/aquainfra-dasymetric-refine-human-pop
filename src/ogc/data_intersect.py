import logging
import subprocess
import json
import os

from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

# how to import python modules containing a hyphen:
import importlib
docker_utils = importlib.import_module("pygeoapi.process.human-population-toolbox.src.ogc.docker_utils")

'''
curl --location 'http://localhost:5000/processes/data-intersect/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_focus_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/lau_2018.rds",
        "inputFile2_analysisExtent_gpkg": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/catchment.gpkg"
    }
}'

curl --location 'http://localhost:5000/processes/data-intersect/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_focus_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/lau_2021.rds",
        "inputFile2_analysisExtent_gpkg": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/catchment.gpkg"
    }
}'

curl --location 'http://localhost:5000/processes/data-intersect/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_focus_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/censusgrid_covering_lau.rds",
        "inputFile2_analysisExtent_gpkg": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/analysis_spatial_extent.gpkg"
    }
}'

curl --location 'http://localhost:5000/processes/data-intersect/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_focus_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/censusgrid_covering_lau.rds",
        "inputFile2_analysisExtent_gpkg": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/catchment.gpkg"
    }
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))


class DataIntersectProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.process_id = self.metadata["id"]
        self.my_job_id = 'nothing-yet'
        self.image_name = 'dasymetric-population-mapping-image'
        self.script_name = 'data_intersect.R'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<DataIntersectProcessor> {self.name}'

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
        in_inputFile1_focus_rds = data.get('inputFile1_focus_rds')
        in_inputFile2_analysisExtent_gpkg = data.get('inputFile2_analysisExtent_gpkg')

        # Check user inputs
        if in_inputFile1_focus_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile1_focus_rds". Please provide a inputFile1_focus_rds.')
        if in_inputFile2_analysisExtent_gpkg is None:
            raise ProcessorExecuteError('Missing parameter "inputFile2_analysisExtent_gpkg". Please provide a inputFile2_analysisExtent_gpkg.')

        # Where to store output data
        intersect_result_filename = 'intersect_result-%s.rds' % self.my_job_id
        intersect_result_filepath = f'{output_dir}/{intersect_result_filename}'
        intersect_result_link = f'{output_url}/{intersect_result_filename}'

        # Assemble args for script (order must match the R script's commandArgs):
        # <focus_rds_path> <analysis_extent_gpkg_path> <output_rds_path>
        script_args = [
            in_inputFile1_focus_rds,
            in_inputFile2_analysisExtent_gpkg,
            intersect_result_filepath
        ]

        # Run docker container:
        returncode, stdout, stderr, user_err_msg = docker_utils.run_docker_container(
            self.docker_executable,
            self.image_name,
            self.script_name,
            output_dir,
            script_args
        )

        if not returncode == 0:
            user_err_msg = "no message" if len(user_err_msg) == 0 else user_err_msg
            err_msg = 'Running docker container failed: %s' % user_err_msg
            raise ProcessorExecuteError(user_msg = err_msg)
        else:
            response_object = {
                "outputs": {
                    "intersect_result": {
                        "title": self.metadata['outputs']['intersect_result']['title'],
                        "description": self.metadata['outputs']['intersect_result']['description'],
                        "href": f'{intersect_result_link}'
                    }
                }
            }
            return 'application/json', response_object

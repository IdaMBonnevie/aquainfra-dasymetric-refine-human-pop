import logging
import subprocess
import json
import os

from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

# how to import python modules containing a hyphen:
import importlib
docker_utils = importlib.import_module("pygeoapi.process.human-population-toolbox.src.ogc.docker_utils")

'''
curl --location 'http://localhost:5000/processes/crop-and-mask-raster/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_corineCLC_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/corine2018_final.rds",
        "inputFile2_analysisExtent_gpkg": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/analysis_spatial_extent.gpkg"
    }
}'

curl --location 'http://localhost:5000/processes/crop-and-mask-raster/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_corineCLC_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/corineCLC2018overlappingPosPop2021_catchment.rds",
        "inputFile2_analysisExtent_gpkg": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/catchment.gpkg"
    }
}'

curl --location 'http://localhost:5000/processes/crop-and-mask-raster/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_corineCLC_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/corine2018_final.rds",
        "inputFile2_analysisExtent_gpkg": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/catchment.gpkg"
    }
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))


class CropAndMaskRasterProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.process_id = self.metadata["id"]
        self.my_job_id = 'nothing-yet'
        self.image_name = 'dasymetric-population-mapping-image'
        self.script_name = 'crop_and_mask_raster.R'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<CropAndMaskRasterProcessor> {self.name}'

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
        in_inputFile1_corineCLC_rds = data.get('inputFile1_corineCLC_rds')
        in_inputFile2_analysisExtent_gpkg = data.get('inputFile2_analysisExtent_gpkg')

        # Check user inputs
        if in_inputFile1_corineCLC_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile1_corineCLC_rds". Please provide a inputFile1_corineCLC_rds.')
        if in_inputFile2_analysisExtent_gpkg is None:
            raise ProcessorExecuteError('Missing parameter "inputFile2_analysisExtent_gpkg". Please provide a inputFile2_analysisExtent_gpkg.')

        # Where to store output data
        corineCLC_cropped_filename = 'corineCLC_cropped-%s.rds' % self.my_job_id
        corineCLC_cropped_filepath = f'{output_dir}/{corineCLC_cropped_filename}'
        corineCLC_cropped_link = f'{output_url}/{corineCLC_cropped_filename}'

        # Assemble args for script (order must match the R script's commandArgs):
        # <corineCLC_rds_path> <analysis_extent_gpkg_path> <output_corineCLC_cropped_rds_path>
        script_args = [
            in_inputFile1_corineCLC_rds,
            in_inputFile2_analysisExtent_gpkg,
            corineCLC_cropped_filepath
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
                    "corineCLC_cropped": {
                        "title": self.metadata['outputs']['corineCLC_cropped']['title'],
                        "description": self.metadata['outputs']['corineCLC_cropped']['description'],
                        "href": f'{corineCLC_cropped_link}'
                    }
                }
            }
            return 'application/json', response_object

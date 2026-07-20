import logging
import subprocess
import json
import os

from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

# how to import python modules containing a hyphen:
import importlib
docker_utils = importlib.import_module("pygeoapi.process.human-population-toolbox.src.ogc.docker_utils")

'''
curl --location 'http://localhost:5000/processes/keep-only-valid-corineCLCclasses/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_corineCLC_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/corine2018_cropped.rds",
        "inputFile2_corineYear_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/coryear2018.rds",
        "inputFile3_weightTable_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/weight_table_final.rds"
    }
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))


class KeepOnlyValidCorineCLCclassesProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.process_id = self.metadata["id"]
        self.my_job_id = 'nothing-yet'
        self.image_name = 'dasymetric-population-mapping-image'
        self.script_name = 'keep_only_valid_corineCLCclasses.R'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<KeepOnlyValidCorineCLCclassesProcessor> {self.name}'

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
        in_inputFile2_corineYear_rds = data.get('inputFile2_corineYear_rds')
        in_inputFile3_weightTable_rds = data.get('inputFile3_weightTable_rds')

        # Check user inputs
        if in_inputFile1_corineCLC_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile1_corineCLC_rds". Please provide a inputFile1_corineCLC_rds.')
        if in_inputFile2_corineYear_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile2_corineYear_rds". Please provide a inputFile2_corineYear_rds.')
        if in_inputFile3_weightTable_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile3_weightTable_rds". Please provide a inputFile3_weightTable_rds.')

        # Where to store output data
        corineCLC_valid_filename = 'corineCLC_valid-%s.rds' % self.my_job_id
        corineCLC_valid_filepath = f'{output_dir}/{corineCLC_valid_filename}'
        corineCLC_valid_link = f'{output_url}/{corineCLC_valid_filename}'

        # Assemble args for script (order must match the R script's commandArgs):
        # <corineCLC_rds_path> <corine_year_rds_path> <weight_table_rds_path> <output_corineCLC_valid_rds_path>
        script_args = [
            in_inputFile1_corineCLC_rds,
            in_inputFile2_corineYear_rds,
            in_inputFile3_weightTable_rds,
            corineCLC_valid_filepath
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
                    "corineCLC_valid": {
                        "title": self.metadata['outputs']['corineCLC_valid']['title'],
                        "description": self.metadata['outputs']['corineCLC_valid']['description'],
                        "href": f'{corineCLC_valid_link}'
                    }
                }
            }
            return 'application/json', response_object

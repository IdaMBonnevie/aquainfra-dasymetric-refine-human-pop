import logging
import subprocess
import json
import os

from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

# how to import python modules containing a hyphen:
import importlib
docker_utils = importlib.import_module("pygeoapi.process.human-population-toolbox.src.ogc.docker_utils")

'''
curl --location 'http://localhost:5000/processes/get-corineCLC/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_focusYear_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/2021.rds"
    }
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))


class GetCorineCLCProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.process_id = self.metadata["id"]
        self.my_job_id = 'nothing-yet'
        self.image_name = 'dasymetric-population-mapping-image'
        self.script_name = 'get_corineCLC.R'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<GetCorineCLCProcessor> {self.name}'

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
        in_inputFile1_focusYear_rds = data.get('inputFile1_focusYear_rds')

        # Check user inputs
        if in_inputFile1_focusYear_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile1_focusYear_rds". Please provide a inputFile1_focusYear_rds.')

        # Where to store output data
        corineCLC_filename = 'corineCLC-%s.rds' % self.my_job_id
        corineCLC_filepath = f'{output_dir}/{corineCLC_filename}'
        corineCLC_link = f'{output_url}/{corineCLC_filename}'

        corine_year_filename = 'corine_year-%s.rds' % self.my_job_id
        corine_year_filepath = f'{output_dir}/{corine_year_filename}'
        corine_year_link = f'{output_url}/{corine_year_filename}'

        # Assemble args for script (order must match the R script's commandArgs):
        # <focus_year_rds_path> <output_corineCLC_rds_path> <corine_year_rds_path>
        script_args = [
            in_inputFile1_focusYear_rds,
            corineCLC_filepath,
            corine_year_filepath
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
                    "corineCLC": {
                        "title": self.metadata['outputs']['corineCLC']['title'],
                        "description": self.metadata['outputs']['corineCLC']['description'],
                        "href": f'{corineCLC_link}'
                    },
                    "corine_year": {
                        "title": self.metadata['outputs']['corine_year']['title'],
                        "description": self.metadata['outputs']['corine_year']['description'],
                        "href": f'{corine_year_link}'
                    }
                }
            }
            return 'application/json', response_object

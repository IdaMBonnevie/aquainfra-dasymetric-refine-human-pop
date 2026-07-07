import logging
import subprocess
import json
import os

from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

# how to import python modules containing a hyphen:
import importlib
docker_utils = importlib.import_module("pygeoapi.process.aquainfra-dasymetric-refinement-human-population.src.ogc.docker_utils")

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))


class AttachLegendToCorineCLCProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.process_id = self.metadata["id"]
        self.my_job_id = 'nothing-yet'
        self.image_name = 'aquainfra-dasymetric-refinement-human-population:20251201'
        self.script_name = 'attach_legend_to_corineCLC.R'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<AttachLegendToCorineCLCProcessor> {self.name}'

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
        in_inputFile1_corineYear_rds = data.get('inputFile1_corineYear_rds')
        in_inputFile2_corineCLC_rds = data.get('inputFile2_corineCLC_rds')

        # Check user inputs
        if in_inputFile1_corineYear_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile1_corineYear_rds". Please provide a inputFile1_corineYear_rds.')
        if in_inputFile2_corineCLC_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile2_corineCLC_rds". Please provide a inputFile2_corineCLC_rds.')

        # Where to store output data
        corineCLC_filename = 'corineCLC_with_legend-%s.rds' % self.my_job_id
        corineCLC_filepath = f'{output_dir}/{corineCLC_filename}'
        corineCLC_link = f'{output_url}/{corineCLC_filename}'

        cor_urban_values_filename = 'cor_urban_values-%s.rds' % self.my_job_id
        cor_urban_values_filepath = f'{output_dir}/{cor_urban_values_filename}'
        cor_urban_values_link = f'{output_url}/{cor_urban_values_filename}'

        clc_legend_filename = 'clc_legend-%s.rds' % self.my_job_id
        clc_legend_filepath = f'{output_dir}/{clc_legend_filename}'
        clc_legend_link = f'{output_url}/{clc_legend_filename}'

        # Assemble args for script (order must match the R script's commandArgs):
        # <corine_year_rds_path> <corineCLC_rds_path> <cor_urban_values_rds_path> <clc_legend_rds_path>
        script_args = [
            in_inputFile1_corineYear_rds,
            in_inputFile2_corineCLC_rds,
            cor_urban_values_filepath,
            clc_legend_filepath
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
                    "corineCLC_with_legend": {
                        "title": self.metadata['outputs']['corineCLC_with_legend']['title'],
                        "description": self.metadata['outputs']['corineCLC_with_legend']['description'],
                        "href": f'{corineCLC_link}'
                    },
                    "cor_urban_values": {
                        "title": self.metadata['outputs']['cor_urban_values']['title'],
                        "description": self.metadata['outputs']['cor_urban_values']['description'],
                        "href": f'{cor_urban_values_link}'
                    },
                    "clc_legend": {
                        "title": self.metadata['outputs']['clc_legend']['title'],
                        "description": self.metadata['outputs']['clc_legend']['description'],
                        "href": f'{clc_legend_link}'
                    }
                }
            }
            return 'application/json', response_object

import logging
import subprocess
import json
import os

from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

# how to import python modules containing a hyphen:
import importlib
docker_utils = importlib.import_module("pygeoapi.process.human-population-toolbox.src.ogc.docker_utils")

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))


class GetEcrinsCatchmentProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.process_id = self.metadata["id"]
        self.my_job_id = 'nothing-yet'
        self.image_name = 'human-population-toolbox:20251201'
        self.script_name = 'get_ecrins_catchment.R'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<GetEcrinsCatchmentProcessor> {self.name}'

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
        in_catchment_id = data.get('catchment_id')

        # Check user inputs
        if in_catchment_id is None:
            raise ProcessorExecuteError('Missing parameter "catchment_id". Please provide a catchment_id.')
        try:
            catchment_id_int = int(in_catchment_id)
        except (TypeError, ValueError):
            raise ProcessorExecuteError(
                f'Invalid parameter "catchment_id": "{in_catchment_id}". Must be an integer.'
            )
        if catchment_id_int < 1 or catchment_id_int > 118:
            raise ProcessorExecuteError(
                f'Invalid parameter "catchment_id": {catchment_id_int}. Must be between 1 and 118.'
            )

        # Where to store output data
        catchment_filename = 'catchment-%s.gpkg' % self.my_job_id
        catchment_filepath = f'{output_dir}/{catchment_filename}'
        catchment_link = f'{output_url}/{catchment_filename}'

        countries_filename = 'countries-%s.rds' % self.my_job_id
        countries_filepath = f'{output_dir}/{countries_filename}'
        countries_link = f'{output_url}/{countries_filename}'

        # Assemble args for script (order must match the R script's commandArgs):
        # <catchment_id> <output_catchment_gpkg_path> <output_countries_rds_path>
        script_args = [
            str(catchment_id_int),
            catchment_filepath,
            countries_filepath
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
                    "catchment": {
                        "title": self.metadata['outputs']['catchment']['title'],
                        "description": self.metadata['outputs']['catchment']['description'],
                        "href": f'{catchment_link}'
                    },
                    "countries": {
                        "title": self.metadata['outputs']['countries']['title'],
                        "description": self.metadata['outputs']['countries']['description'],
                        "href": f'{countries_link}'
                    }
                }
            }
            return 'application/json', response_object

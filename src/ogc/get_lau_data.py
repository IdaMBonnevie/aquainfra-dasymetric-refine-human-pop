import logging
import subprocess
import json
import os

from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

# how to import python modules containing a hyphen:
import importlib
docker_utils = importlib.import_module("pygeoapi.process.human-population-toolbox.src.ogc.docker_utils")

'''
curl --location 'http://localhost:5000/processes/get-lau-data/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_countries_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/countries.rds",
        "focus_year": "2018"
    }
}'

curl --location 'http://localhost:5000/processes/get-lau-data/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_countries_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/countries.rds",
        "focus_year": "2021"
    }
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

VALID_YEARS = (
    "2011", "2012", "2013", "2014", "2015", "2016", "2017",
    "2018", "2019", "2020", "2021", "2022", "2023", "2024"
)


class GetLauDataProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.process_id = self.metadata["id"]
        self.my_job_id = 'nothing-yet'
        self.image_name = 'dasymetric-population-mapping-image'
        self.script_name = 'get_lau_data.R'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<GetLauDataProcessor> {self.name}'

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
        in_inputFile1_countries_rds = data.get('inputFile1_countries_rds')
        in_focus_year = data.get('focus_year')

        # Check user inputs
        if in_inputFile1_countries_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile1_countries_rds". Please provide a inputFile1_countries_rds.')
        if in_focus_year is None:
            raise ProcessorExecuteError('Missing parameter "focus_year". Please provide a focus_year.')
        in_focus_year = str(in_focus_year)
        if in_focus_year not in VALID_YEARS:
            raise ProcessorExecuteError(
                f'Invalid parameter "focus_year": "{in_focus_year}". '
                f'Allowed years are: {", ".join(VALID_YEARS)}.'
            )

        # Where to store output data
        lau_focus_filename = 'lau_focus-%s-%s.rds' % (in_focus_year, self.my_job_id)
        lau_focus_filepath = f'{output_dir}/{lau_focus_filename}'
        lau_focus_link = f'{output_url}/{lau_focus_filename}'

        focusyear_filename = 'focusyear-%s-%s.rds' % (in_focus_year, self.my_job_id)
        focusyear_filepath = f'{output_dir}/{focusyear_filename}'
        focusyear_link = f'{output_url}/{focusyear_filename}'

        # Assemble args for script (order must match the R script's commandArgs):
        # <countries_for_catchment> <focus_year> <output_lau_focus_rds_path> <output_focusyear_rds_path>
        script_args = [
            in_inputFile1_countries_rds,
            in_focus_year,
            lau_focus_filepath,
            focusyear_filepath
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
                    "lau_focus": {
                        "title": self.metadata['outputs']['lau_focus']['title'],
                        "description": self.metadata['outputs']['lau_focus']['description'],
                        "href": f'{lau_focus_link}'
                    },
                    "focusyear": {
                        "title": self.metadata['outputs']['focusyear']['title'],
                        "description": self.metadata['outputs']['focusyear']['description'],
                        "href": f'{focusyear_link}'
                    }
                }
            }
            return 'application/json', response_object

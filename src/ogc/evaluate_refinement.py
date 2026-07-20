import logging
import subprocess
import json
import os

from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

# how to import python modules containing a hyphen:
import importlib
docker_utils = importlib.import_module("pygeoapi.process.human-population-toolbox.src.ogc.docker_utils")

'''
curl --location 'http://localhost:5000/processes/evaluate-refinement/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "inputFile1_refinementWeightedReference_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/refinement_weighted_2021.rds",
        "inputFile2_refinementSimpleReference_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/refinement_simple_2021.rds",
        "inputFile3_censusgrid_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/out/censusgrid_catchment.rds",
        "inputFile4_corineCLC_rds": "https://raw.githubusercontent.com/MarkusKonk/aquainfra-dasymetric-refine-human-pop/refs/heads/main/outputs_example/corine2018_cropped.rds"
    }
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))


class EvaluateRefinementProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.process_id = self.metadata["id"]
        self.my_job_id = 'nothing-yet'
        self.image_name = 'dasymetric-population-mapping-image'
        self.script_name = 'evaluate_refinement.R'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<EvaluateRefinementProcessor> {self.name}'

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
        in_inputFile1_refinementWeightedReference_rds = data.get('inputFile1_refinementWeightedReference_rds')
        in_inputFile2_refinementSimpleReference_rds = data.get('inputFile2_refinementSimpleReference_rds')
        in_inputFile3_censusgrid_rds = data.get('inputFile3_censusgrid_rds')
        in_inputFile4_corineCLC_rds = data.get('inputFile4_corineCLC_rds')

        # Check user inputs
        if in_inputFile1_refinementWeightedReference_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile1_refinementWeightedReference_rds". Please provide a inputFile1_refinementWeightedReference_rds.')
        if in_inputFile2_refinementSimpleReference_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile2_refinementSimpleReference_rds". Please provide a inputFile2_refinementSimpleReference_rds.')
        if in_inputFile3_censusgrid_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile3_censusgrid_rds". Please provide a inputFile3_censusgrid_rds.')
        if in_inputFile4_corineCLC_rds is None:
            raise ProcessorExecuteError('Missing parameter "inputFile4_corineCLC_rds". Please provide a inputFile4_corineCLC_rds.')

        # Where to store output data
        evaluate_weighted_filename = 'evaluate_weighted-%s.rds' % self.my_job_id
        evaluate_weighted_filepath = f'{output_dir}/{evaluate_weighted_filename}'
        evaluate_weighted_link = f'{output_url}/{evaluate_weighted_filename}'

        evaluate_simple_filename = 'evaluate_simple-%s.rds' % self.my_job_id
        evaluate_simple_filepath = f'{output_dir}/{evaluate_simple_filename}'
        evaluate_simple_link = f'{output_url}/{evaluate_simple_filename}'

        corineCLC_only_positive_filename = 'corineCLC_only_positive-%s.rds' % self.my_job_id
        corineCLC_only_positive_filepath = f'{output_dir}/{corineCLC_only_positive_filename}'
        corineCLC_only_positive_link = f'{output_url}/{corineCLC_only_positive_filename}'

        metrics_weighted_filename = 'metrics_weighted-%s.rds' % self.my_job_id
        metrics_weighted_filepath = f'{output_dir}/{metrics_weighted_filename}'
        metrics_weighted_link = f'{output_url}/{metrics_weighted_filename}'

        metrics_simple_filename = 'metrics_simple-%s.rds' % self.my_job_id
        metrics_simple_filepath = f'{output_dir}/{metrics_simple_filename}'
        metrics_simple_link = f'{output_url}/{metrics_simple_filename}'

        # Assemble args for script (order must match the R script's commandArgs):
        # <refinement_weighted_reference_rds_path> <refinement_simple_reference_rds_path>
        # <census_grid_rds_path> <corineCLC_rds_path>
        # <output_evaluate_weighted_rds_path> <output_evaluate_simple_rds_path>
        # <output_corineCLC_only_potisive_rds_path> <output_metrics_rds_path> <output_metrics_simple_rds_path>
        script_args = [
            in_inputFile1_refinementWeightedReference_rds,
            in_inputFile2_refinementSimpleReference_rds,
            in_inputFile3_censusgrid_rds,
            in_inputFile4_corineCLC_rds,
            evaluate_weighted_filepath,
            evaluate_simple_filepath,
            corineCLC_only_positive_filepath,
            metrics_weighted_filepath,
            metrics_simple_filepath
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
            outputs_def = self.metadata['outputs']
            response_object = {
                "outputs": {
                    "evaluate_weighted": {
                        "title": outputs_def['evaluate_weighted']['title'],
                        "description": outputs_def['evaluate_weighted']['description'],
                        "href": f'{evaluate_weighted_link}'
                    },
                    "evaluate_simple": {
                        "title": outputs_def['evaluate_simple']['title'],
                        "description": outputs_def['evaluate_simple']['description'],
                        "href": f'{evaluate_simple_link}'
                    },
                    "corineCLC_only_positive": {
                        "title": outputs_def['corineCLC_only_positive']['title'],
                        "description": outputs_def['corineCLC_only_positive']['description'],
                        "href": f'{corineCLC_only_positive_link}'
                    },
                    "metrics_weighted": {
                        "title": outputs_def['metrics_weighted']['title'],
                        "description": outputs_def['metrics_weighted']['description'],
                        "href": f'{metrics_weighted_link}'
                    },
                    "metrics_simple": {
                        "title": outputs_def['metrics_simple']['title'],
                        "description": outputs_def['metrics_simple']['description'],
                        "href": f'{metrics_simple_link}'
                    }
                }
            }
            return 'application/json', response_object

import os
import json

from utils import (
    get_path_from_env,
    add_file_extension,
    error_if_not_exists,
    create_if_not_exists,
)


TYPES = {
    "COHORTS_PATH": str,
    "COHORTS": list,
    "EDF_PATH": str,
    "HEADER_CSV_COLUMNS": list,
    "FAILED_CSV_COLUMNS": list,
    "OUTPATH": str,
    "HEADER_CSV_FNAME": str,
    "FAILED_CSV_FNAME": str,
    "INDEX_COL": str,
}


class Config:
    
    
    def __init__(self, conf_filename):
        self.values = self._load_config(conf_filename)
        self._reformat_config()
        self._check_config()
        self._create_dir()

        
    def _load_config(self, conf_filename):
        if not os.path.exists(conf_filename):
            raise Exception(f'File not found: ({conf_filename})')

        with open(conf_filename) as C:
            config = json.load(C)

        return config


    def _check_config(self):

        # Check var types
        for var in TYPES:
            if not var in self.values:
                raise Exception(f'Required `{var}` in config file')

            if type(self.values[var]) != TYPES[var]:
                raise Exception(f'Invalid type of `{var}` ' + \
                                f'expected {TYPES[var]}, got {type(self.values[var])}')
                
        # Check path exists
        for path_var in ['COHORTS_PATH']:
            error_if_not_exists(self.values[path_var])
        
        # Check other conditions    
        if not self.values["INDEX_COL"] in self.values["HEADER_CSV_COLUMNS"] or\
            not self.values["INDEX_COL"] in self.values["FAILED_CSV_COLUMNS"]:
            raise Exception(f'INDEX_COL should be in HEADER_CSV_COLUMNS & FAILED_CSV_COLUMNS')
                
                
    def _reformat_config(self):
        self.values["COHORTS_PATH"] = get_path_from_env(self.values["COHORTS_PATH"])
        self.values["OUTPATH"] = get_path_from_env(self.values["OUTPATH"])
        
        self.values["HEADER_CSV_FNAME"] = add_file_extension(self.values["HEADER_CSV_FNAME"], "csv")
        self.values["FAILED_CSV_FNAME"] = add_file_extension(self.values["FAILED_CSV_FNAME"], "csv")
        
        
    def _create_dir(self):
        
        # Check path exists
        for path_var in ['OUTPATH', 'ARCHIVE_PATH']:
            create_if_not_exists(self.values[path_var])
            
from config_handler import Config
from edf_reader import (
    read_header_edf,
    read_raw_edf,
)
from reformat_header import (
    reformat_edf_header, 
    reformat_file_info,
    prepare_df,
)
from utils import (
    save_to_csv,
    error_if_not_exists,
    archive,
    remove,
)
from const import (
    EDF_COMPLIANT,
    CONFIG_PATH,
    FILE_EXT,
)

import pandas as pd
from pathlib import Path
from tqdm import tqdm
import os
pjoin = os.path.join


config = Config(CONFIG_PATH).values
COHORTS_PATH = config["COHORTS_PATH"]
COHORTS = config["COHORTS"]
EDF_PATH = config["EDF_PATH"]
HEADER_CSV_COLUMNS = config["HEADER_CSV_COLUMNS"]
FAILED_CSV_COLUMNS = config["FAILED_CSV_COLUMNS"]
OUTPATH = config["OUTPATH"]
HEADER_CSV_FNAME = config["HEADER_CSV_FNAME"]
FAILED_CSV_FNAME = config["FAILED_CSV_FNAME"]
INDEX_COL = config["INDEX_COL"]
ARCHIVE_PATH = config["ARCHIVE_PATH"]
VERSION = config["VERSION"]


HEADER_CSV_PATH = pjoin(OUTPATH, HEADER_CSV_FNAME)
FAILED_CSV_PATH = pjoin(OUTPATH, FAILED_CSV_FNAME)


if __name__ == '__main__':
    
    existing_id = []
    if os.path.exists(HEADER_CSV_PATH):
        ans = input(f'{HEADER_CSV_FNAME} already exists. Please choose from the following options: \n' + \ 
                    f'  1.) Remove old csv and re-run all\n' + \ 
                    f'  2.) Skip existing `{INDEX_COL}` in the csv\n' + \
                    f'Please input your option (1-2) ? : '
                   )
        
        current_version = archive(OUTPATH, HEADER_CSV_FNAME, ARCHIVE_PATH, VERSION, '.csv')
        current_version = archive(OUTPATH, FAILED_CSV_FNAME, ARCHIVE_PATH, VERSION, '.csv', current_version)
        if ans == '1':
            remove(HEADER_CSV_PATH)
            remove(FAILED_CSV_PATH)
        elif ans == '2':
            df = pd.read_csv(HEADER_CSV_PATH)
            existing_id = df[INDEX_COL].values
        else:
            raise Exception('Invalid option.')
    
        
    print(f'Read EDF headers from {len(COHORTS)} cohorts: {COHORTS}')
    for cohort in COHORTS:
        print('\n\n' + '='*30, cohort, '='*30)
        edf_path_str = EDF_PATH.replace('<COHORT_PATH>', COHORTS_PATH).replace('<COHORT>', cohort)
        error_if_not_exists(edf_path_str)
        
        edf_path = Path(edf_path_str)
        cohort_files = edf_path.glob(FILE_EXT)

        
        for edf_filename in cohort_files:
            edf_filename = str(edf_filename)
            edf_compliant = EDF_COMPLIANT.SUCCESS
            all_header = {}
            error_msg = None

            
            try:
                all_header.update(**reformat_file_info(cohort, edf_filename))
            except Exception as e:
                print(f'Cannot read file-info header from {edf_filename} | {e}')
                error_msg = e

                
            index = all_header[INDEX_COL]   
            if index in existing_id:
                print(f'{index} already exists -> SKIP.')
                continue
            else:
                existing_id.append(index)
                
            try:
                header = read_header_edf(edf_filename)
                all_header.update(**reformat_edf_header(header))
            except Exception as e:
                print(f'Cannot read edf-info header from {edf_filename} | {e}')
                error_msg = e

                
            try:
                raw_reader = read_raw_edf(edf_filename)
            except Exception as e:
                print(f'Cannot read raw EDF | {e}')
                raw_reader = None
                error_msg = e


            if error_msg:
                edf_compliant = EDF_COMPLIANT.ERROR
                
                
            additional_info = {
                "edf_compliant": edf_compliant
            }
            all_header.update(**additional_info)


            headers_df = prepare_df(all_header, HEADER_CSV_COLUMNS, INDEX_COL)
            save_to_csv(headers_df, HEADER_CSV_PATH, HEADER_CSV_COLUMNS, INDEX_COL)
            del headers_df
            
            
            if edf_compliant == EDF_COMPLIANT.SUCCESS:
                print(f'{index} | EDF header saved: {HEADER_CSV_FNAME}\n')
                
            else:
                print(f'{index} | EDF header saved with exception:' +\
                      f' {HEADER_CSV_FNAME} & {FAILED_CSV_FNAME}\n')
                all_header["error"] = error_msg
                failed_df = prepare_df(all_header, FAILED_CSV_COLUMNS, INDEX_COL)
                save_to_csv(failed_df, FAILED_CSV_PATH, FAILED_CSV_COLUMNS, INDEX_COL)
                del failed_df


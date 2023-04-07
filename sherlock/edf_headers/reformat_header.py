import os
import pandas as pd
from utils import get_file_size


def convert_to_megabytes(size_in_bytes):
    return size_in_bytes / (1024*1024)


def convert_to_hours(duration_sec):
    return duration_sec / 60 / 60


def reformat_file_info(cohort, edf_filename):
    fname = edf_filename.split('/')[-1]
    fname_spl = fname.split('.')
    
    info = {
        "file_stem": fname_spl[0],
        "extension": fname_spl[1],
        "cohort": cohort.split('_')[0],
        "file_size_mb": convert_to_megabytes(get_file_size(edf_filename)),
    }
    
    return info


def reformat_date_time(date_time):
    spl = date_time.split(' ')
    return { 
        "date": spl[0],
        "time": spl[1],
    }


def reformat_edf_header(header):
    start = reformat_date_time(header["date_time"])
    h = {
        "start_date": start["date"],
        "start_time": start["time"],
        "duration_hours": convert_to_hours(header['record_length'] * header['n_records']),
        "edf_plus": header['EDF+'],
    }
    return h


def index_columns_exist(index_col, header):
    return index_col in header and header[index_col] != None and len(header[index_col]) > 0


def prepare_df(header, columns, index_col):
    # get only headers specified in config
    if not index_columns_exist(index_col, header):
        raise Exception(f'index_col ({index_col}) cannot be empty')
        
    index = header[index_col]
    d = {}
    for c in columns:
        if c in header:
            d[c] = header[c]
        else:
            d[c] = ''
    
    header_df = pd.DataFrame(d, index=[index])
    header_df.drop([index_col], axis=1, inplace=True)
    
    return header_df


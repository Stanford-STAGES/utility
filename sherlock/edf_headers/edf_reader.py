import pyedflib
import mne
import re, datetime
import numpy as np
from charset_normalizer import from_bytes as fm


def decode_str(b):
    return str(fm(b).best()).strip()


def read_header_edf(edf_filename):
    """
    Reference: https://github.com/akaraspt/deepsleepnet/blob/master/dhedfreader.py
    """
    with open(edf_filename, "rb") as f:
        
        h = {}
        assert f.tell() == 0  # check file position
        assert f.read(8) == b'0       '

        # recording info)
        h['local_subject_id'] = decode_str(f.read(80))
        h['local_recording_id'] = decode_str(f.read(80))

        # parse timestamp
        (day, month, year) = [int(x) for x in re.findall('(\d+)', str(f.read(8)))]
        (hour, minute, sec)= [int(x) for x in re.findall('(\d+)', str(f.read(8)))]
        h['date_time'] = str(datetime.datetime(year + 2000, month, day,
                                               hour, minute, sec))

        # misc
        header_nbytes = int(f.read(8))
        subtype = f.read(44)[:5]
        h['EDF+'] = 1 if subtype in ['EDF+C', 'EDF+D'] else 0
        h['contiguous'] = subtype != 'EDF+D'
        h['n_records'] = int(f.read(8))
        h['record_length'] = float(f.read(8)) # in seconds
        nchannels = h['n_channels'] = int(f.read(4))

        # read channel info
        channels = list(range(h['n_channels']))
        h['channels'] = [decode_str(f.read(16)) for n in channels]
        h['transducer_type'] = [decode_str(f.read(80)) for n in channels]
        h['units'] = [decode_str(f.read(8)) for n in channels]
        h['physical_min'] = np.asarray([float(f.read(8)) for n in channels])
        h['physical_max'] = np.asarray([float(f.read(8)) for n in channels])
        h['digital_min'] = np.asarray([float(f.read(8)) for n in channels])
        h['digital_max'] = np.asarray([float(f.read(8)) for n in channels])
        h['prefiltering'] = [decode_str(f.read(80)) for n in channels]
        h['n_samples_per_record'] = [int(f.read(8)) for n in channels]
        f.read(32 * nchannels)  # reserved

        assert f.tell() == header_nbytes
        return h


def read_raw_edf(edf_filename):
    f = mne.io.read_raw_edf(edf_filename)
    return f

        
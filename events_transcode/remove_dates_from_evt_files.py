from pathlib import Path
import sys
from datetime import datetime # https://docs.python.org/3/library/datetime.html


__DRY_RUN__ = False


def remove_dates_from_evt_files(pathname=None, filename=None):

    if pathname is not None and filename is not None:
        print('Method expects either pathname or filename to be given, but not both.')
    elif pathname is None and filename is None:
        print('Method expects either pathname or filename to be given as an input argument.  None was provided.')
    elif pathname is not None:
        if not isinstance(pathname, Path):
            pathname = Path(pathname)
        if pathname.is_file():
            print('A filename was given as the pathname argument.  Nothing will be done.')
        elif not pathname.is_dir():
            print(f'Invalid/nonexistent pathname given: {str(pathname)}')
        else:
            filenames = pathname.glob('*.[Cc][Ss][Vv]')
            # filenames = glob.glob(pathname, '*.[Cc][Ss][Vv]')
            failed_files = []
            for filename in filenames:
                try:
                    print(f'Removing dates from {str(filename)} . . . ', end='')
                    remove_dates_from_evt_files(filename=filename)
                    print('done.')
                except UnicodeDecodeError:
                    print('FAIL.')
                    failed_files.append(str(filename))

            if len(failed_files):
                print(f'\n{len(failed_files)} files failed: ')
                for i, file in enumerate(failed_files):
                    print(f'{i+1}. {Path(file).name}')
    else:
        if not isinstance(filename, Path):
            filename = Path(filename)
        if filename.is_dir():
            print('A path was given for the filename argument.  Nothing will be done.')
        elif not filename.is_file():
            print(f'Invalid/nonexistent filename given: {str(filename)}')
        else:
            output = []
            contents = None
            with open(filename, 'r') as fid:
                # read_csv_files
                contents = list(fid)
                # contents = fid.readlines()
                # contents = fid.read()
            if contents is not None:
                #Start Time,Duration (seconds),Event
                #5/22/2018 8:16:00 PM, 30.000, Wake
                #5/22/2018 8:16:13 PM, 0.000, Custom User Event 4
                for line in contents:
                    # change the datetime format so it is just the staticmethod
                    timestamp, separator, remainder = line.partition(',')
                    try:
                        timestamp_object = datetime.strptime(timestamp, '%m/%d/%Y %I:%M:%S %p')
                        timestamp = timestamp_object.strftime('%H:%M:%S')
                        output.append(timestamp+separator+remainder)
                    except ValueError as err:
                        output.append(line)
                if __DRY_RUN__:
                    for line in output:
                        print(line)
                else:
                    # write the csv file over the old one
                    with open(filename, 'w') as fid:
                        fid.writelines(output)



def print_usage(name='remove_dates_from_evt_files'):
    print('\nUsage: python -m remove_date_from_evt_files [filename|pathname]\n\n')


# https://docs.python.org/3/library/__main__.html
if __name__ == '__main__':
    num_args = len(sys.argv)
    if num_args == 2:
        ambiguous_name = Path(sys.argv[1])
        if ambiguous_name.is_dir():
            print('A path')
            remove_dates_from_evt_files(pathname=str(ambiguous_name))
        elif ambiguous_name.is_file():
            print(str(ambiguous_name), 'is a file')
            remove_dates_from_evt_files(filename=str(ambiguous_name))
        else:
            print(f'Invalid/nonexistent filename or path given: {str(ambiguous_name)}')
            print_usage(sys.argv[0])
    else:
        print_usage(sys.argv[0])





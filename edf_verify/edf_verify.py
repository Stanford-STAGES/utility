import sys
from pyedflib import EdfReader
from pathlib import Path
import traceback


def verify_edf_files(edf_path_to_verify: Path):
    if not isinstance(edf_path_to_verify, Path):
        edf_path_to_verify = Path(edf_path_to_verify)

    if not edf_path_to_verify.is_dir():
        print(f'Path to edf files is not a directory: {str(edf_path_to_verify)}')
    elif not edf_path_to_verify.exists():
        print(f'Path to edf files does not exist: {str(edf_path_to_verify)}')
    else:
        edf_files_not_in_table = []
        edf_files_in_table = []
        # Get all the files in the path
        edf_files = edf_path_to_verify.glob('*.edf')
        edf_file_count = len([name for name in edf_files if name.is_file()])
        edf_files = edf_path_to_verify.glob('*.edf')
        num_files = edf_file_count
        fail_files = []
        fail_reasons = []

        print(f'Verifying .edf files in {str(edf_path_to_verify)}\n\t{num_files} EDF files found.')

        for i, edf_file in enumerate(edf_files):
            edf_filename = edf_file.name
            edf_stem = edf_file.stem.lower()
            if edf_stem in edf_files_in_table:
                edf_files_in_table.remove(edf_stem)
            else:
                edf_files_not_in_table.append(edf_filename)

            print(f'{i + 1:3d} of {num_files} - {edf_filename} ... ', end='')
            try:
                EdfReader(str(edf_file))
                print('SUCCESS')
            except Exception as Exc:
                # traceback.print_exc(file=sys.stdout)
                # traceback.print_exception(type(Exc), Exc, None)
                # traceback.format_exception_only(type(Exc), Exc)
                #
                fail_reasons.append(str(Exc))
                fail_files.append(edf_filename)
                print('FAIL')

        print('')
        print(f'{len(fail_files)} files failed.')
        if len(fail_files) > 0:
            for idx, fail_file in enumerate(fail_files):
                print('\t' + fail_file + '\t' + fail_reasons[idx])


def main_menu():
    print()
    print('-'*20)
    print('EDF verification')
    choice = ''
    while choice.lower() != 'x':
        print('-'*20)
        print()
        choice = input('Enter the pathname of .edf files to verify or ''x'' to exit: ').lower()

        if choice == 'x':
            print('Goodbye')
        else:
            verify_edf_files(choice)


if __name__ == '__main__':
    nargin = len(sys.argv)

    # if no input arguments or too many input arguments
    if nargin < 2 or nargin > 3:
        main_menu()
    else:
        src_path = Path(sys.argv[1])
        verify_edf_files(src_path)
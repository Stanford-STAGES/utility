import shutil
import os
pjoin = os.path.join


def get_path_from_env(edf_path):
    if '$' in edf_path:
        new_path = []
        for spl in edf_path.split('/'):
            if spl[0] == '$':
                p = os.environ.get(spl[1:])
                if p == None or len(p) == 0:
                    raise Exception(f"env variable `{spl}` doesn't exist.")
                else:
                    new_path.append(p)
            else:
                new_path.append(spl)
        return pjoin(*new_path)
    
    else:
        return edf_path
    
    
def error_if_not_exists(fpath):
    if not os.path.exists(fpath):
        raise Exception(f'File not found: {fpath}')
    
    
def create_if_not_exists(fpath):
    if not os.path.exists(fpath):
        os.makedirs(fpath)
        print(f'Created: {fpath}')
        
    
def get_file_size(filename):
    return os.path.getsize(filename)


def save_to_csv(df, csv_path, columns, index_col):
    if os.path.exists(csv_path):
        mode = "a"
        header = False
    else:
        mode = "w"
        header = True
        
    columns = [c for c in columns if c != index_col]
    df.to_csv(csv_path, mode = mode, columns=columns, 
              header=header, index_label=index_col,
              float_format='%.3f')
        
    
def add_file_extension(filename, extension):
    extension = extension.replace('.', '')
    if not extension.lower() in filename.lower():
        filename += '.' + extension
    return filename


def archive(fpath, fname, arch_path, version, ftype = '.csv', current_version=None):
    
    if ftype in fname:
        fstem = fname[:-len(ftype)]
    else:
        fstem = fname
        fname += ftype

    f_name = pjoin(fpath, fname)
    if not os.path.exists(f_name):
        print(f'No file to archive | {f_name} doesn\'t exist.')
        return
    
    V_SUFFIX = '-v' + version + '.'
    if current_version == None:
        archives = sorted([f[:-len(ftype)] for f in os.listdir(arch_path) if fstem + V_SUFFIX in f])
        if len(archives) == 0:
            latest_version = 0
        else:
            latest = archives[-1]
            latest_version = int(latest[len(fstem):].split(V_SUFFIX)[1])
        current_version = latest_version + 1
    
    fname_new = fstem + V_SUFFIX + str(current_version) + ftype
    arch_name = pjoin(arch_path, fname_new)
    shutil.copyfile(f_name, arch_name)
    print(f'Copied to: {f_name} {arch_name}')
    
    return current_version
    

def remove(fpath):
    if not os.path.exists(fpath):
        print(f'No file to remove | {fpath} doesn\'t exist.')
    else:
        os.remove(fpath)
    
    
    
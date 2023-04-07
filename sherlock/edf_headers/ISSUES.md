# Issues
#### 1. No symbolic links to subdirectories
- `st_lukes` and `ISRUC_Portugal` don't have symbolic links to `<COHORT>/all`. Should I run through all subdirs or skip ? 
- Current version: Removed from config.json, otherwise it will throw an error (Directory not found)


#### 2. Exception
- Should I note the exceptions ?
- Current version: No


#### 3. pyedflib or MNE
- Some EDF files cannot be read using pyedflib (It shows `The file is discontinous and cannot be read` / `the file is not EDF(+) or BDF(+) compliant (it contains format errors)`) but works well by MNE.
- Should I try both and set `edf_compliant = 0` only when both of them don't work? or Should I allow user to configure whether they want to use `pyedflib` or `MNE`?
- Current version: Use only pyedflib


#### 4. Cannot get EDF/EDF+ info
- Headers / Info / functions from both `pyedflib` and `MNE` don't provide types of EDF (EDF/EDF+).
- Now, I read headers from raw EDF as binary, applying the code from `DeepSleepNet`.
- Then, read EDF again using `pyedflib`, to ensure whether it can be loaded via the library.
- Does it worth it ? Is the EDF/EDF+ info really necessary?


#### 5. Duplicate rows
- If `file_stem` already exists in CSV, should I overwrite that row or skip it ?
- Current version: Doesn't check if it exists

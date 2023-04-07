# Details
This repository is implemented for retreiving header information, duration, and location of the .edf files we have on Oak to CSV.

# Installation and Dependencies
* Use `python3.6`
* `pip install -r requirements.txt`

# Configuration
- [Required] -- `config.json`
    - Input
        - `COHORTS_PATH`: Path to cohorts' directories
        - `COHORTS`: List of cohorts
        - `EDF_PATH`: Path to edf files
    - Output
        - `CSV_COLUMNS`: List of desired columns
        - `OUTPATH`: Path to CSV
        - `CSV_FNAME`: CSV filename
        - `INDEX_COL`: Index columns of CSV
- [Optional] -- `const.py` : Define constant variables

# How to Run
```
python run.py
```

# How to Run on Sherlock
```sh
$ ml python/3.6.1
$ python3 run.py
```

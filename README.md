Utility programs, scripts, and resources for use by Stanford Center for Sleep Sciences and Behavioral Research and its collaborators.

# channel_label_identifier.py

Use the `channel_label_identifier.py` tool by running
```
python channel_label_identifier.py <path to folder containing EDFs and hypnograms> montage.json C3 C4 A1 A2 EOGL EOGR LChin RChin EMG
```

This will create a JSON file (`montage.json`) containing key-value pairs to map the desired electrode labels shown above with the electrode configurations available in the data.  This is also a useful way to assess the exact distribution of channel labels found in the .edf files located in a specific folder.  


# edf_verify/

This folder contains a Python script to verify if EDF files will work with pyedflib.EdfReader.

From a command prompt

* To run interactively with a prompt for the path to check (Enter 'x' to quit):

  `python3.6 -m edf_verify`

* To run once, specify which path to check (e.g. '/path/to/check/'):

  `python3.6 -m edf_verify ~/path/to/check`

# edf_deidentify/

This folder contains a Ruby script from the NSRR which may be used to deidentify edf files.

# edf_transcode/

This folder contains MATLAB code that is helpful for curating and normalizing EDF files to include: 

1. Updating header information
   * Removing bad header data, such as unrecognized characters,
   * Correcting discrepancies between file size listed in the header and the actual file size found
2. Resampling an .EDF to a specified sample rate.
3. Referencing channels (e.g. combinging 'C3' and 'M2' to get 'C3-M2').
4. Culling unwanted channels to produce smaller files.

# sherlock/

This folder contains helper methods for Sherlock.

 **edf_headers/** <br>
 This repository is implemented for retreiving header information, duration, and location of the .edf 	
	files we have on Oak to CSV.

## examples

To simplify a set of .edf files in place (i.e. rewrite them):

```matlab
psgPath =  'G:\OAK\narco_validation\edf_path';
normalize_edfs(psgPath);
```

To save a simplified version of .edf files in a different folder (e.g. `destPath` below): 

```matlab
psgPath =  'G:\OAK\narco_validation\edf_path';
destPath = 'G:\OAK\narco_validation\normalized_edfs';
normalize_edfs(psgPath, destPath);
```

To obtain a list of all unique channel labels found in the .edf files at a particular path

```matlab
s = 'G:\OAK\narco_validation\edf_path\'
[channelNames, channelNamesAll] = CLASS_converter.getAllChannelNames(s);
```

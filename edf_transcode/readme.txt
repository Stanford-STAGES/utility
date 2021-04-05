This folder contains MATLAB code that is helpful for curating and normalizing EDF files to include: 

1. Updating header information
   * Removing bad header data, such as unrecognized characters,
   * Correcting discrepancies between file size listed in the header and the actual file size found
2. Resampling an .EDF to a specified sample rate.
3. Referencing channels (e.g. combinging 'C3' and 'M2' to get 'C3-M2').
4. Culling unwanted channels to produce smaller files.

## examples

To simplify a set of .edf files in place (i.e. rewrite them):

```matlab
psgPath ='/var/psg/STNF';
normalize_edfs(psgPath);
```

To save a simplified version of .edf files in a different folder (e.g. `destPath` below): 

```matlab
psgPath ='/var/psg/STNF';
destPath = '/var/psg/STNF/plm_edf';
normalize_edfs(psgPath, destPath);
```

To save a simplified version of .edf files from the Stanford STAGES cohort to a different folder:
```matlab
psgPath ='/var/psg/STNF';
destPath = '/var/psg/STNF/plm_edf';
normalize_stages_edfs(psgPath, destPath);
```


To obtain a list of all unique channel labels found in the .edf files at a particular path

```matlab
s = 'G:\OAK\narco_validation\edf_path\'
[channelNames, channelNamesAll] = CLASS_converter.getAllChannelNames(s);
```

# Examples

## Exporting Embla events

* Description: Converting Embla event files (.evt and .nvt) to Stanford STAGES compatible event files.
Embla categoriezes , where there is folder for a study and inside the folder are files like user.evt, stage.evt, plm.evt; or sometimes its hr.nvt (nvt and evt are used interchangeably).

* Requires: 
1. Path to files with Embla events
2. Path to save exported events.
3. Category of event format to use when exporting (e.g. 'EVTS')


* Example:

```MATLAB
srcPath = '~/Data/sleep/ssc';
destPath = '~/Data/sleep/ssc/evts/';
CLASS_converter.emblaEvtExport(srcPath,destPath,'EVTS');
```
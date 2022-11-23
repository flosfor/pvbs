PVBS: Prairie View Browsing Solution

(yoonjy@mit.edu, yjy@snu.ac.kr)


* MATLAB-based GUI for browsing and analyzing electrophysiology (patch clamp) and imaging data acquired with Prairie View (Bruker)

* Please mention this code in your methods section.

* Supported experiment types: 
1) PV VoltageRecording
2) PV LineScan (synchronized with VoltageRecording and/or MarkPoints)
3) PV T-Series (of VoltageRecording experiments)
4) Any data in .CSV format


* See also (https://github.com/flosfor/pvbs_auxiliary) for auxiliary scripts that can be used with PVBS.


* Instructions: 

1) Run PVBS (pvbs.m)
(designed for Prairie View 5.5; developed with Matlab 2020b, requires statistics & machine learning toolbox, signal processing toolbox)

For a usage example:

2) Unzip sampledata.zip (, .z01, .z02)
(Download from Github by left-clicking on each file name and then clicking "download", instead of right-clicking on the file names and choosing "save link as" - file sizes should be 14.2 MB (.zip) or 24.0 MB (.z01 & .z02))

3) Load sampledata.mat from PVBS using "Load Dataset (.mat)" 
(NOT "Load PV Experiment (.xml, .csv)" - this function is for loading experiments saved from Prairie View (VoltageRecording, LineScan, TSeries; via respective metadata), or .csv exported from PVBS)
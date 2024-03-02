PVBS: Prairie View Browsing Solution


Copyright 2022-2024 (C), Jaeyoung Yoon. 
(jy.yoon@tch.harvard.edu; yoonjy@mit.edu; yjy@snu.ac.kr)

The use or modification of this software (PVBS) is consented only under agreement to cite the developer and/or the original source code (https://github.com/flosfor/pvbs) within the body of the published work or presentation, wherein PVBS was used.


- MATLAB-based general-purpose GUI for browsing and analyzing electrophysiology (patch clamp) and calcium imaging data
  (Requires Statistics & Machine Learning Toolbox, Signal Processing Toolbox)

- Developed for interpreting data acquired with Prairie View (Bruker)
- Compatible with any data in .CSV format (does not have to be from Prairie View)

 - Supported experiment types: 
   1) *.CSV (any data)
   2) *.ABF (from pClamp)
   3) *.XML (from Prairie View (PV))
    3-1) VoltageRecording
    3-2) LineScan (synchronized with VoltageRecording and/or MarkPoints)
    3-3) T-Series (of VoltageRecording type experiments)


- Instructions: 

1) Run PVBS.m
(Developed with Matlab 2020b; requirements: statistics & machine learning toolbox, signal processing toolbox)

 - or -

2) Run PVBS.exe
(Stand-alone .exe; can be run without Matlab license, but does require Matlab Runtime, and slower than running directly from Matlab IDE)


- For a usage example: 

1) Unzip sampledata.zip (, .z01, .z02)
(Download from Github by left-clicking on each file name and then clicking "download", instead of right-clicking on the file names and choosing "save link as" - file sizes should be 14.2 MB (.zip) or 24.0 MB (.z01 & .z02))

2) Load sampledata.mat from PVBS using "Load Dataset (.mat)" 
(NOT "Load PV Experiment (.xml, .csv)" - this function is for loading experiments saved from Prairie View (VoltageRecording, LineScan, TSeries; via respective metadata), or .csv exported from PVBS)




A problem is a problem only when you have the ability to recognize it.

Prairie View (PV) is entirely ill-suited for the typical basic needs of a patch clamp electrophysiologist: it has a most primitive browser, provides no means for analysis, lacks the concept of episodic recording and operates on gap-free mode by default (unless through introducing further complications by using its T-Series format), all while saving data and metadata in a very inefficient and incomprehensible format, which aggravates all of its defects as well as prevents access attempts using other softwares. The fundamental problem of PV can therefore be summarized as the following: it deprives the experimenter of their ability to perform and assess work in good quality.

PVBS ("Prairie View Browsing Solution" ;) ) was developed as a solution to this problem. It was written during the unfortunate period when I had no choice but to use PV at MIT building 46, without being provided with those very basic tools which should normally be available; and while I was a complete beginner at coding until eventually becoming a novice, as must be evident from the way it is written. Hence, it is far from being elegant; still, PVBS will provide at least some means instead of nothing for a patch clamp electrophysiologist to do proper work - at least for those who recognize the needs for it. PVBS was conceptually influenced by Axon pClamp, particularly ClampFit.




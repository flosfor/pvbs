PVBS: Prairie View Browsing Solution


Copyright 2022-2023, Jaeyoung Yoon. 
(jy.yoon@tch.harvard.edu; yoonjy@mit.edu; yjy@snu.ac.kr)

The use or modification of this software (PVBS) is consented only under agreement to cite the developer and/or the original source code (https://github.com/flosfor/pvbs) within the body of the published work or presentation, wherein PVBS was used.


- MATLAB-based general-purpose GUI for browsing and analyzing electrophysiology (patch clamp) and calcium imaging data
  (Requires Statistics & Machine Learning Toolbox, Signal Processing Toolbox)

- Developed for interpreting data acquired with Prairie View (Bruker)
- Compatible with any data in .CSV format (does not have to be from Prairie View)

- Supported experiment types:
1) Any data in .CSV format
2) PV VoltageRecording
3) PV LineScan (synchronized with VoltageRecording and/or MarkPoints)
4) PV T-Series (of VoltageRecording experiments)
5) Specific applications of the above, such as 2-p glutamate uncaging or sCRACM


- Instructions: 

1) Run PVBS (pvbs.m)
(designed for Prairie View 5.5; developed with Matlab 2020b, requires statistics & machine learning toolbox, signal processing toolbox)


- For a usage example: 

1) Unzip sampledata.zip (, .z01, .z02)
(Download from Github by left-clicking on each file name and then clicking "download", instead of right-clicking on the file names and choosing "save link as" - file sizes should be 14.2 MB (.zip) or 24.0 MB (.z01 & .z02))

2) Load sampledata.mat from PVBS using "Load Dataset (.mat)" 
(NOT "Load PV Experiment (.xml, .csv)" - this function is for loading experiments saved from Prairie View (VoltageRecording, LineScan, TSeries; via respective metadata), or .csv exported from PVBS)




A problem is a problem only when you have the ability to recognize it.

Prairie View (PV) is entirely ill-suited for the typical basic needs of a patch clamp electrophysiologist: it has a most primitive browser, provides no means for analysis (online or offline), lacks the concept of episodic recording and operates on gap-free mode by default (unless through introducing further complications by using its T-Series format), all while saving data and metadata in a very inefficient and incomprehensible format, which aggravates all of its defects as well as prevents access attempts using other softwares. The fundamental problem of PV can therefore be summarized as the following: it deprives the experimenter of their ability to perform and assess work in good quality.

PVBS ("Prairie View Browsing Solution") was developed to provide a solution to this problem. The code was written since I was a complete beginner until eventually becoming a novice, as must be evident from the way it is written; hence, it is inevitably far from efficient at all. Still, it will provide at least some means instead of nothing, for a patch clamp electrophysiologist to do proper work - for those who recognize the needs for it. PVBS was conceptually influenced by Axon pClamp, particularly ClampFit.


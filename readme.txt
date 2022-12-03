PVBS (Prairie View Browsing Solution)
(https://github.com/flosfor/pvbs)

Jaeyoung Yoon (yoonjy@mit.edu, yjy@snu.ac.kr)




* MATLAB-based GUI for browsing and analyzing electrophysiology (patch clamp) and imaging data acquired with Prairie View (Bruker)

* Please mention this code in your methods section.

* Supported experiment types: 
1) PV VoltageRecording
2) PV LineScan (synchronized with VoltageRecording and/or MarkPoints)
3) PV T-Series (of VoltageRecording experiments)
4) Any data in .CSV format


* Instructions: 

1) Run PVBS (pvbs.m)
(designed for Prairie View 5.5; developed with Matlab 2020b, requires statistics & machine learning toolbox, signal processing toolbox)


* For a usage example: 

1) Unzip sampledata.zip (, .z01, .z02)
(Download from Github by left-clicking on each file name and then clicking "download", instead of right-clicking on the file names and choosing "save link as" - file sizes should be 14.2 MB (.zip) or 24.0 MB (.z01 & .z02))

2) Load sampledata.mat from PVBS using "Load Dataset (.mat)" 
(NOT "Load PV Experiment (.xml, .csv)" - this function is for loading experiments saved from Prairie View (VoltageRecording, LineScan, TSeries; via respective metadata), or .csv exported from PVBS)


* See also (https://github.com/flosfor/pvbs_auxiliary) for auxiliary scripts that can be used with PVBS.




A problem is a problem only when you have the ability to recognize it. Prairie View (PV) is entirely ill-suited for the typical basic needs of a patch clamp electrophysiologist: it has a most primitive browser, provides no means for analysis, lacks the concept of episodic recording and operates on gap-free mode by default (unless through introducing further complications by using its T-Series format), all while saving data and metadata in a very inefficient and incomprehensible format, which aggravates all of its problems as well as prevent access from other applications. PVBS ("Prairie View Browsing Solution") was developed to provide a solution to this problem. This code was written since I was a complete beginner until eventually becoming a novice, as must be obvious from the way it is written; hence, it is inevitably far from efficient at all. Still, it will provide at least some means for a patch clamp electrophysiologist to do proper work, for those who recognize the needs for it. This code was conceptually influenced by Axon pClamp, particularly ClampFit.




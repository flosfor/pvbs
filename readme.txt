PVBS: Prairie View Browsing Solution


Copyright 2022-2024 (C), Jaeyoung Yoon. 
(jy.yoon@tch.harvard.edu; yoonjy@mit.edu; yjy@snu.ac.kr)

The use or modification of this software (PVBS) is consented only under agreement to cite the developer and/or the original source code (https://github.com/flosfor/pvbs) within the body of the published work or presentation, wherein PVBS was used.


- MATLAB-based general-purpose GUI for browsing and analyzing electrophysiology (patch clamp) and calcium imaging data


- Initially developed for interpreting data acquired with Prairie View (Bruker), but compatible with any data in the following format:

 (Supported experiment types)
   1) *.CSV (any data)
   2) *.ABF (from pClamp)
   3) *.XML (from Prairie View (PV))
    3-1) VoltageRecording
    3-2) LineScan (synchronized with VoltageRecording and/or MarkPoints)
    3-3) T-Series (of VoltageRecording type experiments)


- Instructions: 

1) Run PVBS.exe
 - Stand-alone executable that can be run without a licensed copy of Matlab
 - Requires either Matlab Runtime (R2023a (9.14)), or a licensed copy of Matlab with Statistics & Machine Learning Toolbox and Signal Processing Toolbox
 - If run with Matlab Runtime (MCR), make sure to have the correct version of MCR (R2023a (9.14)) (https://www.mathworks.com/products/compiler/matlab-runtime.html)
 - Can be slower than running PVBS.m from Matlab IDE, but only at startup for initializing MCR

 - or -

2) Run PVBS.m
 - Requirements: Statistics & Machine Learning Toolbox and Signal Processing Toolbox (developed with R2023a)


- For a usage example: 

1) Unzip sampledata.zip (, .z01, .z02)
(Download from Github by left-clicking on each file name and then clicking "download", instead of right-clicking on the file names and choosing "save link as" - file sizes should be 14.2 MB (.zip) or 24.0 MB (.z01 & .z02))

2) Load sampledata.mat using the "Load Dataset (.mat)" button on the PVBS GUI
(NOT "Load Experiment (.abf, .xml, .csv)" - this function is for loading experiment files containing data and/or metadata, not for loading dataset .mat files saved from PVBS)


- For additional scripts that can be used with PVBS:
Scripts for PVBS-processed data (https://github.com/flosfor/pvbs_auxiliary)




A problem is a problem only when you have the ability to recognize it.

Prairie View (PV) is entirely ill-suited for the typical basic needs of a patch clamp electrophysiologist: it has a most primitive browser, provides no means for analysis, lacks the concept of episodic recording and operates on gap-free mode by default (unless through introducing further complications by using its T-Series format), all while saving data and metadata in a very inefficient and incomprehensible format, which aggravates all of its defects as well as prevents access attempts using other softwares. The fundamental problem of PV can therefore be summarized as the following: it deprives the experimenter of their ability to perform and assess work in good quality.

PVBS ("Prairie View Browsing Solution" ;) ) was developed as a solution to this problem. It was written during the unfortunate period when I had no choice but to use PV at MIT building 46, without being provided with those very basic tools which should normally be available; and while I was a complete beginner at coding until eventually becoming a novice, as must be evident from the way it is written. Hence, it is far from being elegant; still, PVBS will provide at least some means instead of nothing for a patch clamp electrophysiologist to do proper work - at least for those who recognize the needs for it. PVBS was conceptually influenced by Axon pClamp, particularly ClampFit.




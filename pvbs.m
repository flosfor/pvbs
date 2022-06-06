%% Prairie View Browsing Solution (PVBS)
% (https://github.com/flosfor/pvbs)
%
% Jaeyoung Yoon (yoonjy@mit.edu, yjy@snu.ac.kr)
%
%
% -------------------------- <!> Important <!> ---------------------------
%  See function setDefaultParams() or use the "Import Settings" button on 
%  the GUI for default import parameters, e.g. DAC gain, input channels, 
%  etc.; these can easily be different across setups, so make sure they 
%  are correct for yours!
% ------------------------------------------------------------------------
%
% Supported experiment types: 
%  1) PV VoltageRecording
%  2) PV LineScan (synchronized with VoltageRecording and/or MarkPoints)
%  3) PV T-Series (of VoltageRecording experiments)
%  4) Any data in .CSV format
%     (When importing .CSV directly and not through PV metadata .XML, and 
%      columns are defined as sweeps, code will tacitly assume that values 
%      are in correct units (ms, mV, pA), represent voltage (see below), 
%      without row or column offset, and include timestamp at column 1; 
%      this is to avoid possible confusion caused by differences in .CSV 
%      formatting conventions used by PV (scaled, gap-free) vs. others, 
%      such as .CSV exported from PVBS (unscaled, episodic). See function 
%      loadCSVMain() for the settings override, including defaulting to 
%      interpret values as current instead of voltage; see also variable 
%      "csvColumnsAsSweeps" in function setDefaultParmas(). Parameters in 
%      "Import Settings" represent those used for importing .CSV saved
%      from PV by loading them via metadata .XML (in which case columns 
%      will not be considered as sweeps regardless of csvColumnsAsSweeps, 
%      since PV data will always be in gap-free format))
%
% NB.
%  Electrophysiology-related labels and parameters assume by default iC 
%  and positive peaks (e.g. EPSP), but are fully compatible with either 
%  iC or VC, and peaks with any direction.
%  "If you only knew the power of the dark side... [of patch clamp]"
%
% Features underway for future versions:
%  - Artifact removal
%  - Manual linescan ROI selection
%  - Threshold detection
%  - Waveform analysis
%  - Improved intrinsic properties analysis
%  - Multiple input channel support (e.g. for dual recordings)
%  - .abf & .atf import
%
%
%  This code was written since I was a complete beginner until eventually 
%  becoming a novice; even the variable naming convention changed at some 
%  point. Hence, it is inevitably very far from effcient at all, but it 
%  will still provide at least some basic means to browse through and 
%  analyze data acquired with PV. This code was conceptually influenced by 
%  Axon pClamp.
%
%
%
%
%%


function pvbs()
% main window
pvbsTitle = 'Prairie View Browsing Solution (PVBS)';
pvbsLastMod = '2022.06.02';
pvbsStage = '(b)';
fpVer = '5.5'; % not the version of this code, but PV itself
matlabVer = '2020b'; % with Statistics & Machine Learning Toolbox (v. 12.0)

% open and initialize
theGreatCorona = 2020; % best year ever
pvbsVer = [num2str(str2num(pvbsLastMod(1:4)) - theGreatCorona), pvbsLastMod(5:end)]; % why not
win = figure('Name', [pvbsTitle, '  //  ', 'v. ', pvbsVer, ' ', pvbsStage, '  /  (PV. ', fpVer, '  &  Matlab ', matlabVer, ')'], 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.075, 0.15, 0.9, 0.8]);
h = struct();
%%{
    ui.aboutPVBS = uicontrol('Style', 'pushbutton', 'String', '?', 'foregroundcolor', [0.75, 0.75, 0.75], 'backgroundcolor', [0.95, 0.95, 0.95], 'Units', 'normalized', 'Position', [0.00, 0.995, 0.0025, 0.005], 'Callback', @aboutPVBS, 'interruptible', 'off'); 
    function aboutPVBS(src, ~)
        aboutButton = src;
        set(aboutButton, 'enable', 'off');
        aboutWin = figure('Name', 'About PVBS', 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.4, 0.4, 0.25, 0.25], 'resize', 'off', 'CloseRequestFcn', @closeAboutWin);
        aboutWinText1 = uicontrol('Parent', aboutWin, 'Style', 'text', 'string', ' PVBS : "Prairie View Browsing Solution"', 'fontweight', 'bold', 'horizontalalignment', 'center', 'Units', 'normalized', 'Position', [0.05, 0.85, 0.9, 0.1]);
        aboutWinText2 = uicontrol('Parent', aboutWin, 'Style', 'text', 'string', sprintf(' "mspaint made by an unfortunate graphics designer \n who is not a programmer and used to having Photoshop" \n   \n\n v. %s \n  Designed for Prairie View %s & Matlab %s \n  (requires Statistics & Machine Learning Toolbox) \n\n (LF)  "What does PVBS stand for?" \n (JY)  "(PVBS)" \n\n', [pvbsVer, ' ', pvbsStage], fpVer, matlabVer), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.15, 0.8, 0.65]);
        aboutWinClose = uicontrol('Parent', aboutWin, 'Style', 'pushbutton', 'string', 'Che sfortuna!', 'horizontalalignment', 'center', 'backgroundcolor', [0.9, 0.9, 0.9], 'Units', 'normalized', 'Position', [0.3, 0.1, 0.4, 0.1], 'Callback', @closeAboutWin, 'interruptible', 'off');
        function closeAboutWin(src, ~)
            set(aboutButton, 'enable', 'on');
            delete(aboutWin);
        end
    end
%}

% load default parameters
guidata(win, h);
%params.defaultParams = struct();
defaultParams = setDefaultParams(win); % default parameter set
params.actualParams = defaultParams; % actual parameters to be used; initializing with defaults
params.defaultParams = defaultParams; % store separately for access (e.g. to revert to defaults)

% default parameters that can be hard-coded without much concern
%params.defaultParams = struct(); % moved up
params.analysisBaseline = [27, 44]; % baseline window; NB. choose ~ 16.67 ms to average out 60 Hz noise
params.analysisWindow1 = [52, 152]; % analysis window 1
params.analysisWindow2 = [60, 200]; % analysis window 2
%params.analysisTargetList = {'(Target)', 'All Groups', 'Selected Groups', 'All Sweeps', 'Selected Sweeps'};
%{
params.analysisOptionList11 = {'(Dir.)', '+/-', '+', '-'};
params.analysisOptionList12 = {'(Kin.)', '20-80', '10-90', 'Custom...'};
params.analysisOptionList21 = {'(Dir.)', '+/-', '+', '-'};
params.analysisOptionList22 = {'(Kin.)', '20-80', '10-90', 'Custom...'};
%}
%params.analysisPlotMenuList0 = {'(Experiment)', 'Current Experiment', 'All Experiments'};
params.analysisPlotMenuList1 = {'(Signal)', 'S1', 'S2'};
params.analysisPlotMenuList2 = {'(Window)', 'W1', 'W2'};
params.analysisPlotMenuList3 = {'(Results)', '(Select Window # for options)'};
params.analysisPlotMenuList31 = {'(Results)', 'Peak', 'Area', 'Mean', 'Time of Peak', 'Rise (time)', 'Decay (time)', 'Rise (slope)', 'Decay (slope)'};
params.analysisPlotMenuList4 = {'(Plot by...)', 'Swps.', 'Grps.'};
params.analysisTypeList1 = {'(Type)', 'Peak / Area / Mean', 'Threshold Detection', 'Waveform'};
params.analysisTypeList2 = {'(Type)', 'Peak / Area / Mean', 'Threshold Detection', 'Waveform'};
params.analysisPresetList = {'(Select)', 'Uncaging w/ LineScan'};
params.analysisBaselineColor = [0.4, 0.5, 0.6]; % baseline window color
params.analysisWindow1Color = [0, 0.75, 0.75]; % analysis window 1 color
params.analysisWindow2Color = [0, 0.6, 0.6]; % analysis window 2 color
%params.intrinsicPropertiesAnalysis = struct(); % default analysis parameters for intrinsic membrane properties %%% moved under params.actualParams
params.xRange = []; % x axis range for main trace display; leave this empty
params.xRangeZoom = 2; % x range zooming factor
params.xRangeMove = 0.166666667; % x range moving factor
params.yRangeDefault = [-140, 20]; % y axis range for main trace display
params.yRange = params.yRangeDefault; 
params.yRangeZoom = 2; % y range zooming factor
params.yRangeMove = 0.083333334; % y range moving factor
params.y2RangeDefault = [-1, 4]; % y axis (right) range for main trace display
params.y2Range = params.y2RangeDefault; 
params.y2RangeZoom = 2; % y range (right) zooming factor
params.y2RangeMove = 0.083333334; % y range (right) moving factor
params.traceColorInactive = [0.6, 0.6, 0.6]; % color for inactive traces
params.traceColorActive = [1, 0, 0]; % color for active (selected) traces
params.trace2ColorInactive = [0.9, 0.95, 0.9]; % secondary color for inactive traces
params.trace2ColorActive = [0.6, 0.8, 0.6]; % secondary color for active (selected) traces
params.selectionInterval = 1; % default sweep selection interval
params.groupSelectionInterval = 0; % default selection interval for grouping
params.groupSweepIdx = 0; % index of sweep to display within group
%params.peakDirection = 0; % direction for peak detection (-1: negative, 0: absolute, 1: positive) - obsolete
params.traceProcessingTargetList = {'Voltage / Current', 'Fluorescence'}; % obsolete, using params.analysisPlotMenuList1 instead
params.exportTarget = 1; % which signal to export - default to 1
params.resultsPlot1YRange = []; % will be updated upon analysis
params.resultsPlot2YRange = []; % will be updated upon analysis
params.lastSweepDeleted = 0; % flag to indicate if last sweep had been deleted; for correct indexing
params.firstRun = 1; % flag for first run

% data structure
exp.experimentCount = 0;
exp.metadata = {}; % cell for tSeries metadata files
%  below are for easier access without having to dig into metadata
exp.fileName = {}; % file name
exp.filePath = {}; % file path
exp.sweeps = {}; % total sweep count for each tSeries
%  actual data
data.VRec = {}; % VRec (.csv)
data.VRecOriginal = {}; % VRec (.csv), to preserve original in case of postprocessing - again real lack of foresight
data.VRecMetadata = {}; % metadata for each VRec (.xml)
data.VOut = {}; % VOut (.xml) - may have to omit due to PVBS insanity in formatting these
data.VOutName = {}; % VRec experiment type (e.g. "single stim") - VOut name will work most of the time
%data.lineScanMetadata = {}; % metadata for each LScn (.xml) - obsolete, linescans don't have separate metadata per cycle
data.lineScan = {}; % LScn (.tiff)
data.lineScanDFF = {}; % LScn dF/F
data.lineScanDFFOriginal = {}; % LScn dF/F, to preserve original in case of postprocessing - again real lack of foresight
data.lineScanF = {}; % LScn F
data.lineScanFChannel = {}; % LScn channel used for F, dF/F
data.lineScanROI = {}; % LScn ROI
data.lineScanBaseline = {}; % LScn baseline period (time)
data.lineScanCSV = {}; % LScn profile (.csv)
data.postprocessing = {}; % postprocessing info (e.g. downsampling)
data.artifactRemoval = {}; % artifact removal info
data.markPointsIdx = {}; % indices for MkPts
data.markPointsMetadata = {}; % MkPts metadata (.xml)
data.intrinsicProperties = {}; % intrinsic properties, analyzed from file below
data.intrinsicPropertiesVRec = {}; % intrinsic properties VRec (.csv)
data.intrinsicPropertiesVRecMetadata = {}; % metadata for intrinsic properties VRec (.xml)
data.intrinsicPropertiesFileName = {}; % file path and name for intrinsic properties
data.zStack = {}; % z-stack
data.zStackFileName = {}; % file path and name for z-stack
data.singleScan = {}; % single-scan image
data.singleScanFileName = {}; % file path and name for single-scan
data.sweepIdx = {}; % sweep indices
data.sweepStr = {}; % sweep strings for display
data.groupIdx = {}; % sweep grouping indices
data.groupStr = {}; % sweep grouping indices in string format for display
data.notes = {}; % notes
exp.data = data; % meta-struct for VRec data

% analysis results
results = {};

% more analysis results - another unplanned mess "resulting" in more of really stupid naming and structuring
analysis = struct();

% UI elements
%  experiment list
ui.experimentTitle = uicontrol('Style', 'text', 'string', 'Experiments', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.015, 0.955, 0.09, 0.02]);
ui.saveMatButton = uicontrol('Style', 'pushbutton', 'String', 'Save Dataset (.mat)', 'backgroundcolor', [0.875, 0.875, 0.9], 'Units', 'normalized', 'Position', [0.015, 0.92, 0.121, 0.03], 'Callback', @saveMat, 'interruptible', 'off');
ui.loadMatButton = uicontrol('Style', 'pushbutton', 'String', 'Load Dataset (.mat)', 'backgroundcolor', [0.875, 0.875, 0.9], 'Units', 'normalized', 'Position', [0.015, 0.89, 0.121, 0.03], 'Callback', @loadMat, 'interruptible', 'off');
ui.saveGUIButton = uicontrol('Style', 'pushbutton', 'enable', 'off', 'String', 'Save GUI for Debugging (.mat)', 'backgroundcolor', [0.875, 0.875, 0.9], 'Units', 'normalized', 'Position', [0, 0, 0.0025, 0.005], 'Callback', @saveGUI, 'interruptible', 'off');
ui.defaultSettingsButton = uicontrol('Style', 'pushbutton', 'String', 'Import Settings', 'backgroundcolor', [0.875, 0.875, 0.9], 'Units', 'normalized', 'Position', [0.015, 0.84, 0.121, 0.03], 'Callback', @defaultSettingsCallback, 'interruptible', 'off');
ui.loadExpButton = uicontrol('Style', 'pushbutton', 'String', 'Load Experiment (.xml, .csv)', 'backgroundcolor', [0.85, 0.85, 0.95], 'Units', 'normalized', 'Position', [0.015, 0.81, 0.121, 0.03], 'Callback', @loadExp, 'interruptible', 'off'); % will be used for both vRec or tSer
ui.cellListDisplay = uicontrol('Style', 'listbox', 'Visible', 'on', 'Min', 0, 'Max', 1000, 'Units', 'normalized', 'Position', [0.015, 0.55, 0.12, 0.25], 'Callback', @cellListClick, 'interruptible', 'off'); % not cellist
ui.cellList = {}; % experiment list items - in hindsight, this was very poorly named
ui.cellListUp = uicontrol('Style', 'pushbutton', 'String', '^', 'Units', 'normalized', 'Position', [0.015, 0.51, 0.02, 0.03], 'Callback', @cellListUp, 'interruptible', 'off');
ui.cellListDown = uicontrol('Style', 'pushbutton', 'String', 'v', 'Units', 'normalized', 'Position', [0.0345, 0.51, 0.02, 0.03], 'Callback', @cellListDown, 'interruptible', 'off');
ui.cellListMerge = uicontrol('Style', 'pushbutton', 'String', 'Merge', 'Units', 'normalized', 'Position', [0.0555, 0.51, 0.025, 0.03], 'Callback', @cellListMerge, 'interruptible', 'off');
ui.cellListDuplicate = uicontrol('Style', 'pushbutton', 'String', 'Duplicate', 'Units', 'normalized', 'Position', [0.08, 0.51, 0.035, 0.03], 'Callback', @cellListDuplicate, 'interruptible', 'off');
ui.cellListDel = uicontrol('Style', 'pushbutton', 'String', 'X', 'Units', 'normalized', 'Position', [0.1155, 0.51, 0.02, 0.03], 'Callback', @cellListDel, 'interruptible', 'off');
%  main trace display window
ui.traceDisplayTitle = uicontrol('Style', 'text', 'string', 'Traces', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.15, 0.955, 0.09, 0.02]);
ui.traceDisplay = axes('Units', 'Normalized', 'Position', [0.19, 0.42, 0.57, 0.53], 'xminortick', 'on', 'yminortick', 'on', 'box', 'on');
ui.traceDisplayChannels = uicontrol('Style', 'pushbutton', 'enable', 'on', 'String', 'S#', 'backgroundcolor', [0.99, 0.99, 0.99], 'Units', 'normalized', 'Position', [0.735, 0.905, 0.015, 0.03], 'Callback', @traceDisplayChannels, 'interruptible', 'off');
ui.traceDisplayXZoomIn = uicontrol('Style', 'pushbutton', 'String', '+', 'fontweight', 'bold', 'Units', 'normalized', 'Position', [0.5245, 0.361, 0.015, 0.03], 'Callback', @traceDisplayXZoomIn, 'interruptible', 'off');
ui.traceDisplayXZoomOut = uicontrol('Style', 'pushbutton', 'String', '-', 'fontweight', 'bold', 'Units', 'normalized', 'Position', [0.4115, 0.361, 0.015, 0.03], 'Callback', @traceDisplayXZoomOut, 'interruptible', 'off');
ui.traceDisplayXMoveRight = uicontrol('Style', 'pushbutton', 'String', '>', 'fontweight', 'bold', 'Units', 'normalized', 'Position', [0.72, 0.361, 0.015, 0.03], 'Callback', @traceDisplayXMoveRight, 'interruptible', 'off');
ui.traceDisplayXMoveLeft = uicontrol('Style', 'pushbutton', 'String', '<', 'fontweight', 'bold', 'Units', 'normalized', 'Position', [0.216, 0.361, 0.015, 0.03], 'Callback', @traceDisplayXMoveLeft, 'interruptible', 'off');
ui.traceDisplayYZoomIn = uicontrol('Style', 'pushbutton', 'String', '+', 'fontweight', 'bold', 'Units', 'normalized', 'Position', [0.15, 0.76, 0.015, 0.03], 'Callback', @traceDisplayYZoomIn, 'interruptible', 'off');
ui.traceDisplayYZoomOut = uicontrol('Style', 'pushbutton', 'String', '-', 'fontweight', 'bold', 'Units', 'normalized', 'Position', [0.15, 0.58, 0.015, 0.03], 'Callback', @traceDisplayYZoomOut, 'interruptible', 'off');
ui.traceDisplayYMoveUp = uicontrol('Style', 'pushbutton', 'String', '^', 'fontweight', 'bold', 'Units', 'normalized', 'Position', [0.15, 0.89, 0.015, 0.03], 'Callback', @traceDisplayYMoveUp, 'interruptible', 'off');
ui.traceDisplayYMoveDown = uicontrol('Style', 'pushbutton', 'String', 'v', 'fontweight', 'bold', 'Units', 'normalized', 'Position', [0.15, 0.45, 0.015, 0.03], 'Callback', @traceDisplayYMoveDown, 'interruptible', 'off');
ui.traceDisplayY2ZoomIn = uicontrol('Style', 'pushbutton', 'String', '+', 'fontweight', 'bold', 'foregroundcolor', [0, 0.5, 0], 'Units', 'normalized', 'Position', [0.785, 0.76, 0.015, 0.03], 'Callback', @traceDisplayY2ZoomIn, 'interruptible', 'off');
ui.traceDisplayY2ZoomOut = uicontrol('Style', 'pushbutton', 'String', '-', 'fontweight', 'bold', 'foregroundcolor', [0, 0.5, 0], 'Units', 'normalized', 'Position', [0.785, 0.58, 0.015, 0.03], 'Callback', @traceDisplayY2ZoomOut, 'interruptible', 'off');
ui.traceDisplayY2MoveUp = uicontrol('Style', 'pushbutton', 'String', '^', 'fontweight', 'bold', 'foregroundcolor', [0, 0.5, 0], 'Units', 'normalized', 'Position', [0.785, 0.89, 0.015, 0.03], 'Callback', @traceDisplayY2MoveUp, 'interruptible', 'off');
ui.traceDisplayY2MoveDown = uicontrol('Style', 'pushbutton', 'String', 'v', 'fontweight', 'bold', 'foregroundcolor', [0, 0.5, 0], 'Units', 'normalized', 'Position', [0.785, 0.45, 0.015, 0.03], 'Callback', @traceDisplayY2MoveDown, 'interruptible', 'off');
ui.traceDisplayReset = uicontrol('Style', 'pushbutton', 'String', 'O', 'fontweight', 'bold', 'Units', 'normalized', 'Position', [0.15, 0.361, 0.015, 0.03], 'Callback', @traceDisplayReset, 'interruptible', 'off');
ui.traceDisplayReset2 = uicontrol('Style', 'pushbutton', 'String', 'O', 'fontweight', 'bold', 'foregroundcolor', [0, 0.5, 0], 'Units', 'normalized', 'Position', [0.785, 0.361, 0.015, 0.03], 'Callback', @traceDisplayReset2, 'interruptible', 'off');
ui.traceDisplayYRange = params.yRange; % set to default Y range
ui.traceDisplayY2Range = params.y2Range; % set to default Y range
ui.traceDisplayXRange = params.xRange; % set to default X range
ui.trace = {}; % traces, saved for sweep indexing
ui.trace2 = {}; % traces (2), saved for sweep indexing
%  sweep and group list
ui.sweepListTitle = uicontrol('Style', 'text', 'string', 'Sweeps ', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.815, 0.955, 0.045, 0.02]);
ui.sweepListDisplay = uicontrol('Style', 'listbox', 'Visible', 'on', 'Min', 0, 'Max', 1000000, 'Units', 'normalized', 'Position', [0.815, 0.62, 0.04, 0.33], 'Callback', @sweepListClick, 'interruptible', 'off');
ui.sweepList = {}; % sweep list items
ui.groupListTitle = uicontrol('Style', 'text', 'string', 'Groups ', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.86, 0.955, 0.09, 0.02]);
ui.groupListDisplay = uicontrol('Style', 'listbox', 'Visible', 'on', 'Min', 0, 'Max', 1000000, 'Units', 'normalized', 'Position', [0.86, 0.62, 0.072, 0.33], 'Callback', @groupListClick, 'interruptible', 'off');
ui.groupList = {}; % group list items
%ui.sweepSelectGroupText = uicontrol('Style', 'text', 'string', '(Sweeps)', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.936, 0.93, 0.045, 0.02]);
ui.sweepSelectText = uicontrol('Style', 'text', 'string', 'Select Swps: ', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.936, 0.93, 0.09, 0.02]);
ui.sweepSelectMod = uicontrol('Style', 'pushbutton', 'string', 'Interval:', 'Units', 'normalized', 'Position', [0.936, 0.9, 0.032, 0.03], 'Callback', @sweepSelectMod, 'interruptible', 'off');
ui.sweepSelectModValue = uicontrol('Style', 'edit', 'string', num2str(params.selectionInterval), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.9685, 0.901, 0.015, 0.028], 'Callback', @sweepSelectModValue, 'interruptible', 'off');
ui.sweepSelectOdd = uicontrol('Style', 'pushbutton', 'string', 'Odd', 'Units', 'normalized', 'Position', [0.936, 0.87, 0.0165, 0.03], 'Callback', @sweepSelectOdd, 'interruptible', 'off');
ui.sweepSelectEven = uicontrol('Style', 'pushbutton', 'string', 'Even', 'Units', 'normalized', 'Position', [0.952, 0.87, 0.0165, 0.03], 'Callback', @sweepSelectEven, 'interruptible', 'off');
ui.sweepSelectInvert = uicontrol('Style', 'pushbutton', 'string', 'Inv', 'Units', 'normalized', 'Position', [0.968, 0.87, 0.0165, 0.03], 'Callback', @sweepSelectInvert, 'interruptible', 'off');
ui.sweepGroupText = uicontrol('Style', 'text', 'string', 'Grp. by: ', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.936, 0.71, 0.045, 0.02]);
ui.groupSelected = uicontrol('Style', 'pushbutton', 'String', 'Sel.', 'Units', 'normalized', 'Position', [0.96, 0.71, 0.024, 0.03], 'Callback', @groupSelected, 'interruptible', 'off');
ui.groupSelectedMod = uicontrol('Style', 'pushbutton', 'string', 'Interval:', 'Units', 'normalized', 'Position', [0.936, 0.68, 0.032, 0.03], 'Callback', @groupSelectedMod, 'interruptible', 'off');
ui.groupSelectedModValue = uicontrol('Style', 'edit', 'string', num2str(params.groupSelectionInterval), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.9685, 0.681, 0.015, 0.028], 'Callback', @groupSelectModValue, 'interruptible', 'off');
%{
ui.groupAuto1 = uicontrol('Style', 'pushbutton', 'String', 'VOut', 'Units', 'normalized', 'Position', [0.936, 0.65, 0.024, 0.03], 'Callback', @groupAutoVOut, 'interruptible', 'off');
ui.groupAuto2 = uicontrol('Style', 'pushbutton', 'String', 'MkPts', 'Units', 'normalized', 'Position', [0.96, 0.65, 0.024, 0.03], 'Callback', @groupAutoMkPts, 'interruptible', 'off');
%}
ui.sweepProcessText = uicontrol('Style', 'text', 'string', 'Selected Swps: ', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.936, 0.84, 0.09, 0.02]);
ui.sweepSegment = uicontrol('Style', 'pushbutton', 'String', 'Segm.', 'Units', 'normalized', 'Position', [0.936, 0.81, 0.024, 0.03], 'Callback', @sweepsSegmentation, 'interruptible', 'off');
ui.sweepTrucante = uicontrol('Style', 'pushbutton', 'String', 'Trunc.', 'Units', 'normalized', 'Position', [0.96, 0.81, 0.024, 0.03], 'Callback', @sweepsTruncate, 'interruptible', 'off');
ui.sweepAverage = uicontrol('Style', 'pushbutton', 'String', 'Avg.', 'Units', 'normalized', 'Position', [0.936, 0.78, 0.024, 0.03], 'Callback', @sweepsAverage, 'interruptible', 'off');
%ui.sweepArithmetic = uicontrol('Style', 'pushbutton', 'String', '+ / -', 'Units', 'normalized', 'Position', [0.96, 0.78, 0.024, 0.03], 'Callback', @sweepsArithmetic, 'interruptible', 'off');
ui.sweepAdd = uicontrol('Style', 'pushbutton', 'String', '+', 'Units', 'normalized', 'Position', [0.96, 0.78, 0.012, 0.03], 'Callback', @sweepsAdd, 'interruptible', 'off');
ui.sweepSubtract = uicontrol('Style', 'pushbutton', 'String', '-', 'Units', 'normalized', 'Position', [0.972, 0.78, 0.012, 0.03], 'Callback', @sweepsSubtract, 'interruptible', 'off');
ui.sweepConcatenate = uicontrol('Style', 'pushbutton', 'String', 'Concat.', 'Units', 'normalized', 'Position', [0.936, 0.75, 0.024, 0.03], 'Callback', @sweepsConcatenate, 'interruptible', 'off');
ui.sweepDel = uicontrol('Style', 'pushbutton', 'String', 'X', 'Units', 'normalized', 'Position', [0.96, 0.75, 0.024, 0.03], 'Callback', @sweepsDelete, 'interruptible', 'off');
%ui.groupText = uicontrol('Style', 'text', 'String', '(Groups)', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.936, 0.68, 0.03, 0.02], 'interruptible', 'off');
ui.groupText = uicontrol('Style', 'text', 'String', 'Selected Grps:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.936, 0.65, 0.09, 0.02], 'interruptible', 'off');
ui.groupListUp = uicontrol('Style', 'pushbutton', 'String', '^', 'Units', 'normalized', 'Position', [0.936, 0.62, 0.024, 0.03], 'Callback', @groupListUp, 'interruptible', 'off');
ui.groupListDown = uicontrol('Style', 'pushbutton', 'String', 'v', 'Units', 'normalized', 'Position', [0.936, 0.59, 0.024, 0.03], 'Callback', @groupListDown, 'interruptible', 'off');
ui.groupListMerge = uicontrol('Style', 'pushbutton', 'String', 'Merge', 'Units', 'normalized', 'Position', [0.96, 0.62, 0.024, 0.03], 'Callback', @groupListMerge, 'interruptible', 'off');
ui.groupListDel = uicontrol('Style', 'pushbutton', 'String', 'X', 'Units', 'normalized', 'Position', [0.96, 0.59, 0.024, 0.03], 'Callback', @groupListDel, 'interruptible', 'off');
ui.groupSweepText = uicontrol('Style', 'text', 'string', 'Sweep #', 'horizontalalignment', 'center', 'Units', 'normalized', 'Position', [0.871, 0.592, 0.05, 0.02]);
ui.groupSweepPrev = uicontrol('Style', 'pushbutton', 'String', '<', 'Units', 'normalized', 'Position', [0.86, 0.59, 0.015, 0.03], 'Callback', @groupSweepPrev, 'interruptible', 'off');
ui.groupSweepNext = uicontrol('Style', 'pushbutton', 'String', '>', 'Units', 'normalized', 'Position', [0.917, 0.59, 0.015, 0.03], 'Callback', @groupSweepNext, 'interruptible', 'off');
%  analysis window
ui.analysisTitle = uicontrol('Style', 'text', 'string', 'Analysis', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.815, 0.56, 0.09, 0.02]);
ui.analysisBaselineText = uicontrol('Style', 'text', 'string', 'Bsln: ', 'foregroundcolor', params.analysisBaselineColor, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.816, 0.532, 0.045, 0.02]);
ui.analysisBaselineText2 = uicontrol('Style', 'text', 'string', '-', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.856, 0.532, 0.02, 0.02]);
ui.analysisBaselineText3 = uicontrol('Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.88, 0.532, 0.045, 0.02]);
ui.analysisBaselineStart = uicontrol('Style', 'edit', 'string', num2str(params.analysisBaseline(1)), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.835, 0.53, 0.02, 0.028], 'Callback', @baselineStart, 'interruptible', 'off');
ui.analysisBaselineEnd = uicontrol('Style', 'edit', 'string', num2str(params.analysisBaseline(2)), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.86, 0.53, 0.02, 0.028], 'Callback', @baselineEnd, 'interruptible', 'off');
ui.analysisBaselineMedian = uicontrol('Style', 'checkbox', 'min', 0, 'max', 1, 'value', 1, 'string', 'Median', 'Units', 'normalized', 'Position', [0.895, 0.53, 0.037, 0.03], 'Callback', @baselineMedian, 'interruptible', 'off');
ui.analysisWindow1Text = uicontrol('Style', 'text', 'string', 'Win 1: ', 'foregroundcolor', params.analysisWindow1Color, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.816, 0.502, 0.045, 0.02]);
ui.analysisWindow1Text2 = uicontrol('Style', 'text', 'string', '-', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.856, 0.502, 0.02, 0.02]);
ui.analysisWindow1Text3 = uicontrol('Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.88, 0.502, 0.045, 0.02]);
ui.analysisWindow1Start = uicontrol('Style', 'edit', 'string', num2str(params.analysisWindow1(1)), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.835, 0.50, 0.02, 0.028], 'Callback', @analysisWindow1Start, 'interruptible', 'off');
ui.analysisWindow1End = uicontrol('Style', 'edit', 'string', num2str(params.analysisWindow1(2)), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.86, 0.50, 0.02, 0.028], 'Callback', @analysisWindow1End, 'interruptible', 'off');
ui.analysisWindow2Text = uicontrol('Style', 'text', 'string', 'Win 2: ', 'foregroundcolor', params.analysisWindow2Color, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.816, 0.472, 0.045, 0.02]);
ui.analysisWindow2Text2 = uicontrol('Style', 'text', 'string', '-', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.856, 0.472, 0.02, 0.02]);
ui.analysisWindow2Text3 = uicontrol('Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.88, 0.472, 0.045, 0.02]);
ui.analysisWindow2Start = uicontrol('Style', 'edit', 'string', num2str(params.analysisWindow2(1)), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.835, 0.47, 0.02, 0.028], 'Callback', @analysisWindow2Start, 'interruptible', 'off');
ui.analysisWindow2End = uicontrol('Style', 'edit', 'string', num2str(params.analysisWindow2(2)), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.86, 0.47, 0.02, 0.028], 'Callback', @analysisWindow2End, 'interruptible', 'off');
ui.analysisWindowHandle = cell(1, 6); % handle for displaying analysis windows - somehow it is overly complicated to make this work
%  analysis parameters
ui.analysisType1 = uicontrol('Style', 'popupmenu', 'string', params.analysisTypeList1, 'value', 2, 'foregroundcolor', params.analysisWindow1Color, 'Units', 'normalized', 'Position', [0.895, 0.497, 0.037, 0.03], 'Callback', @analysisTypeSel, 'interruptible', 'off');
ui.analysisType2 = uicontrol('Style', 'popupmenu', 'string', params.analysisTypeList2, 'value', 2, 'foregroundcolor', params.analysisWindow2Color, 'Units', 'normalized', 'Position', [0.895, 0.467, 0.037, 0.03], 'Callback', @analysisTypeSel, 'interruptible', 'off'); % can use the same callback
%ui.analysisTarget = uicontrol('Style', 'popupmenu', 'string', params.analysisTargetList, 'foregroundcolor', [0.25, 0.25, 0.375],  'Units', 'normalized', 'Position', [0.895, 0.527, 0.037, 0.03], 'Callback', @analysisTargetSel, 'interruptible', 'off');
ui.analysisOptions = uicontrol('Style', 'pushbutton', 'string', 'Options', 'backgroundcolor', [0.9, 0.9, 0.95], 'Units', 'normalized', 'Position', [0.9365, 0.53, 0.0475, 0.025], 'Callback', @analysisOptions, 'interruptible', 'off');
ui.analysisRun = uicontrol('Style', 'pushbutton', 'string', '>>', 'fontweight', 'bold', 'foregroundcolor', 'w', 'backgroundcolor', [0.5, 0.5, 0.75], 'Units', 'normalized', 'Position', [0.936, 0.4735, 0.048, 0.055], 'Callback', @runAnalysis, 'interruptible', 'off');
ui.analysisPresetText = uicontrol('Style', 'text', 'string', 'Analysis Presets: ', 'foregroundcolor', [0.3, 0.3, 0.36], 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.845, 0.442, 0.09, 0.02]);
ui.analysisPreset = uicontrol('Style', 'popupmenu', 'string', params.analysisPresetList, 'value', 2, 'foregroundcolor', [0.3, 0.3, 0.36], 'Units', 'normalized', 'Position', [0.895, 0.437, 0.037, 0.03], 'Callback', @analysisPresetSel, 'interruptible', 'off');
ui.analysisRunPreset = uicontrol('Style', 'pushbutton', 'string', '>', 'fontweight', 'bold', 'foregroundcolor', 'w', 'backgroundcolor', [0.6, 0.6, 0.72], 'Units', 'normalized', 'Position', [0.936, 0.4435, 0.048, 0.025], 'Callback', @runAutoAnalysis, 'interruptible', 'off');
%  analysis results
ui.analysisResultsTitle = uicontrol('Style', 'text', 'string', 'Results', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.815, 0.39, 0.09, 0.02]);
ui.analysisPlot1 = axes('Units', 'Normalized', 'Position', [0.835, 0.255, 0.135, 0.13], 'xminortick', 'on', 'yminortick', 'on');
ui.analysisPlot2 = axes('Units', 'Normalized', 'Position', [0.835, 0.05, 0.135, 0.13], 'xminortick', 'on', 'yminortick', 'on');
ui.analysisPlot1Menu1 = uicontrol('Style', 'popupmenu', 'string', params.analysisPlotMenuList1, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.855, 0.381, 0.032, 0.03], 'callback', @analysisPlotUpdateCall, 'interruptible', 'off');
ui.analysisPlot1Menu2 = uicontrol('Style', 'popupmenu', 'string', params.analysisPlotMenuList2, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.888, 0.381, 0.03, 0.03], 'callback', @analysisPlotUpdateCall, 'interruptible', 'off');
ui.analysisPlot1Menu3 = uicontrol('Style', 'popupmenu', 'string', params.analysisPlotMenuList3, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.919, 0.381, 0.032, 0.03], 'callback', @analysisPlotUpdateCall31, 'interruptible', 'off');
ui.analysisPlot1Menu4 = uicontrol('Style', 'popupmenu', 'string', params.analysisPlotMenuList4, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.952, 0.381, 0.032, 0.03], 'callback', @analysisPlotUpdateCall, 'interruptible', 'off');
ui.analysisPlot2Menu1 = uicontrol('Style', 'popupmenu', 'string', params.analysisPlotMenuList1, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.855, 0.176, 0.032, 0.03], 'callback', @analysisPlotUpdateCall, 'interruptible', 'off');
ui.analysisPlot2Menu2 = uicontrol('Style', 'popupmenu', 'string', params.analysisPlotMenuList2, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.888, 0.176, 0.03, 0.03], 'callback', @analysisPlotUpdateCall, 'interruptible', 'off');
ui.analysisPlot2Menu3 = uicontrol('Style', 'popupmenu', 'string', params.analysisPlotMenuList3, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.919, 0.176, 0.032, 0.03], 'callback', @analysisPlotUpdateCall32, 'interruptible', 'off');
ui.analysisPlot2Menu4 = uicontrol('Style', 'popupmenu', 'string', params.analysisPlotMenuList4, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.952, 0.176, 0.032, 0.03], 'callback', @analysisPlotUpdateCall, 'interruptible', 'off');
ui.analysisPlot1MoveUp = uicontrol('Style', 'pushbutton', 'String', '^', 'Units', 'normalized', 'Position', [0.972, 0.36, 0.0125, 0.024], 'Callback', @resultsPlot1YMoveUp, 'interruptible', 'off');
ui.analysisPlot1MoveDown = uicontrol('Style', 'pushbutton', 'String', 'v', 'Units', 'normalized', 'Position', [0.972, 0.255, 0.0125, 0.024], 'Callback', @resultsPlot1YMoveDown, 'interruptible', 'off');
ui.analysisPlot1ZoomIn = uicontrol('Style', 'pushbutton', 'String', '+', 'Units', 'normalized', 'Position', [0.972, 0.335, 0.0125, 0.024], 'Callback', @resultsPlot1YZoomIn, 'interruptible', 'off');
ui.analysisPlot1ZoomOut = uicontrol('Style', 'pushbutton', 'String', '-', 'Units', 'normalized', 'Position', [0.972, 0.28, 0.0125, 0.024], 'Callback', @resultsPlot1YZoomOut, 'interruptible', 'off');
ui.analysisPlot1ZoomReset = uicontrol('Style', 'pushbutton', 'String', 'O', 'Units', 'normalized', 'Position', [0.972, 0.3075, 0.0125, 0.024], 'Callback', @resultsPlot1YReset, 'interruptible', 'off');
ui.analysisPlot2MoveUp = uicontrol('Style', 'pushbutton', 'String', '^', 'Units', 'normalized', 'Position', [0.972, 0.155, 0.0125, 0.024], 'Callback', @resultsPlot2YMoveUp, 'interruptible', 'off');
ui.analysisPlot2MoveDown = uicontrol('Style', 'pushbutton', 'String', 'v', 'Units', 'normalized', 'Position', [0.972, 0.05, 0.0125, 0.024], 'Callback', @resultsPlot2YMoveDown, 'interruptible', 'off');
ui.analysisPlot2ZoomIn = uicontrol('Style', 'pushbutton', 'String', '+', 'Units', 'normalized', 'Position', [0.972, 0.13, 0.0125, 0.024], 'Callback', @resultsPlot2YZoomIn, 'interruptible', 'off');
ui.analysisPlot2ZoomOut = uicontrol('Style', 'pushbutton', 'String', '-', 'Units', 'normalized', 'Position', [0.972, 0.075, 0.0125, 0.024], 'Callback', @resultsPlot2YZoomOut, 'interruptible', 'off');
ui.analysisPlot2ZoomReset = uicontrol('Style', 'pushbutton', 'String', 'O', 'Units', 'normalized', 'Position', [0.972, 0.1025, 0.0125, 0.024], 'Callback', @resultsPlot2YReset, 'interruptible', 'off');
%  cell info
ui.cellInfoTitle = uicontrol('Style', 'text', 'string', 'Cell Info', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.015, 0.48, 0.09, 0.02]);
ui.cellInfoIntrinsic = uicontrol('Style', 'pushbutton', 'String', 'Intrinsic Properties (.xml, .csv)', 'backgroundcolor', [0.9, 0.9, 0.9], 'Units', 'normalized', 'Position', [0.015, 0.45, 0.095, 0.03], 'Callback', @loadIntrinsic, 'interruptible', 'off');
ui.cellInfoIntrinsicOptions = uicontrol('Style', 'pushbutton', 'string', 'Options', 'backgroundcolor', [0.9, 0.9, 0.9], 'Units', 'normalized', 'Position', [0.11075, 0.45, 0.025, 0.03], 'Callback', @loadIntrinsicOptions, 'interruptible', 'off');
ui.cellInfoZStack = uicontrol('Style', 'pushbutton', 'String', 'Z-Stack (.tif, ...)', 'backgroundcolor', [0.9, 0.9, 0.9], 'Units', 'normalized', 'Position', [0.015, 0.42, 0.06, 0.03], 'Callback', @loadZStack, 'interruptible', 'off');
ui.cellInfoSingleScan = uicontrol('Style', 'pushbutton', 'String', 'Single-Scan (.tif, ...)', 'backgroundcolor', [0.9, 0.9, 0.9], 'Units', 'normalized', 'Position', [0.076, 0.42, 0.06, 0.03], 'Callback', @loadSingleScan, 'interruptible', 'off');
%  notes
ui.notesTitle = uicontrol('Style', 'text', 'string', 'Notes', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.015, 0.39, 0.09, 0.02]);
ui.notes = uicontrol('Style', 'edit', 'string', '', 'horizontalalignment', 'left', 'min', 1, 'max', 1000, 'Units', 'normalized', 'Position', [0.015, 0.33, 0.12, 0.06], 'Callback', @notesEdit);
%  trace processing
ui.traceProcessingTitle = uicontrol('Style', 'text', 'string', 'Postprocessing', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.015, 0.30, 0.09, 0.02]);
ui.traceProcessingTargetText = uicontrol('Style', 'text', 'string', 'Target Signal: ', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.02, 0.274, 0.09, 0.02]);
ui.traceProcessingTarget = uicontrol('Style', 'popupmenu', 'string', params.analysisPlotMenuList1, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.0775, 0.274, 0.0575, 0.025], 'Callback', @downsamplingSignalSelect, 'interruptible', 'off');
ui.downsamplingButton = uicontrol('Style', 'checkbox', 'min', 0, 'max', 1, 'string', 'Boxcar: ', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.016, 0.242, 0.09, 0.03], 'Callback', @downsamplingBoxcarButton, 'interruptible', 'off');
ui.downsamplingInput = uicontrol('Style', 'edit', 'string', num2str(params.actualParams.boxcarLength2), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.08, 0.242, 0.016, 0.026], 'Callback', @downsamplingBoxcarInput, 'interruptible', 'off');
ui.downsamplingText = uicontrol('Style', 'text', 'string', 'x', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.096, 0.242, 0.02, 0.02]);
ui.lowPassFilterButton = uicontrol('Style', 'checkbox', 'min', 0, 'max', 1, 'string', 'Bessel LP: ', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.016, 0.212, 0.09, 0.03],  'Callback', @downsamplingBesselButton, 'interruptible', 'off');
ui.lowPassFilterInput = uicontrol('Style', 'edit', 'string', num2str(params.actualParams.besselFreq2), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.08, 0.212, 0.016, 0.026], 'Callback', @downsamplingBesselInput, 'interruptible', 'off');
ui.lowPassFilterText = uicontrol('Style', 'text', 'string', '(kHz)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.096, 0.212, 0.02, 0.02]);
ui.stimArtifactButton = uicontrol('Style', 'checkbox', 'enable', 'off', 'min', 0, 'max', 1, 'string', 'Remove artifact: ', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.016, 0.18, 0.09, 0.03],  'Callback', @stimArtifactButton, 'interruptible', 'off');
ui.stimArtifactInput = uicontrol('Style', 'edit', 'string', num2str(params.actualParams.artifactLength), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.08, 0.182, 0.016, 0.026], 'Callback', @stimArtifactLength, 'interruptible', 'off');
ui.stimArtifactText = uicontrol('Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.096, 0.182, 0.03, 0.02]);
ui.stimArtifactText2 = uicontrol('Style', 'text', 'string', 'from', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.152, 0.02, 0.02]);
ui.stimArtifactInput2 = uicontrol('Style', 'edit', 'string', num2str(params.actualParams.artifactStart), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.042, 0.152, 0.016, 0.026], 'Callback', @stimArtifactStart, 'interruptible', 'off');
ui.stimArtifactText3 = uicontrol('Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.058, 0.152, 0.02, 0.02]);
ui.stimArtifactText4 = uicontrol('Style', 'text', 'string', 'x', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.073, 0.152, 0.01, 0.02]);
ui.stimArtifactInput3 = uicontrol('Style', 'edit', 'string', num2str(params.actualParams.artifactCount), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.08, 0.152, 0.016, 0.026], 'Callback', @stimArtifactCount, 'interruptible', 'off');
ui.stimArtifactText5 = uicontrol('Style', 'text', 'string', 'at', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.096, 0.152, 0.03, 0.02]);
ui.stimArtifactInput4 = uicontrol('Style', 'edit', 'string', num2str(params.actualParams.artifactFreq), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.105, 0.152, 0.016, 0.026], 'Callback', @stimArtifactFreq, 'interruptible', 'off');
ui.stimArtifactText6 = uicontrol('Style', 'text', 'string', '(Hz)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.121, 0.152, 0.02, 0.02]);
%  export
ui.exportDisplayTitle = uicontrol('Style', 'text', 'string', 'Export', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.015, 0.12, 0.09, 0.02]);
ui.exportTargetText = uicontrol('Style', 'text', 'string', 'Source (Plot / Axis): ', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.02, 0.09, 0.09, 0.02]);
%ui.exportTarget = uicontrol('Style', 'popupmenu', 'string', params.analysisPlotMenuList1, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.042, 0.09, 0.093, 0.025]);
ui.exportTarget1 = uicontrol('Style', 'checkbox', 'min', 0, 'max', 1, 'value', 1, 'string', '1', 'Units', 'normalized', 'Position', [0.09, 0.09, 0.025, 0.025], 'callback', @exportTarget1, 'interruptible', 'off');
ui.exportTarget2 = uicontrol('Style', 'checkbox', 'min', 0, 'max', 1, 'value', 1, 'string', '2', 'Units', 'normalized', 'Position', [0.11, 0.09, 0.025, 0.025], 'callback', @exportTarget2, 'interruptible', 'off');
ui.exportTraceButton1 = uicontrol('Style', 'pushbutton', 'String', 'Traces (.csv)', 'backgroundcolor', [0.85, 0.85, 0.85],  'Units', 'normalized', 'Position', [0.015, 0.06, 0.06, 0.03], 'Callback', @exportTraces1, 'interruptible', 'off');
ui.exportTraceButton2 = uicontrol('Style', 'pushbutton', 'String', 'Trace Display', 'backgroundcolor', [0.85, 0.85, 0.85], 'Units', 'normalized', 'Position', [0.015, 0.03, 0.06, 0.03], 'Callback', @exportTraces2, 'interruptible', 'off');
ui.exportResultsButton1 = uicontrol('Style', 'pushbutton', 'String', 'Results (.csv)', 'backgroundcolor', [0.85, 0.85, 0.85],  'Units', 'normalized', 'Position', [0.076, 0.06, 0.06, 0.03], 'Callback', @exportResults1, 'interruptible', 'off');
ui.exportResultsButton2 = uicontrol('Style', 'pushbutton', 'String', 'All Results (.mat)', 'backgroundcolor', [0.85, 0.85, 0.85],  'Units', 'normalized', 'Position', [0.076, 0.03, 0.06, 0.03], 'Callback', @exportResults2, 'interruptible', 'off');
%  intrinsic properties
ui.intrinsicTitle = uicontrol('Style', 'text', 'string', 'Intrinsic Membrane Properties: ', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.15, 0.3, 0.12, 0.02]);
ui.intrinsicFileName = uicontrol('Style', 'popupmenu', 'string', '(N/A)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.26, 0.298, 0.09, 0.025], 'callback', @copyTextFromPopup, 'interruptible', 'off');
ui.intrinsicUseCurrentFile = uicontrol('Style', 'pushbutton', 'String', 'Use ^', 'Units', 'normalized', 'Position', [0.3525, 0.3, 0.02, 0.024], 'Callback', @intrinsicUseCurrent, 'interruptible', 'off');
ui.intrinsicReanalyze = uicontrol('Style', 'pushbutton', 'String', 'Re-analyze', 'Units', 'normalized', 'Position', [0.3725, 0.3, 0.04, 0.024], 'Callback', @intrinsicReanalyze, 'interruptible', 'off');
ui.intrinsicDel = uicontrol('Style', 'pushbutton', 'String', 'X', 'Units', 'normalized', 'Position', [0.412, 0.3, 0.012, 0.024], 'Callback', @intrinsicDel, 'interruptible', 'off');
ui.intrinsicPlot1 = axes('Units', 'Normalized', 'Position', [0.19, 0.05, 0.11, 0.23], 'xminortick', 'on', 'yminortick', 'on', 'box', 'on');
ui.intrinsicPlot2 = axes('Units', 'Normalized', 'Position', [0.325, 0.19, 0.1, 0.09], 'xminortick', 'on', 'yminortick', 'on');
ui.intrinsicPlot3 = axes('Units', 'Normalized', 'Position', [0.325, 0.05, 0.1, 0.09], 'xminortick', 'on', 'yminortick', 'on');
ui.intrinsicPlot1Enlarge = uicontrol('Style', 'pushbutton', 'String', '+', 'Units', 'normalized', 'Position', [0.288, 0.254, 0.012, 0.024], 'Callback', @intrinsicPlot1Enlarge, 'interruptible', 'off');
ui.intrinsicRMP = uicontrol('Style', 'text', 'string', '', 'backgroundcolor', 'w', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.2425, 0.235, 0.055, 0.02]);
ui.intrinsicRin = uicontrol('Style', 'text', 'string', '', 'backgroundcolor', 'w', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.2425, 0.215, 0.055, 0.02]);
ui.intrinsicSag = uicontrol('Style', 'text', 'string', '', 'backgroundcolor', 'w', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.2425, 0.195, 0.055, 0.02]);
%  z-stack and single-scan images
ui.zStackTitle = uicontrol('Style', 'text', 'string', 'Z-Stack: ', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.445, 0.3, 0.08, 0.02]);
ui.zStackFileName = uicontrol('Style', 'popupmenu', 'string', '(N/A)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.505, 0.298, 0.055, 0.025], 'callback', @copyTextFromPopup, 'interruptible', 'off');
ui.zStackDel = uicontrol('Style', 'pushbutton', 'String', 'X', 'Units', 'normalized', 'Position', [0.562, 0.3, 0.012, 0.024], 'Callback', @zStackDel, 'interruptible', 'off');
ui.zStackEnlarge = uicontrol('Style', 'pushbutton', 'String', '+', 'Units', 'normalized', 'Position', [0.562, 0.2725, 0.012, 0.024], 'Callback', @zStackEnlarge, 'interruptible', 'off');
ui.zStackDisplay = axes('Units', 'Normalized', 'Position', [0.445, 0.03, 0.13, 0.27], 'box', 'on', 'xtick', [], 'ytick', [], 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8], 'color', [0.95, 0.95, 0.95]);
ui.singleScanTitle = uicontrol('Style', 'text', 'string', 'Single-Scan: ', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.58, 0.3, 0.08, 0.02]);
ui.singleScanFileName = uicontrol('Style', 'popupmenu', 'string', '(N/A)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.64, 0.298, 0.055, 0.025], 'callback', @copyTextFromPopup, 'interruptible', 'off');
ui.singleScanDel = uicontrol('Style', 'pushbutton', 'String', 'X', 'Units', 'normalized', 'Position', [0.697, 0.3, 0.012, 0.024], 'Callback', @singleScanDel, 'interruptible', 'off');
ui.singleScanEnlarge = uicontrol('Style', 'pushbutton', 'String', '+', 'Units', 'normalized', 'Position', [0.697, 0.2725, 0.012, 0.024], 'Callback', @singleScanEnlarge, 'interruptible', 'off');
ui.singleScanDisplay = axes('Units', 'Normalized', 'Position', [0.58, 0.03, 0.13, 0.27], 'box', 'on', 'xtick', [], 'ytick', [], 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8], 'color', [0.95, 0.95, 0.95]);
%  linescan
ui.lineScanDisplayTitle = uicontrol('Style', 'text', 'string', 'Linescans: ', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.72, 0.3, 0.08, 0.02]);
ui.lineScanRoiButton = uicontrol('Style', 'pushbutton', 'enable', 'off', 'string', '(ROI)', 'foregroundcolor', [0.2, 0.2, 1], 'horizontalalignment', 'center', 'Units', 'normalized', 'Position', [0.78, 0.3, 0.02, 0.024], 'callback', @lineScanRoiManualSelect, 'interruptible', 'off');
ui.lineScan1Title = uicontrol('Style', 'text', 'string', 'Ch. 1', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.72, 0.27, 0.04, 0.02]);
ui.lineScan2Title = uicontrol('Style', 'text', 'string', 'Ch. 2', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.761, 0.27, 0.04, 0.02]);
ui.lineScan1Display = axes('Units', 'Normalized', 'Position', [0.72, 0.03, 0.038, 0.24], 'box', 'on', 'xtick', [], 'ytick', [], 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8], 'color', [0.95, 0.95, 0.95]);
ui.lineScan2Display = axes('Units', 'Normalized', 'Position', [0.761, 0.03, 0.038, 0.24], 'box', 'on', 'xtick', [], 'ytick', [], 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8], 'color', [0.95, 0.95, 0.95]);
%  initialize display areas
%{
set(ui.traceDisplay, 'xtick', [], 'ytick', [], 'xlabel', [], 'ylabel', []);
set(ui.analysisPlot1, 'xtick', [], 'ytick', [], 'xlabel', [], 'ylabel', []);
set(ui.analysisPlot2, 'xtick', [], 'ytick', [], 'xlabel', [], 'ylabel', []);
set(get(ui.traceDisplay, 'xlabel'), 'string', 't (ms)');
set(get(ui.traceDisplay, 'ylabel'), 'string', 'V_m (mV)');
%}
axes(ui.intrinsicPlot1);
xlabel('t (ms)');
ylabel('V_m (mV)');
xticks(''); yticks('');
axes(ui.intrinsicPlot2);
xlabel('i (pA)');
ylabel('dV (mV)');
xticks(''); yticks('');
axes(ui.intrinsicPlot3);
xlabel('i (pA)');
ylabel('f (Hz)');
xticks(''); yticks('');
axes(ui.analysisPlot1);
%xlabel('Sweep #');
%xticks(''); %yticks('');
axes(ui.analysisPlot2);
%xlabel('Sweep #');
%xticks(''); %yticks('');
axes(ui.traceDisplay); % move focus to main display panel
set(gca, 'layer', 'top');
xlabel('t (ms)');
yyaxis left; ylabel('V_m (mV)', 'color', 'k'); ylim(params.yRange); set(gca, 'ycolor', 'k', 'yminortick', 'on');
yyaxis right; ylabel('dF/F', 'color', 'g'); ylim(params.y2Range); set(gca, 'ycolor', [0, 0.5, 0], 'yminortick', 'on');
yyaxis left; % move focus back to left y axis to be safe

% save
h.exp = exp;
h.results = results;
h.analysis = analysis;
h.params = params;
h.ui = ui;
guidata(win, h);

% load default parameters - moved up
%defaultParams = setDefaultParams(win); % this has to be done after guidata(win, h)
%h.params.defaultParams = defaultParams;

end


%% Default Parameters


function defaultParams = setDefaultParams(win);

% load
h = guidata(win);

% gain settings
%  below are set for MC700B with Rf = 500 MO and usual gain settings for whole-cell recordings, in combination with PV
%  reminder: these are dependent on both acquisition hardware and software settings; make sure they are correct!
pvbsVoltageScalingFactor = 100; % (mV/V); 
pvbsCurrentScalingFactor = 2000; % (pA/V); 

% PVBS software conventions
%  below are set for single channel recording of V and i (in that order)
%  multiple-channel support pending %%%
timeColumn = 1; % column 1: timestamp
pvbsVoltageColumn = 2; % column 2: voltage
pvbsCurrentColumn = 3; % column 3: current
csvOffsetRow = 1; % row 1: title
csvOffsetColumn = 0; % no column offset
csvColumnsAsSweeps = 1; % each column represents a sweep - set this to 0 if primarilily used for importing .csv saved directly from PV (not recommended; import .xls metadata instead for PV data)

% voltage/current data
analysisColumn = 2; % column for analysis; NB. column 1 will usually be timestamp in the current code
peakDirection1 = 1; % window 1 default peak direction (-1, 0, 1 : negative, absolute, positive)
peakDirection2 = 1; % window 2 default peak direction (-1, 0, 1 : negative, absolute, positive)
useMedian = 1; % use median instead of mean for baseline, "mean" (in peak analysis), etc., to be robust from noise
riseDecay = [20, 80]; % low/high point for kinetics analysis (e.g. [20, 80] for 20-80 %)

% fluorescence data
lineScanChannel = 2; % primary channel for calcium imaging signal; e.g. for P4, 1: red, 2: green (primary)
lineScanBaseline = [27, 44]; % (ms), baseline for F_0 in linescans, avoid starting from 0 to prevent possible contamination from shutter artifact
lineScanROIDetectDuringBaseline = 1; % detect linescan ROI only during baseline window specified above (0: no, 1: yes), in order to prevent possible errors from uncaging artifact
lineScanDownsamplingFactor = 1; % downsampling factor for fluorescence signals, for the dF/F to be robust to noise
%  NB. for best performance in ROI detection, use minimal (or zero) smoothing,
%   high threshold for ROI, and low (in terms of absolute value) threshold for background;
%   +/- 1 pixel, top 2% (roi), bottom 50% (background) seems best (2022-02-03)
lineScanROISmoothing = 1; % will average over this many points before and after (not total) while detecting ROI to be robust from noise - obsolete with single ROI
%lineScanROIThreshold = 2.32635; % (s.d.); z-score for 1st percentile
lineScanROIThreshold = 2.05375; % (s.d.); z-score for 2nd percentile
%lineScanROIThreshold = 1.64485; % (s.d.); z-score for 5th percentile
%lineScanROIThreshold = 1.28125; % (s.d.); z-score for 10th percentile
%lineScanROIThreshold = 0.67449; % (s.d.); z-score for 1st quartile
%lineScanROIThreshold = 0.43991; % (s.d.); z-score for 33rd percentile
lineScanBackgroundThreshold = -0; % (s.d.); z-score for 2nd quartile
%lineScanBackgroundThreshold = -0.43991; % (s.d.); z-score for 67th percentile
%lineScanBackgroundThreshold = -0.67449; % (s.d.); z-score for 3rd quartile
%lineScanBackgroundThreshold = -1.28125; % (s.d.); z-score for 90th percentile
%lineScanBackgroundThreshold = -2.05375; % (s.d.); z-score for 98th percentile
lineScanColorMapRange = 1; % saturate displayed intensity for signals above this percentage of maximum
offloadMarkPointsMetadata = 0; % delete markpoints metadata after retrieving point indices to save space (0: no, 1: yes)

% PVBS hardware error correction
%  PVBS GPIO box (DAC) can quite unbelievably have bleedthrough across channels, 
%  which has to be corrected if present; otherwise, it could lead to introducing 
%  "phantom" DC offset error in data...
%  - DO NOT use if recordings DO have intentional baseline DC injection at the beginning!
%  - DO NOT confuse this with having an incorrect bias setting on the amplifier! 
%    (e.g. RV2 for MC700B, or i_G for BVC700A)
pvbsCurrentCorrectionFlag = 0; % set to 1 to correct, 0 to leave as is
pvbsCurrentCorrectionDataPoints = 50; % this many points at the beginning will be used for baseline correction

% data downsampling
boxcarLength1 = 0; % boxcar length for Ch. 1 (e.g. V); 0 to disable by default
boxcarLength2 = 4; % boxcar length for Ch. 2 (e.g. dF/F); 0 to disable by default
besselFreq1 = 0; % (kHz); Bessel filter cutoff frequency for Ch. 1; 0 to disable by default
besselFreq2 = 1; % (kHz); Bessel filter cutoff frequency for Ch. 2; 0 to disable by default
besselOrder1 = 4; % reverse Bessel polynomial order for Ch. 1
besselOrder2 = 4; % reverse Bessel polynomial order for Ch. 2

% artifact removal
artifactLength = 2; % (ms)
artifactStart = 50; % (ms)
artifactCount = 1;
artifactFreq = 10; % (Hz)

% sweep segmentation
segmentationLength = 100; % segment length (ms)
segmentationOffset = 0; % segmentation initial offset (ms)
segmentationTruncate = 1; % truncate remainder (0: no, 1: yes)
segmentationCount = 0; % keep only this many segments and discard the rest (0 to disable)

% analysis - intrinsic properties (to be backwards compatible with ancient code)
%  data format
intrinsicPropertiesAnalysis = struct();
intrinsicPropertiesAnalysisInput = [pvbsVoltageScalingFactor, pvbsCurrentScalingFactor, pvbsCurrentCorrectionFlag];
intrinsicPropertiesAnalysis = setDefaultParamsIntrinsic(intrinsicPropertiesAnalysis, intrinsicPropertiesAnalysisInput);

% sweep grouping
autoGroup = 'Automatic'; % somewhat arbitrary but whatever - currently set to MarkPoints for LineScan and VoltageOutput for TSeries, see loadExpMain()

% default directory
dirSaveDefault = cd;
dirLoadDefault = cd;

% save
defaultParams.pvbsVoltageScalingFactor = pvbsVoltageScalingFactor;
defaultParams.pvbsCurrentScalingFactor = pvbsCurrentScalingFactor;
defaultParams.timeColumn = timeColumn;
defaultParams.pvbsVoltageColumn = pvbsVoltageColumn;
defaultParams.pvbsCurrentColumn = pvbsCurrentColumn;
defaultParams.csvOffsetRow = csvOffsetRow;
defaultParams.csvOffsetColumn = csvOffsetColumn;
defaultParams.csvColumnsAsSweeps = csvColumnsAsSweeps;
defaultParams.analysisColumn = analysisColumn;
defaultParams.peakDirection1 = peakDirection1;
defaultParams.peakDirection2 = peakDirection2;
defaultParams.useMedian = useMedian;
defaultParams.riseDecay = riseDecay;
defaultParams.autoGroup = autoGroup;
defaultParams.lineScanChannel = lineScanChannel;
defaultParams.lineScanBaseline = lineScanBaseline;
defaultParams.lineScanROIDetectDuringBaseline = lineScanROIDetectDuringBaseline;
defaultParams.lineScanDownsamplingFactor = lineScanDownsamplingFactor;
defaultParams.lineScanROISmoothing = lineScanROISmoothing;
defaultParams.lineScanROIThreshold = lineScanROIThreshold;
defaultParams.lineScanBackgroundThreshold = lineScanBackgroundThreshold;
defaultParams.lineScanColorMapRange = lineScanColorMapRange;
defaultParams.offloadMarkPointsMetadata = offloadMarkPointsMetadata;
defaultParams.pvbsCurrentCorrectionFlag = pvbsCurrentCorrectionFlag;
defaultParams.pvbsCurrentCorrectionDataPoints = pvbsCurrentCorrectionDataPoints;
defaultParams.boxcarLength1 = boxcarLength1;
defaultParams.boxcarLength2 = boxcarLength2;
defaultParams.besselFreq1 = besselFreq1;
defaultParams.besselFreq2 = besselFreq2;
defaultParams.besselOrder1 = besselOrder1;
defaultParams.besselOrder2 = besselOrder2;
defaultParams.artifactLength = artifactLength;
defaultParams.artifactStart = artifactStart;
defaultParams.artifactCount = artifactCount;
defaultParams.artifactFreq = artifactFreq;
defaultParams.segmentationLength = segmentationLength;
defaultParams.segmentationOffset = segmentationOffset;
defaultParams.segmentationTruncate = segmentationTruncate;
defaultParams.segmentationCount = segmentationCount;
defaultParams.intrinsicPropertiesAnalysis = intrinsicPropertiesAnalysis;

%h.params.actualParams = actualParams;
guidata(win, h);

end


function intrinsicPropertiesAnalysis = setDefaultParamsIntrinsic(intrinsicPropertiesAnalysis, intrinsicPropertiesAnalysisInput)
% separated for access from elsewhere

% legacy
pvbsVoltageScalingFactor = intrinsicPropertiesAnalysisInput(1);
pvbsCurrentScalingFactor = intrinsicPropertiesAnalysisInput(2);
pvbsCurrentCorrectionFlag = intrinsicPropertiesAnalysisInput(3);

% actual stuff
intrinsicPropertiesAnalysis.v_rec_gain = pvbsVoltageScalingFactor; % gain for V, defined above
intrinsicPropertiesAnalysis.i_cmd_gain = pvbsCurrentScalingFactor; % gain for i, defined above
intrinsicPropertiesAnalysis.voltage_signal_channel = 1; % V_m channel, from PVBS (NB. defined differently above as .csv comlumn index)
intrinsicPropertiesAnalysis.data_length_unit = 100; % (ms); truncate data to a nice multiple of this (e.g. 17919 ms -> 17900 ms)
intrinsicPropertiesAnalysis.data_voltage_samplingrate = 20; % (kHz); sampling rate (e.g. 20 kHz = 20 points/ms)
intrinsicPropertiesAnalysis.data_voltage_interval = 1/intrinsicPropertiesAnalysis.data_voltage_samplingrate; % (ms); data point interval (e.g. 20 kHz = 20 points/ms)
intrinsicPropertiesAnalysis.i_bsln_correction = pvbsCurrentCorrectionFlag; % GPIO error correction, defined above
intrinsicPropertiesAnalysis.i_bsln_correction_window = 10; % GPIO error correction window (ms) (NB. defined differently above as datapoints)
%  long protocol
%%{
%  segmentation (episodic transformation)
intrinsicPropertiesAnalysis.data_segmentation_cutoff_first = 0; % (ms); discard this length of data at the beginning
intrinsicPropertiesAnalysis.data_segment_length = 5000; % Sweep duration (ms), synonymous with inter-sweep interval because of absolutely stupid gap-free PVBS
%  detection window; for more than 2 windows, manually set them as n*3 arrays (start, end, direction) and pass them onto functions
intrinsicPropertiesAnalysis.window_baseline_start = 0; % (ms); baseline start - this is not for main analysis window, but for intrinsic properties!
intrinsicPropertiesAnalysis.window_baseline_end = 2000; % (ms); baseline end
intrinsicPropertiesAnalysis.window_n = 2; % number of detection windows (1 or 2)
intrinsicPropertiesAnalysis.window_1_start = 2000; % (ms); detection window 1 start
intrinsicPropertiesAnalysis.window_1_end = 2250; % (ms); detection window 1 end
intrinsicPropertiesAnalysis.window_1_direction = 0; % (ms); detection window 1 direction (-1: negative, 0: either, 1: positive; e.g. for peak detection)
intrinsicPropertiesAnalysis.window_2_start = 2750; % (ms); analysis window 2 start
intrinsicPropertiesAnalysis.window_2_end = 3000; % (ms); analysis window 2 end
intrinsicPropertiesAnalysis.window_2_direction = 0; % (ms); analysis window 2 direction (-1: negative, 0: either, 1: positive; e.g. for peak detection)
%}
%  short protocol
%{
%  segmentation (episodic transformation)
intrinsicPropertiesAnalysis.data_segmentation_cutoff_first = 0; % (ms); discard this length of data at the beginning
intrinsicPropertiesAnalysis.data_segment_length = 1000; % Sweep duration (ms), synonymous with inter-sweep interval because of absolutely stupid gap-free PVBS
%  detection window; for more than 2 windows, manually set them as n*3 arrays (start, end, direction) and pass them onto functions
intrinsicPropertiesAnalysis.window_baseline_start = 0; % (ms); baseline start - this is not for main analysis window, but for intrinsic properties!
intrinsicPropertiesAnalysis.window_baseline_end = 250; % (ms); baseline end
intrinsicPropertiesAnalysis.window_n = 2; % number of detection windows (1 or 2)
intrinsicPropertiesAnalysis.window_1_start = 250; % (ms); detection window 1 start
intrinsicPropertiesAnalysis.window_1_end = 350; % (ms); detection window 1 end
intrinsicPropertiesAnalysis.window_1_direction = 0; % (ms); detection window 1 direction (-1: negative, 0: either, 1: positive; e.g. for peak detection)
intrinsicPropertiesAnalysis.window_2_start = 400; % (ms); analysis window 2 start
intrinsicPropertiesAnalysis.window_2_end = 500; % (ms); analysis window 2 end
intrinsicPropertiesAnalysis.window_2_direction = 0; % (ms); analysis window 2 direction (-1: negative, 0: either, 1: positive; e.g. for peak detection)
%}
%  display options
intrinsicPropertiesAnalysis.stepStart = intrinsicPropertiesAnalysis.window_1_start; % defined above
intrinsicPropertiesAnalysis.stepEnd = intrinsicPropertiesAnalysis.window_2_end; % defined above
intrinsicPropertiesAnalysis.stepLength = intrinsicPropertiesAnalysis.stepEnd - intrinsicPropertiesAnalysis.stepStart;
intrinsicPropertiesAnalysis.displayMargin = 0.25; % relative to step length
intrinsicPropertiesAnalysis.displayStart = intrinsicPropertiesAnalysis.stepStart - intrinsicPropertiesAnalysis.displayMargin * intrinsicPropertiesAnalysis.stepLength;
intrinsicPropertiesAnalysis.displayEnd = intrinsicPropertiesAnalysis.stepEnd + intrinsicPropertiesAnalysis.displayMargin * intrinsicPropertiesAnalysis.stepLength;

end


function defaultSettingsCallback(src, ~)
% default settings

% load
h = guidata(src);
win1 = src.Parent;
srcButton = src;
set(srcButton, 'enable', 'off');

% load parameters
analysisParameters = h.params.actualParams;
analysisParametersDefault = h.params.defaultParams;

% options
optionsWin = figure('Name', 'Import Settings', 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.2, 0.25, 0.45, 0.6], 'resize', 'off', 'DeleteFcn', @winClosed); % use CloseRequestFcn?
oWin.t101 = uicontrol('Parent', optionsWin, 'Style', 'text', 'fontweight', 'bold', 'string', 'DAC gain', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.925, 0.9, 0.04]);
oWin.t102 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(Cf.  Amplifier output  &  "Acquisition Channel Properties" in PV "Voltage Recording" window)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.125, 0.925, 0.8, 0.04]);
oWin.t111 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Scaling factor (V)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.88, 0.4, 0.04]);
oWin.t112 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.pvbsVoltageScalingFactor), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.8875, 0.125, 0.04], 'callback', @updateParams);
oWin.t113 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(mV/V)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.88, 0.1, 0.04]);
oWin.t121 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Scaling factor (i)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.88, 0.4, 0.04]);
oWin.t122 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.pvbsCurrentScalingFactor), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.8875, 0.125, 0.04], 'callback', @updateParams);
oWin.t123 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(pA/V)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.88, 0.1, 0.04]);

oWin.t201 = uicontrol('Parent', optionsWin, 'Style', 'text', 'fontweight', 'bold', 'string', '.CSV import', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.825, 0.9, 0.04]);
oWin.t202 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(NB.  Settings overridden when directly*  importing .csv (instead of via PV metadata .xml),  if*  "Columns represent sweeps" is checked)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.125, 0.825, 0.85, 0.04]);
oWin.t211 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Row offset:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.78, 0.4, 0.04]);
oWin.t212 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.csvOffsetRow), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.7875, 0.125, 0.04], 'callback', @updateParams);
oWin.t213 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.78, 0.1, 0.04]);
oWin.t221 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Column offset:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.78, 0.4, 0.04]);
oWin.t222 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.csvOffsetColumn), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.7875, 0.125, 0.04], 'callback', @updateParams);
oWin.t223 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.78, 0.1, 0.04]);
oWin.t231 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Timestamp (t) at column:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.73, 0.4, 0.04]);
oWin.t232 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'enable', 'off', 'string', num2str(analysisParameters.timeColumn), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.7375, 0.125, 0.04], 'callback', @updateParams);
oWin.t233 = uicontrol('Parent', optionsWin, 'Style', 'checkbox', 'enable', 'off', 'string', '(available)', 'value', logical(analysisParameters.timeColumn), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.7375, 0.4, 0.04], 'callback', @updateParams);
oWin.t241 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Voltage (V) at column:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.68, 0.4, 0.04]);
oWin.t242 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.pvbsVoltageColumn), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.6875, 0.125, 0.04], 'callback', @updateParams);
oWin.t243 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.68, 0.1, 0.04]);
oWin.t251 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Current (i) at column:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.68, 0.4, 0.04]);
oWin.t252 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.pvbsCurrentColumn), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.6875, 0.125, 0.04], 'callback', @updateParams);
oWin.t253 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.68, 0.1, 0.04]);
oWin.t261 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Columns represent sweeps:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.73, 0.4, 0.04]);
oWin.t262 = uicontrol('Parent', optionsWin, 'Style', 'checkbox', 'string', '(for direct import only)', 'value', logical(analysisParameters.csvColumnsAsSweeps), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.7375, 0.2, 0.04], 'callback', @updateParams);
oWin.t263 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.73, 0.1, 0.04]);

oWin.t301 = uicontrol('Parent', optionsWin, 'Style', 'text', 'fontweight', 'bold', 'string', 'Linescan analysis', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.625, 0.9, 0.04]);
oWin.t311 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'dF/F channel:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.58, 0.4, 0.04]);
oWin.t312 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.lineScanChannel), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.5875, 0.125, 0.04], 'callback', @updateParams);
oWin.t313 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.58, 0.1, 0.04]);
oWin.t321 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Baseline start:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.53, 0.4, 0.04]);
oWin.t322 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.lineScanBaseline(1)), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.5375, 0.125, 0.04], 'callback', @updateParams);
oWin.t323 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.53, 0.1, 0.04]);
oWin.t331 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Baseline end:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.53, 0.4, 0.04]);
oWin.t332 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.lineScanBaseline(2)), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.5375, 0.125, 0.04], 'callback', @updateParams);
oWin.t333 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.53, 0.1, 0.04]);
oWin.t341 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'ROI threshold:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.48, 0.4, 0.04]);
oWin.t342 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.lineScanROIThreshold), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.4875, 0.125, 0.04], 'callback', @updateParams);
oWin.t343 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(sd)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.48, 0.1, 0.04]);
oWin.t351 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Background threshold:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.48, 0.4, 0.04]);
oWin.t352 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.lineScanBackgroundThreshold), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.4875, 0.125, 0.04], 'callback', @updateParams);
oWin.t353 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(sd)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.48, 0.1, 0.04]);
oWin.t361 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'ROI smoothing:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.43, 0.4, 0.04]);
oWin.t362 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.lineScanROISmoothing), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.4375, 0.125, 0.04], 'callback', @updateParams);
oWin.t363 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(points)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.43, 0.1, 0.04]);
oWin.t371 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Detect ROI during baseline:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.43, 0.4, 0.04]);
oWin.t372 = uicontrol('Parent', optionsWin, 'Style', 'checkbox', 'value', logical(analysisParameters.lineScanROIDetectDuringBaseline), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.4375, 0.125, 0.04], 'callback', @updateParams);
oWin.t373 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.43, 0.1, 0.04]);

oWin.t401 = uicontrol('Parent', optionsWin, 'Style', 'text', 'fontweight', 'bold', 'string', 'Postprocessing', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.375, 0.9, 0.04]);
oWin.t411 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'S1 Boxcar order:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.33, 0.4, 0.04]);
oWin.t412 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.boxcarLength1), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.3375, 0.125, 0.04], 'callback', @updateParams);
oWin.t413 = uicontrol('Parent', optionsWin, 'Style', 'checkbox', 'value', logical(analysisParameters.boxcarLength1), 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.33, 0.1, 0.04], 'callback', @updateParams);
oWin.t421 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'S2 Boxcar order:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.33, 0.4, 0.04]);
oWin.t422 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.boxcarLength2), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.3375, 0.125, 0.04], 'callback', @updateParams);
oWin.t423 = uicontrol('Parent', optionsWin, 'Style', 'checkbox', 'value', logical(analysisParameters.boxcarLength2), 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.33, 0.1, 0.04], 'callback', @updateParams);
oWin.t431 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'S1 Bessel order:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.28, 0.4, 0.04]);
oWin.t432 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'enable', 'off', 'string', num2str(analysisParameters.besselOrder1), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.2875, 0.125, 0.04], 'callback', @updateParams);
oWin.t433 = uicontrol('Parent', optionsWin, 'Style', 'checkbox', 'value', logical(analysisParameters.besselFreq1), 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.28, 0.1, 0.04], 'callback', @updateParams);
oWin.t441 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'S2 Bessel order:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.28, 0.4, 0.04]);
oWin.t442 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'enable', 'off', 'string', num2str(analysisParameters.besselOrder2), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.2875, 0.125, 0.04], 'callback', @updateParams);
oWin.t443 = uicontrol('Parent', optionsWin, 'Style', 'checkbox', 'value', logical(analysisParameters.besselFreq2), 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.28, 0.1, 0.04], 'callback', @updateParams);
oWin.t451 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'S1 Bessel frequency:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.23, 0.4, 0.04]);
oWin.t452 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.besselFreq1), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.2375, 0.125, 0.04], 'callback', @updateParams);
oWin.t453 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(kHz)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.23, 0.1, 0.04]);
oWin.t461 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'S2 Bessel frequency:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.23, 0.4, 0.04]);
oWin.t462 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.besselFreq2), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.2375, 0.125, 0.04], 'callback', @updateParams);
oWin.t463 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(kHz)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.23, 0.1, 0.04]);

oWin.t501 = uicontrol('Parent', optionsWin, 'Style', 'text', 'fontweight', 'bold', 'string', 'Sweep grouping', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.175, 0.9, 0.04]);
oWin.t511 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Group by metadata:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.13, 0.4, 0.04]);
oWin.t512 = uicontrol('Parent', optionsWin, 'Style', 'popupmenu', 'string', {'Disable', 'Automatic', 'MarkPoints', 'VoltageOutput'}, 'value', 2, 'enable', 'off', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.1375, 0.2, 0.04], 'callback', @updateParams);
oWin.t513 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(MarkPoint for LineScan, VoltageOutput for TSeries)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.475, 0.13, 0.4, 0.04]);

oWin.resetButton = uicontrol('Parent', optionsWin, 'Style', 'pushbutton', 'string', 'Reset to defaults', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.54, 0.05, 0.2, 0.06], 'callback', @resetParams, 'interruptible', 'off');
oWin.saveButton = uicontrol('Parent', optionsWin, 'Style', 'pushbutton', 'string', 'Save', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.05, 0.2, 0.06], 'callback', @saveParams, 'interruptible', 'off');

t112 = str2num(oWin.t112.String);
t122 = str2num(oWin.t122.String);
t212 = str2num(oWin.t212.String);
t222 = str2num(oWin.t222.String);
t232 = str2num(oWin.t232.String);
t233 = oWin.t233.Value;
t242 = str2num(oWin.t242.String);
t252 = str2num(oWin.t252.String);
t262 = oWin.t262.Value;
t312 = str2num(oWin.t312.String);
t322 = str2num(oWin.t322.String);
t332 = str2num(oWin.t332.String);
t342 = str2num(oWin.t342.String);
t352 = str2num(oWin.t352.String);
t362 = str2num(oWin.t362.String);
t372 = oWin.t372.Value;
t412 = str2num(oWin.t412.String);
t413 = oWin.t413.Value;
t422 = str2num(oWin.t422.String);
t423 = oWin.t423.Value;
t432 = str2num(oWin.t432.String);
t433 = oWin.t433.Value;
t442 = str2num(oWin.t442.String);
t443 = oWin.t443.Value;
t452 = str2num(oWin.t452.String);
t462 = str2num(oWin.t462.String);
%t512 = oWin.t512.String{oWin.t512.Value};

    function winClosed(src, ~)
        set(srcButton, 'enable', 'on');
        %guidata(srcButton, h); % don't save when closed without using the save button
    end

    function updateParams(src, ~)
        t112 = str2num(oWin.t112.String);
        t122 = str2num(oWin.t122.String);
        t212 = str2num(oWin.t212.String);
        t222 = str2num(oWin.t222.String);
        t232 = str2num(oWin.t232.String);
         t233 = oWin.t233.Value;
        t242 = str2num(oWin.t242.String);
        t252 = str2num(oWin.t252.String);
         t262 = oWin.t262.Value;
        if t262
            % overrides now moved within loadCSV()
            %{
            t112 = 1; % default to scaling factor = 1 for V
            t122 = 1; % default to scaling factor = 1 for i
            t212 = 0; % default to no row offset
            t222 = 0; % default to no column offset
            t252 = 0; % default to reading columns as voltage
            oWin.t112.String = num2str(t112);
            oWin.t122.String = num2str(t122);
            oWin.t212.String = num2str(t212);
            oWin.t222.String = num2str(t222);
            oWin.t252.String = num2str(t252);
            %}
        else
        end
        t312 = str2num(oWin.t312.String);
        t322 = str2num(oWin.t322.String);
        t332 = str2num(oWin.t332.String);
        t342 = str2num(oWin.t342.String);
        t352 = str2num(oWin.t352.String);
        t362 = str2num(oWin.t362.String);
         t372 = oWin.t372.Value;
        t412 = str2num(oWin.t412.String);
         t413 = oWin.t413.Value;
        t422 = str2num(oWin.t422.String);
         t423 = oWin.t423.Value;
        t432 = str2num(oWin.t432.String);
         t433 = oWin.t433.Value;
        t442 = str2num(oWin.t442.String);
         t443 = oWin.t443.Value;
        t452 = str2num(oWin.t452.String);
        t462 = str2num(oWin.t462.String);
        %t512 = oWin.t512.String{oWin.t512.Value}; %%% fixlater
        
        if ~logical(t432)
            t433 = 0;
            oWin.t433.Value = t433;
        end
        if ~logical(t442)
            t443 = 0;
            oWin.t443.Value = t443;
        end
    end

    function resetParams(src, ~)
        analysisParametersIntrinsic = analysisParameters.intrinsicPropertiesAnalysis; % salvage this
        analysisParameters = analysisParametersDefault;
        analysisParameters.intrinsicPropertiesAnalysis = analysisParametersIntrinsic;
        
        oWin.t112.String = num2str(analysisParameters.pvbsVoltageScalingFactor);
        oWin.t122.String = num2str(analysisParameters.pvbsCurrentScalingFactor);
        oWin.t212.String = num2str(analysisParameters.csvOffsetRow);
        oWin.t222.String = num2str(analysisParameters.csvOffsetColumn);
        oWin.t232.String = num2str(analysisParameters.timeColumn);
         oWin.t233.Value = logical(analysisParameters.timeColumn);
        oWin.t242.String = num2str(analysisParameters.pvbsVoltageColumn);
        oWin.t252.String = num2str(analysisParameters.pvbsCurrentColumn);
         oWin.t262.Value = logical(analysisParameters.csvColumnsAsSweeps);
        oWin.t312.String = num2str(analysisParameters.lineScanChannel);
        oWin.t322.String = num2str(analysisParameters.lineScanBaseline(1));
        oWin.t332.String = num2str(analysisParameters.lineScanBaseline(2));
        oWin.t342.String = num2str(analysisParameters.lineScanROIThreshold);
        oWin.t352.String = num2str(analysisParameters.lineScanBackgroundThreshold);
        oWin.t362.String = num2str(analysisParameters.lineScanROISmoothing);
         oWin.t372.Value = logical(analysisParameters.lineScanROIDetectDuringBaseline);
        oWin.t412.String = num2str(analysisParameters.boxcarLength1);
         oWin.t413.Value = logical(analysisParameters.boxcarLength1);
        oWin.t422.String = num2str(analysisParameters.boxcarLength2);
         oWin.t423.Value = logical(analysisParameters.boxcarLength2);
        oWin.t432.String = num2str(analysisParameters.besselOrder1);
         oWin.t433.Value = logical(analysisParameters.besselFreq1);
        oWin.t442.String = num2str(analysisParameters.besselOrder2);
         oWin.t443.Value = logical(analysisParameters.besselFreq2);
        oWin.t452.String = num2str(analysisParameters.besselFreq1);
        oWin.t462.String = num2str(analysisParameters.besselFreq2);
        %oWin.t512.Value = fixlater; %%% fixlater
        
        t112 = str2num(oWin.t112.String);
        t122 = str2num(oWin.t122.String);
        t212 = str2num(oWin.t212.String);
        t222 = str2num(oWin.t222.String);
        t232 = str2num(oWin.t232.String);
         t233 = oWin.t233.Value;
        t242 = str2num(oWin.t242.String);
        t252 = str2num(oWin.t252.String);
         t262 = oWin.t262.Value;
        t312 = str2num(oWin.t312.String);
        t322 = str2num(oWin.t322.String);
        t332 = str2num(oWin.t332.String);
        t342 = str2num(oWin.t342.String);
        t352 = str2num(oWin.t352.String);
        t362 = str2num(oWin.t362.String);
         t372 = oWin.t372.Value;
        t412 = str2num(oWin.t412.String);
         t413 = oWin.t413.Value;
        t422 = str2num(oWin.t422.String);
         t423 = oWin.t423.Value;
        t432 = str2num(oWin.t432.String);
         t433 = oWin.t433.Value;
        t442 = str2num(oWin.t442.String);
         t443 = oWin.t443.Value;
        t452 = str2num(oWin.t452.String);
        t462 = str2num(oWin.t462.String);
        %t512 = oWin.t512.String{oWin.t512.Value};
        
        %guidata(win1, h);
        %close(optionsWin);
        %set(srcButton, 'enable', 'on');
    end

    function saveParams(src, ~)

        analysisParameters.pvbsVoltageScalingFactor = t112;
        analysisParameters.pvbsCurrentScalingFactor = t122;
        analysisParameters.csvOffsetRow = t212;
        analysisParameters.csvOffsetColumn = t222;
        if t233
            analysisParameters.timeColumn = t232;
        else
            analysisParameters.timeColumn = 0;
        end
        analysisParameters.pvbsVoltageColumn = t242;
        analysisParameters.pvbsCurrentColumn = t252;
        analysisParameters.csvColumnsAsSweeps = t262;
        if t262
            % overrides now moved within loadCSV()
            %{
            analysisParameters.pvbsVoltageScalingFactor = 1; % default to scaling factor = 1 for V
            analysisParameters.pvbsCurrentScalingFactor = 1; % default to scaling factor = 1 for i
            analysisParameters.csvOffsetRow = 0; % default to no row offset
            analysisParameters.csvOffsetColumn = 0; % default to no column offset
            analysisParameters.pvbsCurrentColumn = 0; % default to reading columns as voltage
            %}
        else
        end
        analysisParameters.lineScanChannel = t312;
        analysisParameters.lineScanBaseline(1) = t322;
        analysisParameters.lineScanBaseline(2) = t332;
        analysisParameters.lineScanROIThreshold = t342;
        analysisParameters.lineScanBackgroundThreshold = t352;
        analysisParameters.lineScanROISmoothing = t362;
         analysisParameters.lineScanROIDetectDuringBaseline = t372;
        if t413
            analysisParameters.boxcarLength1 = t412;
        else
            analysisParameters.boxcarLength1 = 0;
        end
        if t423
            analysisParameters.boxcarLength2 = t422;
        else
            analysisParameters.boxcarLength2 = 0;
        end
        analysisParameters.besselOrder1 = t432;
        analysisParameters.besselOrder2 = t442;
        if t433 % NB. this is for t452, not t432
            analysisParameters.besselFreq1 = t452;
        else
            analysisParameters.besselFreq1 = 0;
        end
        if t443 % NB. this is for t462, not t442
            analysisParameters.besselFreq2 = t462;
        else
            analysisParameters.besselFreq2 = 0;
        end
        %analysisParameters.autoGroup = t512; %%% fixlater
        
        h.params.actualParams = analysisParameters;
        
        guidata(win1, h);
        close(optionsWin);
        set(srcButton, 'enable', 'on');
    end

end


%% Save/Load Experiments 


function saveMat(src, ~)
% export dataset as .mat

% start stopwatch
tic;

% default save parameters - could go into settings
defaultSaveFilePrefix = 'pvbs_';
defaultSavePath = cd;
defaultSavedVariableName = 'h';

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    error('Error: No experiment file present');
end

% shed ui elements
hNew.exp = h.exp;
hNew.results = h.results;
hNew.analysis = h.analysis;
hNew.params = h.params;
%  ... except
hNew.ui.cellList = h.ui.cellList;

% overwrite, just to keep the variable name
h = hNew;

% set save path and file name
todayYY = num2str(year(datetime));
todayYY = todayYY(end-1:end);
todayMM = sprintf('%02.0f', month(datetime));
todayDD = sprintf('%02.0f', day(datetime));
saveNameDate = [defaultSaveFilePrefix, todayYY, todayMM, todayDD];
saveNameCell = h.exp.fileName{1}(1:end-4);
saveNameCell = [defaultSaveFilePrefix, saveNameCell];
if length(h.exp.fileName) > 1 % more than 1 experiments in dataset
    expCount = length(h.exp.fileName);
    expCount = num2str(expCount);
    saveNameCellSuffix = ['_N', expCount];
    saveNameCell = [saveNameCell, saveNameCellSuffix];
end
saveName = [saveNameCell, '.mat'];
savePath = [defaultSavePath, '\']; % appending backslash for proper formatting


% prompt, since it could take some time
fprintf('Saving dataset... ');

% save
warning('off', 'all');
[actualName, actualPath, isSaved] = uisaveX(defaultSavedVariableName, [savePath, saveName]);
warning('on', 'all');

% print results
if isSaved
    elapsedTime = toc;
    fprintf('\nSaved as: %s%s\n (elapsed time: %.2f s)\n\n', actualPath, actualName, elapsedTime);
else
    elapsedTime = toc;
    fprintf('canceled.\n\n');
end

end


function saveGUI(src, ~)
% save everything as .mat - will create a large file because the figure itself is saved

% start stopwatch
tic;

% default save parameters - could go into settings
defaultSaveFilePrefix = 'pvbs_debug_';
defaultSavePath = cd;
defaultSavedVariableName = 'h';

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    error('Error: No experiment file present');
end

% set save path and file name
todayYY = num2str(year(datetime));
todayYY = todayYY(end-1:end);
todayMM = sprintf('%02.0f', month(datetime));
todayDD = sprintf('%02.0f', day(datetime));
saveNameDate = [defaultSaveFilePrefix, todayYY, todayMM, todayDD];
saveNameCell = h.exp.fileName{1}(1:end-4);
saveNameCell = [defaultSaveFilePrefix, saveNameCell];
if length(h.exp.fileName) > 1 % more than 1 experiments in dataset
    expCount = length(h.exp.fileName);
    expCount = num2str(expCount);
    saveNameCellSuffix = ['_N', expCount];
    saveNameCell = [saveNameCell, saveNameCellSuffix];
end
saveName = [saveNameCell, '.mat'];
savePath = [defaultSavePath, '\']; % appending backslash for proper formatting


% prompt, since it could take some time
fprintf('Saving GUI (debug mode)... ');

% save
warning('off', 'all');
[actualName, actualPath, isSaved] = uisaveX(defaultSavedVariableName, [savePath, saveName]);
warning('on', 'all');

% print results
if isSaved
    elapsedTime = toc;
    fprintf('\nSaved as: %s%s\n (elapsed time: %.2f s)\n\n', actualPath, actualName, elapsedTime);
else
    elapsedTime = toc;
    fprintf('canceled.\n\n');
end

end


function loadMat(src, ~)
% import dataset from previously exported .mat

% start stopwatch
tic;

% load
h = guidata(src);
win = src.Parent;

% import cell data from a previously saved .mat file
fprintf('Loading... ');
[fName, fPath] = uigetfile({'*.mat', 'PVBS dataset'});
if ~isempty(fName)
    fprintf('(%s%s) ', fPath, fName);
end

% check if a file was loaded
if fName ~= 0
    dataset = load([fPath, fName]);
    hNew = dataset.h; % "h" will be the name of the top level struct
    h.exp = hNew.exp;
    h.results = hNew.results;
    h.analysis = hNew.analysis;
    h.params = hNew.params;
    h.ui.cellList = hNew.ui.cellList;
    h.ui.cellListDisplay.String = h.ui.cellList;
    h.ui.cellListDisplay.Value = 1;
    h = cellListClick2(h, 1); % select 1st entry by default
else
    fprintf('\ncanceled.\n\n');
    return
end

% ugh...
try % ... to display results
    
    resultsTempGrp = h.results{1}.VRec.groupResults;
    resultsTemp2Grp = h.results{1}.dff.groupResults;
    
    %  plot 1: by default, display Vm, win 1, peak, by group, for current experiment
    targetPlot = h.ui.analysisPlot1; % plot 1
    winToPlot = 1; % analysis window 1
    peakDirToPlot = h.params.actualParams.peakDirection1;
    switch peakDirToPlot % converting to column indices for old code
        case -1 % negative
            peakDirToPlot = 1;
        case 0 % absolute
            peakDirToPlot = 2;
        case 1 % positive
            peakDirToPlot = 3;
        otherwise
            peakDirToPlot = 2; % default to absolute if not available
    end
    dataX = 1:length(resultsTempGrp.groups); % group number - will plot by groups
    dataY = resultsTempGrp.peak; % grouped results, peak
    dataY = dataY(winToPlot, :); % analysis window 1
    dataYNew = nan(length(dataY), 1); % initialize
    for i = 1:length(dataY)
        dataYi = dataY{i}; % current sweep/group
        if isempty(dataYi)
            dataYi = NaN;
        else
            dataYi = dataYi(peakDirToPlot);
        end
        dataYNew(i) = dataYi; % update
    end
    dataY = dataYNew; % update
    axes(targetPlot);
    hold on;
    color = [0, 0, 0];
    targetPlot = displayResults(targetPlot, dataX, dataY, color);
    set(gca, 'xlim', [0, length(dataX) + 1]); % padding for appearance
    hold off;
    xlabel('Group #');
    ylabel('PSP (mV)');
    %xticks(0:5:10000);
    %%{
    if nanmax(dataY) > 40
        ylim([0, 40.5]);
        %yticks(-1000:10:1000);
    elseif nanmax(dataY) > 10
        ylim([0, nanmax(dataY) + 0.5]);
        %yticks(-1000:5:1000);
    else
        ylim([0, 10.5]);
        %yticks(-1000:2:1000);
    end
    %}
    set(gca, 'xminortick', 'on', 'yminortick', 'on');
    h.ui.analysisPlot1 = targetPlot;
    params.resultsPlot1YRange = targetPlot.YLim;
    h.ui.analysisPlot1Menu1.Value = 2; % voltage
    h.ui.analysisPlot1Menu2.Value = 2; % window 1
    %h.ui.analysisPlot1Menu3.Value = 1; % results - will update later
    h.ui.analysisPlot1Menu4.Value = 3; % by group
    
    %  plot 2: by default, display dF/F, win 2, peak, by group, for current experiment
    try
        targetPlot = h.ui.analysisPlot2; % plot 2
        winToPlot = 2; % analysis window 2
        peakDirToPlot = h.params.actualParams.peakDirection2;
        switch peakDirToPlot % converting to column indices for old code
            case -1 % negative
                peakDirToPlot = 1;
            case 0 % absolute
                peakDirToPlot = 2;
            case 1 % positive
                peakDirToPlot = 3;
            otherwise
                peakDirToPlot = 2; % default to absolute if not available
        end
        dataX = 1:length(resultsTemp2Grp.groups); % group number - will plot by groups
        dataY = resultsTemp2Grp.peak; % grouped results, peak
        dataY = dataY(winToPlot, :); % analysis window 2
        dataYNew = nan(length(dataY), 1); % initialize
        %%%
        %%%%%%%
        % data grouping not fucking working properly - why???
        %%%%%%% the fuck happened here? was it fixed? (2022-05-03)
        for i = 1:length(dataY)
            dataYi = dataY{i}; % current sweep/group
            if isempty(dataYi)
                dataYi = NaN;
            else
                dataYi = dataYi(peakDirToPlot);
            end
            dataYNew(i) = dataYi; % update
        end
        dataY = dataYNew; % update
        axes(targetPlot);
        hold on;
        color = [0, 0.5, 0];
        targetPlot = displayResults(targetPlot, dataX, dataY, color);
        set(gca, 'xlim', [0, length(dataX) + 1]); % padding for appearance
        hold off;
        xlabel('Group #');
        ylabel('dF/F');
        %xticks(0:5:10000);
        %{
    if max(dataY) > 4
        ylim([-0.5, max(dataY) + 0.5]);
        yticks(-10:1:100);
    else
        ylim([-0.5, 4.5]);
        yticks(-10:1:100);
    end
        %}
        set(gca, 'xminortick', 'on', 'yminortick', 'on');
        h.ui.analysisPlot2 = targetPlot;
        params.resultsPlot2YRange = targetPlot.YLim;
        h.ui.analysisPlot2Menu1.Value = 3; % fluorescence
        h.ui.analysisPlot2Menu2.Value = 3; % window 2
        %h.ui.analysisPlot2Menu3.Value = 1; % results - will update later
        h.ui.analysisPlot2Menu4.Value = 3; % by group
    catch ME
        %ME
    end
    
    % which results to plot
    try
        switch h.ui.analysisType1.Value % analysis type for window 1
            case 1 % unselected
            case 2 % peak/area/mean
                switch h.ui.analysisPlot1Menu2.Value % plot 1, window number
                    case 1 % unselected
                        h.ui.analysisPlot1Menu3.String = h.params.analysisPlotMenuList3; % to default
                    case 2 % window 1
                        h.ui.analysisPlot1Menu3.String = h.params.analysisPlotMenuList31;
                        h.ui.analysisPlot1Menu3.Value = 2; % default to peak
                    case 3 % window 2
                        h.ui.analysisPlot1Menu3.String = h.params.analysisPlotMenuList3; % to default
                end
                %%% below not available yet
            case 3 % threshold detection
            case 4 % waveform
        end
    catch ME
    end
    try
        switch h.ui.analysisType2.Value % analysis type for window 2
            case 1 % unselected
            case 2 % peak/area/mean
                switch h.ui.analysisPlot2Menu2.Value % plot 1, window number
                    case 1 % unselected
                        h.ui.analysisPlot2Menu3.String = h.params.analysisPlotMenuList3; % to default
                    case 2 % window 1
                        h.ui.analysisPlot2Menu3.String = h.params.analysisPlotMenuList3; % to default
                    case 3 % window 2
                        h.ui.analysisPlot2Menu3.String = h.params.analysisPlotMenuList31;
                        h.ui.analysisPlot2Menu3.Value = 2; % default to peak
                end
                %%% below not available yet
            case 3 % threshold detection
            case 4 % waveform
        end
    catch ME
    end
    
catch ME
end

% save
guidata(src, h);

% print results
elapsedTime = toc;
fprintf('\nImport complete. (elapsed time: %.2f s) \n\n', elapsedTime);

end


function expFile = loadExp(src, ~)
% load Experiment XML files

% load
h = guidata(src);
experiment = h.exp;
data = experiment.data;
results = h.results;
cellList = h.ui.cellList;
cellListDisplay = h.ui.cellListDisplay;

% prompt, since this could take some time
fprintf('Loading experiment(s)...');

% select experiment metadata .xml (or directory of the same name containing it)
filesToImport = uipickfiles('type', {'*.xml', 'VRec/LScn/tSer directory or metadata (.xml)'; '*.csv' 'VRec data (.csv)'});
tic; % start stopwatch
if iscell(filesToImport)
    if isempty(filesToImport)
        fprintf(' canceled.\n\n');
        return
    else
        for i = 1:length(filesToImport)
            isCSV = 0;
            [fPath, fName, fExt] = fileparts(filesToImport{i});
            if isempty(fExt) % if directory is selected
                fExt = '.xml';
                fPath = [fPath, '\', fName, '\'];
                fName = [fName, fExt];
            elseif strcmp(fExt, '.xml'); % if .xml file is selected
                fPath = [fPath, '\'];
                fName = [fName, fExt];
            elseif strcmp(fExt, '.csv'); % if .csv file is selected
                fPath = [fPath, '\'];
                fName = [fName, fExt];
                isCSV = 1;
            else
                error('Error: Invalid file type');
            end
            fprintf('\n(%d/%d) ', i, length(filesToImport));
            %actualParams = setDefaultParams(src); % load parameters
            %h.params.actualParams = actualParams; % save parameters
            actualParams = h.params.actualParams;
            if isCSV
                h = loadCSV(h, fPath, fName, actualParams);
            else
                h = loadExpMain(h, fPath, fName, actualParams);
            end
        end
    end
elseif filesToImport == 0
    fprintf(' canceled.\n\n');
    return
end

% display first experiment if first time loading files, otherwise last experiment
if h.params.firstRun == 1
    set(h.ui.cellListDisplay, 'value', 1);
    h = displayTrace(h, 1);
    h.params.firstRun = 0;
else
    set(h.ui.cellListDisplay, 'value', length(cellList));
    h = displayTrace(h, length(cellList));
end

% highlight first sweep
%h.ui.groupListDisplay.Value = 1;
h.ui.sweepListDisplay.Value = 1;
h = highlightSweep(h, 1);
set(h.ui.groupSweepText, 'string', 'Sweep 1');

% save
guidata(src, h);
elapsedTime = toc;
fprintf('\n Load complete. (elapsed time: %.2f s)\n\n', elapsedTime);

end


% loadExpMain - find default parameters here
function h = loadExpMain(h, fPath, fName, actualParams)
% load each experiment - VRec, LScn, or tSer (of VRec)

%  because PVBS records data in its own units, data must be scaled appropriately
%  hard-coding here, instead of digging again into insane PVBS metadata
%  below are set for MC700B with Rf = 500 MO and usual gain settings for whole-cell recordings
pvbsVoltageScalingFactor = actualParams.pvbsVoltageScalingFactor; % "100 mV" to mV
pvbsCurrentScalingFactor = actualParams.pvbsCurrentScalingFactor; % "0.1 nA" to pA
timeColumn = actualParams.timeColumn; % csv column for timestamp
pvbsVoltageColumn = actualParams.pvbsVoltageColumn; % csv column to apply voltage scaling (column 1 is timestamp, followed by channels)
pvbsCurrentColumn = actualParams.pvbsCurrentColumn; % csv column to apply current scaling
csvColumnsAsSweeps = actualParams.csvColumnsAsSweeps; % interpret columns as sweeps (default: 0)
csvOffsetRow = actualParams.csvOffsetRow; % row offset while reading csv with csvread() (default: 1)
csvOffsetColumn = actualParams.csvOffsetColumn; % column offset while reading csv with csvread() (default: 0)
lineScanChannel = actualParams.lineScanChannel; % primary channel for calcium imaging signal; e.g. for P4, 1: red, 2: green (primary)
lineScanBaseline = actualParams.lineScanBaseline; % (ms), baseline for F_0 in linescans, avoid starting from 0 to prevent possible contamination from shutter artifact
lineScanROIDetectDuringBaseline = actualParams.lineScanROIDetectDuringBaseline; % detect linescan ROI only during baseline window specified above (0: no, 1: yes), in order to prevent possible errors from uncaging artifact
lineScanDownsamplingFactor = actualParams.lineScanDownsamplingFactor; % downsampling factor for fluorescence signals, for the dF/F to be robust to noise
lineScanROISmoothing = actualParams.lineScanDownsamplingFactor; % will average over this many points (before and after) while detecting ROI to be robust from noise - obsolete with single ROI
lineScanROIThreshold = actualParams.lineScanROIThreshold; % (s.d.); z-score for 1st quartile
lineScanBackgroundThreshold = actualParams.lineScanBackgroundThreshold; % (s.d.); z-score for 67th percentile
offloadMarkPointsMetadata = actualParams.offloadMarkPointsMetadata; % delete markpoints metadata after retrieving point indices to save space (0: no, 1: yes)
% PVBS GPIO box can quite unbelievably also introduce current measurement error
%  via bleedthrough across channels, which has to be corrected if present
%  otherwise, there will be "phantom" DC injection present in data
%  DO NOT use if recordings DO have intentional baseline DC injection at the beginning!
%  DO NOT be confused with having incorrect bias current settings from amplifier!
pvbsCurrentCorrectionFlag = actualParams.pvbsCurrentCorrectionFlag; % set to 1 to correct, 0 to leave as is
pvbsCurrentCorrectionDataPoints = actualParams.pvbsCurrentCorrectionDataPoints; % this many points at the beginning will be used for baseline correction

% load
experiment = h.exp;
data = experiment.data;
results = h.results;
cellList = h.ui.cellList;
cellListDisplay = h.ui.cellListDisplay;

% prompt
fprintf(' %s%s ', fPath, fName);

% load file
sweeps = 1;
metadata = xml2struct_pvbs([fPath, fName]); % load metadata from .xml, using modified xml2struct
try
    sweeps = length(metadata.PVScan.Sequence); % !!! this will need to be changed if the TSeries does not entirely consist of VRecs %%%
catch ME
    sweeps = 1;
end

% fill cells
experiment.metadata{end + 1} = metadata;
experiment.fileName{end + 1} = fName; % just to make file name and path readily accessible
experiment.filePath{end + 1} = fPath;
experiment.sweeps{end + 1} = sweeps;
results{end + 1} = struct;

% check experiment type
if sweeps == 1
    expTypeStr = metadata.PVScan.Sequence.Attributes.type;
else
    expTypeStr = metadata.PVScan.Sequence{1}.Attributes.type;
end
expTypeTSer = 'TSeries Voltage Recording';
expTypeVRec = 'VoltageRecording';
expTypeLScn = 'Linescan'; % note cases and spaces because PV is inconsistent
if strcmp(expTypeStr, expTypeTSer)
    expType = 1; % T-Series
elseif strcmp(expTypeStr, expTypeVRec)
    expType = 2; % VoltageRecording
elseif strcmp(expTypeStr, expTypeLScn)
    expType = 3; % LineScan
else
    expType = 0; % invalid
    fprintf('\nInvalid file type\n');
    return
end

% fill cells within cells (... interlinked)
VOutName = {cell(sweeps, 1)};
VOut = {cell(sweeps, 1)};
VRecMetadata = {cell(sweeps, 1)};
VRec = {cell(sweeps, 1)};
VRecOriginal = {cell(sweeps, 1)};
%lineScanMetadata = {cell(sweeps, 1)};
lineScanFile = {cell(sweeps, 1)};
lineScan = {cell(sweeps, 1)};
lineScanF = {cell(sweeps, 1)};
lineScanDFF = {cell(sweeps, 1)};
lineScanDFFOriginal = {cell(sweeps, 1)};
lineScanCSVFile = {cell(sweeps, 1)};
lineScanCSV = {cell(sweeps, 1)};
lineScanFChannel = {cell(sweeps, 1)};
lineScanROI = {cell(sweeps, 1)};
postprocessing = [];
artifactRemoval = [];
markPointsMetadata = {cell(sweeps, 1)};
markPointsIdx = {cell(sweeps, 1)};
intrinsicProperties = struct(); % struct, not cell
intrinsicPropertiesVRec = {cell(1)};
intrinsicPropertiesVRecMetadata = struct();
intrinsicPropertiesFileName = [];
zStack = {cell(1)}; % only one
zStackFileName = [];
singleScan = {cell(1)}; % only one as representative, since saving all of them will be overwhelming for file size
singleScanFileName = [];
sweepIdx = 1:sweeps; % note that this is an array and not a cell
sweepStr = cell(sweeps, 1);
if sweeps == 1
    sweepStr{1} = '1';
else
    for i = 1:sweeps
        sweepStr{i} = num2str(i);
    end
end
groupIdx = {}; % groupIdx = {cell(sweeps, 1)};
groupStr = {};
notes = {};

postprocessing = [h.params.actualParams.boxcarLength1, h.params.actualParams.besselFreq1, h.params.actualParams.besselOrder1];
postprocessing = [postprocessing; [h.params.actualParams.boxcarLength2, h.params.actualParams.besselFreq2, h.params.actualParams.besselOrder2]];

if sweeps == 1 % this has to be separated because if sweep == 1, "Sequence" (in PVBS metadata) becomes a struct rather than a cell by xml2struct
    VRecMetadata{1} = {metadata.PVScan.Sequence.VoltageRecording.Attributes.configurationFile}; % mind the curly braces on RHS
    VRecFile = metadata.PVScan.Sequence.VoltageRecording.Attributes.dataFile;
    VRecTemp = csvread([fPath, VRecFile], csvOffsetRow, csvOffsetColumn); % offset row by 1 ("time(ms), input 0, input 1"), and column by 0
    % this bizzare step has to be taken, because Prairie
    VRecTemp(:, pvbsVoltageColumn) = VRecTemp(:, pvbsVoltageColumn)*pvbsVoltageScalingFactor;
    VRecTemp(:, pvbsCurrentColumn) = VRecTemp(:, pvbsCurrentColumn)*pvbsCurrentScalingFactor;
    pvbsCurrentCorrectionAmount = nanmean(VRecTemp(1:pvbsCurrentCorrectionDataPoints, pvbsCurrentColumn));
    VRecTemp(:, pvbsCurrentColumn) = VRecTemp(:, pvbsCurrentColumn) - pvbsCurrentCorrectionFlag * pvbsCurrentCorrectionAmount;
    % - end of PVBS correction -
            VRecOriginalTemp = VRecTemp;
            try
                if logical(h.params.actualParams.besselFreq1) % do bessel first before boxcar if applicable, although menu order is backwards - another stupid me doing stupid things
                    besselOrder = h.params.actualParams.besselOrder1;
                    cutoffFreq = h.params.actualParams.besselFreq1;
                    cutoffFreq = cutoffFreq*1000; % converting to Hz from kHz
                    samplingRate = VRecTemp(2, 1) - VRecTemp(1, 1); % sampling interval (ms), since first column is timestamp
                    samplingRate = 1000*(1/samplingRate); % converting to Hz from ms
                    for j = 2:size(VRecTemp, 2) % skip timestamp in column 1
                        VRecTempTemp = VRecTemp(:, j); % skip the timestamp in column 1
                        VRecTempTemp = besselLowpass(VRecTempTemp, besselOrder, cutoffFreq, samplingRate);
                        VRecTemp(:, j) = VRecTempTemp;
                    end
                end
                if logical(h.params.actualParams.boxcarLength1) % do boxcar after bessel, again if applicable
                    boxcarLength = h.params.actualParams.boxcarLength1;
                    dataLengthReduced = floor(size(VRecTemp, 1)/boxcarLength);
                    VRecReducedTemp = nan(dataLengthReduced, size(VRecTemp, 2)); % initializing
                    for j = 1:size(VRecTemp, 2) % NB. timestamp can be treated the same way
                        for k = 1:dataLengthReduced
                            VRecReducedTemp(k, j) = nanmean(VRecTemp(1 + (k-1)*boxcarLength : k*boxcarLength, j));
                        end
                    end
                    VRecTemp = VRecReducedTemp; % simply overwrite if data reduction took place
                end
            catch ME
            end
    VRec{1} = VRecTemp;
    VRecOriginal{1} = VRecOriginalTemp;
    try % some experiments might have been recorded with null VOut
        VOutName{1} = {metadata.PVScan.Sequence.VoltageOutput.Attributes.name};
        VOut{1} = {metadata.PVScan.Sequence.VoltageOutput.Attributes.filename}; % let's just read the file name and not the actual file, since that one's insane
    catch ME
        VOutName{1} = {};
        VOut{1} = {};
    end
    try
        lineScanFileChannelCount = metadata.PVScan.Sequence.Frame.File;
        lineScanFileChannelCount = length(lineScanFileChannelCount);
        if lineScanFileChannelCount == 1
            lineScanFileTemp = metadata.PVScan.Sequence.Frame.File.Attributes.filename;
            lineScanFile{1, 1} = lineScanFileTemp;
            warning('off','all');
            lineScan{1, 1} = read(Tiff([fPath, lineScanFileTemp])); % Tiff() is a built-in function
            warning('on','all');
        else
            for j = 1:lineScanFileChannelCount
                lineScanFileTemp = metadata.PVScan.Sequence.Frame.File{j}.Attributes.filename;
                lineScanFile{j, 1} = lineScanFileTemp;
                warning('off','all');
                lineScan{j, 1} = read(Tiff([fPath, lineScanFileTemp])); % Tiff() is a built-in function
                warning('on','all');
            end
        end
    catch ME
        lineScanFile{:, 1} = {};
        lineScan{:, 1} = {};
    end
    try
        lineScanCSVFile{1} =  metadata.PVScan.Sequence.PVLinescanDefinition.LineScanProfiles.Attributes.DataFile; % LineScanProfile csv will include all applicable channels
        lineScanCSV{1} = csvread([fPath, lineScanFile], csvOffsetRow, csvOffsetColumn); % offset row by 1 ("Ch1 time, Ch1, Ch2 time, Ch2"), and column by 0
    catch ME
        lineScanCSV{1} = {};
    end
    try
        % Applicable if the loaded .xml is a linescan
        %  columns 1, 2, 3, 4 in the astounding PVBS metadata: framePeriod, linesPerFrame, pixelsPerLine, scanLinePeriod
        %  i.e. 1 = 2*3*4, but 2 & 3 can be inferred from data
        %  unit is (s)
        lineScanChannelUsed = lineScanChannel;
        framePeriodIdx = 1;
        framePeriod = metadata.PVScan.Sequence.Frame.PVStateShard.PVStateValue{framePeriodIdx}.Attributes.key;
        if strcmp(framePeriod, 'framePeriod')
            framePeriod = metadata.PVScan.Sequence.Frame.PVStateShard.PVStateValue{framePeriodIdx}.Attributes.value;
            framePeriod = str2num(framePeriod);
        end
        if size(lineScan, 1) < lineScanChannel
            lineScanChannelUsed = 1;
        else
            lineScanChannelUsed = lineScanChannel;
        end
        lineScanImage = lineScan{lineScanChannelUsed, 1}; % use only the relevant channel
        linesPerFrame = size(lineScanImage, 1); % this should be the same as the entry in column 2 above
        lineScanInterval = framePeriod/linesPerFrame; % (s)
        lineScanInterval = lineScanInterval * 1000; % (ms)
        framePeriod = framePeriod * 1000; % (ms)
        lineScanTimestamp = 0:lineScanInterval:(framePeriod - lineScanInterval); % this will slightly shift the quasismiultaneous linescan towards earlier in time
        lineScanTimestamp = lineScanTimestamp';
        [lineScanFTemp, lineScanDFFTemp, roiTemp] = lineScanImgToF(lineScanImage, lineScanTimestamp, lineScanBaseline, actualParams);
        lineScanDFFOriginalTemp = lineScanDFFTemp;
        try
            if logical(h.params.actualParams.besselFreq2)
                besselOrder = h.params.actualParams.besselOrder2;
                cutoffFreq = h.params.actualParams.besselFreq2;
                cutoffFreq = cutoffFreq*1000; % converting to Hz from kHz
                samplingRate = lineScanDFFTemp(2, 1) - lineScanDFFTemp(1, 1); % sampling interval (ms), since first column is timestamp
                samplingRate = 1000*(1/samplingRate); % converting to Hz from ms
                lineScanDFFTempTemp = lineScanDFFTemp(:, 2); % skip the timestamp in column 1
                lineScanDFFTempTemp = besselLowpass(lineScanDFFTempTemp, besselOrder, cutoffFreq, samplingRate);
                lineScanDFFTemp(:, 2) = lineScanDFFTempTemp;
            end
            if logical(h.params.actualParams.boxcarLength2)
                boxcarLength = h.params.actualParams.boxcarLength2;
                dataLengthReduced = floor(size(lineScanDFFTemp, 1)/boxcarLength);
                lineScanDFFReducedTemp = nan(dataLengthReduced, size(lineScanDFFTemp, 2)); % initializing
                for j = 1:size(lineScanDFFTemp, 2) % NB. timestamp can be treated the same way
                    for k = 1:dataLengthReduced
                        lineScanDFFReducedTemp(k, j) = nanmean(lineScanDFFTemp(1 + (k-1)*boxcarLength : k*boxcarLength, j));
                    end
                end
                lineScanDFFTemp = lineScanDFFReducedTemp; % simply overwrite if data reduction took place
            end
        catch ME
        end
        lineScanF{1} = lineScanFTemp;
        lineScanDFF{1} = lineScanDFFTemp;
        lineScanDFFOriginal{1} = lineScanDFFOriginalTemp;
        lineScanFChannel{1} = lineScanChannelUsed;
        lineScanROI{1} = roiTemp;
    catch ME
        lineScanF{1} = [];
        lineScanDFF{1} = [];
        lineScanDFFOriginal{1} = [];
        lineScanFChannel{1} = [];
        lineScanROI{1} = [];
    end
    try
        markPointsMetadataFile = metadata.PVScan.MarkPoints.Attributes.filename;
        markPointsMetadata{1} = xml2struct_pvbs([fPath, markPointsMetadataFile]);
        markPointsIdx{1} = markPointsMetadata{1}.PVMarkPointSeriesElements.PVMarkPointElement.PVGalvoPointElement.Attributes.Indices;
    catch ME
        markPointsMetadata{1} = struct();
    end
else
        for i = 1:sweeps
        VRecMetadata{i} = metadata.PVScan.Sequence{i}.VoltageRecording.Attributes.configurationFile;
        VRecFile = metadata.PVScan.Sequence{i}.VoltageRecording.Attributes.dataFile;
        VRecTemp = csvread([fPath, VRecFile], csvOffsetRow, csvOffsetColumn); % offset row by 1 ("time(ms), input 0, input 1"), and column by 0
        % this bizzare step has to be taken, because Prairie
        VRecTemp(:, pvbsVoltageColumn) = VRecTemp(:, pvbsVoltageColumn)*pvbsVoltageScalingFactor;
        VRecTemp(:, pvbsCurrentColumn) = VRecTemp(:, pvbsCurrentColumn)*pvbsCurrentScalingFactor;
        pvbsCurrentCorrectionAmount = nanmean(VRecTemp(1:pvbsCurrentCorrectionDataPoints, pvbsCurrentColumn));
        VRecTemp(:, pvbsCurrentColumn) = VRecTemp(:, pvbsCurrentColumn) - pvbsCurrentCorrectionFlag * pvbsCurrentCorrectionAmount;
        % - end of PVBS correction -
        VRecOriginalTemp = VRecTemp;
        try
            if logical(h.params.actualParams.besselFreq1)
                besselOrder = h.params.actualParams.besselOrder1;
                cutoffFreq = h.params.actualParams.besselFreq1;
                cutoffFreq = cutoffFreq*1000; % converting to Hz from kHz
                samplingRate = VRecTemp(2, 1) - VRecTemp(1, 1); % sampling interval (ms), since first column is timestamp
                samplingRate = 1000*(1/samplingRate); % converting to Hz from ms
                for j = 2:size(VRecTemp, 2) % skip timestamp in column 1
                    VRecTempTemp = VRecTemp(:, j); % skip the timestamp in column 1
                    VRecTempTemp = besselLowpass(VRecTempTemp, besselOrder, cutoffFreq, samplingRate);
                    VRecTemp(:, j) = VRecTempTemp;
                end
            end
            if logical(h.params.actualParams.boxcarLength1)
                boxcarLength = h.params.actualParams.boxcarLength1;
                dataLengthReduced = floor(size(VRecTemp, 1)/boxcarLength);
                VRecReducedTemp = nan(dataLengthReduced, size(VRecTemp, 2)); % initializing
                for j = 1:size(VRecTemp, 2) % NB. timestamp can be treated the same way
                    for k = 1:dataLengthReduced
                        VRecReducedTemp(k, j) = nanmean(VRecTemp(1 + (k-1)*boxcarLength : k*boxcarLength, j));
                    end
                end
                VRecTemp = VRecReducedTemp; % simply overwrite if data reduction took place
            end
        catch ME
        end
        VRec{i} = VRecTemp;
        VRecOriginal{i} = VRecOriginalTemp;
        try % some experiments might have been recorded with null VOut
            VOutName{i} = metadata.PVScan.Sequence{i}.VoltageOutput.Attributes.name;
            VOut{i} = metadata.PVScan.Sequence{i}.VoltageOutput.Attributes.filename; % let's just read the file name and not the actual file, since that one's insane
        catch ME
            VOutName{i} = [];
            VOut{i} = [];
        end
        try
            lineScanFileChannelCount = metadata.PVScan.Sequence{i}.Frame.File;
            lineScanFileChannelCount = length(lineScanFileChannelCount);
            if lineScanFileChannelCount == 1
                lineScanFileTemp = metadata.PVScan.Sequence{i}.Frame.File.Attributes.filename;
                lineScanFile{1, i} = lineScanFileTemp;
                warning('off','all');
                lineScan{1, i} = read(Tiff([fPath, lineScanFileTemp])); % Tiff() is a built-in function
                warning('on','all');
            else
                for j = 1:lineScanFileChannelCount
                    lineScanFileTemp = metadata.PVScan.Sequence{i}.Frame.File{j}.Attributes.filename;
                    lineScanFile{j, i} = lineScanFileTemp;
                    warning('off','all');
                    lineScan{j, i} = read(Tiff([fPath, lineScanFileTemp])); % Tiff() is a built-in function
                    warning('on','all');
                end
            end
        catch ME
            lineScanFile{:, i} = [];
            lineScan{:, i} = [];
        end
        try
            lineScanCSVFile{i} =  metadata.PVScan.Sequence{i}.PVLinescanDefinition.LineScanProfiles.Attributes.DataFile; % LineScanProfile csv will include all applicable channels
            lineScanCSV{i} = csvread([fPath, lineScanFile], csvOffsetRow, csvOffsetColumn); % offset row by 1 ("Prof 1 time, Prof 1, Prof 2 time, Prof 2"), and column by 0
        catch ME
            lineScanCSV{i} = [];
        end
        try
            % Applicable if the loaded .xml is a linescan
            %  columns 1, 2, 3, 4 in the astounding PVBS metadata: framePeriod, linesPerFrame, pixelsPerLine, scanLinePeriod
            %  i.e. 1 = 2*3*4, but 2 & 3 can be inferred from data
            %  unit is (s)
            framePeriodIdx = 1;
            framePeriod = metadata.PVScan.Sequence{i}.Frame.PVStateShard.PVStateValue{framePeriodIdx}.Attributes.key;
            if strcmp(framePeriod, 'framePeriod')
                framePeriod = metadata.PVScan.Sequence{i}.Frame.PVStateShard.PVStateValue{framePeriodIdx}.Attributes.value;
                framePeriod = str2num(framePeriod);
            end
            if size(lineScan, 1) < lineScanChannel
                lineScanChannelUsed = 1;
            else
                lineScanChannelUsed = lineScanChannel;
            end
            lineScanImage = lineScan{lineScanChannelUsed, i}; % use only the relevant channel
            linesPerFrame = size(lineScanImage, 1); % this should be the same as the entry in column 2 above
            lineScanInterval = framePeriod/linesPerFrame; % (s)
            lineScanInterval = lineScanInterval * 1000; % (ms)
            framePeriod = framePeriod * 1000; % (ms)
            lineScanTimestamp = 0:lineScanInterval:(framePeriod - lineScanInterval); % this will slightly shift the quasismiultaneous linescan towards earlier in time
            lineScanTimestamp = lineScanTimestamp';
            [lineScanFTemp, lineScanDFFTemp, roiTemp] = lineScanImgToF(lineScanImage, lineScanTimestamp, lineScanBaseline, actualParams);
            lineScanDFFOriginalTemp = lineScanDFFTemp;
            try
                if logical(h.params.actualParams.besselFreq2)
                    besselOrder = h.params.actualParams.besselOrder2;
                    cutoffFreq = h.params.actualParams.besselFreq2;
                    cutoffFreq = cutoffFreq*1000; % converting to Hz from kHz
                    samplingRate = lineScanDFFTemp(2, 1) - lineScanDFFTemp(1, 1); % sampling interval (ms), since first column is timestamp
                    samplingRate = 1000*(1/samplingRate); % converting to Hz from ms
                    lineScanDFFTempTemp = lineScanDFFTemp(:, 2); % skip the timestamp in column 1
                    lineScanDFFTempTemp = besselLowpass(lineScanDFFTempTemp, besselOrder, cutoffFreq, samplingRate);
                    lineScanDFFTemp(:, 2) = lineScanDFFTempTemp;
                end
                if logical(h.params.actualParams.boxcarLength2)
                    boxcarLength = h.params.actualParams.boxcarLength2;
                    dataLengthReduced = floor(size(lineScanDFFTemp, 1)/boxcarLength);
                    lineScanDFFReducedTemp = nan(dataLengthReduced, size(lineScanDFFTemp, 2)); % initializing
                    for j = 1:size(lineScanDFFTemp, 2) % NB. timestamp can be treated the same way
                        for k = 1:dataLengthReduced
                            lineScanDFFReducedTemp(k, j) = nanmean(lineScanDFFTemp(1 + (k-1)*boxcarLength : k*boxcarLength, j));
                        end
                    end
                    lineScanDFFTemp = lineScanDFFReducedTemp; % simply overwrite if data reduction took place
                end
            catch ME
            end
            lineScanF{i} = lineScanFTemp;
            lineScanDFF{i} = lineScanDFFTemp;
            lineScanDFFOriginal{i} = lineScanDFFOriginalTemp;
            lineScanFChannel{i} = lineScanChannelUsed;
            lineScanROI{i} = roiTemp;
        catch ME
            lineScanF{i} = [];
            lineScanDFF{i} = [];
            lineScanDFFOriginal{i} = [];
            lineScanFChannel{i} = [];
            lineScanROI{i} = [];
        end
        try
            markPointsMetadataFile = metadata.PVScan.Sequence{i}.MarkPoints.Attributes.filename;
            markPointsMetadata{i} = xml2struct_pvbs([fPath, markPointsMetadataFile]);
            markPointsIdx{i} = markPointsMetadata{i}.PVMarkPointSeriesElements.PVMarkPointElement.PVGalvoPointElement.Attributes.Indices;
        catch ME
            markPointsMetadata{i} = struct();
        end
        %groupIdx{i} = {}; %groupIdx{i} = 0; % default to this, but do implement autodetect function
        %groupStr{i} = {};
    end
    if offloadMarkPointsMetadata
        for i = 1:length(markPointsMetadata)
            markPointsMetadata{i} = struct(); % to save space
        end
    end
end

% if ROI detection fails for linescans, inherit ROI from the previous sweep
try
    if isempty(lineScanROI{1}) % if the first sweep is missing a ROI
        firstSweepWithROI = find(~cellfun(@isempty, lineScanROI), 1);
        lineScanROI{1} = lineScanROI{firstSweepWithROI};
    end
    if length(lineScanROI) > 1
        for i = 2:length(lineScanROI)
            if isempty(lineScanROI{i})
                lineScanROI{i} = lineScanROI{i - 1};
                % recalculate dF/F with inherited ROI
                roiTemp = lineScanROI{i};
                [lineScanFTemp, lineScanDFFTemp] = lineScanImgToFManualROI(lineScanImage, lineScanTimestamp, lineScanBaseline, actualParams, roiTemp);
                lineScanF{i} = lineScanFTemp;
                lineScanDFF{i} = lineScanDFFTemp;
                lineScanFChannel{i} = lineScanChannelUsed;
            end
        end
    end
catch ME
end

% load one representative branch image for linescans %%% shockingly, PVBS LScn metadata doesn't have reference image information
%{
        try
            singleScanDisplay = h.ui.singleScanDisplay;
            [singleScan, singleScanDisplay] = loadSingleScan2(singleScanDisplay, ssPath, ssName);
            h.ui.singleScanDisplay = singleScanDisplay;
        catch ME
        end
%}

% group sweeps automatically
groupIdx2 = 1;
if sweeps == 1
    groupIdx{1} = 1;
    groupStr{1} = '1';
else
    switch expType
        case 1 % TSer
            if ~iscell(VOutName)
                VOutName = {VOutName};
            end
            if length(VOutName) > 1
                for i = 2:length(VOutName)
                    for j = 1:max(groupIdx2)
                        searchIdx = find(groupIdx2 == j, 1);
                        if strcmp(VOutName{i}, VOutName{searchIdx})
                            groupIdx2(i) = groupIdx2(searchIdx);
                            break
                        else
                            groupIdx2(i) = groupIdx2(searchIdx) + 1;
                            searchIdx = searchIdx + 1;
                        end
                    end
                end
            end
            for i = 1:max(groupIdx2)
                groupIdxNew = find(groupIdx2 == i);
                groupIdx{end + 1} = groupIdxNew;
                groupStrNew = num2str(groupIdxNew(1));
                if length(groupIdxNew) > 1
                    for i = 2:length(groupIdxNew);
                        groupStrNew = [groupStrNew, ',', num2str(groupIdxNew(i))];
                    end
                end
                groupStr{end + 1} = groupStrNew;
            end
        case 2 % VRec
        case 3 % LScn
            try % group according to markpoints indices for uncaging experiments
                for i = 2:length(markPointsIdx)
                    for j = 1:max(groupIdx2)
                        searchIdx = find(groupIdx2 == j, 1);
                        if strcmp(markPointsIdx{i}, markPointsIdx{searchIdx})
                            groupIdx2(i) = groupIdx2(searchIdx);
                            break
                        else
                            groupIdx2(i) = groupIdx2(searchIdx) + 1;
                            searchIdx = searchIdx + 1;
                        end
                    end
                end
                for i = 1:max(groupIdx2)
                    groupIdxNew = find(groupIdx2 == i);
                    groupIdx{end + 1} = groupIdxNew;
                    groupStrNew = num2str(groupIdxNew(1));
                    if length(groupIdxNew) > 1
                        for i = 2:length(groupIdxNew);
                            groupStrNew = [groupStrNew, ',', num2str(groupIdxNew(i))];
                        end
                    end
                    markPointsStr = markPointsIdx{groupIdxNew(1)}; % point indices, should be same for all elements of groupIdxNew at this point
                    groupStrNew = ['(# ', markPointsStr, ')  ', groupStrNew]; % append point indices to be clear
                    groupStr{end + 1} = groupStrNew;
                end
            catch ME
            end
    end
end

% update experiment count and cell list
experiment.experimentCount = experiment.experimentCount + 1;
cellList{end + 1} = fName(1:end-4); % getting rid of the extension
set(cellListDisplay, 'string', cellList);

% bring up downsampling information if applied
if logical(h.params.actualParams.boxcarLength1) || logical(h.params.actualParams.besselFreq1) % either downsampling has been done on signal 1 - prioritize signal 1 over 2
    h.ui.traceProcessingTarget.Value = 2; % 1st item would be selection indicator
    h.ui.downsamplingButton.Value = logical(h.params.actualParams.boxcarLength1); % check the button
    h.ui.lowPassFilterButton.Value = logical(h.params.actualParams.besselFreq1); % check the button
elseif logical(h.params.actualParams.boxcarLength2) || logical(h.params.actualParams.besselFreq2) % if both signals were processed, display will default to signal 1
    h.ui.traceProcessingTarget.Value = 3; % 1st item would be selection indicator
    h.ui.downsamplingButton.Value = logical(h.params.actualParams.boxcarLength2); % check the button
    h.ui.lowPassFilterButton.Value = logical(h.params.actualParams.besselFreq2); % check the button
end

% save
data.VRecMetadata{end + 1} = VRecMetadata;
data.VRec{end + 1} = VRec;
data.VRecOriginal{end + 1} = VRecOriginal;
data.VOutName{end + 1} = VOutName;
data.VOut{end + 1} = VOut;
data.lineScan{end + 1} = lineScan;
data.lineScanF{end + 1} = lineScanF;
data.lineScanDFF{end + 1} = lineScanDFF;
data.lineScanDFFOriginal{end + 1} = lineScanDFFOriginal;
data.lineScanCSV{end + 1} = lineScanCSV;
data.lineScanFChannel{end + 1} = lineScanFChannel;
data.lineScanROI{end + 1} = lineScanROI;
data.lineScanBaseline{end + 1} = lineScanBaseline;
data.postprocessing{end + 1} = postprocessing;
data.artifactRemoval{end + 1} = artifactRemoval;
data.markPointsMetadata{end + 1} = markPointsMetadata;
data.markPointsIdx{end + 1} = markPointsIdx;
data.intrinsicProperties{end + 1} = intrinsicProperties;
data.intrinsicPropertiesVRec{end + 1} = intrinsicPropertiesVRec;
data.intrinsicPropertiesVRecMetadata{end + 1} = intrinsicPropertiesVRecMetadata;
data.intrinsicPropertiesFileName{end + 1} = intrinsicPropertiesFileName;
data.zStack{end + 1} = zStack;
data.zStackFileName{end + 1} = zStackFileName;
data.singleScan{end + 1} = singleScan;
data.singleScanFileName{end + 1} = singleScanFileName;
data.sweepIdx{end + 1} = sweepIdx;
data.sweepStr{end + 1} = sweepStr;
data.groupIdx{end + 1} = groupIdx;
data.groupStr{end + 1} = groupStr;
data.notes{end + 1} = notes;
experiment.data = data;
h.exp = experiment;
h.results = results;
h.ui.cellList = cellList;
h.ui.cellListDisplay = cellListDisplay;

end % end of loadExpMain()


function h = loadCSV(h, fPath, fName, actualParams)
% modified loadExpMain() for VRec (.csv)
% currently treating all .csv as V, not F %%% fixlater ?

%  because PVBS records data in its own units, data must be scaled appropriately
%  hard-coding here, instead of digging again into insane PVBS metadata
%  below are set for MC700B with Rf = 500 MO and usual gain settings for whole-cell recordings
pvbsVoltageScalingFactor = actualParams.pvbsVoltageScalingFactor; % "100 mV" to mV
pvbsCurrentScalingFactor = actualParams.pvbsCurrentScalingFactor; % "0.1 nA" to pA
timeColumn = actualParams.timeColumn; % csv column for timestamp
pvbsVoltageColumn = actualParams.pvbsVoltageColumn; % csv column to apply voltage scaling (column 1 is timestamp, followed by channels)
pvbsCurrentColumn = actualParams.pvbsCurrentColumn; % csv column to apply current scaling
csvOffsetRow = actualParams.csvOffsetRow; % row offset while reading csv with csvread() (default: 1)
csvOffsetColumn = actualParams.csvOffsetColumn; % column offset while reading csv with csvread() (default: 0)
csvColumnsAsSweeps = actualParams.csvColumnsAsSweeps; % interpret columns as sweeps (default: 0)
lineScanChannel = actualParams.lineScanChannel; % primary channel for calcium imaging signal; e.g. for P4, 1: red, 2: green (primary)
lineScanBaseline = actualParams.lineScanBaseline; % (ms), baseline for F_0 in linescans, avoid starting from 0 to prevent possible contamination from shutter artifact
lineScanROIDetectDuringBaseline = actualParams.lineScanROIDetectDuringBaseline; % detect linescan ROI only during baseline window specified above (0: no, 1: yes), in order to prevent possible errors from uncaging artifact
lineScanDownsamplingFactor = actualParams.lineScanDownsamplingFactor; % downsampling factor for fluorescence signals, for the dF/F to be robust to noise
lineScanROISmoothing = actualParams.lineScanDownsamplingFactor; % will average over this many points (before and after) while detecting ROI to be robust from noise - obsolete with single ROI
lineScanROIThreshold = actualParams.lineScanROIThreshold; % (s.d.); z-score for 1st quartile
lineScanBackgroundThreshold = actualParams.lineScanBackgroundThreshold; % (s.d.); z-score for 67th percentile
offloadMarkPointsMetadata = actualParams.offloadMarkPointsMetadata; % delete markpoints metadata after retrieving point indices to save space (0: no, 1: yes)
% PVBS GPIO box can quite unbelievably also introduce current measurement error
%  via bleedthrough across channels, which has to be corrected if present
%  otherwise, there will be "phantom" DC injection present in data
%  DO NOT use if recordings DO have intentional baseline DC injection at the beginning!
%  DO NOT be confused with having incorrect bias current settings from amplifier!
pvbsCurrentCorrectionFlag = actualParams.pvbsCurrentCorrectionFlag; % set to 1 to correct, 0 to leave as is
pvbsCurrentCorrectionDataPoints = actualParams.pvbsCurrentCorrectionDataPoints; % this many points at the beginning will be used for baseline correction

% load
experiment = h.exp;
data = experiment.data;
results = h.results;
cellList = h.ui.cellList;
cellListDisplay = h.ui.cellListDisplay;

% prompt
fprintf(' %s%s ', fPath, fName);

% load file
%%% fixlater: csvColumnsAsSweeps assumes "correct" values, i.e. not scaled - this will create confusion when reading .csv saved from PV
VRecFile = [fPath, fName];
VRecTemp = csvread([fPath, fName], csvOffsetRow, csvOffsetColumn); % offset row by 1 ("time(ms), input 0, input 1"), and column by 0
if csvColumnsAsSweeps
    
    %%% look here!
    % force scaling factor = 1
    pvbsVoltageScalingFactor = 1;
    pvbsCurrentScalingFactor = 1;
    % force reading data as voltage
    pvbsCurrentColumn = 0;
    % force no column/row offset
    csvOffsetRow = 0;
    csvOffsetColumn = 0;
    
    if timeColumn % timestamp column is present
        sweeps = size(VRecTemp, 2); % each column represents a sweep
        nonTimeColumn = 1:sweeps; % do this first
        nonTimeColumn = nonTimeColumn(nonTimeColumn ~= timeColumn);
        sweeps = sweeps - 1; % since one column is for timestamp and not an actual sweep
    else
        sweeps = size(VRecTemp, 2); % each column represents a sweep
        nonTimeColumn = 1:sweeps;
        nonTimeColumn = nonTimeColumn(nonTimeColumn ~= timeColumn);
    end
    %  pvbs bleedthrough correction
    if pvbsVoltageColumn ~= 0
        if pvbsCurrentColumn == 0 % just adding for possible future use of the next else block
            VRecTemp(:, nonTimeColumn) = VRecTemp(:, nonTimeColumn)*pvbsVoltageScalingFactor;
        else % if both are nonzero, default to interpret as voltage
            VRecTemp(:, nonTimeColumn) = VRecTemp(:, nonTimeColumn)*pvbsVoltageScalingFactor;
        end
    elseif pvbsCurrentColumn == 0 % if both are 0, again default to interpret as voltage; this could be used later to interpret as F instead %%% fixlater
        VRecTemp(:, nonTimeColumn) = VRecTemp(:, nonTimeColumn)*pvbsVoltageScalingFactor;
    else % now interpret as current
        VRecTemp(:, nonTimeColumn) = VRecTemp(:, nonTimeColumn)*pvbsCurrentScalingFactor;
        pvbsCurrentCorrectionAmount = nanmean(VRecTemp(1:pvbsCurrentCorrectionDataPoints, pvbsCurrentColumn));
        VRecTemp(:, pvbsCurrentColumn) = VRecTemp(:, pvbsCurrentColumn) - pvbsCurrentCorrectionFlag * pvbsCurrentCorrectionAmount;
    end
else
    sweeps = 1; % gap-free
    %  pvbs bleedthrough correction
    VRecTemp(:, pvbsVoltageColumn) = VRecTemp(:, pvbsVoltageColumn)*pvbsVoltageScalingFactor;
    VRecTemp(:, pvbsCurrentColumn) = VRecTemp(:, pvbsCurrentColumn)*pvbsCurrentScalingFactor;
    pvbsCurrentCorrectionAmount = nanmean(VRecTemp(1:pvbsCurrentCorrectionDataPoints, pvbsCurrentColumn));
    VRecTemp(:, pvbsCurrentColumn) = VRecTemp(:, pvbsCurrentColumn) - pvbsCurrentCorrectionFlag * pvbsCurrentCorrectionAmount;
end

% fill cells
experiment.metadata{end + 1} = [];
experiment.fileName{end + 1} = fName; % just to make file name and path readily accessible
experiment.filePath{end + 1} = fPath;
experiment.sweeps{end + 1} = sweeps;
results{end + 1} = struct;

% fill cells within cells (... interlinked)
VOutName = {cell(sweeps, 1)};
VOut = {cell(sweeps, 1)};
VRecMetadata = {cell(sweeps, 1)};
VRec = {cell(sweeps, 1)};
VRecOriginal = {cell(sweeps, 1)};
%lineScanMetadata = {cell(sweeps, 1)};
lineScanFile = {cell(sweeps, 1)};
lineScan = {cell(sweeps, 1)};
lineScanF = {cell(sweeps, 1)};
lineScanDFF = {cell(sweeps, 1)};
lineScanDFFOriginal = {cell(sweeps, 1)};
lineScanCSVFile = {cell(sweeps, 1)};
lineScanCSV = {cell(sweeps, 1)};
lineScanFChannel = {cell(sweeps, 1)};
lineScanROI = {cell(sweeps, 1)};
markPointsMetadata = {cell(sweeps, 1)};
markPointsIdx = {cell(sweeps, 1)};
intrinsicProperties = struct(); % struct, not cell
intrinsicPropertiesVRec = {cell(1)};
intrinsicPropertiesVRecMetadata = struct();
intrinsicPropertiesFileName = [];
zStack = {cell(1)}; % only one
zStackFileName = [];
singleScan = {cell(1)}; % only one as representative, since saving all of them will be overwhelming for file size %%% what was this?
singleScanFileName = [];
sweepIdx = 1:sweeps;
sweepStr = cell(sweeps, 1);
for i = 1:sweeps
    VRecMetadata{i} = [];
    sweepStr{i} = num2str(i);
    VOutName{i} = [];
    VOut{i} = []; % let's just read the file name and not the actual file, since that one's insane
end
groupIdx = {}; % groupIdx = {cell(sweeps, 1)};
groupStr = {};
if sweeps == 1 % just for convenience if there's only one sweep
    groupIdx{end + 1} = 1;
    groupStr{end + 1} = '1';
end

% fill sweeps
if csvColumnsAsSweeps
    for i = 1:sweeps
        VRec{i} = [VRecTemp(:, timeColumn), VRecTemp(:, nonTimeColumn(i))];
    end
else
    VRec{1} = VRecTemp;
end
VRecOriginal = VRec;

% postprocessing - if applicable


% this block now moved up in different parts to accommodate multiple-sweep .csv
%{
% load VRec
VRecMetadata{1} = [];
VRecFile = [fPath, fName];
VRecTemp = csvread([fPath, fName], csvOffsetRow, csvOffsetColumn); % offset row by 1 ("time(ms), input 0, input 1"), and column by 0
% this bizzare step has to be taken, because Prairie
VRecTemp(:, pvbsVoltageColumn) = VRecTemp(:, pvbsVoltageColumn)*pvbsVoltageScalingFactor;
VRecTemp(:, pvbsCurrentColumn) = VRecTemp(:, pvbsCurrentColumn)*pvbsCurrentScalingFactor;
pvbsCurrentCorrectionAmount = nanmean(VRecTemp(1:pvbsCurrentCorrectionDataPoints, pvbsCurrentColumn));
VRecTemp(:, pvbsCurrentColumn) = VRecTemp(:, pvbsCurrentColumn) - pvbsCurrentCorrectionFlag * pvbsCurrentCorrectionAmount;
% - end of PVBS correction -
VRec = VRecTemp;
VRecOriginal = VRecTemp;
VOutName = [];
VOut = []; % let's just read the file name and not the actual file, since that one's insane
%}

% update experiment count and cell list
experiment.experimentCount = experiment.experimentCount + 1;
cellList{end + 1} = fName(1:end-4); % getting rid of the extension
set(cellListDisplay, 'string', cellList);

% save
data.VRecMetadata{end + 1} = VRecMetadata;
data.VRec{end + 1} = VRec;
data.VRecOriginal{end + 1} = VRecOriginal;
data.VOutName{end + 1} = VOutName;
data.VOut{end + 1} = VOut;
data.lineScan{end + 1} = lineScan;
data.lineScanF{end + 1} = lineScanF;
data.lineScanDFF{end + 1} = lineScanDFF;
data.lineScanDFFOriginal{end + 1} = lineScanDFFOriginal;
data.lineScanCSV{end + 1} = lineScanCSV;
data.lineScanFChannel{end + 1} = lineScanFChannel;
data.lineScanROI{end + 1} = lineScanROI;
data.lineScanBaseline{end + 1} = lineScanBaseline;
data.markPointsMetadata{end + 1} = markPointsMetadata;
data.markPointsIdx{end + 1} = markPointsIdx;
data.intrinsicProperties{end + 1} = intrinsicProperties;
data.intrinsicPropertiesVRec{end + 1} = intrinsicPropertiesVRec;
data.intrinsicPropertiesVRecMetadata{end + 1} = intrinsicPropertiesVRecMetadata;
data.intrinsicPropertiesFileName{end + 1} = intrinsicPropertiesFileName;
data.zStack{end + 1} = zStack;
data.zStackFileName{end + 1} = zStackFileName;
data.singleScan{end + 1} = singleScan;
data.singleScanFileName{end + 1} = singleScanFileName;
data.sweepIdx{end + 1} = sweepIdx;
data.sweepStr{end + 1} = sweepStr;
data.groupIdx{end + 1} = groupIdx;
data.groupStr{end + 1} = groupStr;
experiment.data = data;
h.exp = experiment;
h.results = results;
h.ui.cellList = cellList;
h.ui.cellListDisplay = cellListDisplay;

end


%% Trace Display 


function h = displayTrace(h, itemSelected)

% load
params = h.params;
VRec = h.exp.data.VRec;
traceDisplay = h.ui.traceDisplay;
axes(traceDisplay); % absolutely necessary - bring focus to main display, since other functions might have brought it to another axes

% clear display
trace = {}; % clear current plot
analysisWindowHandle = {}; % clear current analysis window display
axes(traceDisplay);
yyaxis left; cla;
yyaxis right; cla;
yyaxis left;

% clear sweep list items
sweepListDisplay = h.ui.sweepListDisplay;
sweepList = {};
groupListDisplay = h.ui.groupListDisplay;

% axis range information
traceDisplayYRange = h.ui.traceDisplayYRange; % y range; to be shared across experiments
traceDisplayXRange = h.ui.traceDisplayXRange; % x range; to be shared across experiments

% break if invalid - for when called before loading experiments
if isempty(VRec)
    return
end

% experiment to display
columnTimeStamp = h.params.actualParams.timeColumn;
columnToDisplay = h.params.actualParams.pvbsVoltageColumn; %%% fixlater
itemToDisplay = itemSelected(1); % display only the first one if multiple items are selected - obsolete
VRecToDisplay = VRec{itemToDisplay};
if iscell(VRecToDisplay)
    sweepCount = length(VRecToDisplay);
    if sweepCount == 1
        VRecToDisplay = VRecToDisplay{1};
    end
else
    sweepCount = 1;
end
sweepIdx = h.exp.data.sweepIdx{itemSelected};
sweepStr = h.exp.data.sweepStr{itemSelected};
groupIdx = h.exp.data.groupIdx{itemSelected};
groupStr = h.exp.data.groupStr{itemSelected};

% do display
traceColor = params.traceColorInactive;
axes(traceDisplay);
yyaxis left;
if sweepCount == 1
    if iscell(VRecToDisplay)
        currentSweep = VRecToDisplay{1};
    else
        currentSweep = VRecToDisplay;
    end
    trace{1} = plot(currentSweep(:, columnTimeStamp), currentSweep(:, columnToDisplay), 'parent', traceDisplay, 'color', traceColor, 'linestyle', '-', 'linewidth', 0.25, 'marker', 'none');
    trace{1}.ZData = ones(size(trace{1}.XData)); % assigning z value for display order
    %sweepList{end + 1} = num2str(1);
    %{
    if rem(sweepIdx(i), 1) ~= 0
        sweepList{end + 1} = num2str(sweepIdx(i), '%.3f');
    else
        sweepList{end + 1} = num2str(sweepIdx(i));
    end
    %}
    sweepList{end + 1} = sweepStr{1};
else
    hold on;
    for i = 1:sweepCount
        currentSweep = VRecToDisplay{i};
        trace{i} = plot(currentSweep(:, columnTimeStamp), currentSweep(:, columnToDisplay), 'parent', traceDisplay, 'color', traceColor, 'linestyle', '-', 'linewidth', 0.25, 'marker', 'none');
        trace{i}.ZData = ones(size(trace{i}.XData)); % assigning z value for display order
        %sweepList{end + 1} = num2str(i);
        %{
        if rem(sweepIdx(i), 1) ~= 0
            sweepList{end + 1} = num2str(sweepIdx(i), '%.3f');
        else
            sweepList{end + 1} = num2str(sweepIdx(i));
        end
        %}
        sweepList{end + 1} = sweepStr{i};
    end
    hold off;
end
xlabel('t (ms)');
if isempty(h.ui.traceDisplayXRange) % if displaying for the first time, display full range and save
    traceDisplayXRange = xlim(traceDisplay);
    h.ui.traceDisplayXRange = traceDisplayXRange;
    xlim(traceDisplayXRange);
    set(h.ui.traceDisplayXMoveLeft, 'enable', 'off'); % disable "move x left" button, since it will start from zero
else % otherwise retain x range
    xlim(traceDisplayXRange);
end
%xticks(0:1000:600000); xticklabels(0:1000:600000); % x ticks in 1000 ms up to 600000 ms (600 s)
%ylabel('V_m (mV)');
yyaxis left;
ylabel('V_m (mV)', 'color', 'k');
ylim(traceDisplayYRange);
set(gca, 'ycolor', 'k', 'yminortick', 'on');
%yticks(-2000:10:1000); yticklabels(-2000:10:1000); % y ticks in 10 mV from -200 mV to +100 mV
set(sweepListDisplay, 'string', sweepList);
set(groupListDisplay, 'string', groupStr);
%  do not display tick labels as multiples of powers of 10 
ax = gca;
ax.XRuler.Exponent = 0;
ax.YRuler.Exponent = 0;
yyaxis right; ax.YRuler.Exponent = 0; yyaxis left;
%  reset sweep and group list selection
sweepListDisplay.Value = 1; % select first sweep
if isempty(groupIdx)
else
    groupListDisplay.Value = 1; % select first group, unless there is no group
end

% also display baseline and analysis windows
analysisBaseline = h.params.analysisBaseline;
analysisWindow1 = h.params.analysisWindow1;
analysisWindow2 = h.params.analysisWindow2;
analysisBaselineColor = h.params.analysisBaselineColor;
analysisWindow1Color = h.params.analysisWindow1Color;
analysisWindow2Color = h.params.analysisWindow2Color;
analysisWindowHandle = h.ui.analysisWindowHandle;
axes(traceDisplay); 
hold on;
analysisWindowHandle{end + 1} = plot([analysisBaseline(1), analysisBaseline(1)], [-10000, 10000], 'parent', traceDisplay, 'color', analysisBaselineColor, 'linestyle', ':', 'linewidth', 1, 'marker', 'none');
analysisWindowHandle{end + 1} = plot([analysisBaseline(2), analysisBaseline(2)], [-10000, 10000], 'parent', traceDisplay, 'color', analysisBaselineColor, 'linestyle', ':', 'linewidth', 1, 'marker', 'none');
analysisWindowHandle{end + 1} = plot([analysisWindow1(1), analysisWindow1(1)], [-10000, 10000], 'parent', traceDisplay, 'color', analysisWindow1Color, 'linestyle', '-', 'linewidth', 0.5, 'marker', 'none');
analysisWindowHandle{end + 1} = plot([analysisWindow1(2), analysisWindow1(2)], [-10000, 10000], 'parent', traceDisplay, 'color', analysisWindow1Color, 'linestyle', '-', 'linewidth', 0.5, 'marker', 'none');
analysisWindowHandle{end + 1} = plot([analysisWindow2(1), analysisWindow2(1)], [-10000, 10000], 'parent', traceDisplay, 'color', analysisWindow2Color, 'linestyle', '--', 'linewidth', 0.5, 'marker', 'none');
analysisWindowHandle{end + 1} = plot([analysisWindow2(2), analysisWindow2(2)], [-10000, 10000], 'parent', traceDisplay, 'color', analysisWindow2Color, 'linestyle', '--', 'linewidth', 0.5, 'marker', 'none');
hold off;
%{
try %%% why is analysisWindowHandle{i} supposedly deleted? - worked around by giving dF/F traces negative z values
for i = 1:length(analysisWindowHandle)
    classTemp = class(analysisWindowHandle{i});
    if strcmp(classTemp, 'matlab.graphics.chart.primitive.Line')
        analysisWindowHandle{i}.ZData = 10*ones(size(analysisWindowHandle{i}.XData)); % assigning z value for display order
    else
    end
end
catch ME
end
%}
h.ui.analysisWindowHandle = analysisWindowHandle;

% save
h.exp.data.VRec = VRec;
h.ui.traceDisplay = traceDisplay;
h.ui.trace = trace;
h.ui.sweepListDisplay = sweepListDisplay;
h.ui.sweepList = sweepList;
h.ui.sweepListSelected = itemSelected; % need to save this for grouping function

% try 2nd display where applicable
try
    % load
    dff = h.exp.data.lineScanDFF;
    trace2 = {}; % clear current plot
    %  axis range information
    traceDisplayY2Range = h.ui.traceDisplayY2Range; % y range (right); to be shared across experiments

    % experiment to display
    columnTimeStamp2 = 1;
    columnToDisplay2 = 2; % assuming data columns are timestamp, dF/F
    dFFToDisplay = dff{itemToDisplay};
    
    % obsolete because of data structure format
    %{
    if iscell(dFFToDisplay)
        sweep2Count = length(dFFToDisplay);
    else
        sweep2Count = 1;
    end
    %}
    sweep2Count = length(dFFToDisplay);
    
    % do display
    trace2Color = params.trace2ColorInactive;
    axes(traceDisplay);
    yyaxis right; % right y axis
    
    % obsolete because of data structure format
    %{
    if sweep2Count == 1
        currentSweep = dFFToDisplay{1};
        trace2{1} = plot(currentSweep(:, columnTimeStamp2), currentSweep(:, columnToDisplay2), 'parent', traceDisplay, 'color', trace2Color, 'linestyle', '-', 'linewidth', 0.25, 'marker', 'none');
        trace2{1}.ZData = -2*ones(size(trace2{1}.XData)); % assigning z value for display order
    else
    %}
        hold on;
        for i = 1:sweep2Count
            currentSweep = dFFToDisplay{i};
            if iscell(currentSweep) % cell with same number of empty arrays as number of sweeps, resulting from dF/F detection failure (most likely from absence of data in the first place) - first sweep only? %%% find out exactly when - fixlater
                trace2{i} = [];
            elseif isempty(currentSweep) % empty array - similar to above, but for every other sweep than the first? %%% find out exactly when - fixlater
                trace2{i} = [];
            else
                %%% the line below somehow introduces box ticks and disables y (left) minor tick only when sweep2Count == 1
                trace2{i} = plot(currentSweep(:, columnTimeStamp2), currentSweep(:, columnToDisplay2), 'parent', traceDisplay, 'color', trace2Color, 'linestyle', '-', 'linewidth', 0.25, 'marker', 'none');
                trace2{i}.ZData = -2*ones(size(trace2{i}.XData)); % assigning z value for display order
            end
        end
        ylabel('dF/F', 'color', 'g');
        %ylim(traceDisplayY2Range);
        set(gca, 'ycolor', [0, 0.5, 0], 'yminortick', 'on');
        hold off;
    %end
    yyaxis left; % return to y axis (left), just to be safe
    % save
    h.exp.data.lineScanDFF = dff;
    h.ui.trace2 = trace2;
    h.ui.traceDisplay = traceDisplay;
    
catch ME
end
yyaxis left; % do this to avoid staying on right y axis when the try block is interrupted
set(traceDisplay, 'xminortick', 'on', 'yminortick', 'on', 'box', 'on'); % for some magical reason, yminorticks are disabled when there is only 1 trace to plot on the y axis (right)

% bring voltage traces to top - %%%%%%%
set(traceDisplay, 'SortMethod', 'depth');

end


function h = displayTrace2(h, itemSelected, traceDisplay, displayFlag)

% load
params = h.params;
VRec = h.exp.data.VRec;
%traceDisplay = h.ui.traceDisplay;
axes(traceDisplay); % absolutely necessary - bring focus to main display, since other functions might have brought it to another axes

% clear display
trace = {}; % clear current plot
analysisWindowHandle = {}; % clear current analysis window display
axes(traceDisplay);
yyaxis left;
cla;
set(gca, 'ycolor', 'k', 'yminortick', 'on');
yyaxis right;
cla;
set(gca, 'ycolor', [0, 0.5, 0], 'yminortick', 'on');
yyaxis left;

% clear sweep list items
sweepListDisplay = h.ui.sweepListDisplay;
sweepList = {};
groupListDisplay = h.ui.groupListDisplay;

% axis range information
traceDisplayYRange = h.ui.traceDisplayYRange; % y range; to be shared across experiments
traceDisplayXRange = h.ui.traceDisplayXRange; % x range; to be shared across experiments

% break if invalid - for when called before loading experiments
if isempty(VRec)
    return
end

% experiment to display
columnTimeStamp = h.params.actualParams.timeColumn;
columnToDisplay = h.params.actualParams.pvbsVoltageColumn; %%% fixlater
itemToDisplay = itemSelected(1); % display only the first one if multiple items are selected - obsolete
VRecToDisplay = VRec{itemToDisplay};
if iscell(VRecToDisplay)
    sweepCount = length(VRecToDisplay);
    if sweepCount == 1
        VRecToDisplay = VRecToDisplay{1};
    end
else
    sweepCount = 1;
end
sweepIdx = h.exp.data.sweepIdx{itemSelected};
sweepStr = h.exp.data.sweepStr{itemSelected};
groupIdx = h.exp.data.groupIdx{itemSelected};
groupStr = h.exp.data.groupStr{itemSelected};

% do display
traceColor = params.traceColorInactive;
axes(traceDisplay);
yyaxis left;
if displayFlag(1)
    if sweepCount == 1
        if iscell(VRecToDisplay)
            currentSweep = VRecToDisplay{1};
        else
            currentSweep = VRecToDisplay;
        end
        trace{1} = plot(currentSweep(:, columnTimeStamp), currentSweep(:, columnToDisplay), 'parent', traceDisplay, 'color', traceColor, 'linestyle', '-', 'linewidth', 0.25, 'marker', 'none');
        trace{1}.ZData = ones(size(trace{1}.XData)); % assigning z value for display order
        %sweepList{end + 1} = num2str(1);
        %{
    if rem(sweepIdx(i), 1) ~= 0
        sweepList{end + 1} = num2str(sweepIdx(i), '%.3f');
    else
        sweepList{end + 1} = num2str(sweepIdx(i));
    end
        %}
        sweepList{end + 1} = sweepStr{1};
    else
        hold on;
        for i = 1:sweepCount
            currentSweep = VRecToDisplay{i};
            trace{i} = plot(currentSweep(:, columnTimeStamp), currentSweep(:, columnToDisplay), 'parent', traceDisplay, 'color', traceColor, 'linestyle', '-', 'linewidth', 0.25, 'marker', 'none');
            trace{i}.ZData = ones(size(trace{i}.XData)); % assigning z value for display order
            %sweepList{end + 1} = num2str(i);
            %{
        if rem(sweepIdx(i), 1) ~= 0
            sweepList{end + 1} = num2str(sweepIdx(i), '%.3f');
        else
            sweepList{end + 1} = num2str(sweepIdx(i));
        end
            %}
            sweepList{end + 1} = sweepStr{i};
        end
        hold off;
    end
    xlabel('t (ms)');
    if isempty(h.ui.traceDisplayXRange) % if displaying for the first time, display full range and save
        traceDisplayXRange = xlim(traceDisplay);
        h.ui.traceDisplayXRange = traceDisplayXRange;
        xlim(traceDisplayXRange);
        set(h.ui.traceDisplayXMoveLeft, 'enable', 'off'); % disable "move x left" button, since it will start from zero
    else % otherwise retain x range
        xlim(traceDisplayXRange);
    end
    %xticks(0:1000:600000); xticklabels(0:1000:600000); % x ticks in 1000 ms up to 600000 ms (600 s)
    %ylabel('V_m (mV)');
    yyaxis left;
    ylabel('V_m (mV)', 'color', 'k');
    ylim(traceDisplayYRange);
    set(gca, 'ycolor', 'k', 'yminortick', 'on');
    %yticks(-2000:10:1000); yticklabels(-2000:10:1000); % y ticks in 10 mV from -200 mV to +100 mV
    set(sweepListDisplay, 'string', sweepList);
    set(groupListDisplay, 'string', groupStr);
    %  do not display tick labels as multiples of powers of 10
    ax = gca;
    ax.XRuler.Exponent = 0;
    ax.YRuler.Exponent = 0;
    yyaxis right; ax.YRuler.Exponent = 0; yyaxis left;
    %  reset sweep and group list selection
    sweepListDisplay.Value = 1; % select first sweep
    if isempty(groupIdx)
    else
        groupListDisplay.Value = 1; % select first group, unless there is no group
    end
end

% try 2nd display where applicable
if displayFlag(2)
    try
        % load
        dff = h.exp.data.lineScanDFF;
        trace2 = {}; % clear current plot
        %  axis range information
        traceDisplayY2Range = h.ui.traceDisplayY2Range; % y range (right); to be shared across experiments
        
        % experiment to display
        columnTimeStamp2 = 1;
        columnToDisplay2 = 2; % assuming data columns are timestamp, dF/F
        dFFToDisplay = dff{itemToDisplay};
        
        % obsolete because of data structure format
        %{
    if iscell(dFFToDisplay)
        sweep2Count = length(dFFToDisplay);
    else
        sweep2Count = 1;
    end
        %}
        sweep2Count = length(dFFToDisplay);
        
        % do display
        trace2Color = params.trace2ColorInactive;
        axes(traceDisplay);
        yyaxis right; % right y axis
        
        % obsolete because of data structure format
        %{
    if sweep2Count == 1
        currentSweep = dFFToDisplay{1};
        trace2{1} = plot(currentSweep(:, columnTimeStamp2), currentSweep(:, columnToDisplay2), 'parent', traceDisplay, 'color', trace2Color, 'linestyle', '-', 'linewidth', 0.25, 'marker', 'none');
        trace2{1}.ZData = -2*ones(size(trace2{1}.XData)); % assigning z value for display order
    else
        %}
        hold on;
        for i = 1:sweep2Count
            currentSweep = dFFToDisplay{i};
            if iscell(currentSweep) % cell with same number of empty arrays as number of sweeps, resulting from dF/F detection failure (most likely from absence of data in the first place) - first sweep only? %%% find out exactly when - fixlater
                trace2{i} = [];
            elseif isempty(currentSweep) % empty array - similar to above, but for every other sweep than the first? %%% find out exactly when - fixlater
                trace2{i} = [];
            else
                %%% the line below somehow introduces box ticks and disables y (left) minor tick only when sweep2Count == 1
                trace2{i} = plot(currentSweep(:, columnTimeStamp2), currentSweep(:, columnToDisplay2), 'parent', traceDisplay, 'color', trace2Color, 'linestyle', '-', 'linewidth', 0.25, 'marker', 'none');
                trace2{i}.ZData = -2*ones(size(trace2{i}.XData)); % assigning z value for display order
            end
        end
        ylabel('dF/F', 'color', 'g');
        ylim(traceDisplayY2Range);
        set(gca, 'ycolor', [0, 0.5, 0], 'yminortick', 'on');
        hold off;
        %end
        yyaxis left; % return to y axis (left), just to be safe
        % save
        h.exp.data.lineScanDFF = dff;
        h.ui.trace2 = trace2;
        h.ui.traceDisplay = traceDisplay;
        
    catch ME
    end
end

    yyaxis left; % do this to avoid staying on right y axis when the try block is interrupted
    set(traceDisplay, 'xminortick', 'on', 'yminortick', 'on', 'box', 'on'); % for some magical reason, yminorticks are disabled when there is only 1 trace to plot on the y axis (right)
    
    % bring voltage traces to top - %%%%%%%
    set(traceDisplay, 'SortMethod', 'depth');

if ~displayFlag(1)
    yyaxis left;
    set(gca, 'ytick', [], 'ycolor', 'k');
end

if ~displayFlag(2)
    yyaxis right;
    set(gca, 'ytick', [], 'ycolor', 'k');
end

end

%{
function h = displayTrace2(h, itemSelected) % append trace on existing display using right y axis - obsolete

% load
params = h.params;
dff = h.exp.data.lineScanDFF;
traceDisplay = h.ui.traceDisplay;
trace2 = {}; % clear current plot
%  axis range information
traceDisplayYRange = h.ui.traceDisplayY2Range; % y range (right); to be shared across experiments
traceDisplayXRange = h.ui.traceDisplayXRange; % x range; to be shared across experiments

% clear display if unavailable
if isempty(dff)
    axes(traceDisplay); 
    yyaxis right; 
    cla; 
    yyaxis left; % return to y axis (left) just to be safe
end

% experiment to display
columnTimeStamp = 1;
columnToDisplay = 2; % assuming data columns are timestamp, dF/F
itemToDisplay = itemSelected(1); % display only the first one if multiple items are selected - obsolete
dFFToDisplay = dff{itemToDisplay};
if iscell(dFFToDisplay)
    sweepCount = length(dFFToDisplay);
else
    sweepCount = 1;
end

% do display
traceColor = params.trace2ColorInactive;
axes(traceDisplay);
yyaxis right; % right y axis
if sweepCount == 1
    currentSweep = dFFToDisplay;
    trace2{1} = plot(currentSweep(:, columnTimeStamp), currentSweep(:, columnToDisplay), 'parent', traceDisplay, 'color', traceColor, 'linestyle', '-', 'linewidth', 0.5, 'marker', 'none');
else
    hold on;
    for i = 1:sweepCount
        currentSweep = dFFToDisplay{i};
        trace2{i} = plot(currentSweep(:, columnTimeStamp), currentSweep(:, columnToDisplay), 'parent', traceDisplay, 'color', traceColor, 'linestyle', '-', 'linewidth', 0.5, 'marker', 'none');
    end
    hold off;
end
yyaxis left; % return to y axis (left), just to be safe

% save
h.exp.data.lineScanDFF = dff;
h.ui.traceDisplay = traceDisplay;
h.ui.trace2 = trace2;

end
%}


function h = highlightSweep(h, itemSelected)
% update display with selected sweep(s)

% load
params = h.params;
traceDisplay = h.ui.traceDisplay;
warning('off', 'all');
axes(traceDisplay); % absolutely necessary - bring focus to main display, since other functions might have brought it to another axes
warning('on', 'all');
trace = h.ui.trace;
trace2 = h.ui.trace2;

% this is obsolete after having 2 y axes with yyaxis - works fine for only 1 y axis
%{
% do display
traceColor1 = params.traceColorInactive;
for i = 1:length(trace)
    set(trace{i}, 'color', traceColor1);
end
traceColor2 = params.traceColorActive;
for i = 1:length(itemSelected)
    uistack(trace{itemSelected(i)}, 'top');
    set(trace{itemSelected(i)}, 'color', traceColor2);
end
%}

% do display
traceColor1 = params.traceColorInactive;
for i = 1:length(trace)
    if isempty(trace{i})
        continue
    else
        set(trace{i}, 'color', traceColor1);
        trace{i}.ZData = ones(size(trace{i}.XData)); % assigning z value for display order
    end
end
traceColor2 = params.traceColorActive;
for i = 1:length(itemSelected)
    if isempty(trace{itemSelected(i)})
        continue
    else
        set(trace{itemSelected(i)}, 'color', traceColor2);
        trace{itemSelected(i)}.ZData = 2*ones(size(trace{itemSelected(i)}.XData)); % assigning z value for display order
    end
end

% try also for 2nd data display (e.g. dF/F)
try
    trace2Color1 = params.trace2ColorInactive;
    for i = 1:length(trace2)
        if isempty(trace2{i})
            continue
        else
            set(trace2{i}, 'color', trace2Color1);
            trace2{i}.ZData = -2*ones(size(trace2{i}.XData)); % assigning z value for display order
        end
    end
    trace2Color2 = params.trace2ColorActive;
    for i = 1:length(itemSelected)
        if isempty(trace2{itemSelected(i)})
            continue
        else
            set(trace2{itemSelected(i)}, 'color', trace2Color2);
            trace2{itemSelected(i)}.ZData = -1*ones(size(trace2{itemSelected(i)}.XData)); % assigning z value for display order
        end
    end
catch ME
end

% try then displaying original linescan image
try
    experimentNumber = h.ui.cellListDisplay.Value; % current experiment
    experimentNumber = experimentNumber(1); % force single selection
    %h.ui.cellListDisplay.Value = experimentNumber; %%% fixlater ?
    % set colormap
    colorMapRange = h.params.actualParams.lineScanColorMapRange; % colormap will be scaled up for values below this, and saturated to 1 at this level and above   
    grayModified = gray/colorMapRange; % saturating gray colormap at level designated before
    grayModified(grayModified > 1) = 1;
    % clear axes
    lineScan1Display = h.ui.lineScan1Display;
    cla(lineScan1Display);
    set(lineScan1Display, 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8], 'color', [0.95, 0.95, 0.95]);
    set(lineScan1Display, 'xtick', [], 'ytick', [], 'box', 'on');
    h.ui.lineScan1Display = lineScan1Display;
    lineScan2Display = h.ui.lineScan2Display;
    cla(lineScan2Display);
    set(lineScan2Display, 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8], 'color', [0.95, 0.95, 0.95]);
    set(lineScan2Display, 'xtick', [], 'ytick', [], 'box', 'on');
    h.ui.lineScan2Display = lineScan2Display;
    % display linescans, again one channel at a time 
    %  (so that the try block can work as intended in case of only one channel being present)
    lineScan = h.exp.data.lineScan{experimentNumber};
    lineScan = lineScan(:, itemSelected); % current sweep
    lineScan1 = imagesc(lineScan{1, 1}, 'Parent', lineScan1Display);
    colormap(lineScan1Display, 'gray');
    colormap(lineScan1Display, grayModified);
    set(lineScan1Display, 'xtick', [], 'ytick', [], 'box', 'on');
    h.ui.lineScan1Display = lineScan1Display;
    lineScan2 = imagesc(lineScan{2, 1}, 'Parent', lineScan2Display);
    set(lineScan2Display, 'xtick', [], 'ytick', [], 'box', 'on');
    colormap(lineScan2Display, 'gray');
    colormap(lineScan2Display, grayModified);
    h.ui.lineScan2Display = lineScan2Display;
    % display ROIs
    roi = h.exp.data.lineScanROI{experimentNumber}; % current experiment
    roi = roi{itemSelected}; % current sweep
    channelNum = h.exp.data.lineScanFChannel{experimentNumber};
    channelNum = channelNum{itemSelected}; % channel number
    if channelNum == 1
        axes(lineScan1Display);
        hold on;
        plot([roi(1), roi(1)], [1, size(lineScan{1, 1}, 1)], 'color', [0.2, 0.2, 1], 'linestyle', '--', 'linewidth', 0.5, 'marker', 'none');
        plot([roi(2), roi(2)], [1, size(lineScan{1, 1}, 1)], 'color', [0.2, 0.2, 1], 'linestyle', '--', 'linewidth', 0.5, 'marker', 'none');
        hold off;
        h.ui.lineScan1Display = lineScan1Display;
    elseif channelNum == 2
        axes(lineScan2Display);
        hold on;
        plot([roi(1), roi(1)], [1, size(lineScan{2, 1}, 1)], 'color', [0.2, 0.2, 1], 'linestyle', '--', 'linewidth', 0.5, 'marker', 'none');
        plot([roi(2), roi(2)], [1, size(lineScan{2, 1}, 1)], 'color', [0.2, 0.2, 1], 'linestyle', '--', 'linewidth', 0.5, 'marker', 'none');
        hold off;
        h.ui.lineScan2Display = lineScan2Display;
    else
        return
    end
catch ME
    lineScan1Display = h.ui.lineScan1Display;
    cla(lineScan1Display);
    set(lineScan1Display, 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8], 'color', [0.95, 0.95, 0.95]);
    set(lineScan1Display, 'xtick', [], 'ytick', [], 'box', 'on');
    h.ui.lineScan1Display = lineScan1Display;
    lineScan2Display = h.ui.lineScan2Display;
    cla(lineScan2Display);
    set(lineScan2Display, 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8], 'color', [0.95, 0.95, 0.95]);
    set(lineScan2Display, 'xtick', [], 'ytick', [], 'box', 'on');
    h.ui.lineScan2Display = lineScan2Display;
end

% save
h.ui.traceDisplay = traceDisplay;
h.ui.trace = trace;
h.ui.trace2 = trace2;

end


function traceDisplayChannels(src, ~)

win1 = src.Parent;
srcButton = src;
set(srcButton, 'enable', 'off');

% load parameters
h = guidata(win1);
params = h.params;
analysisParameters = h.params.actualParams;
analysisParametersDefault = h.params.defaultParams;

% options
win2 = figure('Name', 'Channels to Display', 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.55, 0.65, 0.2, 0.2], 'DeleteFcn', @winClosed); % use CloseRequestFcn?

ui2.e101 = uicontrol('Parent', win2, 'Style', 'text', 'fontweight', 'bold', 'string', ' <  Axis 1', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.85, 0.4, 0.08]);
ui2.e102 = uicontrol('Parent', win2, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.85, 0.6, 0.08]);
ui2.e103 = uicontrol('Parent', win2, 'Style', 'text', 'fontweight', 'bold', 'string', 'Axis 2  > ', 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.525, 0.85, 0.4, 0.08]);
ui2.e111 = uicontrol('Parent', win2, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.75, 0.4, 0.08]);
ui2.e112 = uicontrol('Parent', win2, 'Style', 'edit', 'string', num2str(1), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.76, 0.125, 0.08], 'callback', @updateCallback);
ui2.e113 = uicontrol('Parent', win2, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.75, 0.1, 0.08]);
ui2.e121 = uicontrol('Parent', win2, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.75, 0.4, 0.08]);
ui2.e122 = uicontrol('Parent', win2, 'Style', 'edit', 'string', num2str(1), 'horizontalalignment', 'right', 'Units', 'normalized', 'Position', [0.75, 0.76, 0.125, 0.08], 'callback', @updateCallback);
ui2.e123 = uicontrol('Parent', win2, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.75, 0.1, 0.08]);

ui2.resetButton = uicontrol('Parent', win2, 'Style', 'pushbutton', 'string', 'Reset to defaults', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.44, 0.05, 0.25, 0.12], 'callback', @resetCallback, 'interruptible', 'off');
ui2.saveButton = uicontrol('Parent', win2, 'Style', 'pushbutton', 'string', 'Save', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.7, 0.05, 0.25, 0.12], 'callback', @saveCallback, 'interruptible', 'off');


    function winClosed(src, ~)
        set(srcButton, 'enable', 'on');
        %guidata(srcButton, h); % don't save when closed without using the save button
    end

end


%% Experiment List 


function cellListClick(src, event)
% update display with selected experiment

% load
h = guidata(src);

% experiment to display
itemSelected = src.Value;

% do display
axes(h.ui.traceDisplay); % absolutely necessary - bring focus to main display, since other functions might have brought it to another axes
h = displayTrace(h, itemSelected);
%h = analysisPlotUpdate(h);
inputStr1 = h.ui.analysisPlot1Menu3.String{h.ui.analysisPlot1Menu3.Value};
inputStr2 = h.ui.analysisPlot2Menu3.String{h.ui.analysisPlot2Menu3.Value};
try
    h = analysisPlotUpdateCall3HandleInput(h, inputStr1, 1); % for plot 1
catch ME
    cla(h.ui.analysisPlot1);
end
try
    h = analysisPlotUpdateCall3HandleInput(h, inputStr2, 2); % for plot 2
catch ME
    cla(h.ui.analysisPlot2);
end

h = cellListClickActual(h, itemSelected);

if isempty(itemSelected)
else
    fName = h.exp.fileName{itemSelected};
    fPath = h.exp.filePath{itemSelected};
    clipboard('copy', [fPath, fName]); % for convenience - but will only work for single selection
    src.Value = itemSelected; % this is redundant but put here nonetheless to recover selection because cellListClickActual() now forces single experiment selection through subfunctions %%% reverted
end

% save
guidata(src, h);

end


function h = cellListClick2(h, itemSelected)
% update display with selected experiment

% do display
axes(h.ui.traceDisplay); % absolutely necessary - bring focus to main display, since other functions might have brought it to another axes
h = displayTrace(h, itemSelected);
%h = analysisPlotUpdate(h);
inputStr1 = h.ui.analysisPlot1Menu3.String{h.ui.analysisPlot1Menu3.Value};
inputStr2 = h.ui.analysisPlot2Menu3.String{h.ui.analysisPlot2Menu3.Value};
try
    h = analysisPlotUpdateCall3HandleInput(h, inputStr1, 1); % for plot 1
catch ME
    cla(h.ui.analysisPlot1);
end
try
    h = analysisPlotUpdateCall3HandleInput(h, inputStr2, 2); % for plot 2
catch ME
    cla(h.ui.analysisPlot2);
end

h = cellListClickActual(h, itemSelected);

fName = h.exp.fileName{itemSelected};
fPath = h.exp.filePath{itemSelected};
clipboard('copy', [fPath, fName]); % for convenience - but will only work for single selection

end


function h = cellListClickActual(h, itemSelected)

% try displaying intrinsic properties
try
    h = displayIntrinsic2(h, h.exp.data.intrinsicPropertiesVRec, h.exp.data.intrinsicProperties, itemSelected, h.params.actualParams.intrinsicPropertiesAnalysis);
    set(h.ui.intrinsicFileName, 'String', h.exp.data.intrinsicPropertiesFileName{itemSelected});
catch ME
    set(h.ui.intrinsicFileName, 'String', '(N/A)');
end
try
    intrinsicProperties = h.exp.data.intrinsicProperties{itemSelected};
    rmpStr = intrinsicProperties.rmp;
    rinStr = intrinsicProperties.r_in;
    sagStr = intrinsicProperties.sag_ratio;
    rmpStr = sprintf('RMP: %.2f %s', rmpStr, '(mV)');
    rinStr = sprintf('R_in: %.2f %s', rinStr, '(MO)');
    sagStr = sprintf('Sag: %.2f', sagStr);
    set(h.ui.intrinsicRMP, 'String', rmpStr);
    set(h.ui.intrinsicRin, 'String', rinStr);
    set(h.ui.intrinsicSag, 'String', sagStr);
catch ME
    set(h.ui.intrinsicRMP, 'String', []);
    set(h.ui.intrinsicRin, 'String', []);
    set(h.ui.intrinsicSag, 'String', []);
end

% try displaying z-stack
try
    h = displayZStack(h);
    set(h.ui.zStackFileName, 'String', h.exp.data.zStackFileName{itemSelected});
catch ME
    set(h.ui.zStackFileName, 'String', '(N/A)');
    set(h.ui.zStackDisplay, 'color', [0.95, 0.95, 0.95], 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8]);
end

% try displaying single-scan
try
    h = displaySingleScan(h);
    set(h.ui.singleScanFileName, 'String', h.exp.data.singleScanFileName{itemSelected});
catch ME
    set(h.ui.singleScanFileName, 'String', '(N/A)');
    set(h.ui.singleScanDisplay, 'color', [0.95, 0.95, 0.95], 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8]);
end

% try recalling notes
try
    h.ui.notes.String = '';
    h.ui.notes.String = h.exp.data.notes{itemSelected};
catch ME
end

% try to bring up downsampling information
try
    postprocessingTemp = h.exp.data.postprocessing{itemSelected};
    postprocessingTempSignal1 = postprocessingTemp(1, :);
    postprocessingTempSignal2 = postprocessingTemp(2, :);
    boxcarLength1 = postprocessingTempSignal1(1); % boxcar length for Ch. 1 (e.g. V)
    boxcarLength2 = postprocessingTempSignal2(1); % boxcar length for Ch. 2 (e.g. dF/F)
    besselFreq1 = postprocessingTempSignal1(2); % (kHz); Bessel filter cutoff frequency for Ch. 1
    besselFreq2 = postprocessingTempSignal2(2); % (kHz); Bessel filter cutoff frequency for Ch. 2
    besselOrder1 = postprocessingTempSignal1(3); % reverse Bessel polynomial order for Ch. 1
    besselOrder2 = postprocessingTempSignal2(3); % reverse Bessel polynomial order for Ch. 2
    if logical(boxcarLength1) || logical(besselFreq1) % either downsampling has been done on signal 1 - prioritize signal 1 over 2
        h.ui.traceProcessingTarget.Value = 2; % 1st item would be selection indicator
        h.ui.downsamplingButton.Value = logical(boxcarLength1); % check the button
        h.ui.downsamplingInput.String = num2str(boxcarLength1);
        h.ui.lowPassFilterButton.Value = logical(besselFreq1); % check the button
        h.ui.lowPassFilterInput.String = num2str(besselFreq1);
    elseif logical(boxcarLength2) || logical(besselFreq2) % if both signals were processed, display will default to signal 1
        h.ui.traceProcessingTarget.Value = 3; % 1st item would be selection indicator
        h.ui.downsamplingButton.Value = logical(boxcarLength2); % check the button
        h.ui.downsamplingInput.String = num2str(boxcarLength2);
        h.ui.lowPassFilterButton.Value = logical(besselFreq2); % check the button
        h.ui.lowPassFilterInput.String = num2str(besselFreq2);
    else % if neither signals were processed, reset display
        h.ui.traceProcessingTarget.Value = 1; % 1st item would be selection indicator
        h.ui.downsamplingButton.Value = 0; % uncheck the button
        h.ui.lowPassFilterButton.Value = 0; % uncheck the button
    end
catch ME % if downsampling information is unavailable, still reset display
    h.ui.traceProcessingTarget.Value = 1; % 1st item would be selection indicator
    h.ui.downsamplingButton.Value = 0; % uncheck the button
    h.ui.lowPassFilterButton.Value = 0; % uncheck the button
end

% highlight first sweep
if isempty(h.ui.cellListDisplay.String)
else
    %h.ui.groupListDisplay.Value = 1;
    h.ui.sweepListDisplay.Value = 1;
    h = highlightSweep(h, 1);
    set(h.ui.groupSweepText, 'string', 'Sweep 1');
end

% reset index for sweep to display within group
h.params.groupSweepIdx = 0;
%set(h.ui.groupSweepText, 'string', '(All sweeps)');

end


function cellListUp(src, ~)
% move selected experiment up in the list

% load
h = guidata(src);
exp = h.exp;
experimentCount = exp.experimentCount;
cellList = h.ui.cellList;
cellListDisplay = h.ui.cellListDisplay;
results = h.results;

% experiment to display
itemSelected = cellListDisplay.Value;
%itemSelected = itemSelected(1); % display only the first one if multiple items are selected - obsolete
if isempty(itemSelected) % if no experiment is selected
    return
end
if itemSelected(1) == 1 % if at top, do nothing
    return
end

for i = itemSelected
    cellListUpActual(i);
end

    function cellListUpActual(i)
        % reorder
        if i == 1 % if at top, do nothing
        else
            % store temporarily
            tempMetadata = exp.metadata{i};
            tempFileName = exp.fileName{i};
            tempFilePath = exp.filePath{i};
            tempSweeps = exp.sweeps{i};
            tempVRec = exp.data.VRec{i};
            tempVRecOriginal = exp.data.VRecOriginal{i};
            tempVRecMetadata = exp.data.VRecMetadata{i};
            tempVOut = exp.data.VOut{i};
            tempVOutName = exp.data.VOutName{i};
            tempLineScan = exp.data.lineScan{i};
            tempLineScanDFF = exp.data.lineScanDFF{i};
            tempLineScanDFFOriginal = exp.data.lineScanDFFOriginal{i};
            tempLineScanF = exp.data.lineScanF{i};
            tempLineScanFChannel = exp.data.lineScanFChannel{i};
            tempLineScanROI = exp.data.lineScanROI{i};
            tempLineScanBaseline = exp.data.lineScanBaseline{i};
            tempLineScanCSV = exp.data.lineScanCSV{i};
            tempPostprocessing = exp.data.postprocessing{i};
            tempArtifactRemoval = exp.data.artifactRemoval{i};
            tempMarkPointsIdx = exp.data.markPointsIdx{i};
            tempMarkPointsMetadata = exp.data.markPointsMetadata{i};
            tempIntrinsicProperties = exp.data.intrinsicProperties{i};
            tempIntrinsicPropertiesVRec = exp.data.intrinsicPropertiesVRec{i};
            tempIntrinsicPropertiesVRecMetadata = exp.data.intrinsicPropertiesVRecMetadata{i};
            tempIntrinsicPropertiesFileName = exp.data.intrinsicPropertiesFileName{i};
            tempZStack = exp.data.zStack{i};
            tempZStackFileName = exp.data.zStackFileName{i};
            tempSingleScan = exp.data.singleScan{i};
            tempSingleScanFileName = exp.data.singleScanFileName{i};
            tempSweepIdx = exp.data.sweepIdx{i};
            tempSweepStr = exp.data.sweepStr{i};
            tempGroupIdx = exp.data.groupIdx{i};
            tempGroupStr = exp.data.groupStr{i};
            tempNotes = exp.data.notes{i};
            tempResults = results{i};
            tempCellList = cellList{i};
            % move previous entry down
            exp.metadata{i} = exp.metadata{i - 1};
            exp.fileName{i} = exp.fileName{i - 1};
            exp.filePath{i} = exp.filePath{i - 1};
            exp.sweeps{i} = exp.sweeps{i - 1};
            exp.data.VRec{i} = exp.data.VRec{i - 1};
            exp.data.VRecOriginal{i} = exp.data.VRecOriginal{i - 1};
            exp.data.VRecMetadata{i} = exp.data.VRecMetadata{i - 1};
            exp.data.VOut{i} = exp.data.VOut{i - 1};
            exp.data.VOutName{i} = exp.data.VOutName{i - 1};
            exp.data.lineScan{i} = exp.data.lineScan{i - 1};
            exp.data.lineScanDFF{i} = exp.data.lineScanDFF{i - 1};
            exp.data.lineScanDFFOriginal{i} = exp.data.lineScanDFFOriginal{i - 1};
            exp.data.lineScanF{i} = exp.data.lineScanF{i - 1};
            exp.data.lineScanFChannel{i} = exp.data.lineScanFChannel{i - 1};
            exp.data.lineScanROI{i} = exp.data.lineScanROI{i - 1};
            exp.data.lineScanBaseline{i} = exp.data.lineScanBaseline{i - 1};
            exp.data.lineScanCSV{i} = exp.data.lineScanCSV{i - 1};
            exp.data.postprocessing{i} = exp.data.postprocessing{i - 1};
            exp.data.artifactRemoval{i} = exp.data.artifactRemoval{i - 1};
            exp.data.markPointsIdx{i} = exp.data.markPointsIdx{i - 1};
            exp.data.markPointsMetadata{i} = exp.data.markPointsMetadata{i - 1};
            exp.data.intrinsicProperties{i} = exp.data.intrinsicProperties{i - 1};
            exp.data.intrinsicPropertiesVRec{i} = exp.data.intrinsicPropertiesVRec{i - 1};
            exp.data.intrinsicPropertiesVRecMetadata{i} = exp.data.intrinsicPropertiesVRecMetadata{i - 1};
            exp.data.intrinsicPropertiesFileName{i} = exp.data.intrinsicPropertiesFileName{i - 1};
            exp.data.zStack{i} = exp.data.zStack{i - 1};
            exp.data.zStackFileName{i} = exp.data.zStackFileName{i - 1};
            exp.data.singleScan{i} = exp.data.singleScan{i - 1};
            exp.data.singleScanFileName{i} = exp.data.singleScanFileName{i - 1};
            exp.data.sweepIdx{i} = exp.data.sweepIdx{i - 1};
            exp.data.sweepStr{i} = exp.data.sweepStr{i - 1};
            exp.data.groupIdx{i} = exp.data.groupIdx{i - 1};
            exp.data.groupStr{i} = exp.data.groupStr{i - 1};
            exp.data.notes{i} = exp.data.notes{i - 1};
            results{i} = results{i - 1};
            cellList{i} = cellList{i - 1};
            % move selected entry up
            exp.metadata{i - 1} = tempMetadata;
            exp.fileName{i - 1} = tempFileName;
            exp.filePath{i - 1} = tempFilePath;
            exp.sweeps{i - 1} = tempSweeps;
            exp.data.VRec{i - 1} = tempVRec;
            exp.data.VRecOriginal{i - 1} = tempVRecOriginal;
            exp.data.VRecMetadata{i - 1} = tempVRecMetadata;
            exp.data.VOut{i - 1} = tempVOut;
            exp.data.VOutName{i - 1} = tempVOutName;
            exp.data.lineScan{i - 1} = tempLineScan;
            exp.data.lineScanDFF{i - 1} = tempLineScanDFF;
            exp.data.lineScanDFFOriginal{i - 1} = tempLineScanDFFOriginal;
            exp.data.lineScanF{i - 1} = tempLineScanF;
            exp.data.lineScanFChannel{i - 1} = tempLineScanFChannel;
            exp.data.lineScanROI{i - 1} = tempLineScanROI;
            exp.data.lineScanBaseline{i - 1} = tempLineScanBaseline;
            exp.data.lineScanCSV{i - 1} = tempLineScanCSV;
            exp.data.postprocessing{i - 1} = tempPostprocessing;
            exp.data.artifactRemoval{i - 1} = tempArtifactRemoval;
            exp.data.markPointsIdx{i - 1} = tempMarkPointsIdx;
            exp.data.markPointsMetadata{i - 1} = tempMarkPointsMetadata;
            exp.data.intrinsicProperties{i - 1} = tempIntrinsicProperties;
            exp.data.intrinsicPropertiesVRec{i - 1} = tempIntrinsicPropertiesVRec;
            exp.data.intrinsicPropertiesVRecMetadata{i - 1} = tempIntrinsicPropertiesVRecMetadata;
            exp.data.intrinsicPropertiesFileName{i - 1} = tempIntrinsicPropertiesFileName;
            exp.data.zStack{i - 1} = tempZStack;
            exp.data.zStackFileName{i - 1} = tempZStackFileName;
            exp.data.singleScan{i - 1} = tempSingleScan;
            exp.data.singleScanFileName{i - 1} = tempSingleScanFileName;
            exp.data.sweepIdx{i - 1} = tempSweepIdx;
            exp.data.sweepStr{i - 1} = tempSweepStr;
            exp.data.groupIdx{i - 1} = tempGroupIdx;
            exp.data.groupStr{i - 1} = tempGroupStr;
            exp.data.notes{i - 1} = tempNotes;
            results{i - 1} = tempResults;
            cellList{i - 1} = tempCellList;
            % update display
            set(cellListDisplay, 'string', cellList);
            %set(cellListDisplay, 'value', i - 1);
        end
    end

% update display
%set(cellListDisplay, 'string', cellList);
set(cellListDisplay, 'value', itemSelected - 1);

% save
h.results = results;
h.exp = exp;
h.ui.cellList = cellList;
h.ui.cellListDisplay = cellListDisplay;
guidata(src, h);

end


function cellListDown(src, ~)
% move selected experiment down in the list

% load
h = guidata(src);
exp = h.exp;
experimentCount = exp.experimentCount;
cellList = h.ui.cellList;
cellListDisplay = h.ui.cellListDisplay;
results = h.results;

% experiment to display
itemSelected = cellListDisplay.Value;
%itemSelected = itemSelected(1); % display only the first one if multiple items are selected - obsolete
if isempty(itemSelected) % if no experiment is selected
    return
end
if itemSelected(end) == length(cellListDisplay.String) % if at bottom, do nothing
    return
end

for i = fliplr(itemSelected) % later first
    cellListDownActual(i);
end

    function cellListDownActual(i)
        % reorder
        if i == length(cellList) % if at bottom, do nothing
        else
            % store temporarily
            tempMetadata = exp.metadata{i};
            tempFileName = exp.fileName{i};
            tempFilePath = exp.filePath{i};
            tempSweeps = exp.sweeps{i};
            tempVRec = exp.data.VRec{i};
            tempVRecOriginal = exp.data.VRecOriginal{i};
            tempVRecMetadata = exp.data.VRecMetadata{i};
            tempVOut = exp.data.VOut{i};
            tempVOutName = exp.data.VOutName{i};
            tempLineScan = exp.data.lineScan{i};
            tempLineScanDFF = exp.data.lineScanDFF{i};
            tempLineScanDFFOriginal = exp.data.lineScanDFFOriginal{i};
            tempLineScanF = exp.data.lineScanF{i};
            tempLineScanFChannel = exp.data.lineScanFChannel{i};
            tempLineScanROI = exp.data.lineScanROI{i};
            tempLineScanBaseline = exp.data.lineScanBaseline{i};
            tempLineScanCSV = exp.data.lineScanCSV{i};
            tempPostprocessing = exp.data.postprocessing{i};
            tempArtifactRemoval = exp.data.artifactRemoval{i};
            tempMarkPointsIdx = exp.data.markPointsIdx{i};
            tempMarkPointsMetadata = exp.data.markPointsMetadata{i};
            tempIntrinsicProperties = exp.data.intrinsicProperties{i};
            tempIntrinsicPropertiesVRec = exp.data.intrinsicPropertiesVRec{i};
            tempIntrinsicPropertiesVRecMetadata = exp.data.intrinsicPropertiesVRecMetadata{i};
            tempIntrinsicPropertiesFileName = exp.data.intrinsicPropertiesFileName{i};
            tempZStack = exp.data.zStack{i};
            tempZStackFileName = exp.data.zStackFileName{i};
            tempSingleScan = exp.data.singleScan{i};
            tempSingleScanFileName = exp.data.singleScanFileName{i};
            tempSweepIdx = exp.data.sweepIdx{i};
            tempSweepStr = exp.data.sweepStr{i};
            tempGroupIdx = exp.data.groupIdx{i};
            tempGroupStr = exp.data.groupStr{i};
            tempNotes = exp.data.notes{i};
            tempResults = results{i};
            tempCellList = cellList{i};
            % move next entry up
            exp.metadata{i} = exp.metadata{i + 1};
            exp.fileName{i} = exp.fileName{i + 1};
            exp.filePath{i} = exp.filePath{i + 1};
            exp.sweeps{i} = exp.sweeps{i + 1};
            exp.data.VRec{i} = exp.data.VRec{i + 1};
            exp.data.VRecOriginal{i} = exp.data.VRecOriginal{i + 1};
            exp.data.VRecMetadata{i} = exp.data.VRecMetadata{i + 1};
            exp.data.VOut{i} = exp.data.VOut{i + 1};
            exp.data.VOutName{i} = exp.data.VOutName{i + 1};
            exp.data.lineScan{i} = exp.data.lineScan{i + 1};
            exp.data.lineScanDFF{i} = exp.data.lineScanDFF{i + 1};
            exp.data.lineScanDFFOriginal{i} = exp.data.lineScanDFFOriginal{i + 1};
            exp.data.lineScanF{i} = exp.data.lineScanF{i + 1};
            exp.data.lineScanFChannel{i} = exp.data.lineScanFChannel{i + 1};
            exp.data.lineScanROI{i} = exp.data.lineScanROI{i + 1};
            exp.data.lineScanBaseline{i} = exp.data.lineScanBaseline{i + 1};
            exp.data.lineScanCSV{i} = exp.data.lineScanCSV{i + 1};
            exp.data.postprocessing{i} = exp.data.postprocessing{i + 1};
            exp.data.artifactRemoval{i} = exp.data.artifactRemoval{i + 1};
            exp.data.markPointsIdx{i} = exp.data.markPointsIdx{i + 1};
            exp.data.markPointsMetadata{i} = exp.data.markPointsMetadata{i + 1};
            exp.data.intrinsicProperties{i} = exp.data.intrinsicProperties{i + 1};
            exp.data.intrinsicPropertiesVRec{i} = exp.data.intrinsicPropertiesVRec{i + 1};
            exp.data.intrinsicPropertiesVRecMetadata{i} = exp.data.intrinsicPropertiesVRecMetadata{i + 1};
            exp.data.intrinsicPropertiesFileName{i} = exp.data.intrinsicPropertiesFileName{i + 1};
            exp.data.zStack{i} = exp.data.zStack{i + 1};
            exp.data.zStackFileName{i} = exp.data.zStackFileName{i + 1};
            exp.data.singleScan{i} = exp.data.singleScan{i + 1};
            exp.data.singleScanFileName{i} = exp.data.singleScanFileName{i + 1};
            exp.data.sweepIdx{i} = exp.data.sweepIdx{i + 1};
            exp.data.sweepStr{i} = exp.data.sweepStr{i + 1};
            exp.data.groupIdx{i} = exp.data.groupIdx{i + 1};
            exp.data.groupStr{i} = exp.data.groupStr{i + 1};
            exp.data.notes{i} = exp.data.notes{i + 1};
            results{i} = results{i + 1};
            cellList{i} = cellList{i + 1};
            % move selected entry down
            exp.metadata{i + 1} = tempMetadata;
            exp.fileName{i + 1} = tempFileName;
            exp.filePath{i + 1} = tempFilePath;
            exp.sweeps{i + 1} = tempSweeps;
            exp.data.VRec{i + 1} = tempVRec;
            exp.data.VRecOriginal{i + 1} = tempVRecOriginal;
            exp.data.VRecMetadata{i + 1} = tempVRecMetadata;
            exp.data.VOut{i + 1} = tempVOut;
            exp.data.VOutName{i + 1} = tempVOutName;
            exp.data.lineScan{i + 1} = tempLineScan;
            exp.data.lineScanDFF{i + 1} = tempLineScanDFF;
            exp.data.lineScanDFFOriginal{i + 1} = tempLineScanDFFOriginal;
            exp.data.lineScanF{i + 1} = tempLineScanF;
            exp.data.lineScanFChannel{i + 1} = tempLineScanFChannel;
            exp.data.lineScanROI{i + 1} = tempLineScanROI;
            exp.data.lineScanBaseline{i + 1} = tempLineScanBaseline;
            exp.data.lineScanCSV{i + 1} = tempLineScanCSV;
            exp.data.postprocessing{i + 1} = tempPostprocessing;
            exp.data.artifactRemoval{i + 1} = tempArtifactRemoval;
            exp.data.markPointsIdx{i + 1} = tempMarkPointsIdx;
            exp.data.markPointsMetadata{i + 1} = tempMarkPointsMetadata;
            exp.data.intrinsicProperties{i + 1} = tempIntrinsicProperties;
            exp.data.intrinsicPropertiesVRec{i + 1} = tempIntrinsicPropertiesVRec;
            exp.data.intrinsicPropertiesVRecMetadata{i + 1} = tempIntrinsicPropertiesVRecMetadata;
            exp.data.intrinsicPropertiesFileName{i + 1} = tempIntrinsicPropertiesFileName;
            exp.data.zStack{i + 1} = tempZStack;
            exp.data.zStackFileName{i + 1} = tempZStackFileName;
            exp.data.singleScan{i + 1} = tempSingleScan;
            exp.data.singleScanFileName{i + 1} = tempSingleScanFileName;
            exp.data.sweepIdx{i + 1} = tempSweepIdx;
            exp.data.sweepStr{i + 1} = tempSweepStr;
            exp.data.groupIdx{i + 1} = tempGroupIdx;
            exp.data.groupStr{i + 1} = tempGroupStr;
            exp.data.notes{i + 1} = tempNotes;
            results{i + 1} = tempResults;
            cellList{i + 1} = tempCellList;
            % update display
            set(cellListDisplay, 'string', cellList);
            %set(cellListDisplay, 'value', i + 1);
        end
    end

% update display
%set(cellListDisplay, 'string', cellList);
set(cellListDisplay, 'value', itemSelected + 1);

% save
h.results = results;
h.exp = exp;
h.ui.cellList = cellList;
h.ui.cellListDisplay = cellListDisplay;
guidata(src, h);

end


function cellListMerge(src, ~)
% merge selected experiments from the list

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    return
end
exp = h.exp;
experimentCount = exp.experimentCount;
cellList = h.ui.cellList;
cellListDisplay = h.ui.cellListDisplay;
results = h.results;

% experiment to display
itemSelected = cellListDisplay.Value;
if isempty(itemSelected) % if no experiment is selected, do nothing
    return
elseif length(itemSelected) == 1 % if only one experiment is selected, also do nothing
    return
end
itemSelectedFirst = itemSelected(1);
itemSelectedLast = itemSelected(end);
fileNameSuffix = sprintf('_C%s', num2str(length(itemSelected)));

% reorder
%  initialize by duplicating the first selection, at the end of the list
cellList{end + 1} = [cellList{itemSelectedFirst}, fileNameSuffix];
exp.metadata{end + 1} = exp.metadata{itemSelectedFirst};
exp.fileName{end + 1} = [exp.fileName{itemSelectedFirst}, fileNameSuffix];
exp.filePath{end + 1} = exp.filePath{itemSelectedFirst};
exp.sweeps{end + 1} = exp.sweeps{itemSelectedFirst};
exp.data.VRec{end + 1} = exp.data.VRec{itemSelectedFirst};
exp.data.VRecOriginal{end + 1} = exp.data.VRecOriginal{itemSelectedFirst};
exp.data.VRecMetadata{end + 1} = exp.data.VRecMetadata{itemSelectedFirst};
exp.data.VOut{end + 1} = exp.data.VOut{itemSelectedFirst};
exp.data.VOutName{end + 1} = exp.data.VOutName{itemSelectedFirst};
exp.data.lineScan{end + 1} = exp.data.lineScan{itemSelectedFirst};
exp.data.lineScanDFF{end + 1} = exp.data.lineScanDFF{itemSelectedFirst};
exp.data.lineScanDFFOriginal{end + 1} = exp.data.lineScanDFFOriginal{itemSelectedFirst};
exp.data.lineScanF{end + 1} = exp.data.lineScanF{itemSelectedFirst};
exp.data.lineScanFChannel{end + 1} = exp.data.lineScanFChannel{itemSelectedFirst};
exp.data.lineScanROI{end + 1} = exp.data.lineScanROI{itemSelectedFirst};
exp.data.lineScanBaseline{end + 1} = exp.data.lineScanBaseline{itemSelectedFirst};
exp.data.lineScanCSV{end + 1} = exp.data.lineScanCSV{itemSelectedFirst};
exp.data.postprocessing{end + 1} = exp.data.postprocessing{itemSelectedFirst};
exp.data.artifactRemoval{end + 1} = exp.data.artifactRemoval{itemSelectedFirst};
exp.data.markPointsIdx{end + 1} = exp.data.markPointsIdx{itemSelectedFirst};
exp.data.markPointsMetadata{end + 1} = exp.data.markPointsMetadata{itemSelectedFirst};
exp.data.intrinsicProperties{end + 1} = exp.data.intrinsicProperties{itemSelectedFirst};
exp.data.intrinsicPropertiesVRec{end + 1} = exp.data.intrinsicPropertiesVRec{itemSelectedFirst};
exp.data.intrinsicPropertiesVRecMetadata{end + 1} = exp.data.intrinsicPropertiesVRecMetadata{itemSelectedFirst};
exp.data.intrinsicPropertiesFileName{end + 1} = exp.data.intrinsicPropertiesFileName{itemSelectedFirst};
exp.data.zStack{end + 1} = exp.data.zStack{itemSelectedFirst};
exp.data.zStackFileName{end + 1} = exp.data.zStackFileName{itemSelectedFirst};
exp.data.singleScan{end + 1} = exp.data.singleScan{itemSelectedFirst};
exp.data.singleScanFileName{end + 1} = exp.data.singleScanFileName{itemSelectedFirst};
exp.data.sweepIdx{end + 1} = exp.data.sweepIdx{itemSelectedFirst};
exp.data.sweepStr{end + 1} = exp.data.sweepStr{itemSelectedFirst};
exp.data.groupIdx{end + 1} = exp.data.groupIdx{itemSelectedFirst};
exp.data.groupStr{end + 1} = exp.data.groupStr{itemSelectedFirst};
exp.data.notes{end + 1} = exp.data.notes{itemSelectedFirst};
results{end + 1} = results{itemSelectedFirst};

% concatenate cells
for i = itemSelected
    if i == itemSelected(1)
        continue
    end
    %cellList{end}
    %exp.metadata{end}
    %exp.fileName{end}
    %exp.filePath{end}
    exp.sweeps{end} = exp.sweeps{end} + exp.sweeps{i};
    exp.data.VRec{end} = [exp.data.VRec{end}, exp.data.VRec{i}];
    exp.data.VRecOriginal{end} = [exp.data.VRecOriginal{end}, exp.data.VRecOriginal{i}];
    exp.data.VRecMetadata{end} = [exp.data.VRecMetadata{end}, exp.data.VRecMetadata{i}];
    exp.data.VOut{end} = [exp.data.VOut{end}, exp.data.VOut{i}];
    exp.data.VOutName{end} = [exp.data.VOutName{end}, exp.data.VOutName{i}];
    try % channel numbers might differ
        exp.data.lineScan{end} = [exp.data.lineScan{end}, exp.data.lineScan{i}];
        flagLineScanChannelCountMismatch = 0;
    catch ME
        flagLineScanChannelCountMismatch = 1;
    end
    exp.data.lineScanDFF{end} = [exp.data.lineScanDFF{end}, exp.data.lineScanDFF{i}];
    exp.data.lineScanDFFOriginal{end} = [exp.data.lineScanDFFOriginal{end}, exp.data.lineScanDFFOriginal{i}];
    exp.data.lineScanF{end} = [exp.data.lineScanF{end}, exp.data.lineScanF{i}];
    exp.data.lineScanFChannel{end} = [exp.data.lineScanFChannel{end}, exp.data.lineScanFChannel{i}];
    exp.data.lineScanROI{end} = [exp.data.lineScanROI{end}, exp.data.lineScanROI{i}];
    exp.data.lineScanBaseline{end} = [exp.data.lineScanBaseline{end}, exp.data.lineScanBaseline{i}];
    exp.data.lineScanCSV{end} = [exp.data.lineScanCSV{end}, exp.data.lineScanCSV{i}];
    %exp.data.postprocessing{end}
    %exp.data.artifactRemoval{end}
    exp.data.markPointsIdx{end} = [exp.data.markPointsIdx{end}, exp.data.markPointsIdx{i}];
    exp.data.markPointsMetadata{end} = [exp.data.markPointsMetadata{end}, exp.data.markPointsMetadata{i}];
    %exp.data.intrinsicProperties{end}
    %exp.data.intrinsicPropertiesVRec{end}
    %exp.data.intrinsicPropertiesVRecMetadata{end}
    %exp.data.intrinsicPropertiesFileName{end}
    %exp.data.zStack{end}
    %exp.data.zStackFileName{end}
    %exp.data.singleScan{end}
    %exp.data.singleScanFileName{end}
    % tricky part
    sweepIdxTemp1 = exp.data.sweepIdx{end};
    sweepIdxTemp1 = sweepIdxTemp1(end);
    sweepIdxTemp2 = exp.data.sweepIdx{i};
    sweepIdxTemp2 = sweepIdxTemp1 + sweepIdxTemp2;
    exp.data.sweepIdx{end} = [exp.data.sweepIdx{end}, sweepIdxTemp2];
    exp.data.sweepStr{end} = [exp.data.sweepStr{end}; exp.data.sweepStr{i}]; % can't be helped without complicating other things, e.g. by adding experiment number prefix
    groupIdxTemp = exp.data.groupIdx{i};
    for j = 1:length(groupIdxTemp)
        groupIdxTempTemp = groupIdxTemp{j};
        groupIdxTempTemp = sweepIdxTemp1 + groupIdxTempTemp;
        groupIdxTemp{j} = groupIdxTempTemp;
    end
    exp.data.groupIdx{end} = [exp.data.groupIdx{end}, groupIdxTemp];
    exp.data.groupStr{end} = [exp.data.groupStr{end}, exp.data.groupStr{i}]; % this will be even more complicated if sweepStr were changed
    %exp.data.notes{end}
    %results{end}
end

% clean up inaccurate elements to avoid confusion
exp.metadata{end} = struct();
results{end} = struct();
if flagLineScanChannelCountMismatch
    exp.data.lineScan{end} = {};
end

% do this outside of the loop
exp.experimentCount = experimentCount + 1; % somehow i made this variable at some point and it's absolutely necessary that it is correct for the code to run properly

% update display
set(cellListDisplay, 'string', cellList);
set(cellListDisplay, 'value', length(cellList));

% save
h.results = results;
h.exp = exp;
h.ui.cellList = cellList;
h.ui.cellListDisplay = cellListDisplay;
%guidata(src, h);
%h = cellListClickActual(h, length(cellList)); % do this after guidata(src, h) to update properly
h = cellListClick2(h, length(cellList)); % do this before guidata(src, h) to update properly
guidata(src, h);

end


function cellListDuplicate(src, ~)
% duplicate selected experiment from the list

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    return
end
exp = h.exp;
experimentCount = exp.experimentCount;
cellList = h.ui.cellList;
cellListDisplay = h.ui.cellListDisplay;
results = h.results;

% experiment to display
itemSelected = cellListDisplay.Value;
%itemSelected = itemSelected(1); % display only the first one if multiple items are selected - obsolete
if isempty(itemSelected) % if no experiment is selected, do nothing
    return
end

for itemToDuplicate = fliplr(itemSelected) % later first
    cellListDuplicateActual(itemToDuplicate);
end

    function cellListDuplicateActual(idx)
        % reorder
        %  make room for new entry
        cellList{end + 1} = cellList{end};
        exp.metadata{end + 1} = exp.metadata{end};
        exp.fileName{end + 1} = exp.fileName{end};
        exp.filePath{end + 1} = exp.filePath{end};
        exp.sweeps{end + 1} = exp.sweeps{end};
        exp.data.VRec{end + 1} = exp.data.VRec{end};
        exp.data.VRecOriginal{end + 1} = exp.data.VRecOriginal{end};
        exp.data.VRecMetadata{end + 1} = exp.data.VRecMetadata{end};
        exp.data.VOut{end + 1} = exp.data.VOut{end};
        exp.data.VOutName{end + 1} = exp.data.VOutName{end};
        exp.data.lineScan{end + 1} = exp.data.lineScan{end};
        exp.data.lineScanDFF{end + 1} = exp.data.lineScanDFF{end};
        exp.data.lineScanDFFOriginal{end + 1} = exp.data.lineScanDFFOriginal{end};
        exp.data.lineScanF{end + 1} = exp.data.lineScanF{end};
        exp.data.lineScanFChannel{end + 1} = exp.data.lineScanFChannel{end};
        exp.data.lineScanROI{end + 1} = exp.data.lineScanROI{end};
        exp.data.lineScanBaseline{end + 1} = exp.data.lineScanBaseline{end};
        exp.data.lineScanCSV{end + 1} = exp.data.lineScanCSV{end};
        exp.data.postprocessing{end + 1} = exp.data.postprocessing{end};
        exp.data.artifactRemoval{end + 1} = exp.data.artifactRemoval{end};
        exp.data.markPointsIdx{end + 1} = exp.data.markPointsIdx{end};
        exp.data.markPointsMetadata{end + 1} = exp.data.markPointsMetadata{end};
        exp.data.intrinsicProperties{end + 1} = exp.data.intrinsicProperties{end};
        exp.data.intrinsicPropertiesVRec{end + 1} = exp.data.intrinsicPropertiesVRec{end};
        exp.data.intrinsicPropertiesVRecMetadata{end + 1} = exp.data.intrinsicPropertiesVRecMetadata{end};
        exp.data.intrinsicPropertiesFileName{end + 1} = exp.data.intrinsicPropertiesFileName{end};
        exp.data.zStack{end + 1} = exp.data.zStack{end};
        exp.data.zStackFileName{end + 1} = exp.data.zStackFileName{end};
        exp.data.singleScan{end + 1} = exp.data.singleScan{end};
        exp.data.singleScanFileName{end + 1} = exp.data.singleScanFileName{end};
        exp.data.sweepIdx{end + 1} = exp.data.sweepIdx{end};
        exp.data.sweepStr{end + 1} = exp.data.sweepStr{end};
        exp.data.groupIdx{end + 1} = exp.data.groupIdx{end};
        exp.data.groupStr{end + 1} = exp.data.groupStr{end};
        exp.data.notes{end + 1} = exp.data.notes{end};
        results{end + 1} = results{end};
        %  shift following entries down
        if idx == length(cellList) % skip if last item was selected
        else
            for i = length(cellList) : -1 : idx + 1 % reverse direction
                cellList{i} = cellList{i - 1};
                exp.metadata{i} = exp.metadata{i - 1};
                exp.fileName{i} = exp.fileName{i - 1};
                exp.filePath{i} = exp.filePath{i - 1};
                exp.sweeps{i} = exp.sweeps{i - 1};
                exp.data.VRec{i} = exp.data.VRec{i - 1};
                exp.data.VRecOriginal{i} = exp.data.VRecOriginal{i - 1};
                exp.data.VRecMetadata{i} = exp.data.VRecMetadata{i - 1};
                exp.data.VOut{i} = exp.data.VOut{i - 1};
                exp.data.VOutName{i} = exp.data.VOutName{i - 1};
                exp.data.lineScan{i} = exp.data.lineScan{i - 1};
                exp.data.lineScanDFF{i} = exp.data.lineScanDFF{i - 1};
                exp.data.lineScanDFFOriginal{i} = exp.data.lineScanDFFOriginal{i - 1};
                exp.data.lineScanF{i} = exp.data.lineScanF{i - 1};
                exp.data.lineScanFChannel{i} = exp.data.lineScanFChannel{i - 1};
                exp.data.lineScanROI{i} = exp.data.lineScanROI{i - 1};
                exp.data.lineScanBaseline{i} = exp.data.lineScanBaseline{i - 1};
                exp.data.lineScanCSV{i} = exp.data.lineScanCSV{i - 1};
                exp.data.postprocessing{i} = exp.data.postprocessing{i - 1};
                exp.data.artifactRemoval{i} = exp.data.artifactRemoval{i - 1};
                exp.data.markPointsIdx{i} = exp.data.markPointsIdx{i - 1};
                exp.data.markPointsMetadata{i} = exp.data.markPointsMetadata{i - 1};
                exp.data.intrinsicProperties{i} = exp.data.intrinsicProperties{i - 1};
                exp.data.intrinsicPropertiesVRec{i} = exp.data.intrinsicPropertiesVRec{i - 1};
                exp.data.intrinsicPropertiesVRecMetadata{i} = exp.data.intrinsicPropertiesVRecMetadata{i - 1};
                exp.data.intrinsicPropertiesFileName{i} = exp.data.intrinsicPropertiesFileName{i - 1};
                exp.data.zStack{i} = exp.data.zStack{i - 1};
                exp.data.zStackFileName{i} = exp.data.zStackFileName{i - 1};
                exp.data.singleScan{i} = exp.data.singleScan{i - 1};
                exp.data.singleScanFileName{i} = exp.data.singleScanFileName{i - 1};
                exp.data.sweepIdx{i} = exp.data.sweepIdx{i - 1};
                exp.data.sweepStr{i} = exp.data.sweepStr{i - 1};
                exp.data.groupIdx{i} = exp.data.groupIdx{i - 1};
                exp.data.groupStr{i} = exp.data.groupStr{i - 1};
                exp.data.notes{i} = exp.data.notes{i - 1};
                results{i} = results{i - 1};
            end
        end
        exp.experimentCount = experimentCount + 1; % somehow i made this variable at some point and it's absolutely necessary that it is correct for the code to run properly
    end

% update display
newSelection = 1:length(itemSelected);
newSelection = newSelection + itemSelected;
set(cellListDisplay, 'string', cellList);
set(cellListDisplay, 'value', newSelection);

% save
h.results = results;
h.exp = exp;
h.ui.cellList = cellList;
h.ui.cellListDisplay = cellListDisplay;
%guidata(src, h);
%h = cellListClickActual(h, itemSelected + 1); % do this after guidata(src, h) to update properly
h = cellListClick2(h, itemSelected + 1); % do this before guidata(src, h) to update properly
guidata(src, h);

end


function cellListDel(src, ~)
% remove selected experiment from the list

set(src, 'enable', 'off');
srcButton = src;

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    set(src, 'enable', 'on');
    return
end
exp = h.exp;
experimentCount = exp.experimentCount;
cellList = h.ui.cellList;
cellListDisplay = h.ui.cellListDisplay;
results = h.results;

% experiment to display
itemSelected = cellListDisplay.Value;
%itemSelected = itemSelected(1); % display only the first one if multiple items are selected - obsolete
if isempty(itemSelected) % if no experiment is selected, do nothing
    set(srcButton, 'enable', 'on');
    return
end

% are you sure?
confirmWin = figure('Name', 'Delete experiment?', 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.2, 0.65, 0.125, 0.1], 'resize', 'off', 'DeleteFcn', @winClosed); % use CloseRequestFcn?
cWin.text = uicontrol('Parent', confirmWin, 'Style', 'text', 'string', sprintf('Delete selected experiment?\nThis cannot be undone.'), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.6, 0.9, 0.3]);
cWin.buttonYes = uicontrol('Parent', confirmWin, 'Style', 'pushbutton', 'string', 'Yes, Delete', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.1, 0.1, 0.35, 0.25], 'callback', @doKillExpt, 'interruptible', 'off');
cWin.buttonNo = uicontrol('Parent', confirmWin, 'Style', 'pushbutton', 'string', 'Cancel', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.1, 0.35, 0.25], 'callback', @dontKillExpt, 'interruptible', 'off');

    function winClosed(src, ~)
        set(srcButton, 'enable', 'on');
        guidata(srcButton, h);
    end

    function dontKillExpt(src, ~)
        set(src, 'enable', 'on');
        close(confirmWin);
    end

    function doKillExpt(src, ~)
        killExpt();
        set(src, 'enable', 'on');
        close(confirmWin);
    end

    function killExpt()
        
        for itemToKill = fliplr(itemSelected) % later first
            killExptActual(itemToKill);
        end
        
        function killExptActual(idx)
            % reorder
            %  shift following entries up
            if idx == length(cellList) % skip if last item was selected
            else
                for i = idx : length(cellList) - 1
                    cellList{i} = cellList{i + 1};
                    exp.metadata{i} = exp.metadata{i + 1};
                    exp.fileName{i} = exp.fileName{i + 1};
                    exp.filePath{i} = exp.filePath{i + 1};
                    exp.sweeps{i} = exp.sweeps{i + 1};
                    exp.data.VRec{i} = exp.data.VRec{i + 1};
                    exp.data.VRecOriginal{i} = exp.data.VRecOriginal{i + 1};
                    exp.data.VRecMetadata{i} = exp.data.VRecMetadata{i + 1};
                    exp.data.VOut{i} = exp.data.VOut{i + 1};
                    exp.data.VOutName{i} = exp.data.VOutName{i + 1};
                    exp.data.lineScan{i} = exp.data.lineScan{i + 1};
                    exp.data.lineScanDFF{i} = exp.data.lineScanDFF{i + 1};
                    exp.data.lineScanDFFOriginal{i} = exp.data.lineScanDFFOriginal{i + 1};
                    exp.data.lineScanF{i} = exp.data.lineScanF{i + 1};
                    exp.data.lineScanFChannel{i} = exp.data.lineScanFChannel{i + 1};
                    exp.data.lineScanROI{i} = exp.data.lineScanROI{i + 1};
                    exp.data.lineScanBaseline{i} = exp.data.lineScanBaseline{i + 1};
                    exp.data.lineScanCSV{i} = exp.data.lineScanCSV{i + 1};
                    exp.data.postprocessing{i} = exp.data.postprocessing{i + 1};
                    exp.data.artifactRemoval{i} = exp.data.artifactRemoval{i + 1};
                    exp.data.markPointsIdx{i} = exp.data.markPointsIdx{i + 1};
                    exp.data.markPointsMetadata{i} = exp.data.markPointsMetadata{i + 1};
                    exp.data.intrinsicProperties{i} = exp.data.intrinsicProperties{i + 1};
                    exp.data.intrinsicPropertiesVRec{i} = exp.data.intrinsicPropertiesVRec{i + 1};
                    exp.data.intrinsicPropertiesVRecMetadata{i} = exp.data.intrinsicPropertiesVRecMetadata{i + 1};
                    exp.data.intrinsicPropertiesFileName{i} = exp.data.intrinsicPropertiesFileName{i + 1};
                    exp.data.zStack{i} = exp.data.zStack{i + 1};
                    exp.data.zStackFileName{i} = exp.data.zStackFileName{i + 1};
                    exp.data.singleScan{i} = exp.data.singleScan{i + 1};
                    exp.data.singleScanFileName{i} = exp.data.singleScanFileName{i + 1};
                    exp.data.sweepIdx{i} = exp.data.sweepIdx{i + 1};
                    exp.data.sweepStr{i} = exp.data.sweepStr{i + 1};
                    exp.data.groupIdx{i} = exp.data.groupIdx{i + 1};
                    exp.data.groupStr{i} = exp.data.groupStr{i + 1};
                    exp.data.notes{i} = exp.data.notes{i + 1};
                    results{i} = results{i + 1};
                end
            end
            %  delete last entry
            cellList = cellList(1:end - 1);
            exp.metadata = exp.metadata(1:end - 1);
            exp.fileName = exp.fileName(1:end - 1);
            exp.filePath = exp.filePath(1:end - 1);
            exp.sweeps = exp.sweeps(1:end - 1);
            exp.data.VRec = exp.data.VRec(1:end - 1);
            exp.data.VRecOriginal = exp.data.VRecOriginal(1:end - 1);
            exp.data.VRecMetadata = exp.data.VRecMetadata(1:end - 1);
            exp.data.VOut = exp.data.VOut(1:end - 1);
            exp.data.VOutName = exp.data.VOutName(1:end - 1);
            exp.data.lineScan = exp.data.lineScan(1:end - 1);
            exp.data.lineScanDFF = exp.data.lineScanDFF(1:end - 1);
            exp.data.lineScanDFFOriginal = exp.data.lineScanDFFOriginal(1:end - 1);
            exp.data.lineScanF = exp.data.lineScanF(1:end - 1);
            exp.data.lineScanFChannel = exp.data.lineScanFChannel(1:end - 1);
            exp.data.lineScanROI = exp.data.lineScanROI(1:end - 1);
            exp.data.lineScanBaseline = exp.data.lineScanBaseline(1:end - 1);
            exp.data.lineScanCSV = exp.data.lineScanCSV(1:end - 1);
            exp.data.postprocessing = exp.data.postprocessing(1:end - 1);
            exp.data.artifactRemoval = exp.data.artifactRemoval(1:end - 1);
            exp.data.markPointsIdx = exp.data.markPointsIdx(1:end - 1);
            exp.data.markPointsMetadata = exp.data.markPointsMetadata(1:end - 1);
            exp.data.intrinsicProperties = exp.data.intrinsicProperties(1:end - 1);
            exp.data.intrinsicPropertiesVRec = exp.data.intrinsicPropertiesVRec(1:end - 1);
            exp.data.intrinsicPropertiesVRecMetadata = exp.data.intrinsicPropertiesVRecMetadata(1:end - 1);
            exp.data.intrinsicPropertiesFileName = exp.data.intrinsicPropertiesFileName(1:end - 1);
            exp.data.zStack = exp.data.zStack(1:end - 1);
            exp.data.zStackFileName = exp.data.zStackFileName(1:end - 1);
            exp.data.singleScan = exp.data.singleScan(1:end - 1);
            exp.data.singleScanFileName = exp.data.singleScanFileName(1:end - 1);
            exp.data.sweepIdx = exp.data.sweepIdx(1:end - 1);
            exp.data.sweepStr = exp.data.sweepStr(1:end - 1);
            exp.data.groupIdx = exp.data.groupIdx(1:end - 1);
            exp.data.groupStr = exp.data.groupStr(1:end - 1);
            exp.data.notes = exp.data.notes(1:end - 1);
            results = results(1:end - 1);
            experimentCount = experimentCount - 1;
        end
        
        % update display
        set(cellListDisplay, 'string', cellList);
        %{
        if length(itemSelected) == 1
            if itemSelected > experimentCount
                newDisplayIdx = experimentCount;
            else
                newDisplayIdx = itemSelected;
            end
        elseif itemSelected(1) > experimentCount
            newDisplayIdx = 1;
        else
            newDisplayIdx = itemSelected(1);
        end
        %}
        if itemSelected(1) > 1
            newDisplayIdx = itemSelected - 1;
        else
            newDisplayIdx = 1;
        end
        set(cellListDisplay, 'value', newDisplayIdx(1));
        %{
        h = displayTrace(h, newDisplayIdx);
        h = cellListClickActual(h, newDisplayIdx);
        %}

        % 
        if experimentCount == 0
            h.params.firstRun = 1; % practically; needed for re-loading experiments from the same window
        end
        
        % save
        h.results = results;
        exp.experimentCount = experimentCount; % stupid af in retrospect
        h.exp = exp;
        h.ui.cellList = cellList;
        h.ui.cellListDisplay = cellListDisplay;
        set(src, 'enable', 'on');
        %guidata(src, h);
        %h = displayTrace(h, newDisplayIdx);
        %h = cellListClickActual(h, newDisplayIdx);
        if length(cellListDisplay.String)
            h = cellListClick2(h, newDisplayIdx); % do this before guidata(src, h) to update properly
        else
            cla(h.ui.traceDisplay);
            delete(allchild(h.ui.traceDisplay));
            h.ui.trace = {};
            h.ui.trace2 = {};
            h.ui.sweepListDisplay.String = {};
            h.ui.groupListDisplay.String = {};
            cla(h.ui.intrinsicPlot1);
            cla(h.ui.intrinsicPlot2);
            cla(h.ui.intrinsicPlot3);
            h.ui.intrinsicFileName.String = {'(N/A)'};
            cla(h.ui.zStackDisplay);
            set(h.ui.zStackDisplay, 'color', [0.95, 0.95, 0.95], 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8]);
            h.ui.zStackFileName.String = {'(N/A)'};
            cla(h.ui.singleScanDisplay);
            set(h.ui.singleScanDisplay, 'color', [0.95, 0.95, 0.95], 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8]);
            h.ui.singleScanFileName.String = {'(N/A)'};
            cla(h.ui.analysisPlot1);
            cla(h.ui.analysisPlot2);
            cla(h.ui.lineScan1Display);
            cla(h.ui.lineScan2Display);
            set(h.ui.lineScan1Display, 'color', [0.95, 0.95, 0.95], 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8]);
            set(h.ui.lineScan2Display, 'color', [0.95, 0.95, 0.95], 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8]);
        end
        guidata(src, h);
        
    end

end


%% Sweep List 


function sweepListClick(src, event)
% update display with selected sweep(s)

% load
h = guidata(src);
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
if isempty(h.ui.cellListDisplay.String) % if no experiment is loaded
    return
elseif isempty(h.ui.cellListDisplay.Value) % if no experiment is selected
    return
end

% sweep to display
itemSelected = src.Value;
sweepIdx = h.exp.data.sweepIdx{cellListIdx};
sweepStr = h.exp.data.sweepStr{cellListIdx};

% do display
h = highlightSweep(h, itemSelected);

% intended for sweep to display within group, but show sweep info anyway
if length(itemSelected) == 1
    set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', sweepStr{itemSelected}));
else
    set(h.ui.groupSweepText, 'string', sprintf(['(', num2str(length(itemSelected)), ' Swps)']));
end

% save
guidata(src, h);

end


function sweepSelectMod(src, ~)
% select every x sweeps

% load
h = guidata(src);
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
if isempty(h.ui.cellListDisplay.String) % if no experiment is loaded
    return
elseif isempty(h.ui.cellListDisplay.Value) % if no experiment is selected
    return
end
sweepList = h.ui.sweepList;
sweepCount = length(sweepList);
selectionInterval = h.params.selectionInterval;
sweepStr = h.exp.data.sweepStr{cellListIdx};

% select sweeps
currentSelection = h.ui.sweepListDisplay.Value; % load current selection
currentSelection = currentSelection(1); % take the first if multiple sweeps are selected
itemSelected = [];
for i = 1 : 1 + floor((sweepCount - currentSelection)/selectionInterval)
    itemSelected(end + 1) = (i - 1) * selectionInterval;
end
itemSelected = itemSelected + currentSelection;
h.ui.sweepListDisplay.Value = itemSelected;

% do display
h = highlightSweep(h, itemSelected);

% intended for sweep to display within group, but show sweep info anyway
if length(itemSelected) == 1
    set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', sweepStr{itemSelected}));
else
    set(h.ui.groupSweepText, 'string', sprintf(['(', num2str(length(itemSelected)), ' Swps)']));
end

% save
guidata(src, h);

end


function sweepSelectModValue(src, event)
% sweep selection interval input

% load
h = guidata(src);

% get input
selectionInterval = src.String;
selectionInterval = str2num(selectionInterval);

% correct invalid input
if selectionInterval <= 0
    fprintf('Selection aborted - input must be positive integer\n');
    selectionInterval = 1;
    h.ui.sweepSelectModValue.String = num2str(selectionInterval);
end

% save
h.params.selectionInterval = selectionInterval;
guidata(src, h);

end


function sweepSelectOdd(src, ~)
% select all odd numbered sweeps

% load
h = guidata(src);
cellListIdx = h.ui.cellListDisplay.Value;cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
if isempty(h.ui.cellListDisplay.String) % if no experiment is loaded
    return
elseif isempty(h.ui.cellListDisplay.Value) % if no experiment is selected
    return
end
sweepList = h.ui.sweepList;
sweepCount = length(sweepList);
sweepStr = h.exp.data.sweepStr{cellListIdx};

% select sweeps
itemSelected = [];
for i = 1:ceil(sweepCount/2)
    itemSelected(end + 1) = 2*i - 1;
end
h.ui.sweepListDisplay.Value = itemSelected;

% do display
h = highlightSweep(h, itemSelected);

% intended for sweep to display within group, but show sweep info anyway
if length(itemSelected) == 1
    set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', sweepStr{itemSelected}));
else
    set(h.ui.groupSweepText, 'string', sprintf(['(', num2str(length(itemSelected)), ' Swps)']));
end

% save
guidata(src, h);

end


function sweepSelectEven(src, ~)
% select all even numbered sweeps

% load
h = guidata(src);
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
if isempty(h.ui.cellListDisplay.String) % if no experiment is loaded
    return
elseif isempty(h.ui.cellListDisplay.Value) % if no experiment is selected
    return
end
sweepList = h.ui.sweepList;
sweepCount = length(sweepList);
sweepStr = h.exp.data.sweepStr{cellListIdx};

% select sweeps
itemSelected = [];
for i = 1:floor(sweepCount/2)
    itemSelected(end + 1) = 2*i;
end
h.ui.sweepListDisplay.Value = itemSelected;

% do display
h = highlightSweep(h, itemSelected);

% intended for sweep to display within group, but show sweep info anyway
if length(itemSelected) == 1
    set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', sweepStr{itemSelected}));
else
    set(h.ui.groupSweepText, 'string', sprintf(['(', num2str(length(itemSelected)), ' Swps)']));
end

% save
guidata(src, h);

end


function sweepSelectInvert(src, ~)
% invert sweep selection

% load
h = guidata(src);
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
if isempty(h.ui.cellListDisplay.String) % if no experiment is loaded
    return
elseif isempty(h.ui.cellListDisplay.Value) % if no experiment is selected
    return
end
sweepList = h.ui.sweepList;
sweepCount = length(sweepList);
sweepStr = h.exp.data.sweepStr{cellListIdx};

% select sweeps
currentSelection = h.ui.sweepListDisplay.Value;
invertedSelection = 1:sweepCount;
invertedSelection(currentSelection) = [];
h.ui.sweepListDisplay.Value = invertedSelection;

% do display
h = highlightSweep(h, invertedSelection);

% intended for sweep to display within group, but show sweep info anyway
if length(invertedSelection) == 1
    set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', sweepStr{invertedSelection}));
else
    set(h.ui.groupSweepText, 'string', sprintf(['(', num2str(length(invertedSelection)), ' Swps)']));
end

% save
guidata(src, h);

end


%% Group List


function groupListClick(src, event)
% update display with selected group (of sweeps)

% load
h = guidata(src);
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
if isempty(h.ui.cellListDisplay.String) % if no experiment is loaded
    return
elseif isempty(h.ui.cellListDisplay.Value) % if no experiment is selected
    return
end
sweepIdx = h.exp.data.sweepIdx{cellListIdx};
sweepStr = h.exp.data.sweepStr{cellListIdx};
groupIdx = h.exp.data.groupIdx{cellListIdx};
groupStr = h.exp.data.groupStr{cellListIdx};

% sweep to display
itemSelected = src.Value;
if length(itemSelected) == 1
    sweepsSelected = groupIdx{itemSelected};
else
    sweepsSelected = [];
    for i = 1:length(itemSelected)
        sweepsSelected = [sweepsSelected, groupIdx{itemSelected(i)}];
    end
end
%  converting to absolute indices from ordinal indices on sweep list
sweepsSelected = ismember(sweepIdx, sweepsSelected); % find elements of sweepIdx that match sweepsSelected
sweepsSelected = find(sweepsSelected == 1); % find their indices
h.ui.sweepListDisplay.Value = sweepsSelected; % update sweep list selection

% do display
h = highlightSweep(h, sweepsSelected);

% reset index for sweep to display within group
h.params.groupSweepIdx = 0;
if length(itemSelected) == 1
    set(h.ui.groupSweepText, 'string', sprintf(['(Group ', num2str(itemSelected), ')']));
else
    set(h.ui.groupSweepText, 'string', sprintf(['(', num2str(length(itemSelected)), ' Grps)']));
end

% save
guidata(src, h);

end


function groupListUp(src, ~)
% move selected group up in the list

% load
h = guidata(src);
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
if isempty(h.ui.cellListDisplay.String) % if no experiment is loaded
    return
elseif isempty(h.ui.cellListDisplay.Value) % if no experiment is selected
    return
end
groupListDisplay = h.ui.groupListDisplay;
itemSelected = h.ui.groupListDisplay.Value;
groupIdx = h.exp.data.groupIdx{cellListIdx};
groupStr = h.exp.data.groupStr{cellListIdx};

% do nothing if no item was selected
if isempty(itemSelected)
    return
end

% break if already on top
if itemSelected(1) == 1
    return
end

% reorder
for i = itemSelected
    % store temporarily
    tempGroupIdx = groupIdx{i};
    tempGroupStr = groupStr{i};
    % move previous entry down
    groupIdx{i} = groupIdx{i - 1};
    groupStr{i} = groupStr{i - 1};
    % move selected entry up
    groupIdx{i - 1} = tempGroupIdx;
    groupStr{i - 1} = tempGroupStr;
    % update display
    set(groupListDisplay, 'string', groupStr);
    set(groupListDisplay, 'value', i - 1);
end

% save
h.ui.groupListDisplay = groupListDisplay;
h.ui.groupListDisplay.Value = itemSelected - 1;
h.exp.data.groupIdx{cellListIdx} = groupIdx;
h.exp.data.groupStr{cellListIdx} = groupStr;
guidata(src, h);

end


function groupListDown(src, ~)
% move selected group up in the list

% load
h = guidata(src);
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
if isempty(h.ui.cellListDisplay.String) % if no experiment is loaded
    return
elseif isempty(h.ui.cellListDisplay.Value) % if no experiment is selected
    return
end
groupListDisplay = h.ui.groupListDisplay;
itemSelected = h.ui.groupListDisplay.Value;
groupIdx = h.exp.data.groupIdx{cellListIdx};
groupStr = h.exp.data.groupStr{cellListIdx};

% do nothing if no item was selected
if isempty(itemSelected)
    return
end

% break if already at bottom
if itemSelected(end) == length(h.ui.groupListDisplay.String)
    return
end

% reorder
for i = flip(itemSelected) % do backwards, i.e. later ones first
    % store temporarily
    tempGroupIdx = groupIdx{i};
    tempGroupStr = groupStr{i};
    % move next entry up
    groupIdx{i} = groupIdx{i + 1};
    groupStr{i} = groupStr{i + 1};
    % move selected entry down
    groupIdx{i + 1} = tempGroupIdx;
    groupStr{i + 1} = tempGroupStr;
    % update display
    set(groupListDisplay, 'string', groupStr);
    set(groupListDisplay, 'value', i + 1);
end

% save
h.ui.groupListDisplay = groupListDisplay;
h.ui.groupListDisplay.Value = itemSelected + 1;
h.exp.data.groupIdx{cellListIdx} = groupIdx;
h.exp.data.groupStr{cellListIdx} = groupStr;
guidata(src, h);

end


function groupListDel(src, ~)
% remove selected group from the list

set(src, 'enable', 'off');
srcButton = src;

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    set(src, 'enable', 'on');
    return
end
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
if isempty(cellListIdx) % if no experiment is selected
    set(src, 'enable', 'on');
    return
end
groupListDisplay = h.ui.groupListDisplay;
itemSelected = h.ui.groupListDisplay.Value;
groupIdx = h.exp.data.groupIdx{cellListIdx};
groupStr = h.exp.data.groupStr{cellListIdx};

% do nothing if no item was selected
if isempty(itemSelected)
    set(src, 'enable', 'on');
    return
end

% are you sure?
confirmWin = figure('Name', 'Delete groups?', 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.8, 0.65, 0.125, 0.1], 'resize', 'off', 'DeleteFcn', @winClosed); % use CloseRequestFcn?
cWin.text = uicontrol('Parent', confirmWin, 'Style', 'text', 'string', sprintf('Delete selected groups?\nThis cannot be undone.'), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.6, 0.9, 0.3]);
cWin.buttonYes = uicontrol('Parent', confirmWin, 'Style', 'pushbutton', 'string', 'Yes, Delete', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.1, 0.1, 0.35, 0.25], 'callback', @doKillGroups, 'interruptible', 'off');
cWin.buttonNo = uicontrol('Parent', confirmWin, 'Style', 'pushbutton', 'string', 'Cancel', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.1, 0.35, 0.25], 'callback', @dontKillGroups, 'interruptible', 'off');

    function winClosed(src, ~)
        set(srcButton, 'enable', 'on');
        guidata(srcButton, h);
    end

    function dontKillGroups(src, ~)
        set(src, 'enable', 'on');
        close(confirmWin);
    end

    function doKillGroups(src, ~)
        killGroups();
        set(src, 'enable', 'on');
        close(confirmWin);
    end

    function killGroups()
        
        % delete
        for i = itemSelected
            groupIdx{i} = [];
            groupStr{i} = [];
        end
        groupIdx = groupIdx(~cellfun('isempty', groupIdx));
        groupStr = groupStr(~cellfun('isempty', groupStr));
        
        %  update display
        set(groupListDisplay, 'string', groupStr);
        if itemSelected > length(groupIdx)
            set(groupListDisplay, 'value', length(groupIdx));
        else
            %set(groupListDisplay, 'value', itemSelected);
            set(groupListDisplay, 'value', itemSelected(1));
        end
        
        % save
        h.ui.groupListDisplay = groupListDisplay;
        h.exp.data.groupIdx{cellListIdx} = groupIdx;
        h.exp.data.groupStr{cellListIdx} = groupStr;
        
        swpIdxTemp = groupIdx{h.ui.groupListDisplay.Value};
        h.ui.sweepListDisplay.Value = swpIdxTemp;
        h = highlightSweep(h, swpIdxTemp);
        set(h.ui.groupSweepText, 'string', sprintf('(Group %s)', num2str(h.ui.groupListDisplay.Value)));
        
        set(src, 'enable', 'on');
        guidata(src, h);
        
    end

end


function groupSelected(src, ~)
% group selected sweeps

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    return
end
groupListDisplay = h.ui.groupListDisplay;
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
sweepListSelected = h.ui.sweepListDisplay.Value;
sweepIdx = h.exp.data.sweepIdx{cellListIdx};
sweepStr = h.exp.data.sweepStr{cellListIdx};
groupIdx = h.exp.data.groupIdx{cellListIdx};
groupStr = h.exp.data.groupStr{cellListIdx};

% do nothing if no item was selected
if isempty(sweepListSelected)
    return
end

% convert from ordinal index from sweep list to absolute index %%% obsolete? see below
sweepListSelectedIdx = sweepIdx(sweepListSelected);

% group
groupIdx{end + 1} = sweepListSelectedIdx;
%  below originally intended for absolute index as updated above
%{
groupStrNew = sweepStr{sweepListSelectedIdx(1)};
if length(sweepListSelectedIdx) > 1
    for i = 2:length(sweepListSelectedIdx)
        groupStrNew = [groupStrNew, ',', sweepStr{sweepListSelectedIdx(i)}];
    end
end
%}
%{
groupStrNew = sweepStr{sweepListSelected}
if length(sweepListSelected) > 1
    for i = 2:length(sweepListSelected)
        groupStrNew = [groupStrNew, ',', sweepStr{sweepListSelected(i)}];
    end
end
%}
groupStrNew = sweepStr{sweepListSelected(1)};
for i = 2:length(sweepListSelected) % staring at position 2 because of comma
    groupStrNew = [groupStrNew, ',', sweepStr{sweepListSelected(i)}];
end

groupStr{end + 1} = groupStrNew;
set(groupListDisplay, 'string', groupStr);
if groupListDisplay.Value == 0 % if all groups had been deleted
    set(groupListDisplay, 'value', 1); % shouldn't the line below suffice? was i drunk?
else
    set(groupListDisplay, 'value', length(groupListDisplay.String)); % highlight
end

% save
h.exp.data.groupIdx{cellListIdx} = groupIdx;
h.exp.data.groupStr{cellListIdx} = groupStr;
h.ui.groupListDisplay = groupListDisplay;
guidata(src, h);

end


function groupListMerge(src, ~)
% merge selected groups

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    return
end
groupListDisplay = h.ui.groupListDisplay;
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
groupListSelected = h.ui.groupListDisplay.Value;
sweepListSelected = h.ui.sweepListDisplay.Value;
sweepIdx = h.exp.data.sweepIdx{cellListIdx};
sweepStr = h.exp.data.sweepStr{cellListIdx};
groupIdx = h.exp.data.groupIdx{cellListIdx};
groupStr = h.exp.data.groupStr{cellListIdx};

% do nothing if no item or only one item was selected
if isempty(groupListSelected)
    return
elseif length(groupListSelected) == 1 
    return
end

% convert from ordinal index from sweep list to absolute index %%% obsolete? see below
groupListSelectedIdx = groupIdx(groupListSelected); % will be a cell of arrays
groupListSelectedIdx = cell2mat(groupListSelectedIdx);
sweepListSelectedIdx = groupListSelectedIdx;

% re-select all sweeps in group, in case some sweeps were manually de-selected from the sweep list
sweepsSelected = [];
for i = 1:length(groupListSelected)
    sweepsSelected = [sweepsSelected, groupIdx{groupListSelected(i)}];
end
%  converting to absolute indices from ordinal indices on sweep list
sweepsSelected = ismember(sweepIdx, sweepsSelected); % find elements of sweepIdx that match sweepsSelected
sweepsSelected = find(sweepsSelected == 1); % find their indices
h.ui.sweepListDisplay.Value = sweepsSelected; % update sweep list selection

% group
groupIdx{end + 1} = groupListSelectedIdx;
%  below originally intended for absolute index as updated above
%{
groupStrNew = sweepStr{sweepListSelectedIdx(1)};
if length(sweepListSelectedIdx) > 1
    for i = 2:length(sweepListSelectedIdx)
        groupStrNew = [groupStrNew, ',', sweepStr{sweepListSelectedIdx(i)}];
    end
end
%}
%{
groupStrNew = sweepStr{sweepListSelected};
if length(sweepListSelected) > 1
    for i = 2:length(sweepListSelected)
        groupStrNew = [groupStrNew, ',', sweepStr{sweepListSelected(i)}];
    end
end
%}
groupStrNew = sweepStr{sweepsSelected(1)};
for i = 2:length(sweepsSelected) % staring at position 2 because of comma
    groupStrNew = [groupStrNew, ',', sweepStr{sweepsSelected(i)}];
end

% do display
h = highlightSweep(h, sweepsSelected);

groupStr{end + 1} = groupStrNew;
set(groupListDisplay, 'string', groupStr);
if groupListDisplay.Value == 0 % if all groups had been deleted
    set(groupListDisplay, 'value', 1); % shouldn't the line below suffice? was i drunk?
else
    set(groupListDisplay, 'value', length(groupListDisplay.String)); % highlight
end

% reset index for sweep to display within group
h.params.groupSweepIdx = 0;
set(h.ui.groupSweepText, 'string', sprintf(['(Group ', num2str(length(h.ui.groupListDisplay.String)), ')']));

% save
h.exp.data.groupIdx{cellListIdx} = groupIdx;
h.exp.data.groupStr{cellListIdx} = groupStr;
h.ui.groupListDisplay = groupListDisplay;
guidata(src, h);

end


function groupSelectedMod(src, ~)
% group every x sweeps from selection

% load
h = guidata(src);
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
if isempty(h.ui.cellListDisplay.String) % if no experiment is loaded
    return
elseif isempty(h.ui.cellListDisplay.Value) % if no experiment is selected
    return
end
sweepList = h.ui.sweepList;
sweepCount = length(sweepList);
selectionInterval = h.params.groupSelectionInterval;
groupListDisplay = h.ui.groupListDisplay;
sweepListSelected = h.ui.sweepListDisplay.Value;
sweepIdx = h.exp.data.sweepIdx{cellListIdx};
sweepStr = h.exp.data.sweepStr{cellListIdx};
groupIdx = h.exp.data.groupIdx{cellListIdx};
groupStr = h.exp.data.groupStr{cellListIdx};

% do nothing if no item was selected
if isempty(sweepListSelected)
    return
end

if selectionInterval == 0
    selectionInterval = length(sweepListSelected) + 1; % %%% lazy af but this effectively takes care of the job
end

% iterate
for k = 1:selectionInterval
    try
        [h, itemSelected] = groupSelectModMain(h, k);
    catch ME
    end
end

    function [h, itemSelected] = groupSelectModMain(h, k)
        
        % select sweeps
        currentSelection = h.ui.sweepListDisplay.Value; % load current selection
        currentSelectionEnd = currentSelection(end);
        currentSelection = currentSelection(1 + k - 1); % take the first if multiple sweeps are selected
        itemSelected = [];
        for i = 1 : 1 + floor((currentSelectionEnd - currentSelection)/selectionInterval)
            itemSelected(end + 1) = (i - 1) * selectionInterval;
        end
        itemSelected = itemSelected + currentSelection;
        %h.ui.sweepListDisplay.Value = itemSelected; % un-commenting this line will fuck things up because of how currentSelection is re-defined at the top row of this block; could be remedied easily, but i'm that lazy
        
        % convert from ordinal index from sweep list to absolute index
        sweepListSelectedIdx = sweepIdx(itemSelected);
        
        % group
        groupIdx{end + 1} = sweepListSelectedIdx;
        groupStrNew = sweepStr{sweepListSelectedIdx(1)};
        if length(sweepListSelectedIdx) > 1
            for i = 2:length(sweepListSelectedIdx)
                groupStrNew = [groupStrNew, ',', sweepStr{sweepListSelectedIdx(i)}];
            end
        end
        groupStr{end + 1} = groupStrNew;
        set(groupListDisplay, 'string', groupStr);
        if groupListDisplay.Value == 0 % if all groups had been deleted
            set(groupListDisplay, 'value', 1); % shouldn't the line below suffice? was i drunk?
        else
            set(groupListDisplay, 'value', length(groupListDisplay.String)); % highlight
        end
        
    end

% save
h.exp.data.groupIdx{cellListIdx} = groupIdx;
h.exp.data.groupStr{cellListIdx} = groupStr;
h.ui.groupListDisplay = groupListDisplay;
guidata(src, h);

% do display
h = highlightSweep(h, itemSelected);

% save
guidata(src, h);

end


function groupSelectModValue(src, event)
% group by interval input

% load
h = guidata(src);

% get input
selectionInterval = src.String;
selectionInterval = str2num(selectionInterval);

% correct invalid input
if selectionInterval < 0
    fprintf('Grouping aborted - input must be nonnegative integer (0 to group each sweep into an individual group)\n');
    selectionInterval = 0;
    h.ui.groupSelectedModValue.String = num2str(selectionInterval);
end

% save
h.params.selectionInterval = selectionInterval;
guidata(src, h);

% save
h.params.groupSelectionInterval = selectionInterval;
guidata(src, h);

end


function groupAutoVOut(src, ~)
% group sweeps automatically according to VOutName
return %%% not coded in yet!!!
% load
h = guidata(src);
groupListDisplay = h.ui.groupListDisplay;
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
VOutName = h.exp.data.VOutName{cellListIdx};
groupIdx = {}; % groupIdx = h.exp.data.groupIdx{cellListIdx};
groupStr = {}; % groupStr = h.exp.data.groupStr{cellListIdx};

if isempty(VOutName)
    return
end

% group
groupIdx2 = 1;
for i = 2:length(VOutName)
    for j = 1:max(groupIdx2)
        searchIdx = find(groupIdx2 == j, 1);
        if strcmp(VOutName{i}, VOutName{searchIdx})
            groupIdx2(i) = searchIdx;
            break
        else
            searchIdx = searchIdx + 1;
            groupIdx2(i) = searchIdx;
        end
    end
end
for i = 1:max(groupIdx2)
    groupIdxNew = find(groupIdx2 == i);
    groupIdx{end + 1} = groupIdxNew;
    groupStrNew = num2str(groupIdxNew(1));
    if length(groupIdxNew) > 1
        for i = 2:length(groupIdxNew);
            groupStrNew = [groupStrNew, ',', num2str(groupIdxNew(i))];
        end
    end
    groupStr{end + 1} = groupStrNew;
end
set(groupListDisplay, 'string', groupStr);

% save
h.exp.data.groupIdx{cellListIdx} = groupIdx;
h.exp.data.groupStr{cellListIdx} = groupStr;
h.ui.groupListDisplay = groupListDisplay;
guidata(src, h);

end


function groupAutoMkPts(src, ~)
% group sweeps automatically according to MarkPoints indices
return %%% not coded in yet!!!
% load
h = guidata(src);
groupListDisplay = h.ui.groupListDisplay;
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
VOutName = h.exp.data.VOutName{cellListIdx};
groupIdx = {}; % groupIdx = h.exp.data.groupIdx{cellListIdx};
groupStr = {}; % groupStr = h.exp.data.groupStr{cellListIdx};

if isempty(VOutName)
    return
end

% group
groupIdx2 = 1;
for i = 2:length(VOutName)
    for j = 1:max(groupIdx2)
        searchIdx = find(groupIdx2 == j, 1);
        if strcmp(VOutName{i}, VOutName{searchIdx})
            groupIdx2(i) = searchIdx;
            break
        else
            searchIdx = searchIdx + 1;
            groupIdx2(i) = searchIdx;
        end
    end
end
for i = 1:max(groupIdx2)
    groupIdxNew = find(groupIdx2 == i);
    groupIdx{end + 1} = groupIdxNew;
    groupStrNew = num2str(groupIdxNew(1));
    if length(groupIdxNew) > 1
        for i = 2:length(groupIdxNew);
            groupStrNew = [groupStrNew, ',', num2str(groupIdxNew(i))];
        end
    end
    groupStr{end + 1} = groupStrNew;
end
set(groupListDisplay, 'string', groupStr);

% save
h.exp.data.groupIdx{cellListIdx} = groupIdx;
h.exp.data.groupStr{cellListIdx} = groupStr;
h.ui.groupListDisplay = groupListDisplay;
guidata(src, h);

end


function groupSweepPrev(src, ~)
% scroll sweep selection down within selected group

% load
h = guidata(src);
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
if isempty(h.ui.cellListDisplay.String) % if no experiment is loaded
    return
elseif isempty(h.ui.cellListDisplay.Value) % if no experiment is selected
    return
end
sweepIdx = h.exp.data.sweepIdx{cellListIdx};
sweepStr = h.exp.data.sweepStr{cellListIdx};
groupIdx = h.exp.data.groupIdx{cellListIdx};

% sweep to display
itemSelected = h.ui.groupListDisplay.Value;
itemSelected = sweepIdx(itemSelected); % converting to absolute indices from ordinal indices on sweep list
sweepsSelected = groupIdx{itemSelected};
%  converting to absolute indices from ordinal indices on sweep list
sweepsSelected = ismember(sweepIdx, sweepsSelected); % find elements of sweepIdx that match sweepsSelected
sweepsSelected = find(sweepsSelected == 1); % find their indices
h.ui.sweepListDisplay.Value = sweepsSelected; % update sweep list selection
currentSweep = h.params.groupSweepIdx;
if currentSweep == 0 % if first time, go to last sweep
    currentSweep = length(sweepsSelected);
elseif currentSweep == 1 % if at first sweep, roll over to last sweep
    currentSweep = length(sweepsSelected);
else
    currentSweep = currentSweep - 1;
end
h.params.groupSweepIdx = currentSweep; % save index for future use
currentSweep = sweepsSelected(currentSweep); % get actual sweep number from index

% do display
h = highlightSweep(h, currentSweep);
set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', sweepStr{currentSweep}));

% save
guidata(src, h);

end


function groupSweepNext(src, ~)
% scroll sweep selection up within selected group

% load
h = guidata(src);
cellListIdx = h.ui.cellListDisplay.Value;
cellListIdx = cellListIdx(1); % force single selection
h.ui.cellListDisplay.Value = cellListIdx;
if isempty(h.ui.cellListDisplay.String) % if no experiment is loaded
    return
elseif isempty(h.ui.cellListDisplay.Value) % if no experiment is selected
    return
end
sweepIdx = h.exp.data.sweepIdx{cellListIdx};
sweepStr = h.exp.data.sweepStr{cellListIdx};
groupIdx = h.exp.data.groupIdx{cellListIdx};

% sweep to display
itemSelected = h.ui.groupListDisplay.Value;
sweepsSelected = groupIdx{itemSelected};
%  converting to absolute indices from ordinal indices on sweep list
sweepsSelected = ismember(sweepIdx, sweepsSelected); % find elements of sweepIdx that match sweepsSelected
sweepsSelected = find(sweepsSelected == 1); % find their indices
h.ui.sweepListDisplay.Value = sweepsSelected; % update sweep list selection
currentSweep = h.params.groupSweepIdx;
if currentSweep == 0 % if first time, display first sweep
    currentSweep = 1;
elseif currentSweep == length(sweepsSelected) % if at last sweep, roll over to first sweep
    currentSweep = 1;
else
    currentSweep = currentSweep + 1;
end
h.params.groupSweepIdx = currentSweep; % save index for future use
currentSweep = sweepsSelected(currentSweep); % get actual sweep number from index

% do display
h = highlightSweep(h, currentSweep);
set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', sweepStr{currentSweep}));

% save
guidata(src, h);

end


%% Sweep/Group Operation


function sweepsSegmentation(src, ~)
% segment data into fixed-length episodes

% load
h = guidata(src);
winMain = src;
if isempty(h.ui.cellListDisplay.String)
    return
end

% fetch default parameters ... but see "cheap trick" below
actualParams = h.params.actualParams;
segmentationLength = actualParams.segmentationLength; % segment length (ms)
segmentationOffset = actualParams.segmentationOffset; % segmentation initial offset (ms)
segmentationTruncate = actualParams.segmentationTruncate; % truncate remainder (0: no, 1: yes)
segmentationCount = actualParams.segmentationCount; % keep only this many segments and discard the rest (0 to disable)
timeColumn = actualParams.timeColumn; % column 1: timestamp
pvbsVoltageColumn = actualParams.pvbsVoltageColumn; % column 2: voltage
lastSweepDeleted = h.params.lastSweepDeleted; % flag indicating if last sweep had been deleted

% experiment and sweep number
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
swpIdx = h.ui.sweepListDisplay.Value;
expCount = length(h.ui.cellListDisplay);
swpCount = length(h.ui.sweepListDisplay);
sweepIdx = h.exp.data.sweepIdx{expIdx}; % again very poor choice of variable name in hindsight
sweepStr = h.exp.data.sweepStr{expIdx};
%swpIdx = sweepIdx(swpIdx);

% force single selection
if length(expIdx) > 1
    expIdx = expIdx(1);
    h.ui.cellListDisplay.Value = expIdx;
end
%{
if length(swpIdx) > 1
    swpIdx = swpIdx(1);
    h.ui.sweepListDisplay.Value = swpIdx;
end
%}

%{
% cheap trick %%%
vRec = h.exp.data.VRec{expIdx}; % this part is copied from below within runSegmentation(), so it will be overwritten
if iscell(vRec)    
    %vRecSwp = vRec{swpIdx};
    vRecSwpFirst = vRec{swpIdx(1)};
else
    vRecSwpFirst = vRec;
    vRec = {};
    vRec{1} = vRecSwpFirst;
end
%}

% laziness %%%
vRec = h.exp.data.VRec{expIdx};
vRecOriginal = h.exp.data.VRecOriginal{expIdx};
if ~iscell(vRec)    
    vRec = {vRec};
    vRecOriginal = {vRecOriginal};
end
vRecSwpFirst = vRec{swpIdx(1)};
vRecOriginalSwpFirst = vRecOriginal{swpIdx(1)};
try
    dff = h.exp.data.lineScanDFF{expIdx};
    dffOriginal = h.exp.data.lineScanDFFOriginal{expIdx};
    lineScan = h.exp.data.lineScan{expIdx};
    lineScanF = h.exp.data.lineScanF{expIdx};
    lineScanFChannel = h.exp.data.lineScanFChannel{expIdx};
    lineScanROI = h.exp.data.lineScanROI{expIdx};
    lineScanBaseline = h.exp.data.lineScanBaseline{expIdx};
    lineScanCSV = h.exp.data.lineScanCSV{expIdx};
    if ~iscell(dff)
        dff = {dff};
        dffOriginal = {dffOriginal};
        lineScan = {lineScan};
        lineScanF = {lineScanF};
        lineScanFChannel = {lineScanFChannel};
        lineScanROI = {lineScanROI};
        lineScanBaseline = {lineScanBaseline};
        lineScanCSV = {lineScanCSV};
    end
catch ME
end

if length(vRecSwpFirst) == 1800000 % 90 s @ 20 kHz, which is what I use for i-V
    segmentationLength = 5000; % segment length (ms)
elseif length(vRecSwpFirst) == 1200000 % 60 s @ 20 kHz, which is what I used for quick i-V
    segmentationLength = 1000; % segment length (ms)
end

% options
optionsWin = figure('Name', 'Segment Sweeps to Episodic Format', 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.8, 0.6, 0.125, 0.2], 'resize', 'off');
oWin.segmentLengthText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Segment length:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.775, 0.6, 0.125]);
oWin.segmentLengthInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(segmentationLength), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.625, 0.8, 0.175, 0.125]);
oWin.segmentLengthUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.825, 0.775, 0.1, 0.125]);
oWin.segmentOffsetText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Initial cutoff:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.625, 0.6, 0.125]);
oWin.segmentOffsetInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(segmentationOffset), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.625, 0.65, 0.175, 0.125]);
oWin.segmentOffsetUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.825, 0.625, 0.1, 0.125]);
oWin.segmentTruncateText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Truncate remainder:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.475, 0.6, 0.125]);
oWin.segmentTruncateCheck = uicontrol('Parent', optionsWin, 'Style', 'checkbox', 'value', segmentationTruncate, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.625, 0.5, 0.1, 0.125], 'enable', 'off'); % segmentation is currently not working properly if there is remainder %%% fixlater
oWin.segmentCountText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Limit segment count to:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.325, 0.6, 0.125]);
oWin.segmentCountText2 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', ' (0: disable)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.262, 0.6, 0.125]);
oWin.segmentCountCheck = uicontrol('Parent', optionsWin, 'Style', 'checkbox', 'value', 1, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.625, 0.35, 0.1, 0.125]);
oWin.segmentCountInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(segmentationCount), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.725, 0.35, 0.175, 0.125]);
oWin.segmentRun = uicontrol('Parent', optionsWin, 'Style', 'pushbutton', 'string', 'Execute', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.625, 0.05, 0.325, 0.125], 'callback', @runSegmentation, 'interruptible', 'off');

    function runSegmentation(src, ~)
        
        % get parameters
        segmentationLength = str2num(oWin.segmentLengthInput.String); % segment length (ms)
        segmentationOffset = str2num(oWin.segmentOffsetInput.String); % initial offset (ms)
        segmentationTruncate = oWin.segmentTruncateCheck.Value; % truncate remainder (0: no, 1: yes)
        if oWin.segmentCountCheck.Value
            segmentationCount = str2num(oWin.segmentCountInput.String); % keep only this many segments and discard the rest (0 to disable)
        else
            segmentationCount = 0; % 0 to disable
        end
        close(optionsWin); % close window
        if segmentationCount > 0 % only accept positive integers
        else
            segmentationCount = 0; % disable
        end
        
        % do it (read in palpatine voice)
        totalNewSwps = 0;
        for kk = 1:length(swpIdx)
            k = swpIdx(kk);
            [h, segmentCountVRec] = segmentSweepsMain(h, k);
            totalNewSwps = totalNewSwps + segmentCountVRec;
        end
        
        function [h, segmentCountVRec] = segmentSweepsMain(h, k)
            % fetch sweep string
            %swpStr = h.ui.sweepListDisplay.String{swpIdx};
            swpStr = h.ui.sweepListDisplay.String{k};
            
            % fetch data
            try
                vRec = h.exp.data.VRec{expIdx};
                vRecOriginal = h.exp.data.VRecOriginal{expIdx};
                if iscell(vRec)
                    %vRecSwp = vRec{swpIdx};
                    vRecSwp = vRec{k};
                    vRecOriginalSwp = vRecOriginal{k};
                else
                    vRecSwp = vRec;
                    vRec = {};
                    vRec{1} = vRecSwp;
                    vRecOriginalSwp = vRecOriginal;
                    vRecOriginal = {};
                    vRecOriginal{1} = vRecOriginalSwp;
                end
                vRecSamplingInterval = vRecSwp(2, timeColumn) - vRecSwp(1, timeColumn); % (ms)
                segmentationLengthVRec = floor(segmentationLength/vRecSamplingInterval); % converting to points from ms
                segmentationOffsetVRec = floor(segmentationOffset/vRecSamplingInterval); % converting to points from ms
                segmentCountVRec = floor((size(vRecSwp, 1) - segmentationOffsetVRec)/segmentationLengthVRec); % very confusing and poorly chosen variable names...
                if segmentationTruncate == 0
                    segmentCountVRec = segmentCountVRec + 1;
                else
                end
                vRecOriginalSamplingInterval = vRecOriginalSwp(2, timeColumn) - vRecOriginalSwp(1, timeColumn); % (ms); this has to be done too, in case vRec had been boxcar downsampled
                segmentationLengthVRecOriginal = floor(segmentationLength/vRecOriginalSamplingInterval); % converting to points from ms
                segmentationOffsetVRecOriginal = floor(segmentationOffset/vRecOriginalSamplingInterval); % converting to points from ms
                segmentCountVRecOriginal = floor((size(vRecOriginalSwp, 1) - segmentationOffsetVRecOriginal)/segmentationLengthVRecOriginal); % very confusing and poorly chosen variable names...
                if segmentationTruncate == 0
                    segmentCountVRecOriginal = segmentCountVRecOriginal + 1; % this is redundant...
                else
                end
            catch ME
            end
            try
                dff = h.exp.data.lineScanDFF{expIdx}; % will work as intended for single-experiment cases?
                dffOriginal = h.exp.data.lineScanDFFOriginal{expIdx}; % will work as intended for single-experiment cases?
                %dffSwp = dff{swpIdx};
                dffSwp = dff{k};
                dffSamplingInterval = dffSwp(2, timeColumn) - dffSwp(1, timeColumn); % (ms)
                segmentationLengthDFF = floor(segmentationLength/dffSamplingInterval); % converting to points from ms
                segmentationOffsetDFF = floor(segmentationOffset/dffSamplingInterval); % converting to points from ms
                segmentCountDFF = floor((size(dffSwp, 1) - segmentationOffsetDFF)/segmentationLengthDFF); % very confusing and poorly chosen variable names...
                if segmentationTruncate == 0
                    segmentCountDFF = segmentCountDFF + 1;
                else
                end
                dffOriginalSwp = dffOriginal{k};
                dffOriginalSamplingInterval = dffOriginalSwp(2, timeColumn) - dffOriginalSwp(1, timeColumn); % (ms)
                segmentationLengthDFFOriginal = floor(segmentationLength/dffOriginalSamplingInterval); % converting to points from ms
                segmentationOffsetDFFOriginal = floor(segmentationOffset/dffOriginalSamplingInterval); % converting to points from ms
                segmentCountDFFOriginal = floor((size(dffOriginalSwp, 1) - segmentationOffsetDFFOriginal)/segmentationLengthDFFOriginal); % very confusing and poorly chosen variable names...
                if segmentationTruncate == 0
                    segmentCountDFFOriginal = segmentCountDFFOriginal + 1; % also redundant
                else
                end
            catch ME
            end
            if segmentCountVRec > 1000
                error(sprintf('Error: too many segments for sweep %s', num2str(k)));
                return
            end
            
            % segment data
            try
                if segmentationCount ~= 0 && segmentationCount < segmentCountVRec
                    segmentCountVRec = segmentationCount;
                end
                vRecNew = cell(1, segmentCountVRec);
                vRecOriginalNew = cell(1, segmentCountVRec);
                for i = 1:segmentCountVRec
                    try
                        for j = 1:segmentationLengthVRec % points
                            vRecNewTemp(j, :) = vRecSwp(segmentationOffsetVRec + (i-1)*segmentationLengthVRec + j, :);
                        end
                        for j = 1:segmentationLengthVRecOriginal % points
                            vRecOriginalNewTemp(j, :) = vRecOriginalSwp(segmentationOffsetVRecOriginal + (i-1)*segmentationLengthVRecOriginal + j, :);
                        end
                        vRecNewTemp(:, 1) = vRecSwp(1:segmentationLengthVRec, 1); % timestamp needs to be reset for each sub-sweep
                        vRecOriginalNewTemp(:, 1) = vRecOriginalSwp(1:segmentationLengthVRecOriginal, 1); % timestamp needs to be reset for each sub-sweep
                        vRecNew{i} = vRecNewTemp;
                        vRecOriginalNew{i} = vRecOriginalNewTemp;
                    catch ME
                        vRecNew{i} = [];
                        vRecOriginalNew{i} = [];
                    end
                end
            catch ME
            end
            try
                if segmentationCount ~= 0 && segmentationCount < segmentCountDFF
                    segmentCountDFF = segmentationCount;
                end
                % override - force to match size with V %%% idiot %%%%%%% %%%%%%%%%
                segmentCountDFF = segmentCountVRec;
                dffNew = cell(1, segmentCountDFF);
                dffOriginalNew = cell(1, segmentCountDFF);
                lineScanNew = lineScan(:, end);
                lineScanFNew = lineScanF(:, end);
                lineScanFChannelNew = lineScanFChannel(:, end);
                lineScanROINew = lineScanROI(:, end);
                %lineScanBaselineNew = lineScanBaseline(:, end);
                lineScanBaselineNew = [];
                lineScanCSVNew = lineScanCSV(:, end);
                for i = 1:length(lineScanNew) % should be the same for all
                    lineScanNew{i} = [];
                    lineScanFNew{i} = [];
                    lineScanFChannelNew{i} = [];
                    lineScanROINew{i} = [];
                    %lineScanBaselineNew{i} = [];
                    lineScanCSVNew{i} = [];
                end
                for i = 1:segmentCountDFF
                    try
                        for j = 1:segmentationLengthDFF % points
                            dffNewTemp(j, :) = dffSwp(segmentationOffsetDFF + (i-1)*segmentationLengthDFF + j, :);
                        end
                        for j = 1:segmentationLengthDFFOriginal % points
                            dffOriginalNewTemp(j, :) = dffOriginalSwp(segmentationOffsetDFFOriginal + (i-1)*segmentationLengthDFFOriginal + j, :);
                        end
                        dffNewTemp(:, 1) = dffSwp(1:segmentationLengthDFF, 1); % timestamp needs to be reset for each sub-sweep
                        dffOriginalNewTemp(:, 1) = dffOriginalSwp(1:segmentationLengthDFFOriginal, 1); % timestamp needs to be reset for each sub-sweep
                        dffNew{i} = dffNewTemp;
                        dffOriginalNew{i} = dffOriginalNewTemp;
                    catch ME
                        dffNew{i} = [];
                        dffOriginalNew{i} = [];
                    end
                end
                %{
            if segmentCountDFF < segmentCountVRec % could easily happen because linescans will be typically shorter than VRec
                for i = segmentCountVRec - segmentCountDFF : segmentCountVRec
                    for j = 1:segmentationLengthDFF % points
                        dffNewTemp(j, :) = NaN; % fill with null points
                    end
                    dffNewTemp(:, 1) = dffSwp(1:segmentationLengthDFF, 1); % timestamp needs to be reset for each sub-sweep
                    dffNew{i} = dffNewTemp;
                end
            end
            if segmentCountDFF > segmentCountVRec % should not really happen, but for safety
                for i = 1 : segmentCountDFF - segmentCountVRec
                    dffNew{end - i} = []; % ablate leftovers
                end
            end
                %}
            catch ME
            end
            
            % fill data for new sweep indices
            try
                for i = 1:segmentCountVRec
                    vRec{end + 1} = vRecNew{i};
                    vRecOriginal{end + 1} = vRecOriginalNew{i};
                    sweepIdx(end + 1) = sweepIdx(end) + 1; % append sweep index
                    %sweepIdx(end + 1) = k + i*0.001; % append sweep index
                    sweepStr{end + 1} = num2str(k + i*0.001, '%.3f'); % append sweep index
                    if lastSweepDeleted % a better way would be to check this only while i == 1, but well...
                        %sweepIdx(end) = sweepIdx(end) + 1; % increase 1 more to account for the last sweep that had been deleted %%% obsolete
                        lastSweepDeleted = 0; % update flag
                        h.params.lastSweepDeleted = lastSweepDeleted;
                    end
                end
                h.exp.data.VRec{expIdx} = vRec;
                h.exp.data.VRecOriginal{expIdx} = vRecOriginal;
                h.exp.data.sweepIdx{expIdx} = sweepIdx;
                h.exp.data.sweepStr{expIdx} = sweepStr;
                h.exp.sweeps{expIdx} = length(vRec); % this is unfortunately not entirely vestigial; used in old old analysis code
            catch ME
            end
            % below will result in non-matching number of "sweeps" for V and F
            % %%% need fix
            %%{
            try
                %for i = 1:segmentCountVRec % force to match segment count of VRec (doesn't matter which is longer)
                for i = 1:segmentCountDFF
                    if i <= length(dffNew)
                        if isempty(dffNew{i})
                            dff{end + 1} = [];
                            dffOriginal{end + 1} = [];
                            lineScan = [lineScan, lineScanNew]; % for multiple channels
                            lineScanF = [lineScanF, lineScanFNew];
                            lineScanFChannel = [lineScanFChannel, lineScanFChannelNew];
                            lineScanROI = [lineScanROI, lineScanROINew];
                            %lineScanBaseline = [lineScanBaseline, lineScanBaselineNew];
                            lineScanCSV = [lineScanCSV, lineScanCSVNew];
                        else
                            dff{end + 1} = dffNew{i};
                            dffOriginal{end + 1} = dffOriginalNew{i};
                            lineScan = [lineScan, lineScanNew]; % for multiple channels
                            lineScanF = [lineScanF, lineScanFNew];
                            lineScanFChannel = [lineScanFChannel, lineScanFChannelNew];
                            lineScanROI = [lineScanROI, lineScanROINew];
                            %lineScanBaseline = [lineScanBaseline, lineScanBaselineNew];
                            lineScanCSV = [lineScanCSV, lineScanCSVNew];
                        end
                    else
                        dff{end + 1} = [];
                        dffOriginal{end + 1} = [];
                        lineScan = [lineScan, lineScanNew]; % for multiple channels
                        lineScanF = [lineScanF, lineScanFNew];
                        lineScanFChannel = [lineScanFChannel, lineScanFChannelNew];
                        lineScanROI = [lineScanROI, lineScanROINew];
                        %lineScanBaseline = [lineScanBaseline, lineScanBaselineNew];
                        lineScanCSV = [lineScanCSV, lineScanCSVNew];
                    end
                end
                h.exp.data.lineScanDFF{expIdx} = dff;
                h.exp.data.lineScanDFFOriginal{expIdx} = dffOriginal;
                h.exp.data.lineScan{expIdx} = lineScan;
                h.exp.data.lineScanF{expIdx} = lineScanF;
                h.exp.data.lineScanFChannel{expIdx} = lineScanFChannel;
                h.exp.data.lineScanROI{expIdx} = lineScanROI;
                h.exp.data.lineScanBaseline{expIdx} = lineScanBaseline;
                h.exp.data.lineScanCSV{expIdx} = lineScanCSV;
            catch ME
            end
            %}
            
        end
        
        % draw traces
        h = displayTrace(h, expIdx); % this also populates sweep list and sets up strings, etc.
        
        % keep original sweep highlighted
        %{
h.ui.sweepListDisplay.Value = swpIdx;
h = highlightSweep(h, swpIdx);
%set(h.ui.groupSweepText, 'string', sprintf('Sweep %.0f', swpStr));
%set(h.ui.groupSweepText, 'string', sprintf('Sweep %s', num2str(swpIdx)));
if length(swpIdx) == 1
    set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', sweepStr{swpIdx}));
else
    set(h.ui.groupSweepText, 'string', sprintf('(%s Swps)', num2str(length(swpIdx))));
end
        %}
        
        % highlight new sweeps
        swpTotal = length(h.ui.sweepListDisplay.String);
        swpNewIdx = swpTotal - totalNewSwps + 1 : swpTotal;
        h.ui.sweepListDisplay.Value = swpNewIdx;
        h = highlightSweep(h, swpNewIdx);
        %set(h.ui.groupSweepText, 'string', sprintf('Sweep %.0f', swpStr));
        %set(h.ui.groupSweepText, 'string', sprintf('Sweep %s', num2str(swpIdx)));
        if length(swpNewIdx) == 1
            set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', sweepStr{swpNewIdx}));
        else
            set(h.ui.groupSweepText, 'string', sprintf('(%s Swps)', num2str(length(swpNewIdx))));
        end
        
        % set sub-sweep names - obsolete
        %{
sweepNumOriginal = length(h.ui.sweepListDisplay);
swpStrNew = h.ui.sweepListDisplay.String;
for i = 1:segmentCountVRec % NB. segmentCountVRec == segmentCountDFF
    subSwpStr = sprintf(['.', '%03.f'], i);
    subSwpStr = [swpStr, subSwpStr];
    %swpStrNew{end + 1} = subSwpStr;
    swpStrNew{end - segmentCountVRec + i} = subSwpStr;
end
set(h.ui.sweepListDisplay, 'string', swpStrNew);
        %}
        
        guidata(winMain, h);
        
    end

% save
%guidata(src, h);

end


function sweepsTruncate(src, ~)
% truncate selected sweeps

% load
h = guidata(src);
winMain = src;
if isempty(h.ui.cellListDisplay.String)
    return
end

% fetch default parameters ... but see "cheap trick" below
actualParams = h.params.actualParams;
truncationLength = actualParams.segmentationLength; % truncation length (ms); just reuse default value for segmentation
truncationInitialCutoff = 0; % initial cutoff (ms), before truncation; 0 is reasonable
timeColumn = actualParams.timeColumn; % column 1: timestamp
pvbsVoltageColumn = actualParams.pvbsVoltageColumn; % column 2: voltage
lastSweepDeleted = h.params.lastSweepDeleted; % flag indicating if last sweep had been deleted

% experiment and sweep number
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
swpIdx = h.ui.sweepListDisplay.Value;
expCount = length(h.ui.cellListDisplay);
swpCount = length(h.ui.sweepListDisplay);
sweepIdx = h.exp.data.sweepIdx{expIdx}; % again very poor choice of variable name in hindsight
sweepStr = h.exp.data.sweepStr{expIdx};
%swpIdx = sweepIdx(swpIdx);

% force single selection
if length(expIdx) > 1
    expIdx = expIdx(1);
    h.ui.cellListDisplay.Value = expIdx;
end
%{
if length(swpIdx) > 1
    swpIdx = swpIdx(1);
    h.ui.sweepListDisplay.Value = swpIdx;
end
%}

% cheap trick
%  (number of groups) = (number of uncaging points) + 1 
%  ... for uncaging experiments done my way
try
truncationLength = truncationLength * length(h.exp.data.groupIdx{expIdx});
catch ME
end

% options
optionsWin = figure('Name', 'Truncate Sweeps', 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.8, 0.6, 0.125, 0.2], 'resize', 'off');
oWin.truncationLengthText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Truncate sweeps to:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.775, 0.6, 0.125]);
oWin.truncationLengthInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(truncationLength), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.625, 0.8, 0.175, 0.125]);
oWin.truncationLengthUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.825, 0.775, 0.1, 0.125]);
oWin.truncationOffsetText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Initial cutoff:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.625, 0.6, 0.125]);
oWin.truncationOffsetInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(truncationInitialCutoff), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.625, 0.65, 0.175, 0.125]);
oWin.truncationOffsetUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.825, 0.625, 0.1, 0.125]);
oWin.truncationRun = uicontrol('Parent', optionsWin, 'Style', 'pushbutton', 'string', 'Execute', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.625, 0.05, 0.325, 0.125], 'callback', @runTruncation, 'interruptible', 'off');

    function runTruncation(src, ~)
        
        % get parameters
        truncationLength = str2num(oWin.truncationLengthInput.String); % truncation length (ms)
        truncationOffset = str2num(oWin.truncationOffsetInput.String); % initial offset (ms)
        close(optionsWin); % close window
        
        % do it (read in palpatine voice)
        totalNewSwps = 0;
        for kk = 1:length(swpIdx)
            k = swpIdx(kk);
            h = truncateSweepsMain(h, k);
        end
        
        function h = truncateSweepsMain(h, k)
            % fetch sweep string
            %swpStr = h.ui.sweepListDisplay.String{swpIdx};
            swpStr = h.ui.sweepListDisplay.String{k};
            
            % fetch data
            try
                vRec = h.exp.data.VRec{expIdx};
                vRecOriginal = h.exp.data.VRecOriginal{expIdx};
                if iscell(vRec)
                    %vRecSwp = vRec{swpIdx};
                    vRecSwp = vRec{k};
                    vRecOriginalSwp = vRecOriginal{k};
                else
                    vRecSwp = vRec;
                    vRec = {};
                    vRec{1} = vRecSwp;
                    vRecOriginalSwp = vRecOriginal;
                    vRecOriginal = {};
                    vRecOriginal{1} = vRecOriginalSwp;
                end
                vRecSamplingInterval = vRecSwp(2, timeColumn) - vRecSwp(1, timeColumn); % (ms)
                truncationLengthVRec = floor(truncationLength/vRecSamplingInterval); % converting to points from ms
                truncationOffsetVRec = floor(truncationOffset/vRecSamplingInterval); % converting to points from ms
                vRecOriginalSamplingInterval = vRecOriginalSwp(2, timeColumn) - vRecOriginalSwp(1, timeColumn); % (ms)
                truncationLengthVRecOriginal = floor(truncationLength/vRecOriginalSamplingInterval); % converting to points from ms
                truncationOffsetVRecOriginal = floor(truncationOffset/vRecOriginalSamplingInterval); % converting to points from ms
            catch ME
            end
            try
                dff = h.exp.data.lineScanDFF{expIdx}; % will work as intended for single-experiment cases?
                dffOriginal = h.exp.data.lineScanDFFOriginal{expIdx};
                %dffSwp = dff{swpIdx};
                dffSwp = dff{k};
                dffSamplingInterval = dffSwp(2, timeColumn) - dffSwp(1, timeColumn); % (ms)
                truncationLengthDFF = floor(truncationLength/dffSamplingInterval); % converting to points from ms
                truncationOffsetDFF = floor(truncationOffset/dffSamplingInterval); % converting to points from ms
                dffOriginalSwp = dffOriginal{k};
                dffOriginalSamplingInterval = dffOriginalSwp(2, timeColumn) - dffOriginalSwp(1, timeColumn); % (ms)
                truncationLengthDFFOriginal = floor(truncationLength/dffOriginalSamplingInterval); % converting to points from ms
                truncationOffsetDFFOriginal = floor(truncationOffset/dffOriginalSamplingInterval); % converting to points from ms
            catch ME
            end
            
            % truncate data
            try
                vRecSwpNew = vRecSwp(truncationOffsetVRec + 1 : truncationOffsetVRec + truncationLengthVRec, :);
                vRecSwpNew(1:truncationLengthVRec, 1) = vRecSwp(1:truncationLengthVRec, 1); % resetting timestamp start point
                vRec{k} = vRecSwpNew;
                vRecOriginalSwpNew = vRecOriginalSwp(truncationOffsetVRecOriginal + 1 : truncationOffsetVRecOriginal + truncationLengthVRecOriginal, :);
                vRecOriginalSwpNew(1:truncationLengthVRecOriginal, 1) = vRecSwp(1:truncationLengthVRecOriginal, 1); % resetting timestamp start point
                vRecOriginal{k} = vRecOriginalSwpNew;
            catch ME
            end
            try
                dffSwpNew = dffSwp(truncationOffsetDFF + 1 : truncationOffsetDFF + truncationLengthDFF, :);
                dffSwpNew(1:truncationLengthDFF, 1) = dffSwp(1:truncationLengthDFF, 1); % resetting timestamp start point
                dff{k} = dffSwpNew;
                dffOriginalSwpNew = dffOriginalSwp(truncationOffsetDFFOriginal + 1 : truncationOffsetDFFOriginal + truncationLengthDFFOriginal, :);
                dffOriginalSwpNew(1:truncationLengthDFFOriginal, 1) = dffOriginalSwp(1:truncationLengthDFFOriginal, 1); % resetting timestamp start point
                dffOriginal{k} = dffOriginalSwpNew;
            catch ME
            end
            h.exp.data.VRec{expIdx} = vRec;
            h.exp.data.VRecOriginal{expIdx} = vRecOriginal;
            h.exp.data.dff{expIdx} = dff;
            h.exp.data.dffOriginal{expIdx} = dffOriginal;

        end
        
        % draw traces
        h = displayTrace(h, expIdx); % this also populates sweep list and sets up strings, etc.
        h = highlightSweep(h, swpIdx); % maintain highlight at originally selected sweeps
        
        % save
        guidata(winMain, h);
        
    end

% save
%guidata(src, h);

end


function sweepsAverage(src, ~)
% average selected sweeps into a new sweep

% load
h = guidata(src);
winMain = src;
if isempty(h.ui.cellListDisplay.String)
    return
end

% fetch default parameters
actualParams = h.params.actualParams;
timeColumn = actualParams.timeColumn; % column 1: timestamp
pvbsVoltageColumn = actualParams.pvbsVoltageColumn; % column 2: voltage
lastSweepDeleted = h.params.lastSweepDeleted; % flag indicating if last sweep had been deleted

% experiment and sweep number
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
swpIdx = h.ui.sweepListDisplay.Value;
expCount = length(h.ui.cellListDisplay);
swpCount = length(h.ui.sweepListDisplay);
sweepIdx = h.exp.data.sweepIdx{expIdx}; % again very poor choice of variable name in hindsight
sweepStr = h.exp.data.sweepStr{expIdx};
%swpIdx = sweepIdx(swpIdx);

% do nothing if no item or only one item was selected
if isempty(swpIdx)
    return
elseif length(swpIdx) == 1 
    return
end

% force single selection for experiment
if length(expIdx) > 1
    expIdx = expIdx(1);
    h.ui.cellListDisplay.Value = expIdx;
end
%{
if length(swpIdx) > 1
    swpIdx = swpIdx(1);
    h.ui.sweepListDisplay.Value = swpIdx;
end
%}

% laziness %%%
vRec = h.exp.data.VRec{expIdx};
vRecOriginal = h.exp.data.VRecOriginal{expIdx};
if ~iscell(vRec)    
    vRec = {vRec};
    vRecOriginal = {vRecOriginal};
end
try
    dff = h.exp.data.lineScanDFF{expIdx};
    dffOriginal = h.exp.data.lineScanDFFOriginal{expIdx};
    lineScan = h.exp.data.lineScan{expIdx};
    lineScanF = h.exp.data.lineScanF{expIdx};
    lineScanFChannel = h.exp.data.lineScanFChannel{expIdx};
    lineScanROI = h.exp.data.lineScanROI{expIdx};
    lineScanBaseline = h.exp.data.lineScanBaseline{expIdx};
    lineScanCSV = h.exp.data.lineScanCSV{expIdx};
    if ~iscell(dff)
        dff = {dff};
        dffOriginal = {dffOriginal};
        lineScan = {lineScan};
        lineScanF = {lineScanF};
        lineScanFChannel = {lineScanFChannel};
        lineScanROI = {lineScanROI};
        lineScanBaseline = {lineScanBaseline};
        lineScanCSV = {lineScanCSV};
    end
catch ME
end

% do average for V
try
    vRecNew = doSweepsAverage(vRec);
    vRecOriginalNew = doSweepsAverage(vRecOriginal);
catch ME
    vRecNew = [];
    vRecOriginalNew = [];
    fprintf('Averaging aborted for V: dimension or timestamp mismatch\n');
end
%{
vRecNew = zeros(size(vRec{swpIdx(1)}));
timeStamps = [];
try
    for i = swpIdx % NB. relative indices
        vRecNew = vRecNew + vRec{i};
        timeStampNew = vRec{i};
        timeStampNew = timeStampNew(:, timeColumn);
        timeStamps = [timeStamps, timeStampNew]; % needed for timestamp check
    end
    vRecNew = vRecNew / length(swpIdx);
catch ME
    vRecNew = [];
    fprintf('Averaging aborted for V: dimension mismatch\n');
end
%  timestamp check
try
    for i = size(timeStamps, 1)
        if all(timeStamps(i, :) == timeStamps(i, 1))
        else
            vRecNew = [];
            fprintf('Averaging aborted for V: timestamp mismatch\n');
        end
    end
catch ME
    vRecNew = [];
    fprintf('Averaging aborted for V: timestamp mismatch\n');
end
%}

% do average for F
try
    dffNew = doSweepsAverage(dff);
    dffOriginalNew = doSweepsAverage(dffOriginal);
    lineScanNew = lineScan(:, end);
    lineScanFNew = lineScanF(:, end);
    lineScanFChannelNew = lineScanFChannel(:, end);
    lineScanROINew = lineScanROI(:, end);
    %lineScanBaselineNew = lineScanBaseline(:, end);
    lineScanBaselineNew = [];
    lineScanCSVNew = lineScanCSV(:, end);
    for i = 1:length(lineScanNew) % should be the same for all
        lineScanNew{i} = [];
        lineScanFNew{i} = [];
        lineScanFChannelNew{i} = [];
        lineScanROINew{i} = [];
        %lineScanBaselineNew{i} = [];
        lineScanCSVNew{i} = [];
    end
catch ME
    dffNew = [];
    dffOriginalNew = [];
    lineScanNew = [];
    lineScanFNew = [];
    lineScanFChannelNew = [];
    lineScanROINew = [];
    lineScanBaselineNew = [];
    lineScanCSVNew = [];
    fprintf('Averaging aborted for F: dimension or timestamp mismatch\n');
end
%{
dffNew = zeros(size(dff{swpIdx(1)}));
timeStamps = [];
try
    for i = swpIdx % NB. relative indices
        dffNew = dffNew + dff{i};
        timeStampNew = dff{i};
        timeStampNew = timeStampNew(:, timeColumn);
        timeStamps = [timeStamps, timeStampNew]; % needed for timestamp check
    end
    dffNew = dffNew / length(swpIdx);
catch ME
    dffNew = [];
    fprintf('Averaging aborted for F: dimension mismatch\n');
end
%  timestamp check
try
    for i = size(timeStamps, 1)
        if all(timeStamps(i, :) == timeStamps(i, 1))
        else
            dffNew = [];
            fprintf('Averaging aborted for F: timestamp mismatch\n');
        end
    end
catch ME
    dffNew = [];
    fprintf('Averaging aborted for F: timestamp mismatch\n');
end
%}

% actual working function
    function newDataCell = doSweepsAverage(dataCell)
        newDataCell = zeros(size(dataCell{swpIdx(1)}));
        timeStamps = [];
        %try
            for i = swpIdx % NB. relative indices
                newDataCell = newDataCell + dataCell{i};
                timeStampNew = dataCell{i};
                timeStampNew = timeStampNew(:, timeColumn);
                timeStamps = [timeStamps, timeStampNew]; % needed for timestamp check
            end
            newDataCell = newDataCell / length(swpIdx);
            %{
        catch ME
            newDataCell = [];
            fprintf('Averaging aborted for V: dimension mismatch\n');
        end
            %}
        %  timestamp check
        %try
            for i = size(timeStamps, 1)
                if all(timeStamps(i, :) == timeStamps(i, 1))
                else
                    newDataCell = [];
                    fprintf('Averaging aborted for V: timestamp mismatch\n');
                end
            end
            %{
        catch ME
            newDataCell = [];
            fprintf('Averaging aborted for V: timestamp mismatch\n');
        end
            %}
    end

% fill data into new sweep
%  check if any averaging was actually done
try
    if isempty(vRecNew) && isempty(dffNew)
        fprintf('No average calculated.\n\n');
        return
    else
        %fprintf('\n');
    end
    %  string for new sweep
    newSwpStr = '';
    for i = swpIdx
        newSwpStr = [newSwpStr, num2str(i), '+'];
    end
    newSwpStr = newSwpStr(1:end - 1);
    newSwpStr = ['(', newSwpStr, ')', '/', num2str(length(swpIdx))];
    %  filling in data
    vRec{end + 1} = vRecNew;
    vRecOriginal{end + 1} = vRecOriginalNew;
    sweepIdx(end + 1) = sweepIdx(end) + 1; % append sweep index
    sweepStr{end + 1} = newSwpStr; % append sweep index
    if lastSweepDeleted % a better way would be to check this only while i == 1, but well...
        %sweepIdx(end) = sweepIdx(end) + 1; % increase 1 more to account for the last sweep that had been deleted %%% obsolete
        lastSweepDeleted = 0; % update flag
        h.params.lastSweepDeleted = lastSweepDeleted;
    end
    h.exp.data.VRec{expIdx} = vRec;
    h.exp.data.VRecOriginal{expIdx} = vRecOriginal;
    h.exp.data.sweepIdx{expIdx} = sweepIdx;
    h.exp.data.sweepStr{expIdx} = sweepStr;
    h.exp.sweeps{expIdx} = length(vRec); % this is unfortunately not entirely vestigial; used in old old analysis code
    %  filling in data for F - this order assumes that there will be no instances with F only
    try
        dff{end + 1} = dffNew;
        dffOriginal{end + 1} = dffOriginalNew;
        h.exp.data.lineScanDFF{expIdx} = dff;
        h.exp.data.lineScanDFFOriginal{expIdx} = dffOriginal;
        lineScan = [lineScan, lineScanNew]; % for multiple channels
        lineScanF = [lineScanF, lineScanFNew];
        lineScanFChannel = [lineScanFChannel, lineScanFChannelNew];
        lineScanROI = [lineScanROI, lineScanROINew];
        %lineScanBaseline = [lineScanBaseline, lineScanBaselineNew];
        lineScanCSV = [lineScanCSV, lineScanCSVNew];
        h.exp.data.lineScan{expIdx} = lineScan;
        h.exp.data.lineScanF{expIdx} = lineScanF;
        h.exp.data.lineScanFChannel{expIdx} = lineScanFChannel;
        h.exp.data.lineScanROI{expIdx} = lineScanROI;
        h.exp.data.lineScanBaseline{expIdx} = lineScanBaseline;
        h.exp.data.lineScanCSV{expIdx} = lineScanCSV;
    catch ME
    end
catch ME
end

% draw traces
h = displayTrace(h, expIdx); % this also populates sweep list and sets up strings, etc.

% highlight new sweeps
swpNewIdx = length(h.ui.sweepListDisplay.String); % last sweep
h.ui.sweepListDisplay.Value = swpNewIdx;
h = highlightSweep(h, swpNewIdx);
if length(swpNewIdx) == 1
    set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', sweepStr{swpNewIdx}));
else
    set(h.ui.groupSweepText, 'string', sprintf('(%s Swps)', num2str(length(swpNewIdx))));
end

% save
guidata(src, h);

end


function sweepsAdd(src, ~)
% add selected sweeps (baseline-aligned) into a new sweep

% load
h = guidata(src);
winMain = src;
if isempty(h.ui.cellListDisplay.String)
    return
end

% fetch default parameters
actualParams = h.params.actualParams;
timeColumn = actualParams.timeColumn; % column 1: timestamp
pvbsVoltageColumn = actualParams.pvbsVoltageColumn; % column 2: voltage
lastSweepDeleted = h.params.lastSweepDeleted; % flag indicating if last sweep had been deleted

% experiment and sweep number
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
swpIdx = h.ui.sweepListDisplay.Value;
expCount = length(h.ui.cellListDisplay);
swpCount = length(h.ui.sweepListDisplay);
sweepIdx = h.exp.data.sweepIdx{expIdx}; % again very poor choice of variable name in hindsight
sweepStr = h.exp.data.sweepStr{expIdx};
%swpIdx = sweepIdx(swpIdx);

% do nothing if no item or only one item was selected
if isempty(swpIdx)
    return
elseif length(swpIdx) == 1 
    return
end

% force single selection for experiment
if length(expIdx) > 1
    expIdx = expIdx(1);
    h.ui.cellListDisplay.Value = expIdx;
end
%{
if length(swpIdx) > 1
    swpIdx = swpIdx(1);
    h.ui.sweepListDisplay.Value = swpIdx;
end
%}

% laziness %%%
vRec = h.exp.data.VRec{expIdx};
vRecOriginal = h.exp.data.VRecOriginal{expIdx};
if ~iscell(vRec)    
    vRec = {vRec};
    vRecOriginal = {vRecOriginal};
end
try
    dff = h.exp.data.lineScanDFF{expIdx};
    dffOriginal = h.exp.data.lineScanDFFOriginal{expIdx};
    lineScan = h.exp.data.lineScan{expIdx};
    lineScanF = h.exp.data.lineScanF{expIdx};
    lineScanFChannel = h.exp.data.lineScanFChannel{expIdx};
    lineScanROI = h.exp.data.lineScanROI{expIdx};
    lineScanBaseline = h.exp.data.lineScanBaseline{expIdx};
    lineScanCSV = h.exp.data.lineScanCSV{expIdx};
    if ~iscell(dff)
        dff = {dff};
        dffOriginal = {dffOriginal};
        lineScan = {lineScan};
        lineScanF = {lineScanF};
        lineScanFChannel = {lineScanFChannel};
        lineScanROI = {lineScanROI};
        lineScanBaseline = {lineScanBaseline};
        lineScanCSV = {lineScanCSV};
    end
catch ME
end

baselineWindow = h.params.analysisBaseline; % baseline (ms)

% sum V
vRecNew = doSweepsAddV(vRec);
vRecOriginalNew = doSweepsAddV(vRecOriginal);
    function outputCell = doSweepsAddV(inputCell)
        try
            outputCell = zeros(size(inputCell{swpIdx(1)}));
            timeStampNew = inputCell{swpIdx(1)};
            timeStampNew = timeStampNew(:, timeColumn);
            vRecInterval = timeStampNew(2) - timeStampNew(1);
            vRecBaselineWindow = floor(baselineWindow/vRecInterval) + 1; % converting to points from ms
            vRecBaseline = [];
            for i = swpIdx % NB. relative indices
                vRecBaselineTemp = inputCell{i};
                vRecBaselineTemp = nanmean(vRecBaselineTemp(vRecBaselineWindow(1):vRecBaselineWindow(2), pvbsVoltageColumn));
                outputCell = outputCell + inputCell{i} - vRecBaselineTemp; % align to sweep baseline
                vRecBaseline(end + 1) = vRecBaselineTemp;
                timeStampNew = inputCell{i};
                timeStampNew = timeStampNew(:, timeColumn);
            end
            vRecBaseline = nanmean(vRecBaseline);
            outputCell = outputCell + vRecBaseline;
            outputCell(:, timeColumn) = timeStampNew; % overwrite timestamp
        catch ME
            outputCell = [];
            fprintf('Summation aborted for V: dimension mismatch\n');
        end
    end

% sum F
dffNew = doSweepsAddF(dff);
dffOriginalNew = doSweepsAddF(dffOriginal);
lineScanNew = lineScan(:, end);
lineScanFNew = lineScanF(:, end);
lineScanFChannelNew = lineScanFChannel(:, end);
lineScanROINew = lineScanROI(:, end);
%lineScanBaselineNew = lineScanBaseline(:, end);
lineScanBaselineNew = [];
lineScanCSVNew = lineScanCSV(:, end);
for i = 1:length(lineScanNew) % should be the same for all
    lineScanNew{i} = [];
    lineScanFNew{i} = [];
    lineScanFChannelNew{i} = [];
    lineScanROINew{i} = [];
    %lineScanBaselineNew{i} = [];
    lineScanCSVNew{i} = [];
end
    function outputCell = doSweepsAddF(inputCell)
        try
            outputCell = zeros(size(inputCell{swpIdx(1)}));
            timeStampNew = inputCell{swpIdx(1)};
            timeStampNew = timeStampNew(:, timeColumn);
            dffInterval = timeStampNew(2) - timeStampNew(1);
            dffBaselineWindow = floor(baselineWindow/dffInterval) + 1; % converting to points from ms
            dffBaseline = [];
            fColumn = 2; % column for channel 1 (column 1: timestamp) - needs to be refined %%% fixlater
            for i = swpIdx % NB. relative indices
                dffBaselineTemp = inputCell{i};
                dffBaselineTemp = nanmean(dffBaselineTemp(dffBaselineWindow(1):dffBaselineWindow(2), fColumn));
                outputCell = outputCell + inputCell{i} - dffBaselineTemp; % align to sweep baseline
                dffBaseline(end + 1) = dffBaselineTemp;
                timeStampNew = inputCell{i};
                timeStampNew = timeStampNew(:, timeColumn);
            end
            dffBaseline = nanmean(dffBaseline);
            outputCell = outputCell + dffBaseline;
            outputCell(:, timeColumn) = timeStampNew; % overwrite timestamp
        catch ME
            outputCell = [];
            fprintf('Summation aborted for F: dimension mismatch\n');
        end
    end

% fill data into new sweep
%  check if any averaging was actually done
try
    if isempty(vRecNew) && isempty(dffNew)
        fprintf('No result produced.\n\n');
        return
    else
        %fprintf('\n');
    end
    %  string for new sweep
    newSwpStr = '';
    for i = swpIdx
        newSwpStr = [newSwpStr, num2str(i), '+'];
    end
    newSwpStr = newSwpStr(1:end - 1);
    newSwpStr = ['(', newSwpStr, ')'];
    %  filling in data
    vRec{end + 1} = vRecNew;
    vRecOriginal{end + 1} = vRecOriginalNew;
    sweepIdx(end + 1) = sweepIdx(end) + 1; % append sweep index
    sweepStr{end + 1} = newSwpStr; % append sweep index
    if lastSweepDeleted % a better way would be to check this only while i == 1, but well...
        %sweepIdx(end) = sweepIdx(end) + 1; % increase 1 more to account for the last sweep that had been deleted %%% obsolete
        lastSweepDeleted = 0; % update flag
        h.params.lastSweepDeleted = lastSweepDeleted;
    end
    h.exp.data.VRec{expIdx} = vRec;
    h.exp.data.VRecOriginal{expIdx} = vRecOriginal;
    h.exp.data.sweepIdx{expIdx} = sweepIdx;
    h.exp.data.sweepStr{expIdx} = sweepStr;
    h.exp.sweeps{expIdx} = length(vRec); % this is unfortunately not entirely vestigial; used in old old analysis code
    %  filling in data for F - this order assumes that there will be no instances with F only
    try
        dff{end + 1} = dffNew;
        dffOriginal{end + 1} = dffOriginalNew;
        h.exp.data.lineScanDFF{expIdx} = dff;
        h.exp.data.lineScanDFFOriginal{expIdx} = dffOriginal;
        lineScan = [lineScan, lineScanNew]; % for multiple channels
        lineScanF = [lineScanF, lineScanFNew];
        lineScanFChannel = [lineScanFChannel, lineScanFChannelNew];
        lineScanROI = [lineScanROI, lineScanROINew];
        %lineScanBaseline = [lineScanBaseline, lineScanBaselineNew];
        lineScanCSV = [lineScanCSV, lineScanCSVNew];
        h.exp.data.lineScan{expIdx} = lineScan;
        h.exp.data.lineScanF{expIdx} = lineScanF;
        h.exp.data.lineScanFChannel{expIdx} = lineScanFChannel;
        h.exp.data.lineScanROI{expIdx} = lineScanROI;
        h.exp.data.lineScanBaseline{expIdx} = lineScanBaseline;
        h.exp.data.lineScanCSV{expIdx} = lineScanCSV;
    catch ME
    end
catch ME
end

% draw traces
h = displayTrace(h, expIdx); % this also populates sweep list and sets up strings, etc.

% highlight new sweeps
swpNewIdx = length(h.ui.sweepListDisplay.String); % last sweep
h.ui.sweepListDisplay.Value = swpNewIdx;
h = highlightSweep(h, swpNewIdx);
if length(swpNewIdx) == 1
    set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', sweepStr{swpNewIdx}));
else
    set(h.ui.groupSweepText, 'string', sprintf('(%s Swps)', num2str(length(swpNewIdx))));
end

% save
guidata(src, h);

end


function sweepsSubtract(src, ~)
% subtract selected pair of sweeps (baseline-aligned) into new sweeps

% load
h = guidata(src);
winMain = src;
if isempty(h.ui.cellListDisplay.String)
    return
end

% fetch default parameters
actualParams = h.params.actualParams;
timeColumn = actualParams.timeColumn; % column 1: timestamp
pvbsVoltageColumn = actualParams.pvbsVoltageColumn; % column 2: voltage
lastSweepDeleted = h.params.lastSweepDeleted; % flag indicating if last sweep had been deleted

% experiment and sweep number
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
swpIdx = h.ui.sweepListDisplay.Value;
expCount = length(h.ui.cellListDisplay);
swpCount = length(h.ui.sweepListDisplay);
sweepIdx = h.exp.data.sweepIdx{expIdx}; % again very poor choice of variable name in hindsight
sweepStr = h.exp.data.sweepStr{expIdx};
%swpIdx = sweepIdx(swpIdx);

% do nothing if no item or only one item was selected
if isempty(swpIdx)
    return
elseif length(swpIdx) == 1 
    return
end

% force single selection for experiment
if length(expIdx) > 1
    expIdx = expIdx(1);
    h.ui.cellListDisplay.Value = expIdx;
end
%{
if length(swpIdx) > 1
    swpIdx = swpIdx(1);
    h.ui.sweepListDisplay.Value = swpIdx;
end
%}

% force pairwise selection for sweeps
if length(swpIdx) ~= 2
    error('Aborted: subtraction only available while two (2) sweeps are selected');
    return
end

% laziness %%%
vRec = h.exp.data.VRec{expIdx};
vRecOriginal = h.exp.data.VRecOriginal{expIdx};
if ~iscell(vRec)    
    vRec = {vRec};
    vRecOriginal = {vRecOriginal};
end
try
    dff = h.exp.data.lineScanDFF{expIdx};
    dffOriginal = h.exp.data.lineScanDFFOriginal{expIdx};
    lineScan = h.exp.data.lineScan{expIdx};
    lineScanF = h.exp.data.lineScanF{expIdx};
    lineScanFChannel = h.exp.data.lineScanFChannel{expIdx};
    lineScanROI = h.exp.data.lineScanROI{expIdx};
    lineScanBaseline = h.exp.data.lineScanBaseline{expIdx};
    lineScanCSV = h.exp.data.lineScanCSV{expIdx};
    if ~iscell(dff)
        dff = {dff};
        dffOriginal = {dffOriginal};
        lineScan = {lineScan};
        lineScanF = {lineScanF};
        lineScanFChannel = {lineScanFChannel};
        lineScanROI = {lineScanROI};
        lineScanBaseline = {lineScanBaseline};
        lineScanCSV = {lineScanCSV};
    end
catch ME
end

baselineWindow = h.params.analysisBaseline; % baseline (ms)
    
% subtract V
[vRecNew1, vRecNew2] = doSweepsSubtractV(vRec);
[vRecOriginalNew1, vRecOriginalNew2] = doSweepsSubtractV(vRecOriginal);
    function [outputCell1, outputCell2] = doSweepsSubtractV(inputCell)
        try
            %%% leaving in case baseline adjustment is implemented in the future
            timeStampNew = inputCell{swpIdx(1)};
            timeStampNew = timeStampNew(:, timeColumn);
            size(inputCell)
            vRecInterval = timeStampNew(2) - timeStampNew(1);
            vRecBaselineWindow = floor(baselineWindow/vRecInterval) + 1; % converting to points from ms
            vRecBaseline1 = inputCell{swpIdx(1)};
            vRecBaseline1 = nanmean(vRecBaseline1(vRecBaselineWindow(1):vRecBaselineWindow(2), pvbsVoltageColumn));
            vRecBaseline2 = inputCell{swpIdx(2)};
            vRecBaseline2 = nanmean(vRecBaseline2(vRecBaselineWindow(1):vRecBaselineWindow(2), pvbsVoltageColumn));
            
            outputCell1 = inputCell{swpIdx(1)} - inputCell{swpIdx(2)}; % first selection - second
            outputCell2 = inputCell{swpIdx(2)} - inputCell{swpIdx(1)}; % second selection - first
            
            outputCell1(:, timeColumn) = timeStampNew; % overwrite timestamp
            outputCell2(:, timeColumn) = timeStampNew; % overwrite timestamp
        catch ME
            outputCell1 = [];
            outputCell2 = [];
            fprintf('Subtraction aborted for V: dimension mismatch\n');
        end
    end

% subtract F
[dffNew1, dffNew2] = doSweepsSubtractF(dff);
[dffOriginalNew1, dffOriginalNew2] = doSweepsSubtractF(dffOriginal);
lineScanNew = lineScan(:, end);
lineScanFNew = lineScanF(:, end);
lineScanFChannelNew = lineScanFChannel(:, end);
lineScanROINew = lineScanROI(:, end);
%lineScanBaselineNew = lineScanBaseline(:, end);
lineScanBaselineNew = [];
lineScanCSVNew = lineScanCSV(:, end);
for i = 1:length(lineScanNew) % should be the same for all
    lineScanNew{i} = [];
    lineScanFNew{i} = [];
    lineScanFChannelNew{i} = [];
    lineScanROINew{i} = [];
    %lineScanBaselineNew{i} = [];
    lineScanCSVNew{i} = [];
end
function [outputCell1, outputCell2] = doSweepsSubtractF(inputCell)
    fColumn = 2; % column for channel 1 (column 1: timestamp) - needs to be refined %%% fixlater
    try
        %%% leaving in case baseline adjustment is implemented in the future
        timeStampNew = inputCell{swpIdx(1)};
        timeStampNew = timeStampNew(:, timeColumn);
        dffInterval = timeStampNew(2) - timeStampNew(1);
        dffBaselineWindow = floor(baselineWindow/dffInterval) + 1; % converting to points from ms
        dffBaseline1 = inputCell{swpIdx(1)};
        dffBaseline1 = nanmean(dffBaseline1(dffBaselineWindow(1):dffBaselineWindow(2), fColumn));
        dffBaseline2 = inputCell{swpIdx(2)};
        dffBaseline2 = nanmean(dffBaseline2(dffBaselineWindow(1):dffBaselineWindow(2), fColumn));
        
        timeStampNew = inputCell{1};
        timeStampNew = timeStampNew(:, timeColumn);
        outputCell1 = inputCell{swpIdx(1)} - inputCell{swpIdx(2)}; % first selection - second
        outputCell2 = inputCell{swpIdx(2)} - inputCell{swpIdx(1)}; % second selection - first
        outputCell1(:, timeColumn) = timeStampNew; % overwrite timestamp
        outputCell2(:, timeColumn) = timeStampNew; % overwrite timestamp
    catch ME
        outputCell1 = [];
        outputCell2 = [];
        fprintf('Subtraction aborted for F: dimension mismatch\n'); % including timescale mismatch for F
    end
end


% fill data into new sweep
%  check if any averaging was actually done
try
    if isempty(vRecNew1) && isempty(dffNew1)
        if isempty(vRecNew2) && isempty(dffNew2)
            fprintf('No result produced.\n\n');
            return
        else
            %fprintf('\n');
        end
    else
        %fprintf('\n');
    end
    %  string for new sweep
    newSwpStr1 = ['(', num2str(swpIdx(1)), '-', num2str(swpIdx(2)), ')'];
    newSwpStr2 = ['(', num2str(swpIdx(2)), '-', num2str(swpIdx(1)), ')'];
    %  filling in data
    vRec{end + 1} = vRecNew1;
    vRec{end + 1} = vRecNew2;
    vRecOriginal{end + 1} = vRecOriginalNew1;
    vRecOriginal{end + 1} = vRecOriginalNew2;
    sweepIdx(end + 1) = sweepIdx(end) + 1; % append sweep index
    if lastSweepDeleted % a better way would be to check this only while i == 1, but well...
        %sweepIdx(end) = sweepIdx(end) + 1; % increase 1 more to account for the last sweep that had been deleted %%% obsolete
        lastSweepDeleted = 0; % update flag
        h.params.lastSweepDeleted = lastSweepDeleted;
    end
    sweepIdx(end + 1) = sweepIdx(end) + 1; % append sweep index again (this has to be done after the preceding if block)
    sweepStr{end + 1} = newSwpStr1; % append sweep index
    sweepStr{end + 1} = newSwpStr2; % append sweep index again (note different variable name)

    h.exp.data.VRec{expIdx} = vRec;
    h.exp.data.VRecOriginal{expIdx} = vRecOriginal;
    h.exp.data.sweepIdx{expIdx} = sweepIdx;
    h.exp.data.sweepStr{expIdx} = sweepStr;
    h.exp.sweeps{expIdx} = length(vRec); % this is unfortunately not entirely vestigial; used in old old analysis code
    %  filling in data for F - this order assumes that there will be no instances with F only
    try
        dff{end + 1} = dffNew1;
        dff{end + 1} = dffNew2;
        dffOriginal{end + 1} = dffOriginalNew1;
        dffOriginal{end + 1} = dffOriginalNew2;
        h.exp.data.lineScanDFF{expIdx} = dff;
        h.exp.data.lineScanDFFOriginal{expIdx} = dffOriginal;
        lineScan = [lineScan, lineScanNew]; % for multiple channels
        lineScanF = [lineScanF, lineScanFNew];
        lineScanFChannel = [lineScanFChannel, lineScanFChannelNew];
        lineScanROI = [lineScanROI, lineScanROINew];
        %lineScanBaseline = [lineScanBaseline, lineScanBaselineNew];
        lineScanCSV = [lineScanCSV, lineScanCSVNew];
        h.exp.data.lineScan{expIdx} = lineScan;
        h.exp.data.lineScanF{expIdx} = lineScanF;
        h.exp.data.lineScanFChannel{expIdx} = lineScanFChannel;
        h.exp.data.lineScanROI{expIdx} = lineScanROI;
        h.exp.data.lineScanBaseline{expIdx} = lineScanBaseline;
        h.exp.data.lineScanCSV{expIdx} = lineScanCSV;
    catch ME
    end
catch ME
end

% draw traces
h = displayTrace(h, expIdx); % this also populates sweep list and sets up strings, etc.

% highlight new sweeps
swpNewIdx = length(h.ui.sweepListDisplay.String); % last sweep
swpNewIdx = [swpNewIdx - 1, swpNewIdx]; % last two sweeps
h.ui.sweepListDisplay.Value = swpNewIdx;
h = highlightSweep(h, swpNewIdx);
if length(swpNewIdx) == 1
    set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', sweepStr{swpNewIdx}));
else
    set(h.ui.groupSweepText, 'string', sprintf('(%s Swps)', num2str(length(swpNewIdx))));
end

% save
guidata(src, h);

end


function sweepsConcatenate(src, ~)
% concatenate selected sweeps into a new sweep

% load
h = guidata(src);
winMain = src;
if isempty(h.ui.cellListDisplay.String)
    return
end

% fetch default parameters
actualParams = h.params.actualParams;
timeColumn = actualParams.timeColumn; % column 1: timestamp
pvbsVoltageColumn = actualParams.pvbsVoltageColumn; % column 2: voltage
lastSweepDeleted = h.params.lastSweepDeleted; % flag indicating if last sweep had been deleted

% experiment and sweep number
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
swpIdx = h.ui.sweepListDisplay.Value;
expCount = length(h.ui.cellListDisplay);
swpCount = length(h.ui.sweepListDisplay);
sweepIdx = h.exp.data.sweepIdx{expIdx}; % again very poor choice of variable name in hindsight
sweepStr = h.exp.data.sweepStr{expIdx};
%swpIdx = sweepIdx(swpIdx);

% do nothing if no item or only one item was selected
if isempty(swpIdx)
    return
elseif length(swpIdx) == 1 
    return
end

% force single selection for experiment
if length(expIdx) > 1
    expIdx = expIdx(1);
    h.ui.cellListDisplay.Value = expIdx;
end
%{
if length(swpIdx) > 1
    swpIdx = swpIdx(1);
    h.ui.sweepListDisplay.Value = swpIdx;
end
%}

% laziness %%%
vRec = h.exp.data.VRec{expIdx};
vRecOriginal = h.exp.data.VRecOriginal{expIdx};
if ~iscell(vRec)    
    vRec = {vRec};
    vRecOriginal = {vRecOriginal};
end
try
    dff = h.exp.data.lineScanDFF{expIdx};
    dffOriginal = h.exp.data.lineScanDFFOriginal{expIdx};
    lineScan = h.exp.data.lineScan{expIdx};
    lineScanF = h.exp.data.lineScanF{expIdx};
    lineScanFChannel = h.exp.data.lineScanFChannel{expIdx};
    lineScanROI = h.exp.data.lineScanROI{expIdx};
    lineScanBaseline = h.exp.data.lineScanBaseline{expIdx};
    lineScanCSV = h.exp.data.lineScanCSV{expIdx};
    if ~iscell(dff)
        dff = {dff};
        dffOriginal = {dffOriginal};
        lineScan = {lineScan};
        lineScanF = {lineScanF};
        lineScanFChannel = {lineScanFChannel};
        lineScanROI = {lineScanROI};
        lineScanBaseline = {lineScanBaseline};
        lineScanCSV = {lineScanCSV};
    end
catch ME
end

% concatenate for V
try
    vRecNew = doSweepsConcatenate(vRec);
    vRecOriginalNew = doSweepsConcatenate(vRecOriginal);
catch ME
    vRecNew = [];
    vRecOriginalNew = [];
    fprintf('Concatenation aborted for V: dimension mismatch\n');
end
%{
vRecNew = [];
timeStampNew = [];
samplingRateTemp = 0;
timeStampEnd = 0;
try
    for i = swpIdx % NB. relative indices
        if isempty(vRec{i}) % if an empty sweep is encountered for whatever reason, just return up to the previous sweep
            break
        end
        vRecNew = [vRecNew; vRec{i}];
        timeStampTemp = vRec{i};
        timeStampTemp = timeStampTemp(:, timeColumn);
        timeStampTemp = timeStampEnd + samplingRateTemp + timeStampTemp; % update timestamp for current sweep
        timeStampEnd = timeStampTemp(end); % to update timestamp for next sweep
        samplingRateTemp = timeStampTemp(end) - timeStampTemp(end - 1); % just in case sampling rate might differ betwen sweeps, which is realistically absurd
        timeStampNew = [timeStampNew; timeStampTemp];
    end
    vRecNew(:, timeColumn) = timeStampNew; % overwrite timestamp
catch ME
    vRecNew = [];
    fprintf('Concatenation aborted for V: dimension mismatch\n');
end
%}

% concatenate for F
try
    dffNew = doSweepsConcatenate(dff);
    dffOriginalNew = doSweepsConcatenate(dffOriginal);
    lineScanNew = lineScan(:, end);
    lineScanFNew = lineScanF(:, end);
    lineScanFChannelNew = lineScanFChannel(:, end);
    lineScanROINew = lineScanROI(:, end);
    %lineScanBaselineNew = lineScanBaseline(:, end);
    lineScanBaselineNew = [];
    lineScanCSVNew = lineScanCSV(:, end);
    for i = 1:length(lineScanNew) % should be the same for all
        lineScanNew{i} = [];
        lineScanFNew{i} = [];
        lineScanFChannelNew{i} = [];
        lineScanROINew{i} = [];
        %lineScanBaselineNew{i} = [];
        lineScanCSVNew{i} = [];
    end
catch ME
    dffNew = [];
    dffOriginalNew = [];
    lineScanNew = [];
    lineScanFNew = [];
    lineScanFChannelNew = [];
    lineScanROINew = [];
    lineScanBaselineNew = [];
    lineScanCSVNew = [];
    fprintf('Concatenation aborted for F: dimension mismatch\n');
end
%{
dffNew = [];
timeStampNew = [];
samplingRateTemp = 0;
timeStampEnd = 0;
try
    for i = swpIdx % NB. relative indices
        if isempty(dff{i}) % if an empty sweep is encountered for whatever reason, just return up to the previous sweep
            break
        end
        dffNew = [dffNew; dff{i}];
        timeStampTemp = dff{i};
        timeStampTemp = timeStampTemp(:, timeColumn);
        timeStampTemp = timeStampEnd + samplingRateTemp + timeStampTemp; % update timestamp for current sweep
        timeStampEnd = timeStampTemp(end); % to update timestamp for next sweep
        samplingRateTemp = timeStampTemp(end) - timeStampTemp(end - 1); % just in case sampling rate might differ betwen sweeps, which is actually possible for F absurd
        timeStampNew = [timeStampNew; timeStampTemp];
    end

    dffNew(:, timeColumn) = timeStampNew; % overwrite timestamp
catch ME
    dffNew = [];
    fprintf('Concatenation aborted for F: dimension mismatch\n');
end
%}

% actual function doing the work
    function outputArray = doSweepsConcatenate(inputArray)
        outputArray = [];
        timeStampNew = [];
        samplingRateTemp = 0;
        timeStampEnd = 0;
        %try
            for i = swpIdx % NB. relative indices
                if isempty(inputArray{i}) % if an empty sweep is encountered for whatever reason, just return up to the previous sweep
                    break
                end
                outputArray = [outputArray; inputArray{i}];
                timeStampTemp = inputArray{i};
                timeStampTemp = timeStampTemp(:, timeColumn);
                timeStampTemp = timeStampEnd + samplingRateTemp + timeStampTemp; % update timestamp for current sweep
                timeStampEnd = timeStampTemp(end); % to update timestamp for next sweep
                samplingRateTemp = timeStampTemp(end) - timeStampTemp(end - 1); % just in case sampling rate might differ betwen sweeps, which is realistically absurd
                timeStampNew = [timeStampNew; timeStampTemp];
            end
            outputArray(:, timeColumn) = timeStampNew; % overwrite timestamp
            %{
        catch ME
            outputArray = [];
            fprintf('Concatenation aborted for V: dimension mismatch\n');
        end
            %}
    end

% fill data into new sweep
%  check if any concatenation was actually done
try
    if isempty(vRecNew) && isempty(dffNew)
        fprintf('No concatenated sweep created.\n\n');
        return
    else
        %fprintf('\n');
    end
    %  string for new sweep
    newSwpStr = '';
    for i = swpIdx
        newSwpStr = [newSwpStr, num2str(i), ','];
    end
    newSwpStr = newSwpStr(1:end - 1);
    newSwpStr = ['(', newSwpStr, ')'];
    %  filling in data
    vRec{end + 1} = vRecNew;
    vRecOriginal{end + 1} = vRecOriginalNew;
    sweepIdx(end + 1) = sweepIdx(end) + 1; % append sweep index
    sweepStr{end + 1} = newSwpStr; % append sweep index
    if lastSweepDeleted % a better way would be to check this only while i == 1, but well...
        %sweepIdx(end) = sweepIdx(end) + 1; % increase 1 more to account for the last sweep that had been deleted %%% obsolete
        lastSweepDeleted = 0; % update flag
        h.params.lastSweepDeleted = lastSweepDeleted;
    end
    h.exp.data.VRec{expIdx} = vRec;
    h.exp.data.VRecOriginal{expIdx} = vRecOriginal;
    h.exp.data.sweepIdx{expIdx} = sweepIdx;
    h.exp.data.sweepStr{expIdx} = sweepStr;
    h.exp.sweeps{expIdx} = length(vRec); % this is unfortunately not entirely vestigial; used in old old analysis code
    %  filling in data for F - this order assumes that there will be no instances with F only
    try
        dff{end + 1} = dffNew;
        dffOriginal{end + 1} = dffOriginalNew;
        h.exp.data.lineScanDFF{expIdx} = dff;
        h.exp.data.lineScanDFFOriginal{expIdx} = dffOriginal;
        lineScan = [lineScan, lineScanNew]; % for multiple channels
        lineScanF = [lineScanF, lineScanFNew];
        lineScanFChannel = [lineScanFChannel, lineScanFChannelNew];
        lineScanROI = [lineScanROI, lineScanROINew];
        %lineScanBaseline = [lineScanBaseline, lineScanBaselineNew];
        lineScanCSV = [lineScanCSV, lineScanCSVNew];
        h.exp.data.lineScan{expIdx} = lineScan;
        h.exp.data.lineScanF{expIdx} = lineScanF;
        h.exp.data.lineScanFChannel{expIdx} = lineScanFChannel;
        h.exp.data.lineScanROI{expIdx} = lineScanROI;
        h.exp.data.lineScanBaseline{expIdx} = lineScanBaseline;
        h.exp.data.lineScanCSV{expIdx} = lineScanCSV;
    catch ME
    end
catch ME
end

% draw traces
h = displayTrace(h, expIdx); % this also populates sweep list and sets up strings, etc.

% highlight new sweeps
swpNewIdx = length(h.ui.sweepListDisplay.String); % last sweep
h.ui.sweepListDisplay.Value = swpNewIdx;
h = highlightSweep(h, swpNewIdx);
if length(swpNewIdx) == 1
    set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', sweepStr{swpNewIdx}));
else
    set(h.ui.groupSweepText, 'string', sprintf('(%s Swps)', num2str(length(swpNewIdx))));
end

% save
guidata(src, h);

end


function sweepsDelete(src, ~)
% delete selected sweeps

set(src, 'enable', 'off');
srcButton = src;

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    set(src, 'enable', 'on');
    return
end

% experiment and sweep number
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
swpIdx = h.ui.sweepListDisplay.Value;
expCount = length(h.ui.cellListDisplay.String);
swpCount = length(h.ui.sweepListDisplay.String);
sweepIdx = h.exp.data.sweepIdx{expIdx};
sweepStr = h.exp.data.sweepStr{expIdx};
%swpIdx = sweepIdx(swpIdx);

% force single selection
if length(expIdx) > 1
    expIdx = expIdx(1);
    h.ui.cellListDisplay.Value = expIdx;
end
%{
if length(swpIdx) > 1
    swpIdx = swpIdx(1);
    h.ui.sweepListDisplay.Value = swpIdx;
end
%}

% do nothing if no item was selected
if isempty(swpIdx)
    set(src, 'enable', 'on');
    return
end

% are you sure?
confirmWin = figure('Name', 'Delete sweeps?', 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.8, 0.65, 0.125, 0.1], 'resize', 'off', 'DeleteFcn', @winClosed); % use CloseRequestFcn?
cWin.text = uicontrol('Parent', confirmWin, 'Style', 'text', 'string', sprintf('Delete selected sweeps?\nThis cannot be undone.'), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.6, 0.9, 0.3]);
cWin.buttonYes = uicontrol('Parent', confirmWin, 'Style', 'pushbutton', 'string', 'Yes, Delete', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.1, 0.1, 0.35, 0.25], 'callback', @doKillSweeps, 'interruptible', 'off');
cWin.buttonNo = uicontrol('Parent', confirmWin, 'Style', 'pushbutton', 'string', 'Cancel', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.1, 0.35, 0.25], 'callback', @dontKillSweeps, 'interruptible', 'off');

    function winClosed(src, ~)
        set(srcButton, 'enable', 'on');
        guidata(srcButton, h);
    end

    function dontKillSweeps(src, ~)
        set(src, 'enable', 'on');
        close(confirmWin);
    end

    function doKillSweeps(src, ~)
        killSweeps();
        set(src, 'enable', 'on');
        close(confirmWin);
    end

    function killSweeps()
        
        % check if last sweep on display is included
        if swpIdx(end) == swpCount
            h.params.lastSweepDeleted = 1;
        end
        
        % check if first sweep on display is included %%% obsolete
        %{
        if swpIdx(1) == 1
            firstSweepDeleted = 1;
        else
            firstSweepDeleted = 0;
        end
        %}
        
        % delete sweeps
        vRecNew = h.exp.data.VRec{expIdx};
        vRecOriginalNew = h.exp.data.VRecOriginal{expIdx};
        vRecNew(:, swpIdx) = []; % use () instead of {} to eliminate instead of blanking; also, use (:, swpIdx) in case multiple channels will be used later
        vRecOriginalNew(:, swpIdx) = [];
        try
            vRecMetadataNew = h.exp.data.VRecMetadata{expIdx};
            vRecMetadataNew(:, swpIdx) = [];
        catch ME
        end
        try
            VOutNew = h.exp.data.VOut{expIdx};
            VOutNameNew = h.exp.data.VOutName{expIdx};
            VOutNew(:, swpIdx) = [];
            VOutNameNew(:, swpIdx) = [];
        catch ME
        end
        try
            lineScanNew = h.exp.data.lineScan{expIdx};
            lineScanDFFNew = h.exp.data.lineScanDFF{expIdx};
            lineScanDFFOriginalNew = h.exp.data.lineScanDFFOriginal{expIdx};
            lineScanFNew = h.exp.data.lineScanF{expIdx};
            lineScanFChannelNew = h.exp.data.lineScanFChannel{expIdx};
            lineScanROINew = h.exp.data.lineScanROI{expIdx};
            lineScanBaselineNew = h.exp.data.lineScanBaseline{expIdx};
            lineScanCSVNew = h.exp.data.lineScanCSV{expIdx};
            lineScanNew(:, swpIdx) = [];
            lineScanDFFNew(:, swpIdx) = []; 
            lineScanDFFOriginalNew(:, swpIdx) = [];
            lineScanFNew(:, swpIdx) = [];
            lineScanFChannelNew(:, swpIdx) = [];
            lineScanROINew(:, swpIdx) = [];
            lineScanBaselineNew(:, swpIdx) = [];
            lineScanCSVNew(:, swpIdx) = [];
        catch ME
        end
        try
            markPointsIdxNew = h.exp.data.markPointsIdx{expIdx};
            markPointsMetadataNew = h.exp.data.markPointsMetadata{expIdx};
            markPointsIdxNew(:, swpIdx) = [];
            markPointsMetadataNew(:, swpIdx) = [];
        catch ME
        end
        if swpIdx ~= length(sweepIdx)
            for i = swpIdx
                sweepIdx(i + 1 : end) = sweepIdx(i + 1 : end) - 1; % pushing up
            end
        end
        sweepIdx(swpIdx) = [];
        sweepStr(swpIdx) = [];
        %{
        if firstSweepDeleted
            sweepIdx = sweepIdx - 1;
        end
        %}
        
        h.exp.data.VRec{expIdx} = vRecNew;
        h.exp.data.VRecOriginal{expIdx} = vRecOriginalNew;
        h.exp.data.VRecMetadata{expIdx} = vRecMetadataNew;
        h.exp.data.VOut{expIdx} = VOutNew;
        h.exp.data.VOutName{expIdx} = VOutNameNew;
        h.exp.data.sweepIdx{expIdx} = sweepIdx;
        h.exp.data.sweepStr{expIdx} = sweepStr;
        h.exp.sweeps{expIdx} = length(vRecNew); % this is unfortunately not entirely vestigial; used in old old analysis code
        try
            h.exp.data.lineScan{expIdx} = lineScanNew;
            h.exp.data.lineScanDFF{expIdx} = lineScanDFFNew;
            h.exp.data.lineScanDFFOriginal{expIdx} = lineScanDFFOriginalNew;
            h.exp.data.lineScanF{expIdx} = lineScanFNew;
            h.exp.data.lineScanFChannel{expIdx} = lineScanFChannelNew;
            h.exp.data.lineScanROI{expIdx} = lineScanROINew;
            h.exp.data.lineScanBaseline{expIdx} = lineScanBaselineNew;
            h.exp.data.lineScanCSV{expIdx} = lineScanCSVNew;
        catch ME
        end
        try
            h.exp.data.markPointsIdx{expIdx} = markPointsIdxNew;
            h.exp.data.markPointsMetadata{expIdx} = markPointsMetadataNew;
        catch ME
        end
        
        % update group indices
        groupIdx = h.exp.data.groupIdx{expIdx};
        for i = flip(swpIdx) % must be done in reverse order
            for j = 1:length(groupIdx)
                groupIdxNew = groupIdx{j};
                groupIdxNew = groupIdxNew(groupIdxNew ~= i); % remove deleted sweep from group
                groupIdxNew(groupIdxNew > i) = groupIdxNew(groupIdxNew > i) - 1; % shift sweep indices up
                groupIdx{j} = groupIdxNew;
            end
        end
        h.exp.data.groupIdx{expIdx} = groupIdx;
        %%%  forgetting group strings for now, it would be too painful with no huge benefit; removed sweeps will be obvious anyway
        
        % draw traces
        h = displayTrace(h, expIdx);
        
        % move highlight to earliest non-deleted sweep
        if swpIdx(1) == 1
            swpIdxTemp = 1;
        else
            swpIdxTemp = swpIdx(1) - 1;
        end
        
        %{
swpIdxTemp = 1:swpIdx(end);
if swpIdxTemp == 1
    h = highlightSweep(h, sweepIdx(swpIdxTemp));
else
    swpIdxTemp = setdiff(swpIdxTemp, swpIdx);
    if isempty(swpIdxTemp)
        swpIdxTemp = 1;
    else
        swpIdxTemp = swpIdxTemp(end) - (swpIdxTemp(1) - 1);
    end
    h.ui.sweepListDisplay.Value = swpIdxTemp;
    h = highlightSweep(h, sweepIdx(swpIdxTemp));
end
        %}
        %{
h = highlightSweep(h, sweepIdx(swpIdxTemp));
set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', num2str(sweepIdx(swpIdxTemp))));
        %}
        h.ui.sweepListDisplay.Value = swpIdxTemp;
        h = highlightSweep(h, swpIdxTemp);
        set(h.ui.groupSweepText, 'string', sprintf('Swp. %s', num2str(swpIdxTemp)));
        
        % save
        set(src, 'enable', 'on');
        guidata(src, h);
        
    end

end


%% Data Analysis
% some codes in this section may be even more incomprehensible, 
% as there is much adapted from relics written in BC (before Corona)


function analysisOptions(src, ~)
% analysis options

% load
h = guidata(src);

win1 = src.Parent;
srcButton = src;
set(srcButton, 'enable', 'off');

% load parameters
params = h.params;
analysisParameters = h.params.actualParams;
analysisParametersDefault = h.params.defaultParams;

% options
optionsWin = figure('Name', 'Analysis Options', 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.55, 0.2, 0.25, 0.4], 'DeleteFcn', @winClosed); % use CloseRequestFcn?

oWin.t101 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Analysis type:', 'fontweight', 'bold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.9, 0.2, 0.05]);
oWin.t102 = uicontrol('Parent', optionsWin, 'Style', 'popupmenu', 'string', params.analysisTypeList1, 'value', 2, 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.91, 0.5, 0.05], 'callback', @analysisTypeSel);
oWin.t111 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Win 1 peak direction:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.775, 0.4, 0.05]);
oWin.t112 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.peakDirection1), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.3, 0.785, 0.1, 0.05], 'callback', @updateAnalysisOptions);
oWin.t113 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(-1: neg, 0: abs, 1:pos)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.425, 0.775, 0.6, 0.05]);
oWin.t121 = uicontrol('Parent', optionsWin, 'Style', 'text', 'visible', 'off', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.775, 0.4, 0.05]);
oWin.t122 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'visible', 'off', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.8, 0.785, 0.1, 0.05], 'callback', @updateAnalysisOptions);
oWin.t123 = uicontrol('Parent', optionsWin, 'Style', 'text', 'visible', 'off', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.925, 0.775, 0.1, 0.05]);
oWin.t211 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Win 2 peak direction:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.7, 0.4, 0.05]);
oWin.t212 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.peakDirection2), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.3, 0.71, 0.1, 0.05], 'callback', @updateAnalysisOptions);
oWin.t213 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(-1: neg, 0: abs, 1:pos)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.425, 0.7, 0.6, 0.05]);
oWin.t221 = uicontrol('Parent', optionsWin, 'Style', 'text', 'visible', 'off', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.7, 0.4, 0.05]);
oWin.t222 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'visible', 'off', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.8, 0.71, 0.1, 0.05], 'callback', @updateAnalysisOptions);
oWin.t223 = uicontrol('Parent', optionsWin, 'Style', 'text', 'visible', 'off', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.925, 0.7, 0.1, 0.05]);
oWin.t311 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Rise / decay low:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.625, 0.4, 0.05]);
oWin.t312 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.riseDecay(1)), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.3, 0.635, 0.1, 0.05], 'callback', @updateAnalysisOptions);
oWin.t313 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '%', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.425, 0.625, 0.1, 0.05]);
oWin.t321 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Rise / decay high:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.625, 0.4, 0.05]);
oWin.t322 = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.riseDecay(2)), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.8, 0.635, 0.1, 0.05], 'callback', @updateAnalysisOptions);
oWin.t323 = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '%', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.925, 0.625, 0.1, 0.05]);

oWin.resetButton = uicontrol('Parent', optionsWin, 'Style', 'pushbutton', 'string', 'Reset to defaults', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.425, 0.05, 0.25, 0.075], 'callback', @resetAnalysisOptions, 'interruptible', 'off');
oWin.saveButton = uicontrol('Parent', optionsWin, 'Style', 'pushbutton', 'string', 'Save', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.7, 0.05, 0.25, 0.075], 'callback', @saveAnalysisOptions, 'interruptible', 'off');

t112 = str2num(oWin.t112.String);
t212 = str2num(oWin.t212.String);
t312 = str2num(oWin.t312.String);
t322 = str2num(oWin.t322.String);

    function winClosed(src, ~)
        set(srcButton, 'enable', 'on');
        %guidata(srcButton, h); % don't save when closed without using the save button
    end

    function analysisTypeSel(src, ~)
        switch oWin.t102.Value
            case 1
                oWin.t102.Value = 2;
                return
            case 3
                errorMessage = sprintf('\nSelection aborted: Threshold detection currently unavailable, feature underway\n');
                fprintf(errorMessage);
                oWin.t102.Value = 2;
                return
            case 4
                errorMessage = sprintf('\nSelection aborted: Waveform analysis currently unavailable, feature underway\n');
                fprintf(errorMessage);
                oWin.t102.Value = 2;
                return
        end
    end

    function updateAnalysisOptions(src, ~)
        switch oWin.t102.Value
            case 2
                t112 = str2num(oWin.t112.String);
                t212 = str2num(oWin.t212.String);
                t312 = str2num(oWin.t312.String);
                t322 = str2num(oWin.t322.String);
            otherwise
                return
        end
    end

    function resetAnalysisOptions(src, ~)
        %{
        analysisParametersIntrinsic = analysisParameters.intrinsicPropertiesAnalysis; % salvage this
        analysisParameters = analysisParametersDefault;
        analysisParameters.intrinsicPropertiesAnalysis = analysisParametersIntrinsic;
        %}
        
        switch oWin.t102.Value
            case 2
                analysisParameters.peakDirection1 = analysisParametersDefault.peakDirection1;
                analysisParameters.peakDirection2 = analysisParametersDefault.peakDirection2;
                analysisParameters.riseDecay(1) = analysisParametersDefault.riseDecay(1);
                analysisParameters.riseDecay(2) = analysisParametersDefault.riseDecay(2);
                oWin.t112.String = num2str(analysisParameters.peakDirection1);
                oWin.t212.String = num2str(analysisParameters.peakDirection2);
                oWin.t312.String = num2str(analysisParameters.riseDecay(1));
                oWin.t322.String = num2str(analysisParameters.riseDecay(2));
                t112 = str2num(oWin.t112.String);
                t212 = str2num(oWin.t212.String);
                t312 = str2num(oWin.t312.String);
                t322 = str2num(oWin.t322.String);
            otherwise
                return
        end
        
        %guidata(win1, h);
        %close(optionsWin);
        %set(srcButton, 'enable', 'on');
    end

    function saveAnalysisOptions(src, ~)
        
        switch oWin.t102.Value
            case 2
                analysisParameters.peakDirection1 = t112;
                analysisParameters.peakDirection2 = t212;
                analysisParameters.riseDecay(1) = t312;
                analysisParameters.riseDecay(2) = t322;
            otherwise
                return
        end
        
        h.params.actualParams = analysisParameters;
        
        guidata(win1, h);
        close(optionsWin);
        set(srcButton, 'enable', 'on');
    end


% save
%guidata(src, h);

end


function runAnalysis(src, ~)
% run analysis

h = guidata(src);

if isempty(h.ui.cellListDisplay.String)
    error('Error: No experiment file present to perform analysis');
end

expIdx = h.ui.cellListDisplay.Value; % taken out from runAnalysisRun()
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
h = runAnalysisRun(h, expIdx); % moved here so it can be called elsewhere
guidata(src, h);

end


function h = runAnalysisRun(h, expIdx) % run Forrest run

results = h.results;
params = h.params;
VRecData = h.exp.data.VRec;
sweepIdx = h.exp.data.sweepIdx;
sweepStr = h.exp.data.sweepStr;
groupIdx = h.exp.data.groupIdx;
groupStr = h.exp.data.groupStr;

if isempty(h.ui.cellListDisplay.String)
    error('Error: No experiment file present to perform analysis');
end

% current experiment
%expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % take only the first one if multiple items are selected - obsolete %%% actually, must fix for multiple selection
VRecData = VRecData{expIdx};
sweepIdx = sweepIdx{expIdx};
sweepStr = sweepStr{expIdx};
groupIdx = groupIdx{expIdx};
groupStr = groupStr{expIdx};

% initialize
experimentCount = h.exp.experimentCount;
if length(results) < experimentCount
    newSlots = cell(experimentCount - length(results));
    results = [results, newSlots];
elseif length(results) > experimentCount
    results = results(1:experimentCount);
end
analysisTypeIdx = []; % array to save analysis type index

% analysis target
%  obsolete - see switch block below
%{
sweeps = []; % initializing array for sweeps to be analyzed
groups = [];
%}
if iscell(VRecData)
    sweeps = 1:length(VRecData); % all sweeps
    VRecData = VRecData(sweeps); % leave relevant data
else
    sweeps = 1; % VRecData is an array when there is only one sweep
    VRecData = VRecData; % keep as is
end
groups = groupIdx; % all groups
%{
analysisTarget = h.ui.analysisTarget;
analysisTargetString = h.ui.analysisTarget.String;
analysisTargetIdx = h.ui.analysisTarget.Value;
%}
%  the following switch block is obsolete...
%  ... originally, only relevant sweeps were analyzed;
%  now, all sweeps are analyzed anyway, but only relevant ones are processed/plotted afterwards;
%  the older code indexes relevant sweeps again, so it will create massive confusion if used inappropriately
%{
switch analysisTargetIdx
    case 1 % unselected - default to all groups
        analysisTargetIdx = 2;
        analysisTarget.Value = analysisTargetIdx;
        h.ui.analysisTarget.Value = analysisTarget.Value;
        for i = 1:length(groupIdx)
            sweeps = [sweeps, groupIdx{i}];
        end
        sweeps = sort(sweeps); % critical for analysis function to work properly
        groups = groupIdx;
    case 2 % all groups
        for i = 1:length(groupIdx)
            sweeps = [sweeps, groupIdx{i}];
        end
        sweeps = sort(sweeps); % critical for analysis function to work properly
        groups = groupIdx;
    case 3 % selected groups
        selectedGroup = h.ui.groupListDisplay.Value;
        sweeps = groupIdx{selectedGroup};
        sweeps = sort(sweeps); % critical for analysis function to work properly
        groups = groupIdx(selectedGroup);
    case 4 % all sweeps
        sweeps = 1:length(VRecData); % all sweeps
    case 5 % selected sweeps
        selectedSweeps = h.ui.sweepListDisplay.Value;
        sweeps = selectedSweeps;
end
%}
resultsTemp.sweeps = sweeps; % for recordkeeping
resultsTemp.groups = groups; % for recordkeeping

% analysis windows
window0 = params.analysisBaseline; % baseline is shared for all windows - don't use h.ui.analysisBaselineStart.String
window1 = params.analysisWindow1; 
window2 = params.analysisWindow2; 
%  append to pass to analysis main function - obsolete
%window1 = [window0; window1];
%window2 = [window0; window2];
resultsTemp.windowBaseline = window0;
resultsTemp.window1 = window1;
resultsTemp.window2 = window2;

% analysis type
%  window 1
analysisType1 = h.ui.analysisType1;
analysisType1String = h.ui.analysisType1.String;
analysisType1Idx = h.ui.analysisType1.Value;
analysisTypeIdx = [analysisTypeIdx , analysisType1Idx];
%  window 2
analysisType2 = h.ui.analysisType2;
analysisType2String = h.ui.analysisType2.String;
analysisType2Idx = h.ui.analysisType2.Value;
analysisTypeIdx = [analysisTypeIdx , analysisType2Idx];

% check for analysis type match %%% currently supports only a total of 2 analysis windows
if analysisType1Idx == analysisType2Idx
    analysisTypeMatch = 1;
else
    analysisTypeMatch = 0;
end

% run same analysis for both windows if applicable
if analysisTypeMatch
    % append windows
    window = [window0; window1; window2];
    switch analysisType1Idx
        case 1 % unselected - default to peak
            analysisType1Idx = 2;
            analysisType2Idx = 2;
            h.ui.analysisType1.Value = analysisType1Idx;
            h.ui.analysisType2.Value = analysisType2Idx;
            resultsTemp = analysisPeak(resultsTemp, params, VRecData, window);
        case 2 % peak/mean/area
            %{
            switch analysisOption1Idx % peak direction, to be passed onto analysis function
                case 1 % unselected - default to absolute
                    analysisOption1Idx = 0;
                case 2 % either
                    analysisOption1Idx = 0;
                case 3 % positive-going
                    analysisOption1Idx = 1;
                case 4 % negative-going
                    analysisOption1Idx = -1;
            end
            %}
            resultsTemp = analysisPeak(resultsTemp, params, VRecData, window);
        case 3 % threshold detection
            resultsTemp = analysisThresholdDetection(resultsTemp, params, VRecData, window);
        case 4 % waveform analysis
            resultsTemp = analysisAPWaveform(resultsTemp, params, VRecData, window);
    end
else
    windowNan = [NaN, NaN]; % to be passed on for irrelevant window
    % window 1
    window = [window0; window1; windowNan];
    switch analysisType1Idx
        case 1 % unselected - default to peak
            analysisType1Idx = 2;
            h.ui.analysisType1.Value = analysisType1Idx;
            resultsTemp = analysisPeak(resultsTemp, params, VRecData, window);
        case 2 % peak/mean/area
            %{
            switch analysisOption1Idx % peak direction, to be passed onto analysis function
                case 1 % unselected - default to absolute
                    analysisOption1Idx = 0;
                case 2 % either
                    analysisOption1Idx = 0;
                case 3 % positive-going
                    analysisOption1Idx = 1;
                case 4 % negative-going
                    analysisOption1Idx = -1;
            end
            %}
            resultsTemp = analysisPeak(resultsTemp, params, VRecData, window);
        case 3 % threshold detection
            resultsTemp = analysisThresholdDetection(resultsTemp, params, VRecData, window);
        case 4 % waveform analysis
            resultsTemp = analysisAPWaveform(resultsTemp, params, VRecData, window);
    end
    % window 2
    window = [window0; windowNan; window2];
    switch analysisType2Idx
        case 1 % unselected - default to peak
            analysisType2Idx = 2;
            h.ui.analysisType2.Value = analysisType2Idx;
            resultsTemp = analysisPeak(resultsTemp, params, VRecData, window);
        case 2 % peak/mean/area
            %{
            switch analysisOption1Idx % peak direction, to be passed onto analysis function
                case 1 % unselected - default to absolute
                    analysisOption1Idx = 0;
                case 2 % either
                    analysisOption1Idx = 0;
                case 3 % positive-going
                    analysisOption1Idx = 1;
                case 4 % negative-going
                    analysisOption1Idx = -1;
            end
            %}
            resultsTemp = analysisPeak(resultsTemp, params, VRecData, window2);
        case 3 % threshold detection
            resultsTemp = analysisThresholdDetection(resultsTemp, params, VRecData, window2);
        case 4 % waveform analysis
            resultsTemp = analysisAPWaveform(resultsTemp, params, VRecData, window2);
    end
end

% try to repeat the same procedure with df/f
try
    dffData = h.exp.data.lineScanDFF; % load
    dffData = dffData{expIdx}; % current experiment
    dffData = dffData(sweeps); % leave relevant data
    resultsTemp2.sweeps = sweeps;
    resultsTemp2.groups = groups;
    resultsTemp2.windowBaseline = window0;
    resultsTemp2.window1 = window1;
    resultsTemp2.window2 = window2;
    % run same analysis for both windows if applicable
    if analysisTypeMatch
        % append windows
        window = [window0; window1; window2];
        switch analysisType1Idx
            case 1 % unselected - default to peak
                analysisType1Idx = 2;
                analysisType2Idx = 2;
                h.ui.analysisType1.Value = analysisType1Idx;
                h.ui.analysisType2.Value = analysisType2Idx;
                resultsTemp2 = analysisPeak(resultsTemp2, params, dffData, window);
            case 2 % peak/mean/area
                %{
            switch analysisOption1Idx % peak direction, to be passed onto analysis function
                case 1 % unselected - default to absolute
                    analysisOption1Idx = 0;
                case 2 % either
                    analysisOption1Idx = 0;
                case 3 % positive-going
                    analysisOption1Idx = 1;
                case 4 % negative-going
                    analysisOption1Idx = -1;
            end
                %}
                resultsTemp2 = analysisPeak(resultsTemp2, params, dffData, window);
            case 3 % threshold detection
                resultsTemp2 = analysisThresholdDetection(resultsTemp2, params, dffData, window);
            case 4 % waveform analysis
                resultsTemp2 = analysisAPWaveform(resultsTemp2, params, dffData, window);
        end
    else
        % window 1
        window = [window0; window1; windowNan];
        switch analysisType1Idx
            case 1 % unselected - default to peak
                analysisType1Idx = 2;
                h.ui.analysisType1.Value = analysisType1Idx;
                resultsTemp2 = analysisPeak(resultsTemp2, params, dffData, window);
            case 2 % peak/mean/area
                %{
            switch analysisOption1Idx % peak direction, to be passed onto analysis function
                case 1 % unselected - default to absolute
                    analysisOption1Idx = 0;
                case 2 % either
                    analysisOption1Idx = 0;
                case 3 % positive-going
                    analysisOption1Idx = 1;
                case 4 % negative-going
                    analysisOption1Idx = -1;
            end
                %}
                resultsTemp2 = analysisPeak(resultsTemp2, params, dffData, window);
            case 3 % threshold detection
                resultsTemp2 = analysisThresholdDetection(resultsTemp2, params, dffData, window);
            case 4 % waveform analysis
                resultsTemp2 = analysisAPWaveform(resultsTemp2, params, dffData, window);
        end
        
        % window 2
        window = [window0; windowNan; window2];
        switch analysisType2Idx
            case 1 % unselected - default to peak
                analysisType2Idx = 2;
                h.ui.analysisType2.Value = analysisType2Idx;
                resultsTemp2 = analysisPeak(resultsTemp2, params, dffData, window);
            case 2 % peak/mean/area
                %{
            switch analysisOption1Idx % peak direction, to be passed onto analysis function
                case 1 % unselected - default to absolute
                    analysisOption1Idx = 0;
                case 2 % either
                    analysisOption1Idx = 0;
                case 3 % positive-going
                    analysisOption1Idx = 1;
                case 4 % negative-going
                    analysisOption1Idx = -1;
            end
                %}
                resultsTemp2 = analysisPeak(resultsTemp2, params, dffData, window2);
            case 3 % threshold detection
                resultsTemp2 = analysisThresholdDetection(resultsTemp2, params, dffData, window2);
            case 4 % waveform analysis
                resultsTemp2 = analysisAPWaveform(resultsTemp2, params, dffData, window2);
        end
    end
catch ME
    %ME
end

% group results
groups = h.exp.data.groupIdx{expIdx};
resultsTempGrp = resultsTemp; % easier way to initialize; overwrite afterwards
resultsTempGrp.peak = cell(size(resultsTemp.peak, 1), length(groups));
resultsTempGrp.timeOfPeak = cell(size(resultsTemp.timeOfPeak, 1), length(groups));
resultsTempGrp.riseTime = cell(size(resultsTemp.riseTime, 1), length(groups));
resultsTempGrp.decayTime = cell(size(resultsTemp.decayTime, 1), length(groups));
resultsTempGrp.riseSlope = cell(size(resultsTemp.riseSlope, 1), length(groups));
resultsTempGrp.decaySlope = cell(size(resultsTemp.decaySlope, 1), length(groups));
resultsTempGrp.area = cell(size(resultsTemp.area, 1), length(groups));
resultsTempGrp.mean = cell(size(resultsTemp.mean, 1), length(groups));
for i = 1:length(groups)
    sweepsInGroup = groups{i};
    %  converting to absolute indices from ordinal indices on sweep list
    sweepsInGroup = ismember(sweepIdx, sweepsInGroup); % find elements of sweepIdx that match sweepsInGroup
    sweepsInGroup = find(sweepsInGroup == 1); % find their indices
    for j = sweepsInGroup
        resultsTempGrp.baseline{i} = resultsTempGrp.baseline{i} + resultsTemp.baseline{j};
    end
    resultsTempGrp.baseline{i} = resultsTempGrp.baseline{i}./length(sweepsInGroup);
    for k = 1:size(resultsTemp.peak, 1) % this will suffice
        resultsTempGrp.peak{k, i} = zeros(size(resultsTemp.peak{1}));
        resultsTempGrp.timeOfPeak{k, i} = zeros(size(resultsTemp.timeOfPeak{1}));
        resultsTempGrp.riseTime{k, i} = zeros(size(resultsTemp.riseTime{1}));
        resultsTempGrp.decayTime{k, i} = zeros(size(resultsTemp.decayTime{1}));
        resultsTempGrp.riseSlope{k, i} = zeros(size(resultsTemp.riseSlope{1}));
        resultsTempGrp.decaySlope{k, i} = zeros(size(resultsTemp.decaySlope{1}));
        resultsTempGrp.area{k, i} = zeros(size(resultsTemp.area{1}));
        resultsTempGrp.mean{k, i} = zeros(size(resultsTemp.mean{1}));
        for j = sweepsInGroup
            resultsTempGrp.peak{k, i} = resultsTempGrp.peak{k, i} + resultsTemp.peak{k, j};
            resultsTempGrp.timeOfPeak{k, i} = resultsTempGrp.timeOfPeak{k, i} + resultsTemp.timeOfPeak{k, j};
            resultsTempGrp.riseTime{k, i} = resultsTempGrp.riseTime{k, i} + resultsTemp.riseTime{k, j};
            resultsTempGrp.decayTime{k, i} = resultsTempGrp.decayTime{k, i} + resultsTemp.decayTime{k, j};
            resultsTempGrp.riseSlope{k, i} = resultsTempGrp.riseSlope{k, i} + resultsTemp.riseSlope{k, j};
            resultsTempGrp.decaySlope{k, i} = resultsTempGrp.decaySlope{k, i} + resultsTemp.decaySlope{k, j};
            resultsTempGrp.area{k, i} = resultsTempGrp.area{k, i} + resultsTemp.area{k, j};
            resultsTempGrp.mean{k, i} = resultsTempGrp.mean{k, i} + resultsTemp.mean{k, j};
        end
        resultsTempGrp.peak{k, i} = resultsTempGrp.peak{k, i}./length(sweepsInGroup);
        resultsTempGrp.timeOfPeak{k, i} = resultsTempGrp.timeOfPeak{k, i}./length(sweepsInGroup);
        resultsTempGrp.riseTime{k, i} = resultsTempGrp.riseTime{k, i}./length(sweepsInGroup);
        resultsTempGrp.decayTime{k, i} = resultsTempGrp.decayTime{k, i}./length(sweepsInGroup);
        resultsTempGrp.riseSlope{k, i} = resultsTempGrp.riseSlope{k, i}./length(sweepsInGroup);
        resultsTempGrp.decaySlope{k, i} = resultsTempGrp.decaySlope{k, i}./length(sweepsInGroup);
        resultsTempGrp.area{k, i} = resultsTempGrp.area{k, i}./length(sweepsInGroup);
        resultsTempGrp.mean{k, i} = resultsTempGrp.mean{k, i}./length(sweepsInGroup);
    end
end
try
    groups = h.exp.data.groupIdx{expIdx};
    resultsTemp2Grp = resultsTemp2; % easier way to initialize; overwrite afterwards
    resultsTemp2Grp.peak = cell(size(resultsTemp2.peak, 1), length(groups));
    resultsTemp2Grp.timeOfPeak = cell(size(resultsTemp2.timeOfPeak, 1), length(groups));
    resultsTemp2Grp.riseTime = cell(size(resultsTemp2.riseTime, 1), length(groups));
    resultsTemp2Grp.decayTime = cell(size(resultsTemp2.decayTime, 1), length(groups));
    resultsTemp2Grp.riseSlope = cell(size(resultsTemp2.riseSlope, 1), length(groups));
    resultsTemp2Grp.decaySlope = cell(size(resultsTemp2.decaySlope, 1), length(groups));
    resultsTemp2Grp.area = cell(size(resultsTemp2.area, 1), length(groups));
    resultsTemp2Grp.mean = cell(size(resultsTemp2.mean, 1), length(groups));
    for i = 1:length(groups)
        sweepsInGroup = groups{i};
        %  converting to absolute indices from ordinal indices on sweep list
        sweepsInGroup = ismember(sweepIdx, sweepsInGroup); % find elements of sweepIdx that match sweepsInGroup
        sweepsInGroup = find(sweepsInGroup == 1); % find their indices
        for j = sweepsInGroup
            resultsTemp2Grp.baseline{i} = resultsTemp2Grp.baseline{i} + resultsTemp2.baseline{j};
        end
        resultsTemp2Grp.baseline{i} = resultsTemp2Grp.baseline{i}./length(sweepsInGroup);       
        for k = 1:size(resultsTemp2.peak, 1) % this will suffice
            resultsTemp2Grp.peak{k, i} = zeros(size(resultsTemp2.peak{1}));
            resultsTemp2Grp.timeOfPeak{k, i} = zeros(size(resultsTemp2.timeOfPeak{1}));
            resultsTemp2Grp.riseTime{k, i} = zeros(size(resultsTemp2.riseTime{1}));
            resultsTemp2Grp.decayTime{k, i} = zeros(size(resultsTemp2.decayTime{1}));
            resultsTemp2Grp.riseSlope{k, i} = zeros(size(resultsTemp2.riseSlope{1}));
            resultsTemp2Grp.decaySlope{k, i} = zeros(size(resultsTemp2.decaySlope{1}));
            resultsTemp2Grp.area{k, i} = zeros(size(resultsTemp2.area{1}));
            resultsTemp2Grp.mean{k, i} = zeros(size(resultsTemp2.mean{1}));
            for j = sweepsInGroup
                resultsTemp2Grp.peak{k, i} = resultsTemp2Grp.peak{k, i} + resultsTemp2.peak{k, j};
                resultsTemp2Grp.timeOfPeak{k, i} = resultsTemp2Grp.timeOfPeak{k, i} + resultsTemp2.timeOfPeak{k, j};
                resultsTemp2Grp.riseTime{k, i} = resultsTemp2Grp.riseTime{k, i} + resultsTemp2.riseTime{k, j};
                resultsTemp2Grp.decayTime{k, i} = resultsTemp2Grp.decayTime{k, i} + resultsTemp2.decayTime{k, j};
                resultsTemp2Grp.riseSlope{k, i} = resultsTemp2Grp.riseSlope{k, i} + resultsTemp2.riseSlope{k, j};
                resultsTemp2Grp.decaySlope{k, i} = resultsTemp2Grp.decaySlope{k, i} + resultsTemp2.decaySlope{k, j};
                resultsTemp2Grp.area{k, i} = resultsTemp2Grp.area{k, i} + resultsTemp2.area{k, j};
                resultsTemp2Grp.mean{k, i} = resultsTemp2Grp.mean{k, i} + resultsTemp2.mean{k, j};
            end
            resultsTemp2Grp.peak{k, i} = resultsTemp2Grp.peak{k, i}./length(sweepsInGroup);
            resultsTemp2Grp.timeOfPeak{k, i} = resultsTemp2Grp.timeOfPeak{k, i}./length(sweepsInGroup);
            resultsTemp2Grp.riseTime{k, i} = resultsTemp2Grp.riseTime{k, i}./length(sweepsInGroup);
            resultsTemp2Grp.decayTime{k, i} = resultsTemp2Grp.decayTime{k, i}./length(sweepsInGroup);
            resultsTemp2Grp.riseSlope{k, i} = resultsTemp2Grp.riseSlope{k, i}./length(sweepsInGroup);
            resultsTemp2Grp.decaySlope{k, i} = resultsTemp2Grp.decaySlope{k, i}./length(sweepsInGroup);
            resultsTemp2Grp.area{k, i} = resultsTemp2Grp.area{k, i}./length(sweepsInGroup);
            resultsTemp2Grp.mean{k, i} = resultsTemp2Grp.mean{k, i}./length(sweepsInGroup);
        end
    end
catch ME
end

% color scheme - %%% no longer used and no idea what it was for
colorMapX = 1;
colorMapY = 1./(1 + exp(-((1/2)*colorMapX - 1)));
colorMapY = -colorMapY + 1;
colorMap = [1, 1, 1];
colorMap = colorMapY .* colorMap;
colorMapX = colorMapX + 1;

% display results
%  plot 1: by default, display Vm, win 1, peak, by group, for current experiment
targetPlot = h.ui.analysisPlot1; % plot 1
winToPlot = 1; % analysis window 1
peakDirToPlot = h.params.actualParams.peakDirection1;
switch peakDirToPlot % converting to column indices for old code
    case -1 % negative
        peakDirToPlot = 1;
    case 0 % absolute
        peakDirToPlot = 2;
    case 1 % positive
        peakDirToPlot = 3;
    otherwise
        peakDirToPlot = 2; % default to absolute if not available
end
dataX = 1:length(resultsTempGrp.groups); % group number - will plot by groups
dataY = resultsTempGrp.peak; % grouped results, peak
dataY = dataY(winToPlot, :); % analysis window 1
dataYNew = nan(length(dataY), 1); % initialize
for i = 1:length(dataY)
    dataYi = dataY{i}; % current sweep/group
    if isempty(dataYi)
        dataYi = NaN;
    else
        dataYi = dataYi(peakDirToPlot);
    end
    dataYNew(i) = dataYi; % update
end
dataY = dataYNew; % update
axes(targetPlot);
hold on;
color = [0, 0, 0];
targetPlot = displayResults(targetPlot, dataX, dataY, color);
set(gca, 'xlim', [0, length(dataX) + 1]); % padding for appearance
hold off;
xlabel('Group #');
ylabel('PSP (mV)');
%xticks(0:5:10000);
%%{
if nanmax(dataY) > 40
    ylim([0, 40.5]);
    %yticks(-1000:10:1000);
elseif nanmax(dataY) > 10
    ylim([0, nanmax(dataY) + 0.5]);
    %yticks(-1000:5:1000);
else
    ylim([0, 10.5]);
    %yticks(-1000:2:1000);
end
%}
set(gca, 'xminortick', 'on', 'yminortick', 'on');
h.ui.analysisPlot1 = targetPlot;
params.resultsPlot1YRange = targetPlot.YLim;
h.ui.analysisPlot1Menu1.Value = 2; % voltage
h.ui.analysisPlot1Menu2.Value = 2; % window 1
%h.ui.analysisPlot1Menu3.Value = 1; % results - will update later
h.ui.analysisPlot1Menu4.Value = 3; % by group

%  plot 2: by default, display dF/F, win 2, peak, by group, for current experiment
try
    targetPlot = h.ui.analysisPlot2; % plot 2
    winToPlot = 2; % analysis window 2
    peakDirToPlot = h.params.actualParams.peakDirection2;
    switch peakDirToPlot % converting to column indices for old code
        case -1 % negative
            peakDirToPlot = 1;
        case 0 % absolute
            peakDirToPlot = 2;
        case 1 % positive
            peakDirToPlot = 3;
        otherwise
            peakDirToPlot = 2; % default to absolute if not available
    end
    dataX = 1:length(resultsTemp2Grp.groups); % group number - will plot by groups
    dataY = resultsTemp2Grp.peak; % grouped results, peak
    dataY = dataY(winToPlot, :); % analysis window 2
    dataYNew = nan(length(dataY), 1); % initialize
    %%%
    %%%%%%%
    % data grouping not fucking working properly - why???
    %%%%%%% the fuck happened here? was it fixed? (2022-05-03)
    for i = 1:length(dataY)
        dataYi = dataY{i}; % current sweep/group
        if isempty(dataYi)
            dataYi = NaN;
        else
            dataYi = dataYi(peakDirToPlot);
        end
        dataYNew(i) = dataYi; % update
    end
    dataY = dataYNew; % update
    axes(targetPlot);
    hold on;
    color = [0, 0.5, 0];
    targetPlot = displayResults(targetPlot, dataX, dataY, color);
    set(gca, 'xlim', [0, length(dataX) + 1]); % padding for appearance
    hold off;
    xlabel('Group #');
    ylabel('dF/F');
    %xticks(0:5:10000);
    %{
    if max(dataY) > 4
        ylim([-0.5, max(dataY) + 0.5]);
        yticks(-10:1:100);
    else
        ylim([-0.5, 4.5]);
        yticks(-10:1:100);
    end
    %}
    set(gca, 'xminortick', 'on', 'yminortick', 'on');
    h.ui.analysisPlot2 = targetPlot;
    params.resultsPlot2YRange = targetPlot.YLim;
    h.ui.analysisPlot2Menu1.Value = 3; % fluorescence
    h.ui.analysisPlot2Menu2.Value = 3; % window 2
    %h.ui.analysisPlot2Menu3.Value = 1; % results - will update later
    h.ui.analysisPlot2Menu4.Value = 3; % by group
catch ME
    %ME
end

% which results to plot
try
switch h.ui.analysisType1.Value % analysis type for window 1
    case 1 % unselected
    case 2 % peak/area/mean
        switch h.ui.analysisPlot1Menu2.Value % plot 1, window number
            case 1 % unselected
                h.ui.analysisPlot1Menu3.String = h.params.analysisPlotMenuList3; % to default
            case 2 % window 1
                h.ui.analysisPlot1Menu3.String = h.params.analysisPlotMenuList31;
                h.ui.analysisPlot1Menu3.Value = 2; % default to peak
            case 3 % window 2
                h.ui.analysisPlot1Menu3.String = h.params.analysisPlotMenuList3; % to default
        end
    %%% below not available yet
    case 3 % threshold detection
    case 4 % waveform
end
catch ME
end
try
switch h.ui.analysisType2.Value % analysis type for window 2
    case 1 % unselected
    case 2 % peak/area/mean
        switch h.ui.analysisPlot2Menu2.Value % plot 1, window number
            case 1 % unselected
                h.ui.analysisPlot2Menu3.String = h.params.analysisPlotMenuList3; % to default
            case 2 % window 1
                h.ui.analysisPlot2Menu3.String = h.params.analysisPlotMenuList3; % to default
            case 3 % window 2
                h.ui.analysisPlot2Menu3.String = h.params.analysisPlotMenuList31;
                h.ui.analysisPlot2Menu3.Value = 2; % default to peak
        end
    %%% below not available yet
    case 3 % threshold detection
    case 4 % waveform
end
catch ME
end

% set defaults again


%{
% display results 1
targetPlot = h.ui.analysisPlot1;
tempResultsOrigin = resultsTemp.peak(1,:); % win1
tempResults = [];
for i = 1:length(tempResultsOrigin)
    tempResultsEntry = tempResultsOrigin{i};
    tempResultsEntry = tempResultsEntry(3); %%% neg abs pos
    tempResults = [tempResults, tempResultsEntry];
end
axes(targetPlot);
hold on;
scatter(resultsTemp.sweeps, tempResults, 12, 'filled', 'markerfacecolor', 'k'); % 12 is markersize
hold off;
h.ui.analysisPlot1 = targetPlot;

% display results 2
targetPlot = h.ui.analysisPlot2;
tempResultsOrigin = resultsTemp2.peak(2,:); % win2
tempResults = [];
for i = 1:length(tempResultsOrigin)
    tempResultsEntry = tempResultsOrigin{i};
    tempResultsEntry = tempResultsEntry(3); %%% neg abs pos
    tempResults = [tempResults, tempResultsEntry];
end
axes(targetPlot);
hold on;
scatter(resultsTemp2.sweeps, tempResults, 12, 'filled', 'markerfacecolor', 'k'); % 12 is markersize
hold off;
h.ui.analysisPlot2 = targetPlot;
%}

% save
resultsTemp.analysisTypeIdx = analysisTypeIdx;
resultsCurrentExp.VRec.sweepResults = resultsTemp;
resultsCurrentExp.VRec.groupResults = resultsTempGrp; 
results{expIdx} = resultsCurrentExp;
try
    resultsTemp2.analysisTypeIdx = analysisTypeIdx;
    resultsCurrentExp.dff.sweepResults = resultsTemp2;
    resultsCurrentExp.dff.groupResults = resultsTemp2Grp;
    results{expIdx} = resultsCurrentExp;
catch ME
end
h.params = params;
h.results = results;

end

function runAutoAnalysis(src, ~)

win = src; % cannot use "src" as variable name as there will be nested functions downstream using src, cuz i'm a fucking idiot
h = guidata(win);

analysis = h.analysis;

if isempty(h.ui.cellListDisplay.String)
    error('Error: No experiment file present to perform analysis');
end

analysisPreset = h.ui.analysisPreset;
analysisPresetValue = analysisPreset.Value;
if analysisPresetValue == 1 % "(select)"
    analysisPresetValue = 2; % default to first available option
    h.ui.analysisPreset.Value = analysisPresetValue;
end

analysisPresetString = analysisPreset.String;
analysisPresetString = analysisPresetString{analysisPresetValue};

expList = h.ui.cellList; % this is not the ui, but the strings populating it
expCount = length(expList);
expOdd = 1:2:expCount;
expEven = 2:2:expCount;

switch analysisPresetValue
    case 1 % taken care of above
    case 2 % uncaging w/ linescan (Apr 2022)
        % intended for pairwise arrangement of experiments (units, measured)
        % stupid ass way of coding but tired of thinking about this anymore
        
        % open new window
        win2 = figure('Name', analysisPresetString, 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.5, 0.5, 0.25, 0.4], 'resize', 'off');
        ui2.help = uicontrol('Style', 'pushbutton', 'string', '?', 'Units', 'normalized', 'Position', [0.9, 0.9, 0.05, 0.05], 'Callback', @ui2Help, 'interruptible', 'off');
        ui2.text0 = uicontrol('Style', 'text', 'string', 'Experiment Pairs:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.9, 0.4, 0.05]);
        ui2.text1 = uicontrol('Style', 'text', 'string', '(Units)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.85, 0.4, 0.05]);
        ui2.text2 = uicontrol('Style', 'text', 'string', '(Measured)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.85, 0.4, 0.05]);
        ui2.list1 = uicontrol('Style', 'listbox', 'Visible', 'on', 'Min', 0, 'Max', 1, 'Units', 'normalized', 'Position', [0.05, 0.35, 0.4, 0.5], 'interruptible', 'off');
        ui2.list2 = uicontrol('Style', 'listbox', 'Visible', 'on', 'Min', 0, 'Max', 1, 'Units', 'normalized', 'Position', [0.55, 0.35, 0.4, 0.5], 'interruptible', 'off');
        ui2.optionsButton = uicontrol('Style', 'pushbutton', 'string', 'Options', 'Units', 'normalized', 'Position', [0.75, 0.1, 0.2, 0.05], 'Callback', @uncAnalysisOptions, 'interruptible', 'off');
        ui2.runButton = uicontrol('Style', 'pushbutton', 'string', 'Run', 'Units', 'normalized', 'Position', [0.75, 0.05, 0.2, 0.05], 'Callback', @uncAnalysisRun, 'interruptible', 'off');
        ui2.resetList = uicontrol('Style', 'pushbutton', 'string', 'R', 'Units', 'normalized', 'Position', [0.475, 0.775, 0.05, 0.05], 'Callback', @resetList, 'interruptible', 'off');
        ui2.moveRight = uicontrol('Style', 'pushbutton', 'string', '>', 'Units', 'normalized', 'Position', [0.475, 0.45, 0.05, 0.05], 'Callback', @moveRight, 'interruptible', 'off');
        ui2.moveLeft = uicontrol('Style', 'pushbutton', 'string', '<', 'Units', 'normalized', 'Position', [0.475, 0.375, 0.05, 0.05], 'Callback', @moveLeft, 'interruptible', 'off');
        ui2.list1MoveUp = uicontrol('Style', 'pushbutton', 'string', '^', 'Units', 'normalized', 'Position', [0.25, 0.29, 0.05, 0.05], 'Callback', @list1MoveUp, 'interruptible', 'off');
        ui2.list1MoveDn = uicontrol('Style', 'pushbutton', 'string', 'v', 'Units', 'normalized', 'Position', [0.3, 0.29, 0.05, 0.05], 'Callback', @list1MoveDn, 'interruptible', 'off');
        ui2.list1Del = uicontrol('Style', 'pushbutton', 'string', 'X', 'Units', 'normalized', 'Position', [0.4, 0.29, 0.05, 0.05], 'Callback', @list1Del, 'interruptible', 'off');
        ui2.list2MoveUp = uicontrol('Style', 'pushbutton', 'string', '^', 'Units', 'normalized', 'Position', [0.75, 0.29, 0.05, 0.05], 'Callback', @list2MoveUp, 'interruptible', 'off');
        ui2.list2MoveDn = uicontrol('Style', 'pushbutton', 'string', 'v', 'Units', 'normalized', 'Position', [0.8, 0.29, 0.05, 0.05], 'Callback', @list2MoveDn, 'interruptible', 'off');
        ui2.list2Del = uicontrol('Style', 'pushbutton', 'string', 'X', 'Units', 'normalized', 'Position', [0.9, 0.29, 0.05, 0.05], 'Callback', @list2Del, 'interruptible', 'off');
        ui2.analysisSelection = uibuttongroup(win2, 'units', 'normalized', 'position', [0.05, 0.05, 0.3, 0.1], 'bordertype', 'none', 'visible', 'on', 'SelectionChangedFcn', @ui2AnalysisSel);
        ui2.analysisSelection1 = uicontrol('parent', ui2.analysisSelection, 'style', 'radiobutton', 'horizontalalignment', 'left', 'string', 'Use Available Results', 'units', 'normalized', 'position', [0, 0.55, 1, 0.5]);
        ui2.analysisSelection2 = uicontrol('parent', ui2.analysisSelection, 'style', 'radiobutton', 'horizontalalignment', 'left', 'string', 'Start New Analysis', 'units', 'normalized', 'position', [0, 0.05, 1, 0.5], 'enable', 'off');
        ui2.exportResults = uicontrol('Style', 'checkbox', 'value', 0, 'string', 'Export Results (.mat)', 'Units', 'normalized', 'Position', [0.36, 0.1, 0.36, 0.06], 'interruptible', 'off');
        ui2.exportDisplay = uicontrol('Style', 'checkbox', 'value', 0, 'string', 'Export Results (.png)', 'Units', 'normalized', 'Position', [0.36, 0.05, 0.36, 0.06], 'interruptible', 'off');
        
        % populate experiment list
        ui2.list1.String = expList(expOdd);
        ui2.list2.String = expList(expEven);
        
        % preserve original indices
        uncExpIdx1 = expOdd;
        uncExpIdx2 = expEven;
        
        % default parameters
        uncParams = struct();
        winV = 1; % analysis window for V
        winF = 2; % analysis window for dF/F
        pspMax = 35; % max PSP (mV) for threshold detection
        uncUnitSizeDefault = 1; % default assumption for unit size (in number of spines), only used when markpoints metadata is not available
        uncParams.winV = winV;
        uncParams.winF = winF;
        uncParams.pspMax = pspMax;
        uncParams.uncUnitSizeDefault = uncUnitSizeDefault;
        uncParams.defaultParams = uncParams; % for reverting
        guidata(win2, uncParams);
        
    otherwise
end

    % uncaging - run new analysis if applicable
    flagNewAnalysis = 0; % default to this
    function ui2AnalysisSel(src, event)
        newValueString = event.NewValue.String; % clumsy but can't think of a better way
        if strcmp(newValueString, 'Use Available Results') % very clumsy
            flagNewAnalysis = 0;
        elseif strcmp(newValueString, 'Start New Analysis')
            flagNewAnalysis = 1;
        else % shouldn't happen
        end
    end

    % uncaging - unbelievably long due to poor foresight and poor coding and poor mental health in general
    function uncAnalysisRun(src, ~)
        
        % parameters - link these up with default parameters later
        uncParams = guidata(win2);
        winV = uncParams.winV; % analysis window for V
        winF = uncParams.winF; % analysis window for dF/F
        pspMax = uncParams.pspMax; % max PSP (mV) for threshold detection
        uncUnitSizeDefault = uncParams.uncUnitSizeDefault; % default assumption for unit size (in number of spines), only used when markpoints metadata is not available
        %{
        winV = 1; % analysis window for V
        winF = 2; % analysis window for dF/F
        pspMax = 35; % max PSP (mV) for threshold detection
        uncUnitSizeDefault = 1; % default assumption for unit size (in number of spines), only used when markpoints metadata is not available
        %}
        %peakDir = 3; % peak direction: neg, abs, pos %%% fixlater
        
        peakDir = h.params.actualParams.peakDirection1;
        switch peakDir % converting to column indices for old code
            case -1 % negative
                peakDir = 1;
            case 0 % absolute
                peakDir = 2;
            case 1 % positive
                peakDir = 3;
            otherwise
                peakDir = 2; % default to absolute if not available
        end
        
        peakDirF = h.params.actualParams.peakDirection2;
        switch peakDirF % converting to column indices for old code
            case -1 % negative
                peakDirF = 1;
            case 0 % absolute
                peakDirF = 2;
            case 1 % positive
                peakDirF = 3;
            otherwise
                peakDirF = 2; % default to absolute if not available
        end
        
        % display parameters
        vLow = -80;
        vHigh = -45;
        vDiff = vHigh - vLow;
        fLow = -1;
        fHigh = 3;
        pspDispMax = pspMax - 10; % this is only for display purposes, not threshold detection
        spineCountMax = 35; % again for display purposes only
        colorV1 = h.params.traceColorActive;
        colorV2= h.params.traceColorInactive;
        colorF1 = h.params.trace2ColorActive;
        colorF2 = h.params.trace2ColorInactive;
        % make them a little darker
        colorV1 = 0.75*colorV1;
        colorV2 = 0.75*colorV2;
        % make them a little darker and greener (for the environment)
        colorF1(1) = 0.75*colorF1(1);
        colorF1(3) = 0.75*colorF1(3);
        colorF2(1) = 0.75*colorF2(1);
        colorF2(3) = 0.75*colorF2(3);
        
        % abort if not paired
        if ~isequal(length(uncExpIdx1), length(uncExpIdx2))
            errorString = sprintf('Error: experiment numbers do not match; must consist of units-measured pairs');
            error(errorString);
        end
        
        % run new analysis if selected
        if flagNewAnalysis
            expIdx = [uncExpIdx1, uncExpIdx2]; % order doesn't matter
            h = runAnalysisRun(h, expIdx);
        end
                
        % fetch results
        results = h.results;
        
        % experiment file names
        uncFileNameUnits = {};
        uncFileNameMeasured = {};
        for i = uncExpIdx1
            uncFileNameUnits{end + 1} = expList{i};
        end
        for i = uncExpIdx2
            uncFileNameMeasured{end + 1} = expList{i};
        end
        
        % unit size
        uncUnitSize1 = uncUnitSizeFunction(uncExpIdx1);
        uncUnitSize2 = uncUnitSizeFunction(uncExpIdx2);
        uncSpineCountUnits = uncUnitSize1;
        uncSpineCountMeasured = uncUnitSize2;
        for i = 1:length(uncUnitSize2)
            uncUnitSize2Temp = uncUnitSize2{i};
            uncUnitSize2Temp = [uncUnitSize2Temp(1), diff(uncUnitSize2Temp)]; % needs to be done for the measureds, as they would be cumulative (i.e. code assumes cumulative addition of spines)
            uncUnitSize2{i} = uncUnitSize2Temp;
        end
        uncUnitSize = uncUnitSize2; % variable name uncUnitSize too abused in the previous code to fix nicely, just do this
        
        %  function for actually getting the unit size
        function uncUnitSizeOutput = uncUnitSizeFunction(uncExpIdxInput)
            uncUnitSizeOutput = {};
            for i = uncExpIdxInput % iterating for unit experiments
                try
                    markPointsMetadata = h.exp.data.markPointsMetadata; % try to load metadata - should really move out of the for loop
                    markPointsMetadata = markPointsMetadata{i};
                    resultsTemp = results{i};
                    resultsTemp = resultsTemp.VRec;
                    resultsTemp = resultsTemp.groupResults;
                    resultsTemp = resultsTemp.groups; % need this for grouping info
                    uncUnitSizeTemp = []; % initializing
                    for j = 1:length(resultsTemp) % all groups
                        uncUnitSizeTempTemp = [];
                        resultsTempTemp = resultsTemp{j}; % sweep indices within each group
                        for k = resultsTempTemp % all sweeps within each group
                            uncUnitSizeTempTempTemp = markPointsMetadata{k};
                            uncUnitSizeTempTempTemp = uncUnitSizeTempTempTemp.PVMarkPointSeriesElements.PVMarkPointElement.PVGalvoPointElement.Point;
                            uncUnitSizeTempTempTemp = length(uncUnitSizeTempTempTemp);
                            uncUnitSizeTempTemp = [uncUnitSizeTempTemp, uncUnitSizeTempTempTemp];
                        end
                        
                        if all(uncUnitSizeTempTemp == uncUnitSizeTempTemp(1)) % all sweeps within each group have the same spine count, which should normally be the case
                            uncUnitSizeTemp = [uncUnitSizeTemp, uncUnitSizeTempTemp(1)];
                        else
                            uncUnitSizeTemp = [uncUnitSizeTemp, 0]; % putting a 0 should be enough to have this error sorted out downstream
                        end
                    end
                    %{
                for j = 1:length(markPointsMetadata) % all sweeps
                    uncUnitSizeTempTemp = markPointsMetadata{j};
                    uncUnitSizeTempTemp = uncUnitSizeTempTemp.PVMarkPointSeriesElements.PVMarkPointElement.PVGalvoPointElement.Point;
                    uncUnitSizeTempTemp = length(uncUnitSizeTempTemp);
                    uncUnitSizeTemp = [uncUnitSizeTemp, uncUnitSizeTempTemp];
                end
                    %}
                    %{
                % get unit size from first sweep, to compare
                uncUnitSizeTempTemp = markPointsMetadata{1};
                uncUnitSizeTempTemp = uncUnitSizeTempTemp.PVMarkPointSeriesElements.PVMarkPointElement.PVGalvoPointElement.Point;
                uncUnitSizeTempTemp = length(uncUnitSizeTempTemp);
                uncUnitSizeTemp = uncUnitSizeTempTemp;
                for j = 2:length(markPointsMetadata) % iterating for consequent sweeps
                    uncUnitSizeTempTemp = markPointsMetadata{j};
                    uncUnitSizeTempTemp = uncUnitSizeTempTemp.PVMarkPointSeriesElements.PVMarkPointElement.PVGalvoPointElement.Point;
                    uncUnitSizeTempTemp = length(uncUnitSizeTempTemp);
                    if uncUnitSizeTemp == uncUnitSizeTempTemp
                        uncUnitSizeTemp = uncUnitSizeTempTemp; % whatever, not very time-consuming
                    else
                        if uncUnitSizeTemp < uncUnitSizeTempTemp
                            uncUnitSizeMax = uncUnitSizeTempTemp;
                        else
                            uncUnitSizeMin = uncUnitSizeTempTemp;
                        end
                        expName = expList{i};
                        warningString = sprintf('<!> Warning: unit sizes are not consistent, interpret with caution\n(Experiment: %s)\n\n', expName);
                        fprintf(warningString);
                        uncUnitSizeTemp = 0; % overwrite to this to indicate inconsistency
                        break
                    end
                end
                    %}
                catch ME
                    expName = expList{i};
                    warningString = sprintf('<!> Warning: MarkPoints metadata unavailable, assuming unit size of %s spine(s) (Experiment: %s)\n\n', num2str(uncUnitSizeDefault), expName);
                    fprintf(warningString);
                    uncUnitSizeTemp = uncUnitSizeDefault * ones(1, length(resultsTemp)); % will assume some default value defined above if metadata is unavailable
                    %uncUnitSizeTemp = uncUnitSizeDefault * ones(1, length(markPointsMetadata)); % will assume some default value defined above if metadata is unavailable
                end
                uncUnitSizeOutput{end + 1} = uncUnitSizeTemp;
            end
        end
        
        % units
        uncUnits = {};
        for i = uncExpIdx1
            resultsTemp = results{i};
            try
                resultsTemp = resultsTemp.VRec;
            catch ME
                expName = expList{i};
                errorString = sprintf('Error: analysis results not available (%s)', expName);
                error(errorString);
            end
            resultsTemp = resultsTemp.groupResults;
            resultsTemp = resultsTemp.peak; % cell, whose rows represent analysis windows
            resultsTemp = resultsTemp(winV, :); % still a cell, each element containing an array of peaks in [neg, abs, pos]
            for j = 1:size(resultsTemp, 2)
                resultsTempTemp = resultsTemp{j}; % great job again with the naming
                resultsTempTemp = resultsTempTemp(peakDir); % defined above
                resultsTemp{j} = resultsTempTemp; % NB. it will still be a cell, not array
            end
            resultsTemp = cell2mat(resultsTemp); % for ease of handling
            resultsTemp = resultsTemp'; % for ease of viewing and such
            uncUnits{end + 1} = resultsTemp;
            %if ~isequal(uncUnitSizeOriginal{i}, 
        end
        
        % measureds
        uncMeasured = {};
        for i = uncExpIdx2
            resultsTemp = results{i};
            try
                resultsTemp = resultsTemp.VRec;
            catch ME
                expName = expList{i};
                errorString = sprintf('Error: analysis results not available (%s)', expName);
                error(errorString);
            end
            resultsTemp = resultsTemp.groupResults;
            resultsTemp = resultsTemp.peak; % cell, whose rows represent analysis windows
            resultsTemp = resultsTemp(winV, :); % still a cell, each element containing an array of peaks in [neg, abs, pos]
            for j = 1:size(resultsTemp, 2)
                resultsTempTemp = resultsTemp{j}; % great job again with the naming
                resultsTempTemp = resultsTempTemp(peakDir); % defined above
                resultsTemp{j} = resultsTempTemp; % NB. it will still be a cell, not array
            end
            resultsTemp = cell2mat(resultsTemp); % for ease of handling
            resultsTemp = resultsTemp'; % for ease of viewing and such
            uncMeasured{end + 1} = resultsTemp;
        end
        
        % dF/F, just in case
        uncDFF = {};
        try
        for i = uncExpIdx2 % no need to do it for units
            resultsTemp = results{i};
            try
                resultsTemp = resultsTemp.dff;
            catch ME
                expName = expList{i};
                errorString = sprintf('Error: analysis results not available (%s)', expName);
                error(errorString);
            end
            resultsTemp = resultsTemp.groupResults;
            resultsTemp = resultsTemp.peak; % cell, whose rows represent analysis windows
            resultsTemp = resultsTemp(winF, :); % still a cell, each element containing an array of peaks in [neg, abs, pos]
            for j = 1:size(resultsTemp, 2)
                resultsTempTemp = resultsTemp{j}; % great job again with the naming
                resultsTempTemp = resultsTempTemp(peakDirF); % defined above
                resultsTemp{j} = resultsTempTemp; % NB. it will still be a cell, not array
            end
            resultsTemp = cell2mat(resultsTemp); % for ease of handling
            resultsTemp = resultsTemp'; % for ease of viewing and such
            uncDFF{end + 1} = resultsTemp;
        end
        catch ME
            uncDFF{end + 1} = [];
        end
        uncDFFAligned = uncDFF; % initialize by duplicating for the time being
        
        % calculate expected from units
        uncExpected = uncUnits; % initialize
        %  correct for unit size mismatch from grouping differences
        for i = 1:length(uncExpIdx1)
            uncUnitSize1Temp = uncUnitSize1{i};
            uncUnitSize2Temp = uncUnitSize2{i};
            if ~isequal(uncUnitSize1Temp, uncUnitSize2Temp) % unit sizes don't match, e.g. when units are individual spines but measureds are done with increments of groups of spines, or if not all units were used
                if length(uncUnitSize1Temp) > length(uncUnitSize2Temp) % this will most likely be the case, wherein units are individuals, measured are groups
                    if isequal(uncUnitSize1Temp(1:length(uncUnitSize2Temp)), uncUnitSize2Temp) % or some units were simply not used during measured
                        uncExpected{i} = uncUnitSize1Temp(1:length(uncUnitSize2Temp)); % only use the relevant units
                        
                    else
                        uncExpectedTemp = uncExpected{i};
                        uncExpectedTempTemp = uncUnitSize2Temp; % initializing to the shorter one
                        uncUnitSize2Idx = [1, cumsum(uncUnitSize2Temp)]; % will be used below as index
                        for j = 1:length(uncExpectedTempTemp) %%% wtf
                            %try
                            uncExpectedTempTemp(j) = sum(uncExpectedTemp(uncUnitSize2Idx(j):uncUnitSize2Idx(j + 1)));
                            %catch ME
                            %    [i, j]
                            %end
                        end
                        uncExpected{i} = uncExpectedTempTemp;
                    end

                elseif any(~uncUnitSize2Temp) % measured experiment has sweeps with unit sizes defined as 0, likely from missing metadata (e.g. after segmentation, etc.)
                    if length(uncUnitSize1Temp) == length(uncUnitSize2Temp)
                        uncUnitSize2{i} = uncUnitSize1{i};
                        uncSpineCountMeasured{i} = cumsum(uncUnitSize2{i}); % so many redundant variables, so confusingly named
                        uncUnitSize{i} = uncUnitSize2{i}; % needed way later during plotting
                        expName = expList{uncExpIdx2(i)};
                        warningString = sprintf('<!> Warning: MarkPoints metadata unavailable for Measured experiment, assuming increments consistent with units in Unit experiment (Experiment: %s)\n\n', expName);
                        fprintf(warningString);
                        
                    end
                else % should be fixed from the experiment side, most likely grouping mistake (or missing units)
                    
                    errorString = sprintf('Error: group count in measured experiment exceeds unit count - check experiment pairs');
                    error(errorString);
                end
            else % no need to do anything
            end
        end
        %  add up - expected values calculated here and not above!
        for i = 1:size(uncExpected, 2)
            uncExpected{i} = cumsum(uncExpected{i});
        end
        
        % calculate gain
        uncGain = uncMeasured; % initialize
        for i = 1:size(uncMeasured, 2)
            uncGainTemp = nan(size(uncMeasured{i})); % initializing
            uncMeasuredTemp = uncMeasured{i};
            uncExpectedTemp = uncExpected{i};

            if length(uncExpectedTemp) == length(uncMeasuredTemp) % no problem, proceed
            elseif length(uncExpectedTemp) > length(uncMeasuredTemp) % probably because not all units were used, checked upstream
                uncExpectedTemp = uncExpectedTemp(1:length(uncMeasuredTemp))
            else % no
                errorString = sprintf('Error: group count in measured experiment exceeds unit count - check experiment pairs');
                error(errorString);
            end
            
            for j = 1:size(uncMeasuredTemp, 1)
                if uncMeasuredTemp(j) > pspMax % calculate gain for subthreshold PSP only
                    break
                else
                    uncGainTemp(j) = uncMeasuredTemp(j)/uncExpectedTemp(j);
                end
            end
            uncGainTemp = uncGainTemp(~isnan(uncGainTemp)); % ditto
            uncGain{i} = uncGainTemp;
        end
        uncGainAligned = uncGain; % initialize by duplicating for the time being
        
        % stimulation parameters
        uncLaserPower1 = {}; % initializing
        uncLaserDuration1 = {}; % initializing
        uncLaserPower2 = {}; % initializing
        uncLaserDuration2 = {}; % initializing
        for i = uncExpIdx1
            try
                markPointsMetadata = h.exp.data.markPointsMetadata; % try to load metadata - should really move out of the for loop
                markPointsMetadata = markPointsMetadata{i};
                resultsTemp = results{i};
                resultsTemp = resultsTemp.VRec;
                resultsTemp = resultsTemp.groupResults;
                resultsTemp = resultsTemp.groups; % need this for grouping info
                uncLaserPowerTemp1 = []; % initializing
                uncLaserDurationTemp1 = []; % initializing
                for j = 1:length(resultsTemp) % all groups in units experiment
                    uncLaserPowerTempTemp = [];
                    uncLaserDurationTempTemp = [];
                    resultsTempTemp = resultsTemp{j}; % sweep indices within each group
                    for k = resultsTempTemp % all sweeps within each group
                        markPointsMetadataTemp = markPointsMetadata{k};
                        uncLaserPowerTempTempTemp = markPointsMetadataTemp.PVMarkPointSeriesElements.PVMarkPointElement.Attributes.UncagingLaserPower;
                        uncLaserPowerTempTempTemp = str2num(uncLaserPowerTempTempTemp);
                        uncLaserPowerTempTemp = [uncLaserPowerTempTemp, uncLaserPowerTempTempTemp];
                        uncLaserDurationTempTempTemp = markPointsMetadataTemp.PVMarkPointSeriesElements.PVMarkPointElement.PVGalvoPointElement.Attributes.Duration;
                        uncLaserDurationTempTempTemp = str2num(uncLaserDurationTempTempTemp);
                        uncLaserDurationTempTemp = [uncLaserDurationTempTemp, uncLaserDurationTempTempTemp];
                    end
                    if all(uncLaserPowerTempTemp == uncLaserPowerTempTemp(1)) && all(uncLaserDurationTempTemp == uncLaserDurationTempTemp(1)) % all sweeps within each group have the same laser stimulation conditions, which should normally be the case
                        uncLaserPowerTemp1 = uncLaserPowerTempTemp(1);
                        uncLaserDurationTemp1 = uncLaserDurationTempTemp(1);
                    else % blank out if inconsistent
                        uncLaserPowerTemp1 = [];
                        uncLaserDurationTemp1 = [];
                        expName = expList{i};
                        warningString = sprintf('<!> Warning: Inconsistent laser power and/or duration detected - correction needed (Experiment: %s (Group %s))\n\n', num2str(uncUnitSizeDefault), expName, num2str(j));
                        fprintf(warningString);
                    end
                end
            catch ME % blank out if for whatever reason they are not available, e.g. due to missing metadata
                uncLaserPowerTemp1 = [];
                uncLaserDurationTemp1 = [];
            end
            uncLaserPower1{end + 1} = uncLaserPowerTemp1;
            uncLaserDuration1{end + 1} = uncLaserDurationTemp1;
        end
        for i = uncExpIdx2
            try
                markPointsMetadata = h.exp.data.markPointsMetadata; % try to load metadata - should really move out of the for loop
                markPointsMetadata = markPointsMetadata{i};
                resultsTemp = results{i};
                resultsTemp = resultsTemp.VRec;
                resultsTemp = resultsTemp.groupResults;
                resultsTemp = resultsTemp.groups; % need this for grouping info
                uncLaserPowerTemp2 = []; % initializing
                uncLaserDurationTemp2 = []; % initializing
                for j = 1:length(resultsTemp) % all groups in units experiment
                    uncLaserPowerTempTemp = [];
                    uncLaserDurationTempTemp = [];
                    resultsTempTemp = resultsTemp{j}; % sweep indices within each group
                    for k = resultsTempTemp % all sweeps within each group
                        markPointsMetadataTemp = markPointsMetadata{k};
                        uncLaserPowerTempTempTemp = markPointsMetadataTemp.PVMarkPointSeriesElements.PVMarkPointElement.Attributes.UncagingLaserPower;
                        uncLaserPowerTempTempTemp = str2num(uncLaserPowerTempTempTemp);
                        uncLaserPowerTempTemp = [uncLaserPowerTempTemp, uncLaserPowerTempTempTemp];
                        uncLaserDurationTempTempTemp = markPointsMetadataTemp.PVMarkPointSeriesElements.PVMarkPointElement.PVGalvoPointElement.Attributes.Duration;
                        uncLaserDurationTempTempTemp = str2num(uncLaserDurationTempTempTemp);
                        uncLaserDurationTempTemp = [uncLaserDurationTempTemp, uncLaserDurationTempTempTemp];
                    end
                    if all(uncLaserPowerTempTemp == uncLaserPowerTempTemp(1)) && all(uncLaserDurationTempTemp == uncLaserDurationTempTemp(1)) % all sweeps within each group have the same laser stimulation conditions, which should normally be the case
                        uncLaserPowerTemp2 = uncLaserPowerTempTemp(1);
                        uncLaserDurationTemp2 = uncLaserDurationTempTemp(1);
                    else % blank out if inconsistent
                        uncLaserPowerTemp2 = [];
                        uncLaserDurationTemp2 = [];
                        expName = expList{i};
                        warningString = sprintf('<!> Warning: Inconsistent laser power and/or duration detected - correction needed (Experiment: %s (Group %s))\n\n', num2str(uncUnitSizeDefault), expName, num2str(j));
                        fprintf(warningString);
                    end
                end
            catch ME % also blank out if for whatever reason they are not available, e.g. due to missing metadata
                uncLaserPowerTemp2 = [];
                uncLaserDurationTemp2 = [];
            end
            uncLaserPower2{end + 1} = uncLaserPowerTemp2;
            uncLaserDuration2{end + 1} = uncLaserDurationTemp2;
        end
        for i = 1:length(uncLaserPower1)
            if isequal(uncLaserPower1{i}, uncLaserPower2{i}) && isequal(uncLaserDuration1{i}, uncLaserDuration2{i})
            else
                expIdx1 = uncExpIdx1;
                expIdx2 = uncExpIdx2;
                expName1 = expList{expIdx1(i)};
                expName2 = expList{expIdx2(i)};
                warningString = sprintf('<!> Warning: Inconsistent laser power and/or duration detected within experiment pair (Pair %s, Experiments: %s & %s))\n\n', num2str(i), expName1, expName2);
                fprintf(warningString);
            end
        end
        uncLaserPower = [uncLaserPower1; uncLaserPower2]; % 1st row for units, 2nd for measured; dimensions should match
        uncLaserDuration = [uncLaserDuration1; uncLaserDuration2];
        uncLaserPower = num2cell(uncLaserPower); % just to avoid confusion, since different experiments have been stored as elements in a cell
        uncLaserDuration = num2cell(uncLaserDuration);
        
        % save first
        uncaging.fileNameUnits = uncFileNameUnits;
        uncaging.fileNameMeasured = uncFileNameMeasured;
        uncaging.spineCountUnits = uncSpineCountUnits; % this is now actual unit size for unit experiments; see above for the reason for this stupid confusing way of naming
        uncaging.spineCountMeasured = uncSpineCountMeasured; % this is really just cumsum(uncUnitSize{i})
        uncaging.spineIncrementMeasured = uncUnitSize; % see above for the reason for this stupid confusing way of naming
        uncaging.units = uncUnits;
        uncaging.expected = uncExpected;
        uncaging.measured = uncMeasured;
        uncaging.gain = uncGain;
        uncaging.gainAligned = uncGainAligned;
        uncaging.dffPeak = uncDFF;
        uncaging.dffPeakAligned = uncDFFAligned;
        uncaging.alignmentPosition = cell(size(uncGainAligned));
        uncaging.laserPower = uncLaserPower;
        uncaging.laserDuration = uncLaserDuration;
        analysis.uncaging = uncaging;
        h.analysis = analysis;
        guidata(win, h); % has to be within each function
        
        % display if applicable
        expListUnits = expList(uncExpIdx1);
        expListMeasured = expList(uncExpIdx2);
        expPairList = sprintf('(All experiments (n = %s))', num2str(length(expListMeasured)));
        expPairList = {expPairList};
        for i = 1:length(expListMeasured) % should match
            expPairList{end + 1} = [expListUnits{i}, ' - ', expListMeasured{i}];
        end
        unitSizeText = sprintf('(Unit: %s spines)', num2str(uncUnitSizeDefault));
        
        win3 = figure('Name', analysisPresetString, 'NumberTitle', 'off', 'menubar', 'figure', 'Units', 'Normalized', 'Position', [0.2, 0.2, 0.6, 0.6], 'resize', 'on', 'color', [1, 1, 1]);
        ui3.panel = uipanel('position', [0.05, 0.05, 0.9, 0.9], 'bordertype', 'none', 'backgroundcolor', [1, 1, 1]);
        ui3.plot1 = axes('parent', ui3.panel, 'position', [0.05, 0.6, 0.18, 0.32]);
        ui3.plot2 = axes('parent', ui3.panel, 'position', [0.3, 0.6, 0.18, 0.32]);
        ui3.plot3 = axes('parent', ui3.panel, 'position', [0.55, 0.6, 0.18, 0.32]);
        ui3.plot4 = axes('parent', ui3.panel, 'position', [0.8, 0.6, 0.18, 0.32]);
        ui3.plot5 = axes('parent', ui3.panel, 'position', [0.05, 0.1, 0.18, 0.32]);
        ui3.plot6 = axes('parent', ui3.panel, 'position', [0.3, 0.1, 0.18, 0.32]);
        ui3.plot7 = axes('parent', ui3.panel, 'position', [0.55, 0.1, 0.18, 0.32]);
        ui3.plot8 = axes('parent', ui3.panel, 'position', [0.8, 0.1, 0.18, 0.32]);
        ui3.plot5Text = uicontrol('parent', ui3.panel, 'style', 'text', 'string', unitSizeText, 'horizontalalignment', 'right', 'units', 'normalized', 'position', [0.05, 0.42, 0.18, 0.03], 'backgroundcolor', [1, 1, 1]);
        ui3.alignSpinesCheck = uicontrol('parent', ui3.panel, 'style', 'checkbox', 'enable', 'off', 'string', 'Align at spine:', 'horizontalalignment', 'right', 'units', 'normalized', 'position', [0.55, 0.45, 0.1, 0.03], 'backgroundcolor', [1, 1, 1], 'callback', @ui3AlignCheck);
        ui3.alignSpinesInput = uicontrol('parent', ui3.panel, 'style', 'edit', 'string', '0', 'horizontalalignment', 'left', 'units', 'normalized', 'position', [0.64, 0.45, 0.05, 0.025], 'backgroundcolor', [1, 1, 1], 'callback', @ui3AlignInput);
        ui3.menu = uicontrol('parent', win3, 'style', 'popupmenu', 'string', expPairList, 'units', 'normalized', 'position', [0.02, 0.95, 0.45, 0.03], 'callback', @ui3DisplayResultsSel);
        ui3.exportButton1 = uicontrol('parent', win3, 'style', 'pushbutton', 'string', 'Export Results', 'units', 'normalized', 'position', [0.5, 0.95, 0.08, 0.03], 'callback', @ui3ExportFunction1);
        ui3.exportButton2 = uicontrol('parent', win3, 'style', 'pushbutton', 'string', 'Export Display', 'units', 'normalized', 'position', [0.59, 0.95, 0.08, 0.03], 'callback', @ui3ExportFunction2);
        ui3.exportSelection = uibuttongroup(win3, 'units', 'normalized', 'position', [0.69, 0.95, 0.2, 0.03], 'bordertype', 'none', 'backgroundcolor', [1, 1, 1], 'visible', 'on', 'SelectionChangedFcn', @ui3ExportSel);
        ui3.exportSelection1 = uicontrol('parent', ui3.exportSelection, 'style', 'radiobutton', 'horizontalalignment', 'left', 'string', 'All Experiments', 'units', 'pixels', 'position', [0, 2, 100, 20], 'backgroundcolor', [1, 1, 1]);
        ui3.exportSelection2 = uicontrol('parent', ui3.exportSelection, 'style', 'radiobutton', 'horizontalalignment', 'left', 'string', 'Current Experiment', 'units', 'pixels', 'position', [100, 2, 200, 20], 'backgroundcolor', [1, 1, 1]);
        ui3.exportPath = uicontrol('parent', win3, 'style', 'pushbutton', 'string', 'Save Path', 'units', 'normalized', 'position', [0.89, 0.95, 0.05, 0.03], 'callback', @ui3ExportDir, 'visible', 'off', 'enable', 'inactive'); % meh
        
        dataSrc1 = h.exp.data;
        dataSrc2 = h.results;
        dataSrc3 = h.analysis.uncaging;
               
        exportWhich = 0; % initializing
        
        axes(ui3.plot1);
        ylabel('V_m (mV)','FontName','Arial','FontSize',12);
        xlabel('t (ms)','FontName','Arial','FontSize',12);
        set(gca,'XMinorTick','on','YMinorTick','on');
        set(gca,'box','off');
        %ylim([vLow, vLow + pspDispMax]);
        
        axes(ui3.plot2);
        ylabel('\DeltaV_m (mV)','FontName','Arial','FontSize',12);
        xlabel('t (ms)','FontName','Arial','FontSize',12);
        set(gca,'XMinorTick','on','YMinorTick','on');
        set(gca,'box','off');
        
        axes(ui3.plot3);
        ylabel('V_m (mV)','FontName','Arial','FontSize',12);
        xlabel('t (ms)','FontName','Arial','FontSize',12);
        set(gca,'XMinorTick','on','YMinorTick','on');
        set(gca,'box','off');
        
        axes(ui3.plot4);
        ylabel('\DeltaF/F','FontName','Arial','FontSize',12);
        xlabel('t (ms)','FontName','Arial','FontSize',12);
        set(gca,'XMinorTick','on','YMinorTick','on');
        set(gca,'box','off');
        ylim([fLow, fHigh]);
        
        axes(ui3.plot5);
        ylabel('Count','FontName','Arial','FontSize',12);
        xlabel('Unit PSP (mV)','FontName','Arial','FontSize',12);
        set(gca,'XMinorTick','on','YMinorTick','on');
        set(gca,'box','off');
        
        axes(ui3.plot6);
        ylabel('Measured (mV)','FontName','Arial','FontSize',12);
        xlabel('Expected (mV)','FontName','Arial','FontSize',12);
        set(gca,'XMinorTick','on','YMinorTick','on');
        set(gca,'box','off');
        xlim([0, pspDispMax]);
        ylim([0, pspDispMax]);
        
        axes(ui3.plot7);
        ylabel('Gain','FontName','Arial','FontSize',12);
        xlabel('#(Spines)','FontName','Arial','FontSize',12);
        set(gca,'XMinorTick','on','YMinorTick','on');
        set(gca,'box','off');
        xlim([0, spineCountMax]);
        ylim([0, 2.5]);
        
        axes(ui3.plot8);
        ylabel('\DeltaF/F','FontName','Arial','FontSize',12);
        xlabel('#(Spines)','FontName','Arial','FontSize',12);
        set(gca,'XMinorTick','on','YMinorTick','on');
        set(gca,'box','off');
        xlim([0, spineCountMax]);
        ylim([fLow, fHigh]);
        
        if exist('numSpinesPerUnit', 'var') %%% how many spines per unit?
        else
            numSpinesPerUnit = 0; % very poorly done again in hindsight, but will work... sorta
        end
        
        %if ui2.displayResults.Value % this is now removed, will always display
            if length(ui3.menu.String) == 2 % if only one experiment pair exists
                expId = 1; % skip the first choice, which is for the summary from all experiments
            else
                expId = 0; % otherwise initialize with this
            end
            ui3.menu.Value = expId + 1; % skipping first choice, which again is just a label
            ui2DisplayResults(expId);
        %end
             
        % display selected experiment pair
        function ui3DisplayResultsSel(src, ~)
            expId = src.Value;
            expId = src.Value - 1; % first one would be for all experiment pairs
            ui2DisplayResults(expId);
        end
            
        % stuff that do the actual display work
        function ui2DisplayResults(expId)
            cla(ui3.plot1);
            cla(ui3.plot2);
            cla(ui3.plot3);
            cla(ui3.plot4);
            cla(ui3.plot5);
            cla(ui3.plot6);
            cla(ui3.plot7);
            cla(ui3.plot8);
            
            % create a simplified unit size array for all experiment pairs
            uncExpUnitSize = [];
            for i = 1:(length(ui3.menu.String) - 1) % for all experiment pairs
                uncExpUnitSizeTemp = uncSpineCountUnits{i}; % real unit size from unit experiments, not unit size for measured experiments
                if all(uncExpUnitSizeTemp == uncExpUnitSizeTemp(1)) % if unit size is consistent within a given experiment
                    uncExpUnitSize = [uncExpUnitSize, uncExpUnitSizeTemp(1)]; % append with consistent unit size
                else % if not
                    uncExpUnitSize = [uncExpUnitSize, 0]; % put 0 instead of unit size
                end
            end
            
            % prepare for display
            %  there will be a lot of going back and forth with numSpinesPerUnit because this part was written while drunk...
            if expId == 0 % show all experiment pairs
                if all(uncExpUnitSize == uncExpUnitSize(1)) % if all experiments have the same unit size
                    numSpinesPerUnit = uncExpUnitSize(1);
                    if numSpinesPerUnit == 1
                        unitSizeText = sprintf('(Unit: %s spine)', num2str(numSpinesPerUnit));
                    else
                        unitSizeText = sprintf('(Unit: %s spines)', num2str(numSpinesPerUnit));
                    end
                else % not all experiments have the same unit size
                    numSpinesPerUnitMin = NaN; % can initialize with NaN
                    numSpinesPerUnitMax = NaN; % can initialize with NaN
                    for i = 1:(length(ui3.menu.String) - 1) % for all experiment pairs
                        numSpinesPerUnitTemp = uncSpineCountUnits{i};
                        numSpinesPerUnitMinTemp = min(numSpinesPerUnitTemp);
                        numSpinesPerUnitMaxTemp = max(numSpinesPerUnitTemp);
                        numSpinesPerUnitMin = nanmin(numSpinesPerUnitMin, numSpinesPerUnitMinTemp);
                        numSpinesPerUnitMax = nanmax(numSpinesPerUnitMax, numSpinesPerUnitMaxTemp);
                    end
                    unitSizeText = sprintf('(Unit: %s-%s spines)', num2str(numSpinesPerUnitMin), num2str(numSpinesPerUnitMax));
                end
            else % individual experiment pair selected
                numSpinesPerUnit = uncExpUnitSize(expId); % NB. expId = src.Value - 1; from above
                if logical(numSpinesPerUnit)
                    if numSpinesPerUnit == 1
                        unitSizeText = sprintf('(Unit: %s spine)', num2str(numSpinesPerUnit));
                    else
                        unitSizeText = sprintf('(Unit: %s spines)', num2str(numSpinesPerUnit));
                    end
                else
                    numSpinesPerUnitTemp = uncSpineCountUnits{expId};
                    numSpinesPerUnitMin = min(numSpinesPerUnitTemp);
                    numSpinesPerUnitMax = max(numSpinesPerUnitTemp);
                    unitSizeText = sprintf('(Unit: %s-%s spines)', num2str(numSpinesPerUnitMin), num2str(numSpinesPerUnitMax));
                end
                %{
                uncExpUnitSizeTemp = uncUnitSize{expId};
                if all(uncExpUnitSizeTemp == uncExpUnitSizeTemp(1))
                    numSpinesPerUnit = uncExpUnitSizeTemp{1}; % note different brackets
                    unitSizeText = sprintf('(Unit: %s spine(s))', num2str(numSpinesPerUnit));
                else
                    numSpinesPerUnit = 0;
                    unitSizeText = sprintf('(Unit: %s-%s spines)', num2str(min(uncExpUnitSizeTemp)), num2str(max(uncExpUnitSizeTemp)));
                end
                %}
            end           
            set(ui3.plot5Text, 'string', unitSizeText);

            ui2DisplayResults1(expId); % summary plots, e.g. measured vs. expected
            ui2DisplayResults2(expId); % representative traces
        end
        
        % grouped summary plots
        function ui2DisplayResults1(expId) 
            
            % input is intended to be 0 for grouped average
            if logical(expId) % expId was defined in an utterly stupid fucking way
                expId1 = uncExpIdx1(expId);
                expId2 = uncExpIdx2(expId);
                %displayAll = 0;
            else
                expId1 = uncExpIdx1;
                expId2 = uncExpIdx2;
                expId = 1:(length(ui3.menu.String) - 1); % for display later
                %displayAll = 1;
            end
            
            % input is intended to be 0 for grouped average
            %{
            if ~logical(expId)
                expId = 1:(length(ui3.menu.String) - 1);
            end
            
            expId1 = 2*expId - 1
            expId2 = 2*expId
            %}
                        
            % unit size histogram
            axes(ui3.plot5);
            hold on;
            binSize = 0.1;
            binRange = 5;
            unitSizeAll = [];
            for i = expId1 % use ID1, since it will be the units
                unitSize = dataSrc2{i};
                unitSize = unitSize.VRec.sweepResults.peak;
                unitSize = unitSize(winV, :); % winV is defined way above
                for j = 1:length(unitSize)
                    unitSizeTemp = unitSize{j};
                    unitSizeTemp = unitSizeTemp(peakDir); % peakDir also defined way above
                    unitSize{j} = unitSizeTemp; % update
                end
                unitSize = cell2mat(unitSize); % convert to cell for ease of handling
                unitSizeAll = [unitSizeAll, unitSize];
                %histogram(unitSize, 0:binSize:binRange, 'facecolor', colorV2);
            end
            histogram(unitSizeAll, 0:binSize:binRange, 'facecolor', colorV2);
            
            % measured vs expected
            axes(ui3.plot6);
            hold on;
            plot([0, pspMax], [0, pspMax], 'color', [0.5, 0.5, 0.5], 'linestyle', ':');
            for i = expId
                measured = dataSrc3.measured{i};
                expected = dataSrc3.expected{i};
                plot(expected, measured, 'color', colorV2);
            end
            xlim([0, pspMax - 15]);
            ylim([0, pspMax - 15]);
            
            % gain
            axes(ui3.plot7);
            hold on;
            plot([0, spineCountMax], [1, 1], 'color', [0.5, 0.5, 0.5], 'linestyle', ':');
            for i = expId
                try
                    gain = dataSrc3.gain{i};
                    numUnits = length(gain);
                    numSpinesPerUnitTemp = uncUnitSize{i};
                    if all(numSpinesPerUnitTemp == numSpinesPerUnitTemp(1))
                        numUnits = numSpinesPerUnitTemp * numUnits;
                        plot(numSpinesPerUnitTemp:numSpinesPerUnitTemp:numUnits, gain, 'color', colorV2);
                        %{
                    xlabel('#(Spines)','FontName','Arial','FontSize',12);
                    xlim([0, spineCountMax]);
                        %}
                    else
                        numSpinesPerUnitX = cumsum(numSpinesPerUnitTemp);
                        plot(numSpinesPerUnitX, gain, 'color', colorV2);
                        %{
                    xlabel('#','FontName','Arial','FontSize',12);
                    xlim([0, ceil(numUnits/5)*5]);
                        %}
                    end
                catch ME
                end
            end
            
            % dF/F peak
            axes(ui3.plot8);
            hold on;
            plot([0, spineCountMax], [0, 0], 'color', [0.5, 0.5, 0.5], 'linestyle', ':');
            for i = expId
                try
                    dffPeak = dataSrc3.dffPeak{i};
                    numUnits = length(dffPeak);
                    numSpinesPerUnitTemp = uncUnitSize{i};
                    if all(numSpinesPerUnitTemp == numSpinesPerUnitTemp(1))
                        numUnits = numSpinesPerUnitTemp * numUnits;
                        plot(numSpinesPerUnitTemp:numSpinesPerUnitTemp:numUnits, dffPeak, 'color', colorF1);
                        %{
                    xlabel('#(Spines)','FontName','Arial','FontSize',12);
                    xlim([0, spineCountMax]);
                        %}
                    else
                        numSpinesPerUnitX = cumsum(numSpinesPerUnitTemp);
                        plot(numSpinesPerUnitX, dffPeak, 'color', colorF1);
                        %{
                    xlabel('#','FontName','Arial','FontSize',12);
                    xlim([0, ceil(numUnits/5)*5]);
                        %}
                    end
                catch ME
                end
            end
            
        end
        
        % individual experiment pairs - very long
        function ui2DisplayResults2(expId) 
            
            % input is intended to be 0 for grouped display, in which case traces will not be displayed
            if ~logical(expId) % expId was defined in an utterly stupid fucking way
                return
            else
                expId1 = uncExpIdx1(expId);
                expId2 = uncExpIdx2(expId);
            end
            
            % input is intended to be 0 for grouped display, in which case traces will not be displayed
            %{
            if ~logical(expId)
                return
            end
            
            expId1 = 2*expId - 1;
            expId2 = 2*expId;
            %}
            
            % units
            tColumn = h.params.actualParams.timeColumn;
            sColumn = h.params.actualParams.pvbsVoltageColumn; % these will used below to extract relevant data
            dataSrc2Now = dataSrc2{expId1}; % use ID1, since it will be the units
            dataSrc2Now = dataSrc2Now.VRec.sweepResults; % to extract analysis parameters, including groups
            groupIdx = dataSrc2Now.groups;
            baselineWin = dataSrc2Now.windowBaseline;
            analysisWin = dataSrc2Now.window2; % 1 for V, 2 for F
            traces = dataSrc1.VRec{expId1}; % use ID1, since it will be the units
            displayIdx = 1; % will display only the first sweep for each group, as a respresentative example
            for i = 1:length(groupIdx)
                displaySwp = groupIdx{i}; % sweeps within each group
                displaySwp = displaySwp(displayIdx); % keep only the sweep defined above
                groupIdx{i} = displaySwp; % update
            end
            groupIdx = cell2mat(groupIdx); % convert for ease of handling
            axes(ui3.plot1); % prepare to plot
            hold on;
            traces = traces(groupIdx); % keep only relevant sweeps
            for i = 1:length(groupIdx)
                traceToDisplay = traces{i};
                traceTime = traceToDisplay(:, tColumn);
                traceSignal = traceToDisplay(:, sColumn);
                plot(traceTime, traceSignal, 'color', colorV2);
            end
            
            % arithmetic sum
            tColumn = h.params.actualParams.timeColumn;
            sColumn = h.params.actualParams.pvbsVoltageColumn; % these will used below to extract relevant data
            dataSrc2Now = dataSrc2{expId1}; % use ID1, since it will be the units
            dataSrc2Now = dataSrc2Now.VRec.groupResults; % to extract analysis parameters, including groups
            groupIdx = dataSrc2Now.groups;
            baselineWin = dataSrc2Now.windowBaseline; % (ms)
            analysisWin = dataSrc2Now.window2; % 1 for V, 2 for F
            traces = dataSrc1.VRec{expId1}; % use ID1, since it will be the units
            samplingInterval = traces{1}; % just use first entry
            samplingInterval = samplingInterval(2, tColumn) - samplingInterval(1, tColumn); % (ms)
            baselineWin = baselineWin/samplingInterval; % convert to points
            baselineWin(1) = baselineWin(1) + 1; % shift 1 up, since it's a point index now
            displayIdx = 1; % will display only the first sweep for each group, as a respresentative example
            for i = 1:length(groupIdx)
                displaySwp = groupIdx{i}; % sweeps within each group
                displaySwp = displaySwp(displayIdx); % keep only the sweep defined above
                groupIdx{i} = displaySwp; % update
            end
            groupIdx = cell2mat(groupIdx); % convert for ease of handling
            traces = traces(groupIdx); % keep only relevant sweeps
            traceToDisplay = traces{1};
            traceTime = traceToDisplay(:, tColumn);
            traceSignal = traceToDisplay(:, sColumn);
            warning('off','all');
            traceBaseline = nanmean(traceSignal(baselineWin(1):baselineWin(2)));
            warning('on','all');
            traceBaselineAverage = traceBaseline; % will be used later for display purposes
            traceSignal = traceSignal - traceBaseline; % align to baseline
            traceToDisplay = [traceTime, traceSignal]; % update
            traces{1} = traceToDisplay; % update
            for i = 2:length(groupIdx)
                traceToDisplay = traces{i};
                traceTime = traceToDisplay(:, tColumn);
                traceSignal = traceToDisplay(:, sColumn);
                warning('off','all');
                traceBaseline = nanmean(traceSignal(baselineWin(1):baselineWin(2)));
                warning('on','all');
                traceBaselineAverage = traceBaselineAverage + traceBaseline;
                traceSignal = traceSignal - traceBaseline; % align to baseline
                traceSignalPrev = traces{i - 1};
                traceSignalPrev = traceSignalPrev(:, sColumn);
                traceSignal = traceSignal + traceSignalPrev; % sum
                traceToDisplay = [traceTime, traceSignal]; % update
                traces{i} = traceToDisplay; % sum and update
            end
            traceBaselineAverage = traceBaselineAverage/length(groupIdx);
            axes(ui3.plot2); % prepare to plot
            hold on;
            for i = 1:length(groupIdx)
                traceToDisplay = traces{i};
                traceTime = traceToDisplay(:, tColumn);
                traceSignal = traceToDisplay(:, sColumn);
                plot(traceTime, traceSignal, 'color', colorV2);
            end
            ylim([-abs(traceBaselineAverage - vLow), -abs(traceBaselineAverage - vLow) + vDiff]);
                
            % measured traces
            tColumn = h.params.actualParams.timeColumn;
            sColumn = h.params.actualParams.pvbsVoltageColumn; % these will used below to extract relevant data
            dataSrc2Now = dataSrc2{expId2}; % use ID2, since it will be the measured
            dataSrc2Now = dataSrc2Now.VRec.groupResults; % to extract analysis parameters, including groups
            groupIdx = dataSrc2Now.groups;
            baselineWin = dataSrc2Now.windowBaseline;
            analysisWin = dataSrc2Now.window2; % 1 for V, 2 for F
            traces = dataSrc1.VRec{expId2}; % use ID2, since it will be the measured
            displayIdx = 1; % will display only the first sweep for each group, as a respresentative example
            for i = 1:length(groupIdx)
                displaySwp = groupIdx{i}; % sweeps within each group
                displaySwp = displaySwp(displayIdx); % keep only the sweep defined above
                groupIdx{i} = displaySwp; % update
            end
            groupIdx = cell2mat(groupIdx); % convert for ease of handling
            axes(ui3.plot3); % prepare to plot
            hold on;
            traces = traces(groupIdx); % keep only relevant sweeps
            for i = 1:length(groupIdx)
                traceToDisplay = traces{i};
                traceTime = traceToDisplay(:, tColumn);
                traceSignal = traceToDisplay(:, sColumn);
                plot(traceTime, traceSignal, 'color', colorV2);
            end
            ylim([vLow, vHigh]);
            
            % dF/F traces
            try
                tColumn = 1;
                sColumn = 2; % should be OK to hard-code these
                dataSrc2Now = dataSrc2{expId2}; % use ID2, since it will be the measured
                dataSrc2Now = dataSrc2Now.dff.groupResults; % to extract analysis parameters, including groups
                groupIdx = dataSrc2Now.groups;
                baselineWin = dataSrc2Now.windowBaseline;
                analysisWin = dataSrc2Now.window2; % 1 for V, 2 for F
                traces = dataSrc1.lineScanDFF{expId2}; % use ID2, since it will be the measured
                displayIdx = 1; % will display only the first sweep for each group, as a respresentative example
                for i = 1:length(groupIdx)
                    displaySwp = groupIdx{i}; % sweeps within each group
                    displaySwp = displaySwp(displayIdx); % keep only the sweep defined above
                    groupIdx{i} = displaySwp; % update
                end
                groupIdx = cell2mat(groupIdx); % convert for ease of handling
                axes(ui3.plot4); % prepare to plot
                hold on;
                traces = traces(groupIdx); % keep only relevant sweeps
                for i = 1:length(groupIdx)
                    traceToDisplay = traces{i};
                    traceTime = traceToDisplay(:, tColumn);
                    traceSignal = traceToDisplay(:, sColumn);
                    plot(traceTime, traceSignal, 'color', colorF1);
                end
                ylim([fLow, fHigh]);
            catch ME
            end
        end
        
        % which one to export
        function ui3ExportSel(src, event)
            newValueString = event.NewValue.String; % clumsy but can't think of a better way
            if strcmp(newValueString, 'All Experiments') % very clumsy
                exportWhich = 0;
            elseif strcmp(newValueString, 'Current Experiment')
                exportWhich = 1;
            else % shouldn't happen
            end
        end
        
        % export callback - results
        function ui3ExportFunction1(src, ~)
            doUncExport1;
        end
        
        % export callback - display
        function ui3ExportFunction2(src, ~)
            doUncExport2;
        end
        
        % actual function for exporting results
        function doUncExport1()
            if ~exist('exportPath', 'var')
                exportPath = cd;
                exportPath = [exportPath, '\'];
            end
            exportExt = '.mat';
            
            exportData = guidata(win);
            exportData = exportData.analysis;
            exportDataName = 'uncaging';
            exportNamePrefix = exportDataName;
            exportNamePrefix = [exportDataName, '_'];
            
            function exportDataOutput = ui3ExportFunction1Sub(exportDataInput, exportIdInput)
                units = exportDataInput.units;
                unitSize = exportDataInput.unitSize;
                expected = exportDataInput.expected;
                measured = exportDataInput.measured;
                gain = exportDataInput.gain;
                dffPeak = exportDataInput.dffPeak;
                
                units = units{exportIdInput};
                unitSize = unitSize{exportIdInput};
                expected = expected{exportIdInput};
                measured = measured{exportIdInput};
                gain = gain{exportIdInput};
                dffPeak = dffPeak{exportIdInput};
                
                exportDataOutput.units = units;
                exportDataOutput.unitSize = unitSize;
                exportDataOutput.expected = expected;
                exportDataOutput.measured = measured;
                exportDataOutput.gain = gain;
                exportDataOutput.dffPeak = dffPeak;
            end
            
            if logical(exportWhich) % could use "if exportWhich", but just wasting resources (in case it's changed to expId or something like that in the future)
                exportId = ui3.menu.Value;
                if exportId == 1 % this should be the same as what will be done if exportWhich == 0
                    exportId = 1; % do the summary page separately to give it a less generic file name
                    ui3.menu.Value = exportId; % must update display first
                    ui2DisplayResults(exportId - 1); % this is how the input argument was defined for ui2DisplayResults
                    exportName = ui3.menu.String{exportId};
                    todayYY = num2str(year(datetime));
                    todayYY = todayYY(end-1:end);
                    todayMM = sprintf('%02.0f', month(datetime));
                    todayDD = sprintf('%02.0f', day(datetime));
                    hh = sprintf('%02.0f', hour(datetime));
                    mm = sprintf('%02.0f', minute(datetime));
                    ss = sprintf('%02.0f', second(datetime));
                    timeStamp = [todayYY, todayMM, todayDD, '_', hh, mm, ss];
                    exportName = [timeStamp, '_', exportName];
                    exportName = [exportNamePrefix, exportName];
                    exportName = [exportPath, exportName, exportExt];
                    save(exportName, exportDataName);
                    fprintf('\Data exported as: %s\n\n', exportName);
                    exportId = 1;
                    ui3.menu.Value = exportId;
                    ui2DisplayResults(exportId - 1);% return to summary display
                else
                    uncaging = exportData.uncaging;
                    uncaging = ui3ExportFunction1Sub(uncaging, exportId - 1); % confusing, but this is how exportId and the function argument were defined
                    exportName = ui3.menu.String{exportId};
                    exportName = [exportNamePrefix, exportName];
                    exportName = [exportPath, exportName, exportExt];
                    save(exportName, exportDataName);
                    fprintf('\nData exported as: %s\n\n', exportName);
                end
            else
                exportId = 1; % do the summary page separately to give it a less generic file name
                ui3.menu.Value = exportId; % must update display first
                ui2DisplayResults(exportId - 1); % this is how the input argument was defined for ui2DisplayResults
                exportName = ui3.menu.String{exportId};
                todayYY = num2str(year(datetime));
                todayYY = todayYY(end-1:end);
                todayMM = sprintf('%02.0f', month(datetime));
                todayDD = sprintf('%02.0f', day(datetime));
                hh = sprintf('%02.0f', hour(datetime));
                mm = sprintf('%02.0f', minute(datetime));
                ss = sprintf('%02.0f', second(datetime));
                timeStamp = [todayYY, todayMM, todayDD, '_', hh, mm, ss];
                exportName = [timeStamp, '_', exportName];
                exportName = [exportNamePrefix, exportName];
                exportName = [exportPath, exportName, exportExt];
                save(exportName, exportDataName);
                fprintf('\nData exported as: %s\n\n', exportName);
                exportId = 1;
                ui3.menu.Value = exportId;
                ui2DisplayResults(exportId - 1); % return to summary display
            end
        end
        
        % actual function for exporting display
        function doUncExport2()
            if ~exist('exportPath', 'var')
                exportPath = cd;
                exportPath = [exportPath, '\'];
            end
            exportExt = '.png';
            
            if logical(exportWhich) % could use "if exportWhich", but just wasting resources (in case it's changed to expId or something like that in the future)
                exportId = ui3.menu.Value;
                if exportId % do the summary page separately to give it a less generic file name
                    exportName = ui3.menu.String{exportId};
                    todayYY = num2str(year(datetime));
                    todayYY = todayYY(end-1:end);
                    todayMM = sprintf('%02.0f', month(datetime));
                    todayDD = sprintf('%02.0f', day(datetime));
                    hh = sprintf('%02.0f', hour(datetime));
                    mm = sprintf('%02.0f', minute(datetime));
                    ss = sprintf('%02.0f', second(datetime));
                    timeStamp = [todayYY, todayMM, todayDD, '_', hh, mm, ss];
                    exportName = [timeStamp, '_', exportName];
                    exportName = [exportPath, exportName, exportExt];
                    saveas(win3, exportName);
                    fprintf('\nFigure exported as: %s\n\n', exportName);
                else
                    exportName = ui3.menu.String{exportId};
                    exportName = [exportPath, exportName, exportExt];
                    saveas(win3, exportName);
                    fprintf('\nFigure exported as: %s\n\n', exportName);
                end
            else
                exportId = 1; % do the summary page separately to give it a less generic file name
                ui3.menu.Value = exportId; % must update display first
                ui2DisplayResults(exportId - 1); % this is how the input argument was defined for ui2DisplayResults
                exportName = ui3.menu.String{exportId};
                todayYY = num2str(year(datetime));
                todayYY = todayYY(end-1:end);
                todayMM = sprintf('%02.0f', month(datetime));
                todayDD = sprintf('%02.0f', day(datetime));
                hh = sprintf('%02.0f', hour(datetime));
                mm = sprintf('%02.0f', minute(datetime));
                ss = sprintf('%02.0f', second(datetime));
                timeStamp = [todayYY, todayMM, todayDD, '_', hh, mm, ss];
                exportName = [timeStamp, '_', exportName];
                exportName = [exportPath, exportName, exportExt];
                saveas(win3, exportName);
                for i = 2:length(ui3.menu.String) % individual experiments except the summary page
                    exportId = i;
                    ui3.menu.Value = exportId; % must update display first
                    ui2DisplayResults(exportId - 1); % this is how the input argument was defined for ui2DisplayResults
                    exportName = ui3.menu.String{exportId};
                    exportName = [exportPath, exportName, exportExt];
                    saveas(win3, exportName);
                end
                fprintf('\n(%s Files) Figures exported in: %s\n\n', num2str(length(ui3.menu.String)), exportPath);
                exportId = 1;
                ui3.menu.Value = exportId; 
                ui2DisplayResults(exportId - 1);% return to summary display
            end
        end
                
        % align spines - checkbox
        function ui3AlignCheck(src, ~)
        end
        
        % align spines - input
        function ui3AlignInput(src, ~)
        end

        % set save path %%% canceled, too much headache for little return
        function ui3ExportDir(src, ~)
            if ~exist('exportPath', 'var')
                beer = 'good'
                exportPath = cd;
                exportPath = [exportPath, '\'];
            end
            win4 = figure('Name', 'Set Export Directory', 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'normalized', 'Position', [0.4, 0.4, 0.3, 0.03], 'resize', 'off');
            ui4.savePathInput = uicontrol('parent', win4, 'style', 'edit', 'string', exportPath, 'units', 'normalized', 'position', [0.01, 0.05, 0.75, 0.9], 'horizontalalignment', 'left');
            ui4.savePathAccept = uicontrol('parent', win4, 'style', 'pushbutton', 'string', 'V', 'units', 'normalized', 'position', [0.795, 0.05, 0.1, 0.9], 'horizontalalignment', 'left', 'callback', @exportPathSet);
            ui4.savePathCancel = uicontrol('parent', win4, 'style', 'pushbutton', 'string', 'X', 'units', 'normalized', 'position', [0.895, 0.05, 0.1, 0.9], 'horizontalalignment', 'left', 'callback', @exportPathCancel);
            
            function exportPathNew = exportPathSet(src, ~)
                exportPathNew = exportPath;
                if ~strcmp(exportPathNew(end), '\')
                    if ~strcmp(exportPathNew(end), '/') % stupid mac
                    else
                        exportPathNew = [exportPathNew, '\'];
                    end
                end
                exportPath = exportPathNew;
                close(win4);
            end
            
            function exportPathCancel(src, ~)
                close(win4);
            end
        end

        % export immediately if selected
        flagExportResults = ui2.exportResults.Value;
        flagExportDisplay = ui2.exportDisplay.Value;
        if flagExportResults
            doUncExport1();
        end
        if flagExportDisplay
            doUncExport2();
        end
        
        close(win2);

    end

    % uncaging - analysis options
    function uncAnalysisOptions(src, ~)
        srcButton = src;
        set(srcButton, 'enable', 'off');
        
        uncParams = guidata(win2);
        
        win3 = figure('Name', 'Uncaging Analysis Options', 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.5, 0.25, 0.25, 0.2], 'DeleteFcn', @winClosed); % use CloseRequestFcn?
        
        oWin.uo101 = uicontrol('Parent', win3, 'Style', 'text', 'fontweight', 'bold', 'string', 'Analysis windows', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.85, 0.9, 0.08]);
        oWin.uo102 = uicontrol('Parent', win3, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.85, 0.6, 0.08]);
        oWin.uo111 = uicontrol('Parent', win3, 'Style', 'text', 'string', 'Voltage', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.75, 0.4, 0.08]);
        oWin.uo112 = uicontrol('Parent', win3, 'Style', 'edit', 'string', num2str(uncParams.winV), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.76, 0.125, 0.08], 'callback', @updateParams);
        oWin.uo113 = uicontrol('Parent', win3, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.75, 0.1, 0.08]);
        oWin.uo121 = uicontrol('Parent', win3, 'Style', 'text', 'string', 'Fluorescence', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.75, 0.4, 0.08]);
        oWin.uo122 = uicontrol('Parent', win3, 'Style', 'edit', 'string', num2str(uncParams.winF), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.76, 0.125, 0.08], 'callback', @updateParams);
        oWin.uo123 = uicontrol('Parent', win3, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.75, 0.1, 0.08]);
        
        oWin.uo201 = uicontrol('Parent', win3, 'Style', 'text', 'fontweight', 'bold', 'string', 'Detection threshold', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.6, 0.9, 0.08]);
        oWin.uo202 = uicontrol('Parent', win3, 'Style', 'text', 'string', '', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.3, 0.6, 0.6, 0.08]);
        oWin.uo211 = uicontrol('Parent', win3, 'Style', 'text', 'string', 'Max. EPSP peak', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.5, 0.4, 0.08]);
        oWin.uo212 = uicontrol('Parent', win3, 'Style', 'edit', 'string', num2str(uncParams.pspMax), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.51, 0.125, 0.08], 'callback', @updateParams);
        oWin.uo213 = uicontrol('Parent', win3, 'Style', 'text', 'string', '(mV)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.5, 0.1, 0.08]);

        oWin.uo301 = uicontrol('Parent', win3, 'Style', 'text', 'fontweight', 'bold', 'string', 'Default unit size', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.35, 0.9, 0.08]);
        oWin.uo302 = uicontrol('Parent', win3, 'Style', 'text', 'string', '(when metadata unavailable)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.35, 0.6, 0.08]);
        oWin.uo311 = uicontrol('Parent', win3, 'Style', 'text', 'string', 'Unit size', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.25, 0.4, 0.08]);
        oWin.uo312 = uicontrol('Parent', win3, 'Style', 'edit', 'string', num2str(uncParams.uncUnitSizeDefault), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.26, 0.125, 0.08], 'callback', @updateParams);
        oWin.uo313 = uicontrol('Parent', win3, 'Style', 'text', 'string', '(spines)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.25, 0.1, 0.08]);
        
        oWin.resetButton = uicontrol('Parent', win3, 'Style', 'pushbutton', 'string', 'Reset to defaults', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.54, 0.05, 0.2, 0.12], 'callback', @resetParams, 'interruptible', 'off');
        oWin.saveButton = uicontrol('Parent', win3, 'Style', 'pushbutton', 'string', 'Save', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.05, 0.2, 0.12], 'callback', @saveParams, 'interruptible', 'off');

        function winClosed(src, ~)
            set(srcButton, 'enable', 'on');
        end
        
        function updateParams(src, ~) % not really necessary, just a relic of copypaste
            uo112 = str2num(oWin.uo112.String);
            uo122 = str2num(oWin.uo122.String);
            uo212 = str2num(oWin.uo212.String);
            uo312 = str2num(oWin.uo312.String);
            %{
            uncParams.winV = uo112;
            uncParams.winF = uo122;
            uncParams.pspMax = uo212;
            uncParams.uncUnitSizeDefault = uo312;
            %}
            %guidata(win2, uncParams); % don't save when closed without using the save button
        end
        
        function resetParams(src, ~)
            defaultParamsTemp = uncParams.defaultParams;
            uncParams = uncParams.defaultParams;
            uncParams.defaultParams = defaultParamsTemp;
            uo112 = uncParams.winV;
            uo122 = uncParams.winF;
            uo212 = uncParams.pspMax;
            uo312 = uncParams.uncUnitSizeDefault;
            oWin.uo112.String = num2str(uo112);
            oWin.uo122.String = num2str(uo122);
            oWin.uo212.String = num2str(uo212);
            oWin.uo312.String = num2str(uo312);
            %guidata(win2, uncParams); % don't save when closed without using the save button
        end
        
        function saveParams(src, ~)
            uo112 = str2num(oWin.uo112.String);
            uo122 = str2num(oWin.uo122.String);
            uo212 = str2num(oWin.uo212.String);
            uo312 = str2num(oWin.uo312.String);
            uncParams.winV = uo112;
            uncParams.winF = uo122;
            uncParams.pspMax = uo212;
            uncParams.uncUnitSizeDefault = uo312;
            guidata(win2, uncParams);
            close(win3);
            set(srcButton, 'enable', 'on');
        end
        
    end

    % uncaging - reset lists to initial entries
    function resetList(src, ~)
        ui2.list1.String = expList(expOdd);
        ui2.list2.String = expList(expEven);
        uncExpIdx1 = expOdd;
        uncExpIdx2 = expEven;
    end

    % uncaging - move from list 1 to list 2
    function moveRight(src, ~)
        if length(ui2.list1.String) == 0 % do nothing if source list is empty
            return
        end
        idxTemp = ui2.list1.Value; % selected item
        idxTempString = ui2.list1.String{idxTemp};
        idxTempOriginal = uncExpIdx1(idxTemp); % get index for the experiment, not list order
        uncExpIdx2 = [uncExpIdx2, idxTempOriginal]; % update index
        uncExpIdx1(idxTemp) = [];
        ui2.list2.String{end + 1} = idxTempString; % update list
        ui2.list1.String(idxTemp) = [];
        if idxTemp > length(ui2.list1.String) % this will happen if the last item was moved
            ui2.list1.Value = length(ui2.list1.String); % otherwise the list will disappear
        end
        if length(ui2.list2.String) == 1 % this will happen if the target list was empty
            ui2.list2.Value = 1;
        end
    end

    % uncaging - move from list 2 to list 1
    function moveLeft(src, ~)
        if length(ui2.list2.String) == 0 % do nothing if source list is empty
            return
        end
        idxTemp = ui2.list2.Value; % selected item
        idxTempString = ui2.list2.String{idxTemp};
        idxTempOriginal = uncExpIdx2(idxTemp); % get index for the experiment, not list order
        uncExpIdx1 = [uncExpIdx1, idxTempOriginal]; % update index
        uncExpIdx2(idxTemp) = [];
        ui2.list1.String{end + 1} = idxTempString; % update list
        ui2.list2.String(idxTemp) = [];
        if idxTemp > length(ui2.list2.String) % this will happen if the last item was moved
            ui2.list2.Value = length(ui2.list2.String); % otherwise the list will disappear
        end
        if length(ui2.list1.String) == 1 % this will happen if the target list was empty
            ui2.list1.Value = 1;
        end
    end

    % uncaging - list 1, move up
    function list1MoveUp(src, ~)
        idxTemp = ui2.list1.Value; % selected item
        if idxTemp == 1 % do nothing if the first item was selected
            return
        end
       
        uncExpIdx1Temp1 = uncExpIdx1(idxTemp - 1); % index at the upper position
        uncExpIdx1Temp2 = uncExpIdx1(idxTemp); % index at the lower position (selected item)
        uncExpIdx1(idxTemp - 1) = uncExpIdx1Temp2; % switch places
        uncExpIdx1(idxTemp) = uncExpIdx1Temp1; % switch places
        
        stringTemp1 = ui2.list1.String{idxTemp - 1}; % string at the upper position
        stringTemp2 = ui2.list1.String{idxTemp}; % string at the lower position (selected item)
        ui2.list1.String{idxTemp - 1} = stringTemp2; % switch places
        ui2.list1.String{idxTemp} = stringTemp1; % switch places
        
        ui2.list1.Value = idxTemp - 1; %update selection
    end

    % uncaging - list 1, move down
    function list1MoveDn(src, ~)
        idxTemp = ui2.list1.Value; % selected item
        if idxTemp == length(ui2.list1.String) % do nothing if the last item was selected
            return
        end
        
        uncExpIdx1Temp1 = uncExpIdx1(idxTemp); % index at the upper position (selected item)
        uncExpIdx1Temp2 = uncExpIdx1(idxTemp + 1); % index at the lower position 
        uncExpIdx1(idxTemp) = uncExpIdx1Temp2; % switch places
        uncExpIdx1(idxTemp + 1) = uncExpIdx1Temp1; % switch places
        
        stringTemp1 = ui2.list1.String{idxTemp}; % string at the upper position (selected item)
        stringTemp2 = ui2.list1.String{idxTemp + 1}; % string at the lower position 
        ui2.list1.String{idxTemp} = stringTemp2; % switch places
        ui2.list1.String{idxTemp + 1} = stringTemp1; % switch places
        
        ui2.list1.Value = idxTemp + 1; %update selection
    end

    % uncaging - list 1, delete
    function list1Del(src, ~)
        if length(ui2.list1.String) == 0 % do nothing if source list is empty
            return
        end
        idxTemp = ui2.list1.Value; % selected item
        uncExpIdx1(idxTemp) = []; % delete index
        ui2.list1.String(idxTemp) = []; % delete string
        if idxTemp > length(ui2.list1.String) % this will happen if the last item was deleted
            ui2.list1.Value = length(ui2.list1.String); % otherwise the list will disappear
        end
    end

    % uncaging - list 2, move up
    function list2MoveUp(src, ~)
        idxTemp = ui2.list2.Value; % selected item
        if idxTemp == 1 % do nothing if the first item was selected
            return
        end
        
        uncExpIdx2Temp1 = uncExpIdx2(idxTemp - 1); % index at the upper position
        uncExpIdx2Temp2 = uncExpIdx2(idxTemp); % index at the lower position (selected item)
        uncExpIdx2(idxTemp - 1) = uncExpIdx2Temp2; % switch places
        uncExpIdx2(idxTemp) = uncExpIdx2Temp1; % switch places
        
        stringTemp1 = ui2.list2.String{idxTemp - 1}; % string at the upper position
        stringTemp2 = ui2.list2.String{idxTemp}; % string at the lower position (selected item)
        ui2.list2.String{idxTemp - 1} = stringTemp2; % switch places
        ui2.list2.String{idxTemp} = stringTemp1; % switch places
        
        ui2.list2.Value = idxTemp - 1; %update selection
    end

    % uncaging - list 2, move down
    function list2MoveDn(src, ~)
        idxTemp = ui2.list2.Value; % selected item
        if idxTemp == length(ui2.list2.String) % do nothing if the last item was selected
            return
        end
        
        uncExpIdx2Temp1 = uncExpIdx2(idxTemp); % index at the upper position (selected item)
        uncExpIdx2Temp2 = uncExpIdx2(idxTemp + 1); % index at the lower position
        uncExpIdx2(idxTemp) = uncExpIdx2Temp2; % switch places
        uncExpIdx2(idxTemp + 1) = uncExpIdx2Temp1; % switch places
        
        stringTemp1 = ui2.list2.String{idxTemp}; % string at the upper position (selected item)
        stringTemp2 = ui2.list2.String{idxTemp + 1}; % string at the lower position
        ui2.list2.String{idxTemp} = stringTemp2; % switch places
        ui2.list2.String{idxTemp + 1} = stringTemp1; % switch places
        
        ui2.list2.Value = idxTemp + 1; %update selection
    end

    % uncaging - list 2, delete
    function list2Del(src, ~)
        if length(ui2.list2.String) == 0 % do nothing if source list is empty
            return
        end
        idxTemp = ui2.list2.Value; % selected item
        uncExpIdx2(idxTemp) = []; % delete index
        ui2.list2.String(idxTemp) = []; % delete string
        if idxTemp > length(ui2.list2.String) % this will happen if the last item was deleted
            ui2.list2.Value = length(ui2.list2.String); % otherwise the list will disappear
        end
    end

    % uncaging - display help message
    function ui2Help(src, ~)
        winHelp = figure('Name', sprintf('How to use analysis preset: %s', analysisPresetString), 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.4, 0.375, 0.2, 0.3], 'resize', 'off');
        winHelpText1 = uicontrol('Parent', winHelp, 'Style', 'text', 'string', sprintf('"%s" assumes pairwise arrangement of experiments. Place corresponding experiments into each list (aligned with its matching pair):', analysisPresetString), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.1, 0.75, 0.8, 0.2]);
        winHelpText2 = uicontrol('Parent', winHelp, 'Style', 'text', 'string', sprintf('Left: Units (Single, or group of, spine(s))  /  Right: Measured'), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.1, 0.675, 0.8, 0.1]);
        winHelpText3 = uicontrol('Parent', winHelp, 'Style', 'text', 'string', sprintf('Code will automatically detect unit size and spine increment (for Measured experiments) from metadata. Measured experiment results must have increasing number of spines, recruited in the same order as in the associated Units experiment. Increment in spine count does not have to match each unit size, i.e. units can be added together.'), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.1, 0.35, 0.8, 0.35]);
        winHelpText4 = uicontrol('Parent', winHelp, 'Style', 'text', 'string', sprintf('When metadata are not available for each sweep (e.g. when units were recorded in a single sweep, and truncated afterwards), unit size of 1 spine will be assumed. <!> Use caution when working without metadata while groups of spines are defined as units.'), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.1, 0.15, 0.8, 0.25]);
        winHelpClose = uicontrol('Parent', winHelp, 'Style', 'pushbutton', 'string', 'Close', 'horizontalalignment', 'center', 'backgroundcolor', [0.9, 0.9, 0.9], 'Units', 'normalized', 'Position', [0.4, 0.02, 0.2, 0.08], 'Callback', @closeWinHelp, 'interruptible', 'off');
        function closeWinHelp(src, ~)
            delete(winHelp);
        end
    end

%guidata(src, h); % has to be within each function

end


function runAutoAnalysisDBSL(src, ~)
% this was added ad hoc for DBSL experiments; now obsolete, but maybe can be used as a reference for setting up the preset in the future

% 1) i-o from single-stim sweeps; intensity = [50, 100, ...];
% 2) area after stim, by freq. at given intensity
% 3) area after stim, by intensity at given freq.
% -- ez so far
% 4) spike rate after stim train (e.g. 501-1000 ms)
% 5) Vm trend after stim train, long-term - difficult?
% 6) intrinsic before and after - gah

h = guidata(src);
results = h.results;
if isfield(h, 'results2')
    results2 = h.results2;
else
    results2 = {};
end
params = h.params;
exp = h.exp;
VRec = h.exp.data.VRec;
groupIdx = h.exp.data.groupIdx;
groupStr = h.exp.data.groupStr;
experimentCount = h.exp.experimentCount;

if isempty(h.ui.cellListDisplay.String)
    error('Error: No experiment file present to perform analysis');
end

if experimentCount > 7 % e.g. TTX+ at TS8
    experimentCount = 7;
end

% parameters
stimIntensity = [50, 100, 200, 300, 400, 500, 1000]; % watch out for omissions and repetitions
stimFrequency = [0, 20, 50, 100, 200]; % single-stim designated with 0 here
stimDuration = [0, 400, 400, 400, 400]; % single-stim designated with 0 here
groupInterval = 5;
windowA = [89, 99; 102, 152; 102, 5102];
windowA2Length = windowA(3, 2) - windowA(3, 1);
windowB = [89, 99; 55000, 60000; 55000, 60000];
windowB2Length = windowB(3, 2) - windowB(3, 1);

% just do analysis
for i = 1:experimentCount
    VRecNow = VRec{i};
    resultsTemp = struct();
    resultsTemp = analysisPeak(resultsTemp, params, VRecNow, windowA);
    resultsTemp2 = struct();
    resultsTemp2 = analysisPeak(resultsTemp2, params, VRecNow, windowB);
    results{i} = resultsTemp;
    results2{i} = resultsTemp2;
end

cellName = h.exp.fileName{1}(1:21);
tempResultsFig = figure('name', cellName, 'numbertitle', 'off', 'Units', 'Normalized', 'Position', [0.2, 0.25, 0.6, 0.5]);

% 1) i-o from single-stim sweeps
%  take first sweep from each TSer
iOY = [];
for i = 1:experimentCount
    resultsTemp = results{i};
    iOYTemp = resultsTemp.peak{1, 1}; % window 1, sweep 1
    iOYTemp = iOYTemp(3); % positive peaks - NB. bursts are difficult to exclude simply by window settings
    iOY = [iOY, iOYTemp];    
end
subplot(2,3,1); hold on;
plot(stimIntensity, iOY, 'color', 'k');
xlabel('Stimulation Intensity (uA)');
xticks([0, 100, 200, 300, 400, 500, 1000]);
ylabel('PSP peak (mV)');
title(cellName);
hold off;

tempResults.stimIntensity = stimIntensity;
tempResults.stimFrequency = stimFrequency;
tempResults.iO = iOY;

% 2) area after stim by freq at given intensity
%  simply analyze all sweeps at given TSer, then plot for each TSer with hold on
area1 = [];
area1Plot = [];
subplot(2,3,2); hold on;
for i = 1:experimentCount
    colorMapX = i;
    colorMapY = 1./(1 + exp(-((1/exp(1))*colorMapX - 1)));
    colorMapY = -colorMapY + 1;
    colorMap = [1, 1, 1];
    colorMap = colorMapY .* colorMap;

    sweeps = exp.sweeps{i};
    resultsTemp = results{i};
    area1Temp2 = [];
    area1Temp3 = [];
    area1Temp4 = [];
    area1Temp5 = [];
    area1Temp6 = [];
    for j = 1:sweeps
        area1Temp = resultsTemp.area{2, j}; % window 2, sweep j
        area1Temp = area1Temp(2); % absolute
        area1Temp2 = [area1Temp2, area1Temp];
    end
    %{
    for j = 6:10
        area1Temp = resultsTemp.area{2, j}; % window 2, sweep j
        area1Temp = area1Temp(2); % absolute
        area1Temp3 = [area1Temp3, area1Temp];
    end
    for j = 11:15
        area1Temp = resultsTemp.area{2, j}; % window 2, sweep j
        area1Temp = area1Temp(2); % absolute
        area1Temp4 = [area1Temp4, area1Temp];
    end
    %}
    %{
    for j = 16:20
        area1Temp = resultsTemp.area{2, j}; % window 2, sweep j
        area1Temp = area1Temp(2); % absolute
        area1Temp5 = [area1Temp5, area1Temp];
    end
    for j = 21:25
        area1Temp = resultsTemp.area{2, j}; % window 2, sweep j
        area1Temp = area1Temp(2); % absolute
        area1Temp6 = [area1Temp6, area1Temp];
    end
    %}
%    area1Temp7 = (area1Temp2 + area1Temp3 + area1Temp4 + area1Temp5 + area1Temp6) /5;
    %area1Temp7 = (area1Temp2 + area1Temp3 + area1Temp4) /3;
    area1Temp7 = area1Temp2;
    area1(i, :) = [area1Temp7];
    area1Plot(i) = plot(stimFrequency, area1(i, :), 'color', colorMap);
end
xlabel('Stimulation Frequency (Hz)');
xticks([0, 20, 50, 100, 200]);
ylabel(sprintf('Area (mV * ms);  %d s post-stim', windowA2Length/1000));
legend([area1Plot(7), area1Plot(6), area1Plot(5), area1Plot(4), area1Plot(3), area1Plot(2), area1Plot(1)], '1000', '500', '400', '300', '200', '100', '50 uA');
hold off;

tempResults.areaVsFreq = area1;

% 3) area after stim by intensity at given freq
%  analyze across all TSer for given sweep #, then plot for each sweep # with hold on
area2 = nan(sweeps, experimentCount);
area2x = nan(sweeps, experimentCount);
area2xx = nan(sweeps, experimentCount);
area2xxx = nan(sweeps, experimentCount);
area2xxxx = nan(sweeps, experimentCount);
area2xxxxx = nan(sweeps, experimentCount);
subplot(2,3,3); hold on;
for j = 1:sweeps % let's just use this as defined above
    area2Temp2 = [];
    for i = 1:experimentCount
        resultsTemp = results{i};
        area2Temp = resultsTemp.area{2, j}; % window 2, sweep j
        area2Temp = area2Temp(2); % absolute
        area2Temp2 = [area2Temp2, area2Temp];
    end
    area2x(j,:) = area2Temp2;
end
%{
for j = 6:10 % let's just use this as defined above
    area2Temp2 = [];
    for i = 1:experimentCount
        resultsTemp = results{i};
        area2Temp = resultsTemp.area{2, j}; % window 2, sweep j
        area2Temp = area2Temp(2); % absolute
        area2Temp2 = [area2Temp2, area2Temp];
    end
    area2xx(j-5,:) = area2Temp2;
end
for j = 11:15 % let's just use this as defined above
    area2Temp2 = [];
    for i = 1:experimentCount
        resultsTemp = results{i};
        area2Temp = resultsTemp.area{2, j}; % window 2, sweep j
        area2Temp = area2Temp(2); % absolute
        area2Temp2 = [area2Temp2, area2Temp];
    end
    area2xxx(j-10,:) = area2Temp2;
end
%}
%{
for j = 16:20 % let's just use this as defined above
    area2Temp2 = [];
    for i = 1:experimentCount
        resultsTemp = results{i};
        area2Temp = resultsTemp.area{2, j}; % window 2, sweep j
        area2Temp = area2Temp(2); % absolute
        area2Temp2 = [area2Temp2, area2Temp];
    end
    area2xxxx(j-15,:) = area2Temp2;
end
for j = 21:25 % let's just use this as defined above
    area2Temp2 = [];
    for i = 1:experimentCount
        resultsTemp = results{i};
        area2Temp = resultsTemp.area{2, j}; % window 2, sweep j
        area2Temp = area2Temp(2); % absolute
        area2Temp2 = [area2Temp2, area2Temp];
    end
    area2xxxxx(j-20,:) = area2Temp2;
end
%}
%area2 = (area2x + area2xx + area2xxx + area2xxxx + area2xxxxx) /5;
%area2 = (area2x + area2xx + area2xxx) /3;
area2 = area2x;
area2 = area2(1:5, :);

for j = 1:sweeps % let's just use this as defined above
    
    colorMapX = j;
    colorMapY = 1./(1 + exp(-((1/2)*colorMapX - 1)));
    colorMapY = -colorMapY + 1;
    colorMap = [1, 1, 1];
    colorMap = colorMapY .* colorMap;
    area2Plot(j) = plot(stimIntensity, area2(j, :), 'color', colorMap); % note first index is j not i
end
xlabel('Stimulation Intensity (uA)');
xticks([0, 100, 200, 300, 400, 500, 1000]);
ylabel(sprintf('Area (mV * ms);  %d s post-stim', windowA2Length/1000));
legend([area2Plot(5), area2Plot(4), area2Plot(3), area2Plot(2), area2Plot(1)], '200', '100', '50', '20 Hz', 'Single');
hold off;

tempResults.areaVsIntensity = area2;

h.results = results;

% 4) need threshold detection code

% 5) need sliding windows but seems manageable

vm0 = [];
vm0Plot = [];
subplot(2,3,4); hold on;
for i = 1:experimentCount

    sweeps = exp.sweeps{i};
    baseline = results2{i}.baseline;
    vm0Temp2 = [];
    for j = 1:sweeps
        vm0Temp = baseline{j}; % sweep j
        vm0Temp2 = [vm0Temp2, vm0Temp];
    end
    vm0(i, :) = [vm0Temp2];

end
vm0 = vm0'; % for reshape to work properly
vm0 = reshape(vm0, [1, size(vm0, 1) * size(vm0, 2)]);
%vm0Plot = plot(0:(1/4):(1/4)*(size(vm0, 1)*size(vm0, 2))-(1/4)*1, vm0, 'color', 'k');
%vm0Plot = plot(0:(1/3):(1/3)*(size(vm0, 1)*size(vm0, 2))-(1/3)*1, vm0, 'color', 'k');
vm0Plot = plot(0:(1):(1)*(size(vm0, 1)*size(vm0, 2))-(1)*1, vm0, 'color', 'k');
xlabel('t (min)');
%xticks([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60]);
ylabel('RMP (mV)');
hold off;

tempResults.RMP = vm0;


vm1 = [];
vm1Plot = [];
subplot(2,3,5); hold on;
for i = 1:experimentCount
    colorMapX = i;
    colorMapY = 1./(1 + exp(-((1/exp(1))*colorMapX - 1)));
    colorMapY = -colorMapY + 1;
    colorMap = [1, 1, 1];
    colorMap = colorMapY .* colorMap;

    sweeps = exp.sweeps{i};
    baseline = results2{i}.baseline;
    resultsTemp2 = results2{i};
    vm1Temp2 = [];
    vm1Temp3 = [];
    vm1Temp4 = [];
    vm1Temp5 = [];
    vm1Temp6 = [];
    for j = 1:sweeps
        vm1Temp = resultsTemp2.mean{2, j} - baseline{j}; % window 2, sweep j
        vm1Temp2 = [vm1Temp2, vm1Temp];
    end
    %{
    for j = 6:10
        vm1Temp = resultsTemp2.mean{2, j} - baseline{j}; % window 2, sweep j
        vm1Temp3 = [vm1Temp3, vm1Temp];
    end
    for j = 11:15
        vm1Temp = resultsTemp2.mean{2, j} - baseline{j}; % window 2, sweep j
        vm1Temp4 = [vm1Temp4, vm1Temp];
    end
    %}
    %{
    for j = 16:20
        vm1Temp = resultsTemp2.mean{2, j} - baseline{j}; % window 2, sweep j
        vm1Temp5 = [vm1Temp5, vm1Temp];
    end
    for j = 21:25
        vm1Temp = resultsTemp2.mean{2, j} - baseline{j}; % window 2, sweep j
        vm1Temp6 = [vm1Temp6, vm1Temp];
    end
    %}
    %vm1Temp7 = (vm1Temp2 + vm1Temp3 + vm1Temp4 + vm1Temp5 + vm1Temp6) /5;
    %vm1Temp7 = (vm1Temp2 + vm1Temp3 + vm1Temp4) /3;
    vm1Temp7 = vm1Temp2;
    vm1(i, :) = [vm1Temp7];
    vm1Plot(i) = plot(stimFrequency, vm1(i, :), 'color', colorMap);
end
xlabel('Stimulation Frequency (Hz)');
xticks([0, 20, 50, 100, 200]);
ylabel(sprintf('dV_m (mV), t = %d - %d (s))', windowB(3, 1)/1000, windowB(3, 2)/1000));
legend([vm1Plot(7), vm1Plot(6), vm1Plot(5), vm1Plot(4), vm1Plot(3), vm1Plot(2), vm1Plot(1)], '1000', '500', '400', '300', '200', '100', '50 uA');
hold off;

tempResults.dVmVsFreq = vm1;


vm2 = nan(sweeps, experimentCount);
vm2x = nan(sweeps, experimentCount);
vm2xx = nan(sweeps, experimentCount);
vm2xxx = nan(sweeps, experimentCount);
vm2xxxx = nan(sweeps, experimentCount);
vm2xxxxx = nan(sweeps, experimentCount);
subplot(2,3,6); hold on;

for j = 1:sweeps % let's just use this as defined above
    baseline = results2{i}.baseline;
    vm2Temp2 = [];
    for i = 1:experimentCount
        resultsTemp2 = results2{i};
        vm2Temp = resultsTemp2.mean{2, j} - baseline{j}; % window 2, sweep j
        vm2Temp2 = [vm2Temp2, vm2Temp];
    end
    vm2x(j,:) = vm2Temp2;
end
%{
for j = 6:10 % let's just use this as defined above
    baseline = results2{i}.baseline;
    vm2Temp2 = [];
    for i = 1:experimentCount
        resultsTemp2 = results2{i};
        vm2Temp = resultsTemp2.mean{2, j} - baseline{j}; % window 2, sweep j
        vm2Temp2 = [vm2Temp2, vm2Temp];
    end
    vm2xx(j-5,:) = vm2Temp2;
end
for j = 11:15 % let's just use this as defined above
    baseline = results2{i}.baseline;
    vm2Temp2 = [];
    for i = 1:experimentCount
        resultsTemp2 = results2{i};
        vm2Temp = resultsTemp2.mean{2, j} - baseline{j}; % window 2, sweep j
        vm2Temp2 = [vm2Temp2, vm2Temp];
    end
    vm2xxx(j-10,:) = vm2Temp2;
end
%}
%{
for j = 16:20 % let's just use this as defined above
    baseline = results2{i}.baseline;
    vm2Temp2 = [];
    for i = 1:experimentCount
        resultsTemp2 = results2{i};
        vm2Temp = resultsTemp2.mean{2, j} - baseline{j}; % window 2, sweep j
        vm2Temp2 = [vm2Temp2, vm2Temp];
    end
    vm2xxxx(j-15,:) = vm2Temp2;
end
for j = 21:25 % let's just use this as defined above
    baseline = results2{i}.baseline;
    vm2Temp2 = [];
    for i = 1:experimentCount
        resultsTemp2 = results2{i};
        vm2Temp = resultsTemp2.mean{2, j} - baseline{j}; % window 2, sweep j
        vm2Temp2 = [vm2Temp2, vm2Temp];
    end
    vm2xxxxx(j-20,:) = vm2Temp2;
end
%}
%vm2 = (vm2x + vm2xx + vm2xxx + vm2xxxx + vm2xxxxx) /5;
%vm2 = (vm2x + vm2xx + vm2xxx) /3;
vm2 = vm2x;
vm2 = vm2(1:5, :);
    
for j = 1:sweeps % let's just use this as defined above
    
    colorMapX = j;
    colorMapY = 1./(1 + exp(-((1/2)*colorMapX - 1)));
    colorMapY = -colorMapY + 1;
    colorMap = [1, 1, 1];
    colorMap = colorMapY .* colorMap;

    vm2Plot(j) = plot(stimIntensity, vm2(j, :), 'color', colorMap); % note first index is j not i
end
xlabel('Stimulation Intensity (uA)');
xticks([0, 100, 200, 300, 400, 500, 1000]);
ylabel(sprintf('dV_m (mV), t = %d - %d (s))', windowB(3, 1)/1000, windowB(3, 2)/1000));
legend([vm2Plot(5), vm2Plot(4), vm2Plot(3), vm2Plot(2), vm2Plot(1)], '200', '100', '50', '20 Hz', 'Single');
hold off;

tempResults.dVmVsIntensity = vm2;


% 6) maybe can reuse code from scracm

saveas(tempResultsFig, cellName, 'png');

h.tempResults = tempResults;
h.results = results;
guidata(src, h);

end


function results = analysisPeak(results, params, data, windows)
% peak analysis - also calculate area and mean
% code as old as time

% parameters
windowNum = size(windows, 1) - 1; % number of windows - subtract 1 to account for baseline (row 1)
%direction = params.peakDirection; % -1: negative, 0: absolute, +1: positive - obsolete

% parameters %%% hard-coded now, but fix to detect from metadata
%{
timeColumn = 1;
analysisColumn = 2; %%% either use array later to iterate for multiple signals, or simply iterate argument to be passed on
riseDecay = [20, 80]; % percentage of peak for rise/decay calculation
useMedian = 1; % use median instead of mean if 1 %%% implement later, this is not important
%}
timeColumn = params.actualParams.timeColumn;
analysisColumn = params.actualParams.analysisColumn; %%% either use array later to iterate for multiple signals, or simply iterate argument to be passed on
riseDecay = params.actualParams.riseDecay; % percentage of peak for rise/decay calculation
useMedian = params.actualParams.useMedian; % use median instead of mean if 1 %%% implement later, this is not important

% convert time to data points
if iscell(data)
else % if not a cell, e.g. if there is only one TSeries file
    dataCell = {data};
    data = dataCell; % convert to cell for code compatibility
end
% below is problematic for data with potentially different sampling rates across sweeps - moved to iterate for every sweep
%{
dataNow = data{1} % simply pick the first entry for this purpose
samplingInterval = dataNow(2, timeColumn) - dataNow(1, timeColumn); % (ms)
samplingFrequency = 1/samplingInterval; % (kHz)
windows = round(windows ./ samplingInterval) % converting to datapoints
windows = windows + 1; % add 1 because timestamp starts at t = 0, (i.e. point 1)
%}

% sweeps in signal to be analyzed
VRecSweeps = length(data);

% calculate baseline - moved to iterate for each sweep as well
%{
baseline = {}; % initialize
for i = 1:VRecSweeps
    if isempty(data{i})
        dataNow = nan(size(data{1})); %%% fuck it
    else
        dataNow = data{i};
    end
    if useMedian
        baseline{end + 1} = nanmedian(dataNow(windows(1,1):windows(1,2), analysisColumn)); % baseline must be at the first row of input argument "window"
    else
        baseline{end + 1} = nanmean(dataNow(windows(1,1):windows(1,2), analysisColumn));
    end
end
results.baseline = baseline;
%}

% do analysis
%  initialize cells for results from all windows
baseline = {};
peak = {};
area = {};
mean = {};
timeOfPeak = {}; % NB. not time to peak
riseTime = {};
riseSlope = {};
decayTime = {};
decaySlope = {};

%  iterate for windows - start at 2nd row, since 1st row is baseline
for j = 2:size(windows, 1)
    
    %  initialize cells for results from current window
    peakWin = {};
    timeOfPeakWin = {}; % NB. not time to peak
    riseTimeWin = {};
    riseSlopeWin = {};
    decayTimeWin = {};
    decaySlopeWin = {};
    areaWin = {};
    meanWin = {};

    % if window is unavailable, leave cells empty and move onto next row for writing
    checkWin = sum(isnan(windows(j,:)));
    if checkWin ~= 0
        if j == size(windows, 1) % if at last window, do not add another row
            continue % move onto next window - since nonexistent, loop will end
        else
            peak = [peak; peakWin];
            timeOfPeak = [timeOfPeak; timeOfPeakWin]; % NB. not time to peak
            riseTime = [riseTime; riseTimeWin];
            riseSlope = [riseSlope; riseSlopeWin];
            decayTime = [decayTime; decayTimeWin];
            decaySlope = [decaySlope; decaySlopeWin];
            area = [area; areaWin];
            mean = [mean; meanWin];
            continue % move onto next window
        end
    end
    
    % iterate for sweeps
    for i = 1:VRecSweeps
        
        if isempty(data{i})
            %%{
            peakNow = [NaN, NaN, NaN];
            peakWin{end + 1} = peakNow;
            timeOfPeakNow = [NaN, NaN, NaN];
            timeOfPeakWin{end + 1} = timeOfPeakNow;
            riseTimeNow = [NaN, NaN, NaN];
            riseTimeWin{end + 1} = riseTimeNow;
            decayTimeNow = [NaN, NaN, NaN];
            decayTimeWin{end + 1} = decayTimeNow;
            riseSlopeNow = [NaN, NaN, NaN];
            riseSlopeWin{end + 1} = riseSlopeNow;
            decaySlopeNow = [NaN, NaN, NaN];
            decaySlopeWin{end + 1} = decaySlopeNow;
            areaNow = [NaN, NaN, NaN];
            areaWin{end + 1} = areaNow;
            meanNow = NaN;
            meanWin{end + 1} = meanNow;
            %}
            %{
            peak = [peak; peakWin];
            timeOfPeak = [timeOfPeak; timeOfPeakWin]; % NB. not time to peak
            riseTime = [riseTime; riseTimeWin];
            riseSlope = [riseSlope; riseSlopeWin];
            decayTime = [decayTime; decayTimeWin];
            decaySlope = [decaySlope; decaySlopeWin];
            area = [area; areaWin];
            mean = [mean; meanWin];
            %}
            %{
            peak = [peak; {}];
            timeOfPeak = [timeOfPeak; {}]; % NB. not time to peak
            riseTime = [riseTime; {}];
            riseSlope = [riseSlope; {}];
            decayTime = [decayTime; {}];
            decaySlope = [decaySlope; {}];
            area = [area; {}];
            mean = [mean; {}];
            
            %}
            continue
        end

        % set sampling rate and re-define windows
        if isempty(data{i})
            for j = 1:length(VRecSweeps) % find first sweep that is not empty
                if isempty(data{j})
                    continue
                else
                    break
                end
            end
            dataNow = nan(size(data{j})); %%%%%%% dummy if data is absent, e.g. F after segmentation
            samplingInterval = NaN;
            samplingFrequency = NaN;
            windowsNew = nan(size(windows));
            
        else
            dataNow = data{i}; % current sweep
            samplingInterval = dataNow(2, timeColumn) - dataNow(1, timeColumn); % (ms)
            samplingFrequency = 1/samplingInterval; % (kHz)
            windowsNew = round(windows ./ samplingInterval); % converting to datapoints
            windowsNew = windowsNew + 1; % add 1 because timestamp starts at t = 0, (i.e. point 1)
        end
                
        % calculate baseline
        if isempty(data{i})
            baselineNow = NaN;
        else
            if useMedian
                %baseline{end + 1} = nanmedian(dataNow(windows(1,1):windows(1,2), analysisColumn)); % baseline must be at the first row of input argument "window"
                baselineNow = nanmedian(dataNow(windowsNew(1,1):windowsNew(1,2), analysisColumn)); % baseline must be at the first row of input argument "window"
            else
                %baseline{end + 1} = nanmean(dataNow(windows(1,1):windows(1,2), analysisColumn));
                baselineNow = nanmean(dataNow(windowsNew(1,1):windowsNew(1,2), analysisColumn));
            end
        end
        baseline{end + 1} = baselineNow;
                
        %{
        if isempty(data{i})
            %{
            peakNow = [NaN, NaN, NaN];
            peakWin{end + 1} = peakNow;
            timeOfPeakNow = [NaN, NaN, NaN];
            timeOfPeakWin{end + 1} = timeOfPeakNow;
            riseTimeNow = [NaN, NaN, NaN];
            riseTimeWin{end + 1} = riseTimeNow;
            decayTimeNow = [NaN, NaN, NaN];
            decayTimeWin{end + 1} = decayTimeNow;
            riseSlopeNow = NaN;
            riseSlopeWin{end + 1} = riseSlopeNow;
            decaySlopeNow = NaN;
            decaySlopeWin{end + 1} = decaySlopeNow;
            areaNow = [NaN, NaN, NaN];
            areaWin{end + 1} = areaNow;
            meanNow = NaN;
            meanWin{end + 1} = meanNow;

            peak = [peak; peakWin];
            timeOfPeak = [timeOfPeak; timeOfPeakWin]; % NB. not time to peak
            riseTime = [riseTime; riseTimeWin];
            riseSlope = [riseSlope; riseSlopeWin];
            decayTime = [decayTime; decayTimeWin];
            decaySlope = [decaySlope; decaySlopeWin];
            area = [area; areaWin];
            mean = [mean; meanWin];
            %}
            %{
            peak = [peak; {}];
            timeOfPeak = [timeOfPeak; {}]; % NB. not time to peak
            riseTime = [riseTime; {}];
            riseSlope = [riseSlope; {}];
            decayTime = [decayTime; {}];
            decaySlope = [decaySlope; {}];
            area = [area; {}];
            mean = [mean; {}];

            %}
            continue
        end
        %}
        
        % prepare data
        %baselineNow = baseline{i};
        if isempty(data{i})
            dataNow = nan(size(data{1})); %%% fuck it
        else
            dataNowTimeColumn = dataNow(:, timeColumn);
            dataNow = data{i} - baselineNow; % adjust values relative to current baseline
            dataNow(:, timeColumn) = dataNowTimeColumn; % back and forth back and forth %%% fixlater
        end
        
        % peak
        peakNeg = NaN; % initialize cuz somehow it can fail
        peakAbs = NaN;
        peakPos = NaN;
        if windowsNew(j, 2) > size(dataNow, 1)
            windowsNew(j, 2) = size(dataNow, 1); % if window exceeds data length, limit to end of data
        end
        peakPos = nanmax(dataNow(windowsNew(j,1):windowsNew(j,2) - 1, analysisColumn)); % maximum positive deflection
        peakNeg = nanmin(dataNow(windowsNew(j,1):windowsNew(j,2) - 1, analysisColumn)); % maximum negative deflection
        if isnan(peakPos)
        else
            peakPos = max(0, peakPos); % positive-going
        end
        if isnan(peakNeg)
        else
            peakNeg = min(0, peakNeg); % negative-going
        end
        % compare absolute values - will be used later
        if isnan(peakPos) && isnan(peakNeg) % both NaN
            peakAbsFlag = 0;
            peakAbs = NaN;
        elseif isnan(peakNeg) % peakNeg is NaN, peakPos is not NaN
            peakAbsFlag = 1;
        elseif isnan(peakPos) % peakPos is NaN, peakNeg is not NaN
            peakAbsFlag = -1;
        else % neither is NaN
            if peakPos >= abs(peakNeg) % positive-going peak has larger absolute value
                peakAbsFlag = 1;
            else % negative-going peak has larger absolute value
                peakAbsFlag = -1;
            end
        end
        if peakAbsFlag == 0
        else
            peakAbs = peakAbsFlag * max(peakPos, abs(peakNeg)); % either direction
        end
        peakNow = [peakNeg, peakAbs, peakPos];
        if length(peakNow) ~= 3
            error('error during peak calculation - dimension mismatch');
        end
        peakWin{end + 1} = peakNow; % use this order for easier use with my (-1, 0, +1) convention
        
        % time of peak (NB. not time "to" peak)
        %  negative
        peakNegTime = NaN; % initialize to avoid dimension mismatch
        if isnan(peakNeg)
            peakNegTime = NaN;
        elseif peakNeg == 0 % if inapplicable
            peakNegTime = NaN;
        else
            peakNegTimeIdx = find(dataNow(windowsNew(j,1):windowsNew(j,2) - 1, analysisColumn) == peakNeg, 1); % relative index at peak
            peakNegTimeIdx = peakNegTimeIdx + windowsNew(j, 1) - 1; % correct for offset by window start, as introduced by previous calculation
            peakNegTime = dataNow(peakNegTimeIdx, timeColumn);
        end
        %  absolute
        peakAbsTime = NaN; % initialize to avoid dimension mismatch
        if isnan(peakAbs)
            %peakAbsTime = NaN;
        elseif peakAbs == 0 % if inapplicable
            %peakAbsTime = NaN;
        else
            peakAbsTimeIdx = find(dataNow(windowsNew(j,1):windowsNew(j,2) - 1, analysisColumn) == peakAbs, 1); % relative index at peak
            peakAbsTimeIdx = peakAbsTimeIdx + windowsNew(j, 1) - 1; % correct for offset by window start, as introduced by previous calculation
            peakAbsTime = dataNow(peakAbsTimeIdx, timeColumn);
        end
        %  positive
        peakPosTime = NaN; % initialize to avoid dimension mismatch
        if isnan(peakPos)
            %peakPosTime = NaN;
        elseif peakPos == 0 % if inapplicable
            %peakPosTime = NaN;
        else
            peakPosTimeIdx = find(dataNow(windowsNew(j,1):windowsNew(j,2) - 1, analysisColumn) == peakPos, 1); % relative index at peak
            peakPosTimeIdx = peakPosTimeIdx + windowsNew(j, 1) - 1; % correct for offset by window start, as introduced by previous calculation
            peakPosTime = dataNow(peakPosTimeIdx, timeColumn);
        end
        %  save
        timeOfPeakNow = [peakNegTime, peakAbsTime, peakPosTime];
        if length(timeOfPeakNow) ~= 3
            error('error during time-of-peak calculation - dimension mismatch');
        end
        timeOfPeakWin{end + 1} = timeOfPeakNow;
        
        % rise, decay, slope
        %  set low and high points
        riseDecayLow = riseDecay(1); % low point, e.g. 20% (NB. value should be 20, not 0.2)
        riseDecayHigh = riseDecay(2); % high point, e.g. 80% (NB. value should be 80, not 0.8)
        riseDecayLow = [peakNeg, peakAbs, peakPos] * riseDecayLow/100; % relative to detected peak
        riseDecayHigh = [peakNeg, peakAbs, peakPos] * riseDecayHigh/100; % relative to detected peak
        %  detect time at rise and decay phase
        if isnan(peakNegTime)
            riseTimeNeg = NaN;
            decayTimeNeg = NaN;
        else 
            dataNowRiseLowNeg = find(dataNow(windowsNew(j,1):peakNegTimeIdx, analysisColumn) - riseDecayLow(1) < 0, 1); % first time crossing, before negative peak
            dataNowRiseHighNeg = find(dataNow(windowsNew(j,1):peakNegTimeIdx, analysisColumn) - riseDecayHigh(1) < 0, 1); % first time crossing, before negative peak
            dataNowDecayLowNeg = find(dataNow(peakNegTimeIdx:windowsNew(j,2) - 1, analysisColumn) - riseDecayLow(1) > 0, 1); % first time crossing, before negative peak
            dataNowDecayHighNeg = find(dataNow(peakNegTimeIdx:windowsNew(j,2) - 1, analysisColumn) - riseDecayHigh(1) > 0, 1); % first time crossing, before negative peak
            dataNowRiseLowNeg = dataNowRiseLowNeg + windowsNew(j, 1) - 1;
            dataNowRiseHighNeg = dataNowRiseHighNeg + windowsNew(j, 1) - 1;
            dataNowDecayLowNeg = dataNowDecayLowNeg + windowsNew(j, 1) - 1;
            dataNowDecayHighNeg = dataNowDecayHighNeg + windowsNew(j, 1) - 1;
            riseTimeNeg = abs(dataNowRiseLowNeg - dataNowRiseHighNeg); % use difference to simply account for all directions and phases
            decayTimeNeg = abs(dataNowDecayLowNeg - dataNowDecayHighNeg); % use difference to simply account for all directions and phases
        end
        if isnan(peakAbsTime)
            riseTimeAbs = NaN;
            decayTimeAbs = NaN;
        else
            if peakAbsFlag == 1 % positive-going peak was chosen
                dataNowRiseLowAbs = find(dataNow(windowsNew(j,1):peakAbsTimeIdx, analysisColumn) - riseDecayLow(2) > 0, 1); % first time crossing, before positive peak
                dataNowRiseHighAbs = find(dataNow(windowsNew(j,1):peakAbsTimeIdx, analysisColumn) - riseDecayHigh(2) > 0, 1); % first time crossing, before positive peak
                dataNowDecayLowAbs = find(dataNow(peakAbsTimeIdx:windowsNew(j,2) - 1, analysisColumn) - riseDecayLow(2) < 0, 1); % first time crossing, before positive peak
                dataNowDecayHighAbs = find(dataNow(peakAbsTimeIdx:windowsNew(j,2) - 1, analysisColumn) - riseDecayHigh(2) < 0, 1); % first time crossing, before positive peak
            elseif peakAbsFlag == -1 % negative-going peak was chosen
                dataNowRiseLowAbs = find(dataNow(windowsNew(j,1):peakAbsTimeIdx, analysisColumn) - riseDecayLow(2) < 0, 1); % first time crossing, before negative peak
                dataNowRiseHighAbs = find(dataNow(windowsNew(j,1):peakAbsTimeIdx, analysisColumn) - riseDecayHigh(2) < 0, 1); % first time crossing, before negative peak
                dataNowDecayLowAbs = find(dataNow(peakAbsTimeIdx:windowsNew(j,2) - 1, analysisColumn) - riseDecayLow(2) > 0, 1); % first time crossing, before negative peak
                dataNowDecayHighAbs = find(dataNow(peakAbsTimeIdx:windowsNew(j,2) - 1, analysisColumn) - riseDecayHigh(2) > 0, 1); % first time crossing, before negative peak
            else % neither, e.g. both NaN
                dataNowRiseLowAbs = NaN;
                dataNowRiseHighAbs = NaN;
                dataNowDecayLowAbs = NaN;
                dataNowDecayHighAbs = NaN;
            end
            dataNowRiseLowAbs = dataNowRiseLowAbs + windowsNew(j, 1) - 1;
            dataNowRiseHighAbs = dataNowRiseHighAbs + windowsNew(j, 1) - 1;
            dataNowDecayLowAbs = dataNowDecayLowAbs + windowsNew(j, 1) - 1;
            dataNowDecayHighAbs = dataNowDecayHighAbs + windowsNew(j, 1) - 1;
            riseTimeAbs = abs(dataNowRiseLowAbs - dataNowRiseHighAbs); % use difference to simply account for all directions and phases
            decayTimeAbs = abs(dataNowDecayLowAbs - dataNowDecayHighAbs); % use difference to simply account for all directions and phases
        end
        if isnan(peakPosTime)
            riseTimePos = NaN;
            decayTimePos = NaN;
        else
            dataNowRiseLowPos = find(dataNow(windowsNew(j,1):peakPosTimeIdx, analysisColumn) - riseDecayLow(3) > 0, 1); % first time crossing, before positive peak
            dataNowRiseHighPos = find(dataNow(windowsNew(j,1):peakPosTimeIdx, analysisColumn) - riseDecayHigh(3) > 0, 1); % first time crossing, before positive peak
            dataNowDecayLowPos = find(dataNow(peakPosTimeIdx:windowsNew(j,2) - 1, analysisColumn) - riseDecayLow(3) < 0, 1); % first time crossing, before positive peak
            dataNowDecayHighPos = find(dataNow(peakPosTimeIdx:windowsNew(j,2) - 1, analysisColumn) - riseDecayHigh(3) < 0, 1); % first time crossing, before positive peak
            dataNowRiseLowPos = dataNowRiseLowPos + windowsNew(j, 1) - 1;
            dataNowRiseHighPos = dataNowRiseHighPos + windowsNew(j, 1) - 1;
            dataNowDecayLowPos = dataNowDecayLowPos + windowsNew(j, 1) - 1;
            dataNowDecayHighPos = dataNowDecayHighPos + windowsNew(j, 1) - 1;
            riseTimePos = abs(dataNowRiseLowPos - dataNowRiseHighPos); % use difference to simply account for all directions and phases
            decayTimePos = abs(dataNowDecayLowPos - dataNowDecayHighPos); % use difference to simply account for all directions and phases
        end
        
        if isempty(riseTimeNeg)
            riseTimeNeg = NaN;
        end
        if isempty(riseTimeAbs)
            riseTimeAbs = NaN;
        end
        if isempty(riseTimePos)
            riseTimePos = NaN;
        end
        if isempty(decayTimeNeg)
            decayTimeNeg = NaN;
        end
        if isempty(decayTimeAbs)
            decayTimeAbs = NaN;
        end
        if isempty(decayTimePos)
            decayTimePos = NaN;
        end
        %  save rise and decay time
        riseTimeNow = [riseTimeNeg, riseTimeAbs, riseTimePos];
        riseTimeNow = riseTimeNow * samplingInterval; % converting from points to ms
        riseTimeWin{end + 1} = riseTimeNow;
        decayTimeNow = [decayTimeNeg, decayTimeAbs, decayTimePos];
        decayTimeNow = decayTimeNow * samplingInterval; % converting from points to ms
        decayTimeWin{end + 1} = decayTimeNow;
        peakLowHighDiff = (riseDecay(2) - riseDecay(1))/100 .* peakNow; % peak amplitude scaled by low-high point difference
        riseSlopeNow = peakLowHighDiff ./ riseTimeNow; % (mV/ms)
        riseSlopeWin{end + 1} = riseSlopeNow;
        decaySlopeNow = peakLowHighDiff ./ decayTimeNow;
        decaySlopeWin{end + 1} = decaySlopeNow;
        
        % area
        areaNowNeg = 0; % initialize
        areaNowAbs = 0; % initialize
        areaNowPos = 0; % initialize
        for k = windowsNew(j,1):windowsNew(j,2) - 1 % analysis window
            areaNowNeg = areaNowNeg + min(0, dataNow(k, analysisColumn) * samplingInterval); % e.g. (mV * ms)
            areaNowAbs = areaNowAbs + dataNow(k, analysisColumn) * samplingInterval; % e.g. (mV * ms)
            areaNowPos = areaNowPos + max(0, dataNow(k, analysisColumn) * samplingInterval); % e.g. (mV * ms)
        end
        %{
        areaNow = [areaNowNeg, areaNowAbs, areaNowPos];
        areaWin{end + 1} = areaNow;
        %}
        %%% clumsy af but will practically work
        if areaNowNeg == 0
            areaNowNeg = NaN; %%% cuz no fucking way
        end
        if areaNowPos == 0
            areaNowPos = NaN; %%% cuz no fucking way
        end
        areaNow = [areaNowNeg, areaNowAbs, areaNowPos]; % abs is properly calculated
        areaWin{end + 1} = areaNow;
        
        % mean
        if useMedian
            meanNow = nanmedian(dataNow(windowsNew(j,1):windowsNew(j,2) - 1, analysisColumn)); % just call it mean instead of using another variable
        else
            meanNow = nanmean(dataNow(windowsNew(j,1):windowsNew(j,2) - 1, analysisColumn)); % just call it mean instead of using another variable
        end
        meanNow = meanNow + baselineNow; % re-adjust for baseline that had been subtracted
        meanWin{end + 1} = meanNow;
        
    end
    
    % append results from each window into final results
    peak = [peak; peakWin];
    timeOfPeak = [timeOfPeak; timeOfPeakWin]; % NB. not time to peak
    riseTime = [riseTime; riseTimeWin];
    riseSlope = [riseSlope; riseSlopeWin];
    decayTime = [decayTime; decayTimeWin];
    decaySlope = [decaySlope; decaySlopeWin];
    area = [area; areaWin];
    mean = [mean; meanWin];
    
end


% save
results.baseline = baseline;
results.peak = peak;
results.area = area;
results.mean = mean;
results.timeOfPeak = timeOfPeak;
results.riseTime = riseTime;
results.decayTime = decayTime;
results.riseSlope = riseSlope;
results.decaySlope = decaySlope;

end


function resultsTemp = analysisThresholdDetection(resultsTemp, params, VRecData, window)

errorMessage = 'Error: Feature currently unavailable, under development';
fprintf(errorMessage);
%resultsTemp = [];

end


function resultsTemp = analysisAPWaveform(resultsTemp, params, VRecData, window)

errorMessage = 'Error: Feature currently unavailable, under development';
fprintf(errorMessage);
%resultsTemp = [];

end


function analysisTargetSel(src, event)
end


function analysisTypeSel(src, event)
% callback for analysis type selection

% load
h = guidata(src);

% I'm so lazy %%% fixlater
switch h.ui.analysisType1.Value
    case 3
        errorMessage = sprintf('\nSelection aborted: Threshold detection feature unavailable with current version of PVBS\n');
        fprintf(errorMessage);
        h.ui.analysisType1.Value = 1;
        return
    case 4
        errorMessage = sprintf('\nSelection aborted: Waveform analysis feature unavailable with current version of PVBS\n');
        fprintf(errorMessage);
        h.ui.analysisType1.Value = 1;
        return
end
switch h.ui.analysisType2.Value
    case 3
        errorMessage = sprintf('\nSelection aborted: Threshold detection feature unavailable with current version of PVBS\n');
        fprintf(errorMessage);
        h.ui.analysisType2.Value = 1;
        return
    case 4
        errorMessage = sprintf('\nSelection aborted: Waveform analysis feature unavailable with current version of PVBS\n');
        fprintf(errorMessage);
        h.ui.analysisType2.Value = 1;
        return
end

% analysis types
try
switch h.ui.analysisType1.Value % analysis type for window 1
    case 1 % unselected
    case 2 % peak/area/mean
        switch h.ui.analysisPlot1Menu2.Value % plot 1, window number
            case 1 % unselected
                h.ui.analysisPlot1Menu3.String = h.params.analysisPlotMenuList3; % to default
            case 2 % window 1
                h.ui.analysisPlot1Menu3.String = h.params.analysisPlotMenuList31;
                h.ui.analysisPlot1Menu3.Value = 2; % default to peak
            case 3 % window 2
                h.ui.analysisPlot1Menu3.String = h.params.analysisPlotMenuList3; % to default
        end
    %%% below not available yet
    case 3 % threshold detection
    case 4 % waveform
end
catch ME
end
try
switch h.ui.analysisType2.Value % analysis type for window 2
    case 1 % unselected
    case 2 % peak/area/mean
        switch h.ui.analysisPlot2Menu2.Value % plot 1, window number
            case 1 % unselected
                h.ui.analysisPlot2Menu3.String = h.params.analysisPlotMenuList3; % to default
            case 2 % window 1
                h.ui.analysisPlot2Menu3.String = h.params.analysisPlotMenuList3; % to default
            case 3 % window 2
                h.ui.analysisPlot2Menu3.String = h.params.analysisPlotMenuList31;
                h.ui.analysisPlot2Menu3.Value = 2; % default to peak
        end
    %%% below not available yet
    case 3 % threshold detection
    case 4 % waveform
end
catch ME
end
% save
guidata(src, h);

end

function analysisOptionSel(src, event)
end


% VoltageRecording analysis selector
function output = oldAnalysisVRec(input_data, input_data_name, param_window, param_baseline, param_data_voltage_interval)

% Select and run analysis
%
% actual analysis will be performed by specific functions, with arguments carried over
% input_data: episodic data with no row offset, n*m*j array
%  n: data points in each sweep
%  m: number of channels (...+1 if timestamp is in column 1)
%  j: number of sweeps
% input_data_name: name of input data (to be used in figures)
% param_window: peak detection window; w*3 array --- move into this function!! ditto for bsln!
%  w: number of windows
%  each row: start, end (points), direction (-1: negative, 0: unbiased, 1: positive)
% param_baseline: baseline window; w*3 (for each detection window) or 1*3 (for shared baseline) array
%  each row: start, end (points), use median? (0: mean, 1: median)
%
% output: struct with u fields, each value being a 1*w cell,
%  whose elements are structs with k fields and values of j*m*k arrays (from specific analysis)
%   u: number of analysis types (e.g. peak, area, ...)
%   w: number of windows
%   k: number of output types (e.g. peak, time of peak, rise, decay, ...)
%   j: number of sweeps (for each sweep in input_data)
%   m: number of channels (for each channel in input_data)


% Supported analysis types; see also the output struct initialization below and assignment at the bottom 
%  will be used for field names in a struct, so do not use spaces, etc.
analysis_type_list = {'peak_amplitude', 'peak_kinetics', 'area', 'spike', 'mean_and_median', 'intrinsic_properties'};

% Initialize output struct
output = struct(analysis_type_list{1}, [], analysis_type_list{2}, [], analysis_type_list{3}, [], analysis_type_list{4}, [], analysis_type_list{5}, [], analysis_type_list{6}, []);
if numel(fields(output)) ~= size(analysis_type_list, 2)
    error(sprintf('\nOutput struct field number does not match number of analysis types available; revise code\n'));
end

% Prompt to select analysis type(s)
%{
[analysis_type_selected_idx, tf] = listdlg('ListString', analysis_type_list, 'InitialValue', size(analysis_type_list, 2), 'Name', 'Select type(s) of analysis', 'PromptString', 'Select type(s) of analysis', 'selectionmode', 'single');
clear tf;
%}
analysis_type_selected_idx = size(analysis_type_list, 2); % for automated script
analysis_type_selected = {};
for idx = 1:size(analysis_type_selected_idx, 2)
    analysis_type_selected{idx} = analysis_type_list{analysis_type_selected_idx(idx)};
end
clear idx;
%clear analysis_type_selected_idx; % do not clear; indices will be used later

% Check if baseline is shared
if size(param_window, 1) == size(param_baseline, 1)
elseif size(param_baseline, 1) == 1
    for idx = 2:size(param_window, 1)
        param_baseline(idx, :) = param_baseline(1, :); % for convenience
    end
    clear idx;
else
    error(sprintf('\nBaseline must be either shared or assigned for every window\n'));
end

% Initialize temporary output cell and output struct
output_temp = cell(size(analysis_type_list, 2), size(param_window, 1));

% Run analysis
for idx1 = 1:size(analysis_type_selected, 2) % iterate for analysis types selected
    for idx2 = 1:size(param_window, 1) % iterate for windows
        switch analysis_type_selected{idx1}
            case analysis_type_list{1} % peak_amplitude
                output_temp{analysis_type_selected_idx(idx1), idx2} = analysis_peak_amplitude(input_data, input_data_name, param_window(idx2, :), param_baseline(idx2, :));
            case analysis_type_list{2} % peak_kinetics
                output_temp{analysis_type_selected_idx(idx1), idx2} = analysis_peak_kinetics(input_data, input_data_name, param_window(idx2, :), param_baseline(idx2, :));
            case analysis_type_list{3} % area
                output_temp{analysis_type_selected_idx(idx1), idx2} = analysis_area(input_data, input_data_name, param_window(idx2, :), param_baseline(idx2, :));
            case analysis_type_list{4} % spike
                output_temp{analysis_type_selected_idx(idx1), idx2} = analysis_spike(input_data, input_data_name, param_window(idx2, :), param_baseline(idx2, :));
            case analysis_type_list{5} % mean_and_median
                output_temp{analysis_type_selected_idx(idx1), idx2} = analysis_mean_median(input_data, input_data_name, param_window(idx2, :), param_baseline(idx2, :));
            case analysis_type_list{6} % intrinsic_properties
                output_temp{analysis_type_selected_idx(idx1), idx2} = oldAnalysisIntrinsic(input_data, input_data_name, param_window(idx2, :), param_baseline(idx2, :), param_data_voltage_interval);
            otherwise
                disp(sprintf('\nfix later\n'));
        end
    end
end
clear idx1 idx2;

% Assign into output struct
idx = 1;
output.peak_amplitude = output_temp(idx,:); idx = idx + 1;
output.peak_kinetics = output_temp(idx,:); idx = idx + 1;
output.area = output_temp(idx,:); idx = idx + 1;
output.spike = output_temp(idx,:); idx = idx + 1;
output.mean_and_median = output_temp(idx,:); idx = idx + 1;
output.intrinsic_properties = output_temp(idx,:); idx = idx + 1;
clear idx;

% Clear empty fields from output struct
output = output(~cellfun(@isempty,{output}));

end


% Calculate intrinsic membrane properties
function output = oldAnalysisIntrinsic(input_data, input_data_name, param_window, param_baseline, param_data_voltage_interval)

% Calculate i-V (& f-i) relationship, using analysis_peak.m & analysis_mean.m (or analysis_median.m)
% Also calculate RMP, R_in, & sag ratio
% intended to work with detection window covering the duration of current injection
%
% input_data: episodic data with no row offset, n*m*j array
%  n: data points in each sweep
%  m: number of channels (...+1 if timestamp is in column 1)
%  j: number of sweeps
% input_data_name: name of input data (to be used in figures)
% param_window: detection window; 1*3 array
%  (start, end (points), direction (-1: negative, 0: unbiased, 1: positive))
% param_baseline: baseline window; 1*3 array
%  (start, end (points), use median? (0: mean, 1: median))
%
% output: struct with k fields, each value being a j*m array
%  k: number of output types (e.g. peak, time of peak, rise, decay, ...)
%  j: number of sweeps (for each sweep in input_data)
%  m: number of channels (for each channel in input_data)


% Round i_cmd because Dagan is stupid; will be recorded in results for safety
%  changed to auto-detect (in multiples of 10 (pA));
%i_cmd_step = 50; % round to a multiple of this value (pA); set to 0 to not round
roundingfactor = 25; % auto-detect, but then again round to a multiple of this value (pA) %%%%%%%

% Spike counting parameters - caution: will not be prompted!
spike_trigger = 10; % (mV); cationic E_rev, loosely correcting for usual LJP
spike_rearm = 0; % (mV); re-arm threshold for spike detection, arbitrary; must have a good margin from triggering threshold


% Supported output types; see also struct assignment at the bottom
%  will be used for field names in a struct, so do not use spaces, etc.
output_type_list = {'rmp', 'r_in', 'sag_ratio', 'rheobase', 'i_v', 'f_i', 'i_step_resolution', 'rheobase_sweep', 'rheobase_x2_sweep'};

% Initialize output array (sweeps * channels * types)
output_temp = nan(size(input_data, 3), size(input_data, 2), size(output_type_list, 2));

% Check which channel is V and which channel is i_cmd
%  caution: timestamp column may be present!
%{
global voltage_signal_channel; % carried over from pvbs_voltagerecording.m
v_channel = voltage_signal_channel;
%}
v_channel = 1;
if v_channel == 1
    i_channel = 2;
elseif v_channel == 2
    i_channel = 1;
else
    error(sprintf('\nCheck acquisition channels for V_m and i_cmd\n'));
end
% offset column by 1 for timestamp
v_channel = 1 + v_channel; i_channel = 1 + i_channel;

% Force only one baseline and detection window
param_baseline = param_baseline(1,:);
param_window = param_window(1,:);
sprintf('Only window 1 will be used for intrinsic property analysis! (set to i_cmd window)');

% Get window length - will be used to convert spike count to frequency
param_window_length = ((param_window(2) - param_window(1)) * param_data_voltage_interval)/1000; % convert datapoints to ms to s

% Calculate baseline (i.e. RMP) and insert to output (1st dimension)
if param_baseline(3) == 0 % use mean for baseline
    for idx1 = 1:size(input_data, 3) % iterate for each sweep
        for idx2 = 1:size(input_data, 2) % iterate for each channel in each sweep
            output_temp(idx1, idx2, 1) = nanmean(input_data(param_baseline(1):param_baseline(2), idx2, idx1));
        end
    end
elseif param_baseline(3) == 1 % use median for baseline
    for idx1 = 1:size(input_data, 3) % iterate for each sweep
        for idx2 = 1:size(input_data, 2) % iterate for each channel in each sweep
            output_temp(idx1, idx2, 1) = nanmedian(input_data(param_baseline(1):param_baseline(2), idx2, idx1));
        end
    end
else
    error(sprintf('\nInvalid input for baseline: 3rd element must be 0 or 1\n'));
end
clear idx1 idx2;

% Count spikes
spike_count = zeros(size(input_data, 3), 1); % could also accommodate multiple channels, but for the time being just count from one channel in each sweep
for idx1 = 1:size(input_data, 3) % iterate for each sweep
    spike_counter = 0; % spike counter: start from 0
    spike_counter_armed = 1; % spike counter status: armed at start
    for idx2 = param_window(1):param_window(2) % scan for spikes across detection window
        if spike_counter_armed == 1 % spike counter armed; search for spikes
            if input_data(idx2, v_channel, idx1) >= spike_trigger % spike detected
                spike_counter = spike_counter + 1; % increase counter by 1
                spike_counter_armed = 0; % disarm spike counter until V_m falls back
            end
        else % spike counter unarmed; ongoing spike
            if input_data(idx2, v_channel, idx1) <= spike_rearm % when V_m falls back
                spike_counter_armed = 1; % re-arm spike counter
            end
        end
    end
    spike_count(idx1, 1) = spike_counter; % number of spikes for the current sweep
    spike_counter = 0; % reset spike counter
end

% Calculate delta(V) for non-spiking sweeps, at peak & steady-state
i_v_sweeps = find(spike_count == 0);
if max(spike_count) == 0 % following code will not work properly if all sweeps were subthreshold
    i_v_sweeps = i_v_sweeps(1:9); % very arbitrary and annoying, but 9 should usually do in this case
else
    i_v_sweeps = i_v_sweeps(i_v_sweeps < min(find(spike_count > 0))); % discard discontinuous later sweeps (will be either due to inactivation or from dummy sweeps from PVBS gap-free recording)
end
% Peak (no direction bias)
for idx1 = i_v_sweeps(1):i_v_sweeps(end)
    peak_neg = nanmin(input_data(param_window(1):param_window(2), v_channel, idx1) - output_temp(idx1, v_channel, 1)); % peak (relative, negative-going)
    peak_pos = nanmax(input_data(param_window(1):param_window(2), v_channel, idx1) - output_temp(idx1, v_channel, 1)); % peak (relative, positive-going)
    if abs(peak_neg) > peak_pos
        output_temp(idx1, v_channel, 3) = peak_neg; % peak (relative)
        output_temp(idx1, v_channel, 2) = output_temp(idx1, v_channel, 3) + output_temp(idx1, v_channel, 1); % peak (absolute)
        output_temp(idx1, v_channel, 5) = -1; % peak direction
    elseif abs(peak_neg) < peak_pos
        output_temp(idx1, v_channel, 3) = peak_pos; % peak (relative)
        output_temp(idx1, v_channel, 2) = output_temp(idx1, v_channel, 3) + output_temp(idx1, v_channel, 1); % peak (absolute)
        output_temp(idx1, v_channel, 5) = 1; % peak direction
    else % i.e. abs(peak_neg) == peak_pos
        output_temp(idx1, v_channel, 3) = peak_pos; % peak (relative)
        output_temp(idx1, v_channel, 2) = output_temp(idx1, v_channel, 3) + output_temp(idx1, v_channel, 1); % peak (absolute)
        output_temp(idx1, v_channel, 5) = 0; % peak direction
    end
    peak_timeof = find(input_data(param_window(1):param_window(2), v_channel, idx1) == output_temp(idx1, v_channel, 2)); % time of peak (NB. actually in points, not ms)
    output_temp(idx1, v_channel, 4) = peak_timeof(1); % just in case of multiple occurrences
    clear peak_neg peak_pos;
end
% Steady-state V_m
%  taken from the last 1/5 of detection window; intended to work with detection window covering the duration of current injection
%  i.e. would be the last 100 ms if time of i_inj is 500 ms
warning('off', 'all');
param_window_start = param_window(1) + ceil(param_window(2) - param_window(1) + 1)*(1 - 1/5);
for idx1 = i_v_sweeps(1):i_v_sweeps(end)
    output_temp(idx1, v_channel, 6) = nanmean(input_data(param_window_start:param_window(2), v_channel, idx1)); % mean (absolute)
    output_temp(idx1, v_channel, 7) = output_temp(idx1, v_channel, 6) - output_temp(idx1, v_channel, 1); % mean (relative)
    output_temp(idx1, v_channel, 8) = nanmedian(input_data(param_window_start:param_window(2), v_channel, idx1)); % median (absolute)
    output_temp(idx1, v_channel, 9) = output_temp(idx1, v_channel, 8) - output_temp(idx1, v_channel, 1); % median (relative)
end
% i_cmd
%  just allocate into separate 3rd dimension instead of putting next to the delta(V) columns
for idx1 = 1:size(input_data, 3) % all rows here because this will also be used for f-i
    output_temp(idx1, i_channel, 10) = nanmean(input_data(param_window(1):param_window(2), i_channel, idx1)); % mean (absolute)
    output_temp(idx1, i_channel, 11) = output_temp(idx1, i_channel, 10) - output_temp(idx1, i_channel, 1); % mean (relative)
    output_temp(idx1, i_channel, 12) = nanmedian(input_data(param_window(1):param_window(2), i_channel, idx1)); % median (absolute)
    output_temp(idx1, i_channel, 13) = output_temp(idx1, i_channel, 12) - output_temp(idx1, i_channel, 1); % median (relative)
end
warning('on', 'all');
clear idx1;
clear param_window_start;

% R = V/I
v_transient = output_temp(:, v_channel, 3); % for convenience
r_transient = v_transient ./ output_temp(:, i_channel, 11); % using relative means for i_cmd here, and not absolute or median
v_steady = output_temp(:, v_channel, 7);
r_steady = v_steady ./ output_temp(:, i_channel, 11); % using relative means again, for both delta(V) and i_cmd

% Remove NaNs
v_transient = v_transient(1:i_v_sweeps(end));
r_transient = r_transient(1:i_v_sweeps(end));
v_steady = v_steady(1:i_v_sweeps(end));
r_steady = r_steady(1:i_v_sweeps(end));

% Prepare i_cmd arrays for convenience
i_cmd_iv = output_temp(:, i_channel, 11); % relative means
i_cmd_iv = i_cmd_iv(1:i_v_sweeps(end)); % only subthreshold sweeps
i_cmd_fi = output_temp(:, i_channel, 11); % relative means

% Auto-detect i_cmd step size and round
i_cmd_step = 0; % initializing
%for idx = 1 : size(input_data, 3) - 2 % exclude last sweep, as will most likely be a remainder sweep
for idx = 1 : size(i_cmd_iv, 1) - 1 % only take subthreshold sweeps
    i_cmd_step = i_cmd_step + (i_cmd_iv(idx + 1) - i_cmd_iv(idx)); % add up differences, using relative means
end
clear idx;
i_cmd_step = i_cmd_step / (size(i_cmd_iv, 1) - 1);
i_cmd_step = roundingfactor * round(i_cmd_step/roundingfactor); % actual rounding
% round i_cmd_iv and i_cmd_fi
if i_cmd_step <= 0 % relic from manual input; just leave it
    i_cmd_step = 0;
else
    i_cmd_iv = i_cmd_step * round(i_cmd_iv/i_cmd_step);
    i_cmd_fi = i_cmd_step * round(i_cmd_fi/i_cmd_step);
end
i_cmd_all = i_cmd_fi; % preserve this for later. going back and forth again now...

% Only positive sweeps for f-i
%i_cmd_neg_max = max(find(i_cmd_fi < 0)); % last sweep before crossing 0
i_cmd_pos_min = min(find(i_cmd_fi >= 0)); % first sweep after crossing or at 0; tacitly assumes i_cmd starts from negative
i_cmd_neg_max = i_cmd_pos_min - 1; % last sweep before crossing 0; should not use max(find(i_cmd_fi < 0)) because of remainder sweeps; stupid Praire
if abs(i_cmd_fi(i_cmd_neg_max)) >= i_cmd_fi(i_cmd_pos_min) % to take the index of the smaller
    i_cmd_zero = i_cmd_pos_min;
else
    i_cmd_zero = i_cmd_neg_max;
end
i_cmd_fi = i_cmd_fi(i_cmd_zero:end); % only positive sweeps
spike_count = spike_count(i_cmd_zero:end); % only positive sweeps
clear i_cmd_zero;

% Remove erroneous spike counts from incomplete sweep at the end
if max(spike_count) == 0 % following code will not work properly if all sweeps were subthreshold
    rmp = nanmean(output_temp(:, v_channel, 1));
    r_in = mldivide(i_cmd_iv, v_steady); % units are pA and mV, so this results in GOhm
    r_in = r_in * 10^3; % converting to MOhm 
    % Calculate sag ratio from the largest negative current injection
    sag_ratio = (r_transient(1) - r_steady(1)) / r_transient(1);
    output = struct(output_type_list{1}, rmp, output_type_list{2}, r_in, output_type_list{3}, sag_ratio, output_type_list{4}, [], output_type_list{5}, [], output_type_list{6}, [], output_type_list{7}, i_cmd_step, output_type_list{8}, [], output_type_list{9}, []);
    return; %%% fixlater
else
    spike_count_first = min(find(spike_count ~= 0)); % index of first spiking sweep
    spike_count_artifact = find(spike_count == 0); % find non-spiking sweeps
    spike_count_artifact = spike_count_artifact(spike_count_artifact > spike_count_first); % exclude subthreshold sweeps at the beginning
    if isempty(spike_count_artifact) % i.e. no remainder sweep at the end
    else % i.e. if there are remainder sweeps at the end
        spike_count_artifact = spike_count_artifact(1); % first remainder sweep
        spike_count = spike_count(1:spike_count_artifact - 1); % retain up to the last meaningful sweep
        i_cmd_fi = i_cmd_fi(1:spike_count_artifact - 1); % truncate i_cmd_fi accordingly
    end
end
clear spike_count_artifact 
%clear spike_count_first;

% Convert spike count to frequency
spike_count = spike_count / param_window_length; % divide by window duration (s)

%{
% Plot i-V and f-i
figure('name', [input_data_name, '_intrinsic_properties']); % pvbs_voltagerecording.m produces 1 figure preceding analysis codes

% Plot i-V
subplot(2, 2, 1); % 2 rows just for aesthetic reasons
plot(i_cmd_iv, v_steady, 'parent', GUIHandles.UIElements.iVCurve, 'color', 'k');
xlabel('i (pA)'); xticks(-10000:100:10000); % x ticks in 100 pA up to 10 nA
ylabel('dV (mV)'); %yticks(-100:10:100); % y ticks in 10 mV up to 100 mV
% add horizontal and vertical lines at 0
xline(0, '--', 'color', [0.5, 0.5, 0.5]);
yline(0, '--', 'color', [0.5, 0.5, 0.5]);

% Plot f-i
subplot(2, 2, 2);
plot(i_cmd_fi, spike_count, 'parent', GUIHandles.UIElements.fiCurve, 'color', 'k');
xlabel('i (pA)'); xticks(-10000:100:10000); % x ticks in 100 pA up to 10 nA
ylabel('f (Hz)'); yticks(0:10:1000); % y ticks in 10 Hz up to 1000 Hz
%}

% Calculate R_in from linear regression of the i-V curve (passing origin)
r_in = mldivide(i_cmd_iv, v_steady); % units are pA and mV, so this results in GOhm
r_in = r_in * 10^3; % converting to MOhm

% Calculate sag ratio from the largest negative current injection
sag_ratio = (r_transient(1) - r_steady(1)) / r_transient(1);

% Get rheobase
rheobase = i_cmd_fi(spike_count_first);
rheobase_sweep = size(i_cmd_iv, 1) + 1; % number of subthreshold sweeps + 1
rheobase_sweep_check = find(i_cmd_all == rheobase);
if rheobase_sweep ~= rheobase_sweep_check
    error('fix it');
end
rheobase_x2_sweep = find(i_cmd_all == 2*rheobase);
clear spike_count_first;

% Calculate RMP from averages of baselines from all sweeps
rmp = nanmean(output_temp(:, v_channel, 1));

% Arrange i-V and f-i into arrays
i_v = [i_cmd_iv, v_steady];
f_i = [i_cmd_fi, spike_count];

% Organize into struct
output = struct(output_type_list{1}, rmp, output_type_list{2}, r_in, output_type_list{3}, sag_ratio, output_type_list{4}, rheobase, output_type_list{5}, i_v, output_type_list{6}, f_i, output_type_list{7}, i_cmd_step, output_type_list{8}, rheobase_sweep, output_type_list{9}, rheobase_x2_sweep);

end


function baselineStart(src, event)
% baseline start point (in ms)

% load
h = guidata(src);
traceDisplay = h.ui.traceDisplay;
analysisBaseline = h.params.analysisBaseline;
lineColor = h.params.analysisBaselineColor;
selectedSweeps = h.ui.sweepListDisplay.Value;
selectedGroups = h.ui.groupListDisplay.Value;

% get input
inputValue = src.String;
inputValue = str2num(inputValue);

% correct invalid input
if inputValue < 0
    inputValue = 0;
end

% update display
analysisBaseline(1) = inputValue;
analysisWindowHandle = h.ui.analysisWindowHandle;
axes(traceDisplay); 
hold on;
delete(analysisWindowHandle{1});
clear analysisWindowHandle{1}; %%% I don't understand why none of these works...
analysisWindowHandle{1} = plot([analysisBaseline(1), analysisBaseline(1)], [-10000, 10000], 'parent', traceDisplay, 'color', lineColor, 'linestyle', '--', 'linewidth', 0.5, 'marker', 'none');
hold off;
h.ui.analysisWindowHandle = analysisWindowHandle;

%%% fuck it
h.params.analysisBaseline = analysisBaseline;
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
h = displayTrace(h, h.ui.cellListDisplay.Value);
h = highlightSweep(h, selectedSweeps);

% save
h.ui.sweepListDisplay.Value = selectedSweeps;
h.ui.groupListDisplay.Value = selectedGroups;
%h.params.analysisBaseline = analysisBaseline;
h.ui.traceDisplay = traceDisplay;
guidata(src, h);

end


function baselineEnd(src, event)
% baseline end point (in ms)

% load
h = guidata(src);
traceDisplay = h.ui.traceDisplay;
analysisBaseline = h.params.analysisBaseline;
lineColor = h.params.analysisBaselineColor;
selectedSweeps = h.ui.sweepListDisplay.Value;
selectedGroups = h.ui.groupListDisplay.Value;

% get input
inputValue = src.String;
inputValue = str2num(inputValue);

% correct invalid input
if inputValue < h.params.analysisBaseline(1)
    inputValue = h.params.analysisBaseline(1) + 1;
end

% update display
analysisBaseline(2) = inputValue;
analysisWindowHandle = h.ui.analysisWindowHandle;
axes(traceDisplay); 
hold on;
delete(analysisWindowHandle{2});
clear analysisWindowHandle{2}; %%% I don't understand why none of these works...
analysisWindowHandle{2} = plot([analysisBaseline(2), analysisBaseline(2)], [-10000, 10000], 'parent', traceDisplay, 'color', lineColor, 'linestyle', '--', 'linewidth', 0.5, 'marker', 'none');
hold off;
h.ui.analysisWindowHandle = analysisWindowHandle;

%%% fuck it
h.params.analysisBaseline(2) = inputValue;
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
h = displayTrace(h, h.ui.cellListDisplay.Value);
h = highlightSweep(h, selectedSweeps);

% save
h.ui.sweepListDisplay.Value = selectedSweeps;
h.ui.groupListDisplay.Value = selectedGroups;
%h.params.analysisBaseline(2) = inputValue;
h.ui.traceDisplay = traceDisplay;
guidata(src, h);

end


function baselineMedian(src, event)
% toggle use of median for baseline

% load
h = guidata(src);

if src.Value % if checked
    h.params.actualParams.useMedian = 1;
else
    h.params.actualParams.useMedian = 0;
end

% save
guidata(src, h);

end


function analysisWindow1Start(src, event)
% analysis window 1 start point (in ms)

% load
h = guidata(src);
traceDisplay = h.ui.traceDisplay;
analysisWindow1 = h.params.analysisWindow1;
lineColor = h.params.analysisWindow1Color;
selectedSweeps = h.ui.sweepListDisplay.Value;
selectedGroups = h.ui.groupListDisplay.Value;

% get input
inputValue = src.String;
inputValue = str2num(inputValue);

% correct invalid input
if inputValue < 0
    inputValue = 0;
end

% update display
analysisWindow1(1) = inputValue;
analysisWindowHandle = h.ui.analysisWindowHandle;
axes(traceDisplay); 
hold on;
delete(analysisWindowHandle{3});
clear analysisWindowHandle{3}; %%% I don't understand why none of these works...
analysisWindowHandle{3} = plot([analysisWindow1(1), analysisWindow1(1)], [-10000, 10000], 'parent', traceDisplay, 'color', lineColor, 'linestyle', '-', 'linewidth', 0.5, 'marker', 'none');
hold off;
h.ui.analysisWindowHandle = analysisWindowHandle;

%%% fuck it
h.params.analysisWindow1(1) = inputValue;
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
h = displayTrace(h, h.ui.cellListDisplay.Value);
h = highlightSweep(h, selectedSweeps);

% save
h.ui.sweepListDisplay.Value = selectedSweeps;
h.ui.groupListDisplay.Value = selectedGroups;
%h.params.analysisWindow1(1) = inputValue;
h.ui.traceDisplay = traceDisplay;
guidata(src, h);

end


function analysisWindow1End(src, event)
% analysis window 1 end point (in ms)

% load
h = guidata(src);
traceDisplay = h.ui.traceDisplay;
analysisWindow1 = h.params.analysisWindow1;
lineColor = h.params.analysisWindow1Color;
selectedSweeps = h.ui.sweepListDisplay.Value;
selectedGroups = h.ui.groupListDisplay.Value;

% get input
inputValue = src.String;
inputValue = str2num(inputValue);

% correct invalid input
if inputValue < h.params.analysisWindow1(1)
    inputValue = h.params.analysisWindow1(1) + 1;
end

% update display
analysisWindow1(2) = inputValue;
analysisWindowHandle = h.ui.analysisWindowHandle;
axes(traceDisplay); 
hold on;
delete(analysisWindowHandle{4});
clear analysisWindowHandle{4}; %%% I don't understand why none of these works...
analysisWindowHandle{4} = plot([analysisWindow1(2), analysisWindow1(2)], [-10000, 10000], 'parent', traceDisplay, 'color', lineColor, 'linestyle', '-', 'linewidth', 0.5, 'marker', 'none');
hold off;
h.ui.analysisWindowHandle = analysisWindowHandle;

%%% fuck it
h.params.analysisWindow1(2) = inputValue;
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
h = displayTrace(h, h.ui.cellListDisplay.Value);
h = highlightSweep(h, selectedSweeps);

% save
h.ui.sweepListDisplay.Value = selectedSweeps;
h.ui.groupListDisplay.Value = selectedGroups;
%h.params.analysisWindow1(2) = inputValue;
h.ui.traceDisplay = traceDisplay;
guidata(src, h);

end


function analysisWindow2Start(src, event)
% analysis window 2 start point (in ms)

% load
h = guidata(src);
traceDisplay = h.ui.traceDisplay;
analysisWindow2 = h.params.analysisWindow2;
lineColor = h.params.analysisWindow2Color;
selectedSweeps = h.ui.sweepListDisplay.Value;
selectedGroups = h.ui.groupListDisplay.Value;

% get input
inputValue = src.String;
inputValue = str2num(inputValue);

% correct invalid input
if inputValue < 0
    inputValue = 0;
end

% update display
analysisWindow2(1) = inputValue;
analysisWindowHandle = h.ui.analysisWindowHandle;
axes(traceDisplay); 
hold on;
delete(analysisWindowHandle{5});
clear analysisWindowHandle{5}; %%% I don't understand why none of these works...
analysisWindowHandle{5} = plot([analysisWindow2(1), analysisWindow2(1)], [-10000, 10000], 'parent', traceDisplay, 'color', lineColor, 'linestyle', '-', 'linewidth', 0.5, 'marker', 'none');
hold off;
h.ui.analysisWindowHandle = analysisWindowHandle;

%%% fuck it
h.params.analysisWindow2(1) = inputValue;
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
h = displayTrace(h, h.ui.cellListDisplay.Value);
h = highlightSweep(h, selectedSweeps);

% save
h.ui.sweepListDisplay.Value = selectedSweeps;
h.ui.groupListDisplay.Value = selectedGroups;
%h.params.analysisWindow2(1) = inputValue;
h.ui.traceDisplay = traceDisplay;
guidata(src, h);

end


function analysisWindow2End(src, event)
% analysis window 2 end point (in ms)

% load
h = guidata(src);
traceDisplay = h.ui.traceDisplay;
analysisWindow2 = h.params.analysisWindow2;
lineColor = h.params.analysisWindow2Color;
selectedSweeps = h.ui.sweepListDisplay.Value;
selectedGroups = h.ui.groupListDisplay.Value;

% get input
inputValue = src.String;
inputValue = str2num(inputValue);

% correct invalid input
if inputValue < h.params.analysisWindow1(1)
    inputValue = h.params.analysisWindow1(1) + 1;
end

% update display
analysisWindow2(2) = inputValue;
analysisWindowHandle = h.ui.analysisWindowHandle;
axes(traceDisplay); 
hold on;
delete(analysisWindowHandle{6});
clear analysisWindowHandle{6}; %%% I don't understand why none of these works...
analysisWindowHandle{6} = plot([analysisWindow2(2), analysisWindow2(2)], [-10000, 10000], 'parent', traceDisplay, 'color', lineColor, 'linestyle', '-', 'linewidth', 0.5, 'marker', 'none');
hold off;
h.ui.analysisWindowHandle = analysisWindowHandle;

%%% fuck it
h.params.analysisWindow2(2) = inputValue;
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
h = displayTrace(h, h.ui.cellListDisplay.Value);
h = highlightSweep(h, selectedSweeps);

% save
h.ui.sweepListDisplay.Value = selectedSweeps;
h.ui.groupListDisplay.Value = selectedGroups;
%h.params.analysisWindow2(2) = inputValue;
h.ui.traceDisplay = traceDisplay;
guidata(src, h);

end


function [f, dff, roi] = lineScanImgToF(img, timestamp, baseline, actualParams)
% img: 2-d array where each row is a single line (scan)
% timestamp: timestamp (n*1 column vector, unit in (ms))
% baseline: baseline window (1*2 array, for start & end)
% roiDetectDuringBaseline: use only baseline period for ROI detection (0: off, 1: on);
%  could be useful to prevent possible errors caused by uncaging artifacts
% downsamplingFactor: self-explanatory (set to 1 to disable)

% Parameters - should not require tweaking... or not. %%%
roiSmoothing = actualParams.lineScanROISmoothing; % will average over this many points (before and after) while detecting ROI to be robust from noise - obsolete with single ROI
roiThreshold = actualParams.lineScanROIThreshold; % (s.d.); z-score for 33rd percentile
backgroundThreshold = actualParams.lineScanBackgroundThreshold; % (s.d.); z-score for 67th percentile
downsamplingFactor = actualParams.lineScanDownsamplingFactor;
roiDetectDuringBaseline = actualParams.lineScanROIDetectDuringBaseline;

% Get interval and convert baseline to points
interval = timestamp(2, 1) - timestamp(1, 1); % (ms)
baselinePoints = baseline./interval;
baselinePoints = round(baselinePoints); % needs to be done

% Import data for current Cycle
try
    img = double(img); % converting to double, e.g. in case in uint16 form
catch ME
end

% quick fix %%%
if isnan(timestamp)
    f = [];
    dff = [];
    roi = [];
    return
elseif isnan(baseline)
    f = [];
    dff = [];
    roi = [];
    return
end

% Process tiff
if roiDetectDuringBaseline
    imgReduced = img(baselinePoints(1):baselinePoints(2), :); % take only the baseline period from the image
    imgReduced = nanmean(imgReduced, 1); % average across rows, roi should stay the same for each row
else
    imgReduced = nanmean(img, 1); % average across rows, roi should stay the same for each row
end
imgReduced = zscore(imgReduced, 1, 2); % use population sd, over 2nd dimension
for i = 1 + roiSmoothing : size(imgReduced, 2) - roiSmoothing
    imgReduced(1, i) = nanmean(imgReduced(1, (i - roiSmoothing) : (i + roiSmoothing))); % smoothing (note: not boxcar averaging)
end

% Set ROI
%%% below doesn't work properly and needs to be fixed to support multiple ROIs
%{
roiIdx = find(imgReduced(1, :) >= (roiThreshold / ((roiSmoothing * 2) + 1))); % find indices for values above threshold for ROI
if any(ischange(roiIdx, 'linear')) % if there is a break, i.e. multiple ROIs present; will support up to 2 ROIs for plotting
    roiBreakIdx = find(ischange(roiIdx, 'linear') == 1); % find indices where breaks occur
    roi = [roiIdx(1), roiIdx(roiBreakIdx(1) - 1)]; % initializing with first segment
    if size(roiBreakIdx, 2) > 2 % if there are more than 2 breaks, i.e. more than 3 segments, which should be extremely unusual
        for i = 2 : size(roiBreakIdx, 2) - 1 % exclude first and last segments
            roi = [roi; [roiIdx(roiBreakIdx(i)), roiIdx(roiBreakIdx(i + 1))]];
        end
    end
    roi = [roi; [roiIdx(roiBreakIdx(end)), roiIdx(end)]]; % last segment
else % only 1 ROI, which would normally be the case
    roi = [roiIdx(1), roiIdx(end)];
end
%}
roiIdx = find(imgReduced(1, :) >= roiThreshold); % find indices for values above threshold for ROI
if any(ischange(roiIdx, 'linear')) % if there is a break, i.e. multiple ROIs present
    roiBreakIdx = find(ischange(roiIdx, 'linear') == 1); % find indices where breaks occur
    % get the brightest segment - working, not actually doing anything yet here %%% fixlater
    roiBrightest = find(imgReduced == max(imgReduced(roiIdx))); % index for maximum brightness point within ROIs
    % get the longest segment
    roiSegmentLength = [];
    if length(roiBreakIdx) == 1 % only 1 break, i.e. 2 ROIs
        roiSegmentLength(1) = roiBreakIdx;
        roiSegmentLength(2) = length(roiIdx);
    else % multiple breaks, i.e. 3 or more ROIs
        roiSegmentLength(1) = roiBreakIdx;
        for i = 1:length(roiBreakIdx) - 1
            roiSegmentLength(end + 1) = roiBreakIdx(i + 1) - roiBreakIdx(i);
        end
        roiSegmentLength(end + 1) = length(roiIdx) - roiBreakIdx(end); % last segment length is equal to this
    end  
    [roiSegmentMax, roiSegmentMaxIdx] = max(roiSegmentLength); % roiSegmentMaxIdx is now the index for longest ROI
    roi = [roiIdx(1), roiIdx(roiBreakIdx(1) - 1)]; % initializing with first segment
    if size(roiBreakIdx, 2) > 2 % if there are more than 2 breaks, i.e. more than 3 segments, which should be extremely unusual
        for i = 2 : size(roiBreakIdx, 2) - 1 % exclude first and last segments
            roi = [roi; [roiIdx(roiBreakIdx(i)), roiIdx(roiBreakIdx(i + 1))]];
        end
    end
    roi = [roi; [roiIdx(roiBreakIdx(end)), roiIdx(end)]]; % last segment
    % now leave only the longest segment
    roi = roi(roiSegmentMaxIdx, :);
else % only 1 ROI, which would normally be the case
    roi = [roiIdx(1), roiIdx(end)];
end

% Set background
backgroundIdx = find(imgReduced(1, :) <= backgroundThreshold); % find indices for values below threshold for background
if any(ischange(backgroundIdx, 'linear')) % there should usually be one more break than the ROI indices
    backgroundBreakIdx = find(ischange(backgroundIdx, 'linear') == 1); % find indices where breaks occur
    background = [backgroundIdx(1), backgroundIdx(backgroundBreakIdx(1) - 1)]; % initializing with first segment
    if size(backgroundBreakIdx, 2) > 2 % if there are more than 2 breaks, i.e. more than 3 segments; this should not really happen, though
        for i = 2 : size(backgroundBreakIdx, 2) - 1 % exclude first and last segments
            background = [background; [backgroundIdx(backgroundBreakIdx(i)), backgroundIdx(backgroundBreakIdx(i + 1))]];
        end
    end
    background = [background; [backgroundIdx(backgroundBreakIdx(end)), backgroundIdx(end)]]; % last segment
else % when there is no break, which would be uncommon but possible
    background = [backgroundIdx(1), backgroundIdx(end)];
end

% Get background F, and subtract it from all F for each line
backgroundF = []; % to keep track of background f
for i = 1:size(img, 1) % for all lines
    numPoints = 0; % re-initialize for each line
    backgroundFTemp = 0; % re-initialize for each line
    for j = 1:size(background, 1) % for all background segments
        backgroundFTemp = backgroundFTemp + sum(img(i, background(j, 1):background(j, 2))); % sum F across points in background segment
        numPoints = numPoints + 1 + background(j, 2) - background(j, 1); % number of points in all background segments
    end
    backgroundFTemp = backgroundFTemp / numPoints; % average by dividing by number of points
    img(i, :) = img(i, :) - backgroundFTemp;
    backgroundF = [backgroundF; backgroundFTemp];
end

% Get ROI F and convert to a 2-D array
imgOriginal = nan(size(img, 1), size(roi, 1)); % 2 columns, 1 for timestamp and 1 for fluorescence (currently 1-channel only); "original" is misleading but an artifact from previous code
imgOriginal(:, 1) = 0:interval:interval*(size(img, 1) - 1); % actually some minor information is lost here because linescans are never perfectly time-locked with voltagerecording onset...
for i = 1:size(roi, 1) % for each ROI
    for j = 1:size(img, 1) % for each line
        imgOriginal(j, 1 + i) = nanmean(img(j, roi(i, 1):roi(i, 2))); % row: line, column: ROI, offset by 1 by timestamp (previous version of code implied channel, and must be updated!)
    end
end

% Downsample by boxcar averaging
imgNew = NaN(floor(size(imgOriginal, 1)/downsamplingFactor), size(imgOriginal, 2));
warning('off','all'); % due to the low sampling rate of LineProfileData, averaging may cause warnings, but does not actually compromise data quality
for i = 1:size(imgOriginal, 2) % for each column in data, e.g. Prof1, Prof2, ...; NB. duplicate timestamps already removed while making data_fluorescence
    for j = 1:floor(size(imgOriginal, 1)/downsamplingFactor)
        imgNew(j, i) = nanmean(imgOriginal(1 + downsamplingFactor*(j - 1) : downsamplingFactor*j, i));
    end
end
warning('on','all');

%  re-calculate timestamp and baseline time window according to downsampling
timestampNew = timestamp * downsamplingFactor;
intervalNew = timestampNew(2, 1) - timestampNew(1, 1); % (ms)
baselinePointsNew = baseline./intervalNew;
baselinePointsNew = round(baselinePointsNew); % needs to be done
baselinePoints = baselinePointsNew;

% Get F and dF/F
roiIdx = 1; %%% supporting only 1 roi for now
%f = imgOriginal(:, 1 + roiIdx);
f = imgNew(:, 1 + roiIdx);
fZero = nanmean(f(baselinePoints(1):baselinePoints(2)));
dff = (f - fZero)./fZero;

% Adjust lengths if necessary
timestampLength = size(timestampNew, 1);
fLength = size(f, 1);
if timestampLength == fLength
elseif timestampLength > fLength
    timestampNew = timestampNew(1:fLength); % cut off excess timestamp
elseif timestampLength < fLength
    for i = 1:fLength - timestampNew
        timestampNew(end+1) = timestampNew(end) + (timestampNew(end) - timestampNew(end - 1));
    end
end

% Append timestamp
f = [timestampNew, f];
dff = [timestampNew, dff];

end


function [f, dff] = lineScanImgToFManualROI(img, timestamp, baseline, actualParams, roiManual)
% img: 2-d array where each row is a single line (scan)
% timestamp: timestamp (n*1 column vector, unit in (ms))
% baseline: baseline window (1*2 array, for start & end)
% roiDetectDuringBaseline: use only baseline period for ROI detection (0: off, 1: on);
%  could be useful to prevent possible errors caused by uncaging artifacts
% downsamplingFactor: self-explanatory (set to 1 to disable)
% roiManual: ROI (1*2 array, for start & end)

% Parameters - should not require tweaking... or not. %%%
roiSmoothing = actualParams.lineScanROISmoothing; % will average over this many points (before and after) while detecting ROI to be robust from noise - obsolete with single ROI
roiThreshold = actualParams.lineScanROIThreshold; % (s.d.); z-score for 33rd percentile
backgroundThreshold = actualParams.lineScanBackgroundThreshold; % (s.d.); z-score for 67th percentile
downsamplingFactor = actualParams.lineScanDownsamplingFactor;
roiDetectDuringBaseline = actualParams.lineScanROIDetectDuringBaseline;

% Get interval and convert baseline to points
interval = timestamp(2, 1) - timestamp(1, 1); % (ms)
baselinePoints = baseline./interval;
baselinePoints = round(baselinePoints); % needs to be done

% Import data for current Cycle
try
    img = double(img); % converting to double, e.g. in case in uint16 form
catch ME
end

% quick fix %%%
if isnan(timestamp)
    f = [];
    dff = [];
    roi = [];
    return
elseif isnan(baseline)
    f = [];
    dff = [];
    roi = [];
    return
end

% Process tiff
if roiDetectDuringBaseline
    imgReduced = img(baselinePoints(1):baselinePoints(2), :); % take only the baseline period from the image
    imgReduced = nanmean(imgReduced, 1); % average across rows, roi should stay the same for each row
else
    imgReduced = nanmean(img, 1); % average across rows, roi should stay the same for each row
end
imgReduced = zscore(imgReduced, 1, 2); % use population sd, over 2nd dimension
for i = 1 + roiSmoothing : size(imgReduced, 2) - roiSmoothing
    imgReduced(1, i) = nanmean(imgReduced(1, (i - roiSmoothing) : (i + roiSmoothing))); % smoothing (note: not boxcar averaging)
end

% Set ROI
%%% below doesn't work properly and needs to be fixed to support multiple ROIs
%{
roiIdx = find(imgReduced(1, :) >= (roiThreshold / ((roiSmoothing * 2) + 1))); % find indices for values above threshold for ROI
if any(ischange(roiIdx, 'linear')) % if there is a break, i.e. multiple ROIs present; will support up to 2 ROIs for plotting
    roiBreakIdx = find(ischange(roiIdx, 'linear') == 1); % find indices where breaks occur
    roi = [roiIdx(1), roiIdx(roiBreakIdx(1) - 1)]; % initializing with first segment
    if size(roiBreakIdx, 2) > 2 % if there are more than 2 breaks, i.e. more than 3 segments, which should be extremely unusual
        for i = 2 : size(roiBreakIdx, 2) - 1 % exclude first and last segments
            roi = [roi; [roiIdx(roiBreakIdx(i)), roiIdx(roiBreakIdx(i + 1))]];
        end
    end
    roi = [roi; [roiIdx(roiBreakIdx(end)), roiIdx(end)]]; % last segment
else % only 1 ROI, which would normally be the case
    roi = [roiIdx(1), roiIdx(end)];
end
%}
roiIdx = find(imgReduced(1, :) >= (roiThreshold / ((roiSmoothing * 2) + 1))); % find indices for values above threshold for ROI
if any(ischange(roiIdx, 'linear')) % if there is a break, i.e. multiple ROIs present
    roiBreakIdx = find(ischange(roiIdx, 'linear') == 1); % find indices where breaks occur
    % get the longest segment
    roiSegmentLength = [];
    if length(roiBreakIdx) == 1 % only 1 break, i.e. 2 ROIs
        roiSegmentLength(1) = roiBreakIdx;
        roiSegmentLength(2) = length(roiIdx);
    else % multiple breaks, i.e. 3 or more ROIs
        roiSegmentLength(1) = roiBreakIdx;
        for i = 1:length(roiBreakIdx) - 1
            roiSegmentLength(end + 1) = roiBreakIdx(i + 1) - roiBreakIdx(i);
        end
        roiSegmentLength(end + 1) = length(roiIdx) - roiBreakIdx(end); % last segment length is equal to this
    end
    [roiSegmentMax, roiSegmentMaxIdx] = max(roiSegmentLength); % roiSegmentMaxIdx is now the index for longest ROI
    roi = [roiIdx(1), roiIdx(roiBreakIdx(1) - 1)]; % initializing with first segment
    if size(roiBreakIdx, 2) > 2 % if there are more than 2 breaks, i.e. more than 3 segments, which should be extremely unusual
        for i = 2 : size(roiBreakIdx, 2) - 1 % exclude first and last segments
            roi = [roi; [roiIdx(roiBreakIdx(i)), roiIdx(roiBreakIdx(i + 1))]];
        end
    end
    roi = [roi; [roiIdx(roiBreakIdx(end)), roiIdx(end)]]; % last segment
    % now leave only the longest segment
    roi = roi(roiSegmentMaxIdx, :);
else % only 1 ROI, which would normally be the case
    roi = [roiIdx(1), roiIdx(end)];
end

%%% Override ROI because I'm that lazy
roi = [roiManual(1), roiManual(2)];

% Set background
backgroundIdx = find(imgReduced(1, :) <= (backgroundThreshold / ((roiSmoothing * 2) + 1))); % find indices for values below threshold for background
if any(ischange(backgroundIdx, 'linear')) % there should usually be one more break than the ROI indices
    backgroundBreakIdx = find(ischange(backgroundIdx, 'linear') == 1); % find indices where breaks occur
    background = [backgroundIdx(1), backgroundIdx(backgroundBreakIdx(1) - 1)]; % initializing with first segment
    if size(backgroundBreakIdx, 2) > 2 % if there are more than 2 breaks, i.e. more than 3 segments; this should not really happen, though
        for i = 2 : size(backgroundBreakIdx, 2) - 1 % exclude first and last segments
            background = [background; [backgroundIdx(backgroundBreakIdx(i)), backgroundIdx(backgroundBreakIdx(i + 1))]];
        end
    end
    background = [background; [backgroundIdx(backgroundBreakIdx(end)), backgroundIdx(end)]]; % last segment
else % when there is no break, which would be uncommon but possible
    background = [backgroundIdx(1), backgroundIdx(end)];
end

% Get background F, and subtract it from all F for each line
backgroundF = []; % to keep track of background f
for i = 1:size(img, 1) % for all lines
    numPoints = 0; % re-initialize for each line
    backgroundFTemp = 0; % re-initialize for each line
    for j = 1:size(background, 1) % for all background segments
        backgroundFTemp = backgroundFTemp + sum(img(i, background(j, 1):background(j, 2))); % sum F across points in background segment
        numPoints = numPoints + 1 + background(j, 2) - background(j, 1); % number of points in all background segments
    end
    backgroundFTemp = backgroundFTemp / numPoints; % average by dividing by number of points
    img(i, :) = img(i, :) - backgroundFTemp;
    backgroundF = [backgroundF; backgroundFTemp];
end

% Get ROI F and convert to a 2-D array
imgOriginal = nan(size(img, 1), size(roi, 1)); % 2 columns, 1 for timestamp and 1 for fluorescence (currently 1-channel only); "original" is misleading but an artifact from previous code
imgOriginal(:, 1) = 0:interval:interval*(size(img, 1) - 1); % actually some minor information is lost here because linescans are never perfectly time-locked with voltagerecording onset...
for i = 1:size(roi, 1) % for each ROI
    for j = 1:size(img, 1) % for each line
        imgOriginal(j, 1 + i) = nanmean(img(j, roi(i, 1):roi(i, 2))); % row: line, column: ROI, offset by 1 by timestamp (previous version of code implied channel, and must be updated!)
    end
end

% Downsample by boxcar averaging
imgNew = NaN(floor(size(imgOriginal, 1)/downsamplingFactor), size(imgOriginal, 2));
warning('off','all'); % due to the low sampling rate of LineProfileData, averaging may cause warnings, but does not actually compromise data quality
for i = 1:size(imgOriginal, 2) % for each column in data, e.g. Prof1, Prof2, ...; NB. duplicate timestamps already removed while making data_fluorescence
    for j = 1:floor(size(imgOriginal, 1)/downsamplingFactor)
        imgNew(j, i) = nanmean(imgOriginal(1 + downsamplingFactor*(j - 1) : downsamplingFactor*j, i));
    end
end
warning('on','all');

%  re-calculate timestamp and baseline time window according to downsampling
timestampNew = timestamp * downsamplingFactor;
intervalNew = timestampNew(2, 1) - timestampNew(1, 1); % (ms)
baselinePointsNew = baseline./intervalNew;
baselinePointsNew = round(baselinePointsNew); % needs to be done
baselinePoints = baselinePointsNew;

% Get F and dF/F
roiIdx = 1; %%% supporting only 1 roi for now
%f = imgOriginal(:, 1 + roiIdx);
f = imgNew(:, 1 + roiIdx);
fZero = nanmean(f(baselinePoints(1):baselinePoints(2)));
dff = (f - fZero)./fZero;

% Adjust lengths if necessary
timestampLength = size(timestampNew, 1);
fLength = size(f, 1);
if timestampLength == fLength
elseif timestampLength > fLength
    timestampNew = timestampNew(1:fLength); % cut off excess timestamp
elseif timestampLength < fLength
    for i = 1:fLength - timestampNew
        timestampNew(end+1) = timestampNew(end) + (timestampNew(end) - timestampNew(end - 1));
    end
end

% Append timestamp
f = [timestampNew, f];
dff = [timestampNew, dff];

end


function lineScanRoiManualSelect(src, ~)

end


%% Postprocessing


function filteredSignal = besselLowpass(originalSignal, besselOrder, cutoffFreq, samplingRate)
% apply lowpass bessel filter to signal (in a column vector format)

[z, p, k] = besself(besselOrder, 2*pi*cutoffFreq);
[num, den] = zp2tf(z, p, k);
[numD, denD] = bilinear(num, den, samplingRate);
filteredSignal = filtfilt(numD, denD, originalSignal);

end


function downsampledSignal = boxcarAverage(originalSignal, boxcarLength)

dataLengthReduced = floor(size(originalSignal, 1)/boxcarLength); % column direction
downsampledSignal = nan(dataLengthReduced, size(originalSignal, 2)); % initializing
for j = 1:size(originalSignal, 2) % repeat across rows
    for k = 1:dataLengthReduced
        downsampledSignal(k, j) = nanmean(originalSignal(1 + (k-1)*boxcarLength : k*boxcarLength, j));
    end
end

end


function downsamplingSignalSelect(src, ~)

h = guidata(src);

expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;

targetSignal = h.ui.traceProcessingTarget.Value;
targetSignal = targetSignal - 1;

postprocessing = h.exp.data.postprocessing{expIdx};
postprocessing = postprocessing(targetSignal, :);
boxcarLength = postprocessing(1);
besselFreq = postprocessing(2);
%besselFreq = 1000*besselFreq; % converting to Hz from kHz
besselOrder = postprocessing(3);

h.ui.downsamplingInput.String = num2str(boxcarLength);
h.ui.lowPassFilterInput.String = num2str(besselFreq);

if boxcarLength == 0 || boxcarLength == 1
    h.ui.downsamplingButton.Value = 0;
else
    h.ui.downsamplingButton.Value = 1;
end

if logical(besselFreq)
    h.ui.lowPassFilterButton.Value = 1;
else
    h.ui.lowPassFilterButton.Value = 0;
end

guidata(src, h);

end


function downsamplingBoxcarButton(src, event)

h = guidata(src);
checked = event.Source.Value;
besselChecked = h.ui.lowPassFilterButton.Value;
h = downsamplingBesselAndBoxcar(h);
h.ui.downsamplingButton.Value = checked;
h.ui.lowPassFilterButton.Value = besselChecked;

guidata(src, h);
    
end


function downsamplingBoxcarInput(src, ~)

h = guidata(src);

expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;

targetSignal = h.ui.traceProcessingTarget.Value;
targetSignal = targetSignal - 1;

postprocessingNew = h.exp.data.postprocessing{expIdx};
postprocessingTemp = postprocessingNew(targetSignal, :);

boxcarLength = h.ui.downsamplingInput.String;
boxcarLength = str2num(boxcarLength);
postprocessingTemp(1) = boxcarLength;

postprocessingNew(targetSignal, :) = postprocessingTemp;
h.exp.data.postprocessing{expIdx} = postprocessingNew;

boxcarCheck = h.ui.downsamplingButton.Value;
if boxcarCheck
    h = downsamplingBesselAndBoxcar(h);
end

guidata(src, h);

end


function downsamplingBesselButton(src, event)

h = guidata(src);
checked = event.Source.Value;
boxcarChecked = h.ui.downsamplingButton.Value;
h = downsamplingBesselAndBoxcar(h);
h.ui.lowPassFilterButton.Value = checked;
h.ui.downsamplingButton.Value = boxcarChecked;

guidata(src, h);

end


function downsamplingBesselInput(src, ~)

h = guidata(src);

expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;

targetSignal = h.ui.traceProcessingTarget.Value;
targetSignal = targetSignal - 1;

postprocessingNew = h.exp.data.postprocessing{expIdx};
postprocessingTemp = postprocessingNew(targetSignal, :);

besselFreq = h.ui.lowPassFilterInput.String;
besselFreq = str2num(besselFreq);
postprocessingTemp(2) = besselFreq;

postprocessingNew(targetSignal, :) = postprocessingTemp;
h.exp.data.postprocessing{expIdx} = postprocessingNew;

besselCheck = h.ui.lowPassFilterButton.Value;
if besselCheck
    h = downsamplingBesselAndBoxcar(h);
end

guidata(src, h);

end


function h = downsamplingBesselAndBoxcar(h)

if isempty(h.ui.cellListDisplay.String)
    return
end

expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
timeColumn = h.params.actualParams.timeColumn;

boxcarCheck = h.ui.downsamplingButton.Value;
besselCheck = h.ui.lowPassFilterButton.Value;
targetSignal = h.ui.traceProcessingTarget.Value;
targetSignal = targetSignal - 1;

%%{
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;

targetSignal = h.ui.traceProcessingTarget.Value;
targetSignal = targetSignal - 1;

postprocessingNew = h.exp.data.postprocessing{expIdx};
postprocessingTemp = postprocessingNew(targetSignal, :);

boxcarLength = h.ui.downsamplingInput.String;
boxcarLength = str2num(boxcarLength);
postprocessingTemp(1) = boxcarLength;

besselFreq = h.ui.lowPassFilterInput.String;
besselFreq = str2num(besselFreq);
postprocessingTemp(2) = besselFreq;

postprocessingNew(targetSignal, :) = postprocessingTemp;
h.exp.data.postprocessing{expIdx} = postprocessingNew;
%}

postprocessing = h.exp.data.postprocessing{expIdx};
postprocessing = postprocessing(targetSignal, :);
boxcarLength = postprocessing(1);
besselFreq = postprocessing(2);
besselFreq = 1000*besselFreq; % converting to Hz from kHz
besselOrder = postprocessing(3);

if targetSignal == 1
    originalSignal = h.exp.data.VRecOriginal{expIdx};
elseif targetSignal == 2
    originalSignal = h.exp.data.lineScanDFFOriginal{expIdx};
end
newSignal = originalSignal;

if besselCheck
    if logical(besselFreq)
        for i = 1:length(newSignal)
            if iscell(newSignal)
                try % in case sweeps are missing, which can happen especially for dF/F
                    newSignalTemp = newSignal{i};
                    samplingInterval = newSignalTemp(2, timeColumn) - newSignalTemp(1, timeColumn); % sampling interval (ms)
                    samplingInterval = samplingInterval/1000; % sampling interval (s)
                    samplingRate = 1/samplingInterval; % sampling rate (Hz)
                    newSignalTemp = besselLowpass(newSignalTemp, besselOrder, besselFreq, samplingRate);
                    newSignal{i} = newSignalTemp;
                catch ME
                    newSignal{i} = [];
                end
            else
                try % in case sweeps are missing, which can happen especially for dF/F
                    newSignalTemp = newSignal;
                    samplingInterval = newSignalTemp(2, timeColumn) - newSignalTemp(1, timeColumn); % sampling interval (ms)
                    samplingInterval = samplingInterval/1000; % sampling interval (s)
                    samplingRate = 1/samplingInterval; % sampling rate (Hz)
                    newSignalTemp = besselLowpass(newSignalTemp, besselOrder, besselFreq, samplingRate);
                    newSignal = newSignalTemp;
                catch ME
                    newSignal = [];
                end
            end
        end
    end
end

if boxcarCheck
    if boxcarLength == 0 || boxcarLength == 1
    else
        for i = 1:length(newSignal)
            if iscell(newSignal)
                try % in case sweeps are missing, which can happen especially for dF/F
                    newSignalTemp = newSignal{i};
                    newSignalTemp = boxcarAverage(newSignalTemp, boxcarLength);
                    newSignal{i} = newSignalTemp;
                catch ME
                    newSignal{i} = [];
                end
            else
                try % in case sweeps are missing, which can happen especially for dF/F
                    newSignalTemp = newSignal;
                    newSignalTemp = boxcarAverage(newSignalTemp, boxcarLength);
                    newSignal = newSignalTemp;
                catch ME
                    newSignal = [];
                end
            end
        end
    end
end

if targetSignal == 1
    h.exp.data.VRec{expIdx} = newSignal;
elseif targetSignal == 2
    h.exp.data.lineScanDFF{expIdx} = newSignal;
end

axes(h.ui.traceDisplay); % absolutely necessary - bring focus to main display, since other functions might have brought it to another axes
%displayTrace(h, expIdx);
h = cellListClick2(h, expIdx);


end


function stimArtifactButton(src, ~)
end

function stimArtifactLength(src, ~)
end

function stimArtifactStart(src, ~)
end

function stimArtifactCount(src, ~)
end

function stimArtifactFreq(src, ~)
end


%% Results Display


function analysisPlotUpdateCall(src, event)
% invoke analysis plot update

% load
h = guidata(src);

%{
if strcmp(src.String{1}, '(Results)') % if called from results type menu
end
%}

% do display
h = analysisPlotUpdate(h);

% save
guidata(src, h);

end


function analysisPlotUpdateCall31(src, ~) % menu 3; plot 1
% choose results type, then invoke analysis plot update

% load
h = guidata(src);

% results type
inputStr = src.String{src.Value};
if strcmp(inputStr, 'Peak')
    inputIdx = 1;
elseif strcmp(inputStr, 'Area')
    inputIdx = 2;
elseif strcmp(inputStr, 'Mean')
    inputIdx = 3;
elseif strcmp(inputStr, 'Time of Peak')
    inputIdx = 4;
elseif strcmp(inputStr, 'Rise (time)')
    inputIdx = 5;
elseif strcmp(inputStr, 'Decay (time)')
    inputIdx = 6;
elseif strcmp(inputStr, 'Rise (slope)')
    inputIdx = 7;
elseif strcmp(inputStr, 'Decay (slope)')
    inputIdx = 8;
else
    inputIdx = 0;
end
    
% do display
plotIdx = 1; % plot 2
h = analysisPlotUpdateNew(h, inputIdx, plotIdx);

% save
guidata(src, h);

end


function analysisPlotUpdateCall32(src, ~) % menu 3; plot 2
% choose results type, then invoke analysis plot update

% load
h = guidata(src);

% results type
inputStr = src.String{src.Value};
if strcmp(inputStr, 'Peak')
    inputIdx = 1;
elseif strcmp(inputStr, 'Area')
    inputIdx = 2;
elseif strcmp(inputStr, 'Mean')
    inputIdx = 3;
elseif strcmp(inputStr, 'Time of Peak')
    inputIdx = 4;
elseif strcmp(inputStr, 'Rise (time)')
    inputIdx = 5;
elseif strcmp(inputStr, 'Decay (time)')
    inputIdx = 6;
elseif strcmp(inputStr, 'Rise (slope)')
    inputIdx = 7;
elseif strcmp(inputStr, 'Decay (slope)')
    inputIdx = 8;
else
    inputIdx = 0;
end
    
% do display
plotIdx = 2; % plot 2
h = analysisPlotUpdateNew(h, inputIdx, plotIdx);

% save
guidata(src, h);

end


function h = analysisPlotUpdateCall3HandleInput(h, inputStr, plotIdx)
% choose results type, then invoke analysis plot update

% results type
if strcmp(inputStr, 'Peak')
    inputIdx = 1;
elseif strcmp(inputStr, 'Area')
    inputIdx = 2;
elseif strcmp(inputStr, 'Mean')
    inputIdx = 3;
elseif strcmp(inputStr, 'Time of Peak')
    inputIdx = 4;
elseif strcmp(inputStr, 'Rise (time)')
    inputIdx = 5;
elseif strcmp(inputStr, 'Decay (time)')
    inputIdx = 6;
elseif strcmp(inputStr, 'Rise (slope)')
    inputIdx = 7;
elseif strcmp(inputStr, 'Decay (slope)')
    inputIdx = 8;
else
    inputIdx = 0;
end
    
% do display
h = analysisPlotUpdateNew(h, inputIdx, plotIdx);

end


function h = analysisPlotUpdate(h)

%{
% load
h = guidata(src);
%}

% current experiment
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
results = h.results{expIdx};

% fetch plot info
try
    analysisPlot1Menu1 = h.ui.analysisPlot1Menu1.Value; % (sel), v, dff
    analysisPlot1Menu2 = h.ui.analysisPlot1Menu2.Value; % (sel), win1, win2
    analysisPlot1Menu3 = h.ui.analysisPlot1Menu3.Value; % (sel), (result type)
    analysisPlot1Menu4 = h.ui.analysisPlot1Menu4.Value; % (sel), swp, grp
    analysisPlot2Menu1 = h.ui.analysisPlot2Menu1.Value; % (sel), v, dff
    analysisPlot2Menu2 = h.ui.analysisPlot2Menu2.Value; % (sel), win1, win2
    analysisPlot2Menu3 = h.ui.analysisPlot2Menu3.Value; % (sel), (result type)
    analysisPlot2Menu4 = h.ui.analysisPlot2Menu4.Value; % (sel), swp, grp
catch ME
end

%  plot 1
try
    analysisPlot1 = h.ui.analysisPlot1;
    axes(analysisPlot1);
    cla;
    h.ui.analysisPlot1 = analysisPlot1;
    switch analysisPlot1Menu1 % signal
        case 1 % unselected - do nothing
            return
        case 2 % v/i
            results1 = results.VRec;
            color = [0, 0, 0];
        case 3 % dff
            results1 = results.dff;
            color = [0, 0.5, 0];
    end
    winToPlot = analysisPlot1Menu2 - 1; % let the try block take care of winToPlot == 0
    switch analysisPlot1Menu4 % plot by...
        case 1 % unselected - do nothing
            return
        case 2 % by sweep
            results1 = results1.sweepResults;
            dataX = 1:length(results1.sweeps); % sweep number
        case 3 % by group
            results1 = results1.groupResults;
            dataX = 1:length(results1.groups); % group number
    end
    
    %  organize data
    switch h.ui.analysisType1.Value
        case 2 % peak/area/mean
            switch analysisPlot1Menu3 % which kind of results
                case 2
                    dataY = results1.peak;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                case 3
                    dataY = results1.area;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                case 4
                    dataY = results1.mean;
                    resultsType = 1; % only one here
                case 5
                    dataY = results1.timeOfPeak;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                case 6
                    dataY = results1.riseTime;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                case 7
                    dataY = results1.decayTime;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                case 8
                    dataY = results1.riseSlope;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                case 9
                    dataY = results1.decaySlope;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                otherwise
                    dataY = [];
                    resultsType = 1; % whatever
            end
        otherwise % other type of analysis - not implemented yet %%%
    end
    
    dataY = dataY(winToPlot, :); % analysis window 1
    dataYNew = nan(length(dataY), 1); % initialize
    for i = 1:length(dataY)
        dataYi = dataY{i}; % current sweep/group
        if isempty(dataYi)
            dataYi = NaN;
        else
            dataYi = dataYi(resultsType);
        end
        dataYNew(i) = dataYi; % update
    end
    dataY = dataYNew; % update
    axes(analysisPlot1);
    cla;
    hold on;
    analysisPlot1 = displayResults(analysisPlot1, dataX, dataY, color);
    set(gca, 'xlim', [0, length(dataX) + 1]); % padding for appearance
    hold off;
    switch analysisPlot1Menu1 % signal
        case 1 % unselected - do nothing
            return
        case 2 % v/i
            ylabel('PSP (mV)');
            %{
            if nanmax(dataY) > 40
                ylim([0, 40.5]);
                yticks(-1000:10:1000);
            elseif nanmax(dataY) > 10
                ylim([0, max(dataY) + 0.5]);
                yticks(-1000:5:1000);
            else
                ylim([0, 10.5]);
                yticks(-1000:2:1000);
            end
            %}
        case 3 % dff
            ylabel('dF/F');
            %{
            if nanmax(dataY) > 4
                ylim([-0.5, max(dataY) + 0.5]);
                yticks(-10:1:100);
            else
                ylim([-0.5, 4.5]);
                yticks(-10:1:100);
            end
            %}
    end
    %xticks(0:5:10000);
    set(gca, 'xminortick', 'on', 'yminortick', 'on');
    switch analysisPlot1Menu4 % plot by...
        case 1 % unselected - do nothing
            return
        case 2 % by sweep
            xlabel('Sweep #');
        case 3 % by group
            xlabel('Group #');
    end
    h.ui.analysisPlot1 = analysisPlot1;
    h.params.resultsPlot1YRange = analysisPlot1.YLim;
catch ME
end

%  plot 2
try
    analysisPlot2 = h.ui.analysisPlot2;
    axes(analysisPlot2);
    cla;
    h.ui.analysisPlot2 = analysisPlot2;
    switch analysisPlot2Menu1 % signal
        case 1 % unselected - do nothing
            return
        case 2 % v/i
            results2 = results.VRec;
            color = [0, 0, 0];
        case 3 % dff
            results2 = results.dff;
            color = [0, 0.5, 0];
    end
    winToPlot = analysisPlot2Menu2 - 1; % let the try block take care of winToPlot == 0
    switch analysisPlot2Menu4 % plot by...
        case 1 % unselected - do nothing
            return
        case 2 % by sweep
            results2 = results2.sweepResults;
            dataX = 1:length(results2.sweeps); % sweep number
        case 3 % by group
            results2 = results2.groupResults;
            dataX = 1:length(results2.groups); % group number
    end

    %  organize data
    switch h.ui.analysisType2.Value
        case 2 % peak/area/mean
            switch analysisPlot2Menu3 % which kind of results
                case 2
                    dataY = results2.peak;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                case 3
                    dataY = results2.area;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                case 4
                    dataY = results2.mean;
                    resultsType = 1; % only one here
                case 5
                    dataY = results2.timeOfPeak;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                case 6
                    dataY = results2.riseTime;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                case 7
                    dataY = results2.decayTime;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                case 8
                    dataY = results2.riseSlope;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                case 9
                    dataY = results2.decaySlope;
                    resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                otherwise
                    dataY = [];
                    resultsType = 1; % whatever
            end
        otherwise % other type of analysis - not implemented yet %%%
    end
    
    dataY = dataY(winToPlot, :); % analysis window 2
    dataYNew = nan(length(dataY), 1); % initialize
    for i = 1:length(dataY)
        dataYi = dataY{i}; % current sweep/group
        if isempty(dataYi)
            dataYi = NaN;
        else
            dataYi = dataYi(resultsType);
        end
        dataYNew(i) = dataYi; % update
    end
    dataY = dataYNew; % update
    axes(analysisPlot2);
    cla;
    hold on;
    analysisPlot2 = displayResults(analysisPlot2, dataX, dataY, color);
    set(gca, 'xlim', [0, length(dataX) + 1]); % padding for appearance
    hold off;
    switch analysisPlot2Menu1 % signal
        case 1 % unselected - do nothing
            return
        case 2 % v/i
            ylabel('PSP (mV)');
            %{
            if nanmax(dataY) > 40
                ylim([0, 40.5]);
                yticks(-1000:10:1000);
            elseif nanmax(dataY) > 10
                ylim([0, max(dataY) + 0.5]);
                yticks(-1000:5:1000);
            else
                ylim([0, 10.5]);
                yticks(-1000:2:1000);
            end
            %}
        case 3 % dff
            ylabel('dF/F');
            %{
            if nanmax(dataY) > 4
                ylim([-0.5, max(dataY) + 0.5]);
                yticks(-10:1:100);
            else
                ylim([-0.5, 4.5]);
                yticks(-10:1:100);
            end
            %}
    end
    %xticks(0:5:10000);
    set(gca, 'xminortick', 'on', 'yminortick', 'on');
    switch analysisPlot2Menu4 % plot by...
        case 1 % unselected - do nothing
            return
        case 2 % by sweep
            xlabel('Sweep #');
        case 3 % by group
            xlabel('Group #');
    end
    h.ui.analysisPlot2 = analysisPlot2;
    h.params.resultsPlot2YRange = analysisPlot2.YLim;
catch ME
end

%{
% save
guidata(src, h);
%}

end


function h = analysisPlotUpdateNew(h, inputIdx, plotIdx)

%{
% load
h = guidata(src);
%}

% current experiment
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
%h.ui.cellListDisplay.Value = expIdx; %%% fixlater ? don't do this here
results = h.results{expIdx};

% fetch plot info
try
    analysisPlot1Menu1 = h.ui.analysisPlot1Menu1.Value; % (sel), v, dff
    analysisPlot1Menu2 = h.ui.analysisPlot1Menu2.Value; % (sel), win1, win2
    analysisPlot1Menu3 = h.ui.analysisPlot1Menu3.Value; % (sel), (result type)
    analysisPlot1Menu4 = h.ui.analysisPlot1Menu4.Value; % (sel), swp, grp
    analysisPlot2Menu1 = h.ui.analysisPlot2Menu1.Value; % (sel), v, dff
    analysisPlot2Menu2 = h.ui.analysisPlot2Menu2.Value; % (sel), win1, win2
    analysisPlot2Menu3 = h.ui.analysisPlot2Menu3.Value; % (sel), (result type)
    analysisPlot2Menu4 = h.ui.analysisPlot2Menu4.Value; % (sel), swp, grp
catch ME
end

%  plot 1
if plotIdx == 1
    try
        analysisPlot1 = h.ui.analysisPlot1;
        axes(analysisPlot1);
        cla;
        h.ui.analysisPlot1 = analysisPlot1;
        switch analysisPlot1Menu1 % signal
            case 1 % unselected - do nothing
                return
            case 2 % v/i
                results1 = results.VRec;
                color = [0, 0, 0];
            case 3 % dff
                results1 = results.dff;
                color = [0, 0.5, 0];
        end
        winToPlot = analysisPlot1Menu2 - 1; % let the try block take care of winToPlot == 0
        switch analysisPlot1Menu4 % plot by...
            case 1 % unselected - do nothing
                return
            case 2 % by sweep
                results1 = results1.sweepResults;
                dataX = 1:length(results1.sweeps); % sweep number
            case 3 % by group
                results1 = results1.groupResults;
                dataX = 1:length(results1.groups); % group number
        end
        %  organize data
        %dataY = results1.peak; % grouped results, peak %%% switch here for analysis type later
        %   which kind of results
        switch inputIdx
            case 1
                dataY = results1.peak;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            case 2
                dataY = results1.area;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            case 3
                dataY = results1.mean;
                resultsType = 1; % only one here
            case 4
                dataY = results1.timeOfPeak;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            case 5
                dataY = results1.riseTime;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            case 6
                dataY = results1.decayTime;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            case 7
                dataY = results1.riseSlope;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            case 8
                dataY = results1.decaySlope;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            otherwise
                dataY = [];
                resultsType = 1; % whatever
        end
        dataY = dataY(winToPlot, :); % analysis window 1
        dataYNew = nan(length(dataY), 1); % initialize
        for i = 1:length(dataY)
            dataYi = dataY{i}; % current sweep/group
            if isempty(dataYi)
                dataYi = NaN;
            else
                dataYi = dataYi(resultsType);
            end
            dataYNew(i) = dataYi; % update
        end
        dataY = dataYNew; % update
        axes(analysisPlot1);
        cla;
        hold on;
        analysisPlot1 = displayResults(analysisPlot1, dataX, dataY, color);
        set(gca, 'xlim', [0, length(dataX) + 1]); % padding for appearance
        hold off;
        switch analysisPlot1Menu1 % signal
            case 1 % unselected - do nothing
                return
            case 2 % v/i
                ylabel('PSP (mV)');
                switch inputIdx
                    case 1
                        ylabel('PSP (mV)')
                    case 2
                        ylabel('Area (mV*ms)')
                    case 3
                        ylabel('Mean (mV)')
                    case 4
                        ylabel('t of peak (ms)')
                    case 5
                        ylabel('rise (ms)')
                    case 6
                        ylabel('decay (ms)')
                    case 7
                        ylabel('rise (mV/ms)')
                    case 8
                        ylabel('decay (mV/ms)')
                    otherwise
                        ylabel('')
                end
                %{
                if nanmax(abs(dataY)) > 150 % arbitrary but reasonable display range beyond AP
                    ylim([min(0, nanmin(dataY) - 5), max(0, nanmax(dataY) + 5)]);
                    yticks(-1000000:10*round(nanmax(abs(dataY))/50):1000000);
                    %{
                elseif nanmax((dataY)) > 40 && inputIdx == 1 % arbitrary but reasonable display range for peak PSP
                    ylim([0, 40.5]);
                    yticks(-1000:10:1000);
                    %}
                elseif nanmax(abs(dataY)) > 40
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-1000:10:1000);
                elseif nanmax(abs(dataY)) > 10
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-1000:5:1000);
                elseif nanmax(abs(dataY)) > 5
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-1000:1:1000);
                elseif nanmax(abs(dataY)) < 1
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-100:0.1*max(abs(dataY)):100);
                else
                    ylim([0, 5.5]);
                    yticks(-1000:2:1000);
                end
                %}
            case 3 % dff
                ylabel('dF/F');
                switch inputIdx % although it doesn't make much sense here...
                    case 1
                        ylabel('dF/F')
                    case 2
                        ylabel('dF/F area')
                    case 3
                        ylabel('dF/F mean')
                    case 4
                        ylabel('t of peak (ms)')
                    case 5
                        ylabel('rise (ms)')
                    case 6
                        ylabel('decay (ms)')
                    case 7
                        ylabel('rise (mV/ms)')
                    case 8
                        ylabel('decay (mV/ms)')
                    otherwise
                        ylabel('')
                end
                %{
                if nanmax(abs(dataY)) > 100
                    ylim([[min(0, nanmin(dataY) - 5), max(0, nanmax(dataY) + 5)]]);
                    yticks(-1000000:10*round(nanmax(abs(dataY))/50):1000000);
                elseif nanmax(abs(dataY)) > 50
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-1000:10:1000);
                elseif nanmax(abs(dataY)) > 10
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-100:5:100);
                elseif nanmax(abs(dataY)) > 4
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-10:1:10);
                else
                    ylim([min(-4.5, nanmin(dataY) - 0.5), max(4.5, nanmax(dataY) + 0.5)]);
                    yticks(-10:1:100);
                end
                %}
        end
        %xticks(0:5:10000);
        set(gca, 'xminortick', 'on', 'yminortick', 'on');
        switch analysisPlot1Menu4 % plot by...
            case 1 % unselected - do nothing
                return
            case 2 % by sweep
                xlabel('Sweep #');
            case 3 % by group
                xlabel('Group #');
        end
        h.ui.analysisPlot1 = analysisPlot1;
        h.params.resultsPlot1YRange = analysisPlot1.YLim;
    catch ME
    end
end

%  plot 2
if plotIdx == 2
    try
        analysisPlot2 = h.ui.analysisPlot2;
        axes(analysisPlot2);
        cla;
        h.ui.analysisPlot2 = analysisPlot2;
        switch analysisPlot2Menu1 % signal
            case 1 % unselected - do nothing
                return
            case 2 % v/i
                results2 = results.VRec;
                color = [0, 0, 0];
            case 3 % dff
                results2 = results.dff;
                color = [0, 0.5, 0];
        end
        winToPlot = analysisPlot2Menu2 - 1; % let the try block take care of winToPlot == 0
        switch analysisPlot2Menu4 % plot by...
            case 1 % unselected - do nothing
                return
            case 2 % by sweep
                results2 = results2.sweepResults;
                dataX = 1:length(results2.sweeps); % sweep number
            case 3 % by group
                results2 = results2.groupResults;
                dataX = 1:length(results2.groups); % group number
        end
        %  organize data
        %dataY = results2.peak; % grouped results, peak %%% switch here for analysis type later
        %   which kind of results
        switch inputIdx
            case 1
                dataY = results2.peak;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            case 2
                dataY = results2.area;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            case 3
                dataY = results2.mean;
                resultsType = 1; % only one here
            case 4
                dataY = results2.timeOfPeak;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            case 5
                dataY = results2.riseTime;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            case 6
                dataY = results2.decayTime;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            case 7
                dataY = results2.riseSlope;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            case 8
                dataY = results2.decaySlope;
                resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
            otherwise
                dataY = [];
                resultsType = 1; % whatever
        end
        dataY = dataY(winToPlot, :); % analysis window 2
        dataYNew = nan(length(dataY), 1); % initialize
        for i = 1:length(dataY)
            dataYi = dataY{i}; % current sweep/group
            if isempty(dataYi)
                dataYi = NaN;
            else
                dataYi = dataYi(resultsType);
            end
            dataYNew(i) = dataYi; % update
        end
        dataY = dataYNew; % update
        axes(analysisPlot2);
        cla;
        hold on;
        analysisPlot2 = displayResults(analysisPlot2, dataX, dataY, color);
        set(gca, 'xlim', [0, length(dataX) + 1]); % padding for appearance
        hold off;
        switch analysisPlot2Menu1 % signal
            case 1 % unselected - do nothing
                return
            case 2 % v/i
                ylabel('PSP (mV)');
                switch inputIdx
                    case 1
                        ylabel('PSP (mV)')
                    case 2
                        ylabel('Area (mV*ms)')
                    case 3
                        ylabel('Mean (mV)')
                    case 4
                        ylabel('t of peak (ms)')
                    case 5
                        ylabel('rise (ms)')
                    case 6
                        ylabel('decay (ms)')
                    case 7
                        ylabel('rise (mV/ms)')
                    case 8
                        ylabel('decay (mV/ms)')
                    otherwise
                        ylabel('')
                end
                %{
                if nanmax(abs(dataY)) > 150 % arbitrary but reasonable display range beyond AP
                    ylim([min(0, nanmin(dataY) - 5), max(0, nanmax(dataY) + 5)]);
                    yticks(-1000000:10*round(nanmax(abs(dataY))/50):1000000);
                    %{
                elseif nanmax((dataY)) > 40 && inputIdx == 1 % arbitrary but reasonable display range for peak PSP
                    ylim([0, 40.5]);
                    yticks(-1000:10:1000);
                    %}
                elseif nanmax(abs(dataY)) > 40
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-1000:10:1000);
                elseif nanmax(abs(dataY)) > 10
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-1000:5:1000);
                elseif nanmax(abs(dataY)) > 5
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-1000:1:1000);
                elseif nanmax(abs(dataY)) < 1
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-100:0.1*max(abs(dataY)):100);
                else
                    ylim([0, 5.5]);
                    yticks(-1000:2:1000);
                end
                %}
            case 3 % dff
                ylabel('dF/F');
                switch inputIdx % although it doesn't make much sense here...
                    case 1
                        ylabel('dF/F')
                    case 2
                        ylabel('dF/F area')
                    case 3
                        ylabel('dF/F mean')
                    case 4
                        ylabel('t of peak (ms)')
                    case 5
                        ylabel('rise (ms)')
                    case 6
                        ylabel('decay (ms)')
                    case 7
                        ylabel('rise (mV/ms)')
                    case 8
                        ylabel('decay (mV/ms)')
                    otherwise
                        ylabel('')
                end
                %{
                if nanmax(abs(dataY)) > 100
                    ylim([[min(0, nanmin(dataY) - 5), max(0, nanmax(dataY) + 5)]]);
                    yticks(-1000000:10*round(nanmax(abs(dataY))/50):1000000);
                elseif nanmax(abs(dataY)) > 50
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-1000:10:1000);
                elseif nanmax(abs(dataY)) > 10
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-100:5:100);
                elseif nanmax(abs(dataY)) > 4
                    ylim([min(0, nanmin(dataY) - 0.5), max(0, nanmax(dataY) + 0.5)]);
                    yticks(-10:1:10);
                else
                    ylim([min(-4.5, nanmin(dataY) - 0.5), max(4.5, nanmax(dataY) + 0.5)]);
                    yticks(-10:1:100);
                end
                %}
        end
        %xticks(0:5:10000);
        set(gca, 'xminortick', 'on', 'yminortick', 'on');
        switch analysisPlot2Menu4 % plot by...
            case 1 % unselected - do nothing
                return
            case 2 % by sweep
                xlabel('Sweep #');
            case 3 % by group
                xlabel('Group #');
        end
        h.ui.analysisPlot2 = analysisPlot2;
        h.params.resultsPlot2YRange = analysisPlot2.YLim;
    catch ME
    end
end

%{
% save
guidata(src, h);
%}

end


function targetDisplay = displayResults(targetDisplay, dataX, dataY, color)

% pretty self-explanatory
axes(targetDisplay); 
cla;
hold on;
%scatter(dataX, dataY, 12, 'filled', 'markerfacecolor', color); % 12 is markersize
plot(dataX, dataY, 'color', color, 'marker', 'o', 'markersize', 3, 'markerfacecolor', color);
hold off;

end


%% Other Associated Data


function notesEdit(src, ~)

% load
h = guidata(src);

expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
%{
notes = h.exp.data.notes;
notes = notes{expIdx};
%}
notesNew = h.ui.notes.String;
h.exp.data.notes{expIdx} = notesNew;

% save
guidata(src, h);

end


function loadIntrinsic(src, ~)
% load and display intrinsic membrane properties
%  mostly recycled from very very old code (which is also why it's in snake_case)
%  needs to cleaned up for performance... this part is really fucked up %%% fixlater

h = guidata(src);

try
    tic; % also within loadIntrinsicActual(), but just in case
    [h, data_voltage_original] = loadIntrinsicActual(h); % contains tic;
    try
        h = intrinsicAnalysis(h, data_voltage_original, 0);
        elapsedTime = toc;
        fprintf('\n Analysis complete. (elapsed time: %.2f s)\n\n', elapsedTime);
        guidata(src, h);
    catch ME
        elapsedTime = toc;
        error('Analysis parameters incompatible with data shape');
    end
catch ME
    elapsedTime = toc;
end

end


function [h, data_voltage_original] = loadIntrinsicActual(h)

    % basic parameters
    csvOffsetRow = h.params.actualParams.csvOffsetRow; % row offset while reading csv with csvread() (default: 1)
    csvOffsetColumn = h.params.actualParams.csvOffsetColumn; % column offset while reading csv with csvread() (default: 0)

    % load
    if isempty(h.ui.cellListDisplay.String)
        error('Error: Load experiment(s) first before loading intrinsic properties');
    end
    expIdx = h.ui.cellListDisplay.Value;
    expIdx = expIdx(1); % force single selection
    h.ui.cellListDisplay.Value = expIdx;
    
    % prompt, since this could take some time
    fprintf('Loading & analyzing intrinsic properties... ');

    % load datafile
    try
        [fName, fPath] = uigetfile({'*.xml', 'VoltageRecording Metadata'; '*.csv', 'VoltageRecording Data'}, 'Select VoltageRecording (.xml, .csv)'); % filters for '.xml' extension only
    catch
        waitfor(msgbox('Error: Select valid .xml or .csv'));
        error('Error: Select valid .xml or .csv');
    end
    if fName == 0
        fprintf('Canceled.\n\n');
        return
    end
    tic; % start stopwatch
    
    fExt = fName(end - 3:end);
    if strcmp(fExt, '.xml'); % if .xml file is selected
        isCSV = 0;
    elseif strcmp(fExt, '.csv'); % if .csv file is selected
        isCSV = 1;
    else
        elapsedTime = toc;
        error('Error: Invalid file type');
    end
       
    % check if a file was loaded
    if isCSV
        voltageRecordingMetadata = [];
        h.exp.data.intrinsicPropertiesVRecMetadata{expIdx} = voltageRecordingMetadata;
        h.exp.data.intrinsicProperties{expIdx}.fileName = fName;
        h.exp.data.intrinsicProperties{expIdx}.filePath = fPath;
    else
        [voltageRecordingMetadata] = xml2struct_pvbs([fPath, fName]); % load metadata from xml using modified xml2struct
        h.exp.data.intrinsicPropertiesVRecMetadata{expIdx} = voltageRecordingMetadata;
        h.exp.data.intrinsicProperties{expIdx}.fileName = fName;
        h.exp.data.intrinsicProperties{expIdx}.filePath = fPath;
    end
    fileNameStr = [fName, ' (', fPath, ')'];
    h.exp.data.intrinsicPropertiesFileName{expIdx} = fileNameStr;
    set(h.ui.intrinsicFileName, 'string', fileNameStr);
    cla(h.ui.intrinsicPlot1);
    cla(h.ui.intrinsicPlot2);
    cla(h.ui.intrinsicPlot3);
    
    % iterate for cycles %%% ...not! fixlater
	cycleCurrent = 1; %%% gotta start somewhere
    %{
    for cycle_current = 1:guiHandles.experiment.voltageRecording.analysisParameters.cyclesTotal
        % do stuff
    end
    %}
    
    % set data file names for current cycle
    % "....Sequence" may be a struct (with only 1 cycle total) or a cell (with multiple cycles), repeated for each cycle in the latter case
    if isCSV
        data_voltage_original = csvread([fPath, fName], csvOffsetRow, csvOffsetColumn); % offset row by 1 ("time(ms), input 0, input 1"), and column by 0
    else
        if isstruct(voltageRecordingMetadata.PVScan.Sequence)
            data_file_voltage = voltageRecordingMetadata.PVScan.Sequence.VoltageRecording.Attributes.dataFile; % ....Sequence.VoltageRecording is the 1st entry (or 3rd from end); mind the capitalization
        elseif iscell(voltageRecordingMetadata.PVScan.Sequence)
            data_file_voltage = voltageRecordingMetadata.PVScan.Sequence{cycleCurrent}.VoltageRecording.Attributes.dataFile;
        else
            error(sprintf('\nUnexpected experiment metadata format\n'));
        end
        % import data for current cycle
        data_voltage_original = csvread([fPath, data_file_voltage], csvOffsetRow, csvOffsetColumn); % offset row by 1 ("time(ms), input 0, input 1"), and column by 0
    end

end


function h = intrinsicAnalysis(h, data_voltage_original, flagScalingOverride)
% actually run intrinsic membrane properties analysis and display results
%  mostly recycled from very very old code (which is also why it's in snake_case)
%  needs to cleaned up for performance... this part is really fucked up %%% fixlater

    analysisParameters = h.params.actualParams.intrinsicPropertiesAnalysis;

    % Unit conversion for V_rec (unit for raw numbers: 10 nV for Dagan - PVBS)
    v_rec_gain = analysisParameters.v_rec_gain; % to convert to mV - NB. also useful to know when using ClampFit
    % Unit conversion for i_cmd (unit for raw numbers: 10 nA for Dagan - PVBS)
    i_cmd_gain = analysisParameters.i_cmd_gain; % to convert to pA (10 for nA) - NB. also useful to know when using ClampFit

    if flagScalingOverride % lol
        v_rec_gain = 1;
        i_cmd_gain = 1;
    end
    
    % data processing %%% allow access and edit from main window later
    voltage_signal_channel = analysisParameters.voltage_signal_channel; % V_m acquisition channel, from PVBS
    data_segmentation_cutoff_first = analysisParameters.data_segmentation_cutoff_first; % (ms); discard this length of data at the beginning
    data_segment_length = analysisParameters.data_segment_length; % Sweep duration (ms), synonymous with inter-sweep interval because of absolutely stupid gap-free PVBS
    data_length_unit = analysisParameters.data_length_unit; % (ms); truncate data to a nice multiple of this (e.g. 17078 ms -> 17070 ms)
    data_voltage_samplingrate = analysisParameters.data_voltage_samplingrate; % (kHz); sampling rate, after reduction: (e.g. 10 kHz = 10 points/ms)
    data_voltage_interval = analysisParameters.data_voltage_interval; % (ms)
    
    % correction for phantom (i.e. cosmetic) current offset error produced by PVBS GPIO box
    % this works by subtracting average current at the beginning, thus i_cmd (t = 0) must be 0 during recording!
    i_bsln_correction = analysisParameters.i_bsln_correction; % (0: no, 1: yes) PVBS GPIO box bleedthrough correction
    i_bsln_correction_window = analysisParameters.i_bsln_correction_window; % (ms); this should do
    
    % detection window; for more than 2 windows, manually set them as n*3 arrays (start, end, direction) and pass them onto functions
    window_baseline_start = analysisParameters.window_baseline_start; % (ms); baseline start - this is not for main analysis window, but for intrinsic properties!
    window_baseline_end = analysisParameters.window_baseline_end; % (ms); baseline end
    window_n = analysisParameters.window_n; % number of detection windows (1 or 2)
    window_1_start = analysisParameters.window_1_start; % (ms); detection window 1 start
    window_1_end = analysisParameters.window_1_end; % (ms); detection window 1 end
    window_1_direction = analysisParameters.window_1_direction; % (ms); detection window 1 direction (-1: negative, 0: either, 1: positive; e.g. for peak detection)
    window_2_start = analysisParameters.window_2_start; % (ms); analysis window 2 start
    window_2_end = analysisParameters.window_2_end; % (ms); analysis window 2 end
    window_2_direction = analysisParameters.window_2_direction; % (ms); analysis window 2 direction (-1: negative, 0: either, 1: positive; e.g. for peak detection)
 
    % initialize data array
    data_voltage = [];
    data_voltage_episodic = {}; % cell should be easier to handle than a 4-d array
    
    % get data sampling rate from raw data; could also be fetched from metadata, but easier and more straightforward this way
    data_voltage_interval_original = data_voltage_original(2,1) - data_voltage_original(1,1); % (ms)
    data_voltage_samplingrate_original = 1/data_voltage_interval_original; % (kHz)
    %h.experiment.voltageRecording.analysisParameters.voltageSamplingRateOriginal = data_voltage_samplingrate_original;
    
    % prune the end of data
    data_voltage_length = floor(size(data_voltage_original, 1)/(data_voltage_samplingrate_original*data_length_unit))*data_length_unit; % see pvbs_voltagerecording.m for default

    % truncate data into equal-length segments
    data_voltage_interval = 1 / data_voltage_samplingrate; % (ms)
    data_voltage_length_points = data_voltage_length / data_voltage_interval_original;
    if length(data_voltage_original) < data_voltage_length_points
        clear;
        error(sprintf('\nDesignated data length exceeds original data length\n'));
    else
        data_voltage_cycle = data_voltage_original(1:data_voltage_length_points, 2:end); % removing timestamp
    end
    
    % reduce data by boxcar averaging
    data_voltage_samplingrate = data_voltage_samplingrate_original; %%% how about no
    data_voltage_samplingrate_reductionfactor = data_voltage_samplingrate_original / data_voltage_samplingrate;
    if data_voltage_samplingrate_reductionfactor < 1
        clear;
        error(sprintf('\nDesignated sampling rate exceeds original sampling rate\n'));
    end
    data_voltage_new = NaN(floor(size(data_voltage_cycle, 1)/data_voltage_samplingrate_reductionfactor), size(data_voltage_cycle, 2));
    for idx2 = 1:size(data_voltage_cycle, 2) % for each column in data, e.g. V_rec, I_cmd
        for idx1 = 1:floor(size(data_voltage_cycle, 1)/data_voltage_samplingrate_reductionfactor)
            data_voltage_new(idx1, idx2) = ...
                nanmean(data_voltage_cycle(1 + data_voltage_samplingrate_reductionfactor*(idx1 - 1) : data_voltage_samplingrate_reductionfactor*idx1, idx2));
        end
    end
    data_voltage_cycle = data_voltage_new;
    
    % correct for cosmetic error produced by PVBS GPIO box 
    %%%%%%% i is going away here!!!
    if i_bsln_correction == 1 %%% is it worth it to avoid using if?
        i_bsln_correction_value = nanmean(data_voltage_cycle(1:i_bsln_correction_window*data_voltage_samplingrate, 2));
        data_voltage_cycle(:,2) = data_voltage_cycle(:,2) - i_bsln_correction_value;
    end
    %clear i_bsln_correction i_bsln_correction_value i_bsln_correction_window; %%% save these into analysis metadata... later

    % Re-append updated timestamp - this is an artifact from LineScan analysis code (where timestamps are unsynchronized between LineScan and VoltageRecording)
    timestamp_voltage = 0 : data_voltage_interval : data_voltage_interval*size(data_voltage_cycle, 1);
    timestamp_voltage = timestamp_voltage(1 : end - 1);
    timestamp_voltage = timestamp_voltage';
    data_voltage_cycle = [timestamp_voltage, data_voltage_cycle];
    
    % Unit conversion (see start of function for settings)
    data_voltage_cycle(:,2) = data_voltage_cycle(:,2)*v_rec_gain;
    data_voltage_cycle(:,3) = data_voltage_cycle(:,3)*i_cmd_gain; % Reminder: by lab convention, input 0 is V_rec, and input 1 is i_cmd
    clear v_rec_gain i_cmd_gain;


    % Segmentation of moronic gap-free PVBS data into episodic-like form
    %data_segment_length = size(data_voltage_cycle, 1); % un-comment this to default to no segmentation
    %if h.experiment.voltageRecording.analysisParameters.cyclesTotal == 1 || cycleCurrent == 1
        %{
        prompt = {'Truncate first (ms): ', 'Segment length (ms; -1 to cancel segmentation): ', 'Discard last segment if incomplete? [0/1]', 'Calculate and display average? [0/1]'};
        prompt_ans_default = {num2str(data_segmentation_cutoff_first), num2str(data_segment_length), '1', '0'};
        data_segmentation = inputdlg(prompt, 'Data segmentation', [1 64], prompt_ans_default);
        clear prompt prompt_ans_default;
        %}
        data_segmentation = {num2str(data_segmentation_cutoff_first), num2str(data_segment_length), '1', '0'};
    %else
    %end

    % Data segmentation parameters
    data_segmentation_cutoff_first = str2double(data_segmentation{1})/data_voltage_interval; % converting ms to datapoints
    if str2double(data_segmentation{2}) == -1
        data_segment_length = size(data_voltage_cycle, 1); % no segmentation
    else
        data_segment_length = str2double(data_segmentation{2})/data_voltage_interval; % converting ms to datapoints
    end
    if str2double(data_segmentation{3}) == 0 | str2double(data_segmentation{3}) == 1
    else
        %clear;
        error(sprintf('\nInput for "Discard last segment if incomplete?" must be 0 or 1\n'));
    end

    % Prepare space for segmented data
    if data_segment_length == 0 | isnan(data_segment_length)
        %clear;
        error(sprintf('\n"Data segment length" must not be 0\n'));
    elseif str2double(data_segmentation{3}) == 0
        data_segment_count = ceil((size(data_voltage_cycle, 1) - data_segmentation_cutoff_first)/data_segment_length);
        data_voltage_cycle_episodic = nan(data_segment_length, size(data_voltage_cycle, 2), data_segment_count);
    elseif str2double(data_segmentation{3}) == 1
        data_segment_count = floor((size(data_voltage_cycle, 1) - data_segmentation_cutoff_first)/data_segment_length);
        data_voltage_cycle_episodic = nan(data_segment_length, size(data_voltage_cycle, 2), data_segment_count);
    end

    % Get remainder data points; if 0, then just segment; if not 0, then follow users choice
    data_segmentation_cutoff_last = rem((size(data_voltage_cycle, 1) - data_segmentation_cutoff_first), data_segment_length);

    % Actually allocate data into segments (equivalent of sweeps)
    if data_segmentation_cutoff_last == 0 | str2double(data_segmentation{3}) == 1
        for idx1 = 1 : data_segment_count
            for idx2 = 1:data_segment_length
                data_voltage_cycle_episodic(idx2, :, idx1) = data_voltage_cycle(data_segmentation_cutoff_first + (idx1-1)*data_segment_length + idx2,:);
            end
        end
    else
        for idx1 = 1 : data_segment_count - 1
            for idx2 = 1:data_segment_length
                data_voltage_cycle_episodic(idx2, :, idx1) = data_voltage_cycle(data_segmentation_cutoff_first + (idx1-1)*data_segment_length + idx2,:);
            end
        end
        idx1 = idx1 + 1; % last segment
        for idx2 = 1:data_segmentation_cutoff_last
            data_voltage_cycle_episodic(idx2, :, idx1) = data_voltage_cycle(data_segmentation_cutoff_first + (idx1-1)*data_segment_length + idx2,:);
        end
    end
    clear idx1 idx2;

    % Resetting timestamps for each segment
    data_voltage_cycle_episodic(:,1,1) = data_voltage_cycle_episodic(:,1,1) - data_segmentation_cutoff_first * data_voltage_interval;
    for idx = 2:size(data_voltage_cycle_episodic, 3)
        data_voltage_cycle_episodic(:, 1, idx) = data_voltage_cycle_episodic(:, 1, 1);
    end
    clear idx;

    %%{
    % Plot segments instead of entire recording
    if str2double(data_segmentation{4}) == 0
        trace_episodic_color = [0.5, 0.5, 0.5];
    else
        trace_episodic_color = [0.75, 0.75, 0.75];
    end
    %close(1); % to close the entire-length plot
    
    %{
    if GUIHandles.scracm.lineScan.analysisParameters.cyclesTotal == 1
        figures(figure_num) =...
        figure('name', fName);
        figure_num = figure_num + 1;
    else
        figures(figure_num) =...
        figure('name', fName); % edit this later to plot for cycle-specific file name
        figure_num = figure_num + 1;
    end
    hold on;
    %}
    
    
    %{
    % Calculate and display averaged (across segments) trace; no need to calculate if not going to display
    if str2double(data_segmentation{4}) ~= 0
        data_voltage_cycle_episodic_averaged = nan(size(data_voltage_cycle_episodic, 1), size(data_voltage_cycle_episodic, 2), 1);
        for idx1 = 1:size(data_voltage_cycle_episodic, 1)
            for idx2 = 1:size(data_voltage_cycle_episodic, 2)
                data_voltage_cycle_episodic_averaged(idx1, idx2, 1) = nanmean(data_voltage_cycle_episodic(idx1, idx2, :));
            end
        end
        clear idx1 idx2;
        hold on;
        plot(data_voltage_cycle_episodic_averaged(:,1), data_voltage_cycle_episodic_averaged(:,1+voltage_signal_channel), 'color', 'k', 'linewidth', 1);
        hold off;
    end
    %}
    %}

%{
%% #5: Run analysis for each Cycle

% Set detection window
if ischar(exp_analysis_parameters.cycle_selected) || cycle_current == exp_analysis_parameters.cycle_selected(1)
    prompt = {'Baseline start (ms):', 'Baseline end (ms): ', 'Use median for baseline? (0: mean, 1: median)', 'Window 1 start (ms): ', 'Window 1 end (ms): ', 'Window 1 direction (-1, 0, 1; for peaks): ', 'Window 2 start (ms): ', 'Window 2 end (ms): ', 'Window 2 direction (-1, 0, 1; for peaks): '};
    prompt_ans_default = {num2str(window_baseline_start), num2str(window_baseline_end), '1', num2str(window_1_start), num2str(window_1_end), num2str(window_1_direction), num2str(window_2_start), num2str(window_2_end), num2str(window_2_direction)};
    v_detection = inputdlg(prompt, 'dF/F', [1 64], prompt_ans_default);
    v_baseline_start = str2double(v_detection{1}); % (ms)
    v_baseline_end = str2double(v_detection{2}); % (ms)
    v_baseline_median = str2double(v_detection{3});
    v_window_1_start = str2double(v_detection{4}); % (ms)
    v_window_1_end = str2double(v_detection{5}); % (ms)
    v_window_1_direction = str2double(v_detection{6});
    v_window_2_start = str2double(v_detection{4}); % (ms)
    v_window_2_end = str2double(v_detection{5}); % (ms)
    v_window_2_direction = str2double(v_detection{6});
    clear prompt prompt_ans_default;
else
end

% Select type(s) of analysis
analysis_types = {'Peak only', 'Peak and time course', 'Area', 'Mean', 'Median', 'Area'}
[cycle_selected, tf] = listdlg('ListString', cycle_selected, 'InitialValue', 1:cycle_total, 'Name', 'Select Cycles', 'PromptString', 'Select Cycles for analysis');
clear tf;

v_baseline_start = find(v_baseline_start - 0.5 <= data_fluorescence_cycle(:,1) & data_fluorescence_cycle(:,1) < v_baseline_start + 0.5); % row #, implied here is that sampling rate >= 2 kHz
v_baseline_end = find(v_baseline_end - 0.5 <= data_fluorescence_cycle(:,1) & data_fluorescence_cycle(:,1) < v_baseline_end + 0.5); % row #, implied here is that sampling rate >= 2 kHz
if v_baseline_median == 0
    df_f_baseline_f0 = nanmean(data_fluorescence_cycle(v_baseline_start:v_baseline_end, 2));
else
    v_baseline_median = 1;
    df_f_baseline_f0 = nanmedian(data_fluorescence_cycle(v_baseline_start:v_baseline_end, 2));
end
data_fluorescence_cycle_df_f = data_fluorescence_cycle;
data_fluorescence_cycle_df_f(:, 2:end) = (data_fluorescence_cycle_df_f(:, 2:end) - df_f_baseline_f0)/df_f_baseline_f0;

% Append Cycle to complete data array
if isempty(data_fluorescence)
    data_fluorescence = timestamp_fluorescence; % Place timestamp
    data_fluorescence = [data_fluorescence, data_fluorescence_cycle(:,1 + fluorescence_signal_channel)]; % Refer to pvbs_lineScan.m; Ca2+ signal always acquired on channel 1 (= column 2, after timestamp) by lab convention
    data_fluorescence_df_f = timestamp_fluorescence; % Place timestamp
    data_fluorescence_df_f = [data_fluorescence_df_f, data_fluorescence_cycle_df_f(:,1 + fluorescence_signal_channel)];
else
    data_fluorescence = [data_fluorescence, data_fluorescence_cycle(:,1 + fluorescence_signal_channel)];
    data_fluorescence_df_f = [data_fluorescence_df_f, data_fluorescence_cycle_df_f(:,1 + fluorescence_signal_channel)];
end
clear timestamp_fluorescence;
%}


    % Append entire Cycle to complete data array
    if isempty(data_voltage)
        data_voltage = [timestamp_voltage];
        data_voltage = [data_voltage, data_voltage_cycle(:, 2:end)]; % NB. May result in pairs or even groups of data (e.g. V_m, i_cmd, ...); V_m always acquired on channel 1 (= column 2, after timestamp) by lab convention
    else
        data_voltage = [data_voltage, data_voltage_cycle(:, 2:end)];
    end
    clear timestamp_voltage;

    % Append segmented Cycle to complete data cell
    data_voltage_episodic{end+1} = data_voltage_cycle_episodic; % NB. timestamp is already included for each segment
    %%% This could potentially lead to confusion, but for now this assumes only 1 cycle as above
    %%{
    %if h.experiment.voltageRecording.analysisParameters.cyclesTotal == 1
        data_voltage_episodic = data_voltage_episodic{1}; % arrays are easier to handle
    %end
    %}

    % Old version with channel selection (e.g. can be used to get V_m only, discarding i_cmd)
    %{
    % Append to complete data array
    if isempty(data_voltage)
        data_voltage = timestamp_voltage;
        data_voltage = [data_voltage, data_voltage_cycle(:,1 + voltage_signal_channel)]; % Refer to pvbs_voltagerecording.m; Vm always acquired on channel 1 (= column 2, after timestamp) by lab convention
    else
        data_voltage = [data_voltage, data_voltage_cycle(:,1 + voltage_signal_channel)];
    end
    clear timestamp_voltage;
    %}

    
    % Setting up analysis window
    window_detection_temp =...
        {num2str(window_baseline_start), num2str(window_baseline_end),...
        '1', num2str(window_n),...
        num2str(window_1_start), num2str(window_1_end), num2str(window_1_direction),...
        num2str(window_2_start), num2str(window_2_end), num2str(window_2_direction)};

    % Convert ms to points
    window_baseline_start = str2double(window_detection_temp{1})*data_voltage_samplingrate;
    window_baseline_end = str2double(window_detection_temp{2})*data_voltage_samplingrate;
    if window_baseline_start == 0 % this will happen with input t = 0
        window_baseline_start = 1;
    end
    window_1_start = str2double(window_detection_temp{5})*data_voltage_samplingrate;
    window_1_end = str2double(window_detection_temp{6})*data_voltage_samplingrate;
    window_2_start = str2double(window_detection_temp{8})*data_voltage_samplingrate;
    window_2_end = str2double(window_detection_temp{9})*data_voltage_samplingrate;

    %%{
    % Offset by 1 for starting points
    window_baseline_start = window_baseline_start + 1;
    window_1_start = window_1_start + 1;
    window_2_start = window_2_start + 1;
    %}

    % Arrange into arrays
    window_baseline = [window_baseline_start, window_baseline_end, str2double(window_detection_temp{3})];
    window_detection = [window_1_start, window_1_end, str2double(window_detection_temp{7})];
    if str2double(window_detection_temp{7}) == 2
        window_detection_2 = [window_2_start, window_2_end, str2double(window_detection_temp{10})];
        window_detection = [window_detection; window_detection_2];
    end
    
    % Run analysis from episodic-like processed data - reusing old code
    expIdx = h.ui.cellListDisplay.Value;
    expIdx = expIdx(1); % force single selection
    h.ui.cellListDisplay.Value = expIdx;
    fName = h.exp.fileName{expIdx};
    fPath = h.exp.filePath{expIdx};
    results = oldAnalysisVRec(data_voltage_episodic, [fPath, fName], window_detection, window_baseline, data_voltage_interval);     
    h.exp.data.intrinsicProperties{expIdx} = results.intrinsic_properties{1}; %%% cycle 1
    %h.exp.data.intrinsicPropertiesVRec{expIdx} = data_voltage_episodic;
    h.exp.data.intrinsicPropertiesVRec{expIdx} = data_voltage_cycle_episodic;
    %{
    h.experiment.voltageRecording.intrinsicProperties = results.intrinsic_properties{1}; %%% cycle 1
    h.experiment.voltageRecording.data = data_voltage_episodic;
    %}
    
    % plot em
    %displayParams = h.params.actualParams.intrinsicPropertiesAnalysis;
    %%{
    displayParams = struct();
    displayParams.voltage_signal_channel = voltage_signal_channel;
    displayParams.data_segment_length = data_segment_length;
    displayParams.data_voltage_interval = data_voltage_interval;
    %displayParams.trace_episodic_color = trace_episodic_color;
    displayParams.stepStart = window_1_start;
    displayParams.stepEnd = window_2_end;
    stepLength = window_2_end - window_1_start;
    displayParams.stepLength = stepLength;
    try
        displayMargin = h.params.actualParams.intrinsicPropertiesAnalysis.displayMargin;
    catch ME
        displayMargin = 0.25;
    end
    displayParams.displayStart = window_1_start - displayMargin*stepLength;
    displayParams.displayEnd = window_2_end + displayMargin*stepLength;
    %}
    h = displayIntrinsic(h, data_voltage_cycle_episodic, results, displayParams);
    
    % display intrinsic properties summary
    try
        intrinsicProperties = h.exp.data.intrinsicProperties{expIdx};
        rmpStr = intrinsicProperties.rmp;
        rinStr = intrinsicProperties.r_in;
        sagStr = intrinsicProperties.sag_ratio;
        rmpStr = sprintf('RMP: %.2f %s', rmpStr, '(mV)');
        rinStr = sprintf('R_in: %.2f %s', rinStr, '(MO)');
        sagStr = sprintf('Sag: %.2f', sagStr);
        
        set(h.ui.intrinsicRMP, 'String', rmpStr);
        set(h.ui.intrinsicRin, 'String', rinStr);
        set(h.ui.intrinsicSag, 'String', sagStr);
    catch ME
    end
    
    % temp
    %{
    rmp = intrinsic_properties{1}.rmp;
    r_in = intrinsic_properties{1}.r_in;
    sag = intrinsic_properties{1}.sag_ratio;
    rheobase = intrinsic_properties{1}.rheobase; <- what? not working properly
    i_step_resolution = intrinsic_properties{1}.i_step_resolution;
    %}
    
    % Remove irrelevant fields from results struct
    results_fields = fieldnames(results);
    for idx = 1:numel(results_fields)
        if isnumeric(results.(results_fields{idx}){1})
            if isempty(results.(results_fields{idx}){1})
                results = rmfield(results, results_fields{idx});
            else
            end
        else
        end
    end

    %{
    % Data sampling and processing info
    exp_analysis_parameters.data_voltage_channel = voltage_signal_channel;
    exp_analysis_parameters.data_voltage_interval_ms = data_voltage_interval;
    exp_analysis_parameters.data_voltage_interval_original_ms = data_voltage_interval_original;
    exp_analysis_parameters.data_voltage_samplingrate_kHz = data_voltage_samplingrate;
    exp_analysis_parameters.data_voltage_samplingrate_original_kHz = data_voltage_samplingrate_original;
    exp_analysis_parameters.data_voltage_segment_count = data_segment_count;
    exp_analysis_parameters.data_voltage_segment_length = data_segment_length*data_voltage_interval;
    exp_analysis_parameters.data_voltage_segment_cutoff_first_ms = data_segmentation_cutoff_first*data_voltage_interval;
    exp_analysis_parameters.data_voltage_segment_cutoff_last_ms = data_segmentation_cutoff_last*data_voltage_interval;
    % NB. "original" sampling rate and interval are cycle-specific, 
    %  although should be practically identical for VoltageRecording and also for LineScan if the lines were not re-drawn
    %  note that here they are overwritten according to the last Cycle
    %}

end


function h = intrinsicAnalysis2(h, data_voltage_episodic, flagScalingOverride)
% actually run intrinsic membrane properties analysis and display results
%  mostly recycled from very very old code (which is also why it's in snake_case)
%  needs to cleaned up for performance... this part is really fucked up %%% fixlater

    analysisParameters = h.params.actualParams.intrinsicPropertiesAnalysis;

    % Unit conversion for V_rec (unit for raw numbers: 10 nV for Dagan - PVBS)
    v_rec_gain = analysisParameters.v_rec_gain; % to convert to mV - NB. also useful to know when using ClampFit
    % Unit conversion for i_cmd (unit for raw numbers: 10 nA for Dagan - PVBS)
    i_cmd_gain = analysisParameters.i_cmd_gain; % to convert to pA (10 for nA) - NB. also useful to know when using ClampFit

    if flagScalingOverride % lol
        v_rec_gain = 1;
        i_cmd_gain = 1;
    end
    
    % data processing %%% allow access and edit from main window later
    voltage_signal_channel = analysisParameters.voltage_signal_channel; % V_m acquisition channel, from PVBS
    data_segmentation_cutoff_first = analysisParameters.data_segmentation_cutoff_first; % (ms); discard this length of data at the beginning
    data_segment_length = analysisParameters.data_segment_length; % Sweep duration (ms), synonymous with inter-sweep interval because of absolutely stupid gap-free PVBS
    data_length_unit = analysisParameters.data_length_unit; % (ms); truncate data to a nice multiple of this (e.g. 17078 ms -> 17070 ms)
    data_voltage_samplingrate = analysisParameters.data_voltage_samplingrate; % (kHz); sampling rate, after reduction: (e.g. 10 kHz = 10 points/ms)
    data_voltage_interval = analysisParameters.data_voltage_interval; % (ms)
    
    % correction for phantom (i.e. cosmetic) current offset error produced by PVBS GPIO box
    % this works by subtracting average current at the beginning, thus i_cmd (t = 0) must be 0 during recording!
    i_bsln_correction = analysisParameters.i_bsln_correction; % (0: no, 1: yes) PVBS GPIO box bleedthrough correction
    i_bsln_correction_window = analysisParameters.i_bsln_correction_window; % (ms); this should do
    
    % detection window; for more than 2 windows, manually set them as n*3 arrays (start, end, direction) and pass them onto functions
    window_baseline_start = analysisParameters.window_baseline_start; % (ms); baseline start - this is not for main analysis window, but for intrinsic properties!
    window_baseline_end = analysisParameters.window_baseline_end; % (ms); baseline end
    window_n = analysisParameters.window_n; % number of detection windows (1 or 2)
    window_1_start = analysisParameters.window_1_start; % (ms); detection window 1 start
    window_1_end = analysisParameters.window_1_end; % (ms); detection window 1 end
    window_1_direction = analysisParameters.window_1_direction; % (ms); detection window 1 direction (-1: negative, 0: either, 1: positive; e.g. for peak detection)
    window_2_start = analysisParameters.window_2_start; % (ms); analysis window 2 start
    window_2_end = analysisParameters.window_2_end; % (ms); analysis window 2 end
    window_2_direction = analysisParameters.window_2_direction; % (ms); analysis window 2 direction (-1: negative, 0: either, 1: positive; e.g. for peak detection)
 
    % get data sampling rate from raw data; could also be fetched from metadata, but easier and more straightforward this way
    data_voltage_episodic_firstsweep = data_voltage_episodic(:,:,1);
    data_voltage_interval_original = data_voltage_episodic_firstsweep(2,1) - data_voltage_episodic_firstsweep(1,1); % (ms)
    data_voltage_samplingrate_original = 1/data_voltage_interval_original; % (kHz)
    %h.experiment.voltageRecording.analysisParameters.voltageSamplingRateOriginal = data_voltage_samplingrate_original;
    
    % Setting up analysis window
    window_detection_temp =...
        {num2str(window_baseline_start), num2str(window_baseline_end),...
        '1', num2str(window_n),...
        num2str(window_1_start), num2str(window_1_end), num2str(window_1_direction),...
        num2str(window_2_start), num2str(window_2_end), num2str(window_2_direction)};

    % Convert ms to points
    window_baseline_start = str2double(window_detection_temp{1})*data_voltage_samplingrate;
    window_baseline_end = str2double(window_detection_temp{2})*data_voltage_samplingrate;
    if window_baseline_start == 0 % this will happen with input t = 0
        window_baseline_start = 1;
    end
    window_1_start = str2double(window_detection_temp{5})*data_voltage_samplingrate;
    window_1_end = str2double(window_detection_temp{6})*data_voltage_samplingrate;
    window_2_start = str2double(window_detection_temp{8})*data_voltage_samplingrate;
    window_2_end = str2double(window_detection_temp{9})*data_voltage_samplingrate;

    %%{
    % Offset by 1 for starting points
    window_baseline_start = window_baseline_start + 1;
    window_1_start = window_1_start + 1;
    window_2_start = window_2_start + 1;
    %}

    % Arrange into arrays
    window_baseline = [window_baseline_start, window_baseline_end, str2double(window_detection_temp{3})];
    window_detection = [window_1_start, window_1_end, str2double(window_detection_temp{7})];
    if str2double(window_detection_temp{7}) == 2
        window_detection_2 = [window_2_start, window_2_end, str2double(window_detection_temp{10})];
        window_detection = [window_detection; window_detection_2];
    end
    
    % Run analysis from episodic-like processed data - reusing old code
    expIdx = h.ui.cellListDisplay.Value;
    expIdx = expIdx(1); % force single selection
    h.ui.cellListDisplay.Value = expIdx;
    fName = h.exp.fileName{expIdx};
    fPath = h.exp.filePath{expIdx};
    results = oldAnalysisVRec(data_voltage_episodic, [fPath, fName], window_detection, window_baseline, data_voltage_interval);     
    h.exp.data.intrinsicProperties{expIdx} = results.intrinsic_properties{1}; %%% cycle 1
    h.exp.data.intrinsicPropertiesVRec{expIdx} = data_voltage_episodic;
    %h.exp.data.intrinsicPropertiesVRec{expIdx} = data_voltage_cycle_episodic;
    %{
    h.experiment.voltageRecording.intrinsicProperties = results.intrinsic_properties{1}; %%% cycle 1
    h.experiment.voltageRecording.data = data_voltage_episodic;
    %}
    
    % plot em
    %displayParams = h.params.actualParams.intrinsicPropertiesAnalysis;
    %%{
    displayParams = struct();
    displayParams.voltage_signal_channel = voltage_signal_channel;
    displayParams.data_segment_length = data_segment_length;
    displayParams.data_voltage_interval = data_voltage_interval;
    %displayParams.trace_episodic_color = trace_episodic_color;
    displayParams.stepStart = window_1_start;
    displayParams.stepEnd = window_2_end;
    stepLength = window_2_end - window_1_start;
    displayParams.stepLength = stepLength;
    try
        displayMargin = h.params.actualParams.intrinsicPropertiesAnalysis.displayMargin;
    catch ME
        displayMargin = 0.25;
    end
    displayParams.displayStart = window_1_start - displayMargin*stepLength;
    displayParams.displayEnd = window_2_end + displayMargin*stepLength;
    %}
    h = displayIntrinsic(h, data_voltage_episodic, results, displayParams);
    %h = displayIntrinsic(h, data_voltage_cycle_episodic, results, displayParams);
    
    % display intrinsic properties summary
    try
        intrinsicProperties = h.exp.data.intrinsicProperties{expIdx};
        rmpStr = intrinsicProperties.rmp;
        rinStr = intrinsicProperties.r_in;
        sagStr = intrinsicProperties.sag_ratio;
        rmpStr = sprintf('RMP: %.2f %s', rmpStr, '(mV)');
        rinStr = sprintf('R_in: %.2f %s', rinStr, '(MO)');
        sagStr = sprintf('Sag: %.2f', sagStr);
        
        set(h.ui.intrinsicRMP, 'String', rmpStr);
        set(h.ui.intrinsicRin, 'String', rinStr);
        set(h.ui.intrinsicSag, 'String', sagStr);
    catch ME
    end
    
    % temp
    %{
    rmp = intrinsic_properties{1}.rmp;
    r_in = intrinsic_properties{1}.r_in;
    sag = intrinsic_properties{1}.sag_ratio;
    rheobase = intrinsic_properties{1}.rheobase; <- what? not working properly
    i_step_resolution = intrinsic_properties{1}.i_step_resolution;
    %}
    
    % Remove irrelevant fields from results struct
    results_fields = fieldnames(results);
    for idx = 1:numel(results_fields)
        if isnumeric(results.(results_fields{idx}){1})
            if isempty(results.(results_fields{idx}){1})
                results = rmfield(results, results_fields{idx});
            else
            end
        else
        end
    end

    %{
    % Data sampling and processing info
    exp_analysis_parameters.data_voltage_channel = voltage_signal_channel;
    exp_analysis_parameters.data_voltage_interval_ms = data_voltage_interval;
    exp_analysis_parameters.data_voltage_interval_original_ms = data_voltage_interval_original;
    exp_analysis_parameters.data_voltage_samplingrate_kHz = data_voltage_samplingrate;
    exp_analysis_parameters.data_voltage_samplingrate_original_kHz = data_voltage_samplingrate_original;
    exp_analysis_parameters.data_voltage_segment_count = data_segment_count;
    exp_analysis_parameters.data_voltage_segment_length = data_segment_length*data_voltage_interval;
    exp_analysis_parameters.data_voltage_segment_cutoff_first_ms = data_segmentation_cutoff_first*data_voltage_interval;
    exp_analysis_parameters.data_voltage_segment_cutoff_last_ms = data_segmentation_cutoff_last*data_voltage_interval;
    % NB. "original" sampling rate and interval are cycle-specific, 
    %  although should be practically identical for VoltageRecording and also for LineScan if the lines were not re-drawn
    %  note that here they are overwritten according to the last Cycle
    %}

end


function h = displayIntrinsic(h, data_voltage_cycle_episodic, results, displayParams)
% display intrinsic properties

% do this first so all windows can be cleared
try
    axes(h.ui.intrinsicPlot1);
    cla;
catch ME
end
try
    axes(h.ui.intrinsicPlot2);
    cla;
catch ME
end
try
    axes(h.ui.intrinsicPlot3);
    cla;
catch ME
end

currentExperiment = h.ui.cellListDisplay.Value;
currentExperiment = currentExperiment(1); % force single selection
h.ui.cellListDisplay.Value = currentExperiment;
voltage_signal_channel = displayParams.voltage_signal_channel;
data_segment_length = displayParams.data_segment_length;
data_voltage_interval = displayParams.data_voltage_interval;
%trace_episodic_color = displayParams.trace_episodic_color;

% Plot representative traces
axes(h.ui.intrinsicPlot1);
displayWindow = h.ui.intrinsicPlot1;
hold on;
% improve aesthetics and also how "hold on" is repeated for every sweep
% just plot the first and the 2*rheo for now
%for idx = 1:data_segment_count
%for idx = [1, results.intrinsic_properties{1}.rheobase_x2_sweep]
for idx = [1, results.intrinsic_properties{1}.rheobase_sweep]
    %plot(data_voltage_cycle_episodic(:,1,idx), data_voltage_cycle_episodic(:,1+voltage_signal_channel,idx), 'parent', displayWindow, 'color', [0.5, 0.5, 0.5]); % trace_episodic_color was for this
    plot(data_voltage_cycle_episodic(:,1,idx), data_voltage_cycle_episodic(:,1+voltage_signal_channel,idx), 'parent', h.ui.intrinsicPlot1, 'color', [0.5, 0.5, 0.5]); % trace_episodic_color was for this
end
%set(GUIHandles.UIElements.repTrace, 'YLim', [-120, 40], 'XLim', [0, size(data_voltage_cycle_episodic, 1)]);
%set(h.ui.intrinsicPlot1, 'XLim', [0, data_segment_length * data_voltage_interval]);
set(h.ui.intrinsicPlot1, 'XLim', [displayParams.displayStart, displayParams.displayEnd]*data_voltage_interval);
xlabel('t (s)'); xticks(displayParams.stepStart*data_voltage_interval:500:displayParams.stepStart*data_voltage_interval+100000); xticklabels(0:0.5:1000); % x ticks in 0.5 s up to 1000 s
clear idx;
hold off;
%%{
%xlabel('t (ms)'); xticks(0:10:1000000); xticklabels(0:10:1000000); % x ticks in 10 ms up to 1000000 ms
%xlabel('t (ms)'); xticks(0:100:1000000); xticklabels(0:100:1000000); % x ticks in 100 ms up to 1000000 ms
%xlabel('t (s)'); xticks(0:500:1000000); xticklabels(0:0.5:1000); % x ticks in 0.5 s up to 1000 s
%xlabel('t (s)'); xticks(0:1000:1000000); xticklabels(0:1:1000); % x ticks in 1 s up to 1000 s
%xlabel('t (s)'); xticks(0:10000:1000000); xticklabels(0:10:1000); % x ticks in 10 s up to 1000 s
%xlabel('t (ms)'); xticks(0:500:1000000); xticklabels(0:500:1000000); % x ticks in 500 ms up to 1000000 ms
ylabel('V_m (mV)');
yticks(-1000:10:1000);
set(gca, 'xminortick', 'on', 'yminortick', 'on');
clear trace_episodic_color;
%}
h.ui.intrinsicPlot1 = displayWindow;

% Print out results %%%%%%%
%{
    intrinsicProperties_output = sprintf('RMP: %.1f (mV)\nR_in: %.1f (MO)\nSag: %.3f',...
    results.intrinsic_properties{1}.rmp, results.intrinsic_properties{1}.r_in, results.intrinsic_properties{1}.sag_ratio);
    set(h.uiElements.intrinsicPropertiesDisplay, 'String', intrinsicProperties_output, 'horizontalalignment', 'left');
%}

% Plot i-V
try
    axes(h.ui.intrinsicPlot2);
    displayWindow = h.ui.intrinsicPlot2;
    %plot(results.intrinsic_properties{1}.i_v(:, 1), results.intrinsic_properties{1}.i_v(:, 2), 'parent', displayWindow, 'color', 'k');
    plot(results.intrinsic_properties{1}.i_v(:, 1), results.intrinsic_properties{1}.i_v(:, 2), 'parent', h.ui.intrinsicPlot2, 'color', 'k');
    %%{
    xlabel('i (pA)'); %xticks(-10000:200:10000); % x ticks in 200 pA up to 10 nA
    ylabel('dV (mV)'); %yticks(-100:10:100); % y ticks in 10 mV up to 100 mV
    set(gca, 'xminortick', 'on', 'yminortick', 'on');
    % add horizontal and vertical lines at 0
    xline(0, '--', 'color', [0.5, 0.5, 0.5]);
    yline(0, '--', 'color', [0.5, 0.5, 0.5]);
    %}
    h.ui.intrinsicPlot2 = displayWindow;
catch mexciV
    mexciV;
end

% Plot f-i
try
    axes(h.ui.intrinsicPlot3);
    displayWindow = h.ui.intrinsicPlot3;
    %plot(results.intrinsic_properties{1}.f_i(:, 1), results.intrinsic_properties{1}.f_i(:, 2), 'parent', displayWindow, 'color', 'k');
    plot(results.intrinsic_properties{1}.f_i(:, 1), results.intrinsic_properties{1}.f_i(:, 2), 'parent', h.ui.intrinsicPlot3, 'color', 'k');
    %%{
    xlabel('i (pA)'); %xticks(-10000:200:10000); % x ticks in 200 pA up to 10 nA
    ylabel('f (Hz)'); %yticks(0:20:1000); % y ticks in 20 Hz up to 1000 Hz
    set(gca, 'xminortick', 'on', 'yminortick', 'on');
    %}
    h.ui.intrinsicPlot3 = displayWindow;
catch mexcFi
    mexcFi;
end

end


function h = displayIntrinsic2(h, data_voltage_cycle_episodic, resultsIntrinsicProperties, expIdx, displayParams)
% display intrinsic properties - 2

% do this first so all windows can be cleared
try
    axes(h.ui.intrinsicPlot1);
    cla;
catch ME
end
try
    axes(h.ui.intrinsicPlot2);
    cla;
catch ME
end
try
    axes(h.ui.intrinsicPlot3);
    cla;
catch ME
end

data_voltage_cycle_episodic = data_voltage_cycle_episodic{expIdx}; % this is different from displayIntrinsic()
currentExperiment = h.ui.cellListDisplay.Value;
currentExperiment = currentExperiment(1); % force single selection
%h.ui.cellListDisplay.Value = currentExperiment; %%% fixlater ?
voltage_signal_channel = displayParams.voltage_signal_channel;
data_segment_length = displayParams.data_segment_length;
data_voltage_interval = displayParams.data_voltage_interval;
%trace_episodic_color = displayParams.trace_episodic_color;

% Plot representative traces
axes(h.ui.intrinsicPlot1);
displayWindow = h.ui.intrinsicPlot1;
hold on;

% improve aesthetics and also how "hold on" is repeated for every sweep
% just plot the first and the 2*rheo for now
%for idx = 1:data_segment_count
for idx = [1, resultsIntrinsicProperties{expIdx}.rheobase_x2_sweep]
%for idx = [1, resultsIntrinsicProperties{expIdx}.rheobase_sweep]
    %plot(data_voltage_cycle_episodic(:,1,idx), data_voltage_cycle_episodic(:,1+voltage_signal_channel,idx), 'parent', displayWindow, 'color', [0.5, 0.5, 0.5]); % trace_episodic_color was for this
    plot(data_voltage_cycle_episodic(:,1,idx), data_voltage_cycle_episodic(:,1+voltage_signal_channel,idx), 'parent', h.ui.intrinsicPlot1, 'color', [0.5, 0.5, 0.5]); % trace_episodic_color was for this
end
%set(GUIHandles.UIElements.repTrace, 'YLim', [-120, 40], 'XLim', [0, size(data_voltage_cycle_episodic, 1)]);
%set(h.ui.intrinsicPlot1, 'XLim', [0, data_segment_length * data_voltage_interval]);
%set(h.ui.intrinsicPlot1, 'XLim', [0, data_segment_length]);
set(h.ui.intrinsicPlot1, 'XLim', [displayParams.displayStart, displayParams.displayEnd]);
xlabel('t (s)'); xticks(displayParams.stepStart:500:displayParams.stepStart+100000); xticklabels(0:0.5:1000); % x ticks in 0.5 s up to 1000 s

clear idx;
hold off;
%%{
%xlabel('t (ms)'); xticks(0:10:1000000); xticklabels(0:10:1000000); % x ticks in 10 ms up to 1000000 ms
%xlabel('t (ms)'); xticks(0:100:1000000); xticklabels(0:100:1000000); % x ticks in 100 ms up to 1000000 ms
%xlabel('t (s)'); xticks(0:500:1000000); xticklabels(0:0.5:1000); % x ticks in 0.5 s up to 1000 s
%%xlabel('t (s)'); xticks(0:1000:1000000); xticklabels(0:1:1000); % x ticks in 1 s up to 1000 s
%xlabel('t (s)'); xticks(0:10000:1000000); xticklabels(0:10:1000); % x ticks in 10 s up to 1000 s
%xlabel('t (ms)'); xticks(0:500:1000000); xticklabels(0:500:1000000); % x ticks in 500 ms up to 1000000 ms
ylabel('V_m (mV)');
yticks(-1000:10:1000);
clear trace_episodic_color;
%}
h.ui.intrinsicPlot1 = displayWindow;

% Print out results %%%%%%%
%{
    intrinsicProperties_output = sprintf('RMP: %.1f (mV)\nR_in: %.1f (MO)\nSag: %.3f',...
    results.intrinsic_properties{1}.rmp, results.intrinsic_properties{1}.r_in, results.intrinsic_properties{1}.sag_ratio);
    set(h.uiElements.intrinsicPropertiesDisplay, 'String', intrinsicProperties_output, 'horizontalalignment', 'left');
%}

% Plot i-V
try
    axes(h.ui.intrinsicPlot2);
    displayWindow = h.ui.intrinsicPlot2;
    %plot(results.intrinsic_properties{1}.i_v(:, 1), results.intrinsic_properties{1}.i_v(:, 2), 'parent', displayWindow, 'color', 'k');
    plot(resultsIntrinsicProperties{expIdx}.i_v(:, 1), resultsIntrinsicProperties{expIdx}.i_v(:, 2), 'parent', h.ui.intrinsicPlot2, 'color', 'k');
    %%{
    xlabel('i (pA)'); %xticks(-10000:200:10000); % x ticks in 200 pA up to 10 nA
    ylabel('dV (mV)'); %yticks(-100:10:100); % y ticks in 10 mV up to 100 mV
    set(gca, 'xminortick', 'on', 'yminortick', 'on');
    % add horizontal and vertical lines at 0
    xline(0, '--', 'color', [0.5, 0.5, 0.5]);
    yline(0, '--', 'color', [0.5, 0.5, 0.5]);
    %}
    h.ui.intrinsicPlot2 = displayWindow;
catch mexciV
    mexciV;
end

% Plot f-i
try
    axes(h.ui.intrinsicPlot3);
    displayWindow = h.ui.intrinsicPlot3;
    %plot(results.intrinsic_properties{1}.f_i(:, 1), results.intrinsic_properties{1}.f_i(:, 2), 'parent', displayWindow, 'color', 'k');
    plot(resultsIntrinsicProperties{expIdx}.f_i(:, 1), resultsIntrinsicProperties{expIdx}.f_i(:, 2), 'parent', h.ui.intrinsicPlot3, 'color', 'k');
    %%{
    xlabel('i (pA)'); %xticks(-10000:200:10000); % x ticks in 200 pA up to 10 nA
    ylabel('f (Hz)'); %yticks(0:10:1000); % y ticks in 10 Hz up to 1000 Hz
    set(gca, 'xminortick', 'on', 'yminortick', 'on');
    %}
    h.ui.intrinsicPlot3 = displayWindow;
catch mexcFi
    mexcFi;
end

end


function intrinsicUseCurrent(src, ~)
% run intrinsic analysis on the current VRec (has to be stupid gap-free, not episodic)

set(src, 'enable', 'off');
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    set(src, 'enable', 'on');
    return
end
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;

tic;
fprintf('Analyzing intrinsic properties... ');

data_voltage_original = h.exp.data.VRec{expIdx};
if iscell(data_voltage_original)
    if length(data_voltage_original) == 1
        data_voltage_original = data_voltage_original{1};
    else
        set(src, 'enable', 'on');
        error('Error: data has to be in single-sweep, gap-free format');
    end
else % let go, use the force
end

try
    fName = h.exp.fileName{expIdx};
    fPath = h.exp.filePath{expIdx};
    fExt = fName(end - 3:end);
    if strcmp(fExt, '.xml')
        isCSV = 0;
    elseif strcmp(fExt, '.csv')
        isCSV = 1;
    else
        elapsedTime = toc;
        set(src, 'enable', 'on');
        error('Error: Invalid file type');
    end
       
    % check file type
    if isCSV
        voltageRecordingMetadata = [];
        h.exp.data.intrinsicPropertiesVRecMetadata{expIdx} = voltageRecordingMetadata;
        h.exp.data.intrinsicProperties{expIdx}.fileName = fName;
        h.exp.data.intrinsicProperties{expIdx}.filePath = fPath;
    else
        [voltageRecordingMetadata] = xml2struct_pvbs([fPath, fName]); % load metadata from xml using modified xml2struct
        h.exp.data.intrinsicPropertiesVRecMetadata{expIdx} = voltageRecordingMetadata;
        h.exp.data.intrinsicProperties{expIdx}.fileName = fName;
        h.exp.data.intrinsicProperties{expIdx}.filePath = fPath;
    end
    
    fileNameStr = [fName, ' (', fPath, ')'];
    h.exp.data.intrinsicPropertiesFileName{expIdx} = fileNameStr;
    set(h.ui.intrinsicFileName, 'string', fileNameStr);
    
    h = intrinsicAnalysis(h, data_voltage_original, 1);
    guidata(src, h);
    
    elapsedTime = toc;
    fprintf('\n Analysis complete. (elapsed time: %.2f s)\n\n', elapsedTime);
    
catch ME
    elapsedTime = toc;
    set(src, 'enable', 'on');
    error('Analysis parameters incompatible with data shape');
end

set(src, 'enable', 'on');

end


function intrinsicReanalyze(src, ~)
% redo intrinsic properties analysis with available VRec (not the VRec on main display, but for intrinsic analysis)

set(src, 'enable', 'off');
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    set(src, 'enable', 'on');
    return
end
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;

tic;
fprintf('Analyzing intrinsic properties... ');

data_voltage_episodic = h.exp.data.intrinsicPropertiesVRec{expIdx};

if isempty(data_voltage_episodic)
    set(src, 'enable', 'on');
    error('Error: data not present, load data to analyze');
end

if iscell(data_voltage_episodic)
    if length(data_voltage_episodic) == 1
        data_voltage_episodic = data_voltage_episodic{1};
    else
        set(src, 'enable', 'on');
        error('Error: data has to be in single-sweep, gap-free format');
    end
else % let go, use the force
end

try
    h = intrinsicAnalysis2(h, data_voltage_episodic, 1);
    elapsedTime = toc;
    fprintf('\n Analysis complete. (elapsed time: %.2f s)\n\n', elapsedTime);
    guidata(src, h);
catch ME
    elapsedTime = toc;
    set(src, 'enable', 'on');
    error('Error: analysis parameters incompatible with data shape');
end

set(src, 'enable', 'on');

end


function loadIntrinsicOptions(src, ~)
% options for intrinsic properties analysis

% load
h = guidata(src);
win1 = src.Parent;
srcButton = src;
set(srcButton, 'enable', 'off');

% load parameters
analysisParameters = h.params.actualParams.intrinsicPropertiesAnalysis;

% options
optionsWin = figure('Name', 'Intrinsic Properties Analysis Options', 'NumberTitle', 'off', 'MenuBar', 'none', 'Units', 'Normalized', 'Position', [0.2, 0.4, 0.25, 0.4], 'resize', 'off', 'DeleteFcn', @winClosed); % use CloseRequestFcn?
oWin.segmentText = uicontrol('Parent', optionsWin, 'Style', 'text', 'fontweight', 'bold', 'string', 'Gap-free to episodic format', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.9, 0.9, 0.05]);
oWin.segmentLengthText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Segment length:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.825, 0.4, 0.05]);
oWin.segmentLengthInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.data_segment_length), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.835, 0.125, 0.05], 'callback', @lazyIntrinsicParamUpdate);
oWin.segmentLengthUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.825, 0.1, 0.05]);
oWin.segmentOffsetText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Initial offset:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.825, 0.4, 0.05]);
oWin.segmentOffsetInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.data_segmentation_cutoff_first), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.835, 0.125, 0.05], 'callback', @lazyIntrinsicParamUpdate);
oWin.segmentOffsetUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.825, 0.1, 0.05]);

oWin.baselineText = uicontrol('Parent', optionsWin, 'Style', 'text', 'fontweight', 'bold', 'string', 'Baseline (at RMP)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.725, 0.9, 0.05]);
oWin.baselineStartText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Baseline start:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.65, 0.4, 0.05]);
oWin.baselineStartInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.window_baseline_start), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.66, 0.125, 0.05], 'callback', @lazyIntrinsicParamUpdate);
oWin.baselineStartUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.65, 0.1, 0.05]);
oWin.baselineEndText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Baseline end:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.65, 0.4, 0.05]);
oWin.baselineEndInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.window_baseline_end), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.66, 0.125, 0.05], 'callback', @lazyIntrinsicParamUpdate);
oWin.baselineEndUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.65, 0.1, 0.05]);

oWin.windowsText = uicontrol('Parent', optionsWin, 'Style', 'text', 'fontweight', 'bold', 'string', 'Analysis windows (1: transient, 2: steady-state)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.025, 0.55, 0.9, 0.05]);
oWin.window1StartText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Window 1 start:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.475, 0.4, 0.05]);
oWin.window1StartInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.window_1_start), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.485, 0.125, 0.05], 'callback', @lazyIntrinsicParamUpdate);
oWin.window1StartUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.475, 0.1, 0.05]);
oWin.window1EndText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Window 1 end:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.475, 0.4, 0.05]);
oWin.window1EndInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.window_1_end), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.485, 0.125, 0.05], 'callback', @lazyIntrinsicParamUpdate);
oWin.window1EndUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.475, 0.1, 0.05]);

oWin.window2StartText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Window 2 start:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.4, 0.4, 0.05]);
oWin.window2StartInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.window_2_start), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.405, 0.125, 0.05], 'callback', @lazyIntrinsicParamUpdate);
oWin.window2StartUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.4, 0.1, 0.05]);
oWin.window2EndText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'Window 2 end:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.55, 0.4, 0.4, 0.05]);
oWin.window2EndInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.window_2_end), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.75, 0.405, 0.125, 0.05], 'callback', @lazyIntrinsicParamUpdate);
oWin.window2EndUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.9, 0.4, 0.1, 0.05]);

oWin.stepLengthText = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', 'i step Length:', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.05, 0.325, 0.4, 0.05]);
oWin.stepLengthInput = uicontrol('Parent', optionsWin, 'Style', 'edit', 'string', num2str(analysisParameters.window_2_end - analysisParameters.window_1_start), 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.25, 0.335, 0.125, 0.05], 'enable', 'off');
oWin.stepLengthUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '(ms)', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.4, 0.325, 0.1, 0.05]);
oWin.stepLengthUnit = uicontrol('Parent', optionsWin, 'Style', 'text', 'string', '[ = (Win 2 end) - (Win 1 start) ]', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.5, 0.325, 0.4, 0.05]);

oWin.resetButton = uicontrol('Parent', optionsWin, 'Style', 'pushbutton', 'string', 'Reset to defaults', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.425, 0.05, 0.25, 0.075], 'callback', @resetIntrinsicOptions, 'interruptible', 'off');
oWin.saveButton = uicontrol('Parent', optionsWin, 'Style', 'pushbutton', 'string', 'Save', 'horizontalalignment', 'left', 'Units', 'normalized', 'Position', [0.7, 0.05, 0.25, 0.075], 'callback', @saveIntrinsicOptions, 'interruptible', 'off');

oWinSegmentLength = oWin.segmentLengthInput.String;
oWinOffset = oWin.segmentOffsetInput.String;
oWinB1 = oWin.baselineStartInput.String;
oWinB2 = oWin.baselineEndInput.String;
oWinW11 = oWin.window1StartInput.String;
oWinW12 = oWin.window1EndInput.String;
oWinW21 = oWin.window2StartInput.String;
oWinW22 = oWin.window2EndInput.String;

oWinSegmentLength = str2num(oWinSegmentLength);
oWinOffset = str2num(oWinOffset);
oWinB1 = str2num(oWinB1);
oWinB2 = str2num(oWinB2);
oWinW11 = str2num(oWinW11);
oWinW12 = str2num(oWinW12);
oWinW21 = str2num(oWinW21);
oWinW22 = str2num(oWinW22);

    function winClosed(src, ~)
        set(srcButton, 'enable', 'on');
        %guidata(srcButton, h); % don't save when closed without using the save button
    end

    function lazyIntrinsicParamUpdate(src, ~)
        oWinSegmentLength = oWin.segmentLengthInput.String;
        oWinOffset = oWin.segmentOffsetInput.String;
        oWinB1 = oWin.baselineStartInput.String;
        oWinB2 = oWin.baselineEndInput.String;
        oWinW11 = oWin.window1StartInput.String;
        oWinW12 = oWin.window1EndInput.String;
        oWinW21 = oWin.window2StartInput.String;
        oWinW22 = oWin.window2EndInput.String;
        
        oWinSegmentLength = str2num(oWinSegmentLength);
        oWinOffset = str2num(oWinOffset);
        oWinB1 = str2num(oWinB1);
        oWinB2 = str2num(oWinB2);
        oWinW11 = str2num(oWinW11);
        oWinW12 = str2num(oWinW12);
        oWinW21 = str2num(oWinW21);
        oWinW22 = str2num(oWinW22);
        
        oWinStepLength = oWinW22 - oWinW11;
        oWin.stepLengthInput.String = num2str(oWinStepLength);
        
        %{
        h.params.actualParams.intrinsicPropertiesAnalysis.data_segment_length = oWinSegmentLength;
        h.params.actualParams.intrinsicPropertiesAnalysis.data_segmentation_cutoff_first = oWinOffset;
        h.params.actualParams.intrinsicPropertiesAnalysis.window_baseline_start = oWinB1;
        h.params.actualParams.intrinsicPropertiesAnalysis.window_baseline_end = oWinB2;
        h.params.actualParams.intrinsicPropertiesAnalysis.window_1_start = oWinW11;
        h.params.actualParams.intrinsicPropertiesAnalysis.window_1_end = oWinW12;
        h.params.actualParams.intrinsicPropertiesAnalysis.window_2_start = oWinW21;
        h.params.actualParams.intrinsicPropertiesAnalysis.window_2_end = oWinW22;
        %}
    end

    function resetIntrinsicOptions(src, ~)
        h.params.actualParams.intrinsicPropertiesAnalysis = h.params.defaultParams.intrinsicPropertiesAnalysis;
        intrinsicPropertiesAnalysis = h.params.actualParams.intrinsicPropertiesAnalysis;
        
        oWinSegmentLength = num2str(intrinsicPropertiesAnalysis.data_segment_length);
        oWinOffset = num2str(intrinsicPropertiesAnalysis.data_segmentation_cutoff_first);
        oWinB1 = num2str(intrinsicPropertiesAnalysis.window_baseline_start);
        oWinB2 = num2str(intrinsicPropertiesAnalysis.window_baseline_end);
        oWinW11 = num2str(intrinsicPropertiesAnalysis.window_1_start);
        oWinW12 = num2str(intrinsicPropertiesAnalysis.window_1_end);
        oWinW21 = num2str(intrinsicPropertiesAnalysis.window_2_start);
        oWinW22 = num2str(intrinsicPropertiesAnalysis.window_2_end);
        
        oWin.segmentLengthInput.String = oWinSegmentLength;
        oWin.segmentOffsetInput.String = oWinOffset;
        oWin.baselineStartInput.String = oWinB1;
        oWin.baselineEndInput.String = oWinB2;
        oWin.window1StartInput.String = oWinW11;
        oWin.window1EndInput.String = oWinW12;
        oWin.window2StartInput.String = oWinW21;
        oWin.window2EndInput.String = oWinW22;
        
        oWinStepLength = num2str(intrinsicPropertiesAnalysis.stepLength);
        oWin.stepLengthInput.String = num2str(oWinStepLength);
        
        %guidata(win1, h);
        %close(optionsWin);
        %set(srcButton, 'enable', 'on');
    end

    function saveIntrinsicOptions(src, ~)
        oWinSegmentLength = oWin.segmentLengthInput.String;
        oWinOffset = oWin.segmentOffsetInput.String;
        oWinB1 = oWin.baselineStartInput.String;
        oWinB2 = oWin.baselineEndInput.String;
        oWinW11 = oWin.window1StartInput.String;
        oWinW12 = oWin.window1EndInput.String;
        oWinW21 = oWin.window2StartInput.String;
        oWinW22 = oWin.window2EndInput.String;
        
        oWinSegmentLength = str2num(oWinSegmentLength);
        oWinOffset = str2num(oWinOffset);
        oWinB1 = str2num(oWinB1);
        oWinB2 = str2num(oWinB2);
        oWinW11 = str2num(oWinW11);
        oWinW12 = str2num(oWinW12);
        oWinW21 = str2num(oWinW21);
        oWinW22 = str2num(oWinW22);
        
        oWinStepLength = oWinW22 - oWinW11;
        oWin.stepLengthInput.String = num2str(oWinStepLength);
        
        h.params.actualParams.intrinsicPropertiesAnalysis.data_segment_length = oWinSegmentLength;
        h.params.actualParams.intrinsicPropertiesAnalysis.data_segmentation_cutoff_first = oWinOffset;
        h.params.actualParams.intrinsicPropertiesAnalysis.window_baseline_start = oWinB1;
        h.params.actualParams.intrinsicPropertiesAnalysis.window_baseline_end = oWinB2;
        h.params.actualParams.intrinsicPropertiesAnalysis.window_1_start = oWinW11;
        h.params.actualParams.intrinsicPropertiesAnalysis.window_1_end = oWinW12;
        h.params.actualParams.intrinsicPropertiesAnalysis.window_2_start = oWinW21;
        h.params.actualParams.intrinsicPropertiesAnalysis.window_2_end = oWinW22;
        
        % somewhat hidden
        h.params.actualParams.intrinsicPropertiesAnalysis.stepStart = oWinW11;
        h.params.actualParams.intrinsicPropertiesAnalysis.stepEnd = oWinW22;
        h.params.actualParams.intrinsicPropertiesAnalysis.stepLength = oWinW22 - oWinW11;
        displayMargin = h.params.actualParams.intrinsicPropertiesAnalysis.displayMargin;
        h.params.actualParams.intrinsicPropertiesAnalysis.displayStart = oWinW11 - displayMargin*(oWinW22 - oWinW11);
        h.params.actualParams.intrinsicPropertiesAnalysis.displayEnd = oWinW22 + displayMargin*(oWinW22 - oWinW11);
        
        guidata(win1, h);
        close(optionsWin);
        set(srcButton, 'enable', 'on');
    end

end


function intrinsicPlot1Enlarge(src, ~)

h = guidata(src);

win = src.Parent;
if isempty(h.ui.cellListDisplay.String)
    return
end
currentExperiment = h.ui.cellListDisplay.Value;
currentExperiment = currentExperiment(1); % force single selection
h.ui.cellListDisplay.Value = currentExperiment;
intrinsicProperties = h.exp.data.intrinsicProperties{currentExperiment};
data_voltage_cycle_episodic = h.exp.data.intrinsicPropertiesVRec{currentExperiment};
newWinTitle = h.exp.data.intrinsicPropertiesFileName{currentExperiment};
try
    newWin = figure('name', newWinTitle, 'numbertitle', 'off', 'color', 'w', 'units', 'normalized', 'position', [0.25, 0.25, 0.5, 0.5]);
catch ME
    return
end
newAxes = axes('parent', newWin, 'position', [0.15, 0.15, 0.75, 0.75], 'units', 'normalized');

displayParams = h.params.actualParams.intrinsicPropertiesAnalysis;
voltage_signal_channel = displayParams.voltage_signal_channel;
data_segment_length = displayParams.data_segment_length;
data_voltage_interval = displayParams.data_voltage_interval;

axes(newAxes);
displayWindow = newAxes;
hold on;
rheobase_sweep = intrinsicProperties.rheobase_sweep;
rheobase_x2_sweep = intrinsicProperties.rheobase_x2_sweep;
%for idx = [1, rheobase_x2_sweep]
%for idx = [1, rheobase_sweep]
for idx = [1, rheobase_sweep, rheobase_x2_sweep]
    plot(data_voltage_cycle_episodic(:,1,idx), data_voltage_cycle_episodic(:,1+voltage_signal_channel,idx), 'parent', displayWindow, 'color', [0.5, 0.5, 0.5]); % trace_episodic_color was for this
end
set(displayWindow, 'XLim', [displayParams.displayStart, displayParams.displayEnd]);
xlabel('t (s)'); xticks(displayParams.stepStart:500:displayParams.stepStart+100000); xticklabels(-100:0.5:1000); % x ticks in 0.5 s up to 1000 s
hold off;
%xlabel('t (ms)'); xticks(0:10:1000000); xticklabels(0:10:1000000); % x ticks in 10 ms up to 1000000 ms
%xlabel('t (ms)'); xticks(0:100:1000000); xticklabels(0:100:1000000); % x ticks in 100 ms up to 1000000 ms
%xlabel('t (s)'); xticks(0:500:1000000); xticklabels(0:0.5:1000); % x ticks in 0.5 s up to 1000 s
%xlabel('t (s)'); xticks(0:1000:1000000); xticklabels(0:1:1000); % x ticks in 1 s up to 1000 s
%xlabel('t (s)'); xticks(0:10000:1000000); xticklabels(0:10:1000); % x ticks in 10 s up to 1000 s
%xlabel('t (ms)'); xticks(0:500:1000000); xticklabels(0:500:1000000); % x ticks in 500 ms up to 1000000 ms
ylabel('V_m (mV)');
yticks(-1000:10:1000);
set(displayWindow, 'xminortick', 'on', 'yminortick', 'on');

end


function loadZStack(src, ~)
% load and display z-stack

%tiffColorMapRange = 0.25; % colormap will be scaled up for values below this, and saturated to 1 at this level and above

% load
h = guidata(src);
win = src.Parent;
displayWindow = h.ui.zStackDisplay;
%cla(displayWindow);
currentExperiment = h.ui.cellListDisplay.Value;
currentExperiment = currentExperiment(1); % force single selection
h.ui.cellListDisplay.Value = currentExperiment;

if isempty(h.ui.cellListDisplay.String)
    error('Error: Load experiment(s) first before loading z-stack');
end

% import cell data from a previously saved .mat file
[fName, fPath] = uigetfile({'*.tif; *.tiff; *.png; *.jpg; *.jpeg; *.bmp', 'Z-stack image'});

% check if a file was loaded
if fName ~= 0
    image = imread([fPath, fName]);
    fileNameStr = [fName, ' (', fPath, ')'];
    h.exp.data.zStackFileName{currentExperiment} = fileNameStr;
    set(h.ui.zStackFileName, 'string', fileNameStr);
    %cla(displayWindow);
else
    return
end

% read tiff if applicable %%% why does this override above block?
try
    warning('off','all');
    image = read(Tiff([fPath, fName])); % Tiff() is a built-in function
    warning('on','all');
    istiff = 1; % obsolete now
catch ME
    istiff = 0;
end

% save zstack
h.exp.data.zStack{currentExperiment} = image;

% display
h = displayZStack(h);

% save
%h.ui.zStackDisplay = displayWindow;
guidata(src, h);

end


function h = displayZStack(h)
% display z-stack associtated with current experiment

tiffColorMapRange = 0.25; % colormap will be scaled up for values below this, and saturated to 1 at this level and above

% load
displayWindow = h.ui.zStackDisplay;
cla(displayWindow);
currentExperiment = h.ui.cellListDisplay.Value;
currentExperiment = currentExperiment(1); % force single selection
%h.ui.cellListDisplay.Value = currentExperiment; %%% fixlater?
image = h.exp.data.zStack{currentExperiment};

% pad image into 1:1 aspect ratio
if max(size(size(image))) == 3
    image = image(:, :, 1);
end
sizeX = size(image, 2);
sizeY = size(image, 1);
if sizeX < sizeY
    imageNew = zeros(sizeY, sizeY);
    for i = 1:sizeY
        imageNew(i, 1:sizeX) = image(i, :);
    end
elseif sizeX > sizeY
    imageNew = zeros(sizeX, sizeX);
    for i = 1:sizeY
        imageNew(i, 1:sizeX) = image(i, :);
    end
else
    imageNew = image;
end
image = imageNew;

% plot
imageDisplay = imagesc(image, 'Parent', displayWindow, 'buttondownfcn', @cellOrientation); % cell depth and orientation
set(displayWindow, 'xtick', [], 'ytick', [], 'box', 'on');

% set colormap
%{
if istiff
    grayModified = gray/tiffColorMapRange; % saturating gray colormap at level designated before, if tiff
    grayModified(grayModified > 1) = 1;
    colormap(displayWindow, grayModified);
else
    colormap(displayWindow, gray);
    grayModified = gray;
end
%}
if max(max((image))) > 256 % this should crudely sort out tiff... or suit the intended purpose even better
    grayModified = gray/tiffColorMapRange; % saturating gray colormap at level designated before, if tiff
    grayModified(grayModified > 1) = 1;
    colormap(displayWindow, grayModified);
else
    colormap(displayWindow, gray);
    grayModified = gray;
end

% save
h.ui.zStackDisplay = displayWindow;

end


function loadSingleScan(src, ~)
% load and display single-scan

%tiffColorMapRange = 0.2; % colormap will be scaled up for values below this, and saturated to 1 at this level and above

% load
h = guidata(src);
win = src.Parent;
displayWindow = h.ui.singleScanDisplay;
%cla(displayWindow);
currentExperiment = h.ui.cellListDisplay.Value;
currentExperiment = currentExperiment(1); % force single selection
h.ui.cellListDisplay.Value = currentExperiment;

if isempty(h.ui.cellListDisplay.String)
    error('Error: Load experiment(s) first before loading single-scan');
end

% import cell data from a previously saved .mat file
[fName, fPath] = uigetfile({'*.tif; *.tiff; *.png; *.jpg; *.jpeg; *.bmp', 'Single-scan image'});

% check if a file was loaded
if fName ~= 0
    image = imread([fPath, fName]);
    fileNameStr = [fName, ' (', fPath, ')'];
    h.exp.data.singleScanFileName{currentExperiment} = fileNameStr;
    set(h.ui.singleScanFileName, 'string', fileNameStr);
    cla(displayWindow);
else
    return
end

% read tiff if applicable %%% why does this override above block?
try
    warning('off','all');
    image = read(Tiff([fPath, fName])); % Tiff() is a built-in function
    warning('on','all');
    istiff = 1; % obsolete now
catch ME
    istiff = 0;
end

% save singlescan
h.exp.data.singleScan{currentExperiment} = image;

% display
h = displaySingleScan(h);

% save
%h.ui.singleScanDisplay = displayWindow;
guidata(src, h);

end


function h = displaySingleScan(h)
% display single-scan associtated with current experiment

tiffColorMapRange = 0.2; % colormap will be scaled up for values below this, and saturated to 1 at this level and above

% load
displayWindow = h.ui.singleScanDisplay;
cla(displayWindow);
currentExperiment = h.ui.cellListDisplay.Value;
currentExperiment = currentExperiment(1); % force single selection
%h.ui.cellListDisplay.Value = currentExperiment; %%% fixlater ?
image = h.exp.data.singleScan{currentExperiment};

% pad image into 1:1 aspect ratio
if max(size(size(image))) == 3
    image = image(:, :, 1);
end
sizeX = size(image, 2);
sizeY = size(image, 1);
if sizeX < sizeY
    imageNew = zeros(sizeY, sizeY);
    for i = 1:sizeY
        imageNew(i, 1:sizeX) = image(i, :);
    end
elseif sizeX > sizeY
    imageNew = zeros(sizeX, sizeX);
    for i = 1:sizeY
        imageNew(i, 1:sizeX) = image(i, :);
    end
else
    imageNew = image;
end
image = imageNew;

% plot
imageDisplay = imagesc(image, 'Parent', displayWindow, 'buttondownfcn', @cellOrientation); % cell depth and orientation
set(displayWindow, 'xtick', [], 'ytick', [], 'box', 'on');

% set colormap
%{
if istiff
    grayModified = gray/tiffColorMapRange; % saturating gray colormap at level designated before, if tiff
    grayModified(grayModified > 1) = 1;
    colormap(displayWindow, grayModified);
else
    colormap(displayWindow, gray);
    grayModified = gray;
end
%}
%{
if max(max((image))) > 256 % this should crudely sort out tiff
    grayModified = gray/tiffColorMapRange; % saturating gray colormap at level designated before, if tiff
    grayModified(grayModified > 1) = 1;
    colormap(displayWindow, grayModified);
else
    colormap(displayWindow, gray);
    grayModified = gray;
end
%}
grayModified = gray/tiffColorMapRange; % just do it for singlescans
grayModified(grayModified > 1) = 1;
colormap(displayWindow, grayModified);

% save
h.ui.singleScanDisplay = displayWindow;

end


function [image, displayWindow] = loadSingleScan2(displayWindow, fPath, fName)
% load and display single-scan from specified fPath and fName

tiffColorMapRange = 0.2; % colormap will be scaled up for values below this, and saturated to 1 at this level and above

% load
h = guidata(displayWindow);
win = displayWindow.Parent;
%displayWindow = h.ui.singleScanDisplay;
%cla(displayWindow);

% check if a file was loaded
if fName ~= 0
    image = imread([fPath, fName]);
    %set(h.ui.singleScanFileName, 'string', [fName, ' (', fPath, ')']);
    cla(displayWindow);
else
    return
end

% read tiff if applicable %%% why does this override above block?
try
    warning('off','all');
    image = read(Tiff([fPath, fName])); % Tiff() is a built-in function
    warning('on','all');
    istiff = 1;
catch ME
    istiff = 0;
end

% pad image into 1:1 aspect ratio
if max(size(size(image))) == 3
    image = image(:, :, 1);
end
sizeX = size(image, 2);
sizeY = size(image, 1);
if sizeX < sizeY
    imageNew = zeros(sizeY, sizeY);
    for i = 1:sizeY
        imageNew(i, 1:sizeX) = image(i, :);
    end
elseif sizeX > sizeY
    imageNew = zeros(sizeX, sizeX);
    for i = 1:sizeY
        imageNew(i, 1:sizeX) = image(i, :);
    end
else
    imageNew = image;
end
image = imageNew;

% plot
imageDisplay = imagesc(image, 'Parent', displayWindow);
set(displayWindow, 'xtick', [], 'ytick', [], 'box', 'on');

% set colormap
if istiff
    grayModified = gray/tiffColorMapRange; % saturating gray colormap at level designated before, if tiff
    grayModified(grayModified > 1) = 1;
    colormap(displayWindow, grayModified);
else
    colormap(displayWindow, gray);
    grayModified = gray;
end

% save
%h.ui.singleScanDisplay = displayWindow;
%guidata(displayWindow, h);

end


function intrinsicDel(src, ~)
% delete loaded intrinsic properties

% load
h = guidata(src);
win = src.Parent;
displayWindow1 = h.ui.intrinsicPlot1;
displayWindow2 = h.ui.intrinsicPlot2;
displayWindow3 = h.ui.intrinsicPlot3;
fileName = h.ui.intrinsicFileName;

% clear
experimentNumber = h.ui.cellListDisplay.Value; % current experiment
experimentNumber = experimentNumber(1); % force single selection
h.ui.cellListDisplay.Value = experimentNumber;
h.exp.data.intrinsicProperties{experimentNumber} = struct;
h.exp.data.intrinsicPropertiesVRec{experimentNumber} = {};
h.exp.data.intrinsicPropertiesVRecMetadata{experimentNumber} = struct;
axes(displayWindow1);
cla(displayWindow1);
set(displayWindow1, 'xtick', [], 'ytick', [], 'box', 'on');
xlabel('t (ms)'); ylabel('V_m (mV)');
axes(displayWindow2);
cla(displayWindow2);
set(displayWindow2, 'xtick', [], 'ytick', [], 'box', 'off');
xlabel('i (pA)'); ylabel('dV (mV)');
axes(displayWindow3);
cla(displayWindow3);
set(displayWindow3, 'xtick', [], 'ytick', [], 'box', 'off');
xlabel('i (pA)'); ylabel('f (Hz)');
fileName.String = '(N/A)';
h.ui.intrinsicRMP.String = '';
h.ui.intrinsicRin.String = '';
h.ui.intrinsicSag.String = '';


% save
h.ui.intrinsicPlot1 = displayWindow1;
h.ui.intrinsicPlot2 = displayWindow2;
h.ui.intrinsicPlot3 = displayWindow3;
h.ui.intrinsicFileName = fileName;
guidata(src, h);

end


function zStackEnlarge(src, ~)
% open a new window to display loaded z-stack

tiffColorMapRange = 0.25; % colormap will be scaled up for values below this, and saturated to 1 at this level and above

% load
h = guidata(src);
win = src.Parent;
if isempty(h.ui.cellListDisplay.String)
    return
end
currentExperiment = h.ui.cellListDisplay.Value;
currentExperiment = currentExperiment(1); % force single selection
h.ui.cellListDisplay.Value = currentExperiment;
image = h.exp.data.zStack{currentExperiment};
imageTitle = h.exp.data.zStackFileName{currentExperiment};

% open new window
try
    newWin = figure('name', imageTitle, 'numbertitle', 'off', 'units', 'normalized', 'position', [0.4, 0.25, 0.27, 0.48]);
catch ME
    return
end
newAxes = axes('parent', newWin, 'position', [0, 0, 1, 1], 'units', 'normalized');

% plot
imageDisplay = imagesc(image, 'Parent', newAxes);
set(newAxes, 'xtick', [], 'ytick', [], 'box', 'on');

% set colormap
%{
if istiff
    grayModified = gray/tiffColorMapRange; % saturating gray colormap at level designated before, if tiff
    grayModified(grayModified > 1) = 1;
    colormap(displayWindow, grayModified);
else
    colormap(displayWindow, gray);
    grayModified = gray;
end
%}
if max(max((image))) > 256 % this should crudely sort out tiff... or suit the intended purpose even better
    grayModified = gray/tiffColorMapRange; % saturating gray colormap at level designated before, if tiff
    grayModified(grayModified > 1) = 1;
    colormap(newAxes, grayModified);
else
    colormap(newAxes, gray);
    grayModified = gray;
end

end


function singleScanEnlarge(src, ~)
% open a new window to display loaded single-scan

tiffColorMapRange = 0.25; % colormap will be scaled up for values below this, and saturated to 1 at this level and above

% load
h = guidata(src);
win = src.Parent;
if isempty(h.ui.cellListDisplay.String)
    return
end
currentExperiment = h.ui.cellListDisplay.Value;
currentExperiment = currentExperiment(1); % force single selection
h.ui.cellListDisplay.Value = currentExperiment;
image = h.exp.data.singleScan{currentExperiment};
imageTitle = h.exp.data.singleScanFileName{currentExperiment};

% open new window
try
    newWin = figure('name', imageTitle, 'numbertitle', 'off', 'units', 'normalized', 'position', [0.4, 0.25, 0.27, 0.48]);
catch ME
    return
end
newAxes = axes('parent', newWin, 'position', [0, 0, 1, 1], 'units', 'normalized');

% plot
imageDisplay = imagesc(image, 'Parent', newAxes);
set(newAxes, 'xtick', [], 'ytick', [], 'box', 'on');

% set colormap
%{
if istiff
    grayModified = gray/tiffColorMapRange; % saturating gray colormap at level designated before, if tiff
    grayModified(grayModified > 1) = 1;
    colormap(displayWindow, grayModified);
else
    colormap(displayWindow, gray);
    grayModified = gray;
end
%}
if max(max((image))) > 256 % this should crudely sort out tiff... or suit the intended purpose even better
    grayModified = gray/tiffColorMapRange; % saturating gray colormap at level designated before, if tiff
    grayModified(grayModified > 1) = 1;
    colormap(newAxes, grayModified);
else
    colormap(newAxes, gray);
    grayModified = gray;
end

end


function zStackDel(src, ~)
% delete loaded z-stack

% load
h = guidata(src);
win = src.Parent;
displayWindow = h.ui.zStackDisplay;
fileName = h.ui.zStackFileName;

% clear
experimentNumber = h.ui.cellListDisplay.Value; % current experiment
experimentNumber = experimentNumber(1); % force single selection
h.ui.cellListDisplay.Value = experimentNumber;
h.data.zStack{experimentNumber} = [];
cla(displayWindow);
set(displayWindow, 'xtick', [], 'ytick', [], 'box', 'on', 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8], 'color', [0.95, 0.95, 0.95]);
fileName.String = '(N/A)';

% save
h.ui.zStackDisplay = displayWindow;
h.ui.zStackFileName = fileName;
guidata(src, h);

end


function singleScanDel(src, ~)
% delete loaded single-scan

% load
h = guidata(src);
win = src.Parent;
displayWindow = h.ui.singleScanDisplay;
fileName = h.ui.singleScanFileName;

% clear
experimentNumber = h.ui.cellListDisplay.Value; % current experiment
experimentNumber = experimentNumber(1); % force single selection
h.ui.cellListDisplay.Value = experimentNumber;
h.data.zStack{experimentNumber} = [];
cla(displayWindow);
set(displayWindow, 'xtick', [], 'ytick', [], 'box', 'on', 'xcolor', [0.8, 0.8, 0.8], 'ycolor', [0.8, 0.8, 0.8], 'color', [0.95, 0.95, 0.95]);
fileName.String = '(N/A)';

% save
h.ui.singleScanDisplay = displayWindow;
h.ui.singleScanFileName = fileName;
guidata(src, h);

end


%% Export


function exportTarget1(src, event)
% set export target to option 1

% load
h = guidata(src);

%{
% switch
switch1 = h.ui.exportTarget1.Value;
switch2 = h.ui.exportTarget2.Value;
if switch2 % switch2 was on
    if switch1 % switch1 was pressed
        h.ui.exportTarget2.Value = 0; % turn off switch2
    end
else % switch2 was off (switch1 was on), but switch1 was pressed again
    h.ui.exportTarget1.Value = 1; % keep switch1 on
end
h.params.exportTarget = 1;
%}

% save
guidata(src, h);

end


function exportTarget2(src, event)
% set export target to option 2

% load
h = guidata(src);

%{
% switch
switch1 = h.ui.exportTarget1.Value;
switch2 = h.ui.exportTarget2.Value;
if switch1 % switch1 was on
    if switch2 % switch2 was pressed
        h.ui.exportTarget1.Value = 0; % turn off switch2
    end
else % switch1 was off (switch2 was on), but switch2 was pressed again
    h.ui.exportTarget2.Value = 1; % keep switch2 on
end
h.params.exportTarget = 2;
%}

% save
guidata(src, h);

end


function exportResults1(src, ~)
% export anaylsis results (from all experiments) as .csv

tic;

% default save parameters - could go into settings
defaultSaveFilePrefix = 'pvbs_res_';
defaultSavePath = cd;
defaultSavedVariableName = 'h';

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    error('Error: No experiment file present');
end

% fetch number of experiments and initialize
experimentCount = length(h.ui.cellListDisplay.String);
export = cell(1, experimentCount); % this will be the main cell to be exported

if h.ui.exportTarget1.Value == 0 && h.ui.exportTarget2.Value == 0
    fprintf('Export canceled: No target plot/axis selected for export\n\n');
    return
end
    
% prompt
fprintf('Exporting results... (for ALL experiments)');

if h.ui.exportTarget1.Value % signal 1 / window 1
    targetSignal = 1;
    targetWindow = h.ui.analysisPlot1Menu2.Value - 1; % (sel), win1, win2; hence -1
    switch targetWindow
        case 1 % win 1
            targetAnalysisType = h.ui.analysisType1.Value; % (sel), peak/area/mean, threshold, waveform
        case 2 % win 2
            targetAnalysisType = h.ui.analysisType2.Value; % (sel), peak/area/mean, threshold, waveform
    end
    targetResult = h.ui.analysisPlot1Menu3.Value; % (sel), (results types...)
    targetSort = h.ui.analysisPlot1Menu4.Value; % (sel), swp, grp
    
    % iterate for number of experiments
    for currentExperiment = 1:experimentCount
        try
            export = exportResultsMain(export, h, currentExperiment);
        catch ME
            export{currentExperiment} = [];
        end
    end
    [saveName, savePath] = exportReally(); % great name
    
    % also save experiment file names - fuck it
    saveName2 = saveName;
    saveName2 = saveName2(1:end-4); % shedding extension (.csv)
    saveName2 = saveName2(1:end-2); % shedding "S#" (see within exportReally())
    saveName2 = [saveName2, 'fileNames'];
    saveName2 = [saveName2, '.csv']; % re-appending extension
    writecell(h.exp.fileName, [savePath, saveName2]);
    % also save experiment file paths - fuck it
    saveName3 = saveName;
    saveName3 = saveName3(1:end-4); % shedding extension (.csv)
    saveName3 = saveName3(1:end-2); % shedding "S#" (see within exportReally())
    saveName3 = [saveName3, 'filePaths'];
    saveName3 = [saveName3, '.csv']; % re-appending extension
    writecell(h.exp.filePath, [savePath, saveName3]);
end

if h.ui.exportTarget2.Value % signal 2 / window 2
    targetSignal = 2;
    targetWindow = h.ui.analysisPlot2Menu2.Value - 1; % (sel), win1, win2; hence -1
    switch targetWindow
        case 1 % win 1
            targetAnalysisType = h.ui.analysisType1.Value; % (sel), peak/area/mean, threshold, waveform
        case 2 % win 2
            targetAnalysisType = h.ui.analysisType2.Value; % (sel), peak/area/mean, threshold, waveform
    end
    targetResult = h.ui.analysisPlot2Menu3.Value; % (sel), (results types...)
    targetSort = h.ui.analysisPlot2Menu4.Value; % (sel), swp, grp
    
    % iterate for number of experiments
    for currentExperiment = 1:experimentCount
        try
            export = exportResultsMain(export, h, currentExperiment);
        catch ME
            export{currentExperiment} = [];
        end
    end
    exportReally(); % great name
end

    function export = exportResultsMain(export, h, currentExperiment)
        % current experiment
        resultsToExport = h.results{currentExperiment};
        swpIdx = h.exp.data.sweepIdx{currentExperiment};
        
        switch targetSignal % signal
            case 1 % v/i
                resultsToExport = resultsToExport.VRec;
            case 2 % dff
                resultsToExport = resultsToExport.dff;
        end
        
        switch targetSort % plot by...
            case 2 % by sweep
                resultsToExport = resultsToExport.sweepResults;
                dataX = 1:length(resultsToExport.sweeps); % sweep number
            case 3 % by group
                resultsToExport = resultsToExport.groupResults;
                dataX = 1:length(resultsToExport.groups); % group number
        end
        
        switch targetAnalysisType
            case 2 % peak/area/mean
                switch targetResult % which kind of results
                    case 2
                        resultsToExport = resultsToExport.peak;
                        resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                    case 3
                        resultsToExport = resultsToExport.area;
                        resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                    case 4
                        resultsToExport = resultsToExport.mean;
                        resultsType = 1; % only one here
                    case 5
                        resultsToExport = resultsToExport.timeOfPeak;
                        resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                    case 6
                        resultsToExport = resultsToExport.riseTime;
                        resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                    case 7
                        resultsToExport = resultsToExport.decayTime;
                        resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                    case 8
                        resultsToExport = resultsToExport.riseSlope;
                        resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                    case 9
                        resultsToExport = resultsToExport.decaySlope;
                        resultsType = 3; % 1: neg, 2: abs, 3: pos; column indices %%% switch here for results type later
                    otherwise
                        resultsToExport = [];
                        resultsType = 1; % whatever
                end
            otherwise % other type of analysis - not implemented yet %%%
        end
        
        resultsToExport = resultsToExport(targetWindow, :); % window
        switch targetSort % plot by...
            case 2 % by sweep
                resultsToExportNew = nan(length(resultsToExport), 1); % initialize
                for i = 1:length(resultsToExport)
                    resultsToExportUpdate = resultsToExport{i}; % current sweep/group
                    resultsToExportUpdate = resultsToExportUpdate(resultsType); % relevant element
                    %resultsToExportNew(i) = resultsToExportUpdate; % update
                    swpIdxAbs = swpIdx(i);
                    resultsToExportNew(swpIdxAbs) = resultsToExportUpdate; % update
                end
            case 3 % by group
                resultsToExportNew = nan(swpIdx(length(resultsToExport)), 1); % initialize
                for i = 1:length(resultsToExport)
                    resultsToExportUpdate = resultsToExport{i}; % current sweep/group
                    resultsToExportUpdate = resultsToExportUpdate(resultsType); % relevant element
                    resultsToExportNew(i) = resultsToExportUpdate; % update
                end
        end
        resultsToExport = resultsToExportNew; % update
        resultsToExport = resultsToExport'; % transform to column vector
        export{currentExperiment} = resultsToExport; % update for current experiment
    end

    function [saveName, savePath] = exportReally() %%% fuck it
        
        % convert to cell
        maxLength = 0;
        for i = 1:length(export)
            newLength = nanmax(length(export{i}));
            if newLength > maxLength
                maxLength = newLength;
            end
        end
        
        exportFinal = nan(maxLength, experimentCount); % initialize
        for i = 1:experimentCount
            exportCurrent = export{i};
            for j = 1:length(export{i})
                exportFinal(j, i) = exportCurrent(j);
            end
        end
        
        % set save path and file name
        todayYY = num2str(year(datetime));
        todayYY = todayYY(end-1:end);
        todayMM = sprintf('%02.0f', month(datetime));
        todayDD = sprintf('%02.0f', day(datetime));
        saveNameDate = [todayYY, todayMM, todayDD];
        saveNameCell = h.exp.fileName{1}(1:end-4);
        saveNameCell = [defaultSaveFilePrefix, saveNameCell];
        if length(h.exp.fileName) > 1 % more than 1 experiments in dataset
            expCount = length(h.exp.fileName);
            expCount = num2str(expCount);
            saveNameCellSuffix = ['_N', expCount, '_S', num2str(targetSignal), '_', saveNameDate];
            saveNameCell = [saveNameCell, saveNameCellSuffix];
        else
            saveNameCellSuffix = ['_S', num2str(targetSignal), '_', saveNameDate];
            saveNameCell = [saveNameCell, saveNameCellSuffix];
        end
        %saveName = [saveNameCell, '.mat'];
        saveName = [saveNameCell, '.csv'];
        savePath = [defaultSavePath, '\']; % appending backslash for proper formatting
        
        %{
        % prompt, since it could take some time
        fprintf('Exporting results... (for ALL experiments)');
        %}
        
        % save
        try
            %[actualName, actualPath, isSaved] = uisaveX(exportFinal, [savePath, saveName]);
            writematrix(exportFinal, [savePath, saveName]);
            
            % print results
            %elapsedTime = toc;
            %fprintf('\nSaved as: %s%s (%.1f s) \n\n', actualPath, actualName, elapsedTime);
            %fprintf('\nSaved as: %s%s (%.1f s) \n\n', savePath, saveName, elapsedTime);
            fprintf('\n(Src. %s) Saved as: %s%s', num2str(targetSignal), savePath, saveName);
        catch ME
            elapsedTime = toc;
            fprintf('\nAborted or interrupted.\n');
            return
        end
        
    end

elapsedTime = toc;
fprintf('\n Export complete. (elapsed time: %.2f s)\n\n', elapsedTime);
%fprintf('\n\n');

end


function exportResults2(src, ~)
% export anaylsis results (from all experiments) as .mat

tic;

% default save parameters - could go into settings
defaultSaveFilePrefix = 'pvbs_res_';
defaultSavePath = cd;
defaultSavedVariableName = 'h';

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    error('Error: No experiment file present');
end

export = struct();
export.exp.fileName = h.exp.fileName;
export.exp.filePath = h.exp.filePath;
export.results = h.results;
export.analysis = h.analysis;
export.params.actualParams = h.params.actualParams;

% prompt
fprintf('Exporting results... (for ALL experiments)');
[saveName, savePath] = exportToMat(export);

    function [saveName, savePath] = exportToMat(h)

        structName = getStructName(h);
        function outputName = getStructName(inputStruct)
            outputName = inputname(1);
        end
        
        % set save path and file name
        todayYY = num2str(year(datetime));
        todayYY = todayYY(end-1:end);
        todayMM = sprintf('%02.0f', month(datetime));
        todayDD = sprintf('%02.0f', day(datetime));
        saveNameDate = [todayYY, todayMM, todayDD];
        saveNameCell = h.exp.fileName{1}(1:end-4);
        saveNameCell = [defaultSaveFilePrefix, saveNameCell];
        if length(h.exp.fileName) > 1 % more than 1 experiments in dataset
            expCount = length(h.exp.fileName);
            expCount = num2str(expCount);
            saveNameCellSuffix = ['_N', expCount, '_', saveNameDate];
            saveNameCell = [saveNameCell, saveNameCellSuffix];
        else
            saveNameCellSuffix = ['_', saveNameDate];
            saveNameCell = [saveNameCell, saveNameCellSuffix];
        end
        saveName = [saveNameCell, '.mat'];
        savePath = [defaultSavePath, '\']; % appending backslash for proper formatting
        
        % save
        try
            [actualName, actualPath, isSaved] = uisaveX(structName, [savePath, saveName]);
            
            % print results
            %elapsedTime = toc;
            %fprintf('\nSaved as: %s%s (%.1f s) \n\n', actualPath, actualName, elapsedTime);
            %fprintf('\nSaved as: %s%s (%.1f s) \n\n', savePath, saveName, elapsedTime);
            fprintf('\nSaved as: %s%s', savePath, saveName);
            
        catch ME
            elapsedTime = toc;
            fprintf('\nAborted or interrupted.\n');
            return
        end
        
    end

elapsedTime = toc;
fprintf('\n Export complete. (elapsed time: %.2f s)\n\n', elapsedTime);
%fprintf('\n\n');

end


function exportTraces1(src, ~)
% export traces (from current experiment only) as .csv

tic;

% default save parameters - could go into settings
defaultSaveFilePrefix = 'pvbs_tr_';
defaultSavePath = cd;
defaultSavedVariableName = 'h';

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    error('Error: No experiment file present');
end

% fetch number of experiments and initialize
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
if h.ui.exportTarget1.Value == 0 && h.ui.exportTarget2.Value == 0
    fprintf('Export canceled: No target plot/axis selected for export\n\n');
    return
end
    
% prompt
fprintf('Exporting traces...');

if h.ui.exportTarget1.Value
    targetSignal = 1;
    try
        exportTracesMain(h, expIdx, targetSignal);
    catch ME
        fprintf(sprintf('\n(Src. %s) Aborted.', num2str(targetSignal)));
    end
end

if h.ui.exportTarget2.Value
    targetSignal = 2;
    try
        exportTracesMain(h, expIdx, targetSignal);
    catch ME
        fprintf(sprintf('\n(Src. %s) Aborted.', num2str(targetSignal)));
    end
end

    function exportTracesMain(h, currentExperiment, targetSignal)
        % current experiment
        dataToExport = h.exp.data;
        
        switch targetSignal % signal
            case 1 % v/i
                dataToExport = dataToExport.VRec{currentExperiment};
                timeStampColumnIdx = 1; % %%% fixlater
                dataColumnIdx = 2; % %%% fixlater
            case 2 % dff
                dataToExport = dataToExport.lineScanDFF{currentExperiment};
                timeStampColumnIdx = 1; % %%% fixlater
                dataColumnIdx = 2; % %%% fixlater
        end
        
        numSweeps = length(dataToExport);
        sweepLengths = [];
        for i = 1:numSweeps
            sweepLengths(end + 1) = length(dataToExport{i});
        end
        sweepLengthMax = nanmax(sweepLengths);
        
        dataToExportNew = nan(sweepLengthMax, numSweeps); % initialize
        timeStampToExportNew = nan(sweepLengthMax, numSweeps); % initialize
        for i = 1:numSweeps
            if isempty(dataToExport{i})
                continue % needed for empty sweeps, e.g. for dF/F
            end
            dataToExportUpdate = dataToExport{i}; % current sweep
            timeStampToExportUpdate = dataToExportUpdate(:,timeStampColumnIdx); % must do this first
            dataToExportUpdate = dataToExportUpdate(:,dataColumnIdx); % and do this afterwards
            for j = 1:length(timeStampToExportUpdate)
                timeStampToExportNew(j, i) = timeStampToExportUpdate(j);
            end
            for j = 1:length(dataToExportUpdate)
                dataToExportNew(j, i) = dataToExportUpdate(j);
            end
        end

        % ok to have non-matching lengths of sweeps, so long as they still have the same sampling interval
        %{
        if any(isnan(timeStampToExportNew(:))) % will happen if not all timestamps match
        end
        %}
        
        timeStampFlag = 1; % initialize this way
        for i = 1:length(timeStampToExportUpdate)
            timeStampCheck = timeStampToExportUpdate(i, :);
            timeStampCheck = timeStampCheck(~isnan(timeStampCheck)); % to keep timestamp in case there are sweeps of different length but with the same sampling interval
            if all(timeStampCheck == timeStampCheck(1))
            else
                timeStampFlag = 0;
                break
            end
        end
        
        if timeStampFlag == 1
            try
                timeStampColumn = nanmean(timeStampToExportNew, 2); % this will effectively give the longest timestamp
                exportFinal = [timeStampColumn, dataToExportNew];
            catch ME % for whatever reason
                timeStampFlag = 0;
                exportFinal = dataToExportNew;
            end
        else
            timeStampFlag = 0;
            exportFinal = dataToExportNew;
        end
        
        % set save path and file name
        todayYY = num2str(year(datetime));
        todayYY = todayYY(end-1:end);
        todayMM = sprintf('%02.0f', month(datetime));
        todayDD = sprintf('%02.0f', day(datetime));
        saveNameDate = [todayYY, todayMM, todayDD];
        saveNameCell = h.exp.fileName{currentExperiment}(1:end-4);
        saveNameCell = [defaultSaveFilePrefix, saveNameCell];
        %{
        if length(h.exp.fileName) > 1 % more than 1 experiments in dataset
            expCount = length(h.exp.fileName);
            expCount = num2str(expCount);
            saveNameCellSuffix = ['_N', expCount, '_S', num2str(targetSignal), '_', saveNameDate];
            saveNameCell = [saveNameCell, saveNameCellSuffix];
        else
        %}
            saveNameCellSuffix = ['_S', num2str(targetSignal), '_', saveNameDate];
            saveNameCell = [saveNameCell, saveNameCellSuffix];
        %end
        saveName = [saveNameCell, '.csv'];
        savePath = [defaultSavePath, '\']; % appending backslash for proper formatting
        
        %{
        % prompt, since it could take some time
        fprintf('Exporting results... (for ALL experiments)');
        %}
        
        % save
        try
            %[actualName, actualPath, isSaved] = uisaveX(exportFinal, [savePath, saveName]);
            writematrix(exportFinal, [savePath, saveName]);
            
            % print results
            %elapsedTime = toc;
            %fprintf('\nSaved as: %s%s (%.1f s) \n\n', actualPath, actualName, elapsedTime);
            %fprintf('\nSaved as: %s%s (%.1f s) \n\n', savePath, saveName, elapsedTime);
            if timeStampFlag
                fprintf('\n(Src. %s) Saved as: %s%s (timestamp at column %s)', num2str(targetSignal), savePath, saveName, num2str(timeStampColumnIdx));
            else
                fprintf('\n(Src. %s) Saved as: %s%s (without timestamp; timestamp mismatch between sweeps)', num2str(targetSignal), savePath, saveName);
            end
        catch ME
            elapsedTime = toc;
            fprintf(' Aborted.\n\n');
            return
        end

    end

elapsedTime = toc;
fprintf('\n Export complete. (elapsed time: %.2f s)\n\n', elapsedTime);
%fprintf('\n\n');

end


function exportTraces2(src, ~)

% load
h = guidata(src);
expIdx = h.ui.cellListDisplay.Value;
expIdx = expIdx(1); % force single selection
h.ui.cellListDisplay.Value = expIdx;
swpIdx = h.ui.sweepListDisplay.Value;

displayFlag = [0, 0];
if h.ui.exportTarget1.Value
    displayFlag(1) = 1;
end
if h.ui.exportTarget2.Value
    displayFlag(2) = 1;
end

if isempty(h.ui.cellListDisplay.String)
    return
else
    winTitle = h.ui.cellListDisplay.String{expIdx};
    newWin = figure('name', winTitle, 'numbertitle', 'off', 'color', 'w', 'units', 'normalized', 'position', [0.25, 0.25, 0.5, 0.5]);
    newAxes = axes('Parent', newWin);
    set(newAxes, 'layer', 'top');
    displayTrace2(h, expIdx, newAxes, displayFlag);
end

% save
guidata(src, h);

end


%% Trace Display Appearance


function traceDisplayXZoomIn(src, ~)
% zoom in main trace window on x axis

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayXRange = h.ui.traceDisplayXRange; % x range; to be shared across experiments

% zoom
zoom = params.xRangeZoom; % zooming factor
if isempty(traceDisplayXRange)
    return
else
    traceDisplayXRangeLow = traceDisplayXRange(1);
    traceDisplayXRangeHigh = traceDisplayXRange(2);
    traceDisplayXRangeHigh = traceDisplayXRangeLow + (traceDisplayXRangeHigh - traceDisplayXRangeLow)/zoom; % for x axis, retain lower end of range
    traceDisplayXRange = [traceDisplayXRangeLow, traceDisplayXRangeHigh];
    set(h.ui.traceDisplayXZoomOut, 'enable', 'on'); % in case it had been disabled
end

% re-enable move and zoom buttons in case they had been disabled
set(h.ui.traceDisplayXMoveLeft, 'enable', 'on');
set(h.ui.traceDisplayXMoveRight, 'enable', 'on');
set(h.ui.traceDisplayXZoomOut, 'enable', 'on');

% do display
axes(traceDisplay);
xlim(traceDisplayXRange);

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayXRange = traceDisplayXRange;
guidata(src, h);

end


function traceDisplayXZoomOut(src, ~)
% zoom out main trace window on x axis

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayXRange = h.ui.traceDisplayXRange; % x range; to be shared across experiments
%  experiment selected
itemSelected = h.ui.cellListDisplay.Value;
itemSelected = itemSelected(1); % force single selection
h.ui.cellListDisplay.Value = itemSelected;
itemToDisplay = itemSelected(1); % display only the first one if multiple items are selected - obsolete
VRec = h.exp.data.VRec;
if isempty(VRec)
    return
elseif iscell(VRec{itemToDisplay}) == 1
    VRecToDisplay = VRec{itemToDisplay};
    sweepCount = length(VRecToDisplay);
else
    VRecToDisplay = VRec{itemToDisplay};
    sweepCount = 1;
end

% zoom
pvbsTimeColumn = 1; % column for timestamp in .csv - this should not be a problem, so can be written here
dataLimit = [];
if sweepCount == 1
    if iscell(VRecToDisplay)
        currentSweep = VRecToDisplay{1};
    else
        currentSweep = VRecToDisplay;
    end
    timeStampEnd = currentSweep(end, pvbsTimeColumn);
    dataLimit(end + 1) = timeStampEnd;
else
    for i = 1:sweepCount
        currentSweep = VRecToDisplay{i};
        timeStampEnd = currentSweep(end, pvbsTimeColumn);
        dataLimit(end + 1) = timeStampEnd;
    end
end
dataLimit = max(dataLimit); % max number of data points, i.e. recording length
dataLimit = ceil(dataLimit); % for aesthetic reasons - to display last tick
zoom = params.xRangeZoom; % zooming factor
if isempty(traceDisplayXRange)
    return
else
    traceDisplayXRangeLow = traceDisplayXRange(1);
    traceDisplayXRangeHigh = traceDisplayXRange(2);
    traceDisplayXRangeHigh = traceDisplayXRangeHigh + (traceDisplayXRangeHigh - traceDisplayXRangeLow)*(zoom - 1); % for x axis, retain lower end of range
    traceDisplayXRange = [traceDisplayXRangeLow, traceDisplayXRangeHigh];
    if traceDisplayXRangeHigh > dataLimit % do not roll above data limits
        traceDisplayXRangeHigh = dataLimit;
        set(h.ui.traceDisplayXZoomOut, 'enable', 'off');
    end
    traceDisplayXRange = [traceDisplayXRangeLow, traceDisplayXRangeHigh];
end

% do display
axes(traceDisplay); 
xlim(traceDisplayXRange);

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayXRange = traceDisplayXRange;
guidata(src, h);

end


function traceDisplayXMoveRight(src, ~)
% move main trace window right in x axis

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayXRange = h.ui.traceDisplayXRange; % x range; to be shared across experiments
%  experiment selected
itemSelected = h.ui.cellListDisplay.Value;
itemSelected = itemSelected(1); % force single selection
h.ui.cellListDisplay.Value = itemSelected;
itemToDisplay = itemSelected(1); % display only the first one if multiple items are selected - obsolete
VRec = h.exp.data.VRec;
if isempty(VRec)
    return
elseif iscell(VRec{itemToDisplay}) == 1
    VRecToDisplay = VRec{itemToDisplay};
    sweepCount = length(VRecToDisplay);
else
    VRecToDisplay = VRec{itemToDisplay};
    sweepCount = 1;
end

% move
pvbsTimeColumn = 1; % column for timestamp in .csv - this should not be a problem, so can be written here
dataLimit = [];
if sweepCount == 1
    if iscell(VRecToDisplay)
        currentSweep = VRecToDisplay{1};
    else
        currentSweep = VRecToDisplay;
    end
    timeStampEnd = currentSweep(end, pvbsTimeColumn);
    dataLimit(end + 1) = timeStampEnd;
else
    for i = 1:sweepCount
        currentSweep = VRecToDisplay{i};
        timeStampEnd = currentSweep(end, pvbsTimeColumn);
        dataLimit(end + 1) = timeStampEnd;
    end
end
dataLimit = max(dataLimit); % max number of data points, i.e. recording length
move = params.xRangeMove; % moving factor
traceDisplayXRangeLow = traceDisplayXRange(1);
traceDisplayXRangeHigh = traceDisplayXRange(2);
traceDisplayXRangeSpan = traceDisplayXRange(2) - traceDisplayXRange(1);
move = move*traceDisplayXRangeSpan;
traceDisplayXRangeLow = traceDisplayXRangeLow + move;
traceDisplayXRangeHigh = traceDisplayXRangeHigh + move;
if traceDisplayXRangeHigh > dataLimit % do not roll above data limits
    traceDisplayXRangeHigh = dataLimit;
    traceDisplayXRangeLow = dataLimit - traceDisplayXRangeSpan;
    set(h.ui.traceDisplayXMoveRight, 'enable', 'off');
end
traceDisplayXRange = [traceDisplayXRangeLow, traceDisplayXRangeHigh];
set(h.ui.traceDisplayXMoveLeft, 'enable', 'on'); % in case it had been disabled

% do display
axes(traceDisplay);
xlim(traceDisplayXRange);

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayXRange = traceDisplayXRange;
guidata(src, h);

end


function traceDisplayXMoveLeft(src, ~)
% move main trace window left in x axis

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayXRange = h.ui.traceDisplayXRange; % x range; to be shared across experiments

% move
move = params.xRangeMove; % moving factor
if isempty(traceDisplayXRange)
    return
else
    traceDisplayXRangeLow = traceDisplayXRange(1);
    traceDisplayXRangeHigh = traceDisplayXRange(2);
    traceDisplayXRangeSpan = traceDisplayXRange(2) - traceDisplayXRange(1);
    move = move*traceDisplayXRangeSpan;
    traceDisplayXRangeLow = traceDisplayXRangeLow - move;
    traceDisplayXRangeHigh = traceDisplayXRangeHigh - move;
    if traceDisplayXRangeLow < 0 % do not roll below zero
        traceDisplayXRangeLow = 0;
        traceDisplayXRangeHigh = traceDisplayXRangeSpan;
        set(h.ui.traceDisplayXMoveLeft, 'enable', 'off');
    end
    traceDisplayXRange = [traceDisplayXRangeLow, traceDisplayXRangeHigh];
    set(h.ui.traceDisplayXMoveRight, 'enable', 'on'); % in case it had been disabled
end

% do display
axes(traceDisplay);
xlim(traceDisplayXRange);

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayXRange = traceDisplayXRange;
guidata(src, h);

end


function traceDisplayYZoomIn(src, ~)
% zoom in main trace window on y axis

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayYRange = h.ui.traceDisplayYRange; % y range; to be shared across experiments

% zoom
zoom = params.yRangeZoom; % zooming factor
traceDisplayYRangeLow = traceDisplayYRange(1);
traceDisplayYRangeHigh = traceDisplayYRange(2);
traceDisplayYRangeMid = (traceDisplayYRange(2) + traceDisplayYRange(1))/2;
traceDisplayYRangeLow = (traceDisplayYRangeLow + traceDisplayYRangeMid)/zoom;
traceDisplayYRangeHigh = (traceDisplayYRangeMid + traceDisplayYRangeHigh)/zoom;
traceDisplayYRange = [traceDisplayYRangeLow, traceDisplayYRangeHigh];

% do display
axes(traceDisplay); 
ylim(traceDisplayYRange);

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayYRange = traceDisplayYRange;
guidata(src, h);

end


function traceDisplayYZoomOut(src, ~)
% zoom out main trace window on y axis

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayYRange = h.ui.traceDisplayYRange; % y range; to be shared across experiments

% zoom
zoom = params.yRangeZoom; % zooming factor
traceDisplayYRangeLow = traceDisplayYRange(1);
traceDisplayYRangeHigh = traceDisplayYRange(2);
traceDisplayYRangeMid = (traceDisplayYRange(2) + traceDisplayYRange(1))/2;
traceDisplayYRangeLow = traceDisplayYRangeLow + (traceDisplayYRangeLow - traceDisplayYRangeMid)*(zoom - 1);
traceDisplayYRangeHigh = traceDisplayYRangeHigh + (traceDisplayYRangeHigh - traceDisplayYRangeMid)*(zoom - 1);
traceDisplayYRange = [traceDisplayYRangeLow, traceDisplayYRangeHigh];

% do display
axes(traceDisplay);
ylim(traceDisplayYRange);

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayYRange = traceDisplayYRange;
guidata(src, h);

end


function traceDisplayYMoveUp(src, ~)
% move main trace window up in y axis

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayYRange = h.ui.traceDisplayYRange; % y range; to be shared across experiments

% move
move = params.yRangeMove; % moving factor
traceDisplayYRangeLow = traceDisplayYRange(1);
traceDisplayYRangeHigh = traceDisplayYRange(2);
traceDisplayYRangeSpan = traceDisplayYRange(2) - traceDisplayYRange(1);
move = move*traceDisplayYRangeSpan;
traceDisplayYRangeLow = traceDisplayYRangeLow + move;
traceDisplayYRangeHigh = traceDisplayYRangeHigh + move;
traceDisplayYRange = [traceDisplayYRangeLow, traceDisplayYRangeHigh];

% do display
axes(traceDisplay);
ylim(traceDisplayYRange);

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayYRange = traceDisplayYRange;
guidata(src, h);

end


function traceDisplayYMoveDown(src, ~)
% move main trace window down in y axis

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayYRange = h.ui.traceDisplayYRange; % y range; to be shared across experiments

% move
move = params.yRangeMove; % moving factor
traceDisplayYRangeLow = traceDisplayYRange(1);
traceDisplayYRangeHigh = traceDisplayYRange(2);
traceDisplayYRangeSpan = traceDisplayYRange(2) - traceDisplayYRange(1);
move = move*traceDisplayYRangeSpan;
traceDisplayYRangeLow = traceDisplayYRangeLow - move;
traceDisplayYRangeHigh = traceDisplayYRangeHigh - move;
traceDisplayYRange = [traceDisplayYRangeLow, traceDisplayYRangeHigh];

% do display
axes(traceDisplay);
ylim(traceDisplayYRange);

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayYRange = traceDisplayYRange;
guidata(src, h);

end


function traceDisplayY2ZoomIn(src, ~)
% zoom in main trace window on y axis (right)

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayYRange = h.ui.traceDisplayY2Range; % y range; to be shared across experiments

% zoom
zoom = params.y2RangeZoom; % zooming factor
traceDisplayYRangeLow = traceDisplayYRange(1);
traceDisplayYRangeHigh = traceDisplayYRange(2);
traceDisplayYRangeMid = (traceDisplayYRange(2) + traceDisplayYRange(1))/2;
traceDisplayYRangeLow = (traceDisplayYRangeLow + traceDisplayYRangeMid)/zoom;
traceDisplayYRangeHigh = (traceDisplayYRangeMid + traceDisplayYRangeHigh)/zoom;
traceDisplayYRange = [traceDisplayYRangeLow, traceDisplayYRangeHigh];
set(h.ui.traceDisplayY2ZoomOut, 'enable', 'on'); % in case it had been disabled
set(h.ui.traceDisplayY2MoveDown, 'enable', 'on'); % in case it had been disabled

% do display
axes(traceDisplay); yyaxis right;
ylim(traceDisplayYRange);
yyaxis left;

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayY2Range = traceDisplayYRange;
guidata(src, h);

end


function traceDisplayY2ZoomOut(src, ~)
% zoom out main trace window on y axis

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayYRange = h.ui.traceDisplayY2Range; % y range; to be shared across experiments

% zoom
zoom = params.y2RangeZoom; % zooming factor
traceDisplayYRangeLow = traceDisplayYRange(1);
traceDisplayYRangeHigh = traceDisplayYRange(2);
traceDisplayYRangeMid = (traceDisplayYRange(2) + traceDisplayYRange(1))/2;
traceDisplayYRangeLow = traceDisplayYRangeLow + (traceDisplayYRangeLow - traceDisplayYRangeMid)*(zoom - 1);
traceDisplayYRangeHigh = traceDisplayYRangeHigh + (traceDisplayYRangeHigh - traceDisplayYRangeMid)*(zoom - 1);
traceDisplayYRange = [traceDisplayYRangeLow, traceDisplayYRangeHigh];
%{
if traceDisplayYRangeLow < -1 % do not roll below -1
    traceDisplayYRange = [-1, traceDisplayYRangeHigh + (-1 - traceDisplayYRangeLow)];
    %set(h.ui.traceDisplayY2ZoomOut, 'enable', 'off');
end
%}

% do display
axes(traceDisplay); yyaxis right;
ylim(traceDisplayYRange);
yyaxis left;

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayY2Range = traceDisplayYRange;
guidata(src, h);

end


function traceDisplayY2MoveUp(src, ~)
% move main trace window up in y axis

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayYRange = h.ui.traceDisplayY2Range; % y range; to be shared across experiments

% move
move = params.y2RangeMove; % moving factor
traceDisplayYRangeLow = traceDisplayYRange(1);
traceDisplayYRangeHigh = traceDisplayYRange(2);
traceDisplayYRangeSpan = traceDisplayYRange(2) - traceDisplayYRange(1);
move = move*traceDisplayYRangeSpan;
traceDisplayYRangeLow = traceDisplayYRangeLow + move;
traceDisplayYRangeHigh = traceDisplayYRangeHigh + move;
traceDisplayYRange = [traceDisplayYRangeLow, traceDisplayYRangeHigh];
set(h.ui.traceDisplayY2ZoomOut, 'enable', 'on'); % in case it had been disabled
set(h.ui.traceDisplayY2MoveDown, 'enable', 'on'); % in case it had been disabled

% do display
axes(traceDisplay); yyaxis right;
ylim(traceDisplayYRange);
yyaxis left;

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayY2Range = traceDisplayYRange;
guidata(src, h);

end


function traceDisplayY2MoveDown(src, ~)
% move main trace window down in y axis

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayYRange = h.ui.traceDisplayY2Range; % y range; to be shared across experiments

% move
move = params.y2RangeMove; % moving factor
traceDisplayYRangeLow = traceDisplayYRange(1);
traceDisplayYRangeHigh = traceDisplayYRange(2);
traceDisplayYRangeSpan = traceDisplayYRange(2) - traceDisplayYRange(1);
move = move*traceDisplayYRangeSpan;
traceDisplayYRangeLow = traceDisplayYRangeLow - move;
traceDisplayYRangeHigh = traceDisplayYRangeHigh - move;
%{
if traceDisplayYRangeLow < -1 % do not roll below -1
    traceDisplayYRangeLow = -1;
    traceDisplayYRangeHigh = -1 + traceDisplayYRangeSpan;
    set(h.ui.traceDisplayY2MoveDown, 'enable', 'off');
end
%}
traceDisplayYRange = [traceDisplayYRangeLow, traceDisplayYRangeHigh];

% do display
axes(traceDisplay); yyaxis right;
ylim(traceDisplayYRange);
yyaxis left;

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayY2Range = traceDisplayYRange;
guidata(src, h);

end


function traceDisplayReset(src, ~)
% reset main trace window range

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayYRange = params.yRangeDefault;
traceDisplayY2Range = params.y2RangeDefault;
%  experiment selected
itemSelected = h.ui.cellListDisplay.Value;
itemSelected = itemSelected(1); % force single selection
h.ui.cellListDisplay.Value = itemSelected;
itemToDisplay = itemSelected(1); % display only the first one if multiple items are selected - obsolete
VRec = h.exp.data.VRec;
if isempty(VRec)
    return
elseif iscell(VRec{itemToDisplay}) == 1
    VRecToDisplay = VRec{itemToDisplay};
    sweepCount = length(VRecToDisplay);
else
    VRecToDisplay = VRec{itemToDisplay};
    sweepCount = 1;
end

% zoom
pvbsTimeColumn = 1; % column for timestamp in .csv - this should not be a problem, so can be written here
dataLimit = [];
if sweepCount == 1
    if iscell(VRecToDisplay)
        currentSweep = VRecToDisplay{1};
    else
        currentSweep = VRecToDisplay;
    end
    timeStampEnd = currentSweep(end, pvbsTimeColumn);
    dataLimit(end + 1) = timeStampEnd;
else
    for i = 1:sweepCount
        currentSweep = VRecToDisplay{i};
        timeStampEnd = currentSweep(end, pvbsTimeColumn);
        dataLimit(end + 1) = timeStampEnd;
    end
end
dataLimit = max(dataLimit); % max number of data points, i.e. recording length
dataLimit = ceil(dataLimit); % for aesthetic reasons - to display last tick
traceDisplayXRange = [0, dataLimit];

% re-enable move and zoom buttons in case they had been disabled
set(h.ui.traceDisplayXMoveLeft, 'enable', 'on');
set(h.ui.traceDisplayXMoveRight, 'enable', 'on');
set(h.ui.traceDisplayXZoomOut, 'enable', 'on');
set(h.ui.traceDisplayY2MoveDown, 'enable', 'on');
set(h.ui.traceDisplayY2ZoomOut, 'enable', 'on');

% do display
axes(traceDisplay);
xlim(traceDisplayXRange);
ylim(traceDisplayYRange);
yyaxis right; ylim(traceDisplayY2Range); yyaxis left;
%  do not display tick labels as multiples of powers of 10 
ax = gca;
ax.XRuler.Exponent = 0;
ax.YRuler.Exponent = 0;
yyaxis right; ax.YRuler.Exponent = 0; yyaxis left;

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayXRange = traceDisplayXRange;
h.ui.traceDisplayYRange = traceDisplayYRange;
h.ui.traceDisplayY2Range = traceDisplayY2Range;
guidata(src, h);

end


function traceDisplayReset2(src, ~)
% reset main trace window range

% load
h = guidata(src);
params = h.params;
traceDisplay = h.ui.traceDisplay;
traceDisplayY2Range = params.y2RangeDefault;
%  experiment selected
itemSelected = h.ui.cellListDisplay.Value;
itemSelected = itemSelected(1); % force single selection
h.ui.cellListDisplay.Value = itemSelected;
itemToDisplay = itemSelected(1); % display only the first one if multiple items are selected - obsolete
VRec = h.exp.data.VRec;
if isempty(VRec)
    return
elseif iscell(VRec{itemToDisplay}) == 1
    VRecToDisplay = VRec{itemToDisplay};
    sweepCount = length(VRecToDisplay);
else
    VRecToDisplay = VRec{itemToDisplay};
    sweepCount = 1;
end

% zoom
pvbsTimeColumn = 1; % column for timestamp in .csv - this should not be a problem, so can be written here
dataLimit = [];
if sweepCount == 1
    if iscell(VRecToDisplay)
        currentSweep = VRecToDisplay{1};
    else
        currentSweep = VRecToDisplay;
    end
    timeStampEnd = currentSweep(end, pvbsTimeColumn);
    dataLimit(end + 1) = timeStampEnd;
else
    for i = 1:sweepCount
        currentSweep = VRecToDisplay{i};
        timeStampEnd = currentSweep(end, pvbsTimeColumn);
        dataLimit(end + 1) = timeStampEnd;
    end
end
dataLimit = max(dataLimit); % max number of data points, i.e. recording length
dataLimit = ceil(dataLimit); % for aesthetic reasons - to display last tick
traceDisplayXRange = [0, dataLimit];

% re-enable move and zoom buttons in case they had been disabled
set(h.ui.traceDisplayY2MoveDown, 'enable', 'on');
set(h.ui.traceDisplayY2ZoomOut, 'enable', 'on');

% do display
axes(traceDisplay);
yyaxis right; ylim(traceDisplayY2Range); yyaxis left;
%  do not display tick labels as multiples of powers of 10 
ax = gca;
yyaxis right; ax.YRuler.Exponent = 0; yyaxis left;

% save
h.params = params;
h.ui.traceDisplay = traceDisplay;
h.ui.traceDisplayY2Range = traceDisplayY2Range;
guidata(src, h);

end


function resultsPlot1YZoomIn(src, ~)
% zoom in on results plot 1 y axis

% load
h = guidata(src);
params = h.params;
displayWin = h.ui.analysisPlot1;
yRange = displayWin.YLim; % y range

% zoom
zoom = params.yRangeZoom; % zooming factor - originally intended for main trace display window, but can be used here as well
yRangeLow = yRange(1);
yRangeHigh = yRange(2);
yRangeMid = (yRange(2) + yRange(1))/2;
yRangeLow = (yRangeLow + yRangeMid)/zoom;
yRangeHigh = (yRangeMid + yRangeHigh)/zoom;
yRange = [yRangeLow, yRangeHigh];

% do display
axes(displayWin); 
ylim(yRange);

% save
h.params = params;
h.ui.analysisPlot1 = displayWin;
guidata(src, h);

end


function resultsPlot1YZoomOut(src, ~)
% zoom out on results plot 1 y axis

% load
h = guidata(src);
params = h.params;
displayWin = h.ui.analysisPlot1;
yRange = displayWin.YLim; % y range

% zoom
zoom = params.yRangeZoom; % zooming factor - originally intended for main trace display window, but can be used here as well
yRangeLow = yRange(1);
yRangeHigh = yRange(2);
yRangeMid = (yRange(2) + yRange(1))/2;
yRangeLow = yRangeLow + (yRangeLow - yRangeMid)*(zoom - 1);
yRangeHigh = yRangeHigh + (yRangeHigh - yRangeMid)*(zoom - 1);
yRange = [yRangeLow, yRangeHigh];

% do display
axes(displayWin); 
ylim(yRange);

% save
h.params = params;
h.ui.analysisPlot1 = displayWin;
guidata(src, h);

end


function resultsPlot1YMoveUp(src, ~)
% move up on results plot 1 y axis

% load
h = guidata(src);
params = h.params;
displayWin = h.ui.analysisPlot1;
yRange = displayWin.YLim; % y range

% move
move = params.yRangeMove; % moving factor - originally intended for main trace display window, but can be used here as well
move = 2*move; % actually, the above is good for trace display, but seems too fine for results plot
yRangeLow = yRange(1);
yRangeHigh = yRange(2);
yRangeSpan = yRange(2) - yRange(1);
move = move*yRangeSpan;
yRangeLow = yRangeLow + move;
yRangeHigh = yRangeHigh + move;
yRange = [yRangeLow, yRangeHigh];

% do display
axes(displayWin); 
ylim(yRange);

% save
h.params = params;
h.ui.analysisPlot1 = displayWin;
guidata(src, h);

end


function resultsPlot1YMoveDown(src, ~)
% move down on results plot 1 y axis

% load
h = guidata(src);
params = h.params;
displayWin = h.ui.analysisPlot1;
yRange = displayWin.YLim; % y range

% move
move = params.yRangeMove; % moving factor - originally intended for main trace display window, but can be used here as well
move = 2*move; % actually, the above is good for trace display, but seems too fine for results plot
yRangeLow = yRange(1);
yRangeHigh = yRange(2);
yRangeSpan = yRange(2) - yRange(1);
move = move*yRangeSpan;
yRangeLow = yRangeLow - move;
yRangeHigh = yRangeHigh - move;
yRange = [yRangeLow, yRangeHigh];

% do display
axes(displayWin); 
ylim(yRange);

% save
h.params = params;
h.ui.analysisPlot1 = displayWin;
guidata(src, h);

end


function resultsPlot1YReset(src, ~)
% reset results plot 1 y axis

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    return
end
params = h.params;
displayWin = h.ui.analysisPlot1;

% do display
axes(displayWin); 
ylim(h.params.resultsPlot1YRange);

% save
h.params = params; % don't change anything
h.ui.analysisPlot1 = displayWin;
guidata(src, h);

end


function resultsPlot2YZoomIn(src, ~)
% zoom in on results plot 2 y axis

% load
h = guidata(src);
params = h.params;
displayWin = h.ui.analysisPlot2;
yRange = displayWin.YLim; % y range

% zoom
zoom = params.yRangeZoom; % zooming factor - originally intended for main trace display window, but can be used here as well
yRangeLow = yRange(1);
yRangeHigh = yRange(2);
yRangeMid = (yRange(2) + yRange(1))/2;
yRangeLow = (yRangeLow + yRangeMid)/zoom;
yRangeHigh = (yRangeMid + yRangeHigh)/zoom;
yRange = [yRangeLow, yRangeHigh];

% do display
axes(displayWin); 
ylim(yRange);

% save
h.params = params;
h.ui.analysisPlot2 = displayWin;
guidata(src, h);

end


function resultsPlot2YZoomOut(src, ~)
% zoom out on results plot 2 y axis

% load
h = guidata(src);
params = h.params;
displayWin = h.ui.analysisPlot2;
yRange = displayWin.YLim; % y range

% zoom
zoom = params.yRangeZoom; % zooming factor - originally intended for main trace display window, but can be used here as well
yRangeLow = yRange(1);
yRangeHigh = yRange(2);
yRangeMid = (yRange(2) + yRange(1))/2;
yRangeLow = yRangeLow + (yRangeLow - yRangeMid)*(zoom - 1);
yRangeHigh = yRangeHigh + (yRangeHigh - yRangeMid)*(zoom - 1);
yRange = [yRangeLow, yRangeHigh];

% do display
axes(displayWin); 
ylim(yRange);

% save
h.params = params;
h.ui.analysisPlot2 = displayWin;
guidata(src, h);

end


function resultsPlot2YMoveUp(src, ~)
% move up on results plot 2 y axis

% load
h = guidata(src);
params = h.params;
displayWin = h.ui.analysisPlot2;
yRange = displayWin.YLim; % y range

% move
move = params.yRangeMove; % moving factor - originally intended for main trace display window, but can be used here as well
move = 2*move; % actually, the above is good for trace display, but seems too fine for results plot
yRangeLow = yRange(1);
yRangeHigh = yRange(2);
yRangeSpan = yRange(2) - yRange(1);
move = move*yRangeSpan;
yRangeLow = yRangeLow + move;
yRangeHigh = yRangeHigh + move;
yRange = [yRangeLow, yRangeHigh];

% do display
axes(displayWin); 
ylim(yRange);

% save
h.params = params;
h.ui.analysisPlot2 = displayWin;
guidata(src, h);

end


function resultsPlot2YMoveDown(src, ~)
% move down on results plot 2 y axis

% load
h = guidata(src);
params = h.params;
displayWin = h.ui.analysisPlot2;
yRange = displayWin.YLim; % y range

% move
move = params.yRangeMove; % moving factor - originally intended for main trace display window, but can be used here as well
move = 2*move; % actually, the above is good for trace display, but seems too fine for results plot
yRangeLow = yRange(1);
yRangeHigh = yRange(2);
yRangeSpan = yRange(2) - yRange(1);
move = move*yRangeSpan;
yRangeLow = yRangeLow - move;
yRangeHigh = yRangeHigh - move;
yRange = [yRangeLow, yRangeHigh];

% do display
axes(displayWin); 
ylim(yRange);

% save
h.params = params;
h.ui.analysisPlot2 = displayWin;
guidata(src, h);

end


function resultsPlot2YReset(src, ~)
% reset results plot 1 y axis

% load
h = guidata(src);
if isempty(h.ui.cellListDisplay.String)
    return
end
params = h.params;
displayWin = h.ui.analysisPlot2;

% do display
axes(displayWin); 
ylim(h.params.resultsPlot2YRange);

% save
h.params = params; % don't change anything
h.ui.analysisPlot2 = displayWin;
guidata(src, h);

end


%% Miscellaneous


function text = copyTextFromPopup(src, ~)

text = src.String;
clipboard('copy', text);

fprintf('\nCopied to Clipboard: \n %s \n', text);

end


%% Stolen code (... I mean borrowed...... without permission) 


% xml2struct by Wouter Falkena et al.
%  (https://www.mathworks.com/matlabcentral/fileexchange/28518-xml2struct)
function [ s ] = xml2struct_pvbs( file )
%Convert xml file into a MATLAB structure
% [ s ] = xml2struct( file )
%
% A file containing:
% <XMLname attrib1="Some value">
%   <Element>Some text</Element>
%   <DifferentElement attrib2="2">Some more text</Element>
%   <DifferentElement attrib3="2" attrib4="1">Even more text</DifferentElement>
% </XMLname>
%
% Will produce:
% s.XMLname.Attributes.attrib1 = "Some value";
% s.XMLname.Element.Text = "Some text";
% s.XMLname.DifferentElement{1}.Attributes.attrib2 = "2";
% s.XMLname.DifferentElement{1}.Text = "Some more text";
% s.XMLname.DifferentElement{2}.Attributes.attrib3 = "2";
% s.XMLname.DifferentElement{2}.Attributes.attrib4 = "1";
% s.XMLname.DifferentElement{2}.Text = "Even more text";
%
% Please note that the following characters are substituted
% '-' by '_dash_', ':' by '_colon_' and '.' by '_dot_'
%
% Written by W. Falkena, ASTI, TUDelft, 21-08-2010
% Attribute parsing speed increased by 40% by A. Wanner, 14-6-2011
% Added CDATA support by I. Smirnov, 20-3-2012
%
% Modified by X. Mo, University of Wisconsin, 12-5-2012

    if (nargin < 1)
        clc;
        help xml2struct
        return
    end
    
    if isa(file, 'org.apache.xerces.dom.DeferredDocumentImpl') || isa(file, 'org.apache.xerces.dom.DeferredElementImpl')
        % input is a java xml object
        xDoc = file;
    else
        %check for existance
        if (exist(file,'file') == 0)
            %Perhaps the xml extension was omitted from the file name. Add the
            %extension and try again.
            if (isempty(strfind(file,'.xml')))
                file = [file '.xml'];
            end
            
            if (exist(file,'file') == 0)
                error(['The file ' file ' could not be found']);
            end
        end
        %read the xml file
        xDoc = xmlread(file);
    end
    
    %parse xDoc into a MATLAB structure
    s = parseChildNodes(xDoc);
    
%end %%% let subfunctions be subfunctions

% ----- Subfunction parseChildNodes -----
function [children,ptext,textflag] = parseChildNodes(theNode)
    % Recurse over node children.
    children = struct;
    ptext = struct; textflag = 'Text';
    if hasChildNodes(theNode)
        childNodes = getChildNodes(theNode);
        numChildNodes = getLength(childNodes);

        for count = 1:numChildNodes
            theChild = item(childNodes,count-1);
            [text,name,attr,childs,textflag] = getNodeData(theChild);
            
            if (~strcmp(name,'#text') && ~strcmp(name,'#comment') && ~strcmp(name,'#cdata_dash_section'))
                %XML allows the same elements to be defined multiple times,
                %put each in a different cell
                if (isfield(children,name))
                    if (~iscell(children.(name)))
                        %put existsing element into cell format
                        children.(name) = {children.(name)};
                    end
                    index = length(children.(name))+1;
                    %add new element
                    children.(name){index} = childs;
                    if(~isempty(fieldnames(text)))
                        children.(name){index} = text; 
                    end
                    if(~isempty(attr)) 
                        children.(name){index}.('Attributes') = attr; 
                    end
                else
                    %add previously unknown (new) element to the structure
                    children.(name) = childs;
                    if(~isempty(text) && ~isempty(fieldnames(text)))
                        children.(name) = text; 
                    end
                    if(~isempty(attr)) 
                        children.(name).('Attributes') = attr; 
                    end
                end
            else
                ptextflag = 'Text';
                if (strcmp(name, '#cdata_dash_section'))
                    ptextflag = 'CDATA';
                elseif (strcmp(name, '#comment'))
                    ptextflag = 'Comment';
                end
                
                %this is the text in an element (i.e., the parentNode) 
                if (~isempty(regexprep(text.(textflag),'[\s]*','')))
                    if (~isfield(ptext,ptextflag) || isempty(ptext.(ptextflag)))
                        ptext.(ptextflag) = text.(textflag);
                    else
                        %what to do when element data is as follows:
                        %<element>Text <!--Comment--> More text</element>
                        
                        %put the text in different cells:
                        % if (~iscell(ptext)) ptext = {ptext}; end
                        % ptext{length(ptext)+1} = text;
                        
                        %just append the text
                        ptext.(ptextflag) = [ptext.(ptextflag) text.(textflag)];
                    end
                end
            end
            
        end
    end
end
% ----- Subfunction getNodeData -----
function [text,name,attr,childs,textflag] = getNodeData(theNode)
    % Create structure of node info.
    
    %make sure name is allowed as structure name
    name = toCharArray(getNodeName(theNode))';
    name = strrep(name, '-', '_dash_');
    name = strrep(name, ':', '_colon_');
    name = strrep(name, '.', '_dot_');

    attr = parseAttributes(theNode);
    if (isempty(fieldnames(attr))) 
        attr = []; 
    end
    
    %parse child nodes
    [childs,text,textflag] = parseChildNodes(theNode);
    
    if (isempty(fieldnames(childs)) && isempty(fieldnames(text)))
        %get the data of any childless nodes
        % faster than if any(strcmp(methods(theNode), 'getData'))
        % no need to try-catch (?)
        % faster than text = char(getData(theNode));
        text.(textflag) = toCharArray(getTextContent(theNode))';
    end
    
end
% ----- Subfunction parseAttributes -----
function attributes = parseAttributes(theNode)
    % Create attributes structure.

    attributes = struct;
    if hasAttributes(theNode)
       theAttributes = getAttributes(theNode);
       numAttributes = getLength(theAttributes);

       for count = 1:numAttributes
            %attrib = item(theAttributes,count-1);
            %attr_name = regexprep(char(getName(attrib)),'[-:.]','_');
            %attributes.(attr_name) = char(getValue(attrib));

            %Suggestion of Adrian Wanner
            str = toCharArray(toString(item(theAttributes,count-1)))';
            k = strfind(str,'='); 
            attr_name = str(1:(k(1)-1));
            attr_name = strrep(attr_name, '-', '_dash_');
            attr_name = strrep(attr_name, ':', '_colon_');
            attr_name = strrep(attr_name, '.', '_dot_');
            attributes.(attr_name) = str((k(1)+2):(end-1));
       end
    end
end

end %%% end of xml2struct_pvbs()


% uipickfiles by Douglas Schwarz
%  (https://www.mathworks.com/matlabcentral/fileexchange/10867-uipickfiles-uigetfile-on-steroids)
function out = uipickfiles(varargin)
%uipickfiles: GUI program to select files and/or folders.
%
% Syntax:
%   files = uipickfiles('PropertyName',PropertyValue,...)
%
% The current folder can be changed by operating in the file navigator:
% double-clicking on a folder in the list or pressing Enter to move further
% down the tree, using the popup menu, clicking the up arrow button or
% pressing Backspace to move up the tree, typing a path in the box to move
% to any folder or right-clicking (control-click on Mac) on the path box to
% revisit a previously-visited folder.  These folders are listed in order
% of when they were last visited (most recent at the top) and the list is
% saved between calls to uipickfiles.  The list can be cleared or its
% maximum length changed with the items at the bottom of the menu.
% (Windows only: To go to a UNC-named resource you will have to type the
% UNC name in the path box, but all such visited resources will be
% remembered and listed along with the mapped drives.)  The items in the
% file navigator can be sorted by name, modification date or size by
% clicking on the headers, though neither date nor size are displayed.  All
% folders have zero size.
%
% Files can be added to the list by double-clicking or selecting files
% (non-contiguous selections are possible with the control key) and
% pressing the Add button.  Control-F will select all the files listed in
% the navigator while control-A will select everything (Command instead of
% Control on the Mac).  Since double-clicking a folder will open it,
% folders can be added only by selecting them and pressing the Add button.
% Files/folders in the list can be removed or re-ordered.  Recall button
% will insert into the Selected Files list whatever files were returned the
% last time uipickfiles was run.  When finished, a press of the Done button
% will return the full paths to the selected items in a cell array,
% structure array or character array.  If the Cancel button or the escape
% key is pressed then zero is returned.
%
% The figure can be moved and resized in the usual way and this position is
% saved and used for subsequent calls to uipickfiles.  The default position
% can be restored by double-clicking in a vacant region of the figure.
%
% The following optional property/value pairs can be specified as arguments
% to control the indicated behavior:
%
%   Property    Value
%   ----------  ----------------------------------------------------------
%   FilterSpec  String to specify starting folder and/or file filter.
%               Ex:  'C:\bin' will start up in that folder.  '*.txt'
%               will list only files ending in '.txt'.  'c:\bin\*.txt' will
%               do both.  Default is to start up in the current folder and
%               list all files.  Can be changed with the GUI.
%
%   REFilter    String containing a regular expression used to filter the
%               file list.  Ex: '\.m$|\.mat$' will list files ending in
%               '.m' and '.mat'.  Default is empty string.  Can be used
%               with FilterSpec and both filters are applied.  Can be
%               changed with the GUI.
%
%   REDirs      Logical flag indicating whether to apply the regular
%               expression filter to folder names.  Default is false which
%               means that all folders are listed.  Can be changed with the
%               GUI.
%
%   Type        Two-column cell array where the first column contains file
%               filters and the second column contains descriptions.  If
%               this property is specified an additional popup menu will
%               appear below the File Filter and selecting an item will put
%               that item into the File Filter.  By default, the first item
%               will be entered into the File Filter.  For example,
%                   { '*.m',   'M-files'   ;
%                     '*.mat', 'MAT-files' }.
%               Can also be a cell vector of file filter strings in which
%               case the descriptions will be the same as the file filters
%               themselves.
%               Must be a cell array even if there is only one entry.
%
%   Prompt      String containing a prompt appearing in the title bar of
%               the figure.  Default is 'Select files'.
%
%   NumFiles    Scalar or vector specifying number of files that must be
%               selected.  A scalar specifies an exact value; a two-element
%               vector can be used to specify a range, [min max].  The
%               function will not return unless the specified number of
%               files have been chosen.  Default is [] which accepts any
%               number of files.
%
%   Append      Cell array of strings, structure array or char array
%               containing a previously returned output from uipickfiles.
%               Used to start up program with some entries in the Selected
%               Files list.  Any included files that no longer exist will
%               not appear.  Default is empty cell array, {}.
%
%   Output      String specifying the data type of the output: 'cell',
%               'struct' or 'char'.  Specifying 'cell' produces a cell
%               array of strings, the strings containing the full paths of
%               the chosen files.  'Struct' returns a structure array like
%               the result of the dir function except that the 'name' field
%               contains a full path instead of just the file name.  'Char'
%               returns a character array of the full paths.  This is most
%               useful when you have just one file and want it in a string
%               instead of a cell array containing just one string.  The
%               default is 'cell'.
%
% All properties and values are case-insensitive and need only be
% unambiguous.  For example,
%
%   files = uipickfiles('num',1,'out','ch')
%
% is valid usage.

% Version: 1.15, 2 March 2012
% Author:  Douglas M. Schwarz
% Email:   dmschwarz=ieee*org, dmschwarz=urgrad*rochester*edu
% Real_email = regexprep(Email,{'=','*'},{'@','.'})


% Define properties and set default values.
prop.filterspec = '*';
prop.refilter = '';
prop.redirs = false;
prop.type = {};
prop.prompt = 'Select files';
prop.numfiles = [];
prop.append = [];
prop.output = 'cell';

% Process inputs and set prop fields.
prop = parsepropval(prop,varargin{:});

% Validate FilterSpec property.
if isempty(prop.filterspec)
	prop.filterspec = '*';
end
if ~ischar(prop.filterspec)
	error('FilterSpec property must contain a string.')
end

% Validate REFilter property.
if ~ischar(prop.refilter)
	error('REFilter property must contain a string.')
end

% Validate REDirs property.
if ~isscalar(prop.redirs)
	error('REDirs property must contain a scalar.')
end

% Validate Type property.
if isempty(prop.type)
elseif iscellstr(prop.type) && isscalar(prop.type)
	prop.type = repmat(prop.type(:),1,2);
elseif iscellstr(prop.type) && size(prop.type,2) == 2
else
	error(['Type property must be empty or a cellstr vector or ',...
		'a 2-column cellstr matrix.'])
end

% Validate Prompt property.
if ~ischar(prop.prompt)
	error('Prompt property must contain a string.')
end

% Validate NumFiles property.
if numel(prop.numfiles) > 2 || any(prop.numfiles < 0)
	error('NumFiles must be empty, a scalar or two-element vector.')
end
prop.numfiles = unique(prop.numfiles);
if isequal(prop.numfiles,1)
	numstr = 'Select exactly 1 file.';
elseif length(prop.numfiles) == 1
	numstr = sprintf('Select exactly %d items.',prop.numfiles);
else
	numstr = sprintf('Select %d to %d items.',prop.numfiles);
end

% Validate Append property and initialize pick data.
if isstruct(prop.append) && isfield(prop.append,'name')
	prop.append = {prop.append.name};
elseif ischar(prop.append)
	prop.append = cellstr(prop.append);
end
if isempty(prop.append)
	file_picks = {};
	full_file_picks = {};
	dir_picks = dir(' ');  % Create empty directory structure.
elseif iscellstr(prop.append) && isvector(prop.append)
	num_items = length(prop.append);
	file_picks = cell(1,num_items);
	full_file_picks = cell(1,num_items);
	dir_fn = fieldnames(dir(' '));
	dir_picks = repmat(cell2struct(cell(length(dir_fn),1),dir_fn(:)),...
		num_items,1);
	for item = 1:num_items
		if exist(prop.append{item},'dir') && ...
				~any(strcmp(full_file_picks,prop.append{item}))
			full_file_picks{item} = prop.append{item};
			[unused,fn,ext] = fileparts(prop.append{item});
			file_picks{item} = [fn,ext];
			temp = dir(fullfile(prop.append{item},'..'));
			if ispc || ismac
				thisdir = strcmpi({temp.name},[fn,ext]);
			else
				thisdir = strcmp({temp.name},[fn,ext]);
			end
			dir_picks(item) = temp(thisdir);
			dir_picks(item).name = prop.append{item};
		elseif exist(prop.append{item},'file') && ...
				~any(strcmp(full_file_picks,prop.append{item}))
			full_file_picks{item} = prop.append{item};
			[unused,fn,ext] = fileparts(prop.append{item});
			file_picks{item} = [fn,ext];
			dir_picks(item) = dir(prop.append{item});
			dir_picks(item).name = prop.append{item};
		else
			continue
		end
	end
	% Remove items which no longer exist.
	missing = cellfun(@isempty,full_file_picks);
	full_file_picks(missing) = [];
	file_picks(missing) = [];
	dir_picks(missing) = [];
else
	error('Append must be a cell, struct or char array.')
end

% Validate Output property.
legal_outputs = {'cell','struct','char'};
out_idx = find(strncmpi(prop.output,legal_outputs,length(prop.output)));
if length(out_idx) == 1
	prop.output = legal_outputs{out_idx};
else
	error(['Value of ''Output'' property, ''%s'', is illegal or '...
		'ambiguous.'],prop.output)
end


% Set style preference for display of folders.
%   1 => folder icon before and filesep after
%   2 => bullet before and filesep after
%   3 => filesep after only
folder_style_pref = 1;
fsdata = set_folder_style(folder_style_pref);

% Initialize file lists.
if exist(prop.filterspec,'dir')
	current_dir = prop.filterspec;
	filter = '*';
else
	[current_dir,f,e] = fileparts(prop.filterspec);
	filter = [f,e];
end
if isempty(current_dir)
	current_dir = pwd;
end
if isempty(filter)
	filter = '*';
end
re_filter = prop.refilter;
full_filter = fullfile(current_dir,filter);
network_volumes = {};
[path_cell,new_network_vol] = path2cell(current_dir);
if exist(new_network_vol,'dir')
	network_volumes = unique([network_volumes,{new_network_vol}]);
end
fdir = filtered_dir(full_filter,re_filter,prop.redirs,...
	@(x)file_sort(x,[1 0 0]));
filenames = {fdir.name}';
filenames = annotate_file_names(filenames,fdir,fsdata);

% Initialize some data.
show_full_path = false;
nodupes = true;

% Get history preferences and set history.
history = getpref('uipickfiles','history',...
	struct('name',current_dir,'time',now));
default_history_size = 15;
history_size = getpref('uipickfiles','history_size',default_history_size);
history = update_history(history,current_dir,now,history_size);

% Get figure position preference and create figure.
gray = get(0,'DefaultUIControlBackgroundColor');
if ispref('uipickfiles','figure_position');
	fig_pos = getpref('uipickfiles','figure_position');
	fig = figure('Position',fig_pos,...
		'Color',gray,...
		'MenuBar','none',...
		'WindowStyle','modal',...
		'Resize','on',...
		'NumberTitle','off',...
		'Name',prop.prompt,...
		'IntegerHandle','off',...
		'CloseRequestFcn',@cancel,...
		'ButtonDownFcn',@reset_figure_size,...
		'KeyPressFcn',@keypressmisc,...
		'Visible','off');
else
	fig_pos = [0 0 740 494];
	fig = figure('Position',fig_pos,...
		'Color',gray,...
		'MenuBar','none',...
		'WindowStyle','modal',...
		'Resize','on',...
		'NumberTitle','off',...
		'Name',prop.prompt,...
		'IntegerHandle','off',...
		'CloseRequestFcn',@cancel,...
		'CreateFcn',{@movegui,'center'},...
		'ButtonDownFcn',@reset_figure_size,...
		'KeyPressFcn',@keypressmisc,...
		'Visible','off');
end

% Set system-dependent items.
if ismac
	set(fig,'DefaultUIControlFontName','Lucida Grande')
	set(fig,'DefaultUIControlFontSize',9)
	sort_ctrl_size = 8;
	mod_key = 'command';
	action = 'Control-click';
elseif ispc
	set(fig,'DefaultUIControlFontName','Tahoma')
	set(fig,'DefaultUIControlFontSize',8)
	sort_ctrl_size = 7;
	mod_key = 'control';
	action = 'Right-click';
else
	sort_ctrl_size = get(fig,'DefaultUIControlFontSize') - 1;
	mod_key = 'control';
	action = 'Right-click';
end

% Create uicontrols.
frame1 = uicontrol('Style','frame',...
	'Position',[255 260 110 70]);
frame2 = uicontrol('Style','frame',...
	'Position',[275 135 110 100]);

navlist = uicontrol('Style','listbox',...
	'Position',[10 10 250 320],...
	'String',filenames,...
	'Value',[],...
	'BackgroundColor','w',...
	'Callback',@clicknav,...
	'KeyPressFcn',@keypressnav,...
	'Max',2);

tri_up = repmat([1 1 1 1 0 1 1 1 1;1 1 1 0 0 0 1 1 1;1 1 0 0 0 0 0 1 1;...
	1 0 0 0 0 0 0 0 1],[1 1 3]);
tri_up(tri_up == 1) = NaN;
tri_down = tri_up(end:-1:1,:,:);
tri_null = NaN(4,9,3);
tri_icon = {tri_down,tri_null,tri_up};
sort_state = [1 0 0];
last_sort_state = [1 1 1];
sort_cb = zeros(1,3);
sort_cb(1) = uicontrol('Style','checkbox',...
	'Position',[15 331 70 15],...
	'String','Name',...
	'FontSize',sort_ctrl_size,...
	'Value',sort_state(1),...
	'CData',tri_icon{sort_state(1)+2},...
	'KeyPressFcn',@keypressmisc,...
	'Callback',{@sort_type,1});
sort_cb(2) = uicontrol('Style','checkbox',...
	'Position',[85 331 70 15],...
	'String','Date',...
	'FontSize',sort_ctrl_size,...
	'Value',sort_state(2),...
	'CData',tri_icon{sort_state(2)+2},...
	'KeyPressFcn',@keypressmisc,...
	'Callback',{@sort_type,2});
sort_cb(3) = uicontrol('Style','checkbox',...
	'Position',[155 331 70 15],...
	'String','Size',...
	'FontSize',sort_ctrl_size,...
	'Value',sort_state(3),...
	'CData',tri_icon{sort_state(3)+2},...
	'KeyPressFcn',@keypressmisc,...
	'Callback',{@sort_type,3});

pickslist = uicontrol('Style','listbox',...
	'Position',[380 10 350 320],...
	'String',file_picks,...
	'BackgroundColor','w',...
	'Callback',@clickpicks,...
	'KeyPressFcn',@keypresslist,...
	'Max',2,...
	'Value',[]);

openbut = uicontrol('Style','pushbutton',...
	'Position',[270 300 80 20],...
	'String','Open',...
	'Enable','off',...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@open);

arrow = [ ...
	'        1   ';
	'        10  ';
	'         10 ';
	'000000000000';
	'         10 ';
	'        10  ';
	'        1   '];
cmap = NaN(128,3);
cmap(double('10'),:) = [0.5 0.5 0.5;0 0 0];
arrow_im = NaN(7,76,3);
arrow_im(:,45:56,:) = ind2rgb(double(arrow),cmap);
addbut = uicontrol('Style','pushbutton',...
	'Position',[270 270 80 20],...
	'String','Add    ',...
	'Enable','off',...
	'CData',arrow_im,...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@add);

removebut = uicontrol('Style','pushbutton',...
	'Position',[290 205 80 20],...
	'String','Remove',...
	'Enable','off',...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@remove);
moveupbut = uicontrol('Style','pushbutton',...
	'Position',[290 175 80 20],...
	'String','Move Up',...
	'Enable','off',...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@moveup);
movedownbut = uicontrol('Style','pushbutton',...
	'Position',[290 145 80 20],...
	'String','Move Down',...
	'Enable','off',...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@movedown);

dir_popup = uicontrol('Style','popupmenu',...
	'Position',[10 350 225 20],...
	'BackgroundColor','w',...
	'String',path_cell,...
	'Value',length(path_cell),...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@dirpopup);

uparrow = [ ...
	'  0     ';
	' 000    ';
	'00000   ';
	'  0     ';
	'  0     ';
	'  0     ';
	'  000000'];
cmap = NaN(128,3);
cmap(double('0'),:) = [0 0 0];
uparrow_im = ind2rgb(double(uparrow),cmap);
up_dir_but = uicontrol('Style','pushbutton',...
	'Position',[240 350 20 20],...
	'CData',uparrow_im,...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@dir_up_one,...
	'ToolTip','Go to parent folder');
if length(path_cell) > 1
	set(up_dir_but','Enable','on')
else
	set(up_dir_but','Enable','off')
end

hist_cm = uicontextmenu;
pathbox = uicontrol('Style','edit',...
	'Position',[10 375 250 26],...
	'BackgroundColor','w',...
	'String',current_dir,...
	'HorizontalAlignment','left',...
	'TooltipString',[action,' to display folder history'],...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@change_path,...
	'UIContextMenu',hist_cm);
label1 = uicontrol('Style','text',...
	'Position',[10 401 250 16],...
	'String','Current Folder',...
	'HorizontalAlignment','center',...
	'TooltipString',[action,' to display folder history'],...
	'UIContextMenu',hist_cm);
hist_menus = [];
make_history_cm()

label2 = uicontrol('Style','text',...
	'Position',[10 440+36 80 17],...
	'String','File Filter',...
	'HorizontalAlignment','left');
label3 = uicontrol('Style','text',...
	'Position',[100 440+36 160 17],...
	'String','Reg. Exp. Filter',...
	'HorizontalAlignment','left');
showallfiles = uicontrol('Style','checkbox',...
	'Position',[270 420+32 110 20],...
	'String','Show All Files',...
	'Value',0,...
	'HorizontalAlignment','left',...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@togglefilter);
refilterdirs = uicontrol('Style','checkbox',...
	'Position',[270 420+10 100 20],...
	'String','RE Filter Dirs',...
	'Value',prop.redirs,...
	'HorizontalAlignment','left',...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@toggle_refiltdirs);
filter_ed = uicontrol('Style','edit',...
	'Position',[10 420+30 80 26],...
	'BackgroundColor','w',...
	'String',filter,...
	'HorizontalAlignment','left',...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@setfilspec);
refilter_ed = uicontrol('Style','edit',...
	'Position',[100 420+30 160 26],...
	'BackgroundColor','w',...
	'String',re_filter,...
	'HorizontalAlignment','left',...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@setrefilter);

type_value = 1;
type_popup = uicontrol('Style','popupmenu',...
	'Position',[10 422 250 20],...
	'String','',...
	'BackgroundColor','w',...
	'Value',type_value,...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@filter_type_callback,...
	'Visible','off');
if ~isempty(prop.type)
	set(filter_ed,'String',prop.type{type_value,1})
	setfilspec()
	set(type_popup,'String',prop.type(:,2),'Visible','on')
end

viewfullpath = uicontrol('Style','checkbox',...
	'Position',[380 335 230 20],...
	'String','Show full paths',...
	'Value',show_full_path,...
	'HorizontalAlignment','left',...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@showfullpath);
remove_dupes = uicontrol('Style','checkbox',...
	'Position',[380 360 280 20],...
	'String','Remove duplicates (as per full path)',...
	'Value',nodupes,...
	'HorizontalAlignment','left',...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@removedupes);
recall_button = uicontrol('Style','pushbutton',...
	'Position',[665 335 65 20],...
	'String','Recall',...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@recall,...
	'ToolTip','Add previously selected items');
label4 = uicontrol('Style','text',...
	'Position',[380 405 350 20],...
	'String','Selected Items',...
	'HorizontalAlignment','center');
done_button = uicontrol('Style','pushbutton',...
	'Position',[280 80 80 30],...
	'String','Done',...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@done);
cancel_button = uicontrol('Style','pushbutton',...
	'Position',[280 30 80 30],...
	'String','Cancel',...
	'KeyPressFcn',@keypressmisc,...
	'Callback',@cancel);

% If necessary, add warning about number of items to be selected.
num_files_warn = uicontrol('Style','text',...
	'Position',[380 385 350 16],...
	'String',numstr,...
	'ForegroundColor',[0.8 0 0],...
	'HorizontalAlignment','center',...
	'Visible','off');
if ~isempty(prop.numfiles)
	set(num_files_warn,'Visible','on')
end

resize()
% Make figure visible and hide handle.
set(fig,'HandleVisibility','off',...
	'Visible','on',...
	'ResizeFcn',@resize)

% Wait until figure is closed.
uiwait(fig)

% Compute desired output.
switch prop.output
	case 'cell'
		out = full_file_picks;
	case 'struct'
		out = dir_picks(:);
	case 'char'
		out = char(full_file_picks);
	case 'cancel'
		out = 0;
end

% Update history preference.
setpref('uipickfiles','history',history)
if ~isempty(full_file_picks) && ~strcmp(prop.output,'cancel')
	setpref('uipickfiles','full_file_picks',full_file_picks)
end

% Update figure position preference.
setpref('uipickfiles','figure_position',fig_pos)


% ----------------- Callback nested functions ----------------

	function add(varargin)
		values = get(navlist,'Value');
		for i = 1:length(values)
			dir_pick = fdir(values(i));
			pick = dir_pick.name;
			pick_full = fullfile(current_dir,pick);
			dir_pick.name = pick_full;
			if ~nodupes || ~any(strcmp(full_file_picks,pick_full))
				file_picks{end + 1} = pick; %#ok<AGROW>
				full_file_picks{end + 1} = pick_full; %#ok<AGROW>
				dir_picks(end + 1) = dir_pick; %#ok<AGROW>
			end
		end
		if show_full_path
			set(pickslist,'String',full_file_picks,'Value',[]);
		else
			set(pickslist,'String',file_picks,'Value',[]);
		end
		set([removebut,moveupbut,movedownbut],'Enable','off');
	end

	function remove(varargin)
		values = get(pickslist,'Value');
		file_picks(values) = [];
		full_file_picks(values) = [];
		dir_picks(values) = [];
		top = get(pickslist,'ListboxTop');
		num_above_top = sum(values < top);
		top = top - num_above_top;
		num_picks = length(file_picks);
		new_value = min(min(values) - num_above_top,num_picks);
		if num_picks == 0
			new_value = [];
			set([removebut,moveupbut,movedownbut],'Enable','off')
		end
		if show_full_path
			set(pickslist,'String',full_file_picks,'Value',new_value,...
				'ListboxTop',top)
		else
			set(pickslist,'String',file_picks,'Value',new_value,...
				'ListboxTop',top)
		end
	end

	function open(varargin)
		values = get(navlist,'Value');
		if fdir(values).isdir
			set(fig,'pointer','watch')
			drawnow
			% Convert 'My Documents' to 'Documents' when necessary.
			if ispc && strcmp(fdir(values).name,'My Documents')
				if isempty(dir(fullfile(current_dir,fdir(values).name)))
					values = find(strcmp({fdir.name},'Documents'));
				end
			end
			current_dir = fullfile(current_dir,fdir(values).name);
			history = update_history(history,current_dir,now,history_size);
			make_history_cm()
			full_filter = fullfile(current_dir,filter);
			path_cell = path2cell(current_dir);
			fdir = filtered_dir(full_filter,re_filter,prop.redirs,...
				@(x)file_sort(x,sort_state));
			filenames = {fdir.name}';
			filenames = annotate_file_names(filenames,fdir,fsdata);
			set(dir_popup,'String',path_cell,'Value',length(path_cell))
			if length(path_cell) > 1
				set(up_dir_but','Enable','on')
			else
				set(up_dir_but','Enable','off')
			end
			set(pathbox,'String',current_dir)
			set(navlist,'ListboxTop',1,'Value',[],'String',filenames)
			set(addbut,'Enable','off')
			set(openbut,'Enable','off')
			set(fig,'pointer','arrow')
		end
	end

	function clicknav(varargin)
		value = get(navlist,'Value');
		nval = length(value);
		dbl_click_fcn = @add;
		switch nval
			case 0
				set([addbut,openbut],'Enable','off')
			case 1
				set(addbut,'Enable','on');
				if fdir(value).isdir
					set(openbut,'Enable','on')
					dbl_click_fcn = @open;
				else
					set(openbut,'Enable','off')
				end
			otherwise
				set(addbut,'Enable','on')
				set(openbut,'Enable','off')
		end
		if strcmp(get(fig,'SelectionType'),'open')
			dbl_click_fcn();
		end
	end

	function keypressmisc(h,evt) %#ok<INUSL>
		if strcmp(evt.Key,'escape') && isequal(evt.Modifier,cell(1,0))
			% Escape key means Cancel.
			cancel()
		end
	end

	function keypressnav(h,evt) %#ok<INUSL>
		if length(path_cell) > 1 && strcmp(evt.Key,'backspace') && ...
				isequal(evt.Modifier,cell(1,0))
			% Backspace means go to parent folder.
			dir_up_one()
		elseif strcmp(evt.Key,'f') && isequal(evt.Modifier,{mod_key})
			% Control-F (Command-F on Mac) means select all files.
			value = find(~[fdir.isdir]);
			set(navlist,'Value',value)
		elseif strcmp(evt.Key,'rightarrow') && ...
				isequal(evt.Modifier,cell(1,0))
			% Right arrow key means select the file.
			add()
		elseif strcmp(evt.Key,'escape') && isequal(evt.Modifier,cell(1,0))
			% Escape key means Cancel.
			cancel()
		end
	end

	function keypresslist(h,evt) %#ok<INUSL>
		if strcmp(evt.Key,'backspace') && isequal(evt.Modifier,cell(1,0))
			% Backspace means remove item from list.
			remove()
		elseif strcmp(evt.Key,'escape') && isequal(evt.Modifier,cell(1,0))
			% Escape key means Cancel.
			cancel()
		end
	end

	function clickpicks(varargin)
		value = get(pickslist,'Value');
		if isempty(value)
			set([removebut,moveupbut,movedownbut],'Enable','off')
		else
			set(removebut,'Enable','on')
			if min(value) == 1
				set(moveupbut,'Enable','off')
			else
				set(moveupbut,'Enable','on')
			end
			if max(value) == length(file_picks)
				set(movedownbut,'Enable','off')
			else
				set(movedownbut,'Enable','on')
			end
		end
		if strcmp(get(fig,'SelectionType'),'open')
			remove();
		end
	end

	function recall(varargin)
		if ispref('uipickfiles','full_file_picks')
			ffp = getpref('uipickfiles','full_file_picks');
		else
			ffp = {};
		end
		for i = 1:length(ffp)
			if exist(ffp{i},'dir') && ...
					(~nodupes || ~any(strcmp(full_file_picks,ffp{i})))
				full_file_picks{end + 1} = ffp{i}; %#ok<AGROW>
				[unused,fn,ext] = fileparts(ffp{i});
				file_picks{end + 1} = [fn,ext]; %#ok<AGROW>
				temp = dir(fullfile(ffp{i},'..'));
				if ispc || ismac
					thisdir = strcmpi({temp.name},[fn,ext]);
				else
					thisdir = strcmp({temp.name},[fn,ext]);
				end
				dir_picks(end + 1) = temp(thisdir); %#ok<AGROW>
				dir_picks(end).name = ffp{i};
			elseif exist(ffp{i},'file') && ...
					(~nodupes || ~any(strcmp(full_file_picks,ffp{i})))
				full_file_picks{end + 1} = ffp{i}; %#ok<AGROW>
				[unused,fn,ext] = fileparts(ffp{i});
				file_picks{end + 1} = [fn,ext]; %#ok<AGROW>
				dir_picks(end + 1) = dir(ffp{i}); %#ok<AGROW>
				dir_picks(end).name = ffp{i};
			end
		end
		if show_full_path
			set(pickslist,'String',full_file_picks,'Value',[]);
		else
			set(pickslist,'String',file_picks,'Value',[]);
		end
		set([removebut,moveupbut,movedownbut],'Enable','off');
	end

	function sort_type(h,evt,cb) %#ok<INUSL>
		if sort_state(cb)
			sort_state(cb) = -sort_state(cb);
			last_sort_state(cb) = sort_state(cb);
		else
			sort_state = zeros(1,3);
			sort_state(cb) = last_sort_state(cb);
		end
		set(sort_cb,{'CData'},tri_icon(sort_state + 2)')
		
		fdir = filtered_dir(full_filter,re_filter,prop.redirs,...
				@(x)file_sort(x,sort_state));
		filenames = {fdir.name}';
		filenames = annotate_file_names(filenames,fdir,fsdata);
		set(dir_popup,'String',path_cell,'Value',length(path_cell))
		if length(path_cell) > 1
			set(up_dir_but','Enable','on')
		else
			set(up_dir_but','Enable','off')
		end
		set(pathbox,'String',current_dir)
		set(navlist,'String',filenames,'Value',[])
		set(addbut,'Enable','off')
		set(openbut,'Enable','off')
		set(fig,'pointer','arrow')
	end

	function dirpopup(varargin)
		value = get(dir_popup,'Value');
		container = path_cell{min(value + 1,length(path_cell))};
		path_cell = path_cell(1:value);
		set(fig,'pointer','watch')
		drawnow
		if ispc && value == 1
			current_dir = '';
			full_filter = filter;
			drives = getdrives(network_volumes);
			num_drives = length(drives);
			temp = tempname;
			mkdir(temp)
			dir_temp = dir(temp);
			rmdir(temp)
			fdir = repmat(dir_temp(1),num_drives,1);
			[fdir.name] = deal(drives{:});
		else
			current_dir = cell2path(path_cell);
			history = update_history(history,current_dir,now,history_size);
			make_history_cm()
			full_filter = fullfile(current_dir,filter);
			fdir = filtered_dir(full_filter,re_filter,prop.redirs,...
				@(x)file_sort(x,sort_state));
		end
		filenames = {fdir.name}';
		selected = find(strcmp(filenames,container));
		filenames = annotate_file_names(filenames,fdir,fsdata);
		set(dir_popup,'String',path_cell,'Value',length(path_cell))
		if length(path_cell) > 1
			set(up_dir_but','Enable','on')
		else
			set(up_dir_but','Enable','off')
		end
		set(pathbox,'String',current_dir)
		set(navlist,'String',filenames,'Value',selected)
		set(addbut,'Enable','off')
		set(fig,'pointer','arrow')
	end

	function dir_up_one(varargin)
		value = length(path_cell) - 1;
		container = path_cell{value + 1};
		path_cell = path_cell(1:value);
		set(fig,'pointer','watch')
		drawnow
		if ispc && value == 1
			current_dir = '';
			full_filter = filter;
			drives = getdrives(network_volumes);
			num_drives = length(drives);
			temp = tempname;
			mkdir(temp)
			dir_temp = dir(temp);
			rmdir(temp)
			fdir = repmat(dir_temp(1),num_drives,1);
			[fdir.name] = deal(drives{:});
		else
			current_dir = cell2path(path_cell);
			history = update_history(history,current_dir,now,history_size);
			make_history_cm()
			full_filter = fullfile(current_dir,filter);
			fdir = filtered_dir(full_filter,re_filter,prop.redirs,...
				@(x)file_sort(x,sort_state));
		end
		filenames = {fdir.name}';
		selected = find(strcmp(filenames,container));
		filenames = annotate_file_names(filenames,fdir,fsdata);
		set(dir_popup,'String',path_cell,'Value',length(path_cell))
		if length(path_cell) > 1
			set(up_dir_but','Enable','on')
		else
			set(up_dir_but','Enable','off')
		end
		set(pathbox,'String',current_dir)
		set(navlist,'String',filenames,'Value',selected)
		set(addbut,'Enable','off')
		set(fig,'pointer','arrow')
	end

	function change_path(varargin)
		set(fig,'pointer','watch')
		drawnow
		proposed_path = get(pathbox,'String');
		% Process any folders named '..'.
		proposed_path_cell = path2cell(proposed_path);
		ddots = strcmp(proposed_path_cell,'..');
		ddots(find(ddots) - 1) = true;
		proposed_path_cell(ddots) = [];
		proposed_path = cell2path(proposed_path_cell);
		% Check for existance of folder.
		if ~exist(proposed_path,'dir')
			set(fig,'pointer','arrow')
			uiwait(errordlg(['Folder "',proposed_path,...
				'" does not exist.'],'','modal'))
			return
		end
		current_dir = proposed_path;
		history = update_history(history,current_dir,now,history_size);
		make_history_cm()
		full_filter = fullfile(current_dir,filter);
		[path_cell,new_network_vol] = path2cell(current_dir);
		if exist(new_network_vol,'dir')
			network_volumes = unique([network_volumes,{new_network_vol}]);
		end
		fdir = filtered_dir(full_filter,re_filter,prop.redirs,...
				@(x)file_sort(x,sort_state));
		filenames = {fdir.name}';
		filenames = annotate_file_names(filenames,fdir,fsdata);
		set(dir_popup,'String',path_cell,'Value',length(path_cell))
		if length(path_cell) > 1
			set(up_dir_but','Enable','on')
		else
			set(up_dir_but','Enable','off')
		end
		set(pathbox,'String',current_dir)
		set(navlist,'String',filenames,'Value',[])
		set(addbut,'Enable','off')
		set(openbut,'Enable','off')
		set(fig,'pointer','arrow')
	end

	function showfullpath(varargin)
		show_full_path = get(viewfullpath,'Value');
		if show_full_path
			set(pickslist,'String',full_file_picks)
		else
			set(pickslist,'String',file_picks)
		end
	end

	function removedupes(varargin)
		nodupes = get(remove_dupes,'Value');
		if nodupes
			num_picks = length(full_file_picks);
			[unused,rev_order] = unique(full_file_picks(end:-1:1)); %#ok<SETNU>
			order = sort(num_picks + 1 - rev_order);
			full_file_picks = full_file_picks(order);
			file_picks = file_picks(order);
			dir_picks = dir_picks(order);
			if show_full_path
				set(pickslist,'String',full_file_picks,'Value',[])
			else
				set(pickslist,'String',file_picks,'Value',[])
			end
			set([removebut,moveupbut,movedownbut],'Enable','off')
		end
	end

	function moveup(varargin)
		value = get(pickslist,'Value');
		set(removebut,'Enable','on')
		n = length(file_picks);
		omega = 1:n;
		index = zeros(1,n);
		index(value - 1) = omega(value);
		index(setdiff(omega,value - 1)) = omega(setdiff(omega,value));
		file_picks = file_picks(index);
		full_file_picks = full_file_picks(index);
		dir_picks = dir_picks(index);
		value = value - 1;
		if show_full_path
			set(pickslist,'String',full_file_picks,'Value',value)
		else
			set(pickslist,'String',file_picks,'Value',value)
		end
		if min(value) == 1
			set(moveupbut,'Enable','off')
		end
		set(movedownbut,'Enable','on')
	end

	function movedown(varargin)
		value = get(pickslist,'Value');
		set(removebut,'Enable','on')
		n = length(file_picks);
		omega = 1:n;
		index = zeros(1,n);
		index(value + 1) = omega(value);
		index(setdiff(omega,value + 1)) = omega(setdiff(omega,value));
		file_picks = file_picks(index);
		full_file_picks = full_file_picks(index);
		dir_picks = dir_picks(index);
		value = value + 1;
		if show_full_path
			set(pickslist,'String',full_file_picks,'Value',value)
		else
			set(pickslist,'String',file_picks,'Value',value)
		end
		if max(value) == n
			set(movedownbut,'Enable','off')
		end
		set(moveupbut,'Enable','on')
	end

	function togglefilter(varargin)
		set(fig,'pointer','watch')
		drawnow
		value = get(showallfiles,'Value');
		if value
			filter = '*';
			re_filter = '';
			set([filter_ed,refilter_ed],'Enable','off')
		else
			filter = get(filter_ed,'String');
			re_filter = get(refilter_ed,'String');
			set([filter_ed,refilter_ed],'Enable','on')
		end
		full_filter = fullfile(current_dir,filter);
		fdir = filtered_dir(full_filter,re_filter,prop.redirs,...
				@(x)file_sort(x,sort_state));
		filenames = {fdir.name}';
		filenames = annotate_file_names(filenames,fdir,fsdata);
		set(navlist,'String',filenames,'Value',[])
		set(addbut,'Enable','off')
		set(fig,'pointer','arrow')
	end

	function toggle_refiltdirs(varargin)
		set(fig,'pointer','watch')
		drawnow
		value = get(refilterdirs,'Value');
		prop.redirs = value;
		full_filter = fullfile(current_dir,filter);
		fdir = filtered_dir(full_filter,re_filter,prop.redirs,...
				@(x)file_sort(x,sort_state));
		filenames = {fdir.name}';
		filenames = annotate_file_names(filenames,fdir,fsdata);
		set(navlist,'String',filenames,'Value',[])
		set(addbut,'Enable','off')
		set(fig,'pointer','arrow')
	end

	function setfilspec(varargin)
		set(fig,'pointer','watch')
		drawnow
		filter = get(filter_ed,'String');
		if isempty(filter)
			filter = '*';
			set(filter_ed,'String',filter)
		end
		% Process file spec if a subdirectory was included.
		[p,f,e] = fileparts(filter);
		if ~isempty(p)
			newpath = fullfile(current_dir,p,'');
			set(pathbox,'String',newpath)
			filter = [f,e];
			if isempty(filter)
				filter = '*';
			end
			set(filter_ed,'String',filter)
			change_path();
		end
		full_filter = fullfile(current_dir,filter);
		fdir = filtered_dir(full_filter,re_filter,prop.redirs,...
				@(x)file_sort(x,sort_state));
		filenames = {fdir.name}';
		filenames = annotate_file_names(filenames,fdir,fsdata);
		set(navlist,'String',filenames,'Value',[])
		set(addbut,'Enable','off')
		set(fig,'pointer','arrow')
	end

	function setrefilter(varargin)
		set(fig,'pointer','watch')
		drawnow
		re_filter = get(refilter_ed,'String');
		fdir = filtered_dir(full_filter,re_filter,prop.redirs,...
				@(x)file_sort(x,sort_state));
		filenames = {fdir.name}';
		filenames = annotate_file_names(filenames,fdir,fsdata);
		set(navlist,'String',filenames,'Value',[])
		set(addbut,'Enable','off')
		set(fig,'pointer','arrow')
	end

	function filter_type_callback(varargin)
		type_value = get(type_popup,'Value');
		set(filter_ed,'String',prop.type{type_value,1})
		setfilspec()
	end

	function done(varargin)
		% Optional shortcut: click on a file and press 'Done'.
% 		if isempty(full_file_picks) && strcmp(get(addbut,'Enable'),'on')
% 			add();
% 		end
		numfiles = length(full_file_picks);
		if ~isempty(prop.numfiles)
			if numfiles < prop.numfiles(1)
				msg = {'Too few items selected.',numstr};
				uiwait(errordlg(msg,'','modal'))
				return
			elseif numfiles > prop.numfiles(end)
				msg = {'Too many items selected.',numstr};
				uiwait(errordlg(msg,'','modal'))
				return
			end
		end
		fig_pos = get(fig,'Position');
		delete(fig)
	end

	function cancel(varargin)
		prop.output = 'cancel';
		fig_pos = get(fig,'Position');
		delete(fig)
	end

	function history_cb(varargin)
		set(fig,'pointer','watch')
		drawnow
		current_dir = history(varargin{3}).name;
		history = update_history(history,current_dir,now,history_size);
		make_history_cm()
		full_filter = fullfile(current_dir,filter);
		path_cell = path2cell(current_dir);
		fdir = filtered_dir(full_filter,re_filter,prop.redirs,...
				@(x)file_sort(x,sort_state));
		filenames = {fdir.name}';
		filenames = annotate_file_names(filenames,fdir,fsdata);
		set(dir_popup,'String',path_cell,'Value',length(path_cell))
		if length(path_cell) > 1
			set(up_dir_but','Enable','on')
		else
			set(up_dir_but','Enable','off')
		end
		set(pathbox,'String',current_dir)
		set(navlist,'ListboxTop',1,'Value',[],'String',filenames)
		set(addbut,'Enable','off')
		set(openbut,'Enable','off')
		set(fig,'pointer','arrow')
	end

	function clear_history(varargin)
		history = update_history(history(1),'',[],history_size);
		make_history_cm()
	end

	function set_history_size(varargin)
		result_cell = inputdlg('Number of Recent Folders:','',1,...
			{sprintf('%g',history_size)});
		if isempty(result_cell)
			return
		end
		result = sscanf(result_cell{1},'%f');
		if isempty(result) || result < 1
			return
		end
		history_size = result;
		history = update_history(history,'',[],history_size);
		make_history_cm()
		setpref('uipickfiles','history_size',history_size)
	end

	function resize(varargin)
		% Get current figure size.
		P = 'Position';
		pos = get(fig,P);
		w = pos(3); % figure width in pixels
		h = pos(4); % figure height in pixels
		
		% Enforce minimum figure size.
		w = max(w,564);
		h = max(h,443);
		if any(pos(3:4) < [w h])
			pos(3:4) = [w h];
			set(fig,P,pos)
		end
		
		% Change positions of all uicontrols based on the current figure
		% width and height.
		navw_pckw = round([1 1;-350 250]\[w-140;0]);
		navw = navw_pckw(1);
		pckw = navw_pckw(2);
		navp = [10 10 navw h-174];
		pckp = [w-10-pckw 10 pckw h-174];
		set(navlist,P,navp)
		set(pickslist,P,pckp)
		
		set(frame1,P,[navw+5 h-234 110 70])
		set(openbut,P,[navw+20 h-194 80 20])
		set(addbut,P,[navw+20 h-224 80 20])
		
		frame2y = round((h-234 + 110 - 100)/2);
		set(frame2,P,[w-pckw-115 frame2y 110 100])
		set(removebut,P,[w-pckw-100 frame2y+70 80 20])
		set(moveupbut,P,[w-pckw-100 frame2y+40 80 20])
		set(movedownbut,P,[w-pckw-100 frame2y+10 80 20])
		
		set(done_button,P,[navw+30 80 80 30])
		set(cancel_button,P,[navw+30 30 80 30])
		
		set(sort_cb(1),P,[15 h-163 70 15])
		set(sort_cb(2),P,[85 h-163 70 15])
		set(sort_cb(3),P,[155 h-163 70 15])
		
		set(dir_popup,P,[10 h-144 navw-25 20])
		set(up_dir_but,P,[navw-10 h-144 20 20])
		set(pathbox,P,[10 h-119 navw 26])
		set(label1,P,[10 h-93 navw 16])
		
		set(viewfullpath,P,[pckp(1) h-159 230 20])
		set(remove_dupes,P,[pckp(1) h-134 280 20])
		set(recall_button,P,[w-75 h-159 65 20])
		set(label4,P,[w-10-pckw h-89 pckw 20])
		set(num_files_warn,P,[w-10-pckw h-109 pckw 16])
		
		set(label2,P,[10 h-18 80 17])
		set(label3,P,[100 h-18 160 17])
		set(showallfiles,P,[270 h-42 110 20])
		set(refilterdirs,P,[270 h-64 100 20])
		set(filter_ed,P,[10 h-44 80 26])
		set(refilter_ed,P,[100 h-44 160 26])
		set(type_popup,P,[10 h-72 250 20])
	end

	function reset_figure_size(varargin)
		if strcmp(get(fig,'SelectionType'),'open')
			root_units = get(0,'units');
			screen_size = get(0,'ScreenSize');
			set(0,'Units',root_units)
			hw = [740 494];
			pos = [round((screen_size(3:4) - hw - [0 26])/2),hw];
			set(fig,'Position',pos)
			resize()
		end
	end



% ------------------ Other nested functions ------------------

	function make_history_cm
		% Make context menu for history.
		if ~isempty(hist_menus)
			delete(hist_menus)
		end
		num_hist = length(history);
		hist_menus = zeros(1,num_hist+2);
		for i = 1:num_hist
			hist_menus(i) = uimenu(hist_cm,'Label',history(i).name,...
				'Callback',{@history_cb,i});
		end
		hist_menus(num_hist+1) = uimenu(hist_cm,...
			'Label','Clear Menu',...
			'Separator','on',...
			'Callback',@clear_history);
		hist_menus(num_hist+2) = uimenu(hist_cm,'Label',...
			sprintf('Set Number of Recent Folders (%d) ...',history_size),...
			'Callback',@set_history_size);
	end

%end %%% let subfunctions be subfunctions - list is clattered


% -------------------- Subfunctions --------------------

function [c,network_vol] = path2cell(p)
% Turns a path string into a cell array of path elements.
if ispc
	p = strrep(p,'/','\');
	c1 = regexp(p,'(^\\\\[^\\]+\\[^\\]+)|(^[A-Za-z]+:)|[^\\]+','match');
	vol = c1{1};
	c = [{'My Computer'};c1(:)];
	if strncmp(vol,'\\',2)
		network_vol = vol;
	else
		network_vol = '';
	end
else
	c = textscan(p,'%s','delimiter','/');
	c = [{filesep};c{1}(2:end)];
	network_vol = '';
end
end

% --------------------

function p = cell2path(c)
% Turns a cell array of path elements into a path string.
if ispc
	p = fullfile(c{2:end},'');
else
	p = fullfile(c{:},'');
end
end

% --------------------

function d = filtered_dir(full_filter,re_filter,filter_both,sort_fcn)
% Like dir, but applies filters and sorting.
p = fileparts(full_filter);
if isempty(p) && full_filter(1) == '/'
	p = '/';
end
if exist(full_filter,'dir')
	dfiles = dir(' ');
else
	dfiles = dir(full_filter);
end
if ~isempty(dfiles)
	dfiles([dfiles.isdir]) = [];
end

ddir = dir(p);
ddir = ddir([ddir.isdir]);
[unused,index0] = sort(lower({ddir.name})); %#ok<ASGLU>
ddir = ddir(index0);
ddir(strcmp({ddir.name},'.') | strcmp({ddir.name},'..')) = [];

% Additional regular expression filter.
if nargin > 1 && ~isempty(re_filter)
	if ispc || ismac
		no_match = cellfun('isempty',regexpi({dfiles.name},re_filter));
	else
		no_match = cellfun('isempty',regexp({dfiles.name},re_filter));
	end
	dfiles(no_match) = [];
end
if filter_both
	if nargin > 1 && ~isempty(re_filter)
		if ispc || ismac
			no_match = cellfun('isempty',regexpi({ddir.name},re_filter));
		else
			no_match = cellfun('isempty',regexp({ddir.name},re_filter));
		end
		ddir(no_match) = [];
	end
end
% Set navigator style:
%	1 => list all folders before all files, case-insensitive sorting
%	2 => mix files and folders, case-insensitive sorting
%	3 => list all folders before all files, case-sensitive sorting
nav_style = 1;
switch nav_style
	case 1
		[unused,index1] = sort_fcn(dfiles); %#ok<ASGLU>
		[unused,index2] = sort_fcn(ddir); %#ok<ASGLU>
		d = [ddir(index2);dfiles(index1)];
	case 2
		d = [dfiles;ddir];
		[unused,index] = sort(lower({d.name})); %#ok<ASGLU>
		d = d(index);
	case 3
		[unused,index1] = sort({dfiles.name}); %#ok<ASGLU>
		[unused,index2] = sort({ddir.name}); %#ok<ASGLU>
		d = [ddir(index2);dfiles(index1)];
end
end

% --------------------

function [files_sorted,index] = file_sort(files,sort_state)
switch find(sort_state)
	case 1
		[files_sorted,index] = sort(lower({files.name}));
		if sort_state(1) < 0
			files_sorted = files_sorted(end:-1:1);
			index = index(end:-1:1);
		end
	case 2
		if sort_state(2) > 0
			[files_sorted,index] = sort([files.datenum]);
		else
			[files_sorted,index] = sort([files.datenum],'descend');
		end
	case 3
		if sort_state(3) > 0
			[files_sorted,index] = sort([files.bytes]);
		else
			[files_sorted,index] = sort([files.bytes],'descend');
		end
end
end

% --------------------

function drives = getdrives(other_drives)
% Returns a cell array of drive names on Windows.
letters = char('A':'Z');
num_letters = length(letters);
drives = cell(1,num_letters);
for i = 1:num_letters
	if exist([letters(i),':\'],'dir');
		drives{i} = [letters(i),':'];
	end
end
drives(cellfun('isempty',drives)) = [];
if nargin > 0 && iscellstr(other_drives)
	drives = [drives,unique(other_drives)];
end
end

% --------------------

function filenames = annotate_file_names(filenames,dir_listing,fsdata)
% Adds a trailing filesep character to folder names and, optionally,
% prepends a folder icon or bullet symbol.
for i = 1:length(filenames)
	if dir_listing(i).isdir
		filenames{i} = sprintf('%s%s%s%s',fsdata.pre,filenames{i},...
			fsdata.filesep,fsdata.post);
	end
end
end

% --------------------

function history = update_history(history,current_dir,time,history_size)
if ~isempty(current_dir)
	% Insert or move current_dir to the top of the history.
	% If current_dir already appears in the history list, delete it.
	match = strcmp({history.name},current_dir);
	history(match) = [];
	% Prepend history with (current_dir,time).
	history = [struct('name',current_dir,'time',time),history];
end
% Trim history to keep at most <history_size> newest entries.
history = history(1:min(history_size,end));
end

% --------------------

function success = generate_folder_icon(icon_path)
% Black = 1, manila color = 2, transparent = 3.
im = [ ...
	3 3 3 1 1 1 1 3 3 3 3 3;
	3 3 1 2 2 2 2 1 3 3 3 3;
	3 1 1 1 1 1 1 1 1 1 1 3;
	1 2 2 2 2 2 2 2 2 2 2 1;
	1 2 2 2 2 2 2 2 2 2 2 1;
	1 2 2 2 2 2 2 2 2 2 2 1;
	1 2 2 2 2 2 2 2 2 2 2 1;
	1 2 2 2 2 2 2 2 2 2 2 1;
	1 2 2 2 2 2 2 2 2 2 2 1;
	1 1 1 1 1 1 1 1 1 1 1 1];
cmap = [0 0 0;255 220 130;255 255 255]/255;
fid = fopen(icon_path,'w');
if fid > 0
	fclose(fid);
	imwrite(im,cmap,icon_path,'Transparency',[1 1 0])
end
success = exist(icon_path,'file');
end

% --------------------

function fsdata = set_folder_style(folder_style_pref)
% Set style to preference.
fsdata.style = folder_style_pref;
% If style = 1, check to make sure icon image file exists.  If it doesn't,
% try to create it.  If that fails set style = 2.
if fsdata.style == 1
	icon_path = fullfile(prefdir,'uipickfiles_folder_icon.png');
	if ~exist(icon_path,'file')
		success = generate_folder_icon(icon_path);
		if ~success
			fsdata.style = 2;
		end
	end
end
% Set pre and post fields.
if fsdata.style == 1
	icon_url = ['file://localhost/',...
		strrep(strrep(icon_path,':','|'),'\','/')];
	fsdata.pre = sprintf('<html><img src="%s">&nbsp;',icon_url);
	fsdata.post = '</html>';
elseif fsdata.style == 2
	fsdata.pre = '<html><b>&#8226;</b>&nbsp;';
	fsdata.post = '</html>';
elseif fsdata.style == 3
	fsdata.pre = '';
	fsdata.post = '';
end
fsdata.filesep = filesep;

end

% --------------------

function prop = parsepropval(prop,varargin)
% Parse property/value pairs and return a structure.
properties = fieldnames(prop);
arg_index = 1;
while arg_index <= length(varargin)
	arg = varargin{arg_index};
	if ischar(arg)
		prop_index = match_property(arg,properties);
		prop.(properties{prop_index}) = varargin{arg_index + 1};
		arg_index = arg_index + 2;
	elseif isstruct(arg)
		arg_fn = fieldnames(arg);
		for i = 1:length(arg_fn)
			prop_index = match_property(arg_fn{i},properties);
			prop.(properties{prop_index}) = arg.(arg_fn{i});
		end
		arg_index = arg_index + 1;
	else
		error(['Properties must be specified by property/value pairs',...
			' or structures.'])
	end
end
end

% --------------------

function prop_index = match_property(arg,properties)
% Utility function for parsepropval.
prop_index = find(strcmpi(arg,properties));
if isempty(prop_index)
	prop_index = find(strncmpi(arg,properties,length(arg)));
end
if length(prop_index) ~= 1
	error('Property ''%s'' does not exist or is ambiguous.',arg)
end
end

end %%% end of uipickfiles()


% uisave (matlab built-in), modified to return output
function [fn,pn,filterindex] = uisaveX(variables, filename)
%UISAVE GUI Helper function for SAVE
%   
%   UISAVE with no args prompts for file name then saves all variables from
%   workspace.
%
%   UISAVE(VARIABLES) prompts for file name then saves variables listed in
%   VARIABLES, which may be a string or cell array of strings.
%
%   UISAVE(VARIABLES, FILENAME) uses the specified file name as the default
%   instead of "matlab.mat".
%
%   Examples:
%      Example 1:
%           h = 5;
%           uisave('h');
%
%      Example 2:
%           h = 365;
%           uisave('h', 'var1');
%
%   See also SAVE, LOAD
  
% Copyright 1984-2017 The MathWorks, Inc.

if nargin > 0
    variables = convertStringsToChars(variables);
end

if nargin > 1
    filename = convertStringsToChars(filename);
end

whooutput = evalin('caller','who','');
if isempty(whooutput) | (nargin > 0 & ...
    (isempty(variables) | (iscell(variables) & cellfun('isempty',variables)))) %#ok<AND2,OR2>
    errordlg(getString(message('MATLAB:uistring:filedialogs:DialogNoVariablesToSave')))
    return;
end

if nargin == 0
    % no variables specified, save everything
    variables = whooutput;
else
    if ~iscellstr(variables)
        variables = cellstr(variables);
    end

    missing_variables = setdiff(variables, whooutput);
    if ~isempty(missing_variables)
        errordlg([getString(message('MATLAB:uistring:filedialogs:DialogTheseVariablesNotFound')) sprintf('\n    ') sprintf('%s   ',missing_variables{:})]);
        return;
    end
end

if length(whooutput) > 1
    % saving multiple variables to ascii is not very useful
    % the file will not re-load
    filters = {'*.mat','MAT-files (*.mat)'};
else
    filters = {'*.mat','MAT-files (*.mat)'
               '*.txt','ASCII-files (*.txt)'};
end

if nargin < 2
    seed = 'matlab.mat';
else
    seed = filename;
end

% convert input string cell array into a quoted single string like this
% 'a','b','c' where a, b, and c are variable names
variables = sprintf('''%s'',',variables{:});
% trim trailing comma
variables = variables(1:end - 1);


[fn,pn,filterindex] = uiputfile(filters, getString(message('MATLAB:uistring:filedialogs:SaveWorkspaceVariables')), seed);

if ~isequal(fn,0) % fn will be zero if user hits cancel
    % quote the variables string for eval
    fn = strrep(fullfile(pn,fn), '''', '''''');

    % don't use mat if the file ext is '.txt' and 
    useMat = true;
    if (filterindex == 2 && strfind(filters{filterindex}, '.txt'))
        useMat = false;
    end

    % do save and throw errordlg on error
    try
        if useMat
            evalin('caller',['save(''' fn  ''', ' variables ', ''-v7.3'');']);
        else
            evalin('caller',['save(''' fn  ''', ' variables ', ''-ASCII'');']);
        end
    catch ex
    errordlg(ex.getReport('basic', 'hyperlinks', 'off')); 
    end
end
end


%% ----------


%
%  Installation:
%
%  - Copy this file into the XTensions folder in the Imaris installation directory
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%       <Submenu name="Surfaces Functions">
%        <Item name="af_dilatesurf" icon="Matlab">
%          <Command>MatlabXT::af_dilatesurf(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSurfaces">
%          <Item name="af_copysurf" icon="Matlab">
%            <Command>MatlabXT::af_dilatesurf(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
% 
%
%  Description:
%   
%   Dilates a selected surface by a user defined amount. 
% 
%   Author: Adam Fries
%   University of Oregon
%   afries2@uoregon.edu

function af_dilatesurf(aImarisApplicationID)

% connect to Imaris interface
if ~isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
  javaaddpath ImarisLib.jar
  vImarisLib = ImarisLib;
  if ischar(aImarisApplicationID)
    aImarisApplicationID = round(str2double(aImarisApplicationID));
  end
  vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
else
  vImarisApplication = aImarisApplicationID;
end


% the user has to create a scene with some surfaces
vSurpassScene = vImarisApplication.GetSurpassScene;
if isequal(vSurpassScene, [])
  msgbox('Please create some Surfaces in the Surpass scene!');
  return;
end

% get the surfaces
vSurfaces = vImarisApplication.GetFactory.ToSurfaces(vImarisApplication.GetSurpassSelection);

% search the surfaces if not previously selected
if ~vImarisApplication.GetFactory.IsSurfaces(vSurfaces)        
  for vChildIndex = 1:vSurpassScene.GetNumberOfChildren
    vDataItem = vSurpassScene.GetChild(vChildIndex - 1);
    if isequal(vSurfaces, [])
      if vImarisApplication.GetFactory.IsSurfaces(vDataItem)
        vSurfaces = vImarisApplication.GetFactory.ToSurfaces(vDataItem);
      end
    end
  end
  % did we find the surfaces?
  if isequal(vSurfaces, [])
    msgbox('Please create some surfaces!');
    return;
  end
end

vNumberOfSurfaces = vSurfaces.GetNumberOfSurfaces;
vSurfacesName = char(vSurfaces.GetName);
vSurfaces.SetVisible(0);
vIndices = 0:vNumberOfSurfaces;


%%%%%%%%%%%%%%%%%%%%%%
%% function begins here

% get user dilate number
prompt = {'Enter dilation size (\mum):'};
dlgtitle = 'Dilate Surface';
dims = [1 35];
definput = {'5'};
opts.Interpreter = 'tex';
offset = inputdlg(prompt,dlgtitle,dims,definput, opts);


% quit if folks need to cancel
if isempty(offset)
    quit
else
    offset = string(offset);
end


vProgressDisplay = waitbar(0, 'Dilating surface(s)');


% perform distance transform
DistanceTransform(aImarisApplicationID);

% perform channels arithmetics and add offset
nchans = vImarisApplication.GetDataSet.GetSizeC;
ChannelArithmetics(aImarisApplicationID, nchans);

% create the surface off of the newest channel
vDataSet = vImarisApplication.GetImage(0);
nchans = vImarisApplication.GetDataSet.GetSizeC;
vSurfaceDilate = DetectSurfaceWithoutSmoothing(vImarisApplication, vDataSet, nchans, offset);
vSurfaceDilate.SetName([strcat('Dilated_', char(offset), 'um_'), char(vSurfaces.GetName)]);
vSurfaceDilate.SetColorRGBA(vSurfaces.GetColorRGBA);
vSurfaces.GetParent.AddChild(vSurfaceDilate, -1);
    


%% function ends here
%%%%%%%%%%%%%%%%%%%%%

% remove the added channels
xsize = vDataSet.GetSizeX();
ysize = vDataSet.GetSizeY();
zsize = vDataSet.GetSizeZ();
tsize = vDataSet.GetSizeT();
csize = vDataSet.GetSizeC();

vImarisApplication.GetDataSet.Crop(0, xsize, 0, ysize, 0, zsize, 0, csize - 2, 0, tsize);


close(vProgressDisplay);

msgbox('Finished!');

%% detect surfaces without smoothing
function vSurface = DetectSurfaceWithoutSmoothing(aImarisApplication, aDataSet, nchans, dilate)
  
  vSize = [aDataSet.GetSizeX(), aDataSet.GetSizeY(), aDataSet.GetSizeZ()];
 
  vExtentMin = [aDataSet.GetExtendMinX(), aDataSet.GetExtendMinY(), aDataSet.GetExtendMinZ()];
  vExtentMax = [aDataSet.GetExtendMaxX(), aDataSet.GetExtendMaxY(), aDataSet.GetExtendMaxZ()];
  vVoxelSize = (vExtentMax - vExtentMin) ./ vSize;


  vROIs = [];

  vImageProcessing = aImarisApplication.GetImageProcessing();
  vSurface = vImageProcessing.DetectSurfacesWithUpperThreshold(aDataSet, ...
      vROIs, nchans - 1, 0, 0, true, false, 0, true, false, 1 + str2double(dilate), '');
 


%% distance transform
function DistanceTransform(aImarisApplicationID)

% connect to Imaris interface
if ~isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
  javaaddpath ImarisLib.jar
  vImarisLib = ImarisLib;
  if ischar(aImarisApplicationID)
    aImarisApplicationID = round(str2double(aImarisApplicationID));
  end
  vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
else
  vImarisApplication = aImarisApplicationID;
end

vImarisDataSet = vImarisApplication.GetDataSet.Clone;
%Convert dataset to 32bit float
vFloatType = vImarisDataSet.GetType.eTypeFloat;
vImarisDataSet.SetType(vFloatType);

% Get Surpass Surfaces Object
vImarisObject = vImarisApplication.GetSurpassSelection;            
% Check if there is a selection
if isempty(vImarisObject)
  msgbox('A spots/surfaces object must be selected');
  return;
end

vIsSurfaces = false;

% Check if the selection is a surfaces object
if vImarisApplication.GetFactory.IsSurfaces(vImarisObject)
  vImarisObject = vImarisApplication.GetFactory.ToSurfaces(vImarisObject);
  vIsSurfaces = true;
elseif vImarisApplication.GetFactory.IsSpots(vImarisObject)
  vImarisObject = vImarisApplication.GetFactory.ToSpots(vImarisObject);
else
  msgbox('Your selection is not a valid spots or surfaces object');
  return;
end

% if the DataSet is not of type float, display a warning. As the result of
% DistanceTransform will very probably be floating values, a DataSet of
% type int will not be able to display it correctly.
if strcmp(vImarisDataSet.GetType,'eTypeUInt8') || strcmp(vImarisDataSet.GetType,'eTypeUInt16')
  vWarningAnswer = warndlg('Due to the DataSet type the results of the Distance Transform function will probably be truncated! It is best to use it with a float DataSet!','!Warning!');
  waitfor(vWarningAnswer);
end

% do not push: please delete the channel to undo
% vImarisApplication.DataSetPushUndo('Distance Transform'); 

vDataMin = [vImarisDataSet.GetExtendMinX, vImarisDataSet.GetExtendMinY, vImarisDataSet.GetExtendMinZ];
vDataMax = [vImarisDataSet.GetExtendMaxX, vImarisDataSet.GetExtendMaxY, vImarisDataSet.GetExtendMaxZ];
vDataSize = [vImarisDataSet.GetSizeX, vImarisDataSet.GetSizeY, vImarisDataSet.GetSizeZ];

vSelection = 2;
vSpotsXYZ = [];
vSpotsTime = [];

vProgressDisplay = waitbar(0, 'Distance Transform: Preparation');

% Create a new channel where the result will be sent
vNumberOfChannels = vImarisDataSet.GetSizeC;
vImarisDataSet.SetSizeC(vNumberOfChannels + 1);
vImarisDataSet.SetChannelName(vNumberOfChannels,['Distance to ', char(vImarisObject.GetName)]);
vImarisDataSet.SetChannelColorRGBA(vNumberOfChannels, 255*256*256);

vDataSize = [vDataSize, vImarisDataSet.GetSizeT];

if vDataSize(3) == 1
  vBlockSize = [1024, 1024, 1, 1];
else
  vBlockSize = [512, 512, 32, 1];
end
% vBlockSize = [100000, 100000, 1, 1]; % process slice by slice (better not)
vBlockCount = ceil(vDataSize ./ vBlockSize);

for vIndexT = 0:vDataSize(4)-1
  if vIsSurfaces
    
    % Get the mask DataSet
    vMaskDataSet = vImarisObject.GetMask( ...
      vDataMin(1), vDataMin(2), vDataMin(3), ...
      vDataMax(1), vDataMax(2), vDataMax(3), ...
      vDataSize(1), vDataSize(2), vDataSize(3), vIndexT);
    
    for vIndexZ = 1:vBlockCount(3)
      vMinZ = (vIndexZ - 1) * vBlockSize(3);
      vSizeZ = min(vBlockSize(3), vDataSize(3) - vMinZ);
    for vIndexY = 1:vBlockCount(2)
      vMinY = (vIndexY - 1) * vBlockSize(2);
      vSizeY = min(vBlockSize(2), vDataSize(2) - vMinY);
    for vIndexX = 1:vBlockCount(1)
      vMinX = (vIndexX - 1) * vBlockSize(1);
      vSizeX = min(vBlockSize(1), vDataSize(1) - vMinX);
      
      vBlock = vMaskDataSet.GetDataSubVolumeAs1DArrayBytes(...
        vMinX, vMinY, vMinZ, 0, 0, vSizeX, vSizeY, vSizeZ);

      if vSelection == 1
        vBlock = vBlock ~= 1;
      else
        vBlock = vBlock == 1;
      end
      
      vImarisDataSet.SetDataSubVolumeAs1DArrayFloats(single(vBlock), ...
        vMinX, vMinY, vMinZ, vNumberOfChannels, vIndexT, vSizeX, vSizeY, vSizeZ);
      
      vEndXYZT = [vIndexX, vIndexY, vIndexZ, vIndexT + 1];
      waitbar(GetProgress(vEndXYZT, vBlockCount) / 2, vProgressDisplay);
    end
    end
    end

  else % is spots
    
    vThisTime = vSpotsTime == vIndexT;
    vThisSpots = vSpotsXYZ(vThisTime, :);
    if isempty(vThisSpots)
      continue
    end

    for vIndexZ = 1:vBlockCount(3)
      vMinZ = (vIndexZ - 1) * vBlockSize(3);
      vSizeZ = min(vBlockSize(3), vDataSize(3) - vMinZ);
      vValidZ = vThisSpots(:, 3) > vMinZ & vThisSpots(:, 3) <= vMinZ + vSizeZ;
    for vIndexY = 1:vBlockCount(2)
      vMinY = (vIndexY - 1) * vBlockSize(2);
      vSizeY = min(vBlockSize(2), vDataSize(2) - vMinY);
      vValidYZ = vValidZ & vThisSpots(:, 2) > vMinY & vThisSpots(:, 2) <= vMinY + vSizeY;
    for vIndexX = 1:vBlockCount(1)
      vMinX = (vIndexX - 1) * vBlockSize(1);
      vSizeX = min(vBlockSize(1), vDataSize(1) - vMinX);
      vValidXYZ = vValidYZ & vThisSpots(:, 1) > vMinX & vThisSpots(:, 1) <= vMinX + vSizeX;

      vBlockSpots = vThisSpots(vValidXYZ, :);

      if isempty(vBlockSpots)
        continue;
      end
      vBlock = zeros(vSizeX * vSizeY * vSizeZ, 1, 'single');
      vBlock(vBlockSpots(:, 1) - vMinX + ...
        (vBlockSpots(:, 2) - vMinY - 1) * vSizeX + ...
        (vBlockSpots(:, 3) - vMinZ - 1) * vSizeX * vSizeY) = 1;

      vImarisDataSet.SetDataSubVolumeAs1DArrayFloats(vBlock, ...
        vMinX, vMinY, vMinZ, vNumberOfChannels, vIndexT, vSizeX, vSizeY, vSizeZ);

      vEndXYZT = [vIndexX, vIndexY, vIndexZ, vIndexT + 1];
      waitbar(GetProgress(vEndXYZT, vBlockCount) / 2, vProgressDisplay);
    end
    end
    end
  end

end

waitbar(0.5, vProgressDisplay, 'Distance Transform: Calculation');
vImarisApplication.GetImageProcessing.DistanceTransformChannel( ...
  vImarisDataSet, vNumberOfChannels, 1, false);
waitbar(1, vProgressDisplay);

vImarisApplication.SetDataSet(vImarisDataSet);
close(vProgressDisplay);

function aProgress = GetProgress(aIndex, aSize)
aProgress = 1;
for vIndex = numel(aIndex)
  aProgress = (aIndex(vIndex) - 1 + aProgress) / aSize(vIndex);
end


%% channel arithmetics


function ChannelArithmetics(aImarisApplicationID, nchans)

% get the application object
if isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
  % called from workspace
  vImarisApplication = aImarisApplicationID;
else
  % connect to Imaris interface
  javaaddpath ImarisLib.jar
  vImarisLib = ImarisLib;
  if ischar(aImarisApplicationID)
    aImarisApplicationID = round(str2double(aImarisApplicationID));
  end
  vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
end


%vAnswer = cellstr(sprintf(strcat('ch%i+', num2str(offset)), nchans+1));

vAnswer = cellstr(sprintf('ch%i+1', nchans));
%vAnswer = inputdlg({sprintf(['Combination expression:\n\n', ...
%  'Channel names: ch1, ch2, ...\nUse matlab operators, i.e. ', ...
%  '+, -, .*, ./, .^, sqrt, ...\n'])}, ...
%    'Channel Arithmetics', 1, {'sqrt(ch1 .* ch2)'});
%if isempty(vAnswer), return, end

vDataSet = vImarisApplication.GetDataSet.Clone;

vLastC = vDataSet.GetSizeC;
vDataSet.SetSizeC(vLastC + 1);
vMin = vDataSet.GetChannelRangeMin(0);
vMax = vDataSet.GetChannelRangeMax(0);
vDataSet.SetChannelRange(vLastC, vMin, vMax);

vProgressDisplay = waitbar(0, 'Channel Arithmetics');
vProgressCount = 0;

vDataSize = [vDataSet.GetSizeX, vDataSet.GetSizeY, vDataSet.GetSizeZ];
if vDataSize(3) == 1
  vBlockSize = [1024, 1024, 1];
else
  vBlockSize = [512, 512, 32];
end
% vBlockSize = [100000, 100000, 1]; % process slice by slice (better not)
vBlockCount = ceil(vDataSize ./ vBlockSize);

vProgressTotalCount = vDataSet.GetSizeT*prod(vBlockCount);

for vTime = 1:vDataSet.GetSizeT
    for vIndexZ = 1:vBlockCount(3)
      vMinZ = (vIndexZ - 1) * vBlockSize(3);
      vSizeZ = min(vBlockSize(3), vDataSize(3) - vMinZ);
    for vIndexY = 1:vBlockCount(2)
      vMinY = (vIndexY - 1) * vBlockSize(2);
      vSizeY = min(vBlockSize(2), vDataSize(2) - vMinY);
    for vIndexX = 1:vBlockCount(1)
      vMinX = (vIndexX - 1) * vBlockSize(1);
      vSizeX = min(vBlockSize(1), vDataSize(1) - vMinX);

        for vChannel = 1:vLastC
          if strcmp(vDataSet.GetType,'eTypeUInt8')
              vData = vDataSet.GetDataSubVolumeAs1DArrayBytes(...
                vMinX, vMinY, vMinZ, vChannel-1, vTime-1, vSizeX, vSizeY, vSizeZ);
              vData = typecast(vData, 'uint8');
          elseif strcmp(vDataSet.GetType,'eTypeUInt16')
              vData = vDataSet.GetDataSubVolumeAs1DArrayShorts(...
                vMinX, vMinY, vMinZ, vChannel-1, vTime-1, vSizeX, vSizeY, vSizeZ);
              vData = typecast(vData, 'uint16');
          elseif strcmp(vDataSet.GetType,'eTypeFloat')
              vData = vDataSet.GetDataSubVolumeAs1DArrayFloats(...
                vMinX, vMinY, vMinZ, vChannel-1, vTime-1, vSizeX, vSizeY, vSizeZ);
          end
          % works on double to allow division and prevent overflows
          eval(sprintf('ch%i = double(vData);', vChannel));
        end

        try
          vData = eval(vAnswer{1});
        catch er
          close(vProgressDisplay);
          msgbox(sprintf(['Error while evaluating the expression.\n\n', ...
            'Possible causes: invalid variable names (ch1, ch2, ...), ', ...
            'invalid operators (use .* instead of *)...\n\n', er.message]));
          return;
        end
        
        try
          if strcmp(vDataSet.GetType,'eTypeUInt8')
              vDataSet.SetDataSubVolumeAs1DArrayBytes(uint8(vData), ...
                vMinX, vMinY, vMinZ, vLastC, vTime-1, vSizeX, vSizeY, vSizeZ);
          elseif strcmp(vDataSet.GetType,'eTypeUInt16')
              vDataSet.SetDataSubVolumeAs1DArrayShorts(uint16(vData), ...
                vMinX, vMinY, vMinZ, vLastC, vTime-1, vSizeX, vSizeY, vSizeZ);
          elseif strcmp(vDataSet.GetType,'eTypeFloat')
              vDataSet.SetDataSubVolumeAs1DArrayFloats(single(vData), ...
                vMinX, vMinY, vMinZ, vLastC, vTime-1, vSizeX, vSizeY, vSizeZ);
          end
        catch er
          close(vProgressDisplay);
          msgbox(sprintf(['The result of the expression is not a valid dataset.\n\n', ...
            'Possible causes: invalid result size.\n\n', er.message]));
          return
        end

        vProgressCount = vProgressCount + 1;
        waitbar(vProgressCount/vProgressTotalCount, vProgressDisplay);

    end
    end
    end
end

vImarisApplication.SetDataSet(vDataSet);
close(vProgressDisplay);





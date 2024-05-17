% Load the ground truth data
load('pilot-tracker.mat');

% Specify the directory
directory = './F15 Image Plane';
directoryOcean = './F15 Ocean';

% Get a list of all .png files in the directory
files = dir(fullfile(directory, '*.png'));
oceanFiles = dir(fullfile(directoryOcean, '*.png'));

% Create a VideoWriter object
outputVideo = VideoWriter('output.avi', 'Uncompressed AVI');

% Open the VideoWriter object
open(outputVideo);

% Initialize the last bounding box
lastBbox = [];

% Create a directory for the processed images
processedDirectory = './F15 Image Plane-noBG';
if ~exist(processedDirectory, 'dir')
    mkdir(processedDirectory);
end

% Loop over all files
for i = 1:length(files)
    % Read the current image
    img = imread(fullfile(directory, files(i).name));
    oceanImage = imread(fullfile(directoryOcean, oceanFiles(i).name));
    
    % Get the bounding box for the current image from the ground truth data
    bbox = gTruth.LabelData{i, 1};
    
    % Convert the cell array to a numeric array
    bbox = cell2mat(bbox);
    bbox = round(bbox);
    
    % Check if bbox is not empty
    if ~isempty(bbox)
        % Update the last bounding box
        lastBbox = bbox;
    elseif ~isempty(lastBbox)
        % Use the last bounding box if the current one is empty
        bbox = lastBbox;
    else
        % Skip this frame if there is no bounding box
        continue;
    end
    
    % Ensure the bounding box does not exceed the size of the image
    bbox(1) = min(bbox(1), size(img, 2));
    bbox(2) = min(bbox(2), size(img, 1));
    bbox(3) = min(bbox(1) + bbox(3), size(img, 2)) - bbox(1);
    bbox(4) = min(bbox(2) + bbox(4), size(img, 1)) - bbox(2);
    
    %----------------------------------------------------------------------------
    % 1. Quita todo lo que esté fuera del bbox
    % ---------------------------------------------------------------------------
    % Create a binary mask of the same size as the image
    mask = false(size(img, 1), size(img, 2));
    % Set the pixels inside the bounding box to 1
    mask(bbox(2):bbox(2)+bbox(4), bbox(1):bbox(1)+bbox(3)) = true;
    % Multiply the image by the mask to remove pixels outside the bounding box
    imgMasked = bsxfun(@times, img, cast(mask, class(img)));
    
    % Extract the region of the image inside the bounding box
    region = imgMasked(bbox(2):bbox(2)+bbox(4), bbox(1):bbox(1)+bbox(3), :);
    
    %----------------------------------------------------------------------------
    % 2. Quitar todo el croma de dentro de la imagen
    % ---------------------------------------------------------------------------
    % Convert the region to HSV
    hsvImage = rgb2hsv(region);
    % Define the green threshold
    greenThreshold = hsvImage(:,:,1) > 0.25 & hsvImage(:,:,1) < 0.75 ...
        & hsvImage(:,:,2) > 0.2 & hsvImage(:,:,3) > 0.3;
    % Create a mask for the green pixels
    greenMask = greenThreshold;
    % Apply the mask to the region to remove the green pixels
    region(repmat(greenMask, [1, 1, 3])) = 0;
    
    %----------------------------------------------------------------------------
    % 3. Remove black-green pixels and small details
    % ---------------------------------------------------------------------------
    % Define the black-green threshold
    blackGreenThreshold = hsvImage(:,:,1) > 0.25 & hsvImage(:,:,1) < 0.75 ...
        & hsvImage(:,:,2) > 0.1 & hsvImage(:,:,3) < 0.35;
    % Create a mask for the black-green pixels
    blackGreenMask = blackGreenThreshold;
    % Apply the mask to the region to remove the black-green pixels
    region(repmat(blackGreenMask, [1, 1, 3])) = 0;
    
    % Create a structuring element
    se = strel('disk', 5);
    % Erode the green mask
    greenMask = imerode(greenMask, se);
    % Apply the eroded mask to the region to remove small details
    region(repmat(greenMask, [1, 1, 3])) = 0;
    
    % Replace the region in the image
    imgMasked(bbox(2):bbox(2)+bbox(4), bbox(1):bbox(1)+bbox(3), :) = region;
    
    % Create an alpha channel based on the mask and the content of the region
    alphaChannel = uint8(~mask) * 255;
    alphaChannel(bbox(2):bbox(2)+bbox(4), bbox(1):bbox(1)+bbox(3)) = ...
        uint8(any(region ~= 0, 3)) * 255;
    
    % Combine the ocean image with the masked image
    oceanImage = cat(3, oceanImage, 255*ones(size(oceanImage, 1), size(oceanImage, 2), 'uint8'));
    imgMasked = cat(3, imgMasked, alphaChannel);
    
    % Blend the images
    imgCombined = imoverlay(oceanImage, imgMasked);
    
    % Save the processed image to the new directory
    imwrite(imgCombined(:,:,1:3), fullfile(processedDirectory, files(i).name), 'png', 'Alpha', imgCombined(:,:,4));
    
    % Write the current frame to the video
    writeVideo(outputVideo, imgCombined(:,:,1:3));
end

% Close the VideoWriter object
close(outputVideo);

function imgOut = imoverlay(background, foreground)
    alphaChannel = foreground(:,:,4);
    mask = alphaChannel == 255;
    imgOut = background;
    for c = 1:3
        imgOut(:,:,c) = background(:,:,c) .* uint8(~mask) + foreground(:,:,c) .* uint8(mask);
    end
    imgOut = cat(3, imgOut, background(:,:,4));
end

% Load the ground truth data
load('pilot-tracker.mat');
% Specify the directory
directory = './F15 Image Plane';
% Define the output directory
outputDirectory = './F15 Image Plane no bg';
% Check if the output directory exists, if not, create it
if ~exist(outputDirectory, 'dir')
    mkdir(outputDirectory);
end
% Get a list of all .png files in the directory
files = dir(fullfile(directory, '*.png'));
% Create a VideoWriter object
outputVideo = VideoWriter('output.avi', 'Uncompressed AVI');
% Open the VideoWriter object
open(outputVideo);

% Initialize the last bounding box
lastBbox = [];

% Loop over all files
for i = 1:length(files)
    % Read the current image
    img = imread(fullfile(directory, files(i).name));
    
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
    img = bsxfun(@times, img, cast(mask, class(img)));
    
    % Extract the region of the image inside the bounding box
    region = img(bbox(2):bbox(2)+bbox(4), bbox(1):bbox(1)+bbox(3), :);
    
    %----------------------------------------------------------------------------
    % 2. Quitar todo el croma de dentro de la imagen
    % ---------------------------------------------------------------------------
    % Convert the region to HSV
    hsvImage = rgb2hsv(region);
    % Define the green threshold
    greenThreshold = hsvImage(:,:,1) > 0.25 & hsvImage(:,:,1) < 0.75 ...
        & hsvImage(:,:,2) > 0.2 & hsvImage(:,:,3) > 0.3;
    % Create a mask for the green pixels
    greenMask = repmat(greenThreshold, [1, 1, 3]);
    % Apply the mask to the region to remove the green pixels
    region = bsxfun(@times, region, cast(~greenMask, 'like', region));
    
    %----------------------------------------------------------------------------
    % 3. Remove black-green pixels and small details
    % ---------------------------------------------------------------------------
    % Define the black-green threshold
    blackGreenThreshold = hsvImage(:,:,1) > 0.25 & hsvImage(:,:,1) < 0.75 ...
        & hsvImage(:,:,2) > 0.1 & hsvImage(:,:,3) < 0.35;
    % Create a mask for the black-green pixels
    blackGreenMask = repmat(blackGreenThreshold, [1, 1, 3]);
    % Apply the mask to the region to remove the black-green pixels
    region = bsxfun(@times, region, cast(~blackGreenMask, 'like', region));
    
    % Create a structuring element
    se = strel('disk', 5);
    % Erode the green mask
    greenMask = imerode(greenMask, se);
    % Apply the eroded mask to the region to remove small details
    region = bsxfun(@times, region, cast(~greenMask, 'like', region));
    
    % Replace the region in the image
    img(bbox(2):bbox(2)+bbox(4), bbox(1):bbox(1)+bbox(3), :) = region;
    % Create an alpha channel of the same size as the image
    alpha = ones(size(img, 1), size(img, 2)) * 255;
    
    % Find the pixels in the image that are 1 of 255
    pixelsToMakeTransparent = any(img <= 2 & img >= 0, 3);
    
    % Set the alpha value of these pixels to 0
    alpha(pixelsToMakeTransparent) = 0;
    % Display the alpha channel value
    disp(alpha);
    % Pause the execution to see the image
    pause;
    
    % Define the output file path
    outputFilePath = fullfile(outputDirectory, files(i).name);
    
    % Save the image to the output file path with the alpha channel
    imwrite(img, outputFilePath, 'png', 'Alpha', alpha);
    
    % Write the current image to the video file
    writeVideo(outputVideo, img);
    
    % Write the current image to the video file
    % writeVideo(outputVideo, img);
end
% Close the VideoWriter object
close(outputVideo);
% Load the ground truth data
load('pilot-tracker.mat');

% Specify the directory
directory = './F15 Image Plane';
directoryOcean = './F15 Ocean';
directoryJets = './F15 Fighter Jets';
directoryFrontMate = './F15 Front Matte';
directoryGlassMate = './F15 Glass';
directoryGlassBack = './F15 Glass Matte';

% Get a list of all .png files in the directory
files = dir(fullfile(directory, '*.png'));
oceanFiles = dir(fullfile(directoryOcean, '*.png'));
jetsFiles = dir(fullfile(directoryJets, '*.png'));
frontFiles = dir(fullfile(directoryFrontMate, '*.png'));
glassBackFiles = dir(fullfile(directoryGlassBack, '*.png'));
glassFiles = dir(fullfile(directoryGlassMate, '*.png'));

% Create a directory for the processed images
processedDirectory = './F15 Image Plane-noBG';
if ~exist(processedDirectory, 'dir')
    mkdir(processedDirectory);
end

outputVideo = VideoWriter('output.mp4', 'MPEG-4');
open(outputVideo);

% Loop over all files
for i = 1:length(files)
    % Read the current image
    img = imread(fullfile(directory, files(i).name));
    oceanImage = imread(fullfile(directoryOcean, oceanFiles(i).name));
    jetImage = imread(fullfile(directoryJets, jetsFiles(i).name));
    frontImage = imread(fullfile(directoryFrontMate, frontFiles(i).name));
    glassImage = imread(fullfile(directoryGlassMate, glassFiles(i).name));
    glassBackImage = imread(fullfile(directoryGlassBack, glassBackFiles(i).name));

    
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
    imgMasked(bbox(2):bbox(2)+bbox(4), bbox(1):bbox(1)+bbox(3), :) = region;
    
    % Resize oceanImage to match the size of img
    oceanImage = imresize(oceanImage, [size(img, 1), size(img, 2)]);
    jetImage = imresize(jetImage, [size(img, 1), size(img, 2)]);
    frontImage = imresize(frontImage, [size(img, 1), size(img, 2)]);
    glassBackImage = imresize(glassBackImage, [size(img, 1), size(img, 2)]);

    %frontImage = imerode(frontImage,se);
    %jetImage = imerode(jetImage,se);

    % Create a final image by overlaying imgMasked on oceanImage and jetImage
    imgFinal = oceanImage;

    % Only overlay non-black pixels from jetImage
    maskNonBlackJet = jetImage ~= 0;
    imgFinal(maskNonBlackJet) = jetImage(maskNonBlackJet);

    % Only overlay non-black pixels from jetImage
    maskNonBlackGlass = glassBackImage ~= 0;
    imgFinal(maskNonBlackGlass) = jetImage(maskNonBlackGlass);
    
    % Only overlay non-black pixels from imgMasked
    maskNonBlack = imgMasked ~= 0;
    imgFinal(maskNonBlack) = imgMasked(maskNonBlack);

    % Only overlay non-black pixels from jetImage
    maskNonBlackFront = frontImage ~= 0;
    imgFinal(maskNonBlackFront) = frontImage(maskNonBlackFront);

    imgFinal = imfuse(imgFinal,glassImage,'blend');
    
    % Save the processed image to the new directory
    imwrite(imgFinal, fullfile(processedDirectory, files(i).name), 'png');
    writeVideo(outputVideo, imgFinal);
end

close(outputVideo);

directorio = './F15 Image Plane';
archivos = dir(fullfile(directorio, '*.png'));
outputVideo = VideoWriter('video_bbox.avi', 'Uncompressed AVI');
open(outputVideo);
for i = 1:length(archivos)
	imagen = imread(fullfile(directorio, archivos(i).name));
	
	%----------------------------------------------------------------------------
	% 1º QUITAR VERDE - CROMA
	% ---------------------------------------------------------------------------
	% Convertir la imagen a HSV
	hsvImage = rgb2hsv(imagen);
	greenThreshold = hsvImage(:,:,1) > 0.25 & hsvImage(:,:,1) < 0.75 ...
		& hsvImage(:,:,2) > 0.2 & hsvImage(:,:,3) > 0.3;
	mask = repmat(greenThreshold, [1, 1, 3]);
	
	% Umbral para considerar como blanco (ajustar según sea necesario)
	umbral = 240; % Solo los píxeles muy brillantes se considerarán como blanco
	mascara_fondo = rgb2gray(imagen) > umbral;
	% Aplicar operaciones morfológicas para eliminar pequeñas áreas blancas
	mascara_fondo = bwareaopen(mascara_fondo, 100); % Eliminar pequeñas áreas blancas
	mascara_fondo = imfill(mascara_fondo, 'holes'); % Rellenar agujeros en el fondo
	mascara_fondo = imclose(mascara_fondo, strel('disk', 5)); % Cerrar pequeños huecos entre regiones blancas
	mascara_fondo = ~repmat(greenThreshold, [1, 1, 3]);
	
	% Aplicar la máscara del sujeto eliminando el croma
	imagen_sujeto_segmentado = bsxfun(@times, imagen, cast(mascara_fondo, 'like', imagen));

	%----------------------------------------------------------------------------
	% 2º QUITAR TODO MENOS LO VERDE - FONDO
	% ---------------------------------------------------------------------------
	% Convert image to HSV to better isolate the subject
	hsvImage = rgb2hsv(imagen);
	% Assuming the person is not colored green
	personThreshold = (hsvImage(:,:,1) > 0.25 & hsvImage(:,:,1) < 0.75) & ...
		(hsvImage(:,:,2) > 0.2 & hsvImage(:,:,3) > 0.3);
	mask = repmat(personThreshold, [1, 1, 3]);
	
	% Use the mask to isolate the person
	only_croma = imagen; % -> Only the green Croma
	only_croma(~mask) = 0;  % Set background to white
	
	%----------------------------------------------------------------------------
	% 3º OBTENER BBOX
	% ---------------------------------------------------------------------------
	% Convert the image to grayscale
	grayImage = rgb2gray(only_croma);
	cc = bwconncomp(grayImage);
	stats = regionprops(cc, 'BoundingBox');
	% Get the bounding box
	bbox = stats.BoundingBox;
	% Draw the bounding box on the segmented subject image
	imagen_sujeto_segmentado = insertShape(imagen_sujeto_segmentado, 'Rectangle', [bbox(1), bbox(2), bbox(3), bbox(4)], 'Color', 'green', 'LineWidth', 2);
	% Create a mask that only contains the area inside the bounding box
	mask = false(size(imagen));
	mask(round(bbox(2)):round(bbox(2)+bbox(4)), round(bbox(1)):round(bbox(1)+bbox(3)), :) = true;
	
	% Apply the mask to the image
	imagen_sujeto_segmentado(~mask) = 0;
	
	writeVideo(outputVideo, imagen_sujeto_segmentado);
end
close(outputVideo);
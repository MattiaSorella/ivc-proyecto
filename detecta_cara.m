directorio = './F15 Image Plane';
archivos = dir(fullfile(directorio, '*.png'));
outputVideo = VideoWriter('video_con_cara_resaltada.mp4', 'MPEG-4');
open(outputVideo);

% Detector de caras
faceDetector = vision.CascadeObjectDetector;

for i = 1:length(archivos)
    imagen = imread(fullfile(directorio, archivos(i).name));
    
    bboxes = faceDetector(imagen);
    
    imagen_con_caras_resaltadas = insertObjectAnnotation(imagen, 'rectangle', bboxes, 'Face');
    
    % Escribir el cuadro procesado en el nuevo video
    writeVideo(outputVideo, imagen_con_caras_resaltadas);
end
close(outputVideo);
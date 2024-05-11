directorio = './F15 Image Plane';
directorio_superposicion = './F15 Fighter Jets';
archivos = dir(fullfile(directorio, '*.png'));
archivos_superposicion = dir(fullfile(directorio_superposicion, '*.png'));

outputVideo = VideoWriter('video_con_capas.mp4', 'MPEG-4');
open(outputVideo);

for i = 1:length(archivos)
    imagen = imread(fullfile(directorio, archivos(i).name));
    imagen_superposicion = imread(fullfile(directorio_superposicion, archivos_superposicion(i).name));

    % Llamar a delete_croma para eliminar el fondo de la imagen
    imagen_sujeto_segmentado = delete_croma(imagen);

    % Crear una máscara inversa del fondo eliminado por delete_croma
    mask_fondo = any(imagen_sujeto_segmentado == 0, 3);

    % Superponer la imagen de la carpeta 'F15 Fighter Jets' solo en el fondo
    imagen_final = imagen_sujeto_segmentado;
    mask_superposicion = repmat(mask_fondo, [1, 1, 3]);
    imagen_final(mask_superposicion) = imagen_superposicion(mask_superposicion);

    % Escribir el cuadro procesado en el nuevo video
    writeVideo(outputVideo, imagen_final);
end


close(outputVideo);
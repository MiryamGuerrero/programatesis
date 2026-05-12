import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import '../../core/theme/app_theme.dart';

class RecipeImageService {
  static final _picker = ImagePicker();
  static final _supabase = Supabase.instance.client;

  /// Permite al usuario seleccionar una imagen y luego recortarla.
  static Future<XFile?> pickAndCropImage(BuildContext context, ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
    );

    if (pickedFile == null) return null;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9), // Formato tarjeta
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Ajustar Imagen de Receta',
          toolbarColor: AppTema.azulPrincipal,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.ratio16x9,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Ajustar Imagen',
          aspectRatioLockEnabled: true,
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 400, height: 400), // Tamaño aún más pequeño para evitar overflows de 24px
        ),
      ],
    );

    return croppedFile != null ? XFile(croppedFile.path) : null;
  }

  /// Optimiza la imagen para ahorrar espacio (Max 50MB total en bucket).
  /// Redimensiona a 1024px de ancho (manteniendo 16:9) y comprime a JPEG 75%.
  static Future<Uint8List> optimizeImage(XFile xFile) async {
    final bytes = await xFile.readAsBytes();
    
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception("No se pudo decodificar la imagen");

    // Redimensionar si es muy grande
    if (image.width > 1024) {
      image = img.copyResize(image, width: 1024);
    }

    // Comprimir a JPEG con calidad 75 (buen balance espacio/calidad)
    return Uint8List.fromList(img.encodeJpg(image, quality: 75));
  }

  /// Sube la imagen optimizada a Supabase Storage (Bucket: imagenes_recetas, Folder: private).
  static Future<String> uploadRecipeImage({
    required XFile imageFile,
    required String fileName,
  }) async {
    try {
      final optimizedBytes = await optimizeImage(imageFile);
      
      final cleanFileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(fileName)}';
      // Nueva política: carpeta 'public/' para acceso directo de lectura
      final storagePath = 'public/$cleanFileName';

      await _supabase.storage.from('imagenes_recetas').uploadBinary(
            storagePath,
            optimizedBytes,
            fileOptions: const FileOptions(cacheControl: '3600', contentType: 'image/jpeg'),
          );

      // Obtenemos la URL. Si es privada, se asume que el frontend tiene sesión activa para verla.
      final String publicUrl = _supabase.storage.from('imagenes_recetas').getPublicUrl(storagePath);
      
      return publicUrl;
    } catch (e) {
      debugPrint("Error subiendo imagen: $e");
      rethrow;
    }
  }

  /// Elimina una imagen del storage dado su URL.
  static Future<void> deleteImageByUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      // Extraer el path relativo al bucket. 
      // Las URLs de Supabase suelen ser .../storage/v1/object/public/bucket/path
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('imagenes_recetas');
      if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
        final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
        await _supabase.storage.from('imagenes_recetas').remove([storagePath]);
        debugPrint("Imagen eliminada del storage: $storagePath");
      }
    } catch (e) {
      debugPrint("Error eliminando imagen del storage: $e");
    }
  }

  /// Registra la imagen en la tabla nutricion.receta_imagen.
  static Future<void> registerImageInDb({
    required int idReceta,
    required String url,
  }) async {
    try {
      // 1. Limpiar referencias previas en nutricion.receta_imagen para esta receta
      // Esto evita duplicados y mantiene la integridad de "una imagen por receta" según este flujo.
      await _supabase.schema('nutricion').from('receta_imagen').delete().eq('id_receta', idReceta);
      
      // 2. Insertar nueva referencia
      await _supabase.schema('nutricion').from('receta_imagen').insert({
        'id_receta': idReceta,
        'imagen_url': url,
      });
      
      // 3. Sincronizar con la tabla principal receta
      await _supabase.schema('nutricion').from('receta').update({
        'imagen_url': url
      }).eq('id', idReceta);
      
    } catch (e) {
      debugPrint("Error registrando imagen en DB: $e");
    }
  }
}

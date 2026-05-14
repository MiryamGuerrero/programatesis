import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class RecipeImageService {
  static final _picker = ImagePicker();
  static final _supabase = Supabase.instance.client;

  /// Permite al usuario seleccionar una imagen desde la galería o cámara.
  static Future<XFile?> pickImage(ImageSource source) async {
    return await _picker.pickImage(
      source: source,
      maxWidth: 2000, 
      maxHeight: 2000,
    );
  }

  /// Optimiza la imagen: redimensiona a un máximo de 1024px y comprime a JPEG.
  static Future<Uint8List> optimizeImage(XFile xFile) async {
    final bytes = await xFile.readAsBytes();
    
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception("No se pudo decodificar la imagen");

    if (image.width > 1024 || image.height > 1024) {
      if (image.width > image.height) {
        image = img.copyResize(image, width: 1024);
      } else {
        image = img.copyResize(image, height: 1024);
      }
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 80));
  }

  /// Sube la imagen optimizada a Supabase Storage y retorna la URL pública.
  /// Usa el bucket 'receta_imagenes'.
  static Future<String> uploadRecipeImage({
    required XFile imageFile,
    required String fileName,
  }) async {
    try {
      final optimizedBytes = await optimizeImage(imageFile);
      
      final cleanFileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(fileName)}';
      // Guardamos en la raíz del bucket para simplificar
      final storagePath = cleanFileName;

      await _supabase.storage.from('receta_imagenes').uploadBinary(
            storagePath,
            optimizedBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final String publicUrl = _supabase.storage.from('receta_imagenes').getPublicUrl(storagePath);
      
      return publicUrl;
    } catch (e) {
      debugPrint("Error subiendo imagen: $e");
      rethrow;
    }
  }

  /// Elimina una imagen del storage dado su URL pública.
  static Future<void> deleteImageByUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      // El nombre del archivo es el último segmento de la ruta
      final fileName = uri.pathSegments.last;
      
      await _supabase.storage.from('receta_imagenes').remove([fileName]);
      debugPrint("Imagen eliminada del storage: $fileName");
    } catch (e) {
      debugPrint("Error eliminando imagen del storage: $e");
      // No lanzamos error para evitar bloquear la app si la imagen ya no existía
    }
  }

  /// Registra la imagen en la tabla receta_imagen (en el esquema public).
  /// Columnas existentes: id, id_receta, imagen_url, orden.
  static Future<void> registerImageInDb({
    required int idReceta,
    required String url,
    int orden = 1,
  }) async {
    try {
      // Usamos el esquema public (por defecto) para evitar errores de exposición
      await _supabase.from('receta_imagen').insert({
        'id_receta': idReceta,
        'imagen_url': url,
        'orden': orden,
      });
      
      // Intentamos actualizar la tabla nutricion.receta (que el backend sí ve)
      // Pero para la app, si no está expuesto nutricion, esto podría fallar.
      // Por ahora, registramos en receta_imagen que es lo que pide la funcionalidad.
      try {
        await _supabase.schema('nutricion').from('receta').update({'imagen_url': url}).eq('id', idReceta);
      } catch (e) {
        debugPrint("Nota: No se pudo actualizar nutricion.receta (posible esquema no expuesto), pero la imagen se registró en receta_imagen.");
      }
    } catch (e) {
      debugPrint("Error registrando imagen en DB: $e");
    }
  }
}

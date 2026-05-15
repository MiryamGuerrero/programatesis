import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class RecipeImageService {
  static final _picker = ImagePicker();
  static final _supabase = Supabase.instance.client;
  static const String _primaryBucket = 'receta_imagenes';
  static const String _legacyBucket = 'imagenes_recetas';

  static Future<XFile?> pickImage(ImageSource source) async {
    return await _picker.pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
    );
  }

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

  static Future<String> uploadRecipeImage({
    required XFile imageFile,
    required String fileName,
  }) async {
    try {
      final optimizedBytes = await optimizeImage(imageFile);
      final baseName = p
          .basenameWithoutExtension(fileName)
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final cleanFileName =
          '${DateTime.now().millisecondsSinceEpoch}_${baseName.isEmpty ? 'receta' : baseName}.jpg';

      final bucket = await _uploadToAvailableBucket(cleanFileName, optimizedBytes);
      return _supabase.storage.from(bucket).getPublicUrl(cleanFileName);
    } catch (e) {
      debugPrint("Error subiendo imagen: $e");
      rethrow;
    }
  }

  static Future<String> _uploadToAvailableBucket(
    String storagePath,
    Uint8List bytes,
  ) async {
    const options = FileOptions(
      cacheControl: '3600',
      upsert: true,
      contentType: 'image/jpeg',
    );

    try {
      await _supabase.storage.from(_primaryBucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: options,
          );
      return _primaryBucket;
    } on StorageException catch (e) {
      final bucketMissing =
          e.statusCode == '404' || e.message.toLowerCase().contains('bucket not found');
      if (!bucketMissing) rethrow;

      await _supabase.storage.from(_legacyBucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: options,
          );
      return _legacyBucket;
    }
  }

  static Future<void> deleteImageByUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.last;
      final bucket = uri.pathSegments.contains(_legacyBucket) ? _legacyBucket : _primaryBucket;

      await _supabase.storage.from(bucket).remove([fileName]);
      debugPrint("Imagen eliminada del storage: $fileName");
    } catch (e) {
      debugPrint("Error eliminando imagen del storage: $e");
    }
  }

  static Future<void> registerImageInDb({
    required int idReceta,
    required String url,
    int orden = 1,
  }) async {
    try {
      await _supabase.from('receta_imagen').insert({
        'id_receta': idReceta,
        'imagen_url': url,
        'orden': orden,
      });

      try {
        await _supabase.schema('nutricion').from('receta').update({'imagen_url': url}).eq('id', idReceta);
      } catch (e) {
        debugPrint("Nota: No se pudo actualizar nutricion.receta, pero la imagen se registro en receta_imagen.");
      }
    } catch (e) {
      debugPrint("Error registrando imagen en DB: $e");
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Servicio para subir archivos a la nube mediante Cloudinary (100% Gratis sin tarjeta de crédito).
class StorageService {
  // CONFIGURACIÓN DE CLOUDINARY
  // Reemplaza los siguientes 2 valores con tus datos de Cloudinary:
  static const String cloudName = 'uyyjnpgz'; // Tu Cloud Name de Cloudinary
  static const String uploadPreset = 'preset_kanbly'; // Tu Upload Preset (Modo Unsigned)

  /// Sube un archivo local a Cloudinary y retorna la URL pública de descarga (HTTPS).
  /// Si la URL ya es una URL remota de internet (empieza con http/https), la devuelve tal cual.
  Future<String> subirAdjuntoTarea({
    required String filePath,
    required String nombreArchivo,
    required String tareaId,
  }) async {
    // Si ya es una URL de la nube, la devolvemos sin modificar
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('El archivo local no existe para subir: $filePath');
    }

    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = data['secure_url']?.toString();
        if (secureUrl != null && secureUrl.isNotEmpty) {
          return secureUrl;
        } else {
          throw Exception('Cloudinary no devolvió una URL válida.');
        }
      } else {
        throw Exception('Error al subir a Cloudinary (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error en StorageService.subirAdjuntoTarea: $e');
      }
      rethrow;
    }
  }
}

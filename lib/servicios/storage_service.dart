import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Suba un archivo local a Firebase Storage y retorna la URL pública de descarga.
  /// Si la URL ya es una URL remota (empieza con http/https), la devuelve tal cual.
  Future<String> subirAdjuntoTarea({
    required String filePath,
    required String nombreArchivo,
    required String tareaId,
  }) async {
    // Si ya es una URL remota de la nube, no se necesita volver a subir
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('El archivo local no existe para subir: $filePath');
    }

    try {
      final nombreLimpio = nombreArchivo.replaceAll(RegExp(r'[^\w.-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('tareas')
          .child(tareaId.isNotEmpty ? tareaId : 'temp')
          .child('${timestamp}_$nombreLimpio');

      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error en StorageService.subirAdjuntoTarea: $e');
      }
      rethrow;
    }
  }
}

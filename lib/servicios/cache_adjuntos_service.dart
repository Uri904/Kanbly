import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class CacheAdjuntosService {
  static Future<Directory> _obtenerDirectorioCache() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/adjuntos_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _generarNombreFicheroLocal(String urlRemota, String nombreOriginal) {
    final cleanName = nombreOriginal.replaceAll(RegExp(r'[^\w.-]'), '_');
    final hash = urlRemota.hashCode.abs().toString();
    return '${hash}_$cleanName';
  }

  /// Retorna la ruta del archivo local si ya está guardado en caché local, o null si no existe.
  static Future<File?> obtenerArchivoLocalSiExiste(String url, String nombreOriginal) async {
    try {
      if (url.isEmpty) return null;
      if (!url.startsWith('http')) {
        final f = File(url);
        if (await f.exists()) return f;
        return null;
      }

      final dir = await _obtenerDirectorioCache();
      final localName = _generarNombreFicheroLocal(url, nombreOriginal);
      final localFile = File('${dir.path}/$localName');
      if (await localFile.exists()) {
        return localFile;
      }
    } catch (_) {}
    return null;
  }

  /// Descarga el archivo remoto y lo guarda en el almacenamiento local para consumo offline.
  static Future<File?> descargarYGuardarEnCache(String urlRemota, String nombreOriginal) async {
    try {
      if (urlRemota.isEmpty || !urlRemota.startsWith('http')) return null;

      final dir = await _obtenerDirectorioCache();
      final localName = _generarNombreFicheroLocal(urlRemota, nombreOriginal);
      final localFile = File('${dir.path}/$localName');

      final response = await http.get(Uri.parse(urlRemota));
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        return localFile;
      }
    } catch (_) {}
    return null;
  }
}

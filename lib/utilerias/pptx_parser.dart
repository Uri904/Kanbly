import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Estructura de una diapositiva extraída de una presentación PowerPoint (.pptx)
class DiapositivaPptx {
  final int numero;
  final String titulo;
  final List<String> parrafos;
  final List<String> imagenesBase64;

  DiapositivaPptx({
    required this.numero,
    required this.titulo,
    required this.parrafos,
    required this.imagenesBase64,
  });
}

/// Resultado del procesamiento de un archivo .pptx
class ResultadoPptx {
  final List<DiapositivaPptx> diapositivas;
  final String? tituloPresentacion;

  ResultadoPptx({
    required this.diapositivas,
    this.tituloPresentacion,
  });
}

/// Clase utilitaria encargada de extraer y transformar la estructura interna
/// de un archivo Microsoft PowerPoint (.pptx) en diapositivas estructuradas.
class PptxParser {
  /// Procesa un archivo PowerPoint .pptx y retorna sus diapositivas
  static Future<ResultadoPptx> procesarPptxCompleto({
    File? archivoLocal,
    Uint8List? bytesArchivo,
  }) async {
    try {
      Uint8List bytes;
      if (bytesArchivo != null) {
        bytes = bytesArchivo;
      } else if (archivoLocal != null && archivoLocal.existsSync()) {
        bytes = await archivoLocal.readAsBytes();
      } else {
        return ResultadoPptx(diapositivas: []);
      }

      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Extraer imágenes de ppt/media/
      final mapImagenes = <String, String>{};
      for (final file in archive) {
        if (file.name.startsWith('ppt/media/')) {
          final nombreMedia = file.name.replaceFirst('ppt/', '');
          final mediaBytes = file.content as List<int>;
          final base64Str = base64Encode(mediaBytes);

          String mimeType = 'image/png';
          final lower = file.name.toLowerCase();
          if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) mimeType = 'image/jpeg';
          if (lower.endsWith('.gif')) mimeType = 'image/gif';
          if (lower.endsWith('.svg')) mimeType = 'image/svg+xml';

          mapImagenes[file.name] = 'data:$mimeType;base64,$base64Str';
          mapImagenes[nombreMedia] = 'data:$mimeType;base64,$base64Str';
        }
      }

      // 2. Localizar diapositivas
      final slideFiles = archive.files
          .where((f) => RegExp(r'ppt/slides/slide\d+\.xml$').hasMatch(f.name))
          .toList();

      // Ordenar diapositivas por índice numérico de archivo (slide1, slide2, ...)
      slideFiles.sort((a, b) {
        final numA = int.tryParse(RegExp(r'\d+').stringMatch(a.name) ?? '0') ?? 0;
        final numB = int.tryParse(RegExp(r'\d+').stringMatch(b.name) ?? '0') ?? 0;
        return numA.compareTo(numB);
      });

      final diapositivas = <DiapositivaPptx>[];
      int contador = 1;

      for (final file in slideFiles) {
        final xmlStr = utf8.decode(file.content as List<int>, allowMalformed: true);
        final doc = XmlDocument.parse(xmlStr);

        String tituloSlide = '';
        final parrafosSlide = <String>[];
        final imagenesSlide = <String>[];

        // Extraer textos de a:t
        for (final shape in doc.findAllElements('p:sp')) {
          final textRuns = shape.findAllElements('a:t').map((e) => e.innerText.trim()).where((t) => t.isNotEmpty).join(' ');
          if (textRuns.isEmpty) continue;

          // Verificar si es el título de la diapositiva
          final isTitle = shape.findAllElements('p:ph').any((ph) {
            final type = ph.getAttribute('type')?.toLowerCase();
            return type == 'title' || type == 'ctrtitle';
          });

          if (isTitle && tituloSlide.isEmpty) {
            tituloSlide = textRuns;
          } else {
            parrafosSlide.add(textRuns);
          }
        }

        // Si no se asignó título, tomar la primera frase relevante
        if (tituloSlide.isEmpty && parrafosSlide.isNotEmpty) {
          tituloSlide = parrafosSlide.removeAt(0);
        }

        if (tituloSlide.isEmpty) {
          tituloSlide = 'Diapositiva $contador';
        }

        diapositivas.add(
          DiapositivaPptx(
            numero: contador,
            titulo: tituloSlide,
            parrafos: parrafosSlide,
            imagenesBase64: imagenesSlide,
          ),
        );
        contador++;
      }

      return ResultadoPptx(
        diapositivas: diapositivas,
        tituloPresentacion: diapositivas.isNotEmpty ? diapositivas.first.titulo : null,
      );
    } catch (_) {
      return ResultadoPptx(diapositivas: []);
    }
  }
}

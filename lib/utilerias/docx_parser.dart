import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Clase utilitaria encargada de extraer y transformar la estructura interna
/// de un archivo Microsoft Word (.docx) a código HTML enriquecido preservando
/// formatos de texto (negritas, cursivas, subrayados, tachados, colores, tamaños),
/// alineaciones, párrafos, títulos, listas, tablas e imágenes embebidas.
class DocxParser {
  /// Convierte un archivo local .docx o sus bytes raw a una cadena HTML estructurada
  static Future<String> convertirDocxAHtml({
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
        return '<p style="color: #ef4444;">El archivo Word no está disponible o no existe localmente.</p>';
      }

      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Cargar relaciones (Mapeo rId -> Ruta de Imagen)
      final mapRelaciones = _extraerRelaciones(archive);

      // 2. Cargar imágenes de la carpeta word/media/
      final mapImagenesBase64 = _extraerImagenesBase64(archive, mapRelaciones);

      // 3. Cargar el archivo principal word/document.xml
      final docFile = archive.findFile('word/document.xml');
      if (docFile == null) {
        return '<p style="color: #ef4444;">No se encontró la estructura "word/document.xml" dentro del archivo Word.</p>';
      }

      final xmlContent = utf8.decode(docFile.content as List<int>, allowMalformed: true);
      final documentXml = XmlDocument.parse(xmlContent);

      final bodyXml = documentXml.findAllElements('w:body').firstOrNull;
      if (bodyXml == null) {
        return '<p style="color: #64748b; font-style: italic;">El documento Word está vacío.</p>';
      }

      final bufferHtml = StringBuffer();
      bufferHtml.write('<div class="docx-container" style="font-family: \'Inter\', \'Roboto\', sans-serif; color: #1e293b; line-height: 1.6;">');

      for (final child in bodyXml.children) {
        if (child is XmlElement) {
          if (child.name.qualified == 'w:p') {
            bufferHtml.write(_procesarParrafo(child, mapImagenesBase64));
          } else if (child.name.qualified == 'w:tbl') {
            bufferHtml.write(_procesarTabla(child, mapImagenesBase64));
          }
        }
      }

      bufferHtml.write('</div>');

      final resultado = bufferHtml.toString().trim();
      if (resultado == '<div class="docx-container" style="font-family: \'Inter\', \'Roboto\', sans-serif; color: #1e293b; line-height: 1.6;"></div>') {
        return '<p style="color: #64748b; font-style: italic;">El documento Word no contiene texto ni elementos legibles.</p>';
      }

      return resultado;
    } catch (e) {
      return '<div style="padding: 12px; background-color: #fef2f2; border-radius: 8px; color: #991b1b;">'
          '<strong>Error al interpretar documento Word:</strong> $e'
          '</div>';
    }
  }

  /// Extrae el mapa de relaciones (rId -> Target) desde word/_rels/document.xml.rels
  static Map<String, String> _extraerRelaciones(Archive archive) {
    final mapRels = <String, String>{};
    try {
      final relsFile = archive.findFile('word/_rels/document.xml.rels');
      if (relsFile != null) {
        final xmlStr = utf8.decode(relsFile.content as List<int>, allowMalformed: true);
        final doc = XmlDocument.parse(xmlStr);
        for (final rel in doc.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id');
          final target = rel.getAttribute('Target');
          if (id != null && target != null) {
            mapRels[id] = target;
          }
        }
      }
    } catch (_) {}
    return mapRels;
  }

  /// Lee los archivos de imágenes de word/media/ y genera Data URIs base64
  static Map<String, String> _extraerImagenesBase64(Archive archive, Map<String, String> mapRelaciones) {
    final mapImagenes = <String, String>{};
    try {
      for (final file in archive) {
        if (file.name.startsWith('word/media/')) {
          final nombreMedia = file.name.replaceFirst('word/', '');
          final bytes = file.content as List<int>;
          final base64Str = base64Encode(bytes);

          String mimeType = 'image/png';
          final lowerName = file.name.toLowerCase();
          if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
            mimeType = 'image/jpeg';
          } else if (lowerName.endsWith('.gif')) {
            mimeType = 'image/gif';
          } else if (lowerName.endsWith('.webp')) {
            mimeType = 'image/webp';
          } else if (lowerName.endsWith('.svg')) {
            mimeType = 'image/svg+xml';
          }

          final dataUri = 'data:$mimeType;base64,$base64Str';
          mapImagenes[file.name] = dataUri;
          mapImagenes[nombreMedia] = dataUri;
        }
      }

      // Enlazar relaciones rId -> DataURI
      mapRelaciones.forEach((rId, target) {
        String cleanTarget = target.startsWith('/') ? target.substring(1) : target;
        if (!cleanTarget.startsWith('word/')) {
          cleanTarget = 'word/$cleanTarget';
        }
        if (mapImagenes.containsKey(cleanTarget)) {
          mapImagenes[rId] = mapImagenes[cleanTarget]!;
        }
      });
    } catch (_) {}
    return mapImagenes;
  }

  /// Procesa un párrafo `<w:p>` y genera su HTML `<p>`, `<h1>`-`<h6>` o `<ul>/<li>`
  static String _procesarParrafo(XmlElement pXml, Map<String, String> mapImagenes) {
    final pPr = pXml.findElements('w:pPr').firstOrNull;

    // Alineación
    String alignment = 'left';
    final jc = pPr?.findElements('w:jc').firstOrNull;
    if (jc != null) {
      final val = jc.getAttribute('w:val')?.toLowerCase() ?? 'left';
      if (val == 'center') {
        alignment = 'center';
      } else if (val == 'right') {
        alignment = 'right';
      } else if (val == 'both' || val == 'distribute') {
        alignment = 'justify';
      }
    }

    // Estilo de Párrafo (Heading 1-6, Title, Subtitle, etc.)
    String? styleVal;
    final pStyle = pPr?.findElements('w:pStyle').firstOrNull;
    if (pStyle != null) {
      styleVal = pStyle.getAttribute('w:val');
    }

    // Comprobar si es lista con viñetas o números
    bool esLista = pPr?.findElements('w:numPr').firstOrNull != null || (styleVal != null && styleVal.toLowerCase().contains('list'));

    // Generar contenido del párrafo
    final contenido = StringBuffer();
    for (final child in pXml.children) {
      if (child is XmlElement) {
        if (child.name.qualified == 'w:r') {
          contenido.write(_procesarRun(child, mapImagenes));
        } else if (child.name.qualified == 'w:hyperlink') {
          for (final run in child.findElements('w:r')) {
            contenido.write(_procesarRun(run, mapImagenes));
          }
        }
      }
    }

    final textoGenerado = contenido.toString().trim();
    if (textoGenerado.isEmpty && !esLista) {
      return '<div style="height: 10px;"></div>';
    }

    String tag = 'p';
    String extraStyles = 'margin: 6px 0; line-height: 1.6; text-align: $alignment;';

    if (styleVal != null) {
      final s = styleVal.toLowerCase();
      if (s.contains('title') || s == '1' || s.contains('heading1') || s.contains('titulo1')) {
        tag = 'h1';
        extraStyles = 'font-size: 20pt; font-weight: bold; color: #1e293b; margin: 16px 0 8px 0; text-align: $alignment;';
      } else if (s == '2' || s.contains('heading2') || s.contains('titulo2')) {
        tag = 'h2';
        extraStyles = 'font-size: 17pt; font-weight: bold; color: #334155; margin: 14px 0 6px 0; text-align: $alignment;';
      } else if (s == '3' || s.contains('heading3') || s.contains('titulo3')) {
        tag = 'h3';
        extraStyles = 'font-size: 14pt; font-weight: bold; color: #475569; margin: 12px 0 4px 0; text-align: $alignment;';
      } else if (s.contains('subtitle') || s.contains('subtitulo')) {
        tag = 'p';
        extraStyles = 'font-size: 13pt; font-style: italic; color: #64748b; margin: 4px 0 12px 0; text-align: $alignment;';
      }
    }

    if (esLista) {
      return '<li style="margin: 4px 0; text-align: $alignment;">$textoGenerado</li>';
    }

    return '<$tag style="$extraStyles">$textoGenerado</$tag>';
  }

  /// Procesa un fragmento de texto `<w:r>` (Run) y aplica estilos en línea
  static String _procesarRun(XmlElement rXml, Map<String, String> mapImagenes) {
    final buffer = StringBuffer();
    final rPr = rXml.findElements('w:rPr').firstOrNull;

    bool esNegrita = false;
    bool esCursiva = false;
    bool esSubrayado = false;
    bool esTachado = false;
    String? colorHex;
    String? fontSizePt;
    String? bgColor;

    if (rPr != null) {
      if (rPr.findElements('w:b').isNotEmpty) esNegrita = true;
      if (rPr.findElements('w:i').isNotEmpty) esCursiva = true;
      if (rPr.findElements('w:u').isNotEmpty) esSubrayado = true;
      if (rPr.findElements('w:strike').isNotEmpty) esTachado = true;

      final colorXml = rPr.findElements('w:color').firstOrNull;
      if (colorXml != null) {
        final val = colorXml.getAttribute('w:val');
        if (val != null && val.toLowerCase() != 'auto' && val.length == 6) {
          colorHex = '#$val';
        }
      }

      final szXml = rPr.findElements('w:sz').firstOrNull;
      if (szXml != null) {
        final val = int.tryParse(szXml.getAttribute('w:val') ?? '');
        if (val != null) {
          fontSizePt = '${(val / 2).toStringAsFixed(1)}pt';
        }
      }

      final highlightXml = rPr.findElements('w:highlight').firstOrNull;
      if (highlightXml != null) {
        final val = highlightXml.getAttribute('w:val')?.toLowerCase();
        if (val != null && val != 'none') {
          bgColor = _convertirColorHighlight(val);
        }
      }

      final shdXml = rPr.findElements('w:shd').firstOrNull;
      if (shdXml != null && bgColor == null) {
        final fill = shdXml.getAttribute('w:fill');
        if (fill != null && fill.toLowerCase() != 'auto' && fill.length == 6) {
          bgColor = '#$fill';
        }
      }
    }

    // 1. Extraer imágenes en la corrida
    for (final drawing in rXml.findAllElements('w:drawing')) {
      final imgHtml = _extraerImagenDeDrawing(drawing, mapImagenes);
      if (imgHtml.isNotEmpty) {
        buffer.write(imgHtml);
      }
    }
    for (final pict in rXml.findAllElements('w:pict')) {
      final imgHtml = _extraerImagenDePict(pict, mapImagenes);
      if (imgHtml.isNotEmpty) {
        buffer.write(imgHtml);
      }
    }

    // 2. Extraer texto
    final textBuffer = StringBuffer();
    for (final child in rXml.children) {
      if (child is XmlElement) {
        if (child.name.qualified == 'w:t') {
          textBuffer.write(_escaparHtml(child.innerText));
        } else if (child.name.qualified == 'w:tab') {
          textBuffer.write('&nbsp;&nbsp;&nbsp;&nbsp;');
        } else if (child.name.qualified == 'w:br') {
          textBuffer.write('<br/>');
        }
      }
    }

    String textoRaw = textBuffer.toString();
    if (textoRaw.isEmpty) {
      return buffer.toString();
    }

    // Aplicar estilos HTML
    final inlineStyles = <String>[];
    if (colorHex != null) inlineStyles.add('color: $colorHex');
    if (fontSizePt != null) inlineStyles.add('font-size: $fontSizePt');
    if (bgColor != null) inlineStyles.add('background-color: $bgColor');

    String resultadoSpan = textoRaw;
    if (esNegrita) resultadoSpan = '<b>$resultadoSpan</b>';
    if (esCursiva) resultadoSpan = '<i>$resultadoSpan</i>';
    if (esSubrayado) resultadoSpan = '<u>$resultadoSpan</u>';
    if (esTachado) resultadoSpan = '<s style="text-decoration: line-through;">$resultadoSpan</s>';

    if (inlineStyles.isNotEmpty) {
      resultadoSpan = '<span style="${inlineStyles.join('; ')}">$resultadoSpan</span>';
    }

    buffer.write(resultadoSpan);
    return buffer.toString();
  }

  /// Extrae imágenes embebidas dentro de `<w:drawing>`
  static String _extraerImagenDeDrawing(XmlElement drawing, Map<String, String> mapImagenes) {
    for (final blip in drawing.findAllElements('a:blip')) {
      final embedId = blip.getAttribute('r:embed') ?? blip.getAttribute('r:link');
      if (embedId != null && mapImagenes.containsKey(embedId)) {
        final src = mapImagenes[embedId]!;
        return '<img src="$src" alt="imagen Word" style="max-width: 100%; height: auto; border-radius: 8px; margin: 10px auto; display: block; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" />';
      }
    }
    return '';
  }

  /// Extrae imágenes embebidas dentro de `<w:pict>` o `<v:imagedata>`
  static String _extraerImagenDePict(XmlElement pict, Map<String, String> mapImagenes) {
    for (final imgData in pict.findAllElements('v:imagedata')) {
      final id = imgData.getAttribute('r:id') ?? imgData.getAttribute('o:title');
      if (id != null && mapImagenes.containsKey(id)) {
        final src = mapImagenes[id]!;
        return '<img src="$src" alt="imagen Word" style="max-width: 100%; height: auto; border-radius: 8px; margin: 10px auto; display: block;" />';
      }
    }
    return '';
  }

  /// Procesa tablas `<w:tbl>` generando etiquetado `<table>` con bordes y sombreados
  static String _procesarTabla(XmlElement tblXml, Map<String, String> mapImagenes) {
    final buffer = StringBuffer();
    buffer.write(
      '<table style="width: 100%; border-collapse: collapse; margin: 14px 0; '
      'border: 1px solid #cbd5e1; background-color: #ffffff; border-radius: 6px; overflow: hidden;">',
    );

    for (final tr in tblXml.findElements('w:tr')) {
      buffer.write('<tr>');
      for (final tc in tr.findElements('w:tc')) {
        String cellBg = '#ffffff';
        final tcPr = tc.findElements('w:tcPr').firstOrNull;
        if (tcPr != null) {
          final shd = tcPr.findElements('w:shd').firstOrNull;
          if (shd != null) {
            final fill = shd.getAttribute('w:fill');
            if (fill != null && fill.toLowerCase() != 'auto' && fill.length == 6) {
              cellBg = '#$fill';
            }
          }
        }

        buffer.write('<td style="border: 1px solid #cbd5e1; padding: 8px 12px; background-color: $cellBg; vertical-align: top;">');
        for (final p in tc.findElements('w:p')) {
          buffer.write(_procesarParrafo(p, mapImagenes));
        }
        buffer.write('</td>');
      }
      buffer.write('</tr>');
    }

    buffer.write('</table>');
    return buffer.toString();
  }

  static String _convertirColorHighlight(String color) {
    switch (color) {
      case 'yellow': return '#fef08a';
      case 'green': return '#bbf7d0';
      case 'cyan': return '#a5f3fc';
      case 'magenta': return '#fbcfe8';
      case 'blue': return '#bfdbfe';
      case 'red': return '#fecaca';
      case 'darkblue': return '#1e3a8a';
      case 'darkcyan': return '#0e7490';
      case 'darkgreen': return '#14532d';
      case 'darkmagenta': return '#831843';
      case 'darkred': return '#7f1d1d';
      case 'darkyellow': return '#713f12';
      case 'gray50': case 'lightgray': return '#e2e8f0';
      default: return '#f1f5f9';
    }
  }

  static String _escaparHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

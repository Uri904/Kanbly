import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Resultado del procesamiento de un archivo .docx que contiene sus páginas
/// en HTML y opcionalmente el pie de página o encabezado propio del documento.
class ResultadoDocx {
  final List<String> paginasHtml;
  final String? pieDePaginaDocx;
  final String? encabezadoDocx;

  ResultadoDocx({
    required this.paginasHtml,
    this.pieDePaginaDocx,
    this.encabezadoDocx,
  });
}

/// Representa un estilo de párrafo o carácter extraído de word/styles.xml
class DocxEstilo {
  final String id;
  final String? nombre;
  final String? baseEn;
  final String tipo; // 'paragraph' o 'character'

  final double? marginTopPt;
  final double? marginBottomPt;
  final double? lineRatio;
  final String? lineRule; // 'auto', 'exact', 'atLeast'
  final double? lineExactPt;

  final String? alineacion;
  final double? indentIzquierdaPt;
  final double? indentDerechaPt;
  final double? indentPrimeraLineaPt;

  final double? fontSizePt;
  final bool? esNegrita;
  final bool? esCursiva;
  final String? colorHex;

  DocxEstilo({
    required this.id,
    this.nombre,
    this.baseEn,
    this.tipo = 'paragraph',
    this.marginTopPt,
    this.marginBottomPt,
    this.lineRatio,
    this.lineRule,
    this.lineExactPt,
    this.alineacion,
    this.indentIzquierdaPt,
    this.indentDerechaPt,
    this.indentPrimeraLineaPt,
    this.fontSizePt,
    this.esNegrita,
    this.esCursiva,
    this.colorHex,
  });
}

/// Valores por defecto globales del documento extraídos de `<w:docDefaults>`
class DocxDefaults {
  double marginTopPt = 0.0;
  double marginBottomPt = 4.0;
  double lineRatio = 1.2; // Interlineado canónico de lectura A4
  String lineRule = 'auto';
  double? lineExactPt;
  String alineacion = 'left';
  double fontSizePt = 10.5;
  String colorHex = '#1e293b';
}

/// Estructura auxiliar para guardar la información de formato resuelta de un párrafo
class FormatoParrafo {
  final double marginTopPt;
  final double marginBottomPt;
  final double lineRatio;
  final String lineRule;
  final double? lineExactPt;
  final String alineacion;
  final double fontSizePt;
  final double indentIzquierdaPt;
  final double indentDerechaPt;
  final double indentPrimeraLineaPt;
  final String? styleVal;

  FormatoParrafo({
    required this.marginTopPt,
    required this.marginBottomPt,
    required this.lineRatio,
    required this.lineRule,
    this.lineExactPt,
    required this.alineacion,
    required this.fontSizePt,
    this.indentIzquierdaPt = 0.0,
    this.indentDerechaPt = 0.0,
    this.indentPrimeraLineaPt = 0.0,
    this.styleVal,
  });

  String get lineHeightCss {
    if (lineRule == 'exact' && lineExactPt != null) {
      return '${lineExactPt!.toStringAsFixed(1)}pt';
    }
    return lineRatio.toStringAsFixed(2);
  }
}

/// Clase utilitaria encargada de extraer y transformar la estructura interna
/// de un archivo Microsoft Word (.docx) a un lienzo vectorial A4 canónico (595pt x 842pt)
/// idéntico al renderizado PDF de escritorio.
class DocxParser {
  static Future<ResultadoDocx> procesarDocxCompleto({
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
        return ResultadoDocx(
          paginasHtml: ['<p style="color: #ef4444;">El archivo Word no está disponible o no existe localmente.</p>'],
        );
      }

      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Cargar relaciones
      final mapRelaciones = _extraerRelaciones(archive);

      // 2. Cargar imágenes
      final mapImagenesBase64 = _extraerImagenesBase64(archive, mapRelaciones);

      // 3. Extraer estilos del documento
      final defaults = DocxDefaults();
      final mapaEstilos = _extraerEstilos(archive, defaults);

      // 4. Extraer encabezado y pie de página
      final encabezadoEfectivo = _extraerEncabezadoXml(archive, mapImagenesBase64, mapaEstilos, defaults);
      final pieDePaginaEfectivo = _extraerPieDePaginaXml(archive, mapImagenesBase64, mapaEstilos, defaults);

      // 5. Cargar document.xml
      final docFile = archive.findFile('word/document.xml');
      if (docFile == null) {
        return ResultadoDocx(
          paginasHtml: ['<p style="color: #ef4444;">No se encontró la estructura "word/document.xml" dentro del archivo Word.</p>'],
        );
      }

      final xmlContent = utf8.decode(docFile.content as List<int>, allowMalformed: true);
      final documentXml = XmlDocument.parse(xmlContent);

      final bodyXml = documentXml.findAllElements('w:body').firstOrNull;
      if (bodyXml == null) {
        return ResultadoDocx(
          paginasHtml: ['<p style="color: #64748b; font-style: italic;">El documento Word está vacío.</p>'],
        );
      }

      final paginas = <String>[];
      var bufferPaginaActual = StringBuffer();
      double alturaAcumuladaPt = 0.0;
      const double maxAlturaA4Pt = 760.0; // Altura utilizable A4 (842pt - padding superior/inferior)

      void finalizarPaginaActual() {
        final content = bufferPaginaActual.toString().trim();
        if (content.isNotEmpty) {
          paginas.add(
            '<div class="docx-page" style="width: 100%; box-sizing: border-box; background: white; font-family: \'Inter\', \'Arial\', sans-serif; color: #1e293b; line-height: ${defaults.lineRatio.toStringAsFixed(2)}; font-size: ${defaults.fontSizePt.toStringAsFixed(1)}pt; position: relative;">'
            '$content'
            '</div>',
          );
        }
        bufferPaginaActual = StringBuffer();
        alturaAcumuladaPt = 0.0;
      }

      for (final child in bodyXml.children) {
        if (child is XmlElement) {
          bool saltoAntes = child.findAllElements('w:pageBreakBefore').isNotEmpty;
          if (saltoAntes && bufferPaginaActual.isNotEmpty) {
            finalizarPaginaActual();
          }

          bool esSaltoPaginaDespues = false;

          if (child.findAllElements('w:br').any((br) => br.getAttribute('w:type')?.toLowerCase() == 'page') ||
              child.findAllElements('w:sectPr').isNotEmpty) {
            esSaltoPaginaDespues = true;
          }

          if (child.findAllElements('w:lastRenderedPageBreak').isNotEmpty && bufferPaginaActual.isNotEmpty) {
            finalizerPaginaSiSaltoRenderizado(child, bufferPaginaActual, finalizarPaginaActual);
          }

          if (child.name.qualified == 'w:p') {
            final resParrafo = _procesarParrafo(child, mapImagenesBase64, mapaEstilos, defaults);
            bufferPaginaActual.write(resParrafo.html);
            alturaAcumuladaPt += resParrafo.alturaEstimadaPt;
          } else if (child.name.qualified == 'w:tbl') {
            final resTabla = _procesarTabla(child, mapImagenesBase64, mapaEstilos, defaults);
            bufferPaginaActual.write(resTabla.html);
            alturaAcumuladaPt += resTabla.alturaEstimadaPt;
          }

          if (esSaltoPaginaDespues || alturaAcumuladaPt >= maxAlturaA4Pt) {
            finalizarPaginaActual();
          }
        }
      }

      finalizarPaginaActual();

      if (paginas.isEmpty) {
        return ResultadoDocx(
          paginasHtml: ['<p style="color: #64748b; font-style: italic;">El documento Word no contiene texto ni elementos legibles.</p>'],
        );
      }

      return ResultadoDocx(
        paginasHtml: paginas,
        pieDePaginaDocx: pieDePaginaEfectivo,
        encabezadoDocx: encabezadoEfectivo,
      );
    } catch (e) {
      return ResultadoDocx(
        paginasHtml: [
          '<div style="padding: 12px; background-color: #fef2f2; border-radius: 8px; color: #991b1b;">'
              '<strong>Error al interpretar documento Word:</strong> $e'
              '</div>'
        ],
      );
    }
  }

  static void finalizerPaginaSiSaltoRenderizado(
    XmlElement child,
    StringBuffer buffer,
    void Function() finalizarCallback,
  ) {
    finalizarCallback();
  }

  static Future<List<String>> convertirDocxAPaginasHtml({
    File? archivoLocal,
    Uint8List? bytesArchivo,
  }) async {
    final res = await procesarDocxCompleto(
      archivoLocal: archivoLocal,
      bytesArchivo: bytesArchivo,
    );
    return res.paginasHtml;
  }

  static Future<String> convertirDocxAHtml({
    File? archivoLocal,
    Uint8List? bytesArchivo,
  }) async {
    final paginas = await convertirDocxAPaginasHtml(
      archivoLocal: archivoLocal,
      bytesArchivo: bytesArchivo,
    );
    return paginas.join('<hr style="border: none; border-top: 1px dashed #cbd5e1; margin: 24px 0;"/>');
  }

  static String? _extraerEncabezadoXml(
    Archive archive,
    Map<String, String> mapImagenes,
    Map<String, DocxEstilo> mapaEstilos,
    DocxDefaults defaults,
  ) {
    try {
      for (final file in archive) {
        if (file.name.startsWith('word/header')) {
          final xmlStr = utf8.decode(file.content as List<int>, allowMalformed: true);
          final doc = XmlDocument.parse(xmlStr);
          final bufferHeader = StringBuffer();

          for (final child in doc.rootElement.children) {
            if (child is XmlElement) {
              if (child.name.qualified == 'w:p') {
                final resParrafo = _procesarParrafo(child, mapImagenes, mapaEstilos, defaults, esHeaderOFooter: true);
                if (resParrafo.html.trim().isNotEmpty) {
                  bufferHeader.write(resParrafo.html);
                }
              } else if (child.name.qualified == 'w:tbl') {
                final resTabla = _procesarTabla(child, mapImagenes, mapaEstilos, defaults, esHeaderOFooter: true);
                bufferHeader.write(resTabla.html);
              }
            }
          }

          final headerClean = bufferHeader.toString().trim();
          if (headerClean.isNotEmpty) {
            return headerClean;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static String? _extraerPieDePaginaXml(
    Archive archive,
    Map<String, String> mapImagenes,
    Map<String, DocxEstilo> mapaEstilos,
    DocxDefaults defaults,
  ) {
    try {
      for (final file in archive) {
        if (file.name.startsWith('word/footer')) {
          final xmlStr = utf8.decode(file.content as List<int>, allowMalformed: true);
          final doc = XmlDocument.parse(xmlStr);
          final bufferFooter = StringBuffer();

          for (final child in doc.rootElement.children) {
            if (child is XmlElement) {
              if (child.name.qualified == 'w:p') {
                final resParrafo = _procesarParrafo(child, mapImagenes, mapaEstilos, defaults, esHeaderOFooter: true);
                if (resParrafo.html.trim().isNotEmpty) {
                  bufferFooter.write(resParrafo.html);
                }
              } else if (child.name.qualified == 'w:tbl') {
                final resTabla = _procesarTabla(child, mapImagenes, mapaEstilos, defaults, esHeaderOFooter: true);
                bufferFooter.write(resTabla.html);
              }
            }
          }

          final footerClean = bufferFooter.toString().trim();
          if (footerClean.isNotEmpty) {
            return footerClean;
          }
        }
      }
    } catch (_) {}
    return null;
  }

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

  static Map<String, DocxEstilo> _extraerEstilos(Archive archive, DocxDefaults defaults) {
    final mapaEstilos = <String, DocxEstilo>{};
    try {
      final file = archive.findFile('word/styles.xml');
      if (file == null) return mapaEstilos;

      final xmlStr = utf8.decode(file.content as List<int>, allowMalformed: true);
      final doc = XmlDocument.parse(xmlStr);

      final docDefaultsXml = doc.findAllElements('w:docDefaults').firstOrNull;
      if (docDefaultsXml != null) {
        final pPrDef = docDefaultsXml.findAllElements('w:pPrDefault').firstOrNull?.findElements('w:pPr').firstOrNull;
        if (pPrDef != null) {
          _extraerSpacingXml(pPrDef, (marginT, marginB, ratio, rule, exactPt) {
            if (marginT != null) defaults.marginTopPt = marginT;
            if (marginB != null) defaults.marginBottomPt = marginB;
            if (ratio != null) defaults.lineRatio = ratio;
            if (rule != null) defaults.lineRule = rule;
            if (exactPt != null) defaults.lineExactPt = exactPt;
          });
        }
        final rPrDef = docDefaultsXml.findAllElements('w:rPrDefault').firstOrNull?.findElements('w:rPr').firstOrNull;
        if (rPrDef != null) {
          final sz = rPrDef.findElements('w:sz').firstOrNull?.getAttribute('w:val');
          if (sz != null) {
            final szVal = int.tryParse(sz);
            if (szVal != null) defaults.fontSizePt = szVal / 2.0;
          }
        }
      }

      for (final styleXml in doc.findAllElements('w:style')) {
        final styleId = styleXml.getAttribute('w:styleId');
        if (styleId == null) continue;

        final type = styleXml.getAttribute('w:type') ?? 'paragraph';
        final name = styleXml.findElements('w:name').firstOrNull?.getAttribute('w:val');
        final basedOn = styleXml.findElements('w:basedOn').firstOrNull?.getAttribute('w:val');

        double? marginT, marginB, ratio, exactPt;
        String? rule, align;
        double? indL, indR, indFirst;

        final pPr = styleXml.findElements('w:pPr').firstOrNull;
        if (pPr != null) {
          _extraerSpacingXml(pPr, (t, b, r, ruleVal, ePt) {
            marginT = t; marginB = b; ratio = r; rule = ruleVal; exactPt = ePt;
          });
          align = _extraerAlineacionXml(pPr);
          final indRes = _extraerIndentacionXml(pPr);
          indL = indRes.left; indR = indRes.right; indFirst = indRes.firstLine;
        }

        double? fontSz;
        bool? negrita, cursiva;
        String? col;

        final rPr = styleXml.findElements('w:rPr').firstOrNull;
        if (rPr != null) {
          if (rPr.findElements('w:b').isNotEmpty) negrita = true;
          if (rPr.findElements('w:i').isNotEmpty) cursiva = true;
          final szVal = int.tryParse(rPr.findElements('w:sz').firstOrNull?.getAttribute('w:val') ?? '');
          if (szVal != null) fontSz = szVal / 2.0;
          final cVal = rPr.findElements('w:color').firstOrNull?.getAttribute('w:val');
          if (cVal != null && cVal.toLowerCase() != 'auto' && cVal.length == 6) col = '#$cVal';
        }

        mapaEstilos[styleId] = DocxEstilo(
          id: styleId,
          nombre: name,
          baseEn: basedOn,
          tipo: type,
          marginTopPt: marginT,
          marginBottomPt: marginB,
          lineRatio: ratio,
          lineRule: rule,
          lineExactPt: exactPt,
          alineacion: align,
          indentIzquierdaPt: indL,
          indentDerechaPt: indR,
          indentPrimeraLineaPt: indFirst,
          fontSizePt: fontSz,
          esNegrita: negrita,
          esCursiva: cursiva,
          colorHex: col,
        );
      }
    } catch (_) {}
    return mapaEstilos;
  }

  static void _extraerSpacingXml(
    XmlElement pPr,
    void Function(double? marginT, double? marginB, double? ratio, String? rule, double? exactPt) callback,
  ) {
    final spacingXml = pPr.findElements('w:spacing').firstOrNull;
    if (spacingXml == null) return;

    double? marginT, marginB, ratio, exactPt;
    String? rule;

    final beforeVal = int.tryParse(spacingXml.getAttribute('w:before') ?? '');
    if (beforeVal != null && beforeVal >= 0) {
      marginT = beforeVal / 20.0;
    } else {
      final beforeLines = int.tryParse(spacingXml.getAttribute('w:beforeLines') ?? '');
      if (beforeLines != null && beforeLines >= 0) {
        marginT = (beforeLines / 100.0) * 10.5;
      } else if (spacingXml.getAttribute('w:beforeAutospacing') == '1' || spacingXml.getAttribute('w:beforeAutospacing') == 'true') {
        marginT = 10.0;
      }
    }

    final afterVal = int.tryParse(spacingXml.getAttribute('w:after') ?? '');
    if (afterVal != null && afterVal >= 0) {
      marginB = afterVal / 20.0;
    } else {
      final afterLines = int.tryParse(spacingXml.getAttribute('w:afterLines') ?? '');
      if (afterLines != null && afterLines >= 0) {
        marginB = (afterLines / 100.0) * 10.5;
      } else if (spacingXml.getAttribute('w:afterAutospacing') == '1' || spacingXml.getAttribute('w:afterAutospacing') == 'true') {
        marginB = 4.0;
      }
    }

    final lineVal = int.tryParse(spacingXml.getAttribute('w:line') ?? '');
    if (lineVal != null && lineVal > 0) {
      rule = spacingXml.getAttribute('w:lineRule')?.toLowerCase() ?? 'auto';
      if (rule == 'auto') {
        ratio = lineVal / 240.0;
      } else if (rule == 'exact') {
        exactPt = (lineVal / 20.0).abs();
      } else if (rule == 'atleast') {
        rule = 'atleast';
        ratio = max(1.0, (lineVal / 20.0) / 10.5);
      }
    }

    callback(marginT, marginB, ratio, rule, exactPt);
  }

  static String? _extraerAlineacionXml(XmlElement pPr) {
    final jc = pPr.findElements('w:jc').firstOrNull;
    if (jc != null) {
      final val = jc.getAttribute('w:val')?.toLowerCase() ?? 'left';
      if (val == 'center') return 'center';
      if (val == 'right') return 'right';
      if (val == 'both' || val == 'distribute') return 'justify';
      return 'left';
    }
    return null;
  }

  static ({double? left, double? right, double? firstLine}) _extraerIndentacionXml(XmlElement pPr) {
    final ind = pPr.findElements('w:ind').firstOrNull;
    if (ind != null) {
      final l = int.tryParse(ind.getAttribute('w:left') ?? '');
      final r = int.tryParse(ind.getAttribute('w:right') ?? '');
      final fl = int.tryParse(ind.getAttribute('w:firstLine') ?? '');
      final h = int.tryParse(ind.getAttribute('w:hanging') ?? '');

      double? leftPt = l != null ? l / 20.0 : null;
      double? rightPt = r != null ? r / 20.0 : null;
      double? firstPt;
      if (fl != null) {
        firstPt = fl / 20.0;
      } else if (h != null) {
        firstPt = -(h / 20.0);
      }
      return (left: leftPt, right: rightPt, firstLine: firstPt);
    }
    return (left: null, right: null, firstLine: null);
  }

  static FormatoParrafo _resolverFormatoParrafo(
    XmlElement pXml,
    Map<String, DocxEstilo> mapaEstilos,
    DocxDefaults defaults, {
    bool esHeaderOFooter = false,
  }) {
    final pPr = pXml.findElements('w:pPr').firstOrNull;

    String? styleVal = pPr?.findElements('w:pStyle').firstOrNull?.getAttribute('w:val');

    final estilosJerarquia = <DocxEstilo>[];
    String? idBuscado = styleVal ?? 'Normal';
    final visitados = <String>{};

    while (idBuscado != null && mapaEstilos.containsKey(idBuscado) && !visitados.contains(idBuscado)) {
      visitados.add(idBuscado);
      final est = mapaEstilos[idBuscado]!;
      estilosJerarquia.add(est);
      idBuscado = est.baseEn;
    }

    double? marginT, marginB, ratio, exactPt;
    String? rule;
    if (pPr != null) {
      _extraerSpacingXml(pPr, (t, b, r, ruleVal, ePt) {
        marginT = t; marginB = b; ratio = r; rule = ruleVal; exactPt = ePt;
      });
    }

    String? align = pPr != null ? _extraerAlineacionXml(pPr) : null;
    final indRes = pPr != null ? _extraerIndentacionXml(pPr) : (left: null, right: null, firstLine: null);

    for (final est in estilosJerarquia) {
      marginT ??= est.marginTopPt;
      marginB ??= est.marginBottomPt;
      ratio ??= est.lineRatio;
      rule ??= est.lineRule;
      exactPt ??= est.lineExactPt;
      align ??= est.alineacion;
    }

    final double defaultFontSize = esHeaderOFooter ? 8.5 : defaults.fontSizePt;
    final double defaultMarginT = esHeaderOFooter ? 0.0 : defaults.marginTopPt;
    final double defaultMarginB = esHeaderOFooter ? 2.0 : defaults.marginBottomPt;
    final double defaultRatio = esHeaderOFooter ? 1.1 : defaults.lineRatio;

    final effectiveMarginTop = marginT ?? defaultMarginT;
    final effectiveMarginBottom = marginB ?? defaultMarginB;
    final effectiveRatio = ratio ?? defaultRatio;
    final effectiveRule = rule ?? defaults.lineRule;
    final effectiveAlign = align ?? defaults.alineacion;

    double? resolvedFontSizePt;
    for (final run in pXml.findElements('w:r')) {
      final szVal = int.tryParse(run.findElements('w:rPr').firstOrNull?.findElements('w:sz').firstOrNull?.getAttribute('w:val') ?? '');
      if (szVal != null) {
        resolvedFontSizePt = szVal / 2.0;
        break;
      }
    }
    if (resolvedFontSizePt == null && pPr != null) {
      final szVal = int.tryParse(pPr.findElements('w:rPr').firstOrNull?.findElements('w:sz').firstOrNull?.getAttribute('w:val') ?? '');
      if (szVal != null) {
        resolvedFontSizePt = szVal / 2.0;
      }
    }
    if (resolvedFontSizePt == null) {
      for (final est in estilosJerarquia) {
        if (est.fontSizePt != null) {
          resolvedFontSizePt = est.fontSizePt;
          break;
        }
      }
    }
    final double effectiveFontSizePt = resolvedFontSizePt ?? defaultFontSize;

    return FormatoParrafo(
      marginTopPt: effectiveMarginTop,
      marginBottomPt: effectiveMarginBottom,
      lineRatio: effectiveRatio,
      lineRule: effectiveRule,
      lineExactPt: exactPt ?? defaults.lineExactPt,
      alineacion: effectiveAlign,
      fontSizePt: effectiveFontSizePt,
      indentIzquierdaPt: indRes.left ?? 0.0,
      indentDerechaPt: indRes.right ?? 0.0,
      indentPrimeraLineaPt: indRes.firstLine ?? 0.0,
      styleVal: styleVal,
    );
  }

  static ({String html, double alturaEstimadaPt}) _procesarParrafo(
    XmlElement pXml,
    Map<String, String> mapImagenes,
    Map<String, DocxEstilo> mapaEstilos,
    DocxDefaults defaults, {
    bool esHeaderOFooter = false,
  }) {
    final pPr = pXml.findElements('w:pPr').firstOrNull;
    final fmt = _resolverFormatoParrafo(
      pXml,
      mapaEstilos,
      defaults,
      esHeaderOFooter: esHeaderOFooter,
    );

    bool esLista = pPr?.findElements('w:numPr').firstOrNull != null ||
        (fmt.styleVal != null && fmt.styleVal!.toLowerCase().contains('list'));

    final contenido = StringBuffer();
    for (final child in pXml.children) {
      if (child is XmlElement) {
        if (child.name.qualified == 'w:r') {
          contenido.write(_procesarRun(child, mapImagenes));
        } else if (child.name.qualified == 'w:hyperlink') {
          for (final run in child.findElements('w:r')) {
            contenido.write(_procesarRun(run, mapImagenes));
          }
        } else if (child.name.qualified == 'w:fldSimple') {
          final instr = child.getAttribute('w:instr')?.toUpperCase() ?? '';
          if (instr.contains('PAGE') && !instr.contains('NUMPAGES')) {
            contenido.write('{{PAGE}}');
          } else if (instr.contains('NUMPAGES')) {
            contenido.write('{{NUMPAGES}}');
          } else {
            for (final run in child.findElements('w:r')) {
              contenido.write(_procesarRun(run, mapImagenes));
            }
          }
        } else if (child.name.qualified == 'w:sdt') {
          for (final p in child.findAllElements('w:p')) {
            final resP = _procesarParrafo(p, mapImagenes, mapaEstilos, defaults, esHeaderOFooter: esHeaderOFooter);
            contenido.write(resP.html);
          }
        }
      }
    }

    final textoGenerado = contenido.toString().trim();

    final bufferStyles = StringBuffer();
    bufferStyles.write('margin-top: ${fmt.marginTopPt.toStringAsFixed(1)}pt; ');
    bufferStyles.write('margin-bottom: ${fmt.marginBottomPt.toStringAsFixed(1)}pt; ');
    bufferStyles.write('line-height: ${fmt.lineHeightCss}; ');
    bufferStyles.write('font-size: ${fmt.fontSizePt.toStringAsFixed(1)}pt; ');
    bufferStyles.write('text-align: ${fmt.alineacion}; ');
    if (fmt.indentIzquierdaPt > 0) {
      bufferStyles.write('margin-left: ${fmt.indentIzquierdaPt.toStringAsFixed(1)}pt; ');
    }
    if (fmt.indentDerechaPt > 0) {
      bufferStyles.write('margin-right: ${fmt.indentDerechaPt.toStringAsFixed(1)}pt; ');
    }
    if (fmt.indentPrimeraLineaPt != 0) {
      bufferStyles.write('text-indent: ${fmt.indentPrimeraLineaPt.toStringAsFixed(1)}pt; ');
    }

    final numLineasAprox = max(1, (textoGenerado.length / 65.0).ceil());
    final ratioEfectivo = fmt.lineRule == 'exact' && fmt.lineExactPt != null ? (fmt.lineExactPt! / fmt.fontSizePt) : fmt.lineRatio;
    final alturaParrafoPt = fmt.marginTopPt + fmt.marginBottomPt + (numLineasAprox * fmt.fontSizePt * ratioEfectivo);

    final defaultTextColor = esHeaderOFooter ? 'color: #64748b;' : 'color: #1e293b;';

    if (textoGenerado.isEmpty && !esLista) {
      return (
        html: '<p style="${bufferStyles.toString()} $defaultTextColor">&nbsp;</p>',
        alturaEstimadaPt: fmt.marginTopPt + fmt.marginBottomPt + (fmt.fontSizePt * ratioEfectivo),
      );
    }

    String tag = 'p';
    String colorColoring = defaultTextColor;

    if (fmt.styleVal != null) {
      final s = fmt.styleVal!.toLowerCase();
      if (s.contains('title') || s == '1' || s.contains('heading1') || s.contains('titulo1')) {
        tag = 'h1';
        colorColoring = 'color: #1b4b84; font-weight: bold; font-size: 16pt; margin-top: 12pt; margin-bottom: 6pt; border-bottom: 1.5px solid #cbd5e1; padding-bottom: 3pt;';
      } else if (s == '2' || s.contains('heading2') || s.contains('titulo2')) {
        tag = 'h2';
        colorColoring = 'color: #2b579a; font-weight: bold; font-size: 13pt; margin-top: 10pt; margin-bottom: 4pt; border-bottom: 1px solid #e2e8f0; padding-bottom: 2pt;';
      } else if (s == '3' || s.contains('heading3') || s.contains('titulo3')) {
        tag = 'h3';
        colorColoring = 'color: #1b4b84; font-weight: bold; font-size: 11.5pt;';
      } else if (s.contains('subtitle') || s.contains('subtitulo')) {
        tag = 'p';
        colorColoring = 'color: #475569; font-style: italic; font-size: 10.5pt;';
      }
    }

    if (esLista) {
      return (
        html: '<li style="${bufferStyles.toString()} $colorColoring">$textoGenerado</li>',
        alturaEstimadaPt: alturaParrafoPt,
      );
    }

    return (
      html: '<$tag style="${bufferStyles.toString()} $colorColoring">$textoGenerado</$tag>',
      alturaEstimadaPt: alturaParrafoPt,
    );
  }

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
          fontSizePt = '${(val / 2.0).toStringAsFixed(1)}pt';
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

    final textBuffer = StringBuffer();
    for (final child in rXml.children) {
      if (child is XmlElement) {
        if (child.name.qualified == 'w:t') {
          textBuffer.write(_escaparHtml(child.innerText));
        } else if (child.name.qualified == 'w:tab') {
          textBuffer.write('&nbsp;&nbsp;&nbsp;&nbsp;');
        } else if (child.name.qualified == 'w:br') {
          textBuffer.write('<br/>');
        } else if (child.name.qualified == 'w:instrText') {
          final text = child.innerText.toUpperCase();
          if (text.contains('PAGE') && !text.contains('NUMPAGES')) {
            textBuffer.write('{{PAGE}}');
          } else if (text.contains('NUMPAGES')) {
            textBuffer.write('{{NUMPAGES}}');
          }
        }
      }
    }

    String textoRaw = textBuffer.toString();
    if (textoRaw.isEmpty) {
      return buffer.toString();
    }

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

  static String _extraerImagenDeDrawing(XmlElement drawing, Map<String, String> mapImagenes) {
    for (final blip in drawing.findAllElements('a:blip')) {
      final embedId = blip.getAttribute('r:embed') ?? blip.getAttribute('r:link');
      if (embedId != null && mapImagenes.containsKey(embedId)) {
        final src = mapImagenes[embedId]!;
        return '<img src="$src" alt="imagen Word" style="max-width: 100%; height: auto; border-radius: 4px; margin: 8px auto; display: block; box-shadow: 0 2px 8px rgba(0,0,0,0.08);" />';
      }
    }
    return '';
  }

  static String _extraerImagenDePict(XmlElement pict, Map<String, String> mapImagenes) {
    for (final imgData in pict.findAllElements('v:imagedata')) {
      final id = imgData.getAttribute('r:id') ?? imgData.getAttribute('o:title');
      if (id != null && mapImagenes.containsKey(id)) {
        final src = mapImagenes[id]!;
        return '<img src="$src" alt="imagen Word" style="max-width: 100%; height: auto; border-radius: 4px; margin: 8px auto; display: block;" />';
      }
    }
    return '';
  }

  static ({String html, double alturaEstimadaPt}) _procesarTabla(
    XmlElement tblXml,
    Map<String, String> mapImagenes,
    Map<String, DocxEstilo> mapaEstilos,
    DocxDefaults defaults, {
    bool esHeaderOFooter = false,
  }) {
    final buffer = StringBuffer();
    final tableFontSize = esHeaderOFooter ? '8.5pt' : '10.0pt';

    bool tieneBordesExplicitosNulos = false;
    final tblPr = tblXml.findElements('w:tblPr').firstOrNull;
    if (tblPr != null) {
      final tblBorders = tblPr.findElements('w:tblBorders').firstOrNull;
      if (tblBorders != null) {
        final todosNulos = tblBorders.children.whereType<XmlElement>().every((b) {
          final val = b.getAttribute('w:val')?.toLowerCase();
          return val == 'none' || val == 'nil' || val == '0';
        });
        if (todosNulos) {
          tieneBordesExplicitosNulos = true;
        }
      }
    }

    final esSinBordes = esHeaderOFooter || tieneBordesExplicitosNulos;
    final tableStyleStr = esSinBordes
        ? 'width: 100%; border-collapse: collapse; margin: 4px 0; border: none; font-size: $tableFontSize;'
        : 'width: 100%; border-collapse: collapse; margin: 8px 0; border: 1px solid #cbd5e1; background-color: #ffffff; font-size: $tableFontSize;';

    buffer.write('<table style="$tableStyleStr">');

    int filas = 0;
    for (final tr in tblXml.findElements('w:tr')) {
      filas++;
      buffer.write('<tr>');
      for (final tc in tr.findElements('w:tc')) {
        String cellBg = 'transparent';
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

        final cellBorderStyle = esSinBordes
            ? 'border: none;'
            : 'border: 1px solid #cbd5e1;';
        final cellPaddingStyle = esHeaderOFooter ? 'padding: 2px 4px;' : 'padding: 6px 10px;';
        final cellBgStyle = cellBg != 'transparent' ? 'background-color: $cellBg;' : '';

        buffer.write('<td style="$cellBorderStyle $cellPaddingStyle $cellBgStyle vertical-align: top;">');
        for (final p in tc.findElements('w:p')) {
          final resP = _procesarParrafo(
            p,
            mapImagenes,
            mapaEstilos,
            defaults,
            esHeaderOFooter: esHeaderOFooter,
          );
          buffer.write(resP.html);
        }
        buffer.write('</td>');
      }
      buffer.write('</tr>');
    }

    buffer.write('</table>');
    final alturaEstimada = max(20.0, filas * 22.0);
    return (html: buffer.toString(), alturaEstimadaPt: alturaEstimada);
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

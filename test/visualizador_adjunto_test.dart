import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanbly/modelo/tarea.dart';
import 'package:kanbly/utilerias/docx_parser.dart';
import 'package:kanbly/utilerias/pptx_parser.dart';
import 'package:archive/archive.dart';

void main() {
  group('Pruebas del Visualizador de Archivos Adjuntos y Parsers Office', () {
    test('Identificación correcta del modelo AdjuntoTarea', () {
      final adjuntoWord = AdjuntoTarea(
        id: '1',
        nombre: 'DocumentoProyecto.docx',
        url: '/ruta/falsa/DocumentoProyecto.docx',
        tipo: 'documento',
        tamanoBytes: 2048500,
        fechaAdjunto: DateTime.now(),
      );

      expect(adjuntoWord.nombre, equals('DocumentoProyecto.docx'));
      expect(adjuntoWord.tamanoLegible, equals('2.0 MB'));
      expect(adjuntoWord.tipo, equals('documento'));

      final adjuntoPdf = AdjuntoTarea(
        id: '2',
        nombre: 'ReporteFinal.pdf',
        url: 'https://ejemplo.com/ReporteFinal.pdf',
        tipo: 'documento',
        tamanoBytes: 512000,
        fechaAdjunto: DateTime.now(),
      );

      expect(adjuntoPdf.tamanoLegible, equals('500.0 KB'));

      final adjuntoPptx = AdjuntoTarea(
        id: '3',
        nombre: 'PresentacionEjecutiva.pptx',
        url: '/ruta/falsa/PresentacionEjecutiva.pptx',
        tipo: 'documento',
        tamanoBytes: 3145728,
        fechaAdjunto: DateTime.now(),
      );

      expect(adjuntoPptx.nombre.endsWith('.pptx'), isTrue);
      expect(adjuntoPptx.tamanoLegible, equals('3.0 MB'));
    });

    test('Parser Docx convierte XML básico de Word a páginas HTML con formato de impresión', () async {
      final archive = Archive();

      const xmlDocumentContent = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr>
        <w:pStyle w:val="Heading1"/>
        <w:jc w:val="center"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:b/>
          <w:color w:val="2B579A"/>
        </w:rPr>
        <w:t>Título Principal del Proyecto</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:r>
        <w:rPr>
          <w:i/>
        </w:rPr>
        <w:t>Este es un párrafo de prueba en cursiva.</w:t>
      </w:r>
    </w:p>
  </w:body>
</w:document>''';

      final utf8Bytes = utf8.encode(xmlDocumentContent);
      archive.addFile(ArchiveFile(
        'word/document.xml',
        utf8Bytes.length,
        utf8Bytes,
      ));

      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive);

      expect(zipBytes, isNotNull);

      final paginas = await DocxParser.convertirDocxAPaginasHtml(
        bytesArchivo: Uint8List.fromList(zipBytes!),
      );

      expect(paginas.length, equals(1));
      expect(paginas.first, contains('<h1'));
      expect(paginas.first, contains('Título Principal del Proyecto'));
      expect(paginas.first, contains('color: #2B579A'));
      expect(paginas.first, contains('<i>Este es un párrafo de prueba en cursiva.</i>'));
    });

    test('PptxParser extrae diapositivas y títulos correctamente', () async {
      final archive = Archive();

      const slideXmlContent = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:nvSpPr>
          <p:nvPr>
            <p:ph type="title"/>
          </p:nvPr>
        </p:nvSpPr>
        <p:txBody>
          <a:p>
            <a:r>
              <a:t>Visión Estratégica 2026</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:txBody>
          <a:p>
            <a:r>
              <a:t>Punto clave de la propuesta de valor.</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';

      final bytesSlide = utf8.encode(slideXmlContent);
      archive.addFile(ArchiveFile('ppt/slides/slide1.xml', bytesSlide.length, bytesSlide));

      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive);

      final res = await PptxParser.procesarPptxCompleto(
        bytesArchivo: Uint8List.fromList(zipBytes!),
      );

      expect(res.diapositivas.length, equals(1));
      expect(res.diapositivas.first.titulo, equals('Visión Estratégica 2026'));
      expect(res.diapositivas.first.parrafos.first, equals('Punto clave de la propuesta de valor.'));
    });

    test('Manejo de archivo inexistente o nulo en DocxParser', () async {
      final resultadoErr = await DocxParser.convertirDocxAHtml(
        archivoLocal: File('/ruta/totalmente/inexistente/doc.docx'),
      );

      expect(resultadoErr, contains('El archivo Word no está disponible o no existe localmente.'));
    });

    test('Verificación de soporte de adjuntos PowerPoint y extensión PPTX/PPT', () {
      final adjuntoPowerPoint = AdjuntoTarea(
        id: '4',
        nombre: 'PresentacionEstrategica.pptx',
        url: '/ruta/local/PresentacionEstrategica.pptx',
        tipo: 'documento',
        tamanoBytes: 1572864,
        fechaAdjunto: DateTime.now(),
      );

      expect(adjuntoPowerPoint.nombre.endsWith('.pptx'), isTrue);
      expect(adjuntoPowerPoint.tamanoLegible, equals('1.5 MB'));
    });
  });
}

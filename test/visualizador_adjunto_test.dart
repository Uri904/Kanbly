import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanbly/modelo/tarea.dart';
import 'package:kanbly/utilerias/docx_parser.dart';
import 'package:archive/archive.dart';

void main() {
  group('Pruebas del Visualizador de Archivos Adjuntos y Parser DOCX', () {
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
    });

    test('Parser Docx convierte XML básico de Word a HTML con formato', () async {
      // Crear un archivo zip simulación de .docx en memoria
      final archive = Archive();

      // word/document.xml simulado con títulos, negrita y alineación centrada
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

      final htmlResult = await DocxParser.convertirDocxAHtml(
        bytesArchivo: Uint8List.fromList(zipBytes!),
      );

      expect(htmlResult, contains('<h1'));
      expect(htmlResult, contains('Título Principal del Proyecto'));
      expect(htmlResult, contains('color: #2B579A'));
      expect(htmlResult, contains('<i>Este es un párrafo de prueba en cursiva.</i>'));
    });

    test('Manejo de archivo inexistente o nulo en DocxParser', () async {
      final resultadoErr = await DocxParser.convertirDocxAHtml(
        archivoLocal: File('/ruta/totalmente/inexistente/doc.docx'),
      );

      expect(resultadoErr, contains('El archivo Word no está disponible o no existe localmente.'));
    });
  });
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utilerias/docx_parser.dart';

/// Visor interactivo para documentos Microsoft Word (.docx) que presenta el
/// contenido conservando su formato original (títulos, negritas, cursivas,
/// alineación, listas, tablas e imágenes embebidas) dentro de una hoja digital.
class VisorDocx extends StatefulWidget {
  final File? archivoLocal;
  final String urlRemota;
  final String nombreArchivo;

  const VisorDocx({
    super.key,
    this.archivoLocal,
    required this.urlRemota,
    required this.nombreArchivo,
  });

  @override
  State<VisorDocx> createState() => _VisorDocxState();
}

class _VisorDocxState extends State<VisorDocx> {
  String _htmlContenido = '';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDocumentoWord();
  }

  Future<void> _cargarDocumentoWord() async {
    setState(() => _cargando = true);

    File? archivoAUsar = widget.archivoLocal;
    if (archivoAUsar == null || !archivoAUsar.existsSync()) {
      final url = widget.urlRemota.trim();
      if (url.isNotEmpty && !url.startsWith('http') && File(url).existsSync()) {
        archivoAUsar = File(url);
      }
    }

    final htmlResult = await DocxParser.convertirDocxAHtml(
      archivoLocal: archivoAUsar,
    );

    if (mounted) {
      setState(() {
        _htmlContenido = htmlResult;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF2B579A)),
            const SizedBox(height: 16),
            Text(
              'Procesando formato del documento Word...',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ENCABEZADO FORMATO HOJA MICROSOFT WORD
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF2B579A), // Azul clásico de Microsoft Word
            ),
            child: Row(
              children: [
                const Icon(Icons.description_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.nombreArchivo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Documento Microsoft Word • Vista de Lectura con Formato',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CUERPO HOJA DIGITAL FORMATO HTML
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: SelectionArea(
                child: HtmlWidget(
                  _htmlContenido,
                  textStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF1E293B),
                    height: 1.6,
                  ),
                  customStylesBuilder: (element) {
                    if (element.localName == 'table') {
                      return {
                        'border-collapse': 'collapse',
                        'width': '100%',
                        'margin': '12px 0',
                      };
                    }
                    if (element.localName == 'td') {
                      return {
                        'padding': '8px 10px',
                        'border': '1px solid #cbd5e1',
                      };
                    }
                    return null;
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

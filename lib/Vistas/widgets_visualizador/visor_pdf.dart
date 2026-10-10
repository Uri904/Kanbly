import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

/// Visor nativo e interactivo para archivos PDF (.pdf) con soporte para
/// delimitación clara de páginas sobre un fondo contrastante tenue, bordes de hoja,
/// sombras de papel, paginación, indicador de páginas y controles de navegación.
class VisorPdf extends StatefulWidget {
  final File? archivoLocal;
  final String urlRemota;
  final String nombreArchivo;

  const VisorPdf({
    super.key,
    this.archivoLocal,
    required this.urlRemota,
    required this.nombreArchivo,
  });

  @override
  State<VisorPdf> createState() => _VisorPdfState();
}

class _VisorPdfState extends State<VisorPdf> {
  String? _pathLocalDefinitivo;
  bool _cargando = true;
  String? _mensajeError;

  PDFViewController? _pdfViewController;
  int _totalPaginas = 0;
  int _paginaActual = 0;
  bool _pdfListo = false;

  @override
  void initState() {
    super.initState();
    _prepararArchivoPdf();
  }

  Future<void> _prepararArchivoPdf() async {
    setState(() {
      _cargando = true;
      _mensajeError = null;
    });

    try {
      if (widget.archivoLocal != null && widget.archivoLocal!.existsSync()) {
        setState(() {
          _pathLocalDefinitivo = widget.archivoLocal!.path;
          _cargando = false;
        });
        return;
      }

      final url = widget.urlRemota.trim();
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();

        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final fileNameClean = widget.nombreArchivo.replaceAll(RegExp(r'[^\w.-]'), '_');
          final file = File('${tempDir.path}/pdf_$fileNameClean');
          await response.pipe(file.openWrite());

          if (mounted) {
            setState(() {
              _pathLocalDefinitivo = file.path;
              _cargando = false;
            });
          }
        } else {
          throw Exception('Código de respuesta servidor: ${response.statusCode}');
        }
      } else if (url.isNotEmpty && File(url).existsSync()) {
        setState(() {
          _pathLocalDefinitivo = url;
          _cargando = false;
        });
      } else {
        throw Exception('El archivo PDF local no existe y la URL no es válida.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensajeError = 'Error al descargar o cargar el PDF: $e';
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        color: const Color(0xFFFFF5F5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFD32F2F)),
            const SizedBox(height: 16),
            Text(
              'Cargando documento PDF...',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF991B1B), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_mensajeError != null || _pathLocalDefinitivo == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          children: [
            const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              'No se pudo abrir el archivo PDF',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red.shade900),
            ),
            const SizedBox(height: 6),
            Text(
              _mensajeError ?? 'Ruta no válida.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              onPressed: _prepararArchivoPdf,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5), // Fondo rojo tenue de mesa de trabajo
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade900.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // BARRA SUPERIOR DE CONTROL DE PAGINACIÓN PDF EN ROJO Y BLANCO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFD32F2F),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.nombreArchivo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                if (_pdfListo && _totalPaginas > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: Text(
                      'Pág. ${_paginaActual + 1} de $_totalPaginas',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _paginaActual > 0
                        ? () {
                            _pdfViewController?.setPage(_paginaActual - 1);
                          }
                        : null,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _paginaActual < _totalPaginas - 1
                        ? () {
                            _pdfViewController?.setPage(_paginaActual + 1);
                          }
                        : null,
                  ),
                ],
              ],
            ),
          ),

          // VISTA PRINCIPAL CON MARCO DE HOJA DE PAPEL Y DEGRADADO
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    PDFView(
                      filePath: _pathLocalDefinitivo!,
                      backgroundColor: const Color(0xFF0F172A),
                      enableSwipe: true,
                      swipeHorizontal: false,
                      autoSpacing: true,
                      pageFling: true,
                      pageSnap: true,
                      fitPolicy: FitPolicy.WIDTH,
                      preventLinkNavigation: false,
                      onRender: (pages) {
                        setState(() {
                          _totalPaginas = pages ?? 0;
                          _pdfListo = true;
                        });
                      },
                      onError: (error) {
                        setState(() {
                          _mensajeError = error.toString();
                        });
                      },
                      onPageError: (page, error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error en página $page: $error')),
                        );
                      },
                      onViewCreated: (PDFViewController pdfViewController) {
                        _pdfViewController = pdfViewController;
                      },
                      onPageChanged: (int? page, int? total) {
                        if (page != null) {
                          setState(() {
                            _paginaActual = page;
                          });
                        }
                      },
                    ),
                    if (!_pdfListo)
                      const Center(
                        child: CircularProgressIndicator(color: Color(0xFF52ABEB)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

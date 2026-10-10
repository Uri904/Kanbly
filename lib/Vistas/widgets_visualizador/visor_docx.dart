import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../utilerias/docx_parser.dart';

/// Visor interactivo para documentos Microsoft Word (.docx, .doc) que presenta
/// hojas físicas A4 vectoriales completas (595pt x 842pt) ajustadas a la pantalla
/// con soporte para gestos táctiles de zoom y navegación página por página.
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
  List<String> _paginasHtml = [];
  String? _pieDePaginaDocx;
  String? _encabezadoDocx;
  int _paginaActual = 0;
  bool _cargando = true;
  bool _usarVisorWebOffice = false;
  WebViewController? _webViewController;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _evaluarModoYCargar();
  }

  void _evaluarModoYCargar() {
    final url = widget.urlRemota.trim();
    final esUrlPublicaHttp = url.startsWith('http://') || url.startsWith('https://');

    if (esUrlPublicaHttp) {
      _usarVisorWebOffice = true;
      _inicializarWebView(url);
    } else {
      _usarVisorWebOffice = false;
      _cargarDocumentoWordLocal();
    }
  }

  void _inicializarWebView(String url) {
    final urlOficialOffice = 'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(url)}';
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..loadRequest(Uri.parse(urlOficialOffice));

    setState(() {
      _cargando = false;
    });
  }

  Future<void> _cargarDocumentoWordLocal() async {
    setState(() => _cargando = true);

    File? archivoAUsar = widget.archivoLocal;
    if (archivoAUsar == null || !archivoAUsar.existsSync()) {
      final url = widget.urlRemota.trim();
      if (url.isNotEmpty && !url.startsWith('http') && File(url).existsSync()) {
        archivoAUsar = File(url);
      }
    }

    final resultado = await DocxParser.procesarDocxCompleto(
      archivoLocal: archivoAUsar,
    );

    if (mounted) {
      setState(() {
        _paginasHtml = resultado.paginasHtml;
        _pieDePaginaDocx = resultado.pieDePaginaDocx;
        _encabezadoDocx = resultado.encabezadoDocx;
        _paginaActual = 0;
        _cargando = false;
      });
    }
  }

  Future<void> _abrirEnAppExterna() async {
    final path = widget.archivoLocal?.path ?? widget.urlRemota;
    if (path.isNotEmpty) {
      await OpenFilex.open(path);
    }
  }

  String _formatearTextoEspecial(String rawHtml, int paginaActual, int totalPaginas) {
    return rawHtml
        .replaceAll('{{PAGE}}', '$paginaActual')
        .replaceAll('{{NUMPAGES}}', '$totalPaginas');
  }

  void _reiniciarZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Container(
        height: 320,
        alignment: Alignment.center,
        color: const Color(0xFFF0F4F8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF2B579A)),
            const SizedBox(height: 16),
            Text(
              'Cargando documento Word...',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final totalPaginas = _paginasHtml.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8), // Fondo blanco con azul tenue de mesa de trabajo
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // BARRA SUPERIOR WORD AZUL CON BLANCO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF2B579A),
            child: Row(
              children: [
                const Icon(Icons.description_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.nombreArchivo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _usarVisorWebOffice
                            ? 'Microsoft Word Web Viewer'
                            : 'Vista Impresa A4 • Página ${_paginaActual + 1} de ${totalPaginas == 0 ? 1 : totalPaginas}',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (!_usarVisorWebOffice && totalPaginas > 0) ...[
                  IconButton(
                    icon: const Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 20),
                    tooltip: 'Restablecer escala',
                    onPressed: _reiniciarZoom,
                  ),
                  if (totalPaginas > 1) ...[
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _paginaActual > 0
                          ? () {
                              _reiniciarZoom();
                              setState(() => _paginaActual--);
                            }
                          : null,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _paginaActual < totalPaginas - 1
                          ? () {
                              _reiniciarZoom();
                              setState(() => _paginaActual++);
                            }
                          : null,
                    ),
                  ],
                ],
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                  tooltip: 'Abrir en Microsoft Word',
                  onPressed: _abrirEnAppExterna,
                ),
              ],
            ),
          ),

          // VISTA PRINCIPAL CON HOJA FÍSICA COMPLETA A4 AJUSTADA A PANTALLA
          Expanded(
            child: _usarVisorWebOffice && _webViewController != null
                ? WebViewWidget(controller: _webViewController!)
                : InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1.0,
                    maxScale: 3.5,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: _buildHojaA4Vectorial(
                            contenidoHtml: totalPaginas > 0 ? _paginasHtml[_paginaActual] : '<p>Sin contenido</p>',
                            numeroPagina: _paginaActual + 1,
                            totalPaginas: totalPaginas == 0 ? 1 : totalPaginas,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Construye el lienzo A4 físico vectorial con dimensiones explícitas fijas (595pt x 842pt)
  Widget _buildHojaA4Vectorial({
    required String contenidoHtml,
    required int numeroPagina,
    required int totalPaginas,
  }) {
    return Container(
      width: 595,
      height: 842, // Altura A4 canónica explícita para que FittedBox calcule la escala exacta
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 32, 36, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ENCABEZADO SUPERIOR WORD
            if (_encabezadoDocx != null && _encabezadoDocx!.trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.only(bottom: 6),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.0)),
                ),
                child: HtmlWidget(
                  _formatearTextoEspecial(_encabezadoDocx!, numeroPagina, totalPaginas),
                  textStyle: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: const Color(0xFF64748B),
                    height: 1.2,
                  ),
                ),
              ),
            ],

            // CONTENIDO PRINCIPAL A4 DE LA HOJA
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: HtmlWidget(
                  contenidoHtml,
                  textStyle: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF1E293B),
                    height: 1.35,
                  ),
                  customStylesBuilder: (element) {
                    if (element.localName == 'table') {
                      return {
                        'border-collapse': 'collapse',
                        'width': '100%',
                        'margin': '8px 0',
                        'border': '1px solid #cbd5e1',
                        'background-color': '#ffffff',
                      };
                    }
                    if (element.localName == 'th' || element.localName == 'td') {
                      return {
                        'padding': '6px 10px',
                        'border': '1px solid #cbd5e1',
                        'vertical-align': 'top',
                      };
                    }
                    return null;
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // PIE DE PÁGINA REAL WORD
            if (_pieDePaginaDocx != null && _pieDePaginaDocx!.trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.only(top: 6),
                margin: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFCBD5E1), width: 1.0)),
                ),
                child: HtmlWidget(
                  _formatearTextoEspecial(_pieDePaginaDocx!, numeroPagina, totalPaginas),
                  textStyle: GoogleFonts.inter(
                    fontSize: 9.0,
                    color: const Color(0xFF64748B),
                    height: 1.2,
                  ),
                ),
              ),
            ] else ...[
              const Divider(color: Color(0xFFE2E8F0), height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.nombreArchivo,
                    style: GoogleFonts.inter(fontSize: 8.5, color: const Color(0xFF94A3B8)),
                  ),
                  Text(
                    'Página $numeroPagina de $totalPaginas',
                    style: GoogleFonts.inter(fontSize: 8.5, color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

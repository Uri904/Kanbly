import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../utilerias/pptx_parser.dart';

/// Visor interactivo para presentaciones Microsoft PowerPoint (.pptx, .ppt)
/// con lienzo de diapositiva en proporción 16:9, carrusel de miniaturas y tema naranja de PowerPoint.
class VisorPptx extends StatefulWidget {
  final File? archivoLocal;
  final String urlRemota;
  final String nombreArchivo;

  const VisorPptx({
    super.key,
    this.archivoLocal,
    required this.urlRemota,
    required this.nombreArchivo,
  });

  @override
  State<VisorPptx> createState() => _VisorPptxState();
}

class _VisorPptxState extends State<VisorPptx> {
  bool _cargando = true;
  String? _mensajeError;
  bool _usarVisorWeb = false;
  WebViewController? _webViewController;

  List<DiapositivaPptx> _diapositivas = [];
  int _indexDiapositiva = 0;

  @override
  void initState() {
    super.initState();
    _evaluarYCargar();
  }

  void _evaluarYCargar() {
    final url = widget.urlRemota.trim();
    final esUrlPublica = url.startsWith('http://') || url.startsWith('https://');

    if (esUrlPublica) {
      _usarVisorWeb = true;
      final urlOficialOffice = 'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(url)}';
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFC43E1C))
        ..loadRequest(Uri.parse(urlOficialOffice));
      setState(() => _cargando = false);
    } else {
      _usarVisorWeb = false;
      _cargarPptxLocal();
    }
  }

  Future<void> _cargarPptxLocal() async {
    setState(() {
      _cargando = true;
      _mensajeError = null;
    });

    try {
      File? f = widget.archivoLocal;
      if (f == null || !f.existsSync()) {
        final url = widget.urlRemota.trim();
        if (url.isNotEmpty && !url.startsWith('http') && File(url).existsSync()) {
          f = File(url);
        }
      }

      final res = await PptxParser.procesarPptxCompleto(archivoLocal: f);

      if (res.diapositivas.isEmpty) {
        throw Exception('No se pudieron extraer diapositivas de la presentación.');
      }

      if (mounted) {
        setState(() {
          _diapositivas = res.diapositivas;
          _indexDiapositiva = 0;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensajeError = 'Error al leer presentación PowerPoint: $e';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _abrirEnAppExterna() async {
    final path = widget.archivoLocal?.path ?? widget.urlRemota;
    if (path.isNotEmpty) {
      await OpenFilex.open(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        color: const Color(0xFFFFF3ED),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFC43E1C)),
            const SizedBox(height: 16),
            Text(
              'Cargando presentación PowerPoint...',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8C2C14), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_mensajeError != null || (!_usarVisorWeb && _diapositivas.isEmpty)) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          children: [
            const Icon(Icons.slideshow_rounded, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              'No se pudo abrir la presentación PowerPoint',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red.shade900),
            ),
            const SizedBox(height: 6),
            Text(
              _mensajeError ?? 'Archivo sin diapositivas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ],
        ),
      );
    }

    final totalSlides = _diapositivas.length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3ED), // Fondo naranja tenue de mesa de trabajo
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCCBC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade900.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // BARRA SUPERIOR NARANJA POWERPOINT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFC43E1C),
            child: Row(
              children: [
                const Icon(Icons.slideshow_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.nombreArchivo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      if (!_usarVisorWeb)
                        Text(
                          'Diapositiva ${_indexDiapositiva + 1} de $totalSlides',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                    ],
                  ),
                ),
                if (!_usarVisorWeb && totalSlides > 1) ...[
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
                    onPressed: _indexDiapositiva > 0 ? () => setState(() => _indexDiapositiva--) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                    onPressed: _indexDiapositiva < totalSlides - 1 ? () => setState(() => _indexDiapositiva++) : null,
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                  tooltip: 'Abrir en Microsoft PowerPoint',
                  onPressed: _abrirEnAppExterna,
                ),
              ],
            ),
          ),

          // VISTA PRINCIPAL (WEBVIEW O LIENZO DE DIAPOSITIVA 16:9)
          Expanded(
            child: _usarVisorWeb && _webViewController != null
                ? WebViewWidget(controller: _webViewController!)
                : Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFFCCBC)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.shade900.withValues(alpha: 0.15),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _diapositivas[_indexDiapositiva].titulo,
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFC43E1C),
                                      ),
                                    ),
                                    const Divider(color: Color(0xFFFFCCBC), height: 20),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: _diapositivas[_indexDiapositiva].parrafos.map((p) {
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 8.0),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('• ', style: TextStyle(color: Color(0xFFC43E1C), fontWeight: FontWeight.bold)),
                                                  Expanded(
                                                    child: Text(
                                                      p,
                                                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // CARRUSEL DE MINIATURAS INFERIOR EN NARANJA Y BLANCO
                      if (totalSlides > 1)
                        Container(
                          height: 60,
                          color: const Color(0xFFFFE0B2),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: totalSlides,
                            itemBuilder: (ctx, idx) {
                              final sel = idx == _indexDiapositiva;
                              return GestureDetector(
                                onTap: () => setState(() => _indexDiapositiva = idx),
                                child: Container(
                                  width: 80,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: sel ? const Color(0xFFC43E1C) : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFC43E1C),
                                      width: sel ? 2 : 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${idx + 1}',
                                    style: TextStyle(
                                      color: sel ? Colors.white : const Color(0xFFC43E1C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

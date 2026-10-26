import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../modelo/tarea.dart';
import '../servicios/cache_adjuntos_service.dart';
import 'widgets_visualizador/visor_pdf.dart';
import 'widgets_visualizador/visor_video.dart';
import 'widgets_visualizador/visor_docx.dart';
import 'widgets_visualizador/visor_excel.dart';
import 'widgets_visualizador/visor_pptx.dart';
import 'widgets_visualizador/visor_imagen.dart';

/// Pantalla completa para visualizar el contenido de archivos adjuntos (Word, PDF, Videos, Imágenes, Excel, PowerPoint, etc.)
/// conservando todo el formato original y permitiendo abrirlos o editarlos con aplicaciones externas.
/// Soporta almacenamiento en caché local para consumo y apertura 100% offline.
class PantallaVisualizadorAdjunto extends StatefulWidget {
  final AdjuntoTarea adjunto;

  const PantallaVisualizadorAdjunto({
    super.key,
    required this.adjunto,
  });

  /// Método estático auxiliar para navegar a esta pantalla
  static void abrir(BuildContext context, AdjuntoTarea adjunto) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaVisualizadorAdjunto(adjunto: adjunto),
      ),
    );
  }

  @override
  State<PantallaVisualizadorAdjunto> createState() => _PantallaVisualizadorAdjuntoState();
}

class _PantallaVisualizadorAdjuntoState extends State<PantallaVisualizadorAdjunto> {
  File? _archivoLocal;
  bool _estaEnCache = false;
  bool _descargandoCache = false;

  @override
  void initState() {
    super.initState();
    _inicializarCacheLocal();
  }

  Future<void> _inicializarCacheLocal() async {
    // 1. Verificar si ya existe en almacenamiento local o caché
    final localExistente = await CacheAdjuntosService.obtenerArchivoLocalSiExiste(
      widget.adjunto.url,
      widget.adjunto.nombre,
    );

    if (localExistente != null && mounted) {
      setState(() {
        _archivoLocal = localExistente;
        _estaEnCache = true;
      });
      return;
    }

    // 2. Si es una URL remota y no está en caché, intentar descargarla para acceso offline futuro
    if (widget.adjunto.url.startsWith('http://') || widget.adjunto.url.startsWith('https://')) {
      setState(() => _descargandoCache = true);
      final cacheGuardado = await CacheAdjuntosService.descargarYGuardarEnCache(
        widget.adjunto.url,
        widget.adjunto.nombre,
      );

      if (cacheGuardado != null && mounted) {
        setState(() {
          _archivoLocal = cacheGuardado;
          _estaEnCache = true;
          _descargandoCache = false;
        });
      } else if (mounted) {
        setState(() => _descargandoCache = false);
      }
    }
  }

  bool _esImagen() {
    final tipo = widget.adjunto.tipo.toLowerCase();
    final nombre = widget.adjunto.nombre.toLowerCase();
    final url = widget.adjunto.url.toLowerCase();
    return tipo == 'imagen' ||
        ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp', '.svg'].any((ext) => nombre.endsWith(ext) || url.endsWith(ext));
  }

  bool _esVideo() {
    final tipo = widget.adjunto.tipo.toLowerCase();
    final nombre = widget.adjunto.nombre.toLowerCase();
    final url = widget.adjunto.url.toLowerCase();
    return tipo == 'video' ||
        ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.flv', '.3gp'].any((ext) => nombre.endsWith(ext) || url.endsWith(ext));
  }

  bool _esPdf() {
    final nombre = widget.adjunto.nombre.toLowerCase();
    final url = widget.adjunto.url.toLowerCase();
    return nombre.endsWith('.pdf') || url.endsWith('.pdf');
  }

  bool _esDocx() {
    final nombre = widget.adjunto.nombre.toLowerCase();
    final url = widget.adjunto.url.toLowerCase();
    return nombre.endsWith('.docx') || url.endsWith('.docx') || nombre.endsWith('.doc') || url.endsWith('.doc');
  }

  bool _esExcel() {
    final nombre = widget.adjunto.nombre.toLowerCase();
    final url = widget.adjunto.url.toLowerCase();
    return nombre.endsWith('.xlsx') || url.endsWith('.xlsx') || nombre.endsWith('.xls') || url.endsWith('.xls') || nombre.endsWith('.csv');
  }

  bool _esPptx() {
    final nombre = widget.adjunto.nombre.toLowerCase();
    final url = widget.adjunto.url.toLowerCase();
    return nombre.endsWith('.pptx') || url.endsWith('.pptx') || nombre.endsWith('.ppt') || url.endsWith('.ppt');
  }

  bool _esTexto() {
    final nombre = widget.adjunto.nombre.toLowerCase();
    final url = widget.adjunto.url.toLowerCase();
    return ['.txt', '.json', '.md', '.log', '.xml', '.html', '.dart', '.yaml', '.yml', '.js', '.css']
        .any((ext) => nombre.endsWith(ext) || url.endsWith(ext));
  }

  Future<void> _abrirConAppExterna(BuildContext context) async {
    final url = widget.adjunto.url;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La ruta del archivo no está disponible.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      String pathParaAbrir = _archivoLocal?.path ?? url;

      if ((_archivoLocal == null || !_archivoLocal!.existsSync()) &&
          (url.startsWith('http://') || url.startsWith('https://'))) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Descargando archivo para abrir externamente...'),
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFF52ABEB),
            ),
          );
        }

        final fileCache = await CacheAdjuntosService.descargarYGuardarEnCache(url, widget.adjunto.nombre);
        if (fileCache != null) {
          pathParaAbrir = fileCache.path;
          if (mounted) {
            setState(() {
              _archivoLocal = fileCache;
              _estaEnCache = true;
            });
          }
        } else {
          final tempDir = await getTemporaryDirectory();
          final fileNameClean = widget.adjunto.nombre.replaceAll(RegExp(r'[^\w.-]'), '_');
          final localFile = File('${tempDir.path}/ext_$fileNameClean');

          if (!localFile.existsSync()) {
            final client = HttpClient();
            final request = await client.getUrl(Uri.parse(url));
            request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
            final response = await request.close();
            if (response.statusCode == 200) {
              await response.pipe(localFile.openWrite());
            } else {
              throw Exception('Error servidor: ${response.statusCode}');
            }
          }
          pathParaAbrir = localFile.path;
        }
      }

      final result = await OpenFilex.open(pathParaAbrir);
      if (context.mounted) {
        if (result.type == ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Abriendo archivo con la aplicación seleccionada...'),
              backgroundColor: Color(0xFF52ABEB),
            ),
          );
        } else if (result.type == ResultType.noAppToOpen) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se encontró una aplicación compatible instalada para abrir ${widget.adjunto.nombre}. Instala un visor apropiado.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (result.type == ResultType.fileNotFound) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El archivo local no se encuentra en el dispositivo.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Resultado: ${result.message}'),
              backgroundColor: Colors.grey.shade800,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir archivo con otra aplicación: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  IconData _obtenerIconoGeneral(String tipo) {
    if (_esDocx()) return Icons.description_rounded;
    if (_esPdf()) return Icons.picture_as_pdf_rounded;
    if (_esExcel()) return Icons.table_chart_rounded;
    if (_esPptx()) return Icons.slideshow_rounded;
    if (_esVideo()) return Icons.videocam_rounded;
    if (_esImagen()) return Icons.image_rounded;
    return Icons.article_rounded;
  }

  Color _obtenerColorTemaPrincipal() {
    if (_esDocx()) return const Color(0xFF2B579A); // Word Azul
    if (_esExcel()) return const Color(0xFF107C41); // Excel Verde
    if (_esPptx()) return const Color(0xFFC43E1C); // PowerPoint Naranja
    if (_esPdf()) return const Color(0xFFD32F2F); // PDF Rojo
    return const Color(0xFF52ABEB); // Azul Estándar
  }

  Color _obtenerColorFondoMesaTrabajo() {
    if (_esDocx()) return const Color(0xFFF0F4F8); // Word Blanco/Azul
    if (_esExcel()) return const Color(0xFFE8F5E9); // Excel Verde/Blanco
    if (_esPptx()) return const Color(0xFFFFF3ED); // PowerPoint Naranja/Blanco
    if (_esPdf()) return const Color(0xFFFFF5F5); // PDF Rojo/Blanco
    if (_esImagen() || _esVideo() || _esTexto()) return const Color(0xFF0F172A);
    return const Color(0xFFF8FAFC);
  }

  @override
  Widget build(BuildContext context) {
    final colorTema = _obtenerColorTemaPrincipal();
    final colorFondo = _obtenerColorFondoMesaTrabajo();
    final esMediaOscura = _esImagen() || _esVideo() || _esTexto();

    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: esMediaOscura ? const Color(0xFF1E293B) : colorTema,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.adjunto.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '${widget.adjunto.tipo.toUpperCase()} • ${widget.adjunto.tamanoLegible}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ),
                if (_estaEnCache) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.offline_pin_rounded, size: 10, color: Colors.white),
                        SizedBox(width: 3),
                        Text('Offline / Caché', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ] else if (_descargandoCache) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text(
                'Abrir con otra app',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _abrirConAppExterna(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildCuerpoVisualizador(context, _archivoLocal),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: esMediaOscura ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorTema,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.edit_document, size: 20),
                label: const Text(
                  'Abrir / Editar con aplicación externa',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _abrirConAppExterna(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCuerpoVisualizador(BuildContext context, File? archivoLocal) {
    // 1. VISUALIZACIÓN DE DOCUMENTOS WORD (.DOCX)
    if (_esDocx()) {
      return VisorDocx(
        archivoLocal: archivoLocal,
        urlRemota: widget.adjunto.url,
        nombreArchivo: widget.adjunto.nombre,
      );
    }

    // 2. VISUALIZACIÓN DE DOCUMENTOS PDF
    if (_esPdf()) {
      return VisorPdf(
        archivoLocal: archivoLocal,
        urlRemota: widget.adjunto.url,
        nombreArchivo: widget.adjunto.nombre,
      );
    }

    // 3. VISUALIZACIÓN DE PRESENTACIONES POWERPOINT (.PPTX)
    if (_esPptx()) {
      return VisorPptx(
        archivoLocal: archivoLocal,
        urlRemota: widget.adjunto.url,
        nombreArchivo: widget.adjunto.nombre,
      );
    }

    // 4. VISUALIZACIÓN DE VIDEOS
    if (_esVideo()) {
      return VisorVideo(
        archivoLocal: archivoLocal,
        urlRemota: widget.adjunto.url,
        nombreArchivo: widget.adjunto.nombre,
      );
    }

    // 5. VISUALIZACIÓN DE HOJAS DE CÁLCULO EXCEL Y CSV
    if (_esExcel()) {
      return VisorExcel(
        archivoLocal: archivoLocal,
        urlRemota: widget.adjunto.url,
        nombreArchivo: widget.adjunto.nombre,
      );
    }

    // 6. VISUALIZACIÓN DE IMÁGENES
    if (_esImagen()) {
      return VisorImagen(
        archivoLocal: archivoLocal,
        urlRemota: widget.adjunto.url,
        nombreArchivo: widget.adjunto.nombre,
      );
    }

    // 7. VISUALIZACIÓN DE ARCHIVOS DE TEXTO Y CÓDIGO
    if (_esTexto() && archivoLocal != null) {
      try {
        String texto = archivoLocal.readAsStringSync();
        if (texto.length > 50000) {
          texto = '${texto.substring(0, 50000)}\n\n[... Contenido truncado por longitud ...]';
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              texto,
              style: GoogleFonts.firaCode(
                fontSize: 13,
                color: const Color(0xFFE2E8F0),
                height: 1.5,
              ),
            ),
          ),
        );
      } catch (_) {}
    }

    // 8. TARJETA INFORMATIVA PARA OTROS TIPOS DE ARCHIVO
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF52ABEB).withValues(alpha: 0.12),
            child: Icon(
              _obtenerIconoGeneral(widget.adjunto.tipo),
              color: const Color(0xFF52ABEB),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.adjunto.nombre,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tipo: ${widget.adjunto.tipo.toUpperCase()} • Tamaño: ${widget.adjunto.tamanoLegible}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          if (archivoLocal != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ruta del archivo en el dispositivo (Caché local):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    archivoLocal.path,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF52ABEB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Abrir con aplicación instalada', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _abrirConAppExterna(context),
          ),
        ],
      ),
    );
  }
}

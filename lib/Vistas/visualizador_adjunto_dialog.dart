import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../modelo/tarea.dart';
import 'pantalla_visualizador_adjunto.dart';
import 'widgets_visualizador/visor_pdf.dart';
import 'widgets_visualizador/visor_video.dart';
import 'widgets_visualizador/visor_docx.dart';
import 'widgets_visualizador/visor_excel.dart';
import 'widgets_visualizador/visor_pptx.dart';
import 'widgets_visualizador/visor_imagen.dart';

/// Diálogo modal para visualizar el contenido de los archivos adjuntos en tareas
/// con vista previa enriquecida (Word, PDF, Video, Imagen, Excel, PowerPoint) y opción de pantalla completa.
class VisualizadorAdjuntoDialog extends StatelessWidget {
  final AdjuntoTarea adjunto;

  const VisualizadorAdjuntoDialog({
    super.key,
    required this.adjunto,
  });

  /// Método estático auxiliar para abrir el visualizador
  static void mostrar(BuildContext context, AdjuntoTarea adjunto) {
    showDialog(
      context: context,
      builder: (context) => VisualizadorAdjuntoDialog(adjunto: adjunto),
    );
  }

  bool _esImagen() {
    final tipo = adjunto.tipo.toLowerCase();
    final nombre = adjunto.nombre.toLowerCase();
    final url = adjunto.url.toLowerCase();
    return tipo == 'imagen' ||
        ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp', '.svg'].any((ext) => nombre.endsWith(ext) || url.endsWith(ext));
  }

  bool _esVideo() {
    final tipo = adjunto.tipo.toLowerCase();
    final nombre = adjunto.nombre.toLowerCase();
    final url = adjunto.url.toLowerCase();
    return tipo == 'video' ||
        ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.flv', '.3gp'].any((ext) => nombre.endsWith(ext) || url.endsWith(ext));
  }

  bool _esPdf() {
    final nombre = adjunto.nombre.toLowerCase();
    final url = adjunto.url.toLowerCase();
    return nombre.endsWith('.pdf') || url.endsWith('.pdf');
  }

  bool _esDocx() {
    final nombre = adjunto.nombre.toLowerCase();
    final url = adjunto.url.toLowerCase();
    return nombre.endsWith('.docx') || url.endsWith('.docx') || nombre.endsWith('.doc') || url.endsWith('.doc');
  }

  bool _esExcel() {
    final nombre = adjunto.nombre.toLowerCase();
    final url = adjunto.url.toLowerCase();
    return nombre.endsWith('.xlsx') || url.endsWith('.xlsx') || nombre.endsWith('.xls') || url.endsWith('.xls') || nombre.endsWith('.csv');
  }

  bool _esPptx() {
    final nombre = adjunto.nombre.toLowerCase();
    final url = adjunto.url.toLowerCase();
    return nombre.endsWith('.pptx') || url.endsWith('.pptx') || nombre.endsWith('.ppt') || url.endsWith('.ppt');
  }

  bool _esTexto() {
    final nombre = adjunto.nombre.toLowerCase();
    final url = adjunto.url.toLowerCase();
    return ['.txt', '.json', '.md', '.log', '.xml', '.html', '.dart', '.yaml', '.yml', '.js', '.css']
        .any((ext) => nombre.endsWith(ext) || url.endsWith(ext));
  }

  Widget _buildContenidoViewer(BuildContext context) {
    final url = adjunto.url;
    File? archivoLocal;
    try {
      if (url.isNotEmpty && !url.startsWith('http')) {
        final f = File(url);
        if (f.existsSync()) archivoLocal = f;
      }
    } catch (_) {}

    // 1. WORD (.DOCX) CON FORMATO COMPLETO
    if (_esDocx()) {
      return SizedBox(
        height: 380,
        child: VisorDocx(
          archivoLocal: archivoLocal,
          urlRemota: adjunto.url,
          nombreArchivo: adjunto.nombre,
        ),
      );
    }

    // 2. PDF CON PAGINACIÓN Y ZOOM
    if (_esPdf()) {
      return SizedBox(
        height: 380,
        child: VisorPdf(
          archivoLocal: archivoLocal,
          urlRemota: adjunto.url,
          nombreArchivo: adjunto.nombre,
        ),
      );
    }

    // 3. POWERPOINT (.PPTX)
    if (_esPptx()) {
      return SizedBox(
        height: 350,
        child: VisorPptx(
          archivoLocal: archivoLocal,
          urlRemota: adjunto.url,
          nombreArchivo: adjunto.nombre,
        ),
      );
    }

    // 4. VIDEO REPRODUCTOR INTERACTIVO
    if (_esVideo()) {
      return SizedBox(
        height: 320,
        child: VisorVideo(
          archivoLocal: archivoLocal,
          urlRemota: adjunto.url,
          nombreArchivo: adjunto.nombre,
        ),
      );
    }

    // 5. EXCEL / HOJAS DE CÁLCULO
    if (_esExcel()) {
      return SizedBox(
        height: 350,
        child: VisorExcel(
          archivoLocal: archivoLocal,
          urlRemota: adjunto.url,
          nombreArchivo: adjunto.nombre,
        ),
      );
    }

    // 6. IMÁGENES
    if (_esImagen()) {
      return SizedBox(
        height: 320,
        child: VisorImagen(
          archivoLocal: archivoLocal,
          urlRemota: adjunto.url,
          nombreArchivo: adjunto.nombre,
        ),
      );
    }

    // 7. ARCHIVOS DE TEXTO Y CÓDIGO
    if (_esTexto() && archivoLocal != null) {
      try {
        String texto = archivoLocal.readAsStringSync();
        if (texto.length > 30000) {
          texto = '${texto.substring(0, 30000)}\n\n[... Contenido truncado ...]';
        }
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              texto,
              style: GoogleFonts.firaCode(fontSize: 12, color: const Color(0xFFE2E8F0)),
            ),
          ),
        );
      } catch (_) {}
    }

    // 8. TARJETA DE INFORMACIÓN GENERAL
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_obtenerIconoGeneral(adjunto.tipo), color: const Color(0xFF52ABEB), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adjunto.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Tipo: ${adjunto.tipo.toUpperCase()} • ${adjunto.tamanoLegible}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (archivoLocal != null) ...[
            const SizedBox(height: 10),
            Text('Ruta local:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            SelectableText(archivoLocal.path, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
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

  Color _obtenerColorTema() {
    if (_esDocx()) return const Color(0xFF2B579A); // Word Azul
    if (_esExcel()) return const Color(0xFF107C41); // Excel Verde
    if (_esPptx()) return const Color(0xFFC43E1C); // PowerPoint Naranja
    if (_esPdf()) return const Color(0xFFD32F2F); // PDF Rojo
    return const Color(0xFF52ABEB); // Default Azul
  }

  @override
  Widget build(BuildContext context) {
    final colorTema = _obtenerColorTema();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      title: Row(
        children: [
          Icon(_obtenerIconoGeneral(adjunto.tipo), color: colorTema),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              adjunto.nombre,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${adjunto.tipo.toUpperCase()} • ${adjunto.tamanoLegible}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildContenidoViewer(context),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: Icon(Icons.fullscreen_rounded, size: 18, color: colorTema),
          label: Text('Pantalla completa', style: TextStyle(color: colorTema, fontWeight: FontWeight.bold)),
          onPressed: () {
            Navigator.pop(context);
            PantallaVisualizadorAdjunto.abrir(context, adjunto);
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

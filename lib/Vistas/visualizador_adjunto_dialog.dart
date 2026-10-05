import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../modelo/tarea.dart';

/// Diálogo modal para visualizar el contenido de los archivos adjuntos en tareas
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
        ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'].any((ext) => nombre.endsWith(ext) || url.endsWith(ext));
  }

  bool _esTexto() {
    final nombre = adjunto.nombre.toLowerCase();
    final url = adjunto.url.toLowerCase();
    return ['.txt', '.json', '.csv', '.md', '.log', '.xml', '.html', '.dart', '.yaml', '.yml', '.js', '.css']
        .any((ext) => nombre.endsWith(ext) || url.endsWith(ext));
  }

  bool _esDocx() {
    final nombre = adjunto.nombre.toLowerCase();
    final url = adjunto.url.toLowerCase();
    return nombre.endsWith('.docx') || url.endsWith('.docx');
  }

  String _extraerTextoDocx(File archivoLocal) {
    try {
      final bytes = archivoLocal.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.findFile('word/document.xml');
      if (docFile == null) {
        return 'No se pudo encontrar la estructura "word/document.xml" en el archivo .docx.';
      }

      final contentBytes = docFile.content as List<int>;
      final xmlString = utf8.decode(contentBytes, allowMalformed: true);

      // Reemplazar párrafos por saltos de línea doble
      final xmlConSaltos = xmlString.replaceAll(RegExp(r'</w:p>'), '\n\n');

      // Eliminar todas las etiquetas XML
      String textoLimpio = xmlConSaltos.replaceAll(RegExp(r'<[^>]*>'), '');

      // Decodificar entidades XML comunes
      textoLimpio = textoLimpio
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&apos;', "'");

      textoLimpio = textoLimpio.trim();
      if (textoLimpio.isEmpty) {
        return 'El documento .docx está vacío o no contiene texto.';
      }

      return textoLimpio;
    } catch (e) {
      return 'Error al leer el contenido del documento .docx: $e';
    }
  }

  Widget _buildContenidoViewer(BuildContext context) {
    final url = adjunto.url;
    File? archivoLocal;
    try {
      if (url.isNotEmpty && !url.startsWith('http')) {
        final f = File(url);
        if (f.existsSync()) {
          archivoLocal = f;
        }
      }
    } catch (_) {}

    // 1. VISUALIZACIÓN DE IMÁGENES
    if (_esImagen()) {
      if (archivoLocal != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 350),
            child: InteractiveViewer(
              maxScale: 4.0,
              child: Image.file(
                archivoLocal,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _buildErrorCard('No se pudo cargar la imagen local.'),
              ),
            ),
          ),
        );
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 350),
            child: InteractiveViewer(
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) => _buildErrorCard('Error al descargar la imagen remota.'),
              ),
            ),
          ),
        );
      }
    }

    // 2. VISUALIZACIÓN DE ARCHIVOS WORD (.DOCX)
    if (_esDocx() && archivoLocal != null) {
      final textoDocx = _extraerTextoDocx(archivoLocal);
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 380),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF52ABEB).withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_rounded, color: Color(0xFF52ABEB), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Contenido del Documento Word (.docx):',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  textoDocx,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF334155),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 3. VISUALIZACIÓN DE ARCHIVOS DE TEXTO / CÓDIGO (.TXT, .JSON, .CSV, ETC.)
    if (_esTexto() && archivoLocal != null) {
      try {
        String texto = archivoLocal.readAsStringSync();
        if (texto.length > 30000) {
          texto = '${texto.substring(0, 30000)}\n\n[... Contenido truncado por longitud ...]';
        }
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 320),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              texto,
              style: GoogleFonts.firaCode(
                fontSize: 12,
                color: const Color(0xFFE2E8F0),
              ),
            ),
          ),
        );
      } catch (e) {
        // Fallback si falla la lectura
      }
    }

    // 4. TARJETA DE INFORMACIÓN DETALLADA PARA OTROS ARCHIVOS (PDF, DOC, VIDEO, ETC.)
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
              Icon(
                _obtenerIconoGeneral(adjunto.tipo),
                color: const Color(0xFF52ABEB),
                size: 28,
              ),
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
          const SizedBox(height: 12),
          if (archivoLocal != null) ...[
            Text(
              'Ruta local del archivo:',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 2),
            SelectableText(
              archivoLocal.path,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF52ABEB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF52ABEB)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Archivo adjuntado guardado de forma segura en la tarea.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(child: Text(mensaje, style: const TextStyle(fontSize: 12, color: Colors.redAccent))),
        ],
      ),
    );
  }

  IconData _obtenerIconoGeneral(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'imagen':
        return Icons.image_rounded;
      case 'video':
        return Icons.videocam_rounded;
      case 'documento':
      default:
        return Icons.description_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      title: Row(
        children: [
          Icon(_obtenerIconoGeneral(adjunto.tipo), color: const Color(0xFF52ABEB)),
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
      content: SingleChildScrollView(
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

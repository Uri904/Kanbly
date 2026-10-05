import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import '../modelo/tarea.dart';

/// Pantalla completa para visualizar el contenido de archivos adjuntos (Word, Imágenes, Texto, etc.)
/// y permitir abrirlos o editarlos con aplicaciones externas como Microsoft Word o Lectores de PDF.
class PantallaVisualizadorAdjunto extends StatelessWidget {
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
    return nombre.endsWith('.docx') || url.endsWith('.docx') || nombre.endsWith('.doc') || url.endsWith('.doc');
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
        return 'El documento está vacío o no contiene texto editable.';
      }

      return textoLimpio;
    } catch (e) {
      return 'Error al extraer el contenido del archivo Word: $e';
    }
  }

  Future<void> _abrirConAppExterna(BuildContext context) async {
    final url = adjunto.url;
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
      final result = await OpenFilex.open(url);
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
              content: Text('No se encontró una aplicación compatible instalada para abrir ${adjunto.nombre}. Instala Microsoft Word o un visor apropiado.'),
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
    switch (tipo.toLowerCase()) {
      case 'imagen':
        return Icons.image_rounded;
      case 'video':
        return Icons.videocam_rounded;
      case 'documento':
      default:
        return Icons.article_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color azulCielo = Color(0xFF52ABEB);
    const Color verdeTurquesa = Color(0xFF63D0A1);
    final esFondoOscuro = _esImagen() || _esTexto();

    File? archivoLocal;
    try {
      if (adjunto.url.isNotEmpty && !adjunto.url.startsWith('http')) {
        final f = File(adjunto.url);
        if (f.existsSync()) archivoLocal = f;
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: esFondoOscuro ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: esFondoOscuro ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: esFondoOscuro ? Colors.white : const Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              adjunto.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: esFondoOscuro ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            Text(
              '${adjunto.tipo.toUpperCase()} • ${adjunto.tamanoLegible}',
              style: TextStyle(
                fontSize: 11,
                color: esFondoOscuro ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: azulCielo,
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
          child: _buildCuerpoVisualizador(context, archivoLocal),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: esFondoOscuro ? const Color(0xFF1E293B) : Colors.white,
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
                  backgroundColor: verdeTurquesa,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.edit_document, size: 20),
                label: const Text(
                  'Abrir / Editar en Word o app externa',
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
    if (_esDocx() && archivoLocal != null) {
      final textoDocx = _extraerTextoDocx(archivoLocal);
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ENCABEZADO FORMATO HOJA WORD
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF2B579A), // Color azul clásico de Microsoft Word
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                          adjunto.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'Documento Microsoft Word • Vista de Lectura',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // CUERPO HOJA DIGITAL
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: SelectableText(
                    textoDocx,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF1E293B),
                      height: 1.6,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 2. VISUALIZACIÓN DE IMÁGENES
    if (_esImagen()) {
      if (archivoLocal != null) {
        return Center(
          child: InteractiveViewer(
            maxScale: 4.0,
            child: Image.file(
              archivoLocal,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildErrorCard('No se pudo cargar la imagen local.'),
            ),
          ),
        );
      } else if (adjunto.url.startsWith('http://') || adjunto.url.startsWith('https://')) {
        return Center(
          child: InteractiveViewer(
            maxScale: 4.0,
            child: Image.network(
              adjunto.url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              },
              errorBuilder: (context, error, stackTrace) => _buildErrorCard('Error al descargar la imagen remota.'),
            ),
          ),
        );
      }
    }

    // 3. VISUALIZACIÓN DE ARCHIVOS DE TEXTO Y CÓDIGO
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
      } catch (e) {
        // Fallback
      }
    }

    // 4. TARJETA DE INFORMACIÓN DETALLADA PARA OTROS ARCHIVOS (PDF, DOC, VIDEO, ETC.)
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
              _obtenerIconoGeneral(adjunto.tipo),
              color: const Color(0xFF52ABEB),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            adjunto.nombre,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tipo: ${adjunto.tipo.toUpperCase()} • Tamaño: ${adjunto.tamanoLegible}',
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
                    'Ruta del archivo en el dispositivo:',
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
            label: const Text('Abrir con aplicación instalada (Word / PDF Reader)', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _abrirConAppExterna(context),
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
}

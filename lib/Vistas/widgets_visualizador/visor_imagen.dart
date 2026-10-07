import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visor de imágenes interactivo enriquecido con gestos táctiles, zoom (hasta 5x),
/// doble toque para zoom rápido, rotación de 90° y visualización de calidad.
class VisorImagen extends StatefulWidget {
  final File? archivoLocal;
  final String urlRemota;
  final String nombreArchivo;

  const VisorImagen({
    super.key,
    this.archivoLocal,
    required this.urlRemota,
    required this.nombreArchivo,
  });

  @override
  State<VisorImagen> createState() => _VisorImagenState();
}

class _VisorImagenState extends State<VisorImagen> {
  final TransformationController _transformationController = TransformationController();
  int _rotacionCuadrantes = 0; // 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°

  void _zoomIn() {
    final Matrix4 matrix = _transformationController.value.clone();
    matrix.scale(1.3, 1.3);
    _transformationController.value = matrix;
  }

  void _zoomOut() {
    final Matrix4 matrix = _transformationController.value.clone();
    matrix.scale(0.75, 0.75);
    _transformationController.value = matrix;
  }

  void _rotar() {
    setState(() {
      _rotacionCuadrantes = (_rotacionCuadrantes + 1) % 4;
    });
  }

  void _resetTransform() {
    setState(() {
      _rotacionCuadrantes = 0;
      _transformationController.value = Matrix4.identity();
    });
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _resetTransform();
    } else {
      final Matrix4 matrix = Matrix4.identity()..scale(2.5, 2.5);
      _transformationController.value = matrix;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    File? f = widget.archivoLocal;
    if (f == null || !f.existsSync()) {
      final url = widget.urlRemota.trim();
      if (url.isNotEmpty && !url.startsWith('http') && File(url).existsSync()) {
        f = File(url);
      }
    }

    Widget imagenWidget;
    if (f != null && f.existsSync()) {
      imagenWidget = Image.file(
        f,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildErrorCard('Error al cargar la imagen local.'),
      );
    } else if (widget.urlRemota.startsWith('http://') || widget.urlRemota.startsWith('https://')) {
      imagenWidget = Image.network(
        widget.urlRemota,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          final total = loadingProgress.expectedTotalBytes;
          final loaded = loadingProgress.cumulativeBytesLoaded;
          final progreso = total != null && total > 0 ? loaded / total : null;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(value: progreso, color: const Color(0xFF52ABEB)),
                const SizedBox(height: 12),
                Text(
                  progreso != null ? '${(progreso * 100).toInt()}%' : 'Descargando imagen...',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildErrorCard('Error al cargar la imagen desde la red.'),
      );
    } else {
      imagenWidget = _buildErrorCard('No se encuentra la imagen especificada.');
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // ÁREA INTERACTIVA ZOOM Y ROTACIÓN
          Center(
            child: GestureDetector(
              onDoubleTap: _handleDoubleTap,
              child: RotatedBox(
                quarterTurns: _rotacionCuadrantes,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.8,
                  maxScale: 5.0,
                  clipBehavior: Clip.none,
                  child: imagenWidget,
                ),
              ),
            ),
          ),

          // BARRA FLOTANTE DE ACCIONES Y CONTROLES (ZOOM, ROTAR, RESET)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                    tooltip: 'Aumentar Zoom',
                    onPressed: _zoomIn,
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out_rounded, color: Colors.white, size: 20),
                    tooltip: 'Reducir Zoom',
                    onPressed: _zoomOut,
                  ),
                  IconButton(
                    icon: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 20),
                    tooltip: 'Rotar 90°',
                    onPressed: _rotar,
                  ),
                  IconButton(
                    icon: const Icon(Icons.restart_alt_rounded, color: Colors.white, size: 20),
                    tooltip: 'Restablecer',
                    onPressed: _resetTransform,
                  ),
                ],
              ),
            ),
          ),

          // ETIQUETA INFORMATIVA DE INDICACIONES
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.touch_app_rounded, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Pellizca o toca 2 veces para zoom',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String mensaje) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                mensaje,
                style: const TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

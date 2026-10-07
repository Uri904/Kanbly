import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visor y reproductor de video nativo e interactivo (.mp4, .mov, .avi, .mkv, etc.)
/// con controles completos de reproducción, línea de tiempo (seek), tiempo transcurrido,
/// duración total, sonido y pantalla completa.
class VisorVideo extends StatefulWidget {
  final File? archivoLocal;
  final String urlRemota;
  final String nombreArchivo;

  const VisorVideo({
    super.key,
    this.archivoLocal,
    required this.urlRemota,
    required this.nombreArchivo,
  });

  @override
  State<VisorVideo> createState() => _VisorVideoState();
}

class _VisorVideoState extends State<VisorVideo> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _inicializando = true;
  String? _mensajeError;

  @override
  void initState() {
    super.initState();
    _inicializarReproductor();
  }

  Future<void> _inicializarReproductor() async {
    setState(() {
      _inicializando = true;
      _mensajeError = null;
    });

    try {
      if (widget.archivoLocal != null && widget.archivoLocal!.existsSync()) {
        _videoPlayerController = VideoPlayerController.file(widget.archivoLocal!);
      } else {
        final url = widget.urlRemota.trim();
        if (url.startsWith('http://') || url.startsWith('https://')) {
          _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
        } else if (url.isNotEmpty && File(url).existsSync()) {
          _videoPlayerController = VideoPlayerController.file(File(url));
        } else {
          throw Exception('La ruta del video local no existe y la URL no es válida.');
        }
      }

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: _videoPlayerController!.value.aspectRatio > 0
            ? _videoPlayerController!.value.aspectRatio
            : 16 / 9,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF52ABEB),
          handleColor: const Color(0xFF52ABEB),
          backgroundColor: Colors.grey.shade400,
          bufferedColor: const Color(0xFF63D0A1).withValues(alpha: 0.5),
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator(color: Color(0xFF52ABEB))),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error al reproducir el video: $errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _inicializando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensajeError = 'Error al cargar el archivo de video: $e';
          _inicializando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_inicializando) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF52ABEB)),
            const SizedBox(height: 16),
            Text(
              'Inicializando reproductor de video...',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade300),
            ),
          ],
        ),
      );
    }

    if (_mensajeError != null || _chewieController == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el video',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red.shade900),
            ),
            const SizedBox(height: 6),
            Text(
              _mensajeError ?? 'Formato de video no compatible o archivo no encontrado.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              onPressed: _inicializarReproductor,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
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
      child: AspectRatio(
        aspectRatio: _videoPlayerController!.value.aspectRatio > 0
            ? _videoPlayerController!.value.aspectRatio
            : 16 / 9,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modelo/tablero.dart';
import '../modelo/tarea.dart';
import '../modelo/chat_mensaje.dart';
import '../controlador/asistente_ia_chat_controller.dart';
import '../utilerias/formato_util.dart';

/// Pantalla de Chatbot con IA de Solo Lectura sobre el Tablero Activo (Fase 2).
class AsistenteIaChatView extends StatefulWidget {
  final Tablero tablero;
  final List<Tarea> tareasTablero;
  final Map<String, String> miembrosNombres;

  const AsistenteIaChatView({
    super.key,
    required this.tablero,
    required this.tareasTablero,
    required this.miembrosNombres,
  });

  @override
  State<AsistenteIaChatView> createState() => _AsistenteIaChatViewState();
}

class _AsistenteIaChatViewState extends State<AsistenteIaChatView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _enviarMensaje(AsistenteIaChatController controller, String texto) async {
    final mensaje = texto.trim();
    if (mensaje.isEmpty) return;

    _textController.clear();
    controller.setTranscription('');

    final ok = await controller.enviarMensaje(
      texto: mensaje,
      tablero: widget.tablero,
      tareasTablero: widget.tareasTablero,
      miembrosNombres: widget.miembrosNombres,
    );

    if (ok) {
      _scrollAlFinal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorAcento = const Color(0xFF63D0A1);

    return Consumer<AsistenteIaChatController>(
      builder: (context, controller, child) {
        // Sincronizar transcripción por voz con el campo de texto
        if (controller.transcription.isNotEmpty &&
            controller.transcription != _textController.text) {
          _textController.text = controller.transcription;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
            elevation: 1,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF63D0A1), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Asistente Kanbly IA',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  'Tablero: ${widget.tablero.nombre} (Solo Lectura)',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ],
            ),
            actions: [
              if (controller.historial.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Limpiar chat',
                  onPressed: () {
                    controller.limpiarHistorial();
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              // Banner de error si existe
              if (controller.errorMessage != null)
                Container(
                  width: double.infinity,
                  color: Colors.red.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.red),
                        onPressed: () => controller.limpiarError(),
                      ),
                    ],
                  ),
                ),

              // Lista de mensajes del chat
              Expanded(
                child: controller.historial.isEmpty
                    ? _buildSugerenciasIniciales(context, controller, colorAcento)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: controller.historial.length + (controller.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == controller.historial.length && controller.isLoading) {
                            return _buildIndicadorCarga(context, controller, isDark);
                          }

                          final msg = controller.historial[index];
                          return _buildBurbujaMensaje(context, msg, isDark, colorAcento);
                        },
                      ),
              ),

              // Barra inferior para escribir o dictar por voz
              _buildBarraEntrada(context, controller, isDark, colorAcento),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSugerenciasIniciales(
    BuildContext context,
    AsistenteIaChatController controller,
    Color colorAcento,
  ) {
    final sugerencias = [
      '¿Qué tareas están pendientes?',
      '¿Qué tareas vencen esta semana?',
      'Dame un resumen del tablero',
      '¿Cuáles son las tareas vencidas?',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorAcento.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy_outlined, color: colorAcento, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Hola! Soy tu asistente de consulta.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pregúntame sobre el estado del tablero, tareas asignadas o vencimientos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: sugerencias.map((sug) {
                return ActionChip(
                  avatar: const Icon(Icons.help_outline, size: 16),
                  label: Text(sug),
                  onPressed: () {
                    _enviarMensaje(controller, sug);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBurbujaMensaje(
    BuildContext context,
    ChatMensaje msg,
    bool isDark,
    Color colorAcento,
  ) {
    final esUsuario = msg.rol == RolMensaje.usuario;
    final theme = Theme.of(context);

    final bgUser = colorAcento;
    final bgAi = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final textColor = esUsuario
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment:
            esUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!esUsuario) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorAcento.withValues(alpha: 0.2),
              child: Icon(
                msg.esError ? Icons.error_outline : Icons.auto_awesome,
                color: msg.esError ? Colors.red : colorAcento,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.esError ? Colors.red.shade50 : (esUsuario ? bgUser : bgAi),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(esUsuario ? 16 : 4),
                  bottomRight: Radius.circular(esUsuario ? 4 : 16),
                ),
                border: msg.esError
                    ? Border.all(color: Colors.red.shade300)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: esUsuario
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.texto,
                    style: TextStyle(
                      color: msg.esError ? Colors.red.shade900 : textColor,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    FormatoUtil.formatearHora12h(msg.fecha),
                    style: TextStyle(
                      fontSize: 10,
                      color: esUsuario
                          ? Colors.white70
                          : theme.hintColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (esUsuario) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.primaryColor,
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIndicadorCarga(
    BuildContext context,
    AsistenteIaChatController controller,
    bool isDark,
  ) {
    final colorAcento = const Color(0xFF63D0A1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colorAcento.withValues(alpha: 0.2),
            child: Icon(Icons.auto_awesome, color: colorAcento, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colorAcento),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  controller.mensajeCarga,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraEntrada(
    BuildContext context,
    AsistenteIaChatController controller,
    bool isDark,
    Color colorAcento,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Botón de micrófono para dictado por voz (es_MX)
            IconButton(
              icon: Icon(
                controller.isListening ? Icons.mic : Icons.mic_none_rounded,
                color: controller.isListening ? Colors.red : colorAcento,
              ),
              tooltip: controller.isListening
                  ? 'Detener voz'
                  : 'Dictar consulta por voz',
              onPressed: () async {
                if (controller.isListening) {
                  await controller.detenerEscucha();
                } else {
                  await controller.iniciarEscucha();
                }
              },
            ),
            const SizedBox(width: 4),

            // Campo de texto
            Expanded(
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                enabled: !controller.isLoading,
                decoration: InputDecoration(
                  hintText: controller.isListening
                      ? 'Escuchando voz...'
                      : 'Escribe tu consulta...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.grey.shade900
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (val) => _enviarMensaje(controller, val),
              ),
            ),
            const SizedBox(width: 8),

            // Botón de envío
            IconButton(
              icon: controller.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.send_rounded, color: colorAcento),
              onPressed: controller.isLoading
                  ? null
                  : () => _enviarMensaje(controller, _textController.text),
            ),
          ],
        ),
      ),
    );
  }
}

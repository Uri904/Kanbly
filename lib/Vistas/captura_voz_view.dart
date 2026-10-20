import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controlador/asistente_ia_controller.dart';
import '../modelo/tablero.dart';
import '../modelo/usuario.dart';
import 'vista_previa_borradores_view.dart';

class CapturaVozView extends StatefulWidget {
  final Tablero tablero;
  final List<Usuario> miembrosEquipo;

  const CapturaVozView({
    super.key,
    required this.tablero,
    required this.miembrosEquipo,
  });

  @override
  State<CapturaVozView> createState() => _CapturaVozViewState();
}

class _CapturaVozViewState extends State<CapturaVozView> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<AsistenteIaController>(context, listen: false);
      _textController.text = controller.transcription;
      controller.inicializarVoz();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _procesarConIa(AsistenteIaController controller) async {
    // Sincronizar el texto del campo por si el usuario lo editó manualmente
    controller.setTranscription(_textController.text);

    final List<Map<String, String>> listaMiembrosMap = widget.miembrosEquipo
        .map((m) => {'uid': m.id, 'nombre': m.nombre})
        .toList();

    final ok = await controller.procesarTranscripcionConIa(
      fechaActual: DateTime.now(),
      columnas: widget.tablero.columnas,
      miembros: listaMiembrosMap,
    );

    if (ok && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: controller,
            child: VistaPreviaBorradoresView(
              tablero: widget.tablero,
              miembrosEquipo: widget.miembrosEquipo,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const Color azulCielo = Color(0xFF52ABEB);
    const Color verdeTurquesa = Color(0xFF63D0A1);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: azulCielo),
            SizedBox(width: 8),
            Text('Asistente de Voz IA'),
          ],
        ),
        elevation: 0,
      ),
      body: Consumer<AsistenteIaController>(
        builder: (context, controller, child) {
          // Mantener sincronizado el texto transcrito
          if (_textController.text != controller.transcription &&
              controller.isListening) {
            _textController.text = controller.transcription;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera descriptiva
                Text(
                  'Dicta tus tareas por voz',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ejemplo: "Tengo que preparar la presentación para mañana a las 4pm, asignarla a Carlos y marcarla como prioridad alta."',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),

                // Botón de Micrófono Principal e Indicador Visual
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: controller.isLoading
                            ? null
                            : () {
                                if (controller.isListening) {
                                  controller.detenerEscucha();
                                } else {
                                  controller.iniciarEscucha();
                                }
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: EdgeInsets.all(controller.isListening ? 28 : 22),
                          decoration: BoxDecoration(
                            color: controller.isListening
                                ? Colors.redAccent
                                : azulCielo,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (controller.isListening
                                        ? Colors.redAccent
                                        : azulCielo)
                                    .withValues(alpha: 0.4),
                                blurRadius: controller.isListening ? 20 : 10,
                                spreadRadius: controller.isListening ? 6 : 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            controller.isListening
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        controller.isListening
                            ? 'Escuchando... Di tus tareas'
                            : 'Toca el micrófono para comenzar a dictar',
                        style: TextStyle(
                          color: controller.isListening
                              ? Colors.redAccent
                              : theme.colorScheme.onSurface,
                          fontWeight: controller.isListening
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Transcripción editable (TextFormField)
                Text(
                  'Transcripción (puedes editarla):',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _textController,
                  maxLines: 5,
                  onChanged: (val) => controller.setTranscription(val),
                  decoration: InputDecoration(
                    hintText: 'Tu dictado aparecerá aquí...',
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: azulCielo, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Alerta si el permiso de micrófono está denegado permanentemente (Ajuste 13)
                if (controller.permissionPermanentlyDenied)
                  Card(
                    color: Colors.amber.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                'Permiso de micrófono requerido',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Para usar el dictado por voz, habilita el micrófono en los ajustes de tu dispositivo o escribe directamente las tareas en el cuadro de texto.',
                            style: TextStyle(color: Colors.black87, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  controller.abrirAjustesDispositivo(),
                              icon: const Icon(Icons.settings, size: 18),
                              label: const Text('Abrir Ajustes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade800,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Mensaje de error general si aplica
                if (controller.errorMessage != null &&
                    !controller.permissionPermanentlyDenied)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            controller.errorMessage!,
                            style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => controller.clearErrorMessage(),
                        )
                      ],
                    ),
                  ),

                // Estado de Carga ("Procesando con IA...")
                if (controller.isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(color: verdeTurquesa),
                        const SizedBox(height: 12),
                        Text(
                          controller.mensajeCarga,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: verdeTurquesa,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  // Botón "Procesar con IA"
                  ElevatedButton.icon(
                    onPressed: controller.transcription.trim().isEmpty
                        ? null
                        : () => _procesarConIa(controller),
                    icon: const Icon(Icons.auto_awesome, color: Colors.white),
                    label: const Text(
                      'Procesar con IA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: verdeTurquesa,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

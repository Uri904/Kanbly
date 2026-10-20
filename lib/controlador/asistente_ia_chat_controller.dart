import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../modelo/chat_mensaje.dart';
import '../modelo/tablero.dart';
import '../modelo/tarea.dart';
import '../servicios/asistente_ia_service.dart';

/// Controlador de estado para la sesión de Chatbot de IA de Solo Lectura (Fase 2).
///
/// Mantiene el historial de la conversación en memoria (limitado a los últimos 10 mensajes),
/// la integración con dictado por voz opcional (`speech_to_text` en `es_MX`) y el patrón de
/// estado observable mediante [ChangeNotifier].
class AsistenteIaChatController extends ChangeNotifier {
  final IAsistenteIaChatService _chatService;
  final SpeechToText _speechToText;

  List<ChatMensaje> _historial = [];
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechInitialized = false;
  bool _permissionPermanentlyDenied = false;
  String _transcription = '';
  String? _errorMessage;
  String _mensajeCarga = 'Consultando información con IA...';

  AsistenteIaChatController({
    IAsistenteIaChatService? chatService,
    SpeechToText? speechToText,
  })  : _chatService = chatService ?? AsistenteIaService(),
        _speechToText = speechToText ?? SpeechToText();

  // Getters de estado
  List<ChatMensaje> get historial => List.unmodifiable(_historial);
  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  bool get speechInitialized => _speechInitialized;
  bool get permissionPermanentlyDenied => _permissionPermanentlyDenied;
  String get transcription => _transcription;
  String? get errorMessage => _errorMessage;
  String get mensajeCarga => _mensajeCarga;

  /// Limpia cualquier mensaje de error activo en la UI.
  void limpiarError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpia el historial de la conversación en memoria.
  void limpiarHistorial() {
    _historial.clear();
    _errorMessage = null;
    notifyListeners();
  }

  /// Establece o actualiza manualmente la transcripción actual.
  void setTranscription(String text) {
    _transcription = text;
    notifyListeners();
  }

  /// Envía un mensaje del usuario al servicio de IA y registra la respuesta.
  Future<bool> enviarMensaje({
    required String texto,
    required Tablero tablero,
    required List<Tarea> tareasTablero,
    required Map<String, String> miembrosNombres,
    DateTime? fechaActual,
  }) async {
    final textoLimpio = texto.trim();
    if (textoLimpio.isEmpty) {
      _errorMessage = 'Escribe o dicta una consulta antes de enviar.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    _isLoading = true;
    _mensajeCarga = 'Consultando información con IA...';

    // 1. Registrar mensaje del usuario en el historial
    final idUsuarioMsg = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final msgUsuario = ChatMensaje(
      id: idUsuarioMsg,
      rol: RolMensaje.usuario,
      texto: textoLimpio,
      fecha: DateTime.now(),
    );

    _historial.add(msgUsuario);
    _recortarHistorial();
    notifyListeners();

    try {
      final respuestaIa = await _chatService.enviarMensajeChat(
        mensajeUsuario: textoLimpio,
        historial: _historial,
        tablero: tablero,
        tareasTablero: tareasTablero,
        miembrosNombres: miembrosNombres,
        fechaActual: fechaActual ?? DateTime.now(),
        onReintento: (intento, intentosMaximos) {
          _mensajeCarga =
              'El servicio está ocupado, reintentando ($intento/$intentosMaximos)...';
          notifyListeners();
        },
      );

      // 2. Registrar respuesta de la IA en el historial
      final idAiMsg = 'ai_${DateTime.now().millisecondsSinceEpoch}';
      final msgAi = ChatMensaje(
        id: idAiMsg,
        rol: RolMensaje.asistente,
        texto: respuestaIa,
        fecha: DateTime.now(),
      );

      _historial.add(msgAi);
      _recortarHistorial();
      _transcription = '';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      final textoError = e is AsistenteIaException ? e.mensaje : e.toString();
      _errorMessage = textoError;

      // Opcional: Registrar mensaje de error en el historial
      final idErrorMsg = 'err_${DateTime.now().millisecondsSinceEpoch}';
      final msgError = ChatMensaje(
        id: idErrorMsg,
        rol: RolMensaje.asistente,
        texto: 'Error: $textoError',
        fecha: DateTime.now(),
        esError: true,
      );
      _historial.add(msgError);
      _recortarHistorial();

      notifyListeners();
      return false;
    }
  }

  /// Limita el historial en memoria a los últimos 10 mensajes.
  void _recortarHistorial() {
    if (_historial.length > 10) {
      _historial = _historial.sublist(_historial.length - 10);
    }
  }

  // ===========================================================================
  // RECONOCIMIENTO DE VOZ (speech_to_text con localeId: 'es_MX')
  // ===========================================================================

  /// Inicializa el reconocimiento de voz.
  Future<bool> inicializarVoz() async {
    if (_speechInitialized) return true;

    try {
      _speechInitialized = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            notifyListeners();
          }
        },
        onError: (errorNotification) {
          _isListening = false;
          if (errorNotification.permanent) {
            _permissionPermanentlyDenied = true;
          }
          _errorMessage = 'Error de micrófono: ${errorNotification.errorMsg}';
          notifyListeners();
        },
      );

      if (!_speechInitialized) {
        _permissionPermanentlyDenied = true;
        _errorMessage =
            'No se pudo inicializar el micrófono o el permiso fue denegado.';
      } else {
        _permissionPermanentlyDenied = false;
      }

      notifyListeners();
      return _speechInitialized;
    } catch (e) {
      _speechInitialized = false;
      _permissionPermanentlyDenied = true;
      _errorMessage = 'Excepción al inicializar micrófono: $e';
      notifyListeners();
      return false;
    }
  }

  /// Inicia la escucha de voz en español de México (`es_MX`).
  Future<void> iniciarEscucha() async {
    _errorMessage = null;

    if (!_speechInitialized) {
      final ok = await inicializarVoz();
      if (!ok) return;
    }

    try {
      _isListening = true;
      notifyListeners();

      await _speechToText.listen(
        onResult: (result) {
          _transcription = result.recognizedWords;
          notifyListeners();
        },
        listenOptions: SpeechListenOptions(
          localeId: 'es_MX',
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      _isListening = false;
      _errorMessage = 'Error al iniciar la escucha por voz: $e';
      notifyListeners();
    }
  }

  /// Detiene la escucha por voz.
  Future<void> detenerEscucha() async {
    try {
      await _speechToText.stop();
      _isListening = false;
      notifyListeners();
    } catch (_) {
      _isListening = false;
      notifyListeners();
    }
  }

  /// Permite abrir los ajustes del dispositivo si el permiso del micrófono fue denegado.
  Future<void> abrirAjustesDispositivo() async {
    try {
      await openAppSettings();
    } catch (_) {}
  }
}

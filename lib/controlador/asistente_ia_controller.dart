import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelo/tarea_borrador.dart';
import '../modelo/tarea.dart';
import '../servicios/asistente_ia_service.dart';
import '../servicios/firestore_service.dart';

/// Controlador que gestiona el estado del dictado por voz, la interacción con la IA
/// y la administración de borradores de tareas.
///
/// Soporta inyección de dependencias para `IAsistenteIaService` y `SpeechToText` (Ajuste 12)
/// permitiendo realizar pruebas unitarias con fakes/mocks de forma aislada.
class AsistenteIaController extends ChangeNotifier {
  final IAsistenteIaService _iaService;
  final SpeechToText _speechToText;
  FirestoreService? _firestoreServiceInstance;

  FirestoreService get _firestoreService =>
      _firestoreServiceInstance ??= FirestoreService();

  bool _isListening = false;
  bool _speechInitialized = false;
  bool _permissionPermanentlyDenied = false;
  String _transcription = '';
  bool _isLoading = false;
  String? _errorMessage;

  List<TareaBorrador> _borradores = [];
  String _mensajeCarga = 'Procesando dictado con IA Gemini...';

  AsistenteIaController({
    IAsistenteIaService? iaService,
    SpeechToText? speechToText,
    FirestoreService? firestoreService,
  })  : _iaService = iaService ?? AsistenteIaService(),
        _speechToText = speechToText ?? SpeechToText(),
        _firestoreServiceInstance = firestoreService;

  // Getters de estado
  bool get isListening => _isListening;
  bool get speechInitialized => _speechInitialized;
  bool get permissionPermanentlyDenied => _permissionPermanentlyDenied;
  String get transcription => _transcription;
  bool get isLoading => _isLoading;
  String get mensajeCarga => _mensajeCarga;
  String? get errorMessage => _errorMessage;
  List<TareaBorrador> get borradores => List.unmodifiable(_borradores);

  // Setters/mutadores
  void setTranscription(String newText) {
    _transcription = newText;
    notifyListeners();
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Inicializa el servicio de reconocimiento de voz de la plataforma
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
      _errorMessage = 'Excepción al inicializar el micrófono: $e';
      notifyListeners();
      return false;
    }
  }

  /// Inicia la escucha por voz configurando localeId 'es_MX' (Ajuste 4)
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
          localeId: 'es_MX', // Ajuste 4: Usar localeId 'es_MX'
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      _isListening = false;
      _errorMessage = 'Error al iniciar escucha: $e';
      notifyListeners();
    }
  }

  /// Detiene la escucha por voz
  Future<void> detenerEscucha() async {
    try {
      await _speechToText.stop();
      _isListening = false;
      notifyListeners();
    } catch (e) {
      _isListening = false;
      notifyListeners();
    }
  }

  /// Indica que el usuario puede abrir los ajustes del dispositivo si el permiso fue denegado
  Future<void> abrirAjustesDispositivo() async {
    try {
      final bool hasPermissionError = _permissionPermanentlyDenied ||
          (_errorMessage != null &&
              _errorMessage!.toLowerCase().contains('permiso'));

      if (hasPermissionError || _permissionPermanentlyDenied) {
        await openAppSettings();
      } else {
        await inicializarVoz();
      }
    } catch (_) {
      try {
        await openAppSettings();
      } catch (_) {}
    }
  }

  /// Procesa la transcripción con el servicio de IA y genera la lista de borradores en memoria
  Future<bool> procesarTranscripcionConIa({
    required DateTime fechaActual,
    required List<String> columnas,
    required List<Map<String, String>> miembros,
  }) async {
    if (_transcription.trim().isEmpty) {
      _errorMessage = 'Por favor dicta o escribe las tareas antes de procesar.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _mensajeCarga = 'Procesando dictado con IA Gemini...';
    _errorMessage = null;
    notifyListeners();

    try {
      final resultados = await _iaService.procesarDictadoVoz(
        textoTranscrito: _transcription,
        fechaActual: fechaActual,
        columnas: columnas,
        miembros: miembros,
        onReintento: (intento, intentosMaximos) {
          _mensajeCarga =
              'El servicio está ocupado, reintentando ($intento/$intentosMaximos)...';
          notifyListeners();
        },
      );

      _borradores = resultados;
      _isLoading = false;

      if (_borradores.isEmpty) {
        _errorMessage =
            'No se identificaron tareas claras en la transcripción.';
        notifyListeners();
        return false;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'No se pudo procesar con IA: $e';
      notifyListeners();
      return false;
    }
  }

  // Operaciones de manipulación de borradores en memoria (Ajuste 3 / Requisito 3)

  void agregarBorradorManual(String columnaDefault) {
    final idLocal = 'borrador_${DateTime.now().millisecondsSinceEpoch}';
    final nuevo = TareaBorrador(
      id: idLocal,
      titulo: 'Nueva tarea',
      columna: columnaDefault,
    );
    _borradores.add(nuevo);
    notifyListeners();
  }

  void actualizarBorrador(int index, TareaBorrador borradorActualizado) {
    if (index >= 0 && index < _borradores.length) {
      _borradores[index] = borradorActualizado;
      notifyListeners();
    }
  }

  void eliminarBorrador(int index) {
    if (index >= 0 && index < _borradores.length) {
      _borradores.removeAt(index);
      notifyListeners();
    }
  }

  /// Confirma y guarda todos los borradores actuales en Firestore mediante WriteBatch
  Future<bool> guardarBorradoresEnFirestore({
    required String tableroId,
    required String creadorId,
  }) async {
    if (_borradores.isEmpty) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<Tarea> tareasOFiciales = [];

      for (final borrador in _borradores) {
        final idDoc = FirebaseFirestore.instance.collection('tareas').doc().id;

        final tarea = borrador.toTarea(
          idTareaDoc: idDoc,
          tableroId: tableroId,
          creadorId: creadorId,
          orden: 0,
        );
        tareasOFiciales.add(tarea);
      }

      await _firestoreService.crearTareasEnLote(tareasOFiciales);

      _borradores.clear();
      _transcription = '';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error al subir tareas al tablero: $e';
      notifyListeners();
      return false;
    }
  }

  void resetear() {
    _transcription = '';
    _errorMessage = null;
    _isLoading = false;
    _isListening = false;
    _mensajeCarga = 'Procesando dictado con IA Gemini...';
    _borradores.clear();
    notifyListeners();
  }
}

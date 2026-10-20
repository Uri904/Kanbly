import 'dart:async';
import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import '../modelo/tarea_borrador.dart';

/// Interfaz abstracta para el servicio de Asistente con IA.
/// Permite inyectar un doble de prueba (Fake/Mock) en controladores y pruebas unitarias.
abstract class IAsistenteIaService {
  Future<List<TareaBorrador>> procesarDictadoVoz({
    required String textoTranscrito,
    required DateTime fechaActual,
    required List<String> columnas,
    required List<Map<String, String>> miembros, // cada mapa contiene 'uid' y 'nombre'
    void Function(int intento, int intentosMaximos)? onReintento,
  });
}

/// Mensajes breves en español listos para mostrarse al usuario.
///
/// Nunca se expone al usuario JSON crudo, códigos HTTP ni nombres de excepciones.
abstract final class MensajesAsistenteIa {
  /// El servicio está ocupado (500/503, "high demand", "overloaded" o
  /// "unavailable") y se agotaron los reintentos.
  static const String servicioOcupado =
      'El servicio de IA está ocupado. Intenta de nuevo en un momento.';

  /// El modelo solicitado no existe o no está disponible (404 / NOT_FOUND).
  static const String modeloNoDisponible =
      'El modelo de IA no está disponible.';

  /// La API de Firebase AI Logic no está habilitada en el proyecto (403 / PERMISSION_DENIED).
  static const String apiNoHabilitada =
      'La API de Firebase AI Logic no está habilitada en tu proyecto.';

  /// Fallo de red o falta de conexión a Internet.
  static const String sinConexion =
      'Sin conexión a Internet. Revisa tu red e intenta de nuevo.';

  /// La respuesta del modelo no se pudo interpretar (JSON inválido o vacío).
  static const String respuestaInvalida =
      'La IA devolvió una respuesta que no se pudo interpretar.';

  /// Cualquier otro error no contemplado.
  static const String errorInesperado =
      'No se pudo procesar el dictado con IA. Intenta de nuevo.';
}

/// Excepción del asistente de IA con un [mensaje] breve en español para el usuario.
///
/// [toString] devuelve únicamente el [mensaje], de modo que al mostrarla en la UI
/// nunca aparezcan códigos HTTP ni JSON crudo. La causa técnica original se
/// conserva en [causa] para registros o depuración.
class AsistenteIaException implements Exception {
  AsistenteIaException(this.mensaje, {this.causa});

  /// Texto en español que se puede mostrar directamente al usuario.
  final String mensaje;

  /// Error original de Firebase/Gemini que provocó la excepción (solo para diagnóstico).
  final Object? causa;

  @override
  String toString() => mensaje;
}

/// Datos necesarios para pedirle una generación al modelo de IA.
class SolicitudIa {
  const SolicitudIa({
    required this.nombreModelo,
    required this.prompt,
    required this.instruccionSistema,
    required this.configuracionGeneracion,
  });

  /// Modelo de Gemini que atenderá la solicitud.
  final String nombreModelo;

  /// Texto del usuario enviado al modelo.
  final String prompt;

  /// Instrucción de sistema que define el rol y las reglas del modelo.
  final String instruccionSistema;

  /// Configuración de generación (JSON estructurado, `responseSchema`, etc.).
  final GenerationConfig configuracionGeneracion;
}

/// Ejecuta una llamada a `generateContent` y devuelve el texto de la respuesta.
///
/// Por defecto usa `FirebaseAI.googleAI()`, pero puede sustituirse desde el
/// constructor de [AsistenteIaService] para probar los reintentos sin Firebase.
typedef GenerarContenidoIa = Future<String?> Function(SolicitudIa solicitud);

/// Clasificación interna de los errores de IA para decidir si se reintenta
/// y qué mensaje breve mostrar al usuario.
enum _ClaseErrorIa {
  /// Error temporal del servidor (500, 503, "high demand", "overloaded", "unavailable"): se reintenta.
  temporal,

  /// Cuota agotada (429 / RESOURCE_EXHAUSTED): no se reintenta con esperas cortas.
  servicioSaturado,

  /// Modelo inexistente o no soportado (404).
  modeloNoDisponible,

  /// API de Firebase AI Logic deshabilitada o sin permisos (403).
  apiNoHabilitada,

  /// Sin conexión o fallo de red.
  sinConexion,

  /// Respuesta del modelo imposible de interpretar.
  respuestaInvalida,

  /// Cualquier otro error.
  desconocido,
}

/// Servicio que interactúa con Gemini a través de Firebase AI Logic (`FirebaseAI.googleAI()`).
///
/// REINTENTOS AUTOMÁTICOS Y CONMUTACIÓN MULTIMODELO:
/// Prueba ordenadamente los modelos configurados (por defecto 'gemini-3.5-flash-lite'
/// y 'gemini-3.5-flash'). Para cada modelo se realizan hasta 2 intentos (12 s de
/// timeout por intento y 1 s de espera entre intentos si falla por error temporal).
/// Si un modelo agota sus intentos con error temporal, se conmuta al siguiente modelo.
/// Existe un tope total de procesamiento de 30 segundos acumulados.
///
/// NOTA DE CONFIGURACIÓN EN CONSOLA DE FIREBASE:
/// Para que `FirebaseAI.googleAI()` funcione correctamente sin API keys expuestas en el código:
/// 1. Ve a la consola de Firebase (https://console.firebase.google.com/).
/// 2. Selecciona tu proyecto y accede a la sección "Build" -> "AI Logic" (o "Vertex AI / Google AI in Firebase").
/// 3. Habilita la integración de Gemini Developer API.
class AsistenteIaService implements IAsistenteIaService {
  /// Lista predeterminada de modelos ordenados por velocidad y preferencia.
  static const List<String> modelosPredeterminados = <String>[
    'gemini-3.5-flash-lite',
    'gemini-3.5-flash',
  ];

  /// Esperas por defecto antes de cada reintento dentro del mismo modelo: 1 s.
  static const List<Duration> esperasReintentoPredeterminadas = <Duration>[
    Duration(seconds: 1),
  ];

  /// Timeout por defecto por intento de generación: 12 segundos.
  static const Duration timeoutPorIntentoPredeterminado = Duration(seconds: 12);

  /// Tope total de procesamiento para todo procesarDictadoVoz: 30 segundos.
  static const Duration topeTotalProcesamientoPredeterminado =
      Duration(seconds: 30);

  final List<String> modelos;

  /// Esperas entre reintentos por modelo.
  final List<Duration> esperasReintento;

  /// Timeout asignado a cada intento de generateContent.
  final Duration timeoutPorIntento;

  /// Tope máximo acumulado de tiempo para todo procesarDictadoVoz.
  final Duration topeTotalProcesamiento;

  final GenerarContenidoIa _generarContenido;
  final Future<void> Function(Duration duracion) _esperar;

  AsistenteIaService({
    List<String> modelos = modelosPredeterminados,
    List<Duration> esperasReintento = esperasReintentoPredeterminadas,
    this.timeoutPorIntento = timeoutPorIntentoPredeterminado,
    this.topeTotalProcesamiento = topeTotalProcesamientoPredeterminado,
    GenerarContenidoIa? generarContenido,
    Future<void> Function(Duration duracion)? esperar,
  })  : modelos = List<String>.unmodifiable(modelos),
        esperasReintento = List<Duration>.unmodifiable(esperasReintento),
        _generarContenido = generarContenido ?? _generarConFirebaseAi,
        _esperar = esperar ?? Future<void>.delayed;

  /// Número de intentos por cada modelo (intento inicial + reintentos configurados).
  int get intentosMaximosPorModelo => esperasReintento.length + 1;

  /// Número total máximo de intentos sumando todos los modelos.
  int get intentosMaximosTotales => modelos.length * intentosMaximosPorModelo;

  @override
  Future<List<TareaBorrador>> procesarDictadoVoz({
    required String textoTranscrito,
    required DateTime fechaActual,
    required List<String> columnas,
    required List<Map<String, String>> miembros,
    void Function(int intento, int intentosMaximos)? onReintento,
  }) async {
    final cronometroTotal = Stopwatch()..start();
    try {
      final textoLimpio = textoTranscrito.trim();
      if (textoLimpio.isEmpty) {
        return [];
      }

      final columnasLote = columnas.isNotEmpty
          ? columnas
          : const ['Pendiente', 'En progreso', 'Completada'];

      final List<String> uidsMiembros = miembros
          .map((m) => m['uid']?.trim() ?? '')
          .where((uid) => uid.isNotEmpty)
          .toList();

      // 1. Calcular offset de zona horaria de la fecha actual (ISO 8601 con offset)
      final offset = fechaActual.timeZoneOffset;
      final horas = offset.inHours.abs().toString().padLeft(2, '0');
      final minutos = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final signo = offset.isNegative ? '-' : '+';
      final isoOffsetStr =
          '${fechaActual.toIso8601String().split('.').first}$signo$horas:$minutos';

      // 2. Construir responseSchema dinámico con enums para columnas, prioridad y uids
      final Schema schemaTareas = Schema.object(
        properties: {
          'tareas': Schema.array(
            items: Schema.object(
              properties: {
                'titulo': Schema.string(
                  description: 'Título claro y conciso de la tarea dictada.',
                ),
                'descripcion': Schema.string(
                  description:
                      'Descripción o detalle adicional mencionado para la tarea, o null si no hay.',
                  nullable: true,
                ),
                'prioridad': Schema.enumString(
                  enumValues: const ['alta', 'media', 'baja'],
                  description:
                      'Prioridad indicada ("alta", "media", "baja") o null si no se especifica.',
                  nullable: true,
                ),
                'fechaLimite': Schema.string(
                  description:
                      'Fecha y hora límite calculada en formato ISO 8601 con offset de zona horaria o null si no hay.',
                  nullable: true,
                ),
                'columna': Schema.enumString(
                  enumValues: columnasLote,
                  description:
                      'Nombre exacto de una de las columnas del tablero recibidas.',
                  nullable: true,
                ),
                'asignadoUid': uidsMiembros.isNotEmpty
                    ? Schema.enumString(
                        enumValues: uidsMiembros,
                        description:
                            'UID del integrante al que se asigna la tarea o null si no se especifica.',
                        nullable: true,
                      )
                    : Schema.string(
                        description:
                            'UID del integrante al que se asigna la tarea o null.',
                        nullable: true,
                      ),
              },
              optionalProperties: const [
                'descripcion',
                'prioridad',
                'fechaLimite',
                'columna',
                'asignadoUid',
              ],
            ),
          ),
        },
      );

      // 3. Prompt del sistema en español con restricciones estrictas
      final String promptSistema = '''
Eres un asistente de IA experto en estructurar tareas para tableros Kanban.
Tu objetivo es analizar la transcripción de dictado por voz del usuario y extraer las tareas mencionadas.

Contexto proporcionado:
- Fecha y hora actual del usuario con offset de zona horaria: $isoOffsetStr
- Columnas permitidas en el tablero: ${columnasLote.join(', ')}
- Integrantes disponibles (UID y Nombre): ${miembros.map((m) => '${m['uid']}: ${m['nombre']}').join(', ')}

Reglas de extracción estrictas:
1. "titulo": Extrae el título principal de la tarea. Es un campo obligatorio.
2. "descripcion": Detalle explicativo de la tarea si fue dictado. Si no se menciona, debe ser null.
3. "prioridad": Selecciona una de las opciones ["alta", "media", "baja"] si el usuario la menciona o la sugiere claramente. Si no queda clara o no la menciona, asigna null.
4. "fechaLimite": Si el usuario indica un plazo o fecha (ej. "para mañana a las 3pm", "el viernes"), calcula la fecha/hora absoluta en formato ISO 8601 incluyendo el offset de zona horaria ($signo$horas:$minutos). Si no menciona fecha, asigna null.
5. "columna": Selecciona la columna más adecuada dentro de las columnas permitidas. Si no especifica columna, asigna la primera columna de la lista ("${columnasLote.first}").
6. "asignadoUid": Si el usuario menciona el nombre de un integrante de la lista, asigna su UID exacto. Si no coincide con ningún integrante o no se especifica, asigna null.
7. REGLA FUNDAMENTAL DE FIDELIDAD: NO dividas una sola tarea en múltiples tareas. Tampoco inventes tareas que no hayan sido mencionadas explícitamente en el dictado. Si algo no está claro, asigna null al campo correspondiente.
''';

      // 4. Ejecutar con la lista ordenada de modelos
      final String? responseText = await _generarContenidoConModelosYReintentos(
        promptUsuario: 'Texto dictado por el usuario: "$textoLimpio"',
        promptSistema: promptSistema,
        schemaTareas: schemaTareas,
        cronometroTotal: cronometroTotal,
        onReintento: onReintento,
      );

      if (responseText == null || responseText.trim().isEmpty) {
        throw AsistenteIaException(MensajesAsistenteIa.respuestaInvalida);
      }

      // 5. Parsear respuesta JSON devuelta por Gemini
      try {
        final dynamic parsedJson = jsonDecode(responseText);
        List<dynamic> listaTareasJson = [];

        if (parsedJson is Map<String, dynamic>) {
          if (parsedJson.containsKey('tareas') && parsedJson['tareas'] is List) {
            listaTareasJson = parsedJson['tareas'] as List<dynamic>;
          }
        } else if (parsedJson is List) {
          listaTareasJson = parsedJson;
        }

        final List<TareaBorrador> borradores = [];
        int contadorId = 1;

        for (final item in listaTareasJson) {
          if (item is Map<String, dynamic>) {
            final idLocal =
                'borrador_${DateTime.now().millisecondsSinceEpoch}_$contadorId';
            contadorId++;

            final borrador = TareaBorrador.fromMap(
              item,
              columnasDisponibles: columnasLote,
              miembrosUids: uidsMiembros,
              idLocal: idLocal,
            );
            borradores.add(borrador);
          }
        }

        return borradores;
      } on FormatException catch (error) {
        // JSON inválido: no se reintenta, se informa de inmediato.
        throw AsistenteIaException(MensajesAsistenteIa.respuestaInvalida,
            causa: error);
      } catch (error) {
        throw AsistenteIaException(MensajesAsistenteIa.errorInesperado,
            causa: error);
      }
    } finally {
      cronometroTotal.stop();
      debugPrint(
        '[AsistenteIaService] procesarDictadoVoz completado en ${cronometroTotal.elapsedMilliseconds} ms',
      );
    }
  }

  /// Llama a `generateContent` iterando sobre [modelos] y realizando hasta
  /// [intentosMaximosPorModelo] por modelo. Respetando el tope global de 30 s.
  Future<String?> _generarContenidoConModelosYReintentos({
    required String promptUsuario,
    required String promptSistema,
    required Schema schemaTareas,
    required Stopwatch cronometroTotal,
    void Function(int intento, int intentosMaximos)? onReintento,
  }) async {
    Object? ultimaCausa;
    final Set<String> modelosSinThinking = <String>{};
    int intentoGlobal = 0;

    for (var iModelo = 0; iModelo < modelos.length; iModelo++) {
      final nombreModelo = modelos[iModelo];
      final esUltimoModelo = iModelo == modelos.length - 1;

      for (var intentoModelo = 1;
          intentoModelo <= intentosMaximosPorModelo;
          intentoModelo++) {
        intentoGlobal++;

        // 1. Verificar si se superó el tope total de tiempo
        if (cronometroTotal.elapsed >= topeTotalProcesamiento) {
          debugPrint(
            '[AsistenteIaService] Se superó el tope total de procesamiento de ${topeTotalProcesamiento.inSeconds} s',
          );
          throw AsistenteIaException(MensajesAsistenteIa.servicioOcupado,
              causa: ultimaCausa);
        }

        final tiempoRestante = topeTotalProcesamiento - cronometroTotal.elapsed;
        if (tiempoRestante <= Duration.zero) {
          throw AsistenteIaException(MensajesAsistenteIa.servicioOcupado,
              causa: ultimaCausa);
        }

        final timeoutAplicable = tiempoRestante < timeoutPorIntento
            ? tiempoRestante
            : timeoutPorIntento;

        final usarThinking = !modelosSinThinking.contains(nombreModelo);
        final solicitud = SolicitudIa(
          nombreModelo: nombreModelo,
          prompt: promptUsuario,
          instruccionSistema: promptSistema,
          configuracionGeneracion: GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: schemaTareas,
            thinkingConfig: usarThinking
                ? ThinkingConfig.withThinkingLevel(ThinkingLevel.low)
                : null,
          ),
        );

        final cronometroIntento = Stopwatch()..start();
        try {
          final respuesta = await _generarContenido(solicitud)
              .timeout(timeoutAplicable);
          cronometroIntento.stop();
          debugPrint(
            '[AsistenteIaService] Modelo $nombreModelo - Intento $intentoModelo/$intentosMaximosPorModelo (Global $intentoGlobal/$intentosMaximosTotales) exitoso en ${cronometroIntento.elapsedMilliseconds} ms',
          );
          return respuesta;
        } on AsistenteIaException {
          cronometroIntento.stop();
          rethrow;
        } catch (error) {
          cronometroIntento.stop();
          final clase = _clasificarError(error);
          debugPrint(
            '[AsistenteIaService] Modelo $nombreModelo - Intento $intentoModelo/$intentosMaximosPorModelo (Global $intentoGlobal/$intentosMaximosTotales) falló en ${cronometroIntento.elapsedMilliseconds} ms. Clase: $clase. Error: $error',
          );

          // Si el modelo rechazó ThinkingConfig, lo registramos y reintentamos ese intento sin thinking
          final textoError = error.toString().toLowerCase();
          if (usarThinking && _esErrorThinkingConfig(textoError)) {
            debugPrint(
              '[AsistenteIaService] Modelo $nombreModelo rechazó ThinkingConfig. Reintentando sin thinking...',
            );
            modelosSinThinking.add(nombreModelo);
            intentoModelo--;
            intentoGlobal--;
            continue;
          }

          final esUltimoIntentoDelModelo =
              intentoModelo == intentosMaximosPorModelo;
          final esUltimoIntentoGlobal =
              intentoGlobal == intentosMaximosTotales;

          if (clase != _ClaseErrorIa.temporal ||
              (esUltimoModelo && esUltimoIntentoDelModelo)) {
            throw AsistenteIaException(_mensajeParaClase(clase), causa: error);
          }

          ultimaCausa = error;

          if (!esUltimoIntentoGlobal) {
            onReintento?.call(intentoGlobal + 1, intentosMaximosTotales);
          }

          // Esperar si es reintento dentro del mismo modelo
          if (!esUltimoIntentoDelModelo && esperasReintento.isNotEmpty) {
            final espera = esperasReintento[intentoModelo - 1];
            if (espera > Duration.zero) {
              await _esperar(espera);
            }
          }
        }
      }
    }

    throw AsistenteIaException(MensajesAsistenteIa.servicioOcupado,
        causa: ultimaCausa);
  }

  static bool _esErrorThinkingConfig(String textoError) {
    return textoError.contains('thinking') ||
        textoError.contains('thinking_config') ||
        textoError.contains('thinkingconfig') ||
        textoError.contains('thinking_level') ||
        textoError.contains('thinkinglevel') ||
        (textoError.contains('unrecognized') && textoError.contains('field'));
  }

  /// Llamada real a Gemini mediante Firebase AI Logic.
  static Future<String?> _generarConFirebaseAi(SolicitudIa solicitud) async {
    final generativeModel = FirebaseAI.googleAI().generativeModel(
      model: solicitud.nombreModelo,
      generationConfig: solicitud.configuracionGeneracion,
      systemInstruction: Content.system(solicitud.instruccionSistema),
    );

    final response = await generativeModel.generateContent([
      Content.text(solicitud.prompt),
    ]);

    return response.text;
  }

  /// Traduce el error original a una clase interna para decidir reintentos y mensajes.
  static _ClaseErrorIa _clasificarError(Object error) {
    if (error is ServiceApiNotEnabled) return _ClaseErrorIa.apiNoHabilitada;
    if (error is QuotaExceeded) return _ClaseErrorIa.servicioSaturado;
    if (error is TimeoutException) return _ClaseErrorIa.temporal;
    if (error is ClientException) return _ClaseErrorIa.sinConexion;
    if (error is FormatException || error is FirebaseAISdkException) {
      return _ClaseErrorIa.respuestaInvalida;
    }
    return _clasificarPorMensaje(_textoDeError(error));
  }

  /// Texto de diagnóstico del error (incluye el tipo concreto del SDK cuando aplica).
  static String _textoDeError(Object error) => error is FirebaseAIException
      ? '${error.runtimeType} ${error.message}'
      : error.toString();

  /// Clasifica un error a partir de su texto, sin exponerlo nunca al usuario.
  static _ClaseErrorIa _clasificarPorMensaje(String textoOriginal) {
    final texto = textoOriginal.toLowerCase();

    if (_contieneAlguno(texto, _marcadoresSinConexion)) {
      return _ClaseErrorIa.sinConexion;
    }
    if (_contieneAlguno(texto, _marcadoresApiNoHabilitada) ||
        _codigo403.hasMatch(texto)) {
      return _ClaseErrorIa.apiNoHabilitada;
    }
    if (_contieneAlguno(texto, _marcadoresModeloNoDisponible) ||
        _codigo404.hasMatch(texto)) {
      return _ClaseErrorIa.modeloNoDisponible;
    }
    if (_contieneAlguno(texto, _marcadoresTemporales) ||
        _codigo5xx.hasMatch(texto)) {
      return _ClaseErrorIa.temporal;
    }
    if (_contieneAlguno(texto, _marcadoresCuota) ||
        _codigo429.hasMatch(texto)) {
      return _ClaseErrorIa.servicioSaturado;
    }
    return _ClaseErrorIa.desconocido;
  }

  static bool _contieneAlguno(String texto, List<String> marcadores) =>
      marcadores.any(texto.contains);

  /// Mensaje breve en español para cada clase de error.
  static String _mensajeParaClase(_ClaseErrorIa clase) {
    switch (clase) {
      case _ClaseErrorIa.temporal:
      case _ClaseErrorIa.servicioSaturado:
        return MensajesAsistenteIa.servicioOcupado;
      case _ClaseErrorIa.modeloNoDisponible:
        return MensajesAsistenteIa.modeloNoDisponible;
      case _ClaseErrorIa.apiNoHabilitada:
        return MensajesAsistenteIa.apiNoHabilitada;
      case _ClaseErrorIa.sinConexion:
        return MensajesAsistenteIa.sinConexion;
      case _ClaseErrorIa.respuestaInvalida:
        return MensajesAsistenteIa.respuestaInvalida;
      case _ClaseErrorIa.desconocido:
        return MensajesAsistenteIa.errorInesperado;
    }
  }

  /// Códigos HTTP 5xx (500, 502, 503, 504...) presentes en el mensaje de error.
  static final RegExp _codigo5xx = RegExp(r'\b5\d{2}\b');
  static final RegExp _codigo403 = RegExp(r'\b403\b');
  static final RegExp _codigo404 = RegExp(r'\b404\b');
  static final RegExp _codigo429 = RegExp(r'\b429\b');

  /// Señales de fallo de red o falta de conexión.
  static const List<String> _marcadoresSinConexion = <String>[
    'socketexception',
    'clientexception',
    'failed host lookup',
    'connection closed',
    'connection reset',
    'connection refused',
    'connection aborted',
    'connection failed',
    'network is unreachable',
    'network-request-failed',
    'network error',
    'no internet',
    'not connected',
    'err_internet_disconnected',
    'failed to fetch',
    'xmlhttprequest error',
  ];

  /// Señales de API deshabilitada o sin permisos (403 / PERMISSION_DENIED).
  static const List<String> _marcadoresApiNoHabilitada = <String>[
    'firebase ai logic',
    'service_api_not_enabled',
    'serviceapinotenabled',
    'api has not been used',
    'has not been used in project',
    'is disabled',
    'not enabled',
    'permission_denied',
    'permission denied',
  ];

  /// Señales de modelo inexistente o no soportado (404 / NOT_FOUND).
  static const List<String> _marcadoresModeloNoDisponible = <String>[
    'not found',
    'not_found',
    'not supported',
    'not exist',
    'not available',
    'no longer available',
    'listmodels',
    'list models',
  ];

  /// Señales de sobrecarga temporal del servicio (reintentables).
  static const List<String> _marcadoresTemporales = <String>[
    'server error',
    'high demand',
    'overloaded',
    'over capacity',
    'unavailable',
    'internal error',
    'internal server',
    'deadline exceeded',
    'deadline_exceeded',
  ];

  /// Señales de cuota agotada (429 / RESOURCE_EXHAUSTED): no se reintenta.
  static const List<String> _marcadoresCuota = <String>[
    'quota',
    'resource_exhausted',
    'resource exhausted',
    'rate limit',
    'too many requests',
  ];
}

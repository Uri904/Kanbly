import 'dart:async';
import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import '../modelo/tarea_borrador.dart';
import '../modelo/tarea.dart';
import '../modelo/tablero.dart';
import '../modelo/chat_mensaje.dart';
import '../utilerias/kanban_utils.dart';

/// Interfaz abstracta para el servicio de Asistente con IA (Dictado por Voz).
abstract class IAsistenteIaService {
  Future<List<TareaBorrador>> procesarDictadoVoz({
    required String textoTranscrito,
    required DateTime fechaActual,
    required List<String> columnas,
    required List<Map<String, String>> miembros,
    void Function(int intento, int intentosMaximos)? onReintento,
  });
}

/// Interfaz abstracta para el servicio de Chatbot IA (Fase 2: Solo Lectura con Function Calling).
abstract class IAsistenteIaChatService {
  Future<String> enviarMensajeChat({
    required String mensajeUsuario,
    required List<ChatMensaje> historial,
    required Tablero tablero,
    required List<Tarea> tareasTablero,
    required Map<String, String> miembrosNombres,
    required DateTime fechaActual,
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
      'No se pudo procesar la solicitud con IA. Intenta de nuevo.';
}

/// Excepción del asistente de IA con un [mensaje] breve en español para el usuario.
class AsistenteIaException implements Exception {
  AsistenteIaException(this.mensaje, {this.causa});

  /// Texto en español que se puede mostrar directamente al usuario.
  final String mensaje;

  /// Error original de Firebase/Gemini que provocó la excepción (solo para diagnóstico).
  final Object? causa;

  @override
  String toString() => mensaje;
}

/// Datos necesarios para pedirle una generación o conversación al modelo de IA.
class SolicitudIa {
  const SolicitudIa({
    required this.nombreModelo,
    required this.prompt,
    required this.instruccionSistema,
    required this.configuracionGeneracion,
    this.tools,
    this.historial,
  });

  /// Modelo de Gemini que atenderá la solicitud.
  final String nombreModelo;

  /// Texto del usuario enviado al modelo.
  final String prompt;

  /// Instrucción de sistema que define el rol y las reglas del modelo.
  final String instruccionSistema;

  /// Configuración de generación (JSON estructurado, `responseSchema`, etc.).
  final GenerationConfig configuracionGeneracion;

  /// Lista opcional de herramientas (Function Calling).
  final List<Tool>? tools;

  /// Historial opcional de conversación en formato [Content].
  final List<Content>? historial;
}

/// Ejecuta una llamada a `generateContent` o `sendMessage` y devuelve el texto de la respuesta.
typedef GenerarContenidoIa = Future<String?> Function(SolicitudIa solicitud);

/// Clasificación interna de los errores de IA para decidir si se reintenta
/// y qué mensaje breve mostrar al usuario.
enum _ClaseErrorIa {
  temporal,
  servicioSaturado,
  modeloNoDisponible,
  apiNoHabilitada,
  sinConexion,
  respuestaInvalida,
  desconocido,
}

/// Servicio que interactúa con Gemini a través de Firebase AI Logic (`FirebaseAI.googleAI()`).
///
/// Soporta tanto Fase 1 (Dictado por Voz con JSON estructurado) como Fase 2 (Chatbot de Solo Lectura con Function Calling).
class AsistenteIaService implements IAsistenteIaService, IAsistenteIaChatService {
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

  /// Tope total de procesamiento: 30 segundos.
  static const Duration topeTotalProcesamientoPredeterminado =
      Duration(seconds: 30);

  final List<String> modelos;
  final List<Duration> esperasReintento;
  final Duration timeoutPorIntento;
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

  int get intentosMaximosPorModelo => esperasReintento.length + 1;
  int get intentosMaximosTotales => modelos.length * intentosMaximosPorModelo;

  // ===========================================================================
  // FASE 1: DICTADO POR VOZ (CREACIÓN DE BORRADORES DE TAREAS)
  // ===========================================================================

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

      final isoOffsetStr = _formatearFechaIsoOffset(fechaActual);
      final offset = fechaActual.timeZoneOffset;
      final horas = offset.inHours.abs().toString().padLeft(2, '0');
      final minutos = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final signo = offset.isNegative ? '-' : '+';

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

      final String? responseText = await _generarContenidoConModelosYReintentos(
        promptUsuario: 'Texto dictado por el usuario: "$textoLimpio"',
        promptSistema: promptSistema,
        configuracionGeneracionBuilder: (usarThinking) => GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: schemaTareas,
          thinkingConfig: usarThinking
              ? ThinkingConfig.withThinkingLevel(ThinkingLevel.low)
              : null,
        ),
        cronometroTotal: cronometroTotal,
        onReintento: onReintento,
      );

      if (responseText == null || responseText.trim().isEmpty) {
        throw AsistenteIaException(MensajesAsistenteIa.respuestaInvalida);
      }

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

  // ===========================================================================
  // FASE 2: CHATBOT DE SOLO LECTURA SOBRE EL TABLERO ACTIVO CON FUNCTION CALLING
  // ===========================================================================

  @override
  Future<String> enviarMensajeChat({
    required String mensajeUsuario,
    required List<ChatMensaje> historial,
    required Tablero tablero,
    required List<Tarea> tareasTablero,
    required Map<String, String> miembrosNombres,
    required DateTime fechaActual,
    void Function(int intento, int intentosMaximos)? onReintento,
  }) async {
    final cronometroTotal = Stopwatch()..start();
    try {
      final textoLimpio = mensajeUsuario.trim();
      if (textoLimpio.isEmpty) {
        return 'Por favor escribe o dicta un mensaje para consultar el tablero.';
      }

      final isoOffsetStr = _formatearFechaIsoOffset(fechaActual);

      // 1. Declarar las 5 herramientas de Function Calling (Solo Lectura)
      final autoTareasPorEstado = AutoFunctionDeclaration(
        name: 'tareasPorEstado',
        description:
            'Obtiene la lista de tareas del tablero activo filtradas por el nombre exacto o aproximado de una columna o estado.',
        parameters: {
          'estado': Schema.string(
            description: 'Nombre de la columna o estado (ej. "Pendiente", "En progreso", "Completada").',
          ),
        },
        callable: (args) async {
          final estadoArg = args['estado']?.toString() ?? '';
          return ejecutarTareasPorEstado(
            tareas: tareasTablero,
            miembrosNombres: miembrosNombres,
            estado: estadoArg,
            columnasTablero: tablero.columnas,
          );
        },
      );

      final autoTareasDeIntegrante = AutoFunctionDeclaration(
        name: 'tareasDeIntegrante',
        description:
            'Obtiene las tareas asignadas a un integrante específico por su UID o nombre.',
        parameters: {
          'integrante': Schema.string(
            description: 'UID o nombre del integrante del equipo.',
          ),
        },
        callable: (args) async {
          final integranteArg = args['integrante']?.toString() ?? '';
          return ejecutarTareasDeIntegrante(
            tareas: tareasTablero,
            miembrosNombres: miembrosNombres,
            integrante: integranteArg,
          );
        },
      );

      final autoTareasPorVencer = AutoFunctionDeclaration(
        name: 'tareasPorVencer',
        description:
            'Obtiene las tareas que están próximas a vencer dentro del número de días especificado.',
        parameters: {
          'dias': Schema.integer(
            description: 'Número de días hacia el futuro a considerar (por defecto 7).',
          ),
        },
        callable: (args) async {
          final diasVal = args['dias'];
          int dias = 7;
          if (diasVal is int) dias = diasVal;
          if (diasVal is num) dias = diasVal.toInt();
          if (diasVal is String) dias = int.tryParse(diasVal) ?? 7;

          return ejecutarTareasPorVencer(
            tareas: tareasTablero,
            miembrosNombres: miembrosNombres,
            fechaActual: fechaActual,
            dias: dias,
          );
        },
      );

      final autoTareasVencidas = AutoFunctionDeclaration(
        name: 'tareasVencidas',
        description:
            'Obtiene las tareas cuya fecha de vencimiento ya pasó y aún no han sido completadas.',
        parameters: const {},
        callable: (args) async {
          return ejecutarTareasVencidas(
            tareas: tareasTablero,
            miembrosNombres: miembrosNombres,
            fechaActual: fechaActual,
            columnasTablero: tablero.columnas,
          );
        },
      );

      final autoResumenDelTablero = AutoFunctionDeclaration(
        name: 'resumenDelTablero',
        description:
            'Devuelve un resumen general con el conteo de tareas del tablero activo desglosado por columna.',
        parameters: const {},
        callable: (args) async {
          return ejecutarResumenDelTablero(
            tareas: tareasTablero,
            columnasTablero: tablero.columnas,
          );
        },
      );

      final tools = [
        Tool.functionDeclarations([
          autoTareasPorEstado,
          autoTareasDeIntegrante,
          autoTareasPorVencer,
          autoTareasVencidas,
          autoResumenDelTablero,
        ]),
      ];

      // 2. System Prompt en español con restricciones de solo lectura
      final promptSistema = '''
Eres el Asistente IA de Kanbly de SOLO LECTURA sobre el tablero activo.
Tu objetivo es responder las consultas del usuario utilizando EXCLUSIVAMENTE las funciones de consulta disponibles.

Contexto del tablero activo:
- Fecha y hora actual del usuario (con offset): $isoOffsetStr
- Nombre del tablero: ${tablero.nombre}
- Columnas permitidas: ${tablero.columnas.join(', ')}
- Integrantes del equipo (UID: Nombre): ${miembrosNombres.entries.map((e) => '${e.key}: ${e.value}').join(', ')}

Reglas de conducta estrictas:
1. Responde de forma breve, clara, estructurada y amable en español.
2. Básate ÚNICAMENTE en la información devuelta por las funciones de consulta.
3. Si una función devuelve una lista vacía o indica que no hay tareas, dilo claramente al usuario. NUNCA inventes tareas, fechas, nombres ni estados.
4. Si el usuario te pide crear, editar, reordenar, mover o eliminar tareas o tableros, infórmale amablemente que este chatbot es de SOLO LECTURA, y que para crear tareas por voz puede usar el botón del Asistente de Voz (Fase 1) o hacerlo directamente desde el tablero.
5. Utiliza de forma proactiva la función de consulta más adecuada (`tareasPorEstado`, `tareasDeIntegrante`, `tareasPorVencer`, `tareasVencidas` o `resumenDelTablero`) para obtener los datos precisos antes de responder.
6. Si una función de consulta indica que `total` es mayor que `mostradas`, avisa explícitamente al usuario en tu respuesta indicando que solo le estás mostrando `mostradas` de un total de `total` tareas existentes.
''';

      // 3. Convertir historial de mensajes a objetos Content de firebase_ai
      final List<Content> historialContent = historial.map((m) {
        if (m.rol == RolMensaje.usuario) {
          return Content.text(m.texto);
        } else {
          return Content.model([TextPart(m.texto)]);
        }
      }).toList();

      // 4. Ejecutar con la lista ordenada de modelos y reintentos
      final String? responseText = await _generarContenidoConModelosYReintentos(
        promptUsuario: textoLimpio,
        promptSistema: promptSistema,
        configuracionGeneracionBuilder: (usarThinking) => GenerationConfig(
          thinkingConfig: usarThinking
              ? ThinkingConfig.withThinkingLevel(ThinkingLevel.low)
              : null,
        ),
        tools: tools,
        historial: historialContent,
        cronometroTotal: cronometroTotal,
        onReintento: onReintento,
      );

      if (responseText == null || responseText.trim().isEmpty) {
        throw AsistenteIaException(MensajesAsistenteIa.respuestaInvalida);
      }

      return responseText.trim();
    } finally {
      cronometroTotal.stop();
      debugPrint(
        '[AsistenteIaService] enviarMensajeChat completado en ${cronometroTotal.elapsedMilliseconds} ms',
      );
    }
  }

  // ===========================================================================
  // FUNCIONES ESTÁTICAS DE CONSULTA (100% TESTEABLES EN PRUEBAS UNITARIAS)
  // ===========================================================================

  static Map<String, dynamic> ejecutarTareasPorEstado({
    required List<Tarea> tareas,
    required Map<String, String> miembrosNombres,
    required String estado,
    List<String> columnasTablero = const ['Pendiente', 'En progreso', 'Completada'],
  }) {
    final columnas = columnasTablero.isNotEmpty
        ? columnasTablero
        : const ['Pendiente', 'En progreso', 'Completada'];

    int targetIndex = -1;
    String targetCol = estado.trim();

    final estadoLimpio = estado.trim().toLowerCase();
    for (int i = 0; i < columnas.length; i++) {
      final col = columnas[i];
      final colLimpio = col.trim().toLowerCase();
      if (colLimpio == estadoLimpio) {
        targetIndex = i;
        targetCol = col;
        break;
      }
      final esPorHacer = (colLimpio == 'pendiente' || colLimpio == 'por hacer');
      final reqEsPorHacer = (estadoLimpio == 'pendiente' || estadoLimpio == 'por hacer');
      if (esPorHacer && reqEsPorHacer) {
        targetIndex = i;
        targetCol = col;
        break;
      }

      final esEnProgreso = (colLimpio == 'en progreso' || colLimpio == 'en proceso' || colLimpio == 'haciendo');
      final reqEsEnProgreso = (estadoLimpio == 'en progreso' || estadoLimpio == 'en proceso' || estadoLimpio == 'haciendo');
      if (esEnProgreso && reqEsEnProgreso) {
        targetIndex = i;
        targetCol = col;
        break;
      }

      final esCompletada = (colLimpio == 'completada' || colLimpio == 'completado' || colLimpio == 'terminada' || colLimpio == 'hecho');
      final reqEsCompletada = (estadoLimpio == 'completada' || estadoLimpio == 'completado' || estadoLimpio == 'terminada' || estadoLimpio == 'hecho');
      if (esCompletada && reqEsCompletada) {
        targetIndex = i;
        targetCol = col;
        break;
      }
    }

    final filtradas = tareas.where((t) {
      if (t.archivada) return false;
      if (targetIndex != -1) {
        return KanbanUtils.correspondeAColumna(t, targetCol, columnas, targetIndex);
      }
      return KanbanUtils.correspondeAColumna(t, targetCol, columnas, 0);
    }).toList();

    final total = filtradas.length;
    final mostradasList = filtradas.take(20).map((t) => _mapearTareaParaIa(t, miembrosNombres)).toList();

    return {
      'total': total,
      'mostradas': mostradasList.length,
      'tareas': mostradasList,
    };
  }

  static Map<String, dynamic> ejecutarTareasDeIntegrante({
    required List<Tarea> tareas,
    required Map<String, String> miembrosNombres,
    required String integrante,
  }) {
    final integranteLimpio = integrante.trim().toLowerCase();
    final filtradas = tareas.where((t) {
      if (t.archivada) return false;
      return t.asignadosA.any((uid) {
        if (uid.toLowerCase() == integranteLimpio) return true;
        final nombre = miembrosNombres[uid]?.toLowerCase() ?? '';
        return nombre.contains(integranteLimpio);
      });
    }).toList();

    final total = filtradas.length;
    final mostradasList = filtradas.take(20).map((t) => _mapearTareaParaIa(t, miembrosNombres)).toList();

    return {
      'total': total,
      'mostradas': mostradasList.length,
      'tareas': mostradasList,
    };
  }

  static Map<String, dynamic> ejecutarTareasPorVencer({
    required List<Tarea> tareas,
    required Map<String, String> miembrosNombres,
    required DateTime fechaActual,
    int dias = 7,
  }) {
    final limiteFuturo = fechaActual.add(Duration(days: dias));
    final filtradas = tareas.where((t) {
      if (t.archivada) return false;
      if (t.fechaVencimiento == null) return false;
      return t.fechaVencimiento!.isAfter(fechaActual) &&
          (t.fechaVencimiento!.isBefore(limiteFuturo) ||
              t.fechaVencimiento!.isAtSameMomentAs(limiteFuturo));
    }).toList();

    final total = filtradas.length;
    final mostradasList = filtradas.take(20).map((t) => _mapearTareaParaIa(t, miembrosNombres)).toList();

    return {
      'total': total,
      'mostradas': mostradasList.length,
      'tareas': mostradasList,
    };
  }

  static Map<String, dynamic> ejecutarTareasVencidas({
    required List<Tarea> tareas,
    required Map<String, String> miembrosNombres,
    required DateTime fechaActual,
    List<String> columnasTablero = const ['Pendiente', 'En progreso', 'Completada'],
  }) {
    final filtradas = tareas.where((t) {
      if (t.archivada) return false;
      if (t.fechaVencimiento == null) return false;
      if (KanbanUtils.esTareaCompletada(t, columnasTablero)) return false;
      return t.fechaVencimiento!.isBefore(fechaActual);
    }).toList();

    final total = filtradas.length;
    final mostradasList = filtradas.take(20).map((t) => _mapearTareaParaIa(t, miembrosNombres)).toList();

    return {
      'total': total,
      'mostradas': mostradasList.length,
      'tareas': mostradasList,
    };
  }

  static Map<String, dynamic> ejecutarResumenDelTablero({
    required List<Tarea> tareas,
    required List<String> columnasTablero,
  }) {
    final Map<String, int> conteoPorColumna = {
      for (final col in columnasTablero) col: 0,
    };

    int total = 0;
    for (final t in tareas) {
      if (t.archivada) continue;
      total++;
      for (int i = 0; i < columnasTablero.length; i++) {
        final colNombre = columnasTablero[i];
        if (KanbanUtils.correspondeAColumna(t, colNombre, columnasTablero, i)) {
          conteoPorColumna[colNombre] = (conteoPorColumna[colNombre] ?? 0) + 1;
          break;
        }
      }
    }

    return {
      'totalTareas': total,
      'porEstado': conteoPorColumna,
    };
  }

  static Map<String, dynamic> _mapearTareaParaIa(
    Tarea tarea,
    Map<String, String> miembrosNombres,
  ) {
    final String prioridadStr = switch (tarea.prioridad) {
      3 => 'alta',
      1 => 'baja',
      _ => 'media',
    };

    String? asignadoNombre;
    if (tarea.asignadosA.isNotEmpty) {
      final nombres = tarea.asignadosA
          .map((uid) => miembrosNombres[uid] ?? uid)
          .where((n) => n.isNotEmpty)
          .toList();
      if (nombres.isNotEmpty) {
        asignadoNombre = nombres.join(', ');
      }
    }

    return {
      'id': tarea.id,
      'titulo': tarea.titulo,
      'estado': tarea.estadoNombre,
      'prioridad': prioridadStr,
      'fechaVencimiento': tarea.fechaVencimiento?.toIso8601String(),
      'nombreAsignado': asignadoNombre,
    };
  }

  // ===========================================================================
  // NÚCLEO DE RESILIENCIA Y EJECUCIÓN MULTIMODELO
  // ===========================================================================

  Future<String?> _generarContenidoConModelosYReintentos({
    required String promptUsuario,
    required String promptSistema,
    required GenerationConfig Function(bool usarThinking) configuracionGeneracionBuilder,
    List<Tool>? tools,
    List<Content>? historial,
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
          configuracionGeneracion: configuracionGeneracionBuilder(usarThinking),
          tools: tools,
          historial: historial,
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

          if (clase == _ClaseErrorIa.modeloNoDisponible && !esUltimoModelo) {
            debugPrint(
              '[AsistenteIaService] Modelo $nombreModelo no disponible (404). Conmutando inmediatamente al siguiente modelo...',
            );
            ultimaCausa = error;
            if (!esUltimoIntentoGlobal) {
              onReintento?.call(intentoGlobal + 1, intentosMaximosTotales);
            }
            break;
          }

          if (clase != _ClaseErrorIa.temporal ||
              (esUltimoModelo && esUltimoIntentoDelModelo)) {
            throw AsistenteIaException(_mensajeParaClase(clase), causa: error);
          }

          ultimaCausa = error;

          if (!esUltimoIntentoGlobal) {
            onReintento?.call(intentoGlobal + 1, intentosMaximosTotales);
          }

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

  static String _formatearFechaIsoOffset(DateTime fecha) {
    final offset = fecha.timeZoneOffset;
    final horas = offset.inHours.abs().toString().padLeft(2, '0');
    final minutos = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final signo = offset.isNegative ? '-' : '+';
    return '${fecha.toIso8601String().split('.').first}$signo$horas:$minutos';
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
      tools: solicitud.tools,
    );

    if (solicitud.historial != null || (solicitud.tools != null && solicitud.tools!.isNotEmpty)) {
      final chatSession = generativeModel.startChat(
        history: solicitud.historial ?? const [],
      );
      final response = await chatSession.sendMessage(
        Content.text(solicitud.prompt),
      );
      return response.text;
    } else {
      final response = await generativeModel.generateContent([
        Content.text(solicitud.prompt),
      ]);
      return response.text;
    }
  }

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

  static String _textoDeError(Object error) => error is FirebaseAIException
      ? '${error.runtimeType} ${error.message}'
      : error.toString();

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

  static final RegExp _codigo5xx = RegExp(r'\b5\d{2}\b');
  static final RegExp _codigo403 = RegExp(r'\b403\b');
  static final RegExp _codigo404 = RegExp(r'\b404\b');
  static final RegExp _codigo429 = RegExp(r'\b429\b');

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

  static const List<String> _marcadoresCuota = <String>[
    'quota',
    'resource_exhausted',
    'resource exhausted',
    'rate limit',
    'too many requests',
  ];
}

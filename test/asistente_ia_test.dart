import 'dart:async';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kanbly/modelo/tarea_borrador.dart';
import 'package:kanbly/modelo/tarea.dart';
import 'package:kanbly/servicios/asistente_ia_service.dart';
import 'package:kanbly/controlador/asistente_ia_controller.dart';

/// Fake de IAsistenteIaService para pruebas aisladas del controlador (Ajuste 12)
class FakeAsistenteIaService implements IAsistenteIaService {
  final List<TareaBorrador> borradoresAProcesar;
  bool throwError;

  FakeAsistenteIaService({
    this.borradoresAProcesar = const [],
    this.throwError = false,
  });

  @override
  Future<List<TareaBorrador>> procesarDictadoVoz({
    required String textoTranscrito,
    required DateTime fechaActual,
    required List<String> columnas,
    required List<Map<String, String>> miembros,
    void Function(int intento, int intentosMaximos)? onReintento,
  }) async {
    if (throwError) {
      throw Exception('Error simulado en servicio Fake de IA');
    }
    return borradoresAProcesar;
  }
}

/// Fake de IAsistenteIaService que simula reintentos para probar el controlador.
class FakeAsistenteIaConReintentoSimulado implements IAsistenteIaService {
  final _completer = Completer<List<TareaBorrador>>();

  void completar() {
    if (!_completer.isCompleted) {
      _completer.complete([
        const TareaBorrador(
          id: 'borrador_1',
          titulo: 'Tarea recuperada',
          columna: 'Pendiente',
        ),
      ]);
    }
  }

  @override
  Future<List<TareaBorrador>> procesarDictadoVoz({
    required String textoTranscrito,
    required DateTime fechaActual,
    required List<String> columnas,
    required List<Map<String, String>> miembros,
    void Function(int intento, int intentosMaximos)? onReintento,
  }) async {
    onReintento?.call(2, 4);
    return _completer.future;
  }
}

/// Generador falso de respuestas de Gemini para probar los reintentos del servicio.
///
/// Cada elemento de [respuestas] se usa en el intento correspondiente: si es una
/// [Exception] el intento falla lanzándola; si es un `String` (o `null`) el
/// intento devuelve ese texto como respuesta del modelo. Al agotarse la lista se
/// repite el último elemento (útil para simular fallos constantes).
class GeneradorIaFalso {
  GeneradorIaFalso(this.respuestas)
      : assert(respuestas.isNotEmpty, 'Debe haber al menos una respuesta');

  final List<Object?> respuestas;
  final List<SolicitudIa> solicitudes = <SolicitudIa>[];
  int llamadas = 0;

  Future<String?> call(SolicitudIa solicitud) async {
    solicitudes.add(solicitud);
    final int indice =
        llamadas < respuestas.length ? llamadas : respuestas.length - 1;
    final Object? respuesta = respuestas[indice];
    llamadas++;

    if (respuesta is Exception) {
      throw respuesta;
    }
    return respuesta as String?;
  }
}

void main() {
  group('Pruebas Unitarias del Modelo TareaBorrador', () {
    test('Parsea campos válidos desde un Map', () {
      final map = {
        'titulo': 'Diseñar prototipo Figma',
        'descripcion': 'Crear las pantallas del asistente',
        'prioridad': 'alta',
        'fechaLimite': '2026-10-25T15:00:00Z',
        'columna': 'En progreso',
        'asignadoUid': 'user_123',
      };

      final borrador = TareaBorrador.fromMap(
        map,
        columnasDisponibles: ['Pendiente', 'En progreso', 'Completada'],
        miembrosUids: ['user_123', 'user_456'],
        idLocal: 'id_test_1',
      );

      expect(borrador.id, equals('id_test_1'));
      expect(borrador.titulo, equals('Diseñar prototipo Figma'));
      expect(borrador.descripcion, equals('Crear las pantallas del asistente'));
      expect(borrador.prioridad, equals(3)); // 3 = alta
      expect(borrador.prioridadTexto, equals('alta'));
      expect(borrador.columna, equals('En progreso'));
      expect(borrador.asignadoUid, equals('user_123'));
      expect(borrador.fechaLimite, isNotNull);
    });

    test('Sustituye columna inválida por la primera columna disponible (Ajuste 5)', () {
      final map = {
        'titulo': 'Tarea de prueba',
        'columna': 'ColumnaInexistente',
      };

      final borrador = TareaBorrador.fromMap(
        map,
        columnasDisponibles: ['Por Hacer', 'Haciendo', 'Hecho'],
        miembrosUids: [],
        idLocal: 'id_test_2',
      );

      expect(borrador.columna, equals('Por Hacer'));
    });

    test('Sustituye asignadoUid inválido por null (Ajuste 5)', () {
      final map = {
        'titulo': 'Tarea de prueba',
        'columna': 'Pendiente',
        'asignadoUid': 'uid_inexistente',
      };

      final borrador = TareaBorrador.fromMap(
        map,
        columnasDisponibles: ['Pendiente', 'Completada'],
        miembrosUids: ['user_valido_1', 'user_valido_2'],
        idLocal: 'id_test_3',
      );

      expect(borrador.asignadoUid, isNull);
    });

    test('copyWith permite establecer en null fechaLimite, asignadoUid y descripcion', () {
      final borradorOriginal = TareaBorrador(
        id: 'id_1',
        titulo: 'Título original',
        descripcion: 'Descripción existente',
        prioridad: 2,
        fechaLimite: DateTime(2026, 10, 25, 15, 0),
        asignadoUid: 'user_123',
        columna: 'Pendiente',
      );

      final borradorLimpio = borradorOriginal.copyWith(
        fechaLimite: null,
        limpiarFecha: true,
        asignadoUid: null,
        limpiarAsignado: true,
        descripcion: null,
        limpiarDescripcion: true,
      );

      expect(borradorLimpio.id, equals('id_1'));
      expect(borradorLimpio.titulo, equals('Título original'));
      expect(borradorLimpio.fechaLimite, isNull);
      expect(borradorLimpio.asignadoUid, isNull);
      expect(borradorLimpio.descripcion, isNull);
    });

    test('fromMap convierte fechaLimite a hora local con toLocal() cuando incluye offset -06:00', () {
      const dateStrWithOffset = '2026-10-18T15:00:00-06:00';
      final expectedLocal = DateTime.parse(dateStrWithOffset).toLocal();

      final map = {
        'titulo': 'Tarea con offset de zona horaria',
        'fechaLimite': dateStrWithOffset,
        'columna': 'Pendiente',
      };

      final borrador = TareaBorrador.fromMap(
        map,
        columnasDisponibles: ['Pendiente'],
        idLocal: 'id_offset_test',
      );

      expect(borrador.fechaLimite, isNotNull);
      expect(borrador.fechaLimite!.isUtc, isFalse);
      expect(borrador.fechaLimite, equals(expectedLocal));
    });

    test('toTarea llena exhaustivamente todos los campos del modelo Tarea (Ajuste 10)', () {
      final borrador = TareaBorrador(
        id: 'borrador_1',
        titulo: 'Revisar PRs',
        descripcion: 'Revisión de código de la rama main',
        prioridad: 3,
        fechaLimite: DateTime(2026, 10, 20, 18, 0),
        asignadoUid: 'dev_user_1',
        columna: 'En progreso',
      );

      final tarea = borrador.toTarea(
        idTareaDoc: 'tarea_doc_1',
        tableroId: 'tablero_123',
        creadorId: 'creador_456',
        orden: 1,
      );

      expect(tarea.id, equals('tarea_doc_1'));
      expect(tarea.titulo, equals('Revisar PRs'));
      expect(tarea.descripcion, equals('Revisión de código de la rama main'));
      expect(tarea.estado, equals(EstadoTarea.enProgreso));
      expect(tarea.estadoNombre, equals('En progreso'));
      expect(tarea.tableroId, equals('tablero_123'));
      expect(tarea.creadaPor, equals('creador_456'));
      expect(tarea.orden, equals(1));
      expect(tarea.prioridad, equals(3));
      expect(tarea.asignadosA, contains('dev_user_1'));
      expect(tarea.archivada, isFalse);
      expect(tarea.fechaCreacion, isNotNull);
      expect(tarea.fechaVencimiento, equals(DateTime(2026, 10, 20, 18, 0)));
    });
  });

  group('Pruebas Unitarias de AsistenteIaController con Fake Service', () {
    test('Procesa transcripción y llena borradores usando FakeAsistenteIaService', () async {
      final fakeBorradores = [
        const TareaBorrador(
          id: 'fake_1',
          titulo: 'Comprar licencias',
          columna: 'Pendiente',
        ),
      ];

      final fakeService = FakeAsistenteIaService(borradoresAProcesar: fakeBorradores);
      final controller = AsistenteIaController(iaService: fakeService);

      controller.setTranscription('Comprar licencias de software');

      final ok = await controller.procesarTranscripcionConIa(
        fechaActual: DateTime.now(),
        columnas: ['Pendiente', 'Completada'],
        miembros: [],
      );

      expect(ok, isTrue);
      expect(controller.borradores.length, equals(1));
      expect(controller.borradores.first.titulo, equals('Comprar licencias'));
      expect(controller.isLoading, isFalse);
    });

    test('Agrega, actualiza y elimina borradores manualmente', () {
      final controller = AsistenteIaController();

      // Agregar manual
      controller.agregarBorradorManual('Pendiente');
      expect(controller.borradores.length, equals(1));
      expect(controller.borradores.first.titulo, equals('Nueva tarea'));

      // Actualizar borrador
      final borradorEditado = controller.borradores.first.copyWith(
        titulo: 'Título Modificado',
        prioridad: 3,
      );
      controller.actualizarBorrador(0, borradorEditado);
      expect(controller.borradores.first.titulo, equals('Título Modificado'));
      expect(controller.borradores.first.prioridad, equals(3));

      // Eliminar borrador
      controller.eliminarBorrador(0);
      expect(controller.borradores, isEmpty);
    });

    test('Maneja errores devueltos por el servicio de IA', () async {
      final fakeService = FakeAsistenteIaService(throwError: true);
      final controller = AsistenteIaController(iaService: fakeService);

      controller.setTranscription('Dictado que fallará');

      final ok = await controller.procesarTranscripcionConIa(
        fechaActual: DateTime.now(),
        columnas: ['Pendiente'],
        miembros: [],
      );

      expect(ok, isFalse);
      expect(controller.errorMessage, contains('Error simulado en servicio Fake de IA'));
      expect(controller.isLoading, isFalse);
    });

    test('Actualiza mensajeCarga durante reintentos del servicio', () async {
      final fakeService = FakeAsistenteIaConReintentoSimulado();
      final controller = AsistenteIaController(iaService: fakeService);

      controller.setTranscription('Dictado para probar reintento');

      final futuro = controller.procesarTranscripcionConIa(
        fechaActual: DateTime.now(),
        columnas: ['Pendiente'],
        miembros: [],
      );

      expect(
        controller.mensajeCarga,
        equals('El servicio está ocupado, reintentando (2/4)...'),
      );

      fakeService.completar();
      final ok = await futuro;

      expect(ok, isTrue);
      expect(controller.borradores.length, equals(1));
    });
  });

  group('Reintentos automáticos, timeouts y callbacks de AsistenteIaService', () {
    /// Ejecuta el dictado con datos fijos para simplificar cada prueba.
    Future<List<TareaBorrador>> procesar(
      AsistenteIaService servicio, {
      void Function(int, int)? onReintento,
    }) =>
        servicio.procesarDictadoVoz(
          textoTranscrito: 'Enviar el reporte mañana',
          fechaActual: DateTime(2026, 10, 17, 9, 30),
          columnas: const ['Pendiente', 'Completada'],
          miembros: const [],
          onReintento: onReintento,
        );

    /// Ejecuta la acción y devuelve el error capturado (o null si no hubo error).
    Future<Object?> capturarError(Future<void> Function() accion) async {
      try {
        await accion();
        return null;
      } catch (error) {
        return error;
      }
    }

    test('No reintenta ni espera cuando la primera llamada tiene éxito', () async {
      final generador = GeneradorIaFalso(<Object?>[
        '{"tareas":[{"titulo":"Enviar reporte","columna":"Pendiente"}]}',
      ]);
      final esperas = <Duration>[];
      final servicio = AsistenteIaService(
        generarContenido: generador.call,
        esperar: (duracion) async {
          esperas.add(duracion);
        },
      );

      final borradores = await procesar(servicio);

      expect(generador.llamadas, equals(1));
      expect(esperas, isEmpty);
      expect(borradores.single.titulo, equals('Enviar reporte'));
      expect(
        generador.solicitudes.single.prompt,
        contains('Enviar el reporte mañana'),
      );
      expect(
        generador.solicitudes.single.instruccionSistema,
        contains('Kanban'),
      );
    });

    test('Reintenta con esperas crecientes (2 s y 5 s) e invoca onReintento',
        () async {
      final generador = GeneradorIaFalso(<Object?>[
        FirebaseAIException(
            'Server Error [503]: {"error":{"code":503,"status":"UNAVAILABLE","message":"The model is overloaded. Please try again later."}}'),
        FirebaseAIException(
            'Server Error [500]: {"error":{"code":500,"message":"Internal error encountered."}}'),
        '{"tareas":[{"titulo":"Enviar reporte","prioridad":"alta","columna":"Pendiente"}]}',
      ]);
      final esperas = <Duration>[];
      final reintentosNotificados = <String>[];

      final servicio = AsistenteIaService(
        generarContenido: generador.call,
        esperar: (duracion) async {
          esperas.add(duracion);
        },
      );

      final borradores = await procesar(
        servicio,
        onReintento: (intento, max) {
          reintentosNotificados.add('$intento/$max');
        },
      );

      expect(generador.llamadas, equals(3)); // falla 2 veces y acierta a la tercera
      expect(
        esperas,
        equals(const [Duration(seconds: 2), Duration(seconds: 5)]),
      );
      expect(reintentosNotificados, equals(const ['2/4', '3/4']));
      expect(borradores, hasLength(1));
      expect(borradores.single.titulo, equals('Enviar reporte'));
      expect(borradores.single.prioridad, equals(3)); // alta
    });

    test('Agota los 3 reintentos y lanza mensaje de servicio ocupado sin códigos',
        () async {
      final generador = GeneradorIaFalso(<Object?>[
        FirebaseAIException('The service is currently unavailable.'),
      ]); // siempre falla
      final esperas = <Duration>[];
      final servicio = AsistenteIaService(
        generarContenido: generador.call,
        esperar: (duracion) async {
          esperas.add(duracion);
        },
      );

      final error = await capturarError(() => procesar(servicio));

      expect(error, isA<AsistenteIaException>());
      final excepcion = error! as AsistenteIaException;
      expect(
        excepcion.mensaje,
        equals('El servicio de IA está ocupado. Intenta de nuevo en un momento.'),
      );
      // Nunca se filtra JSON crudo ni códigos al usuario.
      expect(excepcion.toString(), isNot(contains('503')));
      expect(excepcion.toString(), isNot(contains('{')));
      // La causa técnica se conserva para diagnóstico.
      expect(excepcion.causa, isNotNull);
      expect(generador.llamadas, equals(4)); // intento inicial + 3 reintentos
      expect(
        esperas,
        equals(const [
          Duration(seconds: 2),
          Duration(seconds: 5),
          Duration(seconds: 10),
        ]),
      );
    });

    test('Un timeout por intento (Future.timeout) se reintenta igual que un error 500',
        () async {
      final esperas = <Duration>[];
      final reintentosNotificados = <String>[];

      final servicio = AsistenteIaService(
        esperasReintento: const [Duration.zero],
        timeoutPorIntento: const Duration(milliseconds: 20),
        generarContenido: (solicitud) async {
          // Simular llamada lenta que excede el timeout por intento
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return '{"tareas":[{"titulo":"Tarea tardía","columna":"Pendiente"}]}';
        },
        esperar: (duracion) async {
          esperas.add(duracion);
        },
      );

      final error = await capturarError(
        () => procesar(
          servicio,
          onReintento: (intento, max) {
            reintentosNotificados.add('$intento/$max');
          },
        ),
      );

      expect(error, isA<AsistenteIaException>());
      expect(
        (error! as AsistenteIaException).mensaje,
        equals(MensajesAsistenteIa.servicioOcupado),
      );
      expect(esperas, equals(const [Duration.zero]));
      expect(reintentosNotificados, equals(const ['2/2']));
    });

    test('Un error 404 de modelo no disponible no se reintenta', () async {
      final generador = GeneradorIaFalso(<Object?>[
        ServerException(
            'models/gemini-3.8-flash is not found for API version v1beta, or is not supported for generateContent. Call ListModels to see the list of available models and their supported methods.'),
      ]);
      final esperas = <Duration>[];
      final servicio = AsistenteIaService(
        generarContenido: generador.call,
        esperar: (duracion) async {
          esperas.add(duracion);
        },
      );

      final error = await capturarError(() => procesar(servicio));

      expect(error, isA<AsistenteIaException>());
      final excepcion = error! as AsistenteIaException;
      expect(excepcion.mensaje, equals(MensajesAsistenteIa.modeloNoDisponible));
      expect(excepcion.toString(), isNot(contains('ListModels')));
      expect(generador.llamadas, equals(1));
      expect(esperas, isEmpty);
    });

    test('Un error 403 de API no habilitada no se reintenta', () async {
      final generador = GeneradorIaFalso(<Object?>[
        ServiceApiNotEnabled('projects/demo-kanbly'),
      ]);
      final esperas = <Duration>[];
      final servicio = AsistenteIaService(
        generarContenido: generador.call,
        esperar: (duracion) async {
          esperas.add(duracion);
        },
      );

      final error = await capturarError(() => procesar(servicio));

      expect(error, isA<AsistenteIaException>());
      final excepcion = error! as AsistenteIaException;
      expect(excepcion.mensaje, equals(MensajesAsistenteIa.apiNoHabilitada));
      expect(excepcion.toString(), isNot(contains('googleapis')));
      expect(generador.llamadas, equals(1));
      expect(esperas, isEmpty);
    });

    test('Un fallo de conexión no se reintenta y avisa al usuario', () async {
      final generador = GeneradorIaFalso(<Object?>[
        http.ClientException(
            'Failed host lookup: firebasevertexai.googleapis.com'),
      ]);
      final esperas = <Duration>[];
      final servicio = AsistenteIaService(
        generarContenido: generador.call,
        esperar: (duracion) async {
          esperas.add(duracion);
        },
      );

      final error = await capturarError(() => procesar(servicio));

      expect(error, isA<AsistenteIaException>());
      final excepcion = error! as AsistenteIaException;
      expect(excepcion.mensaje, equals(MensajesAsistenteIa.sinConexion));
      expect(generador.llamadas, equals(1));
      expect(esperas, isEmpty);
    });

    test('Una respuesta con JSON inválido no se reintenta', () async {
      final generador = GeneradorIaFalso(<Object?>['esto no es JSON']);
      final esperas = <Duration>[];
      final servicio = AsistenteIaService(
        generarContenido: generador.call,
        esperar: (duracion) async {
          esperas.add(duracion);
        },
      );

      final error = await capturarError(() => procesar(servicio));

      expect(error, isA<AsistenteIaException>());
      final excepcion = error! as AsistenteIaException;
      expect(excepcion.mensaje, equals(MensajesAsistenteIa.respuestaInvalida));
      expect(generador.llamadas, equals(1));
      expect(esperas, isEmpty);
    });

    test('Los tiempos de espera son inyectables desde el constructor', () async {
      final generador = GeneradorIaFalso(<Object?>[
        FirebaseAIException('The service is currently unavailable.'),
      ]); // siempre falla
      final esperas = <Duration>[];
      final servicio = AsistenteIaService(
        esperasReintento: const [Duration.zero], // 1 solo reintento, sin esperar
        generarContenido: generador.call,
        esperar: (duracion) async {
          esperas.add(duracion);
        },
      );

      final error = await capturarError(() => procesar(servicio));

      expect(error, isA<AsistenteIaException>());
      expect(
        (error! as AsistenteIaException).mensaje,
        equals(MensajesAsistenteIa.servicioOcupado),
      );
      expect(generador.llamadas, equals(2)); // intento inicial + 1 reintento
      expect(esperas, equals(const [Duration.zero]));
    });

    test('Con esperas en cero se prueba el reintento sin esperar de verdad (temporizador real)',
        () async {
      final generador = GeneradorIaFalso(<Object?>[
        FirebaseAIException(
            'The model is experiencing high demand. Please try again later.'),
        '{"tareas":[{"titulo":"Tarea recuperada","columna":"Pendiente"}]}',
      ]);
      // Sin inyectar `esperar`: se usa Future.delayed, pero con Duration.zero.
      final servicio = AsistenteIaService(
        esperasReintento: const [Duration.zero],
        generarContenido: generador.call,
      );

      final borradores = await procesar(servicio);

      expect(generador.llamadas, equals(2));
      expect(borradores.single.titulo, equals('Tarea recuperada'));
    });
  });
}

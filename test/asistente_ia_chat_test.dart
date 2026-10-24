import 'package:flutter_test/flutter_test.dart';
import 'package:kanbly/modelo/chat_mensaje.dart';
import 'package:kanbly/modelo/tablero.dart';
import 'package:kanbly/modelo/tarea.dart';
import 'package:kanbly/servicios/asistente_ia_service.dart';
import 'package:kanbly/controlador/asistente_ia_chat_controller.dart';

/// Fake de [IAsistenteIaChatService] para probar [AsistenteIaChatController]
class FakeAsistenteIaChatService implements IAsistenteIaChatService {
  String respuestaSimulada;
  bool throwError;
  String? ultimoMensajeRecibido;
  List<ChatMensaje>? ultimoHistorialRecibido;
  String? ultimoUsuarioUidRecibido;
  String? ultimoUsuarioNombreRecibido;
  String? ultimoUsuarioRolRecibido;

  FakeAsistenteIaChatService({
    this.respuestaSimulada = 'Respuesta simulada del asistente de IA.',
    this.throwError = false,
  });

  @override
  Future<String> enviarMensajeChat({
    required String mensajeUsuario,
    required List<ChatMensaje> historial,
    required Tablero tablero,
    required List<Tarea> tareasTablero,
    required Map<String, String> miembrosNombres,
    required DateTime fechaActual,
    String? usuarioUid,
    String? usuarioNombre,
    String? usuarioRol,
    void Function(int intento, int intentosMaximos)? onReintento,
  }) async {
    ultimoMensajeRecibido = mensajeUsuario;
    ultimoHistorialRecibido = historial;
    ultimoUsuarioUidRecibido = usuarioUid;
    ultimoUsuarioNombreRecibido = usuarioNombre;
    ultimoUsuarioRolRecibido = usuarioRol;
    if (throwError) {
      throw AsistenteIaException(MensajesAsistenteIa.servicioOcupado);
    }
    return respuestaSimulada;
  }
}

/// Fake de [IAsistenteIaChatService] que lanza una excepción con [causa] para probar debug mode
class FakeAsistenteIaChatServiceConCausa implements IAsistenteIaChatService {
  final Object causaError;

  FakeAsistenteIaChatServiceConCausa({required this.causaError});

  @override
  Future<String> enviarMensajeChat({
    required String mensajeUsuario,
    required List<ChatMensaje> historial,
    required Tablero tablero,
    required List<Tarea> tareasTablero,
    required Map<String, String> miembrosNombres,
    required DateTime fechaActual,
    String? usuarioUid,
    String? usuarioNombre,
    String? usuarioRol,
    void Function(int intento, int intentosMaximos)? onReintento,
  }) async {
    throw AsistenteIaException('El servicio está ocupado', causa: causaError);
  }
}

void main() {
  final fechaReferencia = DateTime(2026, 10, 20, 10, 0);

  final tableroPrueba = Tablero(
    id: 'tablero_1',
    nombre: 'Tablero Proyecto Kanbly',
    esGrupal: true,
    creadorId: 'user_creador',
    miembrosIds: const ['user_creador', 'user_dev1', 'user_dev2'],
    fechaCreacion: DateTime(2026, 1, 1),
    columnas: const ['Pendiente', 'En progreso', 'Completada'],
  );

  final Map<String, String> miembrosMap = {
    'user_creador': 'Uriel Admin',
    'user_dev1': 'Carlos Programador',
    'user_dev2': 'Ana Diseñadora',
  };

  group('Pruebas de Construcción del Contexto JSON Compacto para el Chatbot', () {
    test('construirContextoTablero compila resumen con conteos por columna iguales al tablero y totales correctos', () {
      final tareas = [
        Tarea(
          id: 't1',
          titulo: 'Tarea Pendiente',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
        ),
        Tarea(
          id: 't2',
          titulo: 'Tarea En Progreso',
          estado: EstadoTarea.enProgreso,
          estadoNombre: 'En progreso',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
        ),
        Tarea(
          id: 't3',
          titulo: 'Tarea Completada',
          estado: EstadoTarea.completada,
          estadoNombre: 'Completada',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
        ),
      ];

      final contexto = AsistenteIaService.construirContextoTablero(
        tablero: tableroPrueba,
        tareasTablero: tareas,
        miembrosNombres: miembrosMap,
        fechaActual: fechaReferencia,
      );

      expect(contexto.containsKey('resumen'), isTrue);
      expect(contexto.containsKey('tareasVencidas'), isTrue);
      expect(contexto.containsKey('tareasPorVencer'), isTrue);
      expect(contexto.containsKey('listaTareas'), isTrue);

      final resumen = contexto['resumen'] as Map<String, dynamic>;
      expect(resumen['totalTareas'], equals(3));
      final porEstado = Map<String, int>.from(resumen['porEstado']);
      expect(porEstado['Pendiente'], equals(1));
      expect(porEstado['En progreso'], equals(1));
      expect(porEstado['Completada'], equals(1));
    });

    test('construirContextoTablero limita listaTareas a máximo 100 y reporta total y mostradas', () {
      final List<Tarea> tareas120 = List.generate(120, (index) {
        return Tarea(
          id: 'tarea_$index',
          titulo: 'Tarea $index',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
        );
      });

      final contexto = AsistenteIaService.construirContextoTablero(
        tablero: tableroPrueba,
        tareasTablero: tareas120,
        miembrosNombres: miembrosMap,
        fechaActual: fechaReferencia,
      );

      final listaTareasMap = contexto['listaTareas'] as Map<String, dynamic>;
      expect(listaTareasMap['total'], equals(120));
      expect(listaTareasMap['mostradas'], equals(100));

      final tareas = listaTareasMap['tareas'] as List<dynamic>;
      expect(tareas.length, equals(100));
    });

    test('listaTareas incluye sólo los campos titulo, estado, prioridad, fechaVencimiento y nombreAsignado', () {
      final tareas = [
        Tarea(
          id: 't1',
          titulo: 'Tarea de Inspección',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          prioridad: 3,
          fechaVencimiento: fechaReferencia.add(const Duration(days: 2)),
          asignadosA: const ['user_dev1'],
        ),
      ];

      final contexto = AsistenteIaService.construirContextoTablero(
        tablero: tableroPrueba,
        tareasTablero: tareas,
        miembrosNombres: miembrosMap,
        fechaActual: fechaReferencia,
      );

      final listaTareasMap = contexto['listaTareas'] as Map<String, dynamic>;
      final primeraTarea = (listaTareasMap['tareas'] as List<dynamic>).first as Map<String, dynamic>;

      expect(primeraTarea.keys.toSet(), equals({
        'titulo',
        'estado',
        'prioridad',
        'fechaVencimiento',
        'nombreAsignado',
      }));
      expect(primeraTarea['titulo'], equals('Tarea de Inspección'));
      expect(primeraTarea['estado'], equals('Pendiente'));
      expect(primeraTarea['prioridad'], equals('alta'));
      expect(primeraTarea['nombreAsignado'], equals('Carlos Programador'));
      expect(primeraTarea.containsKey('id'), isFalse);
      expect(primeraTarea.containsKey('comentarios'), isFalse);
    });

    test('listaTareas ordena estrictamente: 1. Vencidas, 2. Por vencer (en 7 días), 3. El resto', () {
      final tareas = [
        Tarea(
          id: 't_normal',
          titulo: 'Tarea Sin Fecha',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
        ),
        Tarea(
          id: 't_por_vencer',
          titulo: 'Tarea Próxima a Vencer',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          fechaVencimiento: fechaReferencia.add(const Duration(days: 3)),
        ),
        Tarea(
          id: 't_vencida',
          titulo: 'Tarea Atrasada',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          fechaVencimiento: fechaReferencia.subtract(const Duration(days: 2)),
        ),
      ];

      final contexto = AsistenteIaService.construirContextoTablero(
        tablero: tableroPrueba,
        tareasTablero: tareas,
        miembrosNombres: miembrosMap,
        fechaActual: fechaReferencia,
      );

      final listaTareas = (contexto['listaTareas'] as Map<String, dynamic>)['tareas'] as List<dynamic>;

      expect(listaTareas[0]['titulo'], equals('Tarea Atrasada'));
      expect(listaTareas[1]['titulo'], equals('Tarea Próxima a Vencer'));
      expect(listaTareas[2]['titulo'], equals('Tarea Sin Fecha'));
    });
  });

  group('Pruebas de Funciones de Consulta de Solo Lectura', () {
    test('ejecutarTareasPorEstado filtra por columna, reporta total/mostradas y limita a máximo 20 resultados', () {
      final List<Tarea> tareas25 = List.generate(25, (index) {
        return Tarea(
          id: 'tarea_$index',
          titulo: 'Tarea Pendiente $index',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          prioridad: 3,
          asignadosA: const ['user_dev1'],
        );
      });

      final resultado = AsistenteIaService.ejecutarTareasPorEstado(
        tareas: tareas25,
        miembrosNombres: miembrosMap,
        estado: 'Pendiente',
      );

      expect(resultado['total'], equals(25));
      expect(resultado['mostradas'], equals(20));

      final tareas = resultado['tareas'] as List<Map<String, dynamic>>;
      expect(tareas.length, equals(20));

      final primera = tareas.first;
      expect(primera['id'], equals('tarea_0'));
      expect(primera['titulo'], equals('Tarea Pendiente 0'));
      expect(primera['estado'], equals('Pendiente'));
      expect(primera['prioridad'], equals('alta'));
      expect(primera['nombreAsignado'], equals('Carlos Programador'));
      expect(primera.containsKey('comentarios'), isFalse);
      expect(primera.containsKey('adjuntos'), isFalse);
    });

    test('ejecutarTareasDeIntegrante filtra por UID o nombre asignado', () {
      final tareas = [
        Tarea(
          id: 't1',
          titulo: 'Tarea de Carlos',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          asignadosA: const ['user_dev1'],
        ),
        Tarea(
          id: 't2',
          titulo: 'Tarea de Ana',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          asignadosA: const ['user_dev2'],
        ),
      ];

      final resultadoCarlos = AsistenteIaService.ejecutarTareasDeIntegrante(
        tareas: tareas,
        miembrosNombres: miembrosMap,
        integrante: 'carlos',
      );

      expect(resultadoCarlos['total'], equals(1));
      expect(resultadoCarlos['mostradas'], equals(1));
      final tareasCarlos = resultadoCarlos['tareas'] as List<Map<String, dynamic>>;
      expect(tareasCarlos.length, equals(1));
      expect(tareasCarlos.first['id'], equals('t1'));

      final resultadoUid = AsistenteIaService.ejecutarTareasDeIntegrante(
        tareas: tareas,
        miembrosNombres: miembrosMap,
        integrante: 'user_dev2',
      );

      expect(resultadoUid['total'], equals(1));
      final tareasUid = resultadoUid['tareas'] as List<Map<String, dynamic>>;
      expect(tareasUid.length, equals(1));
      expect(tareasUid.first['id'], equals('t2'));
    });

    test('ejecutarTareasPorVencer identifica tareas próximas a vencer en N días', () {
      final tareas = [
        Tarea(
          id: 't1',
          titulo: 'Vence en 3 días',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          fechaVencimiento: fechaReferencia.add(const Duration(days: 3)),
        ),
        Tarea(
          id: 't2',
          titulo: 'Vence en 15 días',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          fechaVencimiento: fechaReferencia.add(const Duration(days: 15)),
        ),
      ];

      final resultado = AsistenteIaService.ejecutarTareasPorVencer(
        tareas: tareas,
        miembrosNombres: miembrosMap,
        fechaActual: fechaReferencia,
        dias: 7,
      );

      expect(resultado['total'], equals(1));
      final tareasList = resultado['tareas'] as List<Map<String, dynamic>>;
      expect(tareasList.length, equals(1));
      expect(tareasList.first['id'], equals('t1'));
    });

    test('ejecutarTareasVencidas identifica tareas vencidas no completadas', () {
      final tareas = [
        Tarea(
          id: 't_vencida_pendiente',
          titulo: 'Atrasada y no hecha',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          fechaVencimiento: fechaReferencia.subtract(const Duration(days: 2)),
        ),
        Tarea(
          id: 't_vencida_completada',
          titulo: 'Atrasada pero completada',
          estado: EstadoTarea.completada,
          estadoNombre: 'Completada',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          fechaVencimiento: fechaReferencia.subtract(const Duration(days: 2)),
        ),
      ];

      final resultado = AsistenteIaService.ejecutarTareasVencidas(
        tareas: tareas,
        miembrosNombres: miembrosMap,
        fechaActual: fechaReferencia,
      );

      expect(resultado['total'], equals(1));
      final tareasList = resultado['tareas'] as List<Map<String, dynamic>>;
      expect(tareasList.length, equals(1));
      expect(tareasList.first['id'], equals('t_vencida_pendiente'));
    });

    test('ejecutarResumenDelTablero ante tablero sin tareas devuelve conteos en cero', () {
      final resultado = AsistenteIaService.ejecutarResumenDelTablero(
        tareas: const [],
        columnasTablero: const ['Pendiente', 'En progreso', 'Completada'],
      );

      expect(resultado['totalTareas'], equals(0));
      final Map<String, int> porEstado = Map<String, int>.from(resultado['porEstado']);
      expect(porEstado['Pendiente'], equals(0));
      expect(porEstado['En progreso'], equals(0));
      expect(porEstado['Completada'], equals(0));
    });

    test('Los sinónimos de columna y conteo de completadas coinciden con la lógica del tablero', () {
      final columnasPersonalizadas = ['Por Hacer', 'Haciendo', 'Hecho'];

      final tareas = [
        Tarea(
          id: 't1',
          titulo: 'Tarea Pendiente',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
        ),
        Tarea(
          id: 't2',
          titulo: 'Tarea Por Hacer',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Por Hacer',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
        ),
        Tarea(
          id: 't3',
          titulo: 'Tarea Terminada',
          estado: EstadoTarea.completada,
          estadoNombre: 'Hecho',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          fechaVencimiento: fechaReferencia.subtract(const Duration(days: 1)),
        ),
      ];

      final resEstado = AsistenteIaService.ejecutarTareasPorEstado(
        tareas: tareas,
        miembrosNombres: miembrosMap,
        estado: 'Por Hacer',
        columnasTablero: columnasPersonalizadas,
      );

      expect(resEstado['total'], equals(2));

      final resResumen = AsistenteIaService.ejecutarResumenDelTablero(
        tareas: tareas,
        columnasTablero: columnasPersonalizadas,
      );

      expect(resResumen['totalTareas'], equals(3));
      final porEstado = Map<String, int>.from(resResumen['porEstado']);
      expect(porEstado['Por Hacer'], equals(2));
      expect(porEstado['Haciendo'], equals(0));
      expect(porEstado['Hecho'], equals(1));

      final resVencidas = AsistenteIaService.ejecutarTareasVencidas(
        tareas: tareas,
        miembrosNombres: miembrosMap,
        fechaActual: fechaReferencia,
        columnasTablero: columnasPersonalizadas,
      );

      expect(resVencidas['total'], equals(0));
    });
  });

  group('Pruebas del Controlador de Chatbot (AsistenteIaChatController)', () {
    test('Envía mensaje del usuario y guarda la respuesta de la IA en el historial', () async {
      final fakeService = FakeAsistenteIaChatService(
        respuestaSimulada: 'Tienes 3 tareas pendientes en el tablero.',
      );

      final controller = AsistenteIaChatController(chatService: fakeService);

      final ok = await controller.enviarMensaje(
        texto: '¿Cuáles son mis tareas?',
        tablero: tableroPrueba,
        tareasTablero: const [],
        miembrosNombres: miembrosMap,
        fechaActual: fechaReferencia,
      );

      expect(ok, isTrue);
      expect(controller.historial.length, equals(2));
      expect(controller.historial[0].rol, equals(RolMensaje.usuario));
      expect(controller.historial[0].texto, equals('¿Cuáles son mis tareas?'));
      expect(controller.historial[1].rol, equals(RolMensaje.asistente));
      expect(controller.historial[1].texto, equals('Tienes 3 tareas pendientes en el tablero.'));
    });

    test('El historial enviado a la IA no contiene el mensaje actual ni errores', () async {
      final fakeService = FakeAsistenteIaChatService();
      final controller = AsistenteIaChatController(chatService: fakeService);

      // 1. Primer intercambio exitoso
      await controller.enviarMensaje(
        texto: 'Consulta 1',
        tablero: tableroPrueba,
        tareasTablero: const [],
        miembrosNombres: miembrosMap,
      );

      // 2. Falla simulada para generar un mensaje con esError == true
      fakeService.throwError = true;
      await controller.enviarMensaje(
        texto: 'Consulta con error',
        tablero: tableroPrueba,
        tareasTablero: const [],
        miembrosNombres: miembrosMap,
      );

      // 3. Tercera consulta válida
      fakeService.throwError = false;
      const nuevaConsulta = 'Consulta 3 válida';
      await controller.enviarMensaje(
        texto: nuevaConsulta,
        tablero: tableroPrueba,
        tareasTablero: const [],
        miembrosNombres: miembrosMap,
      );

      final historialEnviado = fakeService.ultimoHistorialRecibido;
      expect(historialEnviado, isNotNull);

      // NO contiene la consulta actual
      final contieneActual = historialEnviado!.any((m) => m.texto == nuevaConsulta);
      expect(contieneActual, isFalse);

      // NO contiene mensajes de error
      final contieneError = historialEnviado.any((m) => m.esError);
      expect(contieneError, isFalse);

      // Contiene solo el primer par válido (Consulta 1, Respuesta)
      expect(historialEnviado.length, equals(2));
      expect(historialEnviado[0].texto, equals('Consulta 1'));
      expect(historialEnviado[0].rol, equals(RolMensaje.usuario));
      expect(historialEnviado[1].rol, equals(RolMensaje.asistente));
    });

    test('El historial enviado se limita a máximo 10 mensajes y empieza con rol usuario tras 7 o más turnos', () async {
      final fakeService = FakeAsistenteIaChatService();
      final controller = AsistenteIaChatController(chatService: fakeService);

      // Enviar 8 turnos completos (16 mensajes en total)
      for (int i = 1; i <= 8; i++) {
        await controller.enviarMensaje(
          texto: 'Pregunta $i',
          tablero: tableroPrueba,
          tareasTablero: const [],
          miembrosNombres: miembrosMap,
        );
      }

      // Enviar el turno 9
      await controller.enviarMensaje(
        texto: 'Pregunta 9',
        tablero: tableroPrueba,
        tareasTablero: const [],
        miembrosNombres: miembrosMap,
      );

      final historialEnviado = fakeService.ultimoHistorialRecibido!;

      // 1. Longitud máxima de 10 mensajes (5 parejas completas)
      expect(historialEnviado.length, equals(10));

      // 2. Empieza strictly con rol usuario
      expect(historialEnviado.first.rol, equals(RolMensaje.usuario));

      // 3. Alterna usuario/asistente
      for (int i = 0; i < historialEnviado.length; i++) {
        final rolEsperado = i % 2 == 0 ? RolMensaje.usuario : RolMensaje.asistente;
        expect(historialEnviado[i].rol, equals(rolEsperado));
      }

      // 4. NO contiene la pregunta actual
      expect(historialEnviado.any((m) => m.texto == 'Pregunta 9'), isFalse);
    });

    test('Limita el historial en memoria a los últimos 10 mensajes', () async {
      final fakeService = FakeAsistenteIaChatService();
      final controller = AsistenteIaChatController(chatService: fakeService);

      // Enviar 7 mensajes (7 mensajes del usuario + 7 respuestas de IA = 14 mensajes)
      for (int i = 1; i <= 7; i++) {
        await controller.enviarMensaje(
          texto: 'Mensaje $i',
          tablero: tableroPrueba,
          tareasTablero: const [],
          miembrosNombres: miembrosMap,
          fechaActual: fechaReferencia,
        );
      }

      // Debe haber exactamente 10 mensajes en memoria
      expect(controller.historial.length, equals(10));
      expect(controller.historial.last.rol, equals(RolMensaje.asistente));
    });

    test('Maneja errores lanzados por el modelo de IA mostrando mensaje descriptivo', () async {
      final fakeService = FakeAsistenteIaChatService(throwError: true);
      final controller = AsistenteIaChatController(chatService: fakeService);

      final ok = await controller.enviarMensaje(
        texto: 'Consulta que fallará',
        tablero: tableroPrueba,
        tareasTablero: const [],
        miembrosNombres: miembrosMap,
        fechaActual: fechaReferencia,
      );

      expect(ok, isFalse);
      expect(controller.errorMessage, equals(MensajesAsistenteIa.servicioOcupado));
      expect(controller.historial.last.esError, isTrue);
    });

    test('En modo debug incluye la causa técnica recortada a máximo 300 caracteres', () async {
      final causaLarga = 'A' * 400; // Causa de 400 caracteres
      final fakeService = FakeAsistenteIaChatServiceConCausa(
        causaError: causaLarga,
      );

      final controller = AsistenteIaChatController(chatService: fakeService);

      final ok = await controller.enviarMensaje(
        texto: 'Probar causa debug',
        tablero: tableroPrueba,
        tareasTablero: const [],
        miembrosNombres: miembrosMap,
      );

      expect(ok, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('Detalle técnico:'));

      final parteTecnica = controller.errorMessage!.split('Detalle técnico: ')[1];
      expect(parteTecnica.length, equals(300));
    });

    test('Limpiar historial vacía los mensajes almacenados en memoria', () async {
      final fakeService = FakeAsistenteIaChatService();
      final controller = AsistenteIaChatController(chatService: fakeService);

      await controller.enviarMensaje(
        texto: 'Prueba',
        tablero: tableroPrueba,
        tareasTablero: const [],
        miembrosNombres: miembrosMap,
      );

      expect(controller.historial, isNotEmpty);
      controller.limpiarHistorial();
      expect(controller.historial, isEmpty);
    });
  });

  group('Pruebas de Validación de Permisos de Visualización del Tablero', () {
    test('Permite acceso a creadores y miembros registrados del tablero', () {
      const uidCreador = 'user_creador';
      const uidMiembro = 'user_dev1';
      const uidAjeno = 'user_desconocido';

      final bool creadorPuedeVer = tableroPrueba.creadorId == uidCreador ||
          tableroPrueba.miembrosIds.contains(uidCreador);
      final bool miembroPuedeVer = tableroPrueba.creadorId == uidMiembro ||
          tableroPrueba.miembrosIds.contains(uidMiembro);
      final bool ajenoPuedeVer = tableroPrueba.creadorId == uidAjeno ||
          tableroPrueba.miembrosIds.contains(uidAjeno);

      expect(creadorPuedeVer, isTrue);
      expect(miembroPuedeVer, isTrue);
      expect(ajenoPuedeVer, isFalse);
    });
  });

  group('Pruebas de Mejoras de Fase 2 (Identidad, Formato Texto Plano y misTareas)', () {
    test('ejecutarMisTareas filtra únicamente las tareas asignadas al UID especificado y respeta el tope de 100', () {
      final tareas = [
        Tarea(
          id: 't1',
          titulo: 'Tarea de Uriel Creador',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          asignadosA: const ['user_creador'],
        ),
        Tarea(
          id: 't2',
          titulo: 'Tarea Compartida',
          estado: EstadoTarea.enProgreso,
          estadoNombre: 'En progreso',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          asignadosA: const ['user_creador', 'user_dev1'],
        ),
        Tarea(
          id: 't3',
          titulo: 'Tarea de Carlos Dev',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          asignadosA: const ['user_dev1'],
        ),
      ];

      final misTareasCreador = AsistenteIaService.ejecutarMisTareas(
        tareas: tareas,
        miembrosNombres: miembrosMap,
        usuarioUid: 'user_creador',
      );

      expect(misTareasCreador['total'], equals(2));
      expect(misTareasCreador['mostradas'], equals(2));
      final listaMisTareas = misTareasCreador['tareas'] as List<dynamic>;
      expect(listaMisTareas.length, equals(2));
      expect(listaMisTareas[0]['titulo'], equals('Tarea de Uriel Creador'));
      expect(listaMisTareas[1]['titulo'], equals('Tarea Compartida'));

      final misTareasCarlos = AsistenteIaService.ejecutarMisTareas(
        tareas: tareas,
        miembrosNombres: miembrosMap,
        usuarioUid: 'user_dev1',
      );

      expect(misTareasCarlos['total'], equals(2));

      final misTareasInexistente = AsistenteIaService.ejecutarMisTareas(
        tareas: tareas,
        miembrosNombres: miembrosMap,
        usuarioUid: 'user_desconocido',
      );

      expect(misTareasInexistente['total'], equals(0));
      expect(misTareasInexistente['mostradas'], equals(0));
    });

    test('construirContextoTablero incluye el bloque misTareas filtrado por UID', () {
      final tareas = [
        Tarea(
          id: 't1',
          titulo: 'Tarea Asignada a Carlos',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          asignadosA: const ['user_dev1'],
        ),
      ];

      final contexto = AsistenteIaService.construirContextoTablero(
        tablero: tableroPrueba,
        tareasTablero: tareas,
        miembrosNombres: miembrosMap,
        fechaActual: fechaReferencia,
        usuarioUid: 'user_dev1',
      );

      expect(contexto.containsKey('misTareas'), isTrue);
      final misTareasMap = contexto['misTareas'] as Map<String, dynamic>;
      expect(misTareasMap['total'], equals(1));
      expect(misTareasMap['mostradas'], equals(1));
      final tareasList = misTareasMap['tareas'] as List<dynamic>;
      expect(tareasList.first['titulo'], equals('Tarea Asignada a Carlos'));
    });

    test('limpiarMarkdownRespuesta quita ** y * y # pero conserva "- "', () {
      const respuestaRaw = '''
**Resumen de mis tareas:**
# Tareas pendientes
- **Tarea 1** (*Pendiente*, prioridad alta, vence 25/10 03:00 pm)
- Tarea 2 (En progreso, prioridad media)
''';

      final limpia = AsistenteIaService.limpiarMarkdownRespuesta(respuestaRaw);

      expect(limpia.contains('**'), isFalse);
      expect(limpia.contains('*'), isFalse);
      expect(limpia.contains('#'), isFalse);
      expect(limpia.contains('- Tarea 1 (Pendiente, prioridad alta, vence 25/10 03:00 pm)'), isTrue);
      expect(limpia.contains('- Tarea 2 (En progreso, prioridad media)'), isTrue);
    });

    test('enviarMensajeChat incluye nombre, uid y rol en el system prompt y la instrucción de consultas de cuenta', () async {
      SolicitudIa? solicitudCapturada;

      final servicioPrueba = AsistenteIaService(
        generarContenido: (solicitud) async {
          solicitudCapturada = solicitud;
          return '- Tarea de prueba (Pendiente, media, vence 20/10 10:00 am)';
        },
      );

      await servicioPrueba.enviarMensajeChat(
        mensajeUsuario: '¿Cuáles son mis tareas?',
        historial: [],
        tablero: tableroPrueba,
        tareasTablero: [],
        miembrosNombres: miembrosMap,
        fechaActual: fechaReferencia,
        usuarioUid: 'user_creador',
        usuarioNombre: 'Uriel Admin',
        usuarioRol: 'creador',
      );

      expect(solicitudCapturada, isNotNull);
      final prompt = solicitudCapturada!.instruccionSistema;

      expect(
        prompt,
        contains(
          "El usuario que te consulta es Uriel Admin (UID: user_creador), rol en este tablero: creador.",
        ),
      );
      expect(
        prompt,
        contains(
          "Cuando diga 'mis tareas', 'a mi nombre', 'yo' o 'mío', se refiere a este usuario.",
        ),
      );
      expect(
        prompt,
        contains("misTareas"),
      );
      expect(
        prompt,
        contains(
          "Si el usuario pregunta por algo de su cuenta que no esté en el contexto (como correo, contraseña, foto o configuración), responde que solo puedes consultar tareas y datos del tablero.",
        ),
      );
      expect(
        prompt,
        contains(
          'Responde en TEXTO PLANO sin usar formato Markdown: sin asteriscos (* o **), sin #, sin negritas ni cursivas. Para listas de tareas, usa un guion "-" con una tarea por línea, con el formato "- Título (estado, prioridad, vence dd/mm hh:mm am/pm)".',
        ),
      );
    });

    test('Controller pasa usuarioUid, usuarioNombre y usuarioRol a enviarMensajeChat y limpia la respuesta', () async {
      final fakeService = FakeAsistenteIaChatService(
        respuestaSimulada: '**Tus tareas:**\n- *Tarea 1* (Pendiente, alta)',
      );
      final controller = AsistenteIaChatController(chatService: fakeService);

      final ok = await controller.enviarMensaje(
        texto: 'mis tareas',
        tablero: tableroPrueba,
        tareasTablero: const [],
        miembrosNombres: miembrosMap,
        usuarioUid: 'user_dev1',
        usuarioNombre: 'Carlos Programador',
        usuarioRol: 'miembro',
        fechaActual: fechaReferencia,
      );

      expect(ok, isTrue);
      expect(fakeService.ultimoUsuarioUidRecibido, equals('user_dev1'));
      expect(fakeService.ultimoUsuarioNombreRecibido, equals('Carlos Programador'));
      expect(fakeService.ultimoUsuarioRolRecibido, equals('miembro'));

      final respuestaEnHistorial = controller.historial.last.texto;
      expect(respuestaEnHistorial.contains('**'), isFalse);
      expect(respuestaEnHistorial.contains('*'), isFalse);
      expect(respuestaEnHistorial, contains('- Tarea 1 (Pendiente, alta)'));
    });
  });
}

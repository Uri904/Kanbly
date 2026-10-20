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
    void Function(int intento, int intentosMaximos)? onReintento,
  }) async {
    ultimoMensajeRecibido = mensajeUsuario;
    if (throwError) {
      throw AsistenteIaException(MensajesAsistenteIa.servicioOcupado);
    }
    return respuestaSimulada;
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

  group('Pruebas de Funciones de Consulta de Solo Lectura (Function Calling)', () {
    test('ejecutarTareasPorEstado filtra por columna y limita a máximo 20 resultados', () {
      // Crear 25 tareas pendientes
      final List<Tarea> tareas25 = List.generate(25, (index) {
        return Tarea(
          id: 'tarea_$index',
          titulo: 'Tarea Pendiente $index',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          tableroId: 'tablero_1',
          fechaCreacion: fechaReferencia,
          prioridad: 3, // alta
          asignadosA: const ['user_dev1'],
        );
      });

      final resultado = AsistenteIaService.ejecutarTareasPorEstado(
        tareas: tareas25,
        miembrosNombres: miembrosMap,
        estado: 'Pendiente',
      );

      // Debe limitar estrictamente a 20 resultados
      expect(resultado.length, equals(20));

      // Verificar que los campos mapeados son exactamente los permitidos (sin comentarios ni adjuntos)
      final primera = resultado.first;
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

      // Filtro por nombre parcial 'Carlos'
      final resultadoCarlos = AsistenteIaService.ejecutarTareasDeIntegrante(
        tareas: tareas,
        miembrosNombres: miembrosMap,
        integrante: 'carlos',
      );

      expect(resultadoCarlos.length, equals(1));
      expect(resultadoCarlos.first['id'], equals('t1'));

      // Filtro por UID exacto
      final resultadoUid = AsistenteIaService.ejecutarTareasDeIntegrante(
        tareas: tareas,
        miembrosNombres: miembrosMap,
        integrante: 'user_dev2',
      );

      expect(resultadoUid.length, equals(1));
      expect(resultadoUid.first['id'], equals('t2'));
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

      expect(resultado.length, equals(1));
      expect(resultado.first['id'], equals('t1'));
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

      expect(resultado.length, equals(1));
      expect(resultado.first['id'], equals('t_vencida_pendiente'));
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

      // Debe haber exactamente 10 mensajes (se descartaron los 4 más antiguos)
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
}

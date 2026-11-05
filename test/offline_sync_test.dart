import 'package:flutter_test/flutter_test.dart';
import 'package:kanbly/modelo/tablero.dart';
import 'package:kanbly/modelo/tarea.dart';
import 'package:kanbly/modelo/usuario.dart';

void main() {
  group('Pruebas de Funcionamiento y Sincronización Offline (Kanbly)', () {
    test('Creación local de Tablero con ID offline', () {
      final tablero = Tablero(
        id: 'tablero_offline_123',
        nombre: 'Proyecto Demo Sin Internet',
        descripcion: 'Tablero creado de forma local',
        esGrupal: false,
        creadorId: 'user_offline_001',
        miembrosIds: ['user_offline_001'],
        columnas: ['Pendiente', 'En progreso', 'Completada'],
        fechaCreacion: DateTime.now(),
      );

      expect(tablero.id, equals('tablero_offline_123'));
      expect(tablero.nombre, equals('Proyecto Demo Sin Internet'));
      expect(tablero.columnas.length, equals(3));
      expect(tablero.esGrupal, isFalse);

      final map = tablero.toMap();
      expect(map['nombre'], equals('Proyecto Demo Sin Internet'));
      expect(map['miembrosIds'], contains('user_offline_001'));
    });

    test('Creación local de Tareas con asignación y prioridades offline', () {
      final tarea = Tarea(
        id: 'tarea_offline_456',
        titulo: 'Diseñar base de datos SQLite local',
        descripcion: 'Crear esquema offline en caché',
        estado: EstadoTarea.pendiente,
        estadoNombre: 'Pendiente',
        orden: 0,
        tableroId: 'tablero_offline_123',
        asignadosA: ['user_offline_001'],
        fechaCreacion: DateTime.now(),
        prioridad: 3,
        archivada: false,
        creadaPor: 'user_offline_001',
      );

      expect(tarea.id, equals('tarea_offline_456'));
      expect(tarea.prioridad, equals(3));
      expect(tarea.estadoNombre, equals('Pendiente'));
      expect(tarea.archivada, isFalse);

      final map = tarea.toMap();
      expect(map['titulo'], equals('Diseñar base de datos SQLite local'));
      expect(map['prioridad'], equals(3));
    });

    test('Ordenamiento en memoria de tareas offline cuando falla índice ordenado', () {
      final ahora = DateTime.now();
      final tareas = [
        Tarea(
          id: '1',
          titulo: 'Tarea Vieja',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          orden: 2,
          tableroId: 't1',
          fechaCreacion: ahora.subtract(const Duration(hours: 2)),
          prioridad: 1,
          archivada: false,
          creadaPor: 'u1',
        ),
        Tarea(
          id: '2',
          titulo: 'Tarea Reciente',
          estado: EstadoTarea.pendiente,
          estadoNombre: 'Pendiente',
          orden: 1,
          tableroId: 't1',
          fechaCreacion: ahora,
          prioridad: 3,
          archivada: false,
          creadaPor: 'u1',
        ),
      ];

      // Ordenar por fechaCreacion descendente (como hace el fallback de FirestoreService)
      tareas.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
      expect(tareas.first.id, equals('2'));

      // Ordenar por prioridad descendente
      tareas.sort((a, b) => b.prioridad.compareTo(a.prioridad));
      expect(tareas.first.prioridad, equals(3));
    });

    test('Mantenimiento de modelo Usuario local provisional cuando no hay red', () {
      final usuarioLocal = Usuario(
        id: 'uid_offline_99',
        email: 'estudiante@e.uttecamac.edu.mx',
        nombreCompleto: 'Estudiante Kanbly',
        fechaRegistro: DateTime.now(),
        emailVerificado: true,
        rol: 'estudiante',
        tablerosIds: [],
        activo: true,
      );

      expect(usuarioLocal.id, equals('uid_offline_99'));
      expect(usuarioLocal.email, equals('estudiante@e.uttecamac.edu.mx'));
      expect(usuarioLocal.activo, isTrue);
    });
  });
}

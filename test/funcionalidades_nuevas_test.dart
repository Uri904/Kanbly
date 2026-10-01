import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanbly/modelo/tablero.dart';
import 'package:kanbly/modelo/tarea.dart';
import 'package:kanbly/utilerias/formato_util.dart';

void main() {
  group('Pruebas de Funcionalidades Solicitadas por el Usuario', () {
    test('1. Personalización de columnas en el modelo Tablero', () {
      final tableroDefault = Tablero(
        id: 'b1',
        nombre: 'Tablero Estándar',
        esGrupal: false,
        creadorId: 'u1',
        fechaCreacion: DateTime.now(),
      );

      // Por defecto tiene Pendiente, En progreso, Completada
      expect(tableroDefault.columnas, equals(['Pendiente', 'En progreso', 'Completada']));

      // Tablero con columnas personalizadas
      final tableroCustom = Tablero(
        id: 'b2',
        nombre: 'Tablero Desarrollo Software',
        esGrupal: true,
        creadorId: 'u1',
        columnas: ['Por Hacer', 'En Desarrollo', 'En Pruebas / QA', 'Aprobado'],
        fechaCreacion: DateTime.now(),
      );

      expect(tableroCustom.columnas.length, equals(4));
      expect(tableroCustom.columnas, contains('En Pruebas / QA'));

      // Verificar toMap y fromMap con columnas
      final map = tableroCustom.toMap();
      expect(map['columnas'], equals(['Por Hacer', 'En Desarrollo', 'En Pruebas / QA', 'Aprobado']));

      final tableroRecuperado = Tablero.fromMap('b2', map);
      expect(tableroRecuperado.columnas, equals(['Por Hacer', 'En Desarrollo', 'En Pruebas / QA', 'Aprobado']));
    });

    test('2. Colores y textos según nivel de importancia / prioridad', () {
      expect(FormatoUtil.obtenerTextoPrioridad(3), equals('Alta'));
      expect(FormatoUtil.obtenerTextoPrioridad(2), equals('Media'));
      expect(FormatoUtil.obtenerTextoPrioridad(1), equals('Baja'));

      final colorAlta = FormatoUtil.obtenerColorPorPrioridad(3);
      final colorMedia = FormatoUtil.obtenerColorPorPrioridad(2);
      final colorBaja = FormatoUtil.obtenerColorPorPrioridad(1);

      expect(colorAlta, equals(const Color(0xFFE53E3E))); // Rojo
      expect(colorMedia, equals(const Color(0xFFED8936))); // Naranja
      expect(colorBaja, equals(const Color(0xFF38A169))); // Verde
    });

    test('3. Tareas en tableros de equipo soportan asignación de integrante', () {
      final tarea = Tarea(
        id: 't1',
        titulo: 'Diseño de la Arquitectura',
        tableroId: 'b2',
        asignadoA: 'user_dev_1',
        fechaCreacion: DateTime.now(),
        prioridad: 3,
        estadoNombre: 'En Desarrollo',
      );

      expect(tarea.asignadoA, equals('user_dev_1'));
      expect(tarea.estadoNombre, equals('En Desarrollo'));
      expect(tarea.prioridad, equals(3));

      final map = tarea.toMap();
      expect(map['asignadoA'], equals('user_dev_1'));
      expect(map['estado'], equals('En Desarrollo'));

      final tareaFromMap = Tarea.fromMap('t1', map);
      expect(tareaFromMap.asignadoA, equals('user_dev_1'));
      expect(tareaFromMap.estadoNombre, equals('En Desarrollo'));
    });

    test('4. Copia de tarea con copyWith actualiza asignación y columna', () {
      final tareaOriginal = Tarea(
        id: 't2',
        titulo: 'Revisión de Código',
        tableroId: 'b2',
        fechaCreacion: DateTime.now(),
      );

      final tareaActualizada = tareaOriginal.copyWith(
        asignadoA: 'user_qa_1',
        estadoNombre: 'En Pruebas / QA',
        prioridad: 2,
      );

      expect(tareaActualizada.asignadoA, equals('user_qa_1'));
      expect(tareaActualizada.estadoNombre, equals('En Pruebas / QA'));
      expect(tareaActualizada.prioridad, equals(2));
    });
  });
}

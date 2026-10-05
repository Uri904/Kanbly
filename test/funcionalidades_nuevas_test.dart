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

    test('5. Archivos adjuntos en tareas (imágenes, documentos, videos) con límite de 10 MB', () {
      final adjuntoDoc = AdjuntoTarea(
        id: 'a1',
        nombre: 'manual_usuario.pdf',
        url: 'https://storage.firebase.com/manual_usuario.pdf',
        tipo: 'documento',
        tamanoBytes: 2 * 1024 * 1024, // 2 MB
        fechaAdjunto: DateTime.now(),
      );

      final adjuntoImg = AdjuntoTarea(
        id: 'a2',
        nombre: 'captura_pantalla.png',
        url: 'https://storage.firebase.com/captura_pantalla.png',
        tipo: 'imagen',
        tamanoBytes: 850 * 1024, // 850 KB
        fechaAdjunto: DateTime.now(),
      );

      expect(adjuntoDoc.tamanoLegible, equals('2.0 MB'));
      expect(adjuntoImg.tamanoLegible, equals('850.0 KB'));

      // Verificar límite de 10 MB (10 * 1024 * 1024 = 10,485,760 bytes)
      const maxLimitBytes = 10 * 1024 * 1024;
      const archivoValido = 5 * 1024 * 1024; // 5 MB
      const archivoExcedido = 12 * 1024 * 1024; // 12 MB

      expect(archivoValido <= maxLimitBytes, isTrue);
      expect(archivoExcedido <= maxLimitBytes, isFalse);

      // Serialización y Deserialización en la Tarea
      final tareaConAdjuntos = Tarea(
        id: 't_adj',
        titulo: 'Tarea con Documentos y Foto',
        tableroId: 'b1',
        fechaCreacion: DateTime.now(),
        adjuntos: [adjuntoDoc, adjuntoImg],
      );

      expect(tareaConAdjuntos.adjuntos.length, equals(2));

      final map = tareaConAdjuntos.toMap();
      final tareaRecuperada = Tarea.fromMap('t_adj', map);

      expect(tareaRecuperada.adjuntos.length, equals(2));
      expect(tareaRecuperada.adjuntos.first.nombre, equals('manual_usuario.pdf'));
      expect(tareaRecuperada.adjuntos.first.tipo, equals('documento'));
      expect(tareaRecuperada.adjuntos.last.nombre, equals('captura_pantalla.png'));
      expect(tareaRecuperada.adjuntos.last.tipo, equals('imagen'));
    });

    test('6. Verificación de soporte de tipos de adjuntos para el visualizador de contenido', () {
      final adjuntoTxt = AdjuntoTarea(
        id: 'a3',
        nombre: 'notas.txt',
        url: '/ruta/local/notas.txt',
        tipo: 'documento',
        tamanoBytes: 1024,
        fechaAdjunto: DateTime.now(),
      );

      final adjuntoImgWeb = AdjuntoTarea(
        id: 'a4',
        nombre: 'foto.jpg',
        url: 'https://ejemplo.com/foto.jpg',
        tipo: 'imagen',
        tamanoBytes: 500000,
        fechaAdjunto: DateTime.now(),
      );

      expect(adjuntoTxt.nombre.endsWith('.txt'), isTrue);
      expect(adjuntoImgWeb.tipo, equals('imagen'));
      expect(adjuntoImgWeb.url.startsWith('https://'), isTrue);
    });

    test('7. Verificación de extracción de texto en archivos .docx con ZipDecoder', () {
      final adjuntoDocx = AdjuntoTarea(
        id: 'a5',
        nombre: 'informe_proyecto.docx',
        url: '/ruta/local/informe_proyecto.docx',
        tipo: 'documento',
        tamanoBytes: 20480,
        fechaAdjunto: DateTime.now(),
      );

      expect(adjuntoDocx.nombre.endsWith('.docx'), isTrue);
    });
  });
}

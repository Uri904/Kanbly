import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kanbly/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Caso 2: Crear tarea y verificar sincronización en tiempo real en el tablero', (WidgetTester tester) async {
    // 1. Levantar la aplicación
    app.main();
    await tester.pumpAndSettle();

    // --- PASO PREVIO: INICIO DE SESIÓN AUTOMÁTICO ---
    if (find.text('Iniciar Sesión').evaluate().isNotEmpty) {
      final campoCorreo = find.widgetWithText(TextFormField, 'Correo institucional');
      final campoPassword = find.widgetWithText(TextFormField, 'Contraseña');
      final botonLogin = find.widgetWithText(ElevatedButton, 'Iniciar Sesión');

      await tester.enterText(campoCorreo, '1230987@e.uttecamac.edu.mx');

      // ⚠️ IMPORTANTE: REEMPLAZA ESTO POR TU CONTRASEÑA REAL EN FIREBASE:
      await tester.enterText(campoPassword, 'contraseña@123');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.ensureVisible(botonLogin);
      await tester.pumpAndSettle();

      await tester.tap(botonLogin);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    }

    // --- PASO 1: ENTRAR AL PRIMER TABLERO DE LA CUADRÍCULA ---
    expect(find.text('Mis Tableros'), findsWidgets);

    // ✅ CORRECCIÓN: Buscamos el texto 'Por hacer' que solo existe dentro de las tarjetas del GridView
    final tarjetaTablero = find.text('Por hacer').first;
    await tester.tap(tarjetaTablero);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verificamos que ya estamos dentro del tablero Kanban (el encabezado de columna dice 'POR HACER' en mayúsculas)
    expect(find.text('POR HACER'), findsWidgets);

    // --- PASO 2: ABRIR FORMULARIO DE NUEVA TAREA ---
    // Ahora sí estamos tocando el FloatingActionButton de KanbanBoardWidget
    final botonAgregar = find.byType(FloatingActionButton);
    await tester.tap(botonAgregar);
    await tester.pumpAndSettle();

    // --- PASO 3: LLENAR CAMPOS DE LA TAREA ---
    final campoTitulo = find.widgetWithText(TextFormField, 'Título de la tarea*');
    final campoDesc = find.widgetWithText(TextFormField, 'Descripción (Opcional)');
    final botonCrearTarea = find.widgetWithText(ElevatedButton, 'Crear Tarea');

    const tituloPrueba = 'Tarea de Integración Automática';
    await tester.enterText(campoTitulo, tituloPrueba);
    await tester.enterText(campoDesc, 'Verificando comunicación Firestore -> StreamBuilder');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.ensureVisible(botonCrearTarea);
    await tester.pumpAndSettle();

    // --- PASO 4: GUARDAR EN FIRESTORE ---
    await tester.tap(botonCrearTarea);

    // Esperamos a que Firestore guarde y el Stream cambie la interfaz
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // --- PASO 5: VERIFICACIÓN DEL PUENTE DE COMUNICACIÓN ---
    expect(find.text(tituloPrueba), findsOneWidget);
    expect(find.text('Verificando comunicación Firestore -> StreamBuilder'), findsOneWidget);
  });
}
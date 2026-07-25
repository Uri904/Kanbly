import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// --- IMPORTS DE TU PROYECTO ---
import 'package:kanbly/main.dart' as app;
import 'package:kanbly/utilerias/formato_util.dart';
import 'package:kanbly/modelo/usuario.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // 🛠️ FUNCIÓN AUXILIAR BLINDADA CONTRA REDIRECCIONES AUTOMÁTICAS DE FIREBASE
  // ===========================================================================
  Future<void> iniciarSesionSiEsNecesario(WidgetTester tester) async {
    // 1. ESPERA ESTRATÉGICA: Damos 2 segundos para que Firebase verifique si ya
    // hay una sesión activa del test anterior y haga su redirección automática.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 2. Buscamos ESPECÍFICAMENTE el botón de ElevatedButton('Iniciar Sesión')
    final botonLogin = find.widgetWithText(ElevatedButton, 'Iniciar Sesión');

    // 3. Solo si el botón SIGUE en pantalla después de esperar, iniciamos sesión
    if (botonLogin.evaluate().isNotEmpty) {
      final campoCorreo = find.widgetWithText(TextFormField, 'Correo institucional');
      final campoPassword = find.widgetWithText(TextFormField, 'Contraseña');

      await tester.enterText(campoCorreo, '1230987@e.uttecamac.edu.mx');

      // ⚠️ IMPORTANTE: REEMPLAZA ESTO POR TU CONTRASEÑA REAL DE FIREBASE:
      await tester.enterText(campoPassword, 'contraseña@123');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.ensureVisible(botonLogin);
      await tester.pumpAndSettle();

      await tester.tap(botonLogin);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    }
  }

  // ===========================================================================
  // 🚀 SUITE INTEGRAL DE PRUEBAS DE INTEGRACIÓN - KANBLY
  // ===========================================================================
  group('Suite Integral de Pruebas de Integración - Kanbly', () {

    // -------------------------------------------------------------------------
    // CASO 1: AUTENTICACIÓN Y VALIDACIÓN DE DOMINIO INSTITUCIONAL
    // -------------------------------------------------------------------------
    testWidgets('Caso 1: Validar rechazo de correo externo y login institucional exitoso', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Si estamos en el Login, hacemos la prueba de rechazo primero
      final botonLogin = find.widgetWithText(ElevatedButton, 'Iniciar Sesión');
      if (botonLogin.evaluate().isNotEmpty) {
        final campoCorreo = find.widgetWithText(TextFormField, 'Correo institucional');
        final campoPassword = find.widgetWithText(TextFormField, 'Contraseña');

        await tester.enterText(campoCorreo, 'estudiante@gmail.com');
        await tester.enterText(campoPassword, 'password123');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.ensureVisible(botonLogin);
        await tester.pumpAndSettle();

        await tester.tap(botonLogin);
        await tester.pumpAndSettle();

        expect(find.text('Solo se permiten correos institucionales @e.uttecamac.edu.mx'), findsOneWidget);
      }

      await iniciarSesionSiEsNecesario(tester);
      expect(find.text('Mis Tableros'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // CASO 2: CREACIÓN DE TAREA Y SINCRONIZACIÓN EN TIEMPO REAL (KANBAN)
    // -------------------------------------------------------------------------
    testWidgets('Caso 2: Crear tarea y verificar sincronización en tiempo real en el tablero', (WidgetTester tester) async {
      app.main();
      await iniciarSesionSiEsNecesario(tester);

      expect(find.text('Mis Tableros'), findsWidgets);

      // Entramos al tablero tocando el texto 'Por hacer' del pie de la tarjeta
      final tarjetaTablero = find.text('Por hacer').first;
      await tester.tap(tarjetaTablero);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('POR HACER'), findsWidgets);

      final botonAgregar = find.byType(FloatingActionButton);
      await tester.tap(botonAgregar);
      await tester.pumpAndSettle();

      final campoTitulo = find.widgetWithText(TextFormField, 'Título de la tarea*');
      final campoDesc = find.widgetWithText(TextFormField, 'Descripción (Opcional)');
      final botonCrearTarea = find.widgetWithText(ElevatedButton, 'Crear Tarea');

      const tituloPrueba = 'Tarea QA Suite Integral';
      await tester.enterText(campoTitulo, tituloPrueba);
      await tester.enterText(campoDesc, 'Verificando interoperabilidad Firestore -> StreamBuilder');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.ensureVisible(botonCrearTarea);
      await tester.pumpAndSettle();

      await tester.tap(botonCrearTarea);
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // ✅ CORRECCIÓN: Usamos findsWidgets por si acumulas tareas de pruebas anteriores
      expect(find.text(tituloPrueba), findsWidgets);
      expect(find.text('Verificando interoperabilidad Firestore -> StreamBuilder'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // CASO 3: GESTIÓN DE TABLEROS Y NAVEGACIÓN (MENÚ LATERAL)
    // -------------------------------------------------------------------------
    testWidgets('Caso 3: Navegación por menú lateral y creación de tablero individual', (WidgetTester tester) async {
      app.main();
      await iniciarSesionSiEsNecesario(tester);

      final botonMenu = find.byIcon(Icons.menu);
      await tester.tap(botonMenu);
      await tester.pumpAndSettle();

      expect(find.text('Kanbly'), findsWidgets);
      final opcionMisTableros = find.text('Mis Tableros').last;
      await tester.tap(opcionMisTableros);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final opcionIndividual = find.text('Tablero Individual');
      await tester.tap(opcionIndividual);
      await tester.pumpAndSettle();

      final campoNombre = find.widgetWithText(TextFormField, 'Ej. Sprint 1...');
      const nombreTableroTest = 'Tablero QA Automatizado';
      await tester.enterText(campoNombre, nombreTableroTest);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      final botonGuardar = find.widgetWithText(ElevatedButton, 'Crear Tablero');
      await tester.ensureVisible(botonGuardar);
      await tester.pumpAndSettle();

      await tester.tap(botonGuardar);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // ✅ CORRECCIÓN: Usamos findsWidgets para que no falle si ya existe un tablero previo con este nombre
      expect(find.text(nombreTableroTest), findsWidgets);
      expect(find.text('Individual'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // CASO 4: INTEGRACIÓN DE UTILERÍAS Y FORMATEO DE DATOS EN LA UI
    // -------------------------------------------------------------------------
    testWidgets('Caso 4: Verificar que FormatoUtil se comunique correctamente sin errores de renderizado', (WidgetTester tester) async {
      // A. Validación lógica en memoria
      final usuarioPrueba = Usuario(
        id: '123',
        email: 'test@e.uttecamac.edu.mx',
        nombreCompleto: 'Martin Villalobos',
        fechaRegistro: DateTime.now(),
      );

      final iniciales = FormatoUtil.obtenerIniciales(usuarioPrueba);
      expect(iniciales, 'MV');

      final colorAlta = FormatoUtil.obtenerColorPorPrioridad(3);
      expect(colorAlta, const Color(0xFF63D0A1));

      // B. Validación en interfaz real
      app.main();
      await iniciarSesionSiEsNecesario(tester);

      expect(find.text('Mis Tableros'), findsWidgets);

      final tarjetaTablero = find.text('Por hacer').first;
      await tester.tap(tarjetaTablero);
      await tester.pumpAndSettle(const Duration(seconds: 4));

      expect(find.text('POR HACER'), findsWidgets);

      final contenedoresVisuales = find.byType(Container);
      expect(contenedoresVisuales, findsWidgets);
    });

  });
}
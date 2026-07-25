import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kanbly/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Caso 3: Navegación de menú lateral y creación de tablero individual', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // --- PASO PREVIO: INICIO DE SESIÓN AUTOMÁTICO ---
    // Verificamos si el sistema nos pide iniciar sesión
    if (find.text('Iniciar Sesión').evaluate().isNotEmpty) {
      final campoCorreo = find.widgetWithText(TextFormField, 'Correo institucional');
      final campoPassword = find.widgetWithText(TextFormField, 'Contraseña');
      final botonLogin = find.widgetWithText(ElevatedButton, 'Iniciar Sesión');

      await tester.enterText(campoCorreo, '1230987@e.uttecamac.edu.mx');

      // ⚠️ IMPORTANTE: REEMPLAZA ESTO POR TU CONTRASEÑA REAL EN FIREBASE:
      await tester.enterText(campoPassword, 'contraseña@123');

      // Ocultar teclado y hacer scroll al botón
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.ensureVisible(botonLogin);
      await tester.pumpAndSettle();

      await tester.tap(botonLogin);

      // Esperar a que Firebase valide y cargue la vista "Mis Tableros"
      await tester.pumpAndSettle(const Duration(seconds: 6));
    }

    // 1. Abrir el Drawer (Menú lateral) tocando el icono de hamburguesa en el Encabezado
    final botonMenu = find.byIcon(Icons.menu); // O el icono que use tu Encabezado
    await tester.tap(botonMenu);
    await tester.pumpAndSettle();

    // 2. Verificar que se cargaron los datos del usuario en el DrawerHeader y pulsar 'Mis Tableros'
    expect(find.text('Kanbly'), findsWidgets);
    final opcionMisTableros = find.text('Mis Tableros').last;
    await tester.tap(opcionMisTableros);
    await tester.pumpAndSettle();

    // 3. Tocar el botón (+) en MisTableros para llamar a _mostrarOpcionesCreacion
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // 4. Elegir la opción 'Tablero Individual' en el BottomSheet
    final opcionIndividual = find.text('Tablero Individual');
    await tester.tap(opcionIndividual);
    await tester.pumpAndSettle(); // Nos lleva a FormularioTablero(esGrupal: false)

    // 5. Llenar el formulario del tablero
    final campoNombre = find.widgetWithText(TextFormField, 'Ej. Sprint 1...');
    const nombreTableroTest = 'Tablero QA Integración';
    await tester.enterText(campoNombre, nombreTableroTest);

    // Guardar (comunicación con _firestoreService.crearTableroConId)
    final botonGuardar = find.widgetWithText(ElevatedButton, 'Crear Tablero');
    await tester.tap(botonGuardar);

    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Criterio de éxito: Al regresar a la cuadrícula, el nuevo tablero es visible
    expect(find.text(nombreTableroTest), findsOneWidget);
    expect(find.text('Individual'), findsWidgets);
  });
}
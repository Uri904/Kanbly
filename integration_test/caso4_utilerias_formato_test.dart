import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kanbly/main.dart' as app;
import 'package:kanbly/utilerias/formato_util.dart';
import 'package:kanbly/modelo/usuario.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Caso 4: Integración de Utilerías con Componentes Visuales', () {
    testWidgets('Verificar que FormatoUtil se comunique correctamente sin errores de renderizado', (WidgetTester tester) async {
      // --- PRUEBA A: COMUNICACIÓN LÓGICA DE MODELOS CON FORMATO_UTIL ---
      final usuarioPrueba = Usuario(
        id: '123',
        email: 'test@e.uttecamac.edu.mx',
        nombreCompleto: 'Martin Villalobos',
        fechaRegistro: DateTime.now(),
      );

      // 1. Verificar que la función lógica extraiga correctamente las iniciales 'MV'
      final iniciales = FormatoUtil.obtenerIniciales(usuarioPrueba);
      expect(iniciales, 'MV');

      // 2. Verificar que el mapeo de colores por prioridad devuelva el código Hexadecimal exacto de Kanbly[cite: 2]
      final colorAlta = FormatoUtil.obtenerColorPorPrioridad(3); // Prioridad Alta[cite: 2]
      expect(colorAlta, const Color(0xFF63D0A1)); // Verde Turquesa[cite: 2]

      // --- PRUEBA B: INTEGRACIÓN EN PANTALLA REAL (UI) ---
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

      // --- PASO 1: ENTRAR AL TABLERO (Evitando la trampa de las pestañas) ---
      expect(find.text('Mis Tableros'), findsWidgets);

      // Tocamos el texto 'Por hacer' del pie de la tarjeta del tablero para entrar de forma segura[cite: 2]
      final tarjetaTablero = find.text('Por hacer').first;
      await tester.tap(tarjetaTablero);

      // Esperamos a que Firestore descargue las tareas y el StreamBuilder construya las TaskCardWidget[cite: 2]
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // --- PASO 2: VERIFICACIÓN DE RENDERIZADO SIN EXCEPCIONES ---
      // Verificamos que entramos correctamente a la vista Kanban
      expect(find.text('POR HACER'), findsWidgets);

      // Buscamos que los contenedores visuales se hayan construido en la pantalla
      final contenedoresVisuales = find.byType(Container);
      expect(contenedoresVisuales, findsWidgets);

      // Criterio de éxito final: Si el código llegó hasta esta línea sin que Flutter
      // arrojara una pantalla roja de error de tipado (Null Pointer Exception o Type Error)
      // al inyectar las iniciales y colores en las tarjetas, la integración fue 100% exitosa.
    });
  });
}
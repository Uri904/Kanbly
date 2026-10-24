import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kanbly/controlador/preferencias_controller.dart';
import 'package:kanbly/Vistas/splash_animado_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pruebas de PreferenciasController y SplashAnimadoView', () {
    test('1. El valor por defecto de mostrarAnimacion es true', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = PreferenciasController();
      await Future.delayed(Duration.zero);
      expect(controller.mostrarAnimacion, isTrue);
    });

    test('2. Guardar false en PreferenciasController persiste el valor', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = PreferenciasController();
      await controller.setMostrarAnimacion(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PreferenciasController.keyMostrarAnimacion), isFalse);
      expect(controller.mostrarAnimacion, isFalse);
    });

    testWidgets('3. Con mostrarAnimacion=false, el destino directo se renderiza sin splash',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'mostrar_animacion_inicio': false});
      final prefs = await SharedPreferences.getInstance();
      final mostrarAnimacion = prefs.getBool('mostrar_animacion_inicio') ?? true;

      const Widget destinoMock = Scaffold(
        body: Center(child: Text('Pantalla Destino Falsa')),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: mostrarAnimacion
              ? SplashAnimadoView(destinoBuilder: (_) => destinoMock)
              : destinoMock,
        ),
      );

      expect(find.text('Pantalla Destino Falsa'), findsOneWidget);
      expect(find.byType(SplashAnimadoView), findsNothing);
    });

    testWidgets('4. Con mostrarAnimacion=true, se muestra la splash y navega al destino tras animar',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'mostrar_animacion_inicio': true});

      const Widget destinoMock = Scaffold(
        body: Center(child: Text('Pantalla Destino Falsa')),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SplashAnimadoView(
            destinoBuilder: (_) => destinoMock,
          ),
        ),
      );

      expect(find.byType(SplashAnimadoView), findsOneWidget);
      expect(find.text('KANBLY'), findsOneWidget);
      expect(find.text('Fluye y avanza'), findsOneWidget);
      expect(find.text('Pantalla Destino Falsa'), findsNothing);

      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();

      expect(find.text('Pantalla Destino Falsa'), findsOneWidget);
    });

    testWidgets('5. Un toque (tap) en la pantalla salta la animación y navega de inmediato',
        (WidgetTester tester) async {
      const Widget destinoMock = Scaffold(
        body: Center(child: Text('Pantalla Destino Falsa')),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SplashAnimadoView(
            destinoBuilder: (_) => destinoMock,
          ),
        ),
      );

      expect(find.byType(SplashAnimadoView), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byType(SplashAnimadoView));
      await tester.pumpAndSettle();

      expect(find.text('Pantalla Destino Falsa'), findsOneWidget);
    });

    testWidgets('6. Con MediaQuery disableAnimations=true, navega de inmediato sin animar',
        (WidgetTester tester) async {
      const Widget destinoMock = Scaffold(
        body: Center(child: Text('Pantalla Destino Falsa')),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: SplashAnimadoView(
              destinoBuilder: (_) => destinoMock,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pantalla Destino Falsa'), findsOneWidget);
    });

    testWidgets('7. Modo vistaPrevia=true realiza Navigator.pop al finalizar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SplashAnimadoView(
                        vistaPrevia: true,
                        destinoBuilder: (_) => const SizedBox(),
                      ),
                    ),
                  );
                },
                child: const Text('Abrir Vista Previa'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Vista Previa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SplashAnimadoView), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();

      expect(find.byType(SplashAnimadoView), findsNothing);
      expect(find.text('Abrir Vista Previa'), findsOneWidget);
    });
  });
}

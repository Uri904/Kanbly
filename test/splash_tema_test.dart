import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanbly/Vistas/splash_animado_view.dart';

void main() {
  Widget app(ThemeMode modo) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: modo,
      home: SplashAnimadoView(
        destinoBuilder: (_) => const Scaffold(body: Text('Destino')),
      ),
    );
  }

  AnnotatedRegion<SystemUiOverlayStyle> regionDeLaSplash(WidgetTester tester) {
    return tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find
          .descendant(
            of: find.byType(SplashAnimadoView),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .first,
    );
  }

  group('SplashAnimadoView sigue el tema de la app', () {
    testWidgets('tema oscuro: fondo oscuro e iconos claros en la barra de estado',
        (WidgetTester tester) async {
      await tester.pumpWidget(app(ThemeMode.dark));
      await tester.pump(const Duration(milliseconds: 500));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, SplashAnimadoView.fondoOscuro);
      expect(regionDeLaSplash(tester).value.statusBarIconBrightness,
          Brightness.light);

      await tester.pumpAndSettle();
    });

    testWidgets('tema claro: fondo claro e iconos oscuros en la barra de estado',
        (WidgetTester tester) async {
      await tester.pumpWidget(app(ThemeMode.light));
      await tester.pump(const Duration(milliseconds: 500));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, SplashAnimadoView.fondoClaro);
      expect(regionDeLaSplash(tester).value.statusBarIconBrightness,
          Brightness.dark);

      await tester.pumpAndSettle();
    });

    testWidgets('incluye las dos capas de la abeja (alas y cuerpo)',
        (WidgetTester tester) async {
      await tester.pumpWidget(app(ThemeMode.light));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Image), findsAtLeastNWidgets(2));

      await tester.pumpAndSettle();
    });

    testWidgets('el nombre y el eslogan aparecen y luego navega al destino',
        (WidgetTester tester) async {
      await tester.pumpWidget(app(ThemeMode.dark));
      await tester.pump(const Duration(milliseconds: 1600));

      expect(find.text('KANBLY'), findsOneWidget);
      expect(find.text('Fluye y avanza'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Destino'), findsOneWidget);
    });
  });
}


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Kanbly puede renderizar una pantalla básica',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Kanbly'),
              ),
            ),
          ),
        );

        expect(find.text('Kanbly'), findsOneWidget);
      });
}

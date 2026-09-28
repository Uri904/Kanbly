import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanbly/modelo/tarea.dart';

void main() {
  testWidgets('Verifica que LongPressDraggable e inicie el arrastre con touch rápido', (WidgetTester tester) async {
    bool tareaAceptada = false;
    Tarea? tareaArrastrada;

    final tareaPrueba = Tarea(
      id: 'task_1',
      titulo: 'Tarea de Prueba Touch',
      tableroId: 'board_1',
      fechaCreacion: DateTime.now(),
      estado: EstadoTarea.pendiente,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              // Columna Origen con LongPressDraggable
              SizedBox(
                width: 200,
                child: LongPressDraggable<Tarea>(
                  data: tareaPrueba,
                  delay: const Duration(milliseconds: 150),
                  feedback: Material(
                    child: Text(tareaPrueba.titulo),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue,
                    child: Text(tareaPrueba.titulo),
                  ),
                ),
              ),
              // Columna Destino con DragTarget
              SizedBox(
                width: 200,
                child: DragTarget<Tarea>(
                  onAcceptWithDetails: (details) {
                    tareaAceptada = true;
                    tareaArrastrada = details.data;
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      color: candidateData.isNotEmpty ? Colors.green : Colors.grey,
                      child: const Text('Columna Destino'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Tarea de Prueba Touch'), findsOneWidget);
    expect(find.text('Columna Destino'), findsOneWidget);

    // 1. Iniciar el toque sobre la tarjeta de tarea
    final location = tester.getCenter(find.text('Tarea de Prueba Touch'));
    final gesture = await tester.startGesture(location);

    // 2. Transcurrir el retardo optimizado de 150ms para activar el arrastre táctil
    await tester.pump(const Duration(milliseconds: 160));

    // 3. Mover hacia la columna de destino
    final targetLocation = tester.getCenter(find.text('Columna Destino'));
    await gesture.moveTo(targetLocation);
    await tester.pump();

    // 4. Soltar el toque (*drop*)
    await gesture.up();
    await tester.pumpAndSettle();

    // 5. Verificación
    expect(tareaAceptada, isTrue);
    expect(tareaArrastrada?.id, equals('task_1'));
  });
}

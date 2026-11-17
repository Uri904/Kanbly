import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanbly/modelo/tarea.dart';
import 'package:kanbly/Vistas/kanban_board_widget.dart';

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

  testWidgets('Verifica renderizado de píldora flotante minimalista al arrastrar para eliminar', (WidgetTester tester) async {
    bool tareaEliminada = false;
    bool isDragging = false;

    final tareaPrueba = Tarea(
      id: 'task_delete',
      titulo: 'Tarea a Eliminar',
      tableroId: 'board_1',
      fechaCreacion: DateTime.now(),
      estado: EstadoTarea.pendiente,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Column(
                children: [
                  LongPressDraggable<Tarea>(
                    data: tareaPrueba,
                    delay: const Duration(milliseconds: 150),
                    onDragStarted: () => setState(() => isDragging = true),
                    onDragEnd: (_) => setState(() => isDragging = false),
                    feedback: Material(
                      child: Text(tareaPrueba.titulo),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue,
                      child: Text(tareaPrueba.titulo),
                    ),
                  ),
                  const Spacer(),
                  Visibility(
                    visible: isDragging,
                    child: SizedBox(
                      height: 56,
                      child: Center(
                        child: DragTarget<Tarea>(
                          onAcceptWithDetails: (details) {
                            tareaEliminada = true;
                          },
                          builder: (context, candidateData, rejectedData) {
                            final isHovered = candidateData.isNotEmpty;
                            return Container(
                              key: const Key('zona_eliminar_pildora'),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isHovered ? Colors.red : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isHovered ? Icons.delete_forever_rounded : Icons.delete_outline_rounded,
                                    color: isHovered ? Colors.white : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isHovered ? 'Soltar para eliminar' : 'Arrastrar para eliminar',
                                    style: TextStyle(color: isHovered ? Colors.white : Colors.black),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    // Iniciar arrastre
    final location = tester.getCenter(find.text('Tarea a Eliminar'));
    final gesture = await tester.startGesture(location);
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump();

    // Al estar arrastrando debe verse el texto "Arrastrar para eliminar"
    expect(find.text('Arrastrar para eliminar'), findsOneWidget);

    // Mover sobre la píldora de eliminación
    final dropTargetLocation = tester.getCenter(find.byKey(const Key('zona_eliminar_pildora')));
    await gesture.moveTo(dropTargetLocation);
    await tester.pump();

    // Debe cambiar a "Soltar para eliminar"
    expect(find.text('Soltar para eliminar'), findsOneWidget);

    // Soltar
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tareaEliminada, isTrue);
  });

  testWidgets('Verifica despliegue del menú rápido Mover a... en TaskCardWidget', (WidgetTester tester) async {
    final tareaPrueba = Tarea(
      id: 'task_quick_move',
      titulo: 'Tarea Movimiento Rápido',
      tableroId: 'board_1',
      fechaCreacion: DateTime.now(),
      estado: EstadoTarea.pendiente,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: TaskCardWidget(
              tarea: tareaPrueba,
              columnasList: const ['Pendiente', 'En progreso', 'Completada'],
            ),
          ),
        ),
      ),
    );

    // Verificar que la tarjeta renderiza el título y el botón "Mover ▾"
    expect(find.text('Tarea Movimiento Rápido'), findsOneWidget);
    expect(find.text('Mover ▾'), findsOneWidget);

    // Buscar el botón del menú de movimiento rápido por su icono swap_horiz_rounded o el texto "Mover ▾"
    final moveIconFinder = find.byIcon(Icons.swap_horiz_rounded);
    expect(moveIconFinder, findsWidgets);

    // Tocar el botón del menú "Mover ▾"
    await tester.tap(find.text('Mover ▾'));
    await tester.pumpAndSettle();

    // Debe mostrar la lista de columnas para selección directa
    expect(find.text('En progreso'), findsOneWidget);
    expect(find.text('Completada'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../modelo/tarea.dart';
import '../servicios/tarea_service.dart';

class CalendarioTablero extends StatefulWidget {
  final String tableroId;
  const CalendarioTablero({super.key, required this.tableroId});

  @override
  State<CalendarioTablero> createState() => _CalendarioTableroState();
}

class _CalendarioTableroState extends State<CalendarioTablero> {
  final TareaService _tareaService=TareaService();
  DateTime _diaSeleccionado = DateTime.now();
  DateTime _diaEnfocado = DateTime.now();
  List<Tarea> _tareas = [];
  List<Tarea> _tareasDelDia(DateTime dia){
    return _tareas.where((tarea){
      if (tarea.fechaVencimiento ==null){
        return false;
      }
      return isSameDay(tarea.fechaVencimiento, dia);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
      ),
      body: StreamBuilder<List<Tarea>>(
        stream: _tareaService.obtenerTareasDelTablero(widget.tableroId),
        builder: (context, snapshot){
          if(snapshot.connectionState == ConnectionState.waiting){
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError){
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }
          _tareas= snapshot.data ?? [];

          final tareasSeleccionadas= _tareasDelDia (_diaSeleccionado);
          return Column(
            children: [
              TableCalendar<Tarea>(
                firstDay: DateTime.utc(2020,1,1),
                lastDay: DateTime.utc(2040,12,32),
                focusedDay: _diaEnfocado,

                selectedDayPredicate: (day){
                  return isSameDay(_diaSeleccionado, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _diaSeleccionado=selectedDay;
                    _diaEnfocado=focusedDay;
                  });
                },
          eventLoader: (day) {
                  return _tareasDelDia(day);
          },

                ),
          const SizedBox(height: 20),
              Padding(padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Tareas del día', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Expanded(child: tareasSeleccionadas.isEmpty? const Center(
                child: Text('No hay tareas para este día',),
              )
                  : ListView.builder(itemCount: tareasSeleccionadas.length,
              itemBuilder:(context,index){
                    final tarea = tareasSeleccionadas[index];

                    return ListTile(
                      leading: Icon(
                        tarea.estado == EstadoTarea.completada ? Icons.check_circle:Icons.circle_outlined,
                      ),
                      title: Text(tarea.titulo,),
                      subtitle: Text(tarea.estado.value,),
                      trailing: Text('Prioridad ${tarea.prioridad}'),
                    );
              })
              )

            ],
          );
        },
      ),

    );
  }
}

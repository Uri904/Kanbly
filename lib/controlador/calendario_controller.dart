import 'package:table_calendar/table_calendar.dart';
import '../modelo/tarea.dart';
import '../servicios/tarea_service.dart';
import 'package:flutter/material.dart';

class CalendarioController {
  final TareaService _tareaService = TareaService();

  DateTime diaSeleccionado = DateTime.now();
  DateTime diaEnfocado = DateTime.now();

  List<Tarea> tareas = [];

  // Obtener las tareas del tablero
  Stream<List<Tarea>> obtenerTareasDelTablero(String tableroId) {
    return _tareaService.obtenerTareasDelTablero(tableroId);
  }

  // Actualizar las tareas recibidas
  void actualizarTareas(List<Tarea> nuevasTareas) {
    tareas = nuevasTareas;
  }

  // Obtener las tareas de un día específico
  List<Tarea> tareasDelDia(DateTime dia) {
    return tareas.where((tarea) {
      if (tarea.fechaVencimiento == null) {
        return false;
      }

      return isSameDay(tarea.fechaVencimiento, dia);
    }).toList();
  }

  Color colorPorEstado(EstadoTarea estado) {
    switch (estado) {
      case EstadoTarea.pendiente:
        return const Color(0xFF1E293B);
      case EstadoTarea.enProgreso:
        return const Color(0xFF63B09C);
      case EstadoTarea.completada:
        return const Color(0xFF63D0A1);
      case EstadoTarea.bloqueada:
        return const Color(0xFFE53E3E);
    }
  }

  Color colorPorTiempoRestante(DateTime? fechaVencimiento, EstadoTarea estado) {
    // Si está completada, siempre será azul
    if (estado == EstadoTarea.completada) {
      return const Color(0xFF52ABEB);
    }

    if (fechaVencimiento == null) {
      return Colors.grey;
    }

    final ahora = DateTime.now();
    final diferencia = fechaVencimiento.difference(ahora);

    // La tarea ya venció
    if (diferencia.isNegative) {
      return const Color(0xFFB91C1C);
    }

    // Falta 1 día o menos
    if (diferencia.inHours <= 24) {
      return const Color(0xFFE53E3E);
    }

    // Falta hasta 2 días
    if (diferencia.inHours <= 48) {
      return const Color(0xFFF59E0B);
    }

    // Falta más de 2 días
    return const Color(0xFF63D0A1);
  }

  // Seleccionar un día del calendario
  void seleccionarDia(DateTime selectedDay, DateTime focusedDay) {
    diaSeleccionado = selectedDay;
    diaEnfocado = focusedDay;
  }
}

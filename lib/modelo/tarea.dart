import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoTarea {
  pendiente,
  enProgreso,
  completada,
  bloqueada, // Nuevo estado según metodología Kanban
}

extension EstadoTareaExtension on EstadoTarea {
  String get value {
    switch (this) {
      case EstadoTarea.pendiente:
        return 'Pendiente';
      case EstadoTarea.enProgreso:
        return 'En progreso';
      case EstadoTarea.completada:
        return 'Completada';
      case EstadoTarea.bloqueada:
        return 'Bloqueada';
    }
  }

  static EstadoTarea fromString(String value) {
    switch (value) {
      case 'Pendiente':
        return EstadoTarea.pendiente;
      case 'En progreso':
        return EstadoTarea.enProgreso;
      case 'Completada':
        return EstadoTarea.completada;
      case 'Bloqueada':
        return EstadoTarea.bloqueada;
      default:
        return EstadoTarea.pendiente;
    }
  }
}

class Tarea {
  final String id;
  final String titulo;
  final String? descripcion;
  final EstadoTarea estado;
  final int orden;
  final String tableroId;
  final String? asignadoA;
  final DateTime fechaCreacion;
  final DateTime? fechaVencimiento;
  final DateTime? fechaActualizacion;
  final List<String> etiquetas;
  final int prioridad; // 1 = baja, 2 = media, 3 = alta
  final bool archivada;
  final String? creadaPor; // ID del usuario que creó la tarea
  final String? comentario; // Comentario adicional

  Tarea({
    required this.id,
    required this.titulo,
    this.descripcion,
    this.estado = EstadoTarea.pendiente,
    this.orden = 0,
    required this.tableroId,
    this.asignadoA,
    required this.fechaCreacion,
    this.fechaVencimiento,
    this.fechaActualizacion,
    this.etiquetas = const [],
    this.prioridad = 2,
    this.archivada = false,
    this.creadaPor,
    this.comentario,
  });

  factory Tarea.fromMap(String id, Map<String, dynamic> map) {
    return Tarea(
      id: id,
      titulo: map['titulo'] ?? 'Tarea sin título',
      descripcion: map['descripcion'],
      estado: EstadoTareaExtension.fromString(map['estado'] ?? 'Pendiente'),
      orden: map['orden'] ?? 0,
      tableroId: map['tableroId'] ?? '',
      asignadoA: map['asignadoA'],
      fechaCreacion: (map['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaVencimiento: (map['fechaVencimiento'] as Timestamp?)?.toDate(),
      fechaActualizacion: (map['fechaActualizacion'] as Timestamp?)?.toDate(),
      etiquetas: List<String>.from(map['etiquetas'] ?? []),
      prioridad: map['prioridad'] ?? 2,
      archivada: map['archivada'] ?? false,
      creadaPor: map['creadaPor'],
      comentario: map['comentario'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'estado': estado.value,
      'orden': orden,
      'tableroId': tableroId,
      'asignadoA': asignadoA,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaVencimiento': fechaVencimiento != null
          ? Timestamp.fromDate(fechaVencimiento!)
          : null,
      'fechaActualizacion': fechaActualizacion != null
          ? Timestamp.fromDate(fechaActualizacion!)
          : null,
      'etiquetas': etiquetas,
      'prioridad': prioridad,
      'archivada': archivada,
      'creadaPor': creadaPor,
      'comentario': comentario,
    };
  }

  Tarea copyWith({
    String? id,
    String? titulo,
    String? descripcion,
    EstadoTarea? estado,
    int? orden,
    String? tableroId,
    String? asignadoA,
    DateTime? fechaCreacion,
    DateTime? fechaVencimiento,
    DateTime? fechaActualizacion,
    List<String>? etiquetas,
    int? prioridad,
    bool? archivada,
    String? creadaPor,
    String? comentario,
  }) {
    return Tarea(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      orden: orden ?? this.orden,
      tableroId: tableroId ?? this.tableroId,
      asignadoA: asignadoA ?? this.asignadoA,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      etiquetas: etiquetas ?? this.etiquetas,
      prioridad: prioridad ?? this.prioridad,
      archivada: archivada ?? this.archivada,
      creadaPor: creadaPor ?? this.creadaPor,
      comentario: comentario ?? this.comentario,
    );
  }
}
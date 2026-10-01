import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoTarea {
  pendiente,
  enProgreso,
  completada,
  bloqueada,
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
    switch (value.trim()) {
      case 'Pendiente':
      case 'Por Hacer':
      case 'Por hacer':
        return EstadoTarea.pendiente;
      case 'En progreso':
      case 'En proceso':
      case 'Haciendo':
        return EstadoTarea.enProgreso;
      case 'Completada':
      case 'Completado':
      case 'Terminada':
      case 'Hecho':
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
  final String estadoNombre;
  final int orden;
  final String tableroId;
  final String? asignadoA;
  final DateTime fechaCreacion;
  final DateTime? fechaVencimiento;
  final DateTime? fechaActualizacion;
  final List<String> etiquetas;
  final int prioridad; // 1 = baja, 2 = media, 3 = alta
  final bool archivada;
  final String? creadaPor;
  final String? comentario;

  Tarea({
    required this.id,
    required this.titulo,
    this.descripcion,
    this.estado = EstadoTarea.pendiente,
    String? estadoNombre,
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
  }) : estadoNombre = estadoNombre ?? (estado.value);

  static int _parsePrioridad(dynamic val) {
    if (val == null) return 2;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final parsed = int.tryParse(val);
      if (parsed != null) return parsed;
      final str = val.trim().toLowerCase();
      if (str == 'alta') return 3;
      if (str == 'media') return 2;
      if (str == 'baja') return 1;
    }
    return 2;
  }

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  static DateTime? _parseFecha(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  factory Tarea.fromMap(String id, Map<String, dynamic> map) {
    final estadoStr = map['estado']?.toString() ?? 'Pendiente';
    final tituloStr = map['titulo']?.toString() ?? 'Tarea sin título';

    return Tarea(
      id: id,
      titulo: tituloStr.trim().isNotEmpty ? tituloStr : 'Tarea sin título',
      descripcion: map['descripcion']?.toString(),
      estado: EstadoTareaExtension.fromString(estadoStr),
      estadoNombre: estadoStr,
      orden: _parseInt(map['orden']),
      tableroId: map['tableroId']?.toString() ?? '',
      asignadoA: map['asignadoA']?.toString(),
      fechaCreacion: _parseFecha(map['fechaCreacion']) ?? DateTime.now(),
      fechaVencimiento: _parseFecha(map['fechaVencimiento']),
      fechaActualizacion: _parseFecha(map['fechaActualizacion']),
      etiquetas: List<String>.from(map['etiquetas'] ?? []),
      prioridad: _parsePrioridad(map['prioridad']),
      archivada: map['archivada'] ?? false,
      creadaPor: map['creadaPor']?.toString(),
      comentario: map['comentario']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'estado': estadoNombre,
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
    String? estadoNombre,
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
      estadoNombre: estadoNombre ?? (estado != null ? estado.value : this.estadoNombre),
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

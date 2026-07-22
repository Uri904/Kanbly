import 'package:cloud_firestore/cloud_firestore.dart';

class Tablero {
  final String id;
  final String nombre;
  final String? descripcion;

  /// Indica si el tablero es individual o grupal
  final bool esGrupal;

  /// Usuario que creó el tablero
  final String creadorId;

  /// Integrantes del tablero (vacío si es individual)
  final List<String> miembrosIds;

  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  /// Color opcional del tablero
  final String? color;

  /// Permite ocultar/desactivar tableros sin eliminarlos
  final bool activo;

  /// Configuración adicional
  final Map<String, dynamic>? configuracion;

  const Tablero({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.esGrupal,
    required this.creadorId,
    this.miembrosIds = const [],
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.color,
    this.activo = true,
    this.configuracion,
  });

  factory Tablero.fromMap(String id, Map<String, dynamic> map) {
    return Tablero(
      id: id,
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      esGrupal: map['esGrupal'] ?? false,
      creadorId: map['creadorId'] ?? '',
      miembrosIds: List<String>.from(map['miembrosIds'] ?? []),
      fechaCreacion:
      (map['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaActualizacion:
      (map['fechaActualizacion'] as Timestamp?)?.toDate(),
      color: map['color'],
      activo: map['activo'] ?? true,
      configuracion: map['configuracion'] != null
          ? Map<String, dynamic>.from(map['configuracion'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'esGrupal': esGrupal,
      'creadorId': creadorId,
      'miembrosIds': miembrosIds,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaActualizacion': fechaActualizacion != null
          ? Timestamp.fromDate(fechaActualizacion!)
          : null,
      'color': color,
      'activo': activo,
      'configuracion': configuracion,
    };
  }

  Tablero copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    bool? esGrupal,
    String? creadorId,
    List<String>? miembrosIds,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    String? color,
    bool? activo,
    Map<String, dynamic>? configuracion,
  }) {
    return Tablero(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      esGrupal: esGrupal ?? this.esGrupal,
      creadorId: creadorId ?? this.creadorId,
      miembrosIds: miembrosIds ?? this.miembrosIds,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      color: color ?? this.color,
      activo: activo ?? this.activo,
      configuracion: configuracion ?? this.configuracion,
    );
  }
}
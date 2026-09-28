import 'package:cloud_firestore/cloud_firestore.dart';

/// Permisos granulares de un integrante dentro de un tablero
class PermisosMiembro {
  final bool crearTareas;
  final bool editarTareas;
  final bool eliminarTareas;
  final bool moverTareas;
  final bool gestionarModulos;
  final bool administrarMiembros;
  final bool editarTablero;

  const PermisosMiembro({
    this.crearTareas = true,
    this.editarTareas = true,
    this.eliminarTareas = false,
    this.moverTareas = true,
    this.gestionarModulos = true,
    this.administrarMiembros = false,
    this.editarTablero = false,
  });

  static const PermisosMiembro todos = PermisosMiembro(
    crearTareas: true,
    editarTareas: true,
    eliminarTareas: true,
    moverTareas: true,
    gestionarModulos: true,
    administrarMiembros: true,
    editarTablero: true,
  );

  factory PermisosMiembro.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PermisosMiembro();
    return PermisosMiembro(
      crearTareas: map['crearTareas'] ?? true,
      editarTareas: map['editarTareas'] ?? true,
      eliminarTareas: map['eliminarTareas'] ?? false,
      moverTareas: map['moverTareas'] ?? true,
      gestionarModulos: map['gestionarModulos'] ?? true,
      administrarMiembros: map['administrarMiembros'] ?? false,
      editarTablero: map['editarTablero'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'crearTareas': crearTareas,
      'editarTareas': editarTareas,
      'eliminarTareas': eliminarTareas,
      'moverTareas': moverTareas,
      'gestionarModulos': gestionarModulos,
      'administrarMiembros': administrarMiembros,
      'editarTablero': editarTablero,
    };
  }

  PermisosMiembro copyWith({
    bool? crearTareas,
    bool? editarTareas,
    bool? eliminarTareas,
    bool? moverTareas,
    bool? gestionarModulos,
    bool? administrarMiembros,
    bool? editarTablero,
  }) {
    return PermisosMiembro(
      crearTareas: crearTareas ?? this.crearTareas,
      editarTareas: editarTareas ?? this.editarTareas,
      eliminarTareas: eliminarTareas ?? this.eliminarTareas,
      moverTareas: moverTareas ?? this.moverTareas,
      gestionarModulos: gestionarModulos ?? this.gestionarModulos,
      administrarMiembros: administrarMiembros ?? this.administrarMiembros,
      editarTablero: editarTablero ?? this.editarTablero,
    );
  }
}

/// Información del rol Kanban y permisos de un integrante
class MiembroTableroInfo {
  final String usuarioId;
  final String rolKanban;
  final bool esAdmin;
  final PermisosMiembro permisos;

  const MiembroTableroInfo({
    required this.usuarioId,
    this.rolKanban = 'Programador / Desarrollador',
    this.esAdmin = false,
    this.permisos = const PermisosMiembro(),
  });

  factory MiembroTableroInfo.fromMap(String id, Map<String, dynamic>? map) {
    if (map == null) {
      return MiembroTableroInfo(usuarioId: id);
    }
    return MiembroTableroInfo(
      usuarioId: id,
      rolKanban: map['rolKanban'] ?? 'Programador / Desarrollador',
      esAdmin: map['esAdmin'] ?? false,
      permisos: PermisosMiembro.fromMap(
        map['permisos'] != null ? Map<String, dynamic>.from(map['permisos']) : null,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuarioId': usuarioId,
      'rolKanban': rolKanban,
      'esAdmin': esAdmin,
      'permisos': permisos.toMap(),
    };
  }

  MiembroTableroInfo copyWith({
    String? usuarioId,
    String? rolKanban,
    bool? esAdmin,
    PermisosMiembro? permisos,
  }) {
    return MiembroTableroInfo(
      usuarioId: usuarioId ?? this.usuarioId,
      rolKanban: rolKanban ?? this.rolKanban,
      esAdmin: esAdmin ?? this.esAdmin,
      permisos: permisos ?? this.permisos,
    );
  }
}

class Tablero {
  final String id;
  final String nombre;
  final String? descripcion;

  /// Indica si el tablero es individual o grupal
  final bool esGrupal;

  /// Usuario que creó el tablero (Dueño Principal con permisos inmutables)
  final String creadorId;

  /// Integrantes del tablero (vacío si es individual)
  final List<String> miembrosIds;

  /// Información detallada de roles y permisos de los integrantes
  final Map<String, MiembroTableroInfo> miembrosInfo;

  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  /// Color opcional del tablero
  final String? color;

  /// Permite ocultar/desactivar tableros sin eliminarlos
  final bool activo;

  /// Módulos adicionales activados para el tablero
  final bool tieneCalendario;
  final bool tieneNotas;
  final bool tieneRecordatorios;

  /// Configuración adicional
  final Map<String, dynamic>? configuracion;

  const Tablero({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.esGrupal,
    required this.creadorId,
    this.miembrosIds = const [],
    this.miembrosInfo = const {},
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.color,
    this.activo = true,
    this.tieneCalendario = true,
    this.tieneNotas = true,
    this.tieneRecordatorios = true,
    this.configuracion,
  });

  factory Tablero.fromMap(String id, Map<String, dynamic> map) {
    Map<String, MiembroTableroInfo> infoMap = {};
    if (map['miembrosInfo'] != null) {
      final rawMap = Map<String, dynamic>.from(map['miembrosInfo']);
      rawMap.forEach((key, value) {
        infoMap[key] = MiembroTableroInfo.fromMap(
          key,
          value != null ? Map<String, dynamic>.from(value) : null,
        );
      });
    }

    return Tablero(
      id: id,
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'],
      esGrupal: map['esGrupal'] ?? false,
      creadorId: map['creadorId'] ?? '',
      miembrosIds: List<String>.from(map['miembrosIds'] ?? []),
      miembrosInfo: infoMap,
      fechaCreacion:
          (map['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaActualizacion:
          (map['fechaActualizacion'] as Timestamp?)?.toDate(),
      color: map['color'],
      activo: map['activo'] ?? true,
      tieneCalendario: map['tieneCalendario'] ?? true,
      tieneNotas: map['tieneNotas'] ?? true,
      tieneRecordatorios: map['tieneRecordatorios'] ?? true,
      configuracion: map['configuracion'] != null
          ? Map<String, dynamic>.from(map['configuracion'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> infoMapData = {};
    miembrosInfo.forEach((key, value) {
      infoMapData[key] = value.toMap();
    });

    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'esGrupal': esGrupal,
      'creadorId': creadorId,
      'miembrosIds': miembrosIds,
      'miembrosInfo': infoMapData,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaActualizacion': fechaActualizacion != null
          ? Timestamp.fromDate(fechaActualizacion!)
          : null,
      'color': color,
      'activo': activo,
      'tieneCalendario': tieneCalendario,
      'tieneNotas': tieneNotas,
      'tieneRecordatorios': tieneRecordatorios,
      'configuracion': configuracion,
    };
  }

  /// Retorna si el usuario dado es el Dueño Principal (Creador)
  bool esCreador(String userId) => userId == creadorId;

  /// Retorna si el usuario dado es Admin (Co-dueño) o el Dueño Principal
  bool esAdminOCreador(String userId) {
    if (userId == creadorId) return true;
    return miembrosInfo[userId]?.esAdmin ?? false;
  }

  /// Retorna la estructura de permisos efectiva para un usuario
  PermisosMiembro obtenerPermisosDeUsuario(String userId) {
    // El creador original SIEMPRE tiene todos los permisos (Inmutable)
    if (userId == creadorId) {
      return PermisosMiembro.todos;
    }
    final info = miembrosInfo[userId];
    if (info != null) {
      if (info.esAdmin) {
        return PermisosMiembro.todos;
      }
      return info.permisos;
    }
    // Si es un miembro registrado pero no tiene objeto específico
    if (miembrosIds.contains(userId)) {
      return const PermisosMiembro();
    }
    // Si no pertenece al tablero
    return const PermisosMiembro(
      crearTareas: false,
      editarTareas: false,
      eliminarTareas: false,
      moverTareas: false,
      gestionarModulos: false,
      administrarMiembros: false,
      editarTablero: false,
    );
  }

  Tablero copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    bool? esGrupal,
    String? creadorId,
    List<String>? miembrosIds,
    Map<String, MiembroTableroInfo>? miembrosInfo,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    String? color,
    bool? activo,
    bool? tieneCalendario,
    bool? tieneNotas,
    bool? tieneRecordatorios,
    Map<String, dynamic>? configuracion,
  }) {
    return Tablero(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      esGrupal: esGrupal ?? this.esGrupal,
      creadorId: creadorId ?? this.creadorId,
      miembrosIds: miembrosIds ?? this.miembrosIds,
      miembrosInfo: miembrosInfo ?? this.miembrosInfo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      color: color ?? this.color,
      activo: activo ?? this.activo,
      tieneCalendario: tieneCalendario ?? this.tieneCalendario,
      tieneNotas: tieneNotas ?? this.tieneNotas,
      tieneRecordatorios: tieneRecordatorios ?? this.tieneRecordatorios,
      configuracion: configuracion ?? this.configuracion,
    );
  }
}

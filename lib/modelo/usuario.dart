import 'package:cloud_firestore/cloud_firestore.dart';

class Usuario {
  final String id;
  final String email;
  final String nombreCompleto;
  final String? fotoPerfil;
  final DateTime fechaRegistro;
  final bool emailVerificado;
  final String rol; // 'estudiante', 'docente', 'admin'
  final List<String> tablerosIds; // Tableros a los que pertenece
  final bool activo;

  Usuario({
    required this.id,
    required this.email,
    required this.nombreCompleto,
    this.fotoPerfil,
    required this.fechaRegistro,
    this.emailVerificado = false,
    this.rol = 'estudiante',
    this.tablerosIds = const [],
    this.activo = true,
  });

  factory Usuario.fromMap(String id, Map<String, dynamic> map) {
    return Usuario(
      id: id,
      email: map['email'] ?? '',
      nombreCompleto: map['nombreCompleto'] ?? '',
      fotoPerfil: map['fotoPerfil'],
      fechaRegistro: (map['fechaRegistro'] as Timestamp?)?.toDate() ?? DateTime.now(),
      emailVerificado: map['emailVerificado'] ?? false,
      rol: map['rol'] ?? 'estudiante',
      tablerosIds: List<String>.from(map['tablerosIds'] ?? []),
      activo: map['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nombreCompleto': nombreCompleto,
      'fotoPerfil': fotoPerfil,
      'fechaRegistro': Timestamp.fromDate(fechaRegistro),
      'emailVerificado': emailVerificado,
      'rol': rol,
      'tablerosIds': tablerosIds,
      'activo': activo,
    };
  }

  Usuario copyWith({
    String? id,
    String? email,
    String? nombreCompleto,
    String? fotoPerfil,
    DateTime? fechaRegistro,
    bool? emailVerificado,
    String? rol,
    List<String>? tablerosIds,
    bool? activo,
  }) {
    return Usuario(
      id: id ?? this.id,
      email: email ?? this.email,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      fotoPerfil: fotoPerfil ?? this.fotoPerfil,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      emailVerificado: emailVerificado ?? this.emailVerificado,
      rol: rol ?? this.rol,
      tablerosIds: tablerosIds ?? this.tablerosIds,
      activo: activo ?? this.activo,
    );
  }
}
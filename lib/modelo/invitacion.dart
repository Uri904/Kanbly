class Invitacion {
  final String id;
  final String tableroId;
  final String tableroNombre;
  final String invitadoId;
  final String invitadoEmail;
  final String invitadoPor;
  final String rol;
  final String estado;
  final DateTime? fechaCreacion;

  Invitacion({
    required this.id,
    required this.tableroId,
    required this.tableroNombre,
    required this.invitadoId,
    required this.invitadoEmail,
    required this.invitadoPor,
    required this.rol,
    required this.estado,
    this.fechaCreacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'tableroId': tableroId,
      'tableroNombre': tableroNombre,
      'invitadoId': invitadoId,
      'invitadoEmail': invitadoEmail,
      'invitadoPor': invitadoPor,
      'rol': rol,
      'estado': estado,
      'fechaCreacion': fechaCreacion,
    };
  }

  factory Invitacion.fromMap(
      String id,
      Map<String, dynamic> map,
      ) {
    return Invitacion(
      id: id,
      tableroId: map['tableroId'] ?? '',
      tableroNombre: map['tableroNombre'] ?? '',
      invitadoId: map['invitadoId'] ?? '',
      invitadoEmail: map['invitadoEmail'] ?? '',
      invitadoPor: map['invitadoPor'] ?? '',
      rol: map['rol'] ?? '',
      estado: map['estado'] ?? 'pendiente',
      fechaCreacion: map['fechaCreacion'] != null
          ? map['fechaCreacion'].toDate()
          : null,
    );
  }
}
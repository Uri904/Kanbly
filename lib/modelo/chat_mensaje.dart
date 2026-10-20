/// Rol del emisor de un mensaje en la conversación del asistente IA.
enum RolMensaje {
  /// Mensaje enviado por el usuario.
  usuario,

  /// Mensaje respondido por la Inteligencia Artificial.
  asistente,
}

/// Representa un mensaje individual dentro de la sesión de chat con la IA.
class ChatMensaje {
  /// Identificador único del mensaje.
  final String id;

  /// Rol de quien envió el mensaje (usuario o asistente).
  final RolMensaje rol;

  /// Contenido textual del mensaje.
  final String texto;

  /// Momento en el que se creó o recibió el mensaje.
  final DateTime fecha;

  /// Indica si el mensaje representa un mensaje de error para la UI.
  final bool esError;

  const ChatMensaje({
    required this.id,
    required this.rol,
    required this.texto,
    required this.fecha,
    this.esError = false,
  });

  /// Crea una copia del mensaje modificando atributos específicos.
  ChatMensaje copyWith({
    String? id,
    RolMensaje? rol,
    String? texto,
    DateTime? fecha,
    bool? esError,
  }) {
    return ChatMensaje(
      id: id ?? this.id,
      rol: rol ?? this.rol,
      texto: texto ?? this.texto,
      fecha: fecha ?? this.fecha,
      esError: esError ?? this.esError,
    );
  }
}

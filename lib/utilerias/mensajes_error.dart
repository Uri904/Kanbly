import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show HttpException, SocketException;

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

/// Excepción cuyo [mensaje] ya está redactado en español para el usuario.
///
/// Su `toString()` devuelve únicamente el mensaje amigable, de modo que aunque
/// alguien la interpole por descuido (`'$e'`) nunca se exponga un detalle técnico.
/// El error original queda disponible en [causa] solo para diagnóstico.
class KanblyException implements Exception {
  const KanblyException(this.mensaje, {this.causa});

  final String mensaje;
  final Object? causa;

  @override
  String toString() => mensaje;
}

/// Traduce cualquier error a un texto claro para el usuario y registra el
/// detalle técnico únicamente en el sistema de logs (consola / DevTools).
class MensajesError {
  MensajesError._();

  /// Gancho opcional para capturar los logs (usado en pruebas o para enviar
  /// a Crashlytics en el futuro). Recibe contexto, error y stack trace.
  static void Function(String contexto, Object? error, StackTrace? stackTrace)?
  onLog;

  static const String _generico =
      'Algo salió mal. Inténtalo de nuevo en unos momentos.';
  static const String mensajeSinConexion =
      'No hay conexión a internet. Revisa tu red e inténtalo de nuevo.';
  static const String mensajeSesionExpirada =
      'Tu sesión expiró. Vuelve a iniciar sesión para continuar.';
  static const String mensajeSinPermiso =
      'No tienes permiso para realizar esta acción.';

  /// Devuelve el mensaje amigable para [error].
  ///
  /// [accion] completa la frase genérica: "No pudimos {accion}". Ejemplo:
  /// `MensajesError.desde(e, accion: 'guardar el tablero')`.
  static String desde(
      Object? error, {
        String accion = 'completar la operación',
        StackTrace? stackTrace,
      }) {
    registrar(error, stackTrace: stackTrace, contexto: accion);
    return _traducir(error, accion);
  }

  /// Igual que [desde] pero devuelve una [KanblyException] lista para lanzar
  /// desde la capa de servicios. Si [error] ya es amigable, se conserva.
  static KanblyException envolver(
      Object error, {
        required String accion,
        StackTrace? stackTrace,
      }) {
    if (error is KanblyException) return error;
    registrar(error, stackTrace: stackTrace, contexto: accion);
    return KanblyException(_traducir(error, accion), causa: error);
  }

  /// Registra el detalle técnico SOLO en consola/logs.
  static void registrar(
      Object? error, {
        StackTrace? stackTrace,
        String contexto = '',
      }) {
    if (error == null || error is KanblyException) return;
    developer.log(
      'Error técnico${contexto.isEmpty ? '' : ' al $contexto'}',
      name: 'Kanbly',
      error: error,
      stackTrace: stackTrace,
    );
    onLog?.call(contexto, error, stackTrace);
  }

  /// Traduce los códigos de `speech_to_text` (p. ej. `error_no_match`) a texto claro.
  static String mensajeMicrofono(String? codigo) {
    registrar(codigo, contexto: 'usar el micrófono');
    switch (codigo) {
      case 'error_permission':
        return 'Kanbly necesita permiso para usar el micrófono. Actívalo en los ajustes del teléfono.';
      case 'error_no_match':
      case 'error_speech_timeout':
        return 'No logramos escucharte bien. Habla más cerca del micrófono e inténtalo de nuevo.';
      case 'error_network':
      case 'error_network_timeout':
      case 'error_server':
        return 'El reconocimiento de voz necesita internet. Revisa tu conexión e inténtalo de nuevo.';
      case 'error_audio':
      case 'error_busy':
      case 'error_client':
        return 'No pudimos usar el micrófono ahora. Ciérralo en otras apps e inténtalo de nuevo.';
      default:
        return 'No pudimos usar el micrófono. Inténtalo de nuevo.';
    }
  }

  // ---------------------------------------------------------------------------

  static String _traducir(Object? error, String accion) {
    final fallback = 'No pudimos $accion. Inténtalo de nuevo en unos momentos.';

    if (error == null) return fallback;
    if (error is KanblyException) return error.mensaje;

    // FirebaseAuthException hereda de FirebaseException: se evalúa primero.
    if (error is FirebaseAuthException) {
      return _mensajeAuth(error.code) ?? fallback;
    }
    if (error is FirebaseException) {
      return _mensajeFirebase(error.code) ?? fallback;
    }
    if (error is TimeoutException) {
      return 'La operación tardó demasiado. Revisa tu conexión e inténtalo de nuevo.';
    }
    if (error is SocketException || error is HttpException) {
      return mensajeSinConexion;
    }
    if (error is FormatException) {
      return 'El archivo o los datos recibidos no tienen un formato válido.';
    }

    // Los `Error` de Dart (StateError, TypeError, RangeError, ArgumentError...)
    // son fallos de programación: nunca se muestran al usuario.
    if (error is Error) return fallback;

    final tipo = error.runtimeType.toString();
    if (tipo.contains('SocketException') ||
        tipo.contains('ClientException') ||
        tipo.contains('HandshakeException')) {
      return mensajeSinConexion;
    }
    if (tipo.contains('PlatformException')) {
      return 'No pudimos acceder a la función del dispositivo. '
          'Revisa que la app tenga los permisos necesarios.';
    }

    // Excepciones genéricas (`Exception('texto')`) o textos sueltos: solo se
    // muestran si el texto es claramente un mensaje escrito para personas.
    var texto = error.toString().trim();
    if (texto.startsWith('Exception:')) {
      texto = texto.substring('Exception:'.length).trim();
    }
    final porCodigo = _mensajePorTextoTecnico(texto);
    if (porCodigo != null) return porCodigo;
    if (texto.isNotEmpty && !_pareceTecnico(texto)) return texto;

    return fallback;
  }

  /// Si el texto trae el patrón `[plugin/codigo]` de Firebase, lo traduce.
  static String? _mensajePorTextoTecnico(String texto) {
    final m = RegExp(r'\[([a-z_\-]+)/([a-z\-]+)\]').firstMatch(texto);
    if (m == null) return null;
    final plugin = m.group(1)!;
    final codigo = m.group(2)!;
    if (plugin == 'firebase_auth') return _mensajeAuth(codigo);
    return _mensajeFirebase(codigo);
  }

  static bool _pareceTecnico(String texto) {
    final t = texto.toLowerCase();
    const huellas = [
      'exception',
      'error:',
      'stack',
      '#0 ',
      'package:',
      'dart:',
      'null check',
      'is not a subtype',
      "type '",
      'status code',
      'statuscode',
      'firebase',
      'firestore',
      'platformexception',
      'socket',
      'errno',
      'unhandled',
      'instance of',
      'nosuchmethod',
      'rangeerror',
      'typeerror',
    ];
    if (huellas.any(t.contains)) return true;
    if (RegExp(r'\b[45]\d{2}\b').hasMatch(t) &&
        (t.contains('http') || t.contains('code') || t.contains('status'))) {
      return true;
    }
    if (RegExp(r'\[[^\]]*/[^\]]*\]').hasMatch(t)) return true;
    // Códigos HTTP entre paréntesis y cuerpos JSON de respuestas de servidores.
    if (RegExp(r'\(\s*[1-5]\d{2}\s*\)').hasMatch(t)) return true;
    if (t.contains('{"') || t.contains('":') || t.contains('{\n')) return true;
    if (texto.length > 220) return true;
    return false;
  }

  static String? _mensajeAuth(String codigo) {
    switch (codigo) {
      case 'invalid-email':
        return 'El correo no tiene un formato válido. Revísalo e inténtalo de nuevo.';
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'El correo o la contraseña son incorrectos.';
      case 'user-disabled':
        return 'Esta cuenta está desactivada. Contacta al administrador de Kanbly.';
      case 'too-many-requests':
        return 'Hiciste demasiados intentos. Espera unos minutos antes de volver a intentarlo.';
      case 'network-request-failed':
        return mensajeSinConexion;
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo. Inicia sesión o recupera tu contraseña.';
      case 'weak-password':
        return 'La contraseña es muy débil. Usa al menos 6 caracteres con letras y números.';
      case 'requires-recent-login':
      case 'user-token-expired':
      case 'no-current-user':
      case 'invalid-user-token':
        return mensajeSesionExpirada;
      case 'expired-action-code':
      case 'invalid-action-code':
        return 'El enlace ya no es válido. Solicita uno nuevo.';
      case 'operation-not-allowed':
        return 'Esta acción no está disponible por ahora. Contacta al administrador.';
      default:
        return null;
    }
  }

  static String? _mensajeFirebase(String codigo) {
    switch (codigo) {
      case 'permission-denied':
      case 'unauthorized':
        return mensajeSinPermiso;
      case 'unauthenticated':
        return mensajeSesionExpirada;
      case 'unavailable':
      case 'network-request-failed':
        return mensajeSinConexion;
      case 'deadline-exceeded':
      case 'retry-limit-exceeded':
        return 'La operación tardó demasiado. Revisa tu conexión e inténtalo de nuevo.';
      case 'not-found':
      case 'object-not-found':
        return 'No encontramos lo que buscabas. Es posible que ya haya sido eliminado.';
      case 'already-exists':
        return 'Ya existe un elemento con esos datos.';
      case 'resource-exhausted':
      case 'quota-exceeded':
        return 'El servicio está saturado en este momento. Inténtalo más tarde.';
      case 'aborted':
      case 'cancelled':
      case 'canceled':
        return 'La operación se interrumpió. Inténtalo de nuevo.';
      case 'failed-precondition':
        return 'No pudimos completar la acción en este momento. Inténtalo más tarde.';
      default:
        return null;
    }
  }
}
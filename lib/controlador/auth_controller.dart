import 'package:flutter/material.dart';
import '../modelo/usuario.dart';
import '../servicios/auth_service.dart';
import '../servicios/firestore_service.dart';
import '../servicios/encryption_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error
}

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  AuthStatus _status = AuthStatus.initial;
  Usuario? _usuarioActual;
  String? _errorMessage;

  AuthStatus get status => _status;
  Usuario? get usuarioActual => _usuarioActual;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // Método para registrar usuario
  Future<bool> register({
    required String email,
    required String password,
    required String nombreCompleto,
  }) async {
    try {
      _setStatus(AuthStatus.loading);
      _clearError();

      print('📝 [REGISTER] Intentando registrar: $email');

      // Validar dominio
      if (!_authService.validarDominioInstitucional(email)) {
        throw Exception('Solo se permiten correos institucionales @e.uttecamac.edu.mx');
      }

      // Registrar en Firebase Auth
      print('🔐 [REGISTER] Creando usuario en Firebase Auth...');
      final userCredential = await _authService.registrarConEmailYPassword(
        email,
        password,
        nombreCompleto,
      );
      print('✅ [REGISTER] Usuario creado en Auth: ${userCredential.user!.uid}');

      // Crear usuario
      final usuario = Usuario(
        id: userCredential.user!.uid,
        email: email,
        nombreCompleto: nombreCompleto,
        fechaRegistro: DateTime.now(),
        emailVerificado: false,
        rol: 'estudiante',
        tablerosIds: [],
        activo: true,
      );

      print('📦 [REGISTER] Usuario creado: ${usuario.nombreCompleto}');

      // ✅ GUARDAR EN FIRESTORE CON RETRY
      print('💾 [REGISTER] Guardando usuario en Firestore...');

      bool guardado = false;
      int intentos = 0;
      while (!guardado && intentos < 3) {
        try {
          await _firestoreService.crearUsuario(usuario);
          guardado = true;
          print('✅ [REGISTER] Usuario guardado en Firestore (intento ${intentos + 1})');
        } catch (e) {
          intentos++;
          print('⚠️ [REGISTER] Intento $intentos falló: $e');
          if (intentos >= 3) {
            // Si falla, eliminar usuario de Auth
            await userCredential.user?.delete();
            throw Exception('Error al guardar usuario en la base de datos después de 3 intentos');
          }
          await Future.delayed(Duration(seconds: 1));
        }
      }

      _usuarioActual = usuario;
      _setStatus(AuthStatus.authenticated);
      print('✅ [REGISTER] Registro completado exitosamente');
      return true;

    } catch (e) {
      print('❌ [REGISTER] Error: $e');
      _setError(e.toString());
      _setStatus(AuthStatus.error);
      return false;
    }
  }

  // Método para iniciar sesión
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      _setStatus(AuthStatus.loading);
      _clearError();

      // Validar dominio institucional
      if (!_authService.validarDominioInstitucional(email)) {
        throw Exception('Solo se permiten correos institucionales @e.uttecamac.edu.mx');
      }

      // Encriptar contraseña para verificación
      final encryptedPassword = EncryptionService.encryptPassword(password);

      // Iniciar sesión en Firebase Auth
      final userCredential = await _authService.loginConEmailYPassword(email, password);

      // Obtener usuario de Firestore
      final usuario = await _firestoreService.obtenerUsuario(userCredential.user!.uid);

      if (usuario == null) {
        throw Exception('Usuario no encontrado en la base de datos');
      }

      if (!usuario.activo) {
        throw Exception('Usuario desactivado. Contacta al administrador');
      }

      _usuarioActual = usuario;
      _setStatus(AuthStatus.authenticated);
      return true;

    } catch (e) {
      _setError(e.toString());
      _setStatus(AuthStatus.error);
      return false;
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    try {
      await _authService.logout();
      _usuarioActual = null;
      _setStatus(AuthStatus.unauthenticated);
    } catch (e) {
      _setError(e.toString());
      _setStatus(AuthStatus.error);
    }
  }

  // Verificar estado de autenticación
  Future<void> checkAuthStatus() async {
    try {
      final user = _authService.getCurrentUser();
      if (user != null) {
        final usuario = await _firestoreService.obtenerUsuario(user.uid);
        if (usuario != null && usuario.activo) {
          _usuarioActual = usuario;
          _setStatus(AuthStatus.authenticated);
          return;
        }
      }
      _setStatus(AuthStatus.unauthenticated);
    } catch (e) {
      _setError(e.toString());
      _setStatus(AuthStatus.error);
    }
  }

  // Enviar correo de verificación
  Future<bool> sendVerificationEmail() async {
    try {
      await _authService.sendVerificationEmail();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Restablecer contraseña
  Future<bool> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Guardar contraseña encriptada
  Future<void> _saveEncryptedPassword(String encryptedPassword) async {
    // Implementar si se quiere guardar en SharedPreferences
  }

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Limpiar errores manualmente
  void clearError() {
    _clearError();
  }

  // Obtener nombre del usuario
  String get userName => _usuarioActual?.nombreCompleto ?? 'Usuario';

  // Obtener email del usuario
  String get userEmail => _usuarioActual?.email ?? '';

  // Obtener rol del usuario
  String get userRole => _usuarioActual?.rol ?? 'estudiante';
}
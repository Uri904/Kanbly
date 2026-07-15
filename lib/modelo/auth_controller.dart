import 'package:flutter/material.dart';
import '../modelo/usuario.dart';
import '../servicios/auth_service.dart';
import '../servicios/firestore_service.dart';

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
        print('❌ [REGISTER] Dominio inválido');
        throw Exception('Solo se permiten correos institucionales @e.uttecamac.edu.mx');
      }

      // 1. Registrar en Firebase Auth
      print('🔐 [REGISTER] Creando usuario en Firebase Auth...');
      final userCredential = await _authService.registerUser(email, password);
      print('✅ [REGISTER] Usuario creado en Auth: ${userCredential.user!.uid}');

      // 2. Crear objeto Usuario
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

      // 3. ✅ GUARDAR EN FIRESTORE CON MÉTODO DIRECTO
      print('💾 [REGISTER] Guardando usuario en Firestore...');
      try {
        await _firestoreService.guardarUsuarioDirecto(usuario);
        print('✅ [REGISTER] Usuario guardado en Firestore');
      } catch (firestoreError) {
        print('❌ [REGISTER] Error al guardar en Firestore: $firestoreError');
        // Si falla Firestore, eliminamos el usuario de Auth
        await userCredential.user?.delete();
        throw Exception('Error al guardar usuario en la base de datos: $firestoreError');
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


  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      _setStatus(AuthStatus.loading);
      _clearError();

      print('📝 [LOGIN] Intentando login: $email');

      // 1. Autenticar en Firebase Auth
      print('🔐 [LOGIN] Autenticando en Firebase Auth...');
      final userCredential = await _authService.loginUser(email, password);
      print('✅ [LOGIN] Usuario autenticado: ${userCredential.user!.uid}');

      // 2. Buscar en Firestore
      print('🔍 [LOGIN] Buscando usuario en Firestore...');
      final usuario = await _firestoreService.obtenerUsuario(userCredential.user!.uid);

      if (usuario == null) {
        print('❌ [LOGIN] Usuario NO encontrado en Firestore');
        throw Exception('Usuario no encontrado en la base de datos');
      }

      print('✅ [LOGIN] Usuario encontrado: ${usuario.nombreCompleto}');

      if (!usuario.activo) {
        throw Exception('Usuario desactivado. Contacta al administrador');
      }

      _usuarioActual = usuario;
      _setStatus(AuthStatus.authenticated);
      print('✅ [LOGIN] Login completado exitosamente');
      return true;

    } catch (e) {
      print('❌ [LOGIN] Error: $e');
      _setError(e.toString());
      _setStatus(AuthStatus.error);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logoutUser();
      _usuarioActual = null;
      _setStatus(AuthStatus.unauthenticated);
      print('✅ [LOGOUT] Sesión cerrada');
    } catch (e) {
      print('❌ [LOGOUT] Error: $e');
      _setError(e.toString());
      _setStatus(AuthStatus.error);
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      final user = _authService.getCurrentUser();
      if (user != null) {
        print('🔍 [CHECK] Usuario autenticado: ${user.uid}');
        final usuario = await _firestoreService.obtenerUsuario(user.uid);
        if (usuario != null && usuario.activo) {
          _usuarioActual = usuario;
          _setStatus(AuthStatus.authenticated);
          print('✅ [CHECK] Usuario cargado: ${usuario.nombreCompleto}');
          return;
        } else {
          print('⚠️ [CHECK] Usuario no encontrado en Firestore o inactivo');
        }
      } else {
        print('🔍 [CHECK] No hay usuario autenticado');
      }
      _setStatus(AuthStatus.unauthenticated);
    } catch (e) {
      print('❌ [CHECK] Error: $e');
      _setError(e.toString());
      _setStatus(AuthStatus.error);
    }
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

  void clearError() {
    _clearError();
  }

  String get userName => _usuarioActual?.nombreCompleto ?? 'Usuario';
  String get userEmail => _usuarioActual?.email ?? '';
  String get userRole => _usuarioActual?.rol ?? 'estudiante';
}
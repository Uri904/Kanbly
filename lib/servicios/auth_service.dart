// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelo/usuario.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Validar dominio institucional
  bool validarDominioInstitucional(String email) {
    final dominio = email.split('@').last;
    return dominio == 'e.uttecamac.edu.mx';
  }

  // Registrar usuario con validación de dominio
  Future<UserCredential> registrarConEmailYPassword(
      String email,
      String password,
      String nombreCompleto,
      ) async {
    try {
      // Validar dominio institucional
      if (!validarDominioInstitucional(email)) {
        throw Exception('Solo se permiten correos institucionales @e.uttecamac.edu.mx');
      }

      // Crear usuario en Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Crear documento en Firestore
      final usuario = Usuario(
        id: userCredential.user!.uid,
        email: email,
        nombreCompleto: nombreCompleto,
        fechaRegistro: DateTime.now(),
        emailVerificado: false,
        rol: 'estudiante',
      );

      await _firestore.collection('usuarios').doc(usuario.id).set(usuario.toMap());

      return userCredential;
    } catch (e) {
      throw Exception('Error al registrar usuario: $e');
    }
  }

  // Iniciar sesión
  Future<UserCredential> loginConEmailYPassword(
      String email,
      String password,
      ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Obtener usuario actual
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Stream de cambios de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Obtener datos del usuario desde Firestore
  Future<Usuario?> obtenerUsuarioActual() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      if (doc.exists) {
        return Usuario.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener usuario actual: $e');
    }
  }

  // Stream del usuario actual en Firestore
  Stream<Usuario?> streamUsuarioActual() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('usuarios')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? Usuario.fromMap(doc.id, doc.data()!) : null);
  }

  // Enviar email de verificación
  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Enviar correo de restablecimiento de contraseña
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Error al enviar correo de restablecimiento: $e');
    }
  }
}
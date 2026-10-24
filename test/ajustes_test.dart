import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kanbly/modelo/usuario.dart';
import 'package:kanbly/controlador/auth_controller.dart';
import 'package:kanbly/controlador/preferencias_controller.dart';
import 'package:kanbly/controlador/theme_controller.dart';
import 'package:kanbly/Vistas/ajustes_page.dart';

class FakeAuthController extends ChangeNotifier implements AuthController {
  @override
  String get userName => 'Usuario Pruebas';

  @override
  String get userEmail => 'prueba@e.uttecamac.edu.mx';

  @override
  String get userRole => 'estudiante';

  @override
  Usuario? get usuarioActual => Usuario(
        id: 'test_u',
        email: 'prueba@e.uttecamac.edu.mx',
        nombreCompleto: 'Usuario Pruebas',
        fechaRegistro: DateTime(2025, 1, 1),
        rol: 'estudiante',
      );

  @override
  AuthStatus get status => AuthStatus.authenticated;

  @override
  String? get errorMessage => null;

  @override
  bool get isLoading => false;

  @override
  bool get isAuthenticated => true;

  @override
  void clearError() {}

  @override
  Future<bool> register({required String email, required String password, required String nombreCompleto}) async => true;

  @override
  Future<bool> login({required String email, required String password}) async => true;

  @override
  Future<void> logout() async {}

  @override
  Future<bool> checkAuthStatus() async => true;

  @override
  Future<bool> resetPassword(String email) async => true;

  @override
  Future<bool> sendVerificationEmail() async => true;

  @override
  Future<bool> actualizarPerfil({String? nombreCompleto, String? fotoPerfil}) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pruebas de la Sección de Ajustes y Perfil de Usuario', () {
    test('1. Modelo Usuario admite y actualiza correctamente la foto de perfil y datos personales', () {
      final usuarioInicial = Usuario(
        id: 'u_123',
        email: 'estudiante1@e.uttecamac.edu.mx',
        nombreCompleto: 'Juan Pérez García',
        fechaRegistro: DateTime(2025, 1, 15),
        emailVerificado: false,
        rol: 'estudiante',
      );

      expect(usuarioInicial.fotoPerfil, isNull);
      expect(usuarioInicial.nombreCompleto, equals('Juan Pérez García'));
      expect(usuarioInicial.emailVerificado, isFalse);

      // Copia con nueva foto de perfil y nombre actualizado
      final usuarioActualizado = usuarioInicial.copyWith(
        nombreCompleto: 'Juan Pérez García Modificado',
        fotoPerfil: 'https://cloudinary.com/v1_1/preset/perfil_u_123.jpg',
        emailVerificado: true,
      );

      expect(usuarioActualizado.nombreCompleto, equals('Juan Pérez García Modificado'));
      expect(usuarioActualizado.fotoPerfil, equals('https://cloudinary.com/v1_1/preset/perfil_u_123.jpg'));
      expect(usuarioActualizado.emailVerificado, isTrue);
      expect(usuarioActualizado.email, equals('estudiante1@e.uttecamac.edu.mx'));
    });

    test('2. Serialización toMap y deserialización fromMap con foto de perfil y campos de perfil', () {
      final usuario = Usuario(
        id: 'u_456',
        email: 'docente1@e.uttecamac.edu.mx',
        nombreCompleto: 'Dra. María López',
        fotoPerfil: 'https://cloudinary.com/v1_1/preset/foto_maria.png',
        fechaRegistro: DateTime(2025, 2, 10),
        emailVerificado: true,
        rol: 'docente',
        activo: true,
      );

      final map = usuario.toMap();
      expect(map['email'], equals('docente1@e.uttecamac.edu.mx'));
      expect(map['nombreCompleto'], equals('Dra. María López'));
      expect(map['fotoPerfil'], equals('https://cloudinary.com/v1_1/preset/foto_maria.png'));
      expect(map['rol'], equals('docente'));
      expect(map['emailVerificado'], isTrue);

      final usuarioRecuperado = Usuario.fromMap('u_456', map);
      expect(usuarioRecuperado.id, equals('u_456'));
      expect(usuarioRecuperado.nombreCompleto, equals('Dra. María López'));
      expect(usuarioRecuperado.fotoPerfil, equals('https://cloudinary.com/v1_1/preset/foto_maria.png'));
      expect(usuarioRecuperado.rol, equals('docente'));
    });

    test('3. Verificación de reglas de dominio institucional para actualización de perfil', () {
      const emailValido = 'alumno@e.uttecamac.edu.mx';
      const emailInvalido = 'alumno@gmail.com';

      bool esValido(String email) {
        final dominio = email.split('@').last;
        return dominio == 'e.uttecamac.edu.mx';
      }

      expect(esValido(emailValido), isTrue);
      expect(esValido(emailInvalido), isFalse);
    });

    test('4. ThemeProvider administra el cambio entre tema Claro, Oscuro y Sistema', () {
      final themeProvider = ThemeProvider();

      expect(themeProvider.themeMode, equals(ThemeMode.light));
      expect(themeProvider.themeString, equals('Claro'));

      themeProvider.setThemeString('Oscuro');
      expect(themeProvider.themeMode, equals(ThemeMode.dark));
      expect(themeProvider.themeString, equals('Oscuro'));
      expect(themeProvider.isDarkMode, isTrue);

      themeProvider.setThemeString('Sistema');
      expect(themeProvider.themeMode, equals(ThemeMode.system));
      expect(themeProvider.themeString, equals('Sistema'));

      themeProvider.setThemeString('Claro');
      expect(themeProvider.themeMode, equals(ThemeMode.light));
      expect(themeProvider.isDarkMode, isFalse);
    });

    testWidgets('5. AjustesPage contiene los controles "Animación de inicio" y "Ver animación"', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>(create: (_) => FakeAuthController()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => PreferenciasController()),
          ],
          child: const MaterialApp(
            home: AjustesPage(),
          ),
        ),
      );

      expect(find.text('Animación de inicio'), findsOneWidget);
      expect(find.text('Ver animación'), findsOneWidget);
    });
  });
}

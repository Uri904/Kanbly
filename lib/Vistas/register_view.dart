import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../controlador/auth_controller.dart';
import '../utilerias/validators.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  File? _imagenPerfil;
  String _rutaImagen = '';
  final ImagePicker _picker = ImagePicker();

  // Colores definidos con hex (no usar shade en constantes)
  static const Color azulCielo = Color(0xFF52ABEB);
  static const Color azulClaro = Color(0xFF37B5F4);
  static const Color blanco = Color(0xFFFCFDFD);
  static const Color gris50 = Color(0xFFFAFAFA);
  static const Color gris200 = Color(0xFFEEEEEE);
  static const Color gris300 = Color(0xFFE0E0E0);
  static const Color gris400 = Color(0xFFBDBDBD);
  static const Color gris600 = Color(0xFF757575);
  static const Color gris700 = Color(0xFF616161);
  static const Color rojo50 = Color(0xFFFFEBEE);
  static const Color rojo200 = Color(0xFFEF9A9A);
  static const Color rojo700 = Color(0xFFD32F2F);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final String nuevaRuta = '${directory.path}/${pickedFile.name}';
      final File imagenGuardada = await File(pickedFile.path).copy(nuevaRuta);

      setState(() {
        _imagenPerfil = imagenGuardada;
        _rutaImagen = imagenGuardada.path;
      });
    } catch (e) {
      print('Error al seleccionar imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al seleccionar imagen'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarTerminos() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.assignment, color: azulCielo),
              const SizedBox(width: 10),
              const Text('Aviso de Privacidad'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(
              maxHeight: 400,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aviso de Privacidad',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Se informa que los datos personales recabados en el cuestionario '
                        'denominado Cuestionario de información Médica para Estudiantes '
                        'de Nuevo Ingreso, consistente en: nombre completo, edad, sexo, '
                        'condiciones médicas, alergias, discapacidades, y trastornos '
                        'diagnosticados, serán utilizados exclusivamente para fines '
                        'académicos y de seguimiento médico preventivo, en el marco del '
                        'proyecto titulado "Valoración del estado de salud de los '
                        'estudiantes de nuevo ingreso de la Universidad Tecnológica de '
                        'Tecámac", con la finalidad de: detectar oportunamente condiciones '
                        'que puedan requerir atención o ajustes en su entorno académico, '
                        'así como brindar acompañamiento y canalización si fuera necesario.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Los datos recabados no serán transferidos a terceros sin '
                        'consentimiento expreso, salvo en los casos previstos por la Ley '
                        'De Protección de Datos Personales en Posesión de Sujetos '
                        'Obligados del Estado de México y Municipios, sin embargo, los '
                        'resultados del cuestionario podrán ser presentados en su conjunto '
                        'ante las autoridades.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Lo anterior, con fundamento en los artículos 6º, Base A y 16, '
                        'segundo párrafo, de la Constitución Política de los Estados '
                        'Unidos Mexicanos, artículos 15, 16, 17, 18, 19, 20, 21, 22, 24, 25, '
                        '26, 27 de la Ley De Protección de Datos Personales en Posesión '
                        'de Sujetos Obligados del Estado de México y Municipios.',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: gris700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _acceptedTerms = true;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: azulCielo,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Acepto los términos'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: gris600,
                          ),
                          child: const Text('Cerrar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blanco,
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        backgroundColor: azulCielo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Consumer<AuthController>(
          builder: (context, authController, child) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),

                      // Foto de Perfil
                      GestureDetector(
                        onTap: authController.isLoading ? null : _seleccionarImagen,
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 55,
                                  backgroundColor: gris200,
                                  backgroundImage: _imagenPerfil != null
                                      ? FileImage(_imagenPerfil!)
                                      : null,
                                  child: _imagenPerfil == null
                                      ? Icon(
                                    Icons.person_add,
                                    size: 50,
                                    color: gris400,
                                  )
                                      : null,
                                ),
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: azulCielo,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _imagenPerfil == null
                                  ? 'Toca para seleccionar foto de perfil'
                                  : 'Cambiar foto de perfil',
                              style: TextStyle(
                                color: azulCielo,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Nombre Completo
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre Completo',
                          prefixIcon: Icon(Icons.person_outline, color: azulCielo),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: gris300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: azulCielo, width: 2),
                          ),
                          filled: true,
                          fillColor: gris50,
                        ),
                        validator: Validators.validateName,
                        enabled: !authController.isLoading,
                      ),
                      const SizedBox(height: 14),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Correo Institucional',
                          hintText: 'ejemplo@e.uttecamac.edu.mx',
                          prefixIcon: Icon(Icons.email_outlined, color: azulCielo),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: gris300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: azulCielo, width: 2),
                          ),
                          filled: true,
                          fillColor: gris50,
                        ),
                        validator: Validators.validateInstitutionalEmail,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !authController.isLoading,
                      ),
                      const SizedBox(height: 14),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline, color: azulCielo),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: gris600,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: gris300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: azulCielo, width: 2),
                          ),
                          filled: true,
                          fillColor: gris50,
                        ),
                        validator: Validators.validatePassword,
                        enabled: !authController.isLoading,
                      ),
                      const SizedBox(height: 14),

                      // Confirm Password
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirmar Contraseña',
                          prefixIcon: Icon(Icons.lock_outline, color: azulCielo),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: gris600,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: gris300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: azulCielo, width: 2),
                          ),
                          filled: true,
                          fillColor: gris50,
                        ),
                        validator: (value) => Validators.validateConfirmPassword(
                          value,
                          _passwordController.text,
                        ),
                        enabled: !authController.isLoading,
                      ),
                      const SizedBox(height: 16),

                      // Términos y condiciones
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _acceptedTerms,
                            onChanged: authController.isLoading
                                ? null
                                : (value) {
                              setState(() {
                                _acceptedTerms = value ?? false;
                              });
                            },
                            activeColor: azulCielo,
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: gris700,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'He leído y acepto el ',
                                  ),
                                  TextSpan(
                                    text: 'Aviso de Privacidad',
                                    style: TextStyle(
                                      color: azulCielo,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = _mostrarTerminos,
                                  ),
                                  const TextSpan(
                                    text: ' y los términos de uso de la aplicación.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Error Message
                      if (authController.errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: rojo50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: rojo200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: rojo700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authController.errorMessage!,
                                  style: TextStyle(color: rojo700),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Register Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: authController.isLoading || !_acceptedTerms
                              ? null
                              : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: azulCielo,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: authController.isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                            'Crear Cuenta',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Back to Login
                      TextButton(
                        onPressed: authController.isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(
                          '¿Ya tienes cuenta? Inicia sesión',
                          style: TextStyle(color: azulCielo),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleRegister() {
    if (_formKey.currentState?.validate() ?? false) {
      final authController = Provider.of<AuthController>(context, listen: false);

      authController.register(
        email: _emailController.text,
        password: _passwordController.text,
        nombreCompleto: _nameController.text,
      );
    }
  }
}
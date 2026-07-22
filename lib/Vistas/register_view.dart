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

  // ✅ COLORES DE KANBLY
  static const Color azulCielo = Color(0xFF52ABEB);
  static const Color azulClaro = Color(0xFF37B5F4);
  static const Color verdeTurquesa = Color(0xFF63D0A1);
  static const Color verdeAgua = Color(0xFF63B09C);
  static const Color blanco = Color(0xFFFCFDFD);
  static const Color grisOscuro = Color(0xFF1E293B);

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.assignment, color: azulCielo, size: 24),
              const SizedBox(width: 10),
              const Text(
                'Aviso de Privacidad',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aviso de Privacidad - Kanbly',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'En Kanbly, nos comprometemos a proteger los datos personales de nuestros usuarios. Los datos recabados a través de la plataforma, que incluyen nombre completo, correo electrónico institucional, fotografía de perfil y preferencias de uso, serán utilizados exclusivamente para:',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Gestionar la autenticación y acceso a la plataforma.\n'
                        '• Facilitar la creación y administración de tableros y tareas colaborativas.\n'
                        '• Mejorar la experiencia de usuario mediante personalización.\n'
                        '• Realizar análisis estadísticos anónimos para optimizar el servicio.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Los datos personales no serán transferidos a terceros sin el consentimiento expreso del usuario, salvo en los casos previstos por la legislación aplicable en materia de protección de datos personales en posesión de sujetos obligados del Estado de México y Municipios.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Este tratamiento se fundamenta en los artículos 6°, Base A y 16 de la Constitución Política de los Estados Unidos Mexicanos, así como en la Ley General de Protección de Datos Personales en Posesión de Sujetos Obligados y la normativa aplicable del Estado de México.',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: verdeAgua,
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
                            backgroundColor: verdeTurquesa,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Acepto los términos'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: verdeAgua,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: verdeAgua.withOpacity(0.3)!),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: const Text(
            'Crear Cuenta',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [azulCielo, verdeTurquesa],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SafeArea(
        child: Consumer<AuthController>(
          builder: (context, authController, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    // ✅ FOTO DE PERFIL
                    GestureDetector(
                      onTap: authController.isLoading ? null : _seleccionarImagen,
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[100],
                                backgroundImage: _imagenPerfil != null
                                    ? FileImage(_imagenPerfil!)
                                    : null,
                                child: _imagenPerfil == null
                                    ? Icon(Icons.person_add, size: 40, color: verdeAgua)
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: verdeTurquesa,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 18,
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
                              color: verdeTurquesa,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ✅ NOMBRE COMPLETO - BORDE VERDE TURQUESA
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre Completo',
                        labelStyle: TextStyle(color: grisOscuro, fontSize: 14),
                        prefixIcon: Icon(Icons.person_outline, color: verdeTurquesa, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: verdeTurquesa.withOpacity(0.5)!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: verdeTurquesa.withOpacity(0.3)!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: verdeTurquesa, width: 2),
                        ),
                        filled: true,
                        fillColor: blanco,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      validator: Validators.validateName,
                      enabled: !authController.isLoading,
                    ),
                    const SizedBox(height: 14),

                    // ✅ CORREO INSTITUCIONAL - BORDE VERDE TURQUESA
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Correo Institucional',
                        labelStyle: TextStyle(color: grisOscuro, fontSize: 14),
                        hintText: 'ejemplo@e.uttecamac.edu.mx',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                        prefixIcon: Icon(Icons.email_outlined, color: verdeTurquesa, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: verdeTurquesa.withOpacity(0.5)!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: verdeTurquesa.withOpacity(0.3)!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: verdeTurquesa, width: 2),
                        ),
                        filled: true,
                        fillColor: blanco,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      validator: Validators.validateInstitutionalEmail,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !authController.isLoading,
                    ),
                    const SizedBox(height: 14),

                    // ✅ CONTRASEÑA - BORDE VERDE TURQUESA
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        labelStyle: TextStyle(color: grisOscuro, fontSize: 14),
                        prefixIcon: Icon(Icons.lock_outline, color: verdeTurquesa, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: verdeTurquesa.withOpacity(0.5)!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: verdeTurquesa.withOpacity(0.3)!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: verdeTurquesa, width: 2),
                        ),
                        filled: true,
                        fillColor: blanco,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      validator: Validators.validatePassword,
                      enabled: !authController.isLoading,
                    ),
                    const SizedBox(height: 14),

                    // ✅ CONFIRMAR CONTRASEÑA - BORDE VERDE TURQUESA
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirmar Contraseña',
                        labelStyle: TextStyle(color: grisOscuro, fontSize: 14),
                        prefixIcon: Icon(Icons.lock_outline, color: verdeTurquesa, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: verdeTurquesa.withOpacity(0.5)!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: verdeTurquesa.withOpacity(0.3)!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: verdeTurquesa, width: 2),
                        ),
                        filled: true,
                        fillColor: blanco,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      validator: (value) => Validators.validateConfirmPassword(
                        value,
                        _passwordController.text,
                      ),
                      enabled: !authController.isLoading,
                    ),
                    const SizedBox(height: 16),

                    // ✅ TÉRMINOS Y CONDICIONES
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
                          activeColor: verdeTurquesa,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: grisOscuro,
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
                                    color: verdeTurquesa,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = _mostrarTerminos,
                                ),
                                const TextSpan(
                                  text: ' y los términos de uso de Kanbly.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ✅ ERROR MESSAGE
                    if (authController.errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authController.errorMessage!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ✅ BOTÓN CREAR CUENTA - VERDE TURQUESA
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: authController.isLoading || !_acceptedTerms
                            ? null
                            : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: verdeTurquesa,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: authController.isLoading
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Text(
                          'Crear Cuenta',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ VOLVER AL LOGIN
                    TextButton(
                      onPressed: authController.isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '¿Ya tienes cuenta? Inicia sesión',
                        style: TextStyle(
                          color: verdeTurquesa,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
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
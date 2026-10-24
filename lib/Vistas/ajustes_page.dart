import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../utilerias/mensajes_error.dart';
import '../utilerias/validators.dart';
import '../controlador/auth_controller.dart';
import '../controlador/preferencias_controller.dart';
import '../controlador/theme_controller.dart';
import '../servicios/storage_service.dart';
import 'login_view.dart';
import 'splash_animado_view.dart';

class AjustesPage extends StatefulWidget {
  const AjustesPage({super.key});

  @override
  State<AjustesPage> createState() => _AjustesPageState();
}

class _AjustesPageState extends State<AjustesPage> {
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  bool _editandoNombre = false;
  late TextEditingController _nombreController;
  bool _guardandoNombre = false;
  bool _subiendoFoto = false;

  // Preferencias locales
  bool _notificacionesActivas = true;
  TimeOfDay _horaRecordatorio = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    final authController = Provider.of<AuthController>(context, listen: false);
    _nombreController = TextEditingController(text: authController.userName);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  // --- MÉTODOS DE ACCIÓN ---

  Future<void> _cambiarFotoPerfil() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF52ABEB)),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(bottomContext);
                _procesarImagen(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF63D0A1)),
              title: const Text('Tomar una foto'),
              onTap: () {
                Navigator.pop(bottomContext);
                _procesarImagen(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _procesarImagen(ImageSource origen) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: origen,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _subiendoFoto = true);

      if (!mounted) return;

      final authController = Provider.of<AuthController>(context, listen: false);
      final userId = authController.usuarioActual?.id ?? 'usuario';

      // Subir foto a Cloudinary mediante StorageService
      final String photoUrl = await _storageService.subirAdjuntoTarea(
        filePath: pickedFile.path,
        nombreArchivo: 'perfil_$userId.jpg',
        tareaId: 'perfiles',
      );

      if (!mounted) return;

      // Actualizar en Firestore y AuthController
      final authCtrl = Provider.of<AuthController>(context, listen: false);
      final exito = await authCtrl.actualizarPerfil(fotoPerfil: photoUrl);

      if (!mounted) return;

      setState(() => _subiendoFoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exito
              ? 'Foto de perfil actualizada correctamente.'
              : (authCtrl.errorMessage ?? 'No pudimos actualizar tu foto de perfil. Inténtalo de nuevo.')),
          backgroundColor: exito ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _subiendoFoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(MensajesError.desde(e, accion: 'subir la imagen')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _guardarNombre() async {
    final nuevoNombre = _nombreController.text.trim();
    final errorNombre = Validators.validateName(nuevoNombre);
    if (errorNombre != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorNombre)),
      );
      return;
    }

    setState(() => _guardandoNombre = true);

    final authController = Provider.of<AuthController>(context, listen: false);
    final exito = await authController.actualizarPerfil(nombreCompleto: nuevoNombre);

    if (mounted) {
      setState(() {
        _guardandoNombre = false;
        if (exito) _editandoNombre = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exito
              ? 'Nombre actualizado exitosamente.'
              : (authController.errorMessage ?? 'No pudimos actualizar tu nombre. Inténtalo de nuevo.')),
          backgroundColor: exito ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _solicitarCambioPassword() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final email = authController.userEmail;

    if (email.isEmpty) return;

    final exito = await authController.resetPassword(email);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exito
              ? 'Se ha enviado un correo a $email para restablecer tu contraseña.'
              : (authController.errorMessage ?? 'No pudimos enviar el correo. Inténtalo de nuevo.')),
          backgroundColor: exito ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _reenviarVerificacionCorreo() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final exito = await authController.sendVerificationEmail();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exito
              ? 'Correo de verificación enviado. Revisa tu bandeja institucional.'
              : (authController.errorMessage ?? 'No pudimos enviar el correo de verificación. Inténtalo de nuevo.')),
          backgroundColor: exito ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _seleccionarHoraRecordatorio() async {
    final TimeOfDay? seleccionada = await showTimePicker(
      context: context,
      initialTime: _horaRecordatorio,
    );
    if (seleccionada != null) {
      setState(() {
        _horaRecordatorio = seleccionada;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hora de recordatorios fijada a las ${_horaRecordatorio.format(context)}',
            ),
          ),
        );
      }
    }
  }

  // Eliminar cuenta (movido desde la pantalla Mi Perfil; misma lógica de negocio).
  void _confirmarEliminarCuenta() {
    final authController = Provider.of<AuthController>(context, listen: false);
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool eliminando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('¿Eliminar tu cuenta?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esta acción es permanente: se borrarán tus datos y no podrás recuperar tu cuenta. '
                      'Confirma tu contraseña para continuar.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: eliminando ? null : () => Navigator.pop(dialogContext),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: eliminando
                  ? null
                  : () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                setDialogState(() => eliminando = true);

                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                final exito = await authController.eliminarCuenta(passwordController.text);

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext); // cierra el diálogo

                if (exito) {
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginView()),
                        (route) => false,
                  );
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Tu cuenta fue eliminada correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  final mensaje = authController.errorMessage ??
                      'No pudimos eliminar tu cuenta. Inténtalo de nuevo.';
                  authController.clearError();
                  messenger.showSnackBar(
                    SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: eliminando
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // --- CONSTRUCCIÓN DE INTERFAZ ---

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final usuario = authController.usuarioActual;
    User? firebaseUser;
    try {
      firebaseUser = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    final bool emailVerificado = firebaseUser?.emailVerified ?? usuario?.emailVerificado ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF37B5F4)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              colors: [Color(0xFF52ABEB), Color(0xFF63D0A1)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds);
          },
          child: const Text(
            'Ajustes y Perfil',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        // RESPONSIVO: en horizontal el contenido se centra con ancho máximo.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                // --- TARJETA DE RESUMEN DEL PERFIL CON FOTO EDITABLE ---
                _buildProfileHeaderCard(authController, usuario),

                const SizedBox(height: 20),

                // --- SECCIÓN 1: DETALLES DE LA CUENTA ---
                _buildSectionTitle('Detalles de la Cuenta', Icons.manage_accounts_outlined),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Campo Nombre Completo
                        if (!_editandoNombre) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_outline, color: Color(0xFF52ABEB)),
                            title: const Text('Nombre Completo', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            subtitle: Text(
                              authController.userName,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF52ABEB)),
                              onPressed: () {
                                setState(() {
                                  _nombreController.text = authController.userName;
                                  _editandoNombre = true;
                                });
                              },
                            ),
                          ),
                        ] else ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Editar Nombre Completo', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _nombreController,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  suffixIcon: _guardandoNombre
                                      ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => setState(() => _editandoNombre = false),
                                    child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _guardandoNombre ? null : _guardarNombre,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF52ABEB),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Guardar', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ],

                        const Divider(),

                        // Correo Institucional
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.email_outlined, color: Color(0xFF52ABEB)),
                          title: const Text('Correo Institucional', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Text(
                            authController.userEmail,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                          ),
                          trailing: const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                        ),

                        const Divider(),

                        // Rol y fecha de registro (antes solo se veían en Mi Perfil)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.badge_outlined, color: Color(0xFF52ABEB)),
                          title: const Text('Rol', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Text(
                            authController.userRole.isEmpty
                                ? 'Estudiante'
                                : authController.userRole[0].toUpperCase() +
                                authController.userRole.substring(1),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                          ),
                        ),

                        if (usuario != null) ...[
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.event_available_outlined, color: Color(0xFF52ABEB)),
                            title: const Text('Miembro desde', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            subtitle: Text(
                              DateFormat('dd/MM/yyyy').format(usuario.fechaRegistro),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                            ),
                          ),
                        ],

                        const Divider(),

                        // Estado de Verificación de Correo
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            emailVerificado ? Icons.verified_user : Icons.gpp_maybe_outlined,
                            color: emailVerificado ? Colors.green : Colors.orange,
                          ),
                          title: const Text('Verificación de Correo', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Text(
                            emailVerificado ? 'Correo Verificado' : 'Verificación Pendiente',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: emailVerificado ? Colors.green : Colors.orange,
                            ),
                          ),
                          trailing: !emailVerificado
                              ? TextButton(
                            onPressed: _reenviarVerificacionCorreo,
                            child: const Text('Verificar', style: TextStyle(fontSize: 12)),
                          )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // --- SECCIÓN 2: SEGURIDAD ---
                _buildSectionTitle('Seguridad y Contraseña', Icons.security_outlined),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: const Icon(Icons.key_outlined, color: Color(0xFF52ABEB)),
                    title: const Text('Cambiar Contraseña', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Envia un correo para restablecer tu contraseña institucional'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                    onTap: _solicitarCambioPassword,
                  ),
                ),

                const SizedBox(height: 20),

                // --- SECCIÓN 3: PREFERENCIAS DE LA APP ---
                _buildSectionTitle('Preferencias y Notificaciones', Icons.tune_rounded),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_active_outlined, color: Color(0xFF52ABEB)),
                        title: const Text('Notificaciones de Vencimiento', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Avisar cuando las tareas estén por vencer'),
                        activeTrackColor: const Color(0xFF63D0A1),
                        value: _notificacionesActivas,
                        onChanged: (val) {
                          setState(() => _notificacionesActivas = val);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.access_time_rounded, color: Color(0xFF52ABEB)),
                        title: const Text('Hora de Recordatorio Diario', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Programado para las ${_horaRecordatorio.format(context)}'),
                        trailing: const Icon(Icons.edit_calendar_outlined, color: Color(0xFF52ABEB)),
                        onTap: _notificacionesActivas ? _seleccionarHoraRecordatorio : null,
                      ),
                      const Divider(height: 1),
                      Consumer<ThemeProvider>(
                        builder: (context, themeProvider, child) {
                          return ListTile(
                            leading: const Icon(Icons.palette_outlined, color: Color(0xFF63D0A1)),
                            title: const Text('Tema Visual', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(themeProvider.themeString),
                            trailing: DropdownButton<String>(
                              value: themeProvider.themeString,
                              dropdownColor: theme.cardColor,
                              underline: const SizedBox(),
                              items: ['Claro', 'Oscuro', 'Sistema']
                                  .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  t,
                                  style: TextStyle(color: theme.colorScheme.onSurface),
                                ),
                              ))
                                  .toList(),
                              onChanged: (nuevo) {
                                if (nuevo != null) {
                                  themeProvider.setThemeString(nuevo);
                                }
                              },
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      Consumer<PreferenciasController>(
                        builder: (context, prefCtrl, child) {
                          return SwitchListTile(
                            secondary: const Icon(Icons.movie_filter_outlined, color: Color(0xFF52ABEB)),
                            title: const Text('Animación de inicio', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Se aplica la próxima vez que abras la app'),
                            activeTrackColor: const Color(0xFF63D0A1),
                            value: prefCtrl.mostrarAnimacion,
                            onChanged: (val) {
                              prefCtrl.setMostrarAnimacion(val);
                            },
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.play_circle_outline, color: Color(0xFF52ABEB)),
                        title: const Text('Ver animación', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Toca para probar la animación de inicio'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SplashAnimadoView(
                                vistaPrevia: true,
                                destinoBuilder: (_) => const SizedBox(),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- SECCIÓN 4: ACERCA DE Y SOPORTE ---
                _buildSectionTitle('Información y Soporte', Icons.info_outline_rounded),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.domain_verification_rounded, color: Color(0xFF52ABEB)),
                        title: Text('Dominio Institucional Permitido'),
                        subtitle: Text('@e.uttecamac.edu.mx'),
                      ),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(Icons.vibration_outlined, color: Color(0xFF63D0A1)),
                        title: Text('Versión de Kanbly'),
                        subtitle: Text('1.0.0+1'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.help_outline_rounded, color: Color(0xFF52ABEB)),
                        title: const Text('Acerca de Kanbly'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'Kanbly',
                            applicationVersion: '1.0.0+1',
                            applicationIcon: const CircleAvatar(
                              backgroundColor: Color(0xFF52ABEB),
                              child: Icon(Icons.view_kanban, color: Colors.white),
                            ),
                            children: const [
                              SizedBox(height: 10),
                              Text(
                                'Kanbly es la plataforma integral de gestión de proyectos Kanban diseñada para la Universidad Tecnológica de Tecámac.',
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // --- SECCIÓN 5: BOTÓN ELIMINAR MI CUENTA ---
                // (reemplaza al segundo "Cerrar Sesión", que ya existe en el menú lateral)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                    label: const Text(
                      'Eliminar mi cuenta',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onPressed: _confirmarEliminarCuenta,
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE SOPORTE ---

  Widget _buildSectionTitle(String titulo, IconData icono) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Row(
        children: [
          Icon(icono, size: 20, color: const Color(0xFF52ABEB)),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeaderCard(AuthController authController, dynamic usuario) {
    final String? fotoUrl = usuario?.fotoPerfil;
    final String nombre = authController.userName;
    final String email = authController.userEmail;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF52ABEB), Color(0xFF63D0A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF52ABEB).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar con botón de cámara
          Stack(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
                    ? NetworkImage(fotoUrl) as ImageProvider
                    : null,
                child: (fotoUrl == null || fotoUrl.isEmpty)
                    ? Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF52ABEB),
                  ),
                )
                    : null,
              ),
              if (_subiendoFoto)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _subiendoFoto ? null : _cambiarFotoPerfil,
                  child: const CircleAvatar(
                    radius: 13,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: Color(0xFF52ABEB),
                      child: Icon(Icons.camera_alt, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Nombre e Email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
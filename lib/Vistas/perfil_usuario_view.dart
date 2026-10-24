import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controlador/auth_controller.dart';
import '../modelo/invitacion.dart';
import '../modelo/resumen_tableros.dart';
import '../modelo/tablero.dart';
import '../servicios/firestore_service.dart';
import '../utilerias/mensajes_error.dart';
import 'informacion_tableros_section.dart';
import 'kanban_board_widget.dart';


// ✅ COLORES OFICIALES DE KANBLY (mismos de login/registro)
const Color _azulCielo = Color(0xFF52ABEB);
const Color _verdeTurquesa = Color(0xFF63D0A1);

class PerfilUsuarioView extends StatefulWidget {
  const PerfilUsuarioView({super.key});

  @override
  State<PerfilUsuarioView> createState() => _PerfilUsuarioViewState();
}

class _PerfilUsuarioViewState extends State<PerfilUsuarioView> {
  final FirestoreService _firestoreService = FirestoreService();

  List<Tablero> _tableros = [];
  ResumenActividadTareas? _actividad;
  bool _cargando = true;
  bool _errorCarga = false;
  bool _errorNotificacionesRegistrado = false;
  String? _mensajeErrorNotificaciones;
  String _mensajeCargaError =
      'No pudimos cargar tu resumen. Inténtalo de nuevo.';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw StateError('La sesión ya no está disponible.');
      }
      final tableros = await _firestoreService.obtenerTablerosDeUsuario(uid);
      final tareas = await _firestoreService.obtenerTareasCreadasPorUsuario(
        uid,
      );

      if (!mounted) return;
      setState(() {
        _tableros = tableros;
        _actividad = ResumenActividadTareas.desde(tareas, tableros: tableros);
        _cargando = false;
        _errorCarga = false;
      });
    } catch (e, stackTrace) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = true;
        _mensajeCargaError =
        'No se pudo cargar tu actividad. Revisa tu conexión e inténtalo de nuevo.';
        _mensajeCargaError = MensajesError.desde(
          e,
          accion: 'cargar tu actividad',
          stackTrace: stackTrace,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final usuario = authController.usuarioActual;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: const Text(
            'Información de tableros',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_azulCielo, _verdeTurquesa],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: usuario == null
          ? const Center(child: Text('Inicia sesión para consultar tu perfil.'))
          : RefreshIndicator(
        onRefresh: _cargarDatos,
        child: LayoutBuilder(
          builder: (context, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              28 + MediaQuery.of(context).padding.bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _tituloSeccion('Resumen de tus espacios'),
                    const SizedBox(height: 10),
                    if (_cargando)
                      _cargandoMini()
                    else if (_errorCarga)
                      _tarjetaReintentar()
                    else
                      InformacionTablerosSection(
                        resumen: ResumenTableros.desde(_tableros, uid),
                      ),
                    const SizedBox(height: 20),
                    _tituloSeccion('Tu actividad'),
                    const SizedBox(height: 10),
                    if (_cargando)
                      _cargandoMini()
                    else if (!_errorCarga && _actividad != null)
                      ActividadTareasSection(actividad: _actividad!),
                    const SizedBox(height: 22),
                    _tituloSeccion('Tus tableros'),
                    const SizedBox(height: 4),
                    Text(
                      'Toca un tablero para abrirlo. El detalle de columnas y tareas está en la pantalla principal.',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_cargando)
                      _cargandoMini()
                    else if (!_errorCarga)
                      MisTablerosDetalle(
                        resumen: ResumenTableros.desde(_tableros, uid),
                        onTapTablero: _abrirTablero,
                      ),
                    const SizedBox(height: 22),
                    _tituloSeccion('Notificaciones'),
                    const SizedBox(height: 10),
                    _seccionNotificaciones(uid),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _abrirTablero(InfoTableroUsuario info) {
    final indice = _tableros.indexWhere((item) => item.id == info.id);
    if (indice < 0) return;
    final tablero = _tableros[indice];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KanbanBoardWidget(tablero: tablero),
      ),
    );
  }

  Widget _tituloSeccion(String titulo) {
    return Text(
      titulo,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _cargandoMini() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );

  Widget _tarjetaReintentar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: _azulCielo),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _mensajeCargaError,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
          IconButton(
            tooltip: 'Reintentar',
            onPressed: () {
              setState(() => _cargando = true);
              _cargarDatos();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  // ---------- SECCIÓN: NOTIFICACIONES (invitaciones pendientes en tiempo real) ----------
  Widget _seccionNotificaciones(String uid) {
    return StreamBuilder<List<Invitacion>>(
      stream: _firestoreService.obtenerMisInvitaciones(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _cargandoMini();
        }
        if (snapshot.hasError) {

              _mensajeErrorNotificaciones ??= MensajesError.desde(
                snapshot.error,
                accion: 'cargar tus notificaciones',
              );
              return _tarjetaVacia(_mensajeErrorNotificaciones!);
        }
        _errorNotificacionesRegistrado = false;
        _mensajeErrorNotificaciones = null;
        final invitaciones = snapshot.data ?? [];
        if (invitaciones.isEmpty) {
          return _tarjetaVacia('No tienes notificaciones pendientes.');
        }
        return Column(
          children: invitaciones.map((inv) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _azulCielo.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _azulCielo.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline, color: _azulCielo, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Invitación pendiente al tablero "${inv.tableroNombre}"',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _tarjetaVacia(String mensaje) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2D3748)
              : Colors.grey.shade200,
        ),
      ),
      child: Text(
        mensaje,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
    );
  }


}
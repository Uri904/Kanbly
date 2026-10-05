import 'package:flutter/material.dart';
import '../servicios/firestore_service.dart';
import '../modelo/tablero.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modelo/usuario.dart';

class FormularioTablero extends StatefulWidget {
  final bool esGrupal;
  final Tablero? tablero;

  const FormularioTablero({
    super.key,
    required this.esGrupal,
    this.tablero,
  });

  @override
  State<FormularioTablero> createState() => _FormularioTableroState();
}

class _FormularioTableroState extends State<FormularioTablero>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  late TabController _tabController;

  List<Usuario> _miembrosSeleccionados = [];
  Map<String, MiembroTableroInfo> _miembrosInfo = {};
  List<String> _columnas = ['Pendiente', 'En progreso', 'Completada'];
  String _fechaActualizacion = 'Sin actualizar';

  // Módulos del tablero
  bool _tieneCalendario = true;
  bool _tieneNotas = true;
  bool _tieneRecordatorios = true;

  // Paleta oficial Kanbly
  final Color blanco = const Color(0xFFFCFDFD);
  final Color azulCielo = const Color(0xFF52ABEB);
  final Color verdeTurquesa = const Color(0xFF63D0A1);
  final Color grisOscuro = const Color(0xFF1E293B);

  static const List<String> _rolesKanbanDisponibles = [
    'Líder de Proyecto',
    'Programador / Desarrollador',
    'Tester / QA',
    'Diseñador UI/UX',
    'Analista',
    'Scrum Master',
    'Product Owner',
  ];

  @override
  void initState() {
    super.initState();
    // 2 Pestañas para tablero individual | 3 Pestañas para tablero en equipo
    _tabController = TabController(length: widget.esGrupal ? 3 : 2, vsync: this);

    if (widget.tablero != null) {
      _nombreController.text = widget.tablero!.nombre;
      _descripcionController.text = widget.tablero!.descripcion ?? "";
      _tieneCalendario = widget.tablero!.tieneCalendario;
      _tieneNotas = widget.tablero!.tieneNotas;
      _tieneRecordatorios = widget.tablero!.tieneRecordatorios;
      _miembrosInfo = Map.from(widget.tablero!.miembrosInfo);
      _columnas = List<String>.from(
        widget.tablero!.columnas.isNotEmpty
            ? widget.tablero!.columnas
            : ['Pendiente', 'En progreso', 'Completada'],
      );

      if (widget.tablero!.fechaActualizacion != null) {
        _fechaActualizacion = widget.tablero!.fechaActualizacion!
            .toString()
            .substring(0, 16);
      }

      _cargarMiembros();
    } else {
      // Para un tablero nuevo
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _miembrosInfo[uid] = MiembroTableroInfo(
          usuarioId: uid,
          rolKanban: 'Líder de Proyecto',
          esAdmin: true,
          permisos: PermisosMiembro.todos,
        );
        _cargarCreadorActual();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color colorTema = widget.esGrupal ? azulCielo : verdeTurquesa;

    return Scaffold(
      backgroundColor: blanco,
      appBar: AppBar(
        backgroundColor: blanco,
        elevation: 0,
        iconTheme: IconThemeData(color: colorTema),
        title: Text(
          widget.tablero != null
              ? 'Editar Tablero'
              : widget.esGrupal
                  ? 'Nuevo Tablero Grupal'
                  : 'Nuevo Tablero Individual',
          style: TextStyle(
              color: grisOscuro, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorTema,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: colorTema,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: [
            const Tab(
              icon: Icon(Icons.tune_rounded, size: 18),
              text: 'Información y Módulos',
            ),
            const Tab(
              icon: Icon(Icons.dashboard_customize_outlined, size: 18),
              text: 'Personalizar Tablero',
            ),
            if (widget.esGrupal)
              const Tab(
                icon: Icon(Icons.people_outline_rounded, size: 18),
                text: 'Miembros y Permisos',
              ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _construirPestanaGeneral(colorTema),
            _construirPestanaPersonalizar(colorTema),
            if (widget.esGrupal) _construirPestanaMiembros(colorTema),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _guardarTablero,
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            label: Text(
              widget.tablero != null ? 'Guardar Cambios' : 'Crear Tablero',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorTema,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  // --- PESTAÑA 1: INFORMACIÓN GENERAL Y MÓDULOS ---
  Widget _construirPestanaGeneral(Color colorTema) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      children: [
        // CABECERA CON ILUSTRACIÓN DE TIPO DE TABLERO
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: colorTema.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorTema.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: colorTema.withOpacity(0.18),
                child: Icon(
                  widget.esGrupal
                      ? Icons.groups_rounded
                      : Icons.person_outline_rounded,
                  color: colorTema,
                  size: 36,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.esGrupal ? 'Tablero en Equipo' : 'Tablero Personal',
                style: TextStyle(
                  color: colorTema,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.esGrupal
                    ? 'Colaboración en tiempo real con permisos granulares y roles'
                    : 'Espacio personal de organización de tareas',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // TARJETA DE INFORMACIÓN GENERAL
        _tarjetaSeccion(
          titulo: 'Información del Tablero',
          icono: Icons.info_outline_rounded,
          colorHeader: colorTema,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nombre del Tablero *',
                  style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nombreController,
                decoration: _construirDecoracionInput(
                  pista: 'Ej. Proyecto Integrador...',
                  icono: Icons.dashboard_outlined,
                  colorFoco: colorTema,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Ingresa un nombre'
                    : null,
              ),
              const SizedBox(height: 16),
              const Text('Descripción (Opcional)',
                  style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descripcionController,
                maxLines: 3,
                decoration: _construirDecoracionInput(
                  pista: 'Describe los objetivos del tablero...',
                  icono: Icons.description_outlined,
                  colorFoco: colorTema,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // TARJETA DE MÓDULOS ACTIVOS
        _tarjetaSeccion(
          titulo: 'Módulos Adicionales',
          icono: Icons.apps_rounded,
          colorHeader: colorTema,
          child: Column(
            children: [
              _construirSwitchModulo(
                titulo: 'Calendario',
                subtitulo:
                    'Agendar entregables y visualizar fechas en el calendario',
                icono: Icons.calendar_month,
                colorIcono: Colors.blue,
                valor: _tieneCalendario,
                onChanged: (val) => setState(() => _tieneCalendario = val),
                colorTema: colorTema,
              ),
              const Divider(height: 1),
              _construirSwitchModulo(
                titulo: 'Notas para tareas',
                subtitulo:
                    'Añadir anotaciones y documentación técnica a las tareas',
                icono: Icons.note_alt_outlined,
                colorIcono: Colors.orange,
                valor: _tieneNotas,
                onChanged: (val) => setState(() => _tieneNotas = val),
                colorTema: colorTema,
              ),
              const Divider(height: 1),
              _construirSwitchModulo(
                titulo: 'Recordatorios y Alertas',
                subtitulo:
                    'Alertas de vencimiento para los integrantes del equipo',
                icono: Icons.notifications_active_outlined,
                colorIcono: Colors.redAccent,
                valor: _tieneRecordatorios,
                onChanged: (val) => setState(() => _tieneRecordatorios = val),
                colorTema: colorTema,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // METADATA
        Row(
          children: [
            Expanded(
              child: _chipInfo(
                label: 'Creado el',
                valor: widget.tablero != null
                    ? widget.tablero!.fechaCreacion
                        .toString()
                        .substring(0, 10)
                    : DateTime.now().toString().substring(0, 10),
                icono: Icons.calendar_today_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _chipInfo(
                label: 'Actualizado',
                valor: _fechaActualizacion,
                icono: Icons.update_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // --- PESTAÑA 2: PERSONALIZAR TABLERO (COLUMNAS Y FLUJOS KANBAN) ---
  Widget _construirPestanaPersonalizar(Color colorTema) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      children: [
        // CABECERA DE PERSONALIZACIÓN
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorTema.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorTema.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorTema.withOpacity(0.2),
                child: Icon(Icons.dashboard_customize_outlined,
                    color: colorTema, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personalizar Columnas y Flujo',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: grisOscuro),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Añade, reordena o cambia el nombre de las columnas de tu tablero.',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // PLANTILLAS RÁPIDAS
        _tarjetaSeccion(
          titulo: 'Plantillas de Flujo Recomendadas',
          icono: Icons.auto_awesome_outlined,
          colorHeader: colorTema,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona una plantilla predefinida para aplicar un flujo de trabajo rápido:',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _columnas = ['Pendiente', 'En progreso', 'Completada'];
                      });
                    },
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('Clásico Kanban',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorTema,
                      side:
                          BorderSide(color: colorTema.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _columnas = [
                          'Por Hacer',
                          'En Desarrollo',
                          'QA / Pruebas',
                          'Aprobado'
                        ];
                      });
                    },
                    icon: const Icon(Icons.code_rounded, size: 16),
                    label: const Text('Software & QA',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorTema,
                      side:
                          BorderSide(color: colorTema.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _columnas = [
                          'Backlog',
                          'Por Hacer',
                          'En Proceso',
                          'En Revisión',
                          'Completado'
                        ];
                      });
                    },
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text('Ágil / Scrum',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorTema,
                      side:
                          BorderSide(color: colorTema.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // LISTA DE COLUMNAS ACTUALES
        _tarjetaSeccion(
          titulo: 'Columnas del Tablero (${_columnas.length})',
          icono: Icons.view_column_rounded,
          colorHeader: colorTema,
          child: Column(
            children: [
              ..._columnas.asMap().entries.map((entry) {
                final idx = entry.key;
                final colNombre = entry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorTema.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            color: colorTema,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          colNombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (idx > 0)
                        IconButton(
                          icon: const Icon(Icons.arrow_upward_rounded,
                              size: 18, color: Colors.grey),
                          tooltip: 'Mover hacia arriba',
                          onPressed: () {
                            setState(() {
                              final item = _columnas.removeAt(idx);
                              _columnas.insert(idx - 1, item);
                            });
                          },
                        ),
                      if (idx < _columnas.length - 1)
                        IconButton(
                          icon: const Icon(Icons.arrow_downward_rounded,
                              size: 18, color: Colors.grey),
                          tooltip: 'Mover hacia abajo',
                          onPressed: () {
                            setState(() {
                              final item = _columnas.removeAt(idx);
                              _columnas.insert(idx + 1, item);
                            });
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: Colors.blue),
                        tooltip: 'Editar nombre',
                        onPressed: () => _dialogEditarColumna(idx),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Colors.redAccent),
                        tooltip: 'Eliminar columna',
                        onPressed: _columnas.length <= 1
                            ? null
                            : () {
                                setState(() {
                                  _columnas.removeAt(idx);
                                });
                              },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _dialogAgregarColumna,
                  icon: const Icon(Icons.add_rounded,
                      size: 20, color: Colors.white),
                  label: const Text('Agregar Nueva Columna',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorTema,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _dialogAgregarColumna() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Nueva Columna',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nombre de la columna',
            hintText: 'Ej. Por Revisar, Bloqueada, QA...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: azulCielo,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final nombre = controller.text.trim();
              if (nombre.isNotEmpty) {
                if (_columnas
                    .map((c) => c.toLowerCase())
                    .contains(nombre.toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Ya existe una columna con este nombre')),
                  );
                  return;
                }
                setState(() {
                  _columnas.add(nombre);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Agregar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _dialogEditarColumna(int index) {
    final controller = TextEditingController(text: _columnas[index]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Columna',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nombre de la columna',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: azulCielo,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final nombre = controller.text.trim();
              if (nombre.isNotEmpty) {
                setState(() {
                  _columnas[index] = nombre;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _construirSwitchModulo({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color colorIcono,
    required bool valor,
    required ValueChanged<bool> onChanged,
    required Color colorTema,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      title: Text(titulo,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitulo,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorIcono.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icono, color: colorIcono, size: 22),
      ),
      activeTrackColor: colorTema,
      value: valor,
      onChanged: onChanged,
    );
  }

  // --- PESTAÑA 3: MIEMBROS Y PERMISOS DE EQUIPO ---
  Widget _construirPestanaMiembros(Color colorTema) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool soyCreadorOriginal =
        widget.tablero?.esCreador(currentUserId) ?? true;
    final bool esAdmin =
        widget.tablero?.esAdminOCreador(currentUserId) ?? true;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      children: [
        // CABECERA CON BOTÓN INVITAR
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Integrantes del Equipo',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_miembrosSeleccionados.length} miembros registrados',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: (esAdmin || soyCreadorOriginal)
                    ? _agregarMiembro
                    : null,
                icon: const Icon(Icons.person_add_alt_1_rounded,
                    size: 18, color: Colors.white),
                label: const Text('Invitar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorTema,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // LISTA DE INTEGRANTES CON SUS TARJETAS Y ROLES
        if (_miembrosSeleccionados.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text(
              'No hay miembros en este equipo aún.\nHaz clic en "Invitar" para sumar integrantes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        else
          ..._miembrosSeleccionados.map((usuario) {
            final id = usuario.id;
            final isOwner =
                (widget.tablero != null && widget.tablero!.esCreador(id)) ||
                    (widget.tablero == null && id == currentUserId);

            final info = _miembrosInfo[id] ??
                MiembroTableroInfo(
                  usuarioId: id,
                  rolKanban: usuario.rol == 'estudiante'
                      ? 'Programador / Desarrollador'
                      : usuario.rol,
                  esAdmin: isOwner,
                );

            bool puedeRemover = false;
            if (!isOwner) {
              if (info.esAdmin) {
                puedeRemover = soyCreadorOriginal;
              } else {
                puedeRemover = soyCreadorOriginal || esAdmin;
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isOwner
                      ? Colors.amber.shade400
                      : info.esAdmin
                          ? azulCielo
                          : Colors.grey.shade200,
                  width: isOwner || info.esAdmin ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isOwner
                            ? Colors.amber.shade100
                            : info.esAdmin
                                ? azulCielo.withOpacity(0.15)
                                : verdeTurquesa.withOpacity(0.15),
                        child: Text(
                          usuario.nombreCompleto.isNotEmpty
                              ? usuario.nombreCompleto[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: isOwner
                                ? Colors.amber.shade900
                                : info.esAdmin
                                    ? azulCielo
                                    : verdeTurquesa,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    usuario.nombreCompleto,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              usuario.email,
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (puedeRemover)
                        IconButton(
                          icon: const Icon(Icons.person_remove_outlined,
                              color: Colors.redAccent, size: 20),
                          tooltip: 'Remover del equipo',
                          onPressed: () {
                            setState(() {
                              _miembrosSeleccionados
                                  .removeWhere((u) => u.id == usuario.id);
                              _miembrosInfo.remove(usuario.id);
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // BADGES Y BOTÓN DE PERMISOS (RESPONSIVO SIN OVERFLOW)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _badge(
                            texto: isOwner
                                ? 'Dueño Principal'
                                : info.esAdmin
                                    ? 'Admin / Co-dueño'
                                    : 'Miembro',
                            colorFondo: isOwner
                                ? Colors.amber.shade100
                                : info.esAdmin
                                    ? azulCielo.withOpacity(0.15)
                                    : Colors.grey.shade100,
                            colorTexto: isOwner
                                ? Colors.amber.shade900
                                : info.esAdmin
                                    ? azulCielo
                                    : Colors.grey.shade800,
                            icono: isOwner
                                ? Icons.shield_rounded
                                : info.esAdmin
                                    ? Icons.admin_panel_settings
                                    : Icons.person,
                          ),
                          _badge(
                            texto: info.rolKanban,
                            colorFondo: verdeTurquesa.withOpacity(0.15),
                            colorTexto: const Color(0xFF1E293B),
                            icono: Icons.work_outline_rounded,
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => _abrirModalPermisosMiembro(
                            usuario, info, isOwner, currentUserId),
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text('Permisos y Rol',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 32),
      ],
    );
  }

  // --- MODAL DE PERMISOS GRANULARES Y ROLES KANBAN ---
  void _abrirModalPermisosMiembro(
    Usuario usuario,
    MiembroTableroInfo infoActual,
    bool isOwner,
    String currentUserId,
  ) {
    final bool soyCreadorOriginal =
        widget.tablero?.esCreador(currentUserId) ?? true;
    final bool esObjetivoAdmin = infoActual.esAdmin;

    final bool puedeEditar = !isOwner &&
        (soyCreadorOriginal ||
            (!esObjetivoAdmin &&
                (widget.tablero?.esAdminOCreador(currentUserId) ?? true)));

    String rolKanbanSeleccionado = infoActual.rolKanban;
    bool esAdminSeleccionado = infoActual.esAdmin;
    PermisosMiembro permisosTemp = infoActual.permisos;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 24,
                right: 24,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ENCABEZADO PERFIL MIEMBRO
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: isOwner
                              ? Colors.amber.shade100
                              : esAdminSeleccionado
                                  ? azulCielo.withOpacity(0.15)
                                  : verdeTurquesa.withOpacity(0.15),
                          child: Text(
                            usuario.nombreCompleto.isNotEmpty
                                ? usuario.nombreCompleto[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: isOwner
                                  ? Colors.amber.shade900
                                  : esAdminSeleccionado
                                      ? azulCielo
                                      : verdeTurquesa,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                usuario.nombreCompleto,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF1E293B)),
                              ),
                              Text(usuario.email,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (isOwner)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield_rounded,
                                color: Colors.amber.shade900, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'El Creador y Dueño Principal posee todos los permisos de forma inmutable.',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF78350F)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (esObjetivoAdmin && !soyCreadorOriginal)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                color: Colors.blue, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Solo el Creador (Dueño Principal) del tablero puede modificar los permisos o el rol de un Administrador.',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!isOwner)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 2),
                          title: const Text('Administrador / Co-dueño',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B))),
                          subtitle: const Text(
                              'Otorga acceso y administración completa al tablero',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                          value: esAdminSeleccionado,
                          activeTrackColor: azulCielo,
                          onChanged: puedeEditar && soyCreadorOriginal
                              ? (val) {
                                  setModalState(() {
                                    esAdminSeleccionado = val;
                                  });
                                }
                              : null,
                        ),
                      ),

                    const Text('Rol Kanban en el Equipo:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E293B))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _rolesKanbanDisponibles
                              .contains(rolKanbanSeleccionado)
                          ? rolKanbanSeleccionado
                          : 'Programador / Desarrollador',
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      items: _rolesKanbanDisponibles.map((rol) {
                        return DropdownMenuItem<String>(
                          value: rol,
                          child: Text(rol, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: puedeEditar
                          ? (value) {
                              if (value != null) {
                                setModalState(
                                    () => rolKanbanSeleccionado = value);
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Permisos Granulares:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1E293B))),
                        if (esAdminSeleccionado || isOwner)
                          Text(
                            'Acceso Total',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _encabezadoGrupoPermisos(
                              'Gestión de Tareas', Icons.task_alt_rounded),
                          _switchPermiso(
                            titulo: 'Crear Tareas',
                            subtitulo:
                                'Permite agregar nuevas tareas al tablero',
                            valor: esAdminSeleccionado || isOwner
                                ? true
                                : permisosTemp.crearTareas,
                            deshabilitado:
                                !puedeEditar || esAdminSeleccionado || isOwner,
                            onChanged: (v) => setModalState(() =>
                                permisosTemp =
                                    permisosTemp.copyWith(crearTareas: v)),
                          ),
                          const Divider(height: 1),
                          _switchPermiso(
                            titulo: 'Mover y Reordenar Tareas',
                            subtitulo:
                                'Permite arrastrar tareas entre las columnas',
                            valor: esAdminSeleccionado || isOwner
                                ? true
                                : permisosTemp.moverTareas,
                            deshabilitado:
                                !puedeEditar || esAdminSeleccionado || isOwner,
                            onChanged: (v) => setModalState(() =>
                                permisosTemp =
                                    permisosTemp.copyWith(moverTareas: v)),
                          ),
                          const Divider(height: 1),
                          _switchPermiso(
                            titulo: 'Editar Tareas',
                            subtitulo:
                                'Modificar título, descripción, prioridad y fecha',
                            valor: esAdminSeleccionado || isOwner
                                ? true
                                : permisosTemp.editarTareas,
                            deshabilitado:
                                !puedeEditar || esAdminSeleccionado || isOwner,
                            onChanged: (v) => setModalState(() =>
                                permisosTemp =
                                    permisosTemp.copyWith(editarTareas: v)),
                          ),
                          const Divider(height: 1),
                          _switchPermiso(
                            titulo: 'Eliminar y Archivar Tareas',
                            subtitulo: 'Permite eliminar tareas del tablero',
                            valor: esAdminSeleccionado || isOwner
                                ? true
                                : permisosTemp.eliminarTareas,
                            deshabilitado:
                                !puedeEditar || esAdminSeleccionado || isOwner,
                            onChanged: (v) => setModalState(() =>
                                permisosTemp =
                                    permisosTemp.copyWith(eliminarTareas: v)),
                          ),
                          _encabezadoGrupoPermisos('Módulos y Configuración',
                              Icons.grid_view_rounded),
                          _switchPermiso(
                            titulo: 'Gestionar Módulos',
                            subtitulo:
                                'Acceso al Calendario, Notas y Recordatorios',
                            valor: esAdminSeleccionado || isOwner
                                ? true
                                : permisosTemp.gestionarModulos,
                            deshabilitado:
                                !puedeEditar || esAdminSeleccionado || isOwner,
                            onChanged: (v) => setModalState(() =>
                                permisosTemp =
                                    permisosTemp.copyWith(gestionarModulos: v)),
                          ),
                          const Divider(height: 1),
                          _switchPermiso(
                            titulo: 'Editar Configuración del Tablero',
                            subtitulo:
                                'Cambiar nombre, descripción y opciones generales',
                            valor: esAdminSeleccionado || isOwner
                                ? true
                                : permisosTemp.editarTablero,
                            deshabilitado:
                                !puedeEditar || esAdminSeleccionado || isOwner,
                            onChanged: (v) => setModalState(() =>
                                permisosTemp =
                                    permisosTemp.copyWith(editarTablero: v)),
                          ),
                          _encabezadoGrupoPermisos(
                              'Gestión del Equipo', Icons.badge_outlined),
                          _switchPermiso(
                            titulo: 'Administrar Miembros',
                            subtitulo:
                                'Invitar integrantes y ajustar permisos regulares',
                            valor: esAdminSeleccionado || isOwner
                                ? true
                                : permisosTemp.administrarMiembros,
                            deshabilitado:
                                !puedeEditar || esAdminSeleccionado || isOwner,
                            onChanged: (v) => setModalState(() => permisosTemp =
                                permisosTemp.copyWith(administrarMiembros: v)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: azulCielo,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: puedeEditar
                            ? () {
                                setState(() {
                                  _miembrosInfo[usuario.id] =
                                      MiembroTableroInfo(
                                    usuarioId: usuario.id,
                                    rolKanban: rolKanbanSeleccionado,
                                    esAdmin: esAdminSeleccionado,
                                    permisos: esAdminSeleccionado
                                        ? PermisosMiembro.todos
                                        : permisosTemp,
                                  );
                                });
                                Navigator.pop(context);
                              }
                            : () => Navigator.pop(context),
                        child: Text(
                          puedeEditar ? 'Aplicar Cambios' : 'Cerrar',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _encabezadoGrupoPermisos(String titulo, IconData icono) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Icon(icono, size: 16, color: azulCielo),
          const SizedBox(width: 6),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchPermiso({
    required String titulo,
    required String subtitulo,
    required bool valor,
    required bool deshabilitado,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      title: Text(titulo,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitulo,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      value: valor,
      activeTrackColor: azulCielo,
      onChanged: deshabilitado ? null : onChanged,
    );
  }

  Widget _tarjetaSeccion({
    required String titulo,
    required IconData icono,
    required Color colorHeader,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: colorHeader, size: 22),
              const SizedBox(width: 10),
              Text(
                titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _chipInfo(
      {required String label,
      required String valor,
      required IconData icono}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icono, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
              Text(valor,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Color(0xFF1E293B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(
      {required String texto,
      required Color colorFondo,
      required Color colorTexto,
      required IconData icono}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: colorTexto),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
                color: colorTexto, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  InputDecoration _construirDecoracionInput(
      {required String pista,
      required IconData icono,
      required Color colorFoco}) {
    return InputDecoration(
      hintText: pista,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: Icon(icono, color: Colors.grey.shade400, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorFoco, width: 1.8)),
    );
  }

  Future<void> _guardarTablero() async {
    if (_formKey.currentState!.validate()) {
      try {
        final uid = FirebaseAuth.instance.currentUser!.uid;

        final doc = FirebaseFirestore.instance.collection('tableros').doc();

        final creadorIdFinal = widget.tablero?.creadorId ?? uid;

        List<String> miembrosFinales =
            _miembrosSeleccionados.map((u) => u.id).toList();
        if (!miembrosFinales.contains(creadorIdFinal)) {
          miembrosFinales.add(creadorIdFinal);
        }

        if (!_miembrosInfo.containsKey(creadorIdFinal)) {
          _miembrosInfo[creadorIdFinal] = MiembroTableroInfo(
            usuarioId: creadorIdFinal,
            rolKanban: 'Líder de Proyecto',
            esAdmin: true,
            permisos: PermisosMiembro.todos,
          );
        }

        final tablero = Tablero(
          id: widget.tablero?.id ?? doc.id,
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          esGrupal: widget.esGrupal,
          creadorId: creadorIdFinal,
          miembrosIds: miembrosFinales,
          miembrosInfo: _miembrosInfo,
          columnas: _columnas.isNotEmpty
              ? _columnas
              : const ['Pendiente', 'En progreso', 'Completada'],
          fechaCreacion: widget.tablero?.fechaCreacion ?? DateTime.now(),
          tieneCalendario: _tieneCalendario,
          tieneNotas: _tieneNotas,
          tieneRecordatorios: _tieneRecordatorios,
          fechaActualizacion: widget.tablero != null ? DateTime.now() : null,
        );

        if (widget.tablero == null) {
          await _firestoreService.crearTableroConId(tablero);
        } else {
          await _firestoreService.actualizarTablero(tablero);
        }

        if (!mounted) return;
        Navigator.of(context).pop(true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar tablero: $e')),
          );
        }
      }
    }
  }

  Future<void> _agregarMiembro() async {
    final TextEditingController emailController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    String rolSeleccionado = 'Programador / Desarrollador';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Invitar Miembro por Correo"),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: SingleChildScrollView(
                child: Form(
                  key: dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Correo Institucional:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'ejemplo@e.uttecamac.edu.mx',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa un correo';
                          }
                          if (!value.trim().endsWith('@e.uttecamac.edu.mx')) {
                            return 'Debe ser dominio @e.uttecamac.edu.mx';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Rol Kanban Inicial:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: rolSeleccionado,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        items: _rolesKanbanDisponibles.map((rol) {
                          return DropdownMenuItem<String>(
                            value: rol,
                            child: Text(rol,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => rolSeleccionado = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulCielo,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (dialogFormKey.currentState!.validate()) {
                      final email = emailController.text.trim();
                      final usuario =
                          await _firestoreService.obtenerUsuarioPorEmail(email);

                      if (usuario == null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Usuario no encontrado en la base de datos')),
                        );
                        return;
                      }

                      setState(() {
                        if (!_miembrosSeleccionados
                            .any((u) => u.id == usuario.id)) {
                          _miembrosSeleccionados.add(usuario);
                        }
                        _miembrosInfo[usuario.id] = MiembroTableroInfo(
                          usuarioId: usuario.id,
                          rolKanban: rolSeleccionado,
                          esAdmin: false,
                          permisos: const PermisosMiembro(),
                        );
                      });

                      if (!context.mounted) return;
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Invitar',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cargarCreadorActual() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final usuario = await _firestoreService.obtenerUsuarioPorId(uid);
      if (usuario != null && mounted) {
        setState(() {
          if (!_miembrosSeleccionados.any((u) => u.id == usuario.id)) {
            _miembrosSeleccionados.add(usuario);
          }
        });
      }
    }
  }

  Future<void> _cargarMiembros() async {
    final ids = widget.tablero!.miembrosIds;
    List<Usuario> usuarios = [];

    for (String id in ids) {
      final usuario = await _firestoreService.obtenerUsuarioPorId(id);
      if (usuario != null) {
        usuarios.add(usuario);
      }
    }

    if (mounted) {
      setState(() {
        _miembrosSeleccionados = usuarios;
      });
    }
  }
}

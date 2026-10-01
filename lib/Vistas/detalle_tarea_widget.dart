import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- IMPORTS DE LOS MODELOS Y SERVICIOS DEL EQUIPO ---
import '../modelo/tarea.dart';
import '../modelo/tablero.dart';
import '../modelo/usuario.dart';
import '../servicios/firestore_service.dart';
import '../utilerias/formato_util.dart';

class DetalleTareaWidget extends StatefulWidget {
  final Tarea tarea;
  final Tablero? tablero;

  const DetalleTareaWidget({
    super.key,
    required this.tarea,
    this.tablero,
  });

  @override
  State<DetalleTareaWidget> createState() => _DetalleTareaWidgetState();
}

class _DetalleTareaWidgetState extends State<DetalleTareaWidget> {
  final FirestoreService _firestoreService = FirestoreService();

  // Control de modo: false = Solo lectura, true = Editando campos
  bool _modoEdicion = false;
  bool _procesando = false;

  // Controladores y variables de estado
  late TextEditingController _tituloController;
  late TextEditingController _descController;
  late String _columnaActual;
  late int _prioridadActual;
  DateTime? _fechaVencimiento;
  String? _asignadoA;
  List<Usuario> _miembrosEquipo = [];
  bool _cargandoMiembros = false;

  late List<String> _columnasDisponibles;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.tarea.titulo);
    _descController = TextEditingController(text: widget.tarea.descripcion ?? '');

    _columnasDisponibles = widget.tablero?.columnas.isNotEmpty == true
        ? widget.tablero!.columnas
        : const ['Pendiente', 'En progreso', 'Completada'];

    _columnaActual = widget.tarea.estadoNombre.isNotEmpty
        ? widget.tarea.estadoNombre
        : widget.tarea.estado.value;

    if (!_columnasDisponibles.contains(_columnaActual)) {
      _columnaActual = _columnasDisponibles.first;
    }

    _prioridadActual = widget.tarea.prioridad;
    _fechaVencimiento = widget.tarea.fechaVencimiento;
    _asignadoA = widget.tarea.asignadoA;

    if (widget.tablero != null && (widget.tablero!.esGrupal || widget.tablero!.miembrosIds.isNotEmpty)) {
      _cargarMiembrosTablero();
    }
  }

  Future<void> _cargarMiembrosTablero() async {
    if (widget.tablero == null) return;
    setState(() => _cargandoMiembros = true);
    List<Usuario> lista = [];
    for (String id in widget.tablero!.miembrosIds) {
      final u = await _firestoreService.obtenerUsuarioPorId(id);
      if (u != null) {
        lista.add(u);
      }
    }
    if (mounted) {
      setState(() {
        _miembrosEquipo = lista;
        _cargandoMiembros = false;
      });
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color textoPrincipal = Color(0xFF1E293B);
    const Color azulCielo = Color(0xFF52ABEB);
    const Color verdeTurquesa = Color(0xFF63D0A1);
    const Color rojoAlta = Color(0xFFE53E3E);
    const Color naranjaMedia = Color(0xFFED8936);
    const Color verdeBaja = Color(0xFF38A169);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final permisos = widget.tablero?.obtenerPermisosDeUsuario(uid) ?? PermisosMiembro.todos;
    final colorPrioridad = FormatoUtil.obtenerColorPorPrioridad(_prioridadActual);

    // Obtener usuario asignado si existe
    Usuario? usuarioAsignado;
    if (_asignadoA != null) {
      final index = _miembrosEquipo.indexWhere((u) => u.id == _asignadoA);
      if (index != -1) usuarioAsignado = _miembrosEquipo[index];
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BARRA SUPERIOR: ETIQUETA DE COLOR Y ACCIONES ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Indicador de prioridad
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorPrioridad.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorPrioridad, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_rounded, size: 14, color: colorPrioridad),
                      const SizedBox(width: 4),
                      Text(
                        'Prioridad ${FormatoUtil.obtenerTextoPrioridad(_prioridadActual)}',
                        style: TextStyle(
                          color: colorPrioridad,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (permisos.editarTareas)
                      IconButton(
                        icon: Icon(
                          _modoEdicion ? Icons.edit_off_rounded : Icons.edit_rounded,
                          color: azulCielo,
                        ),
                        tooltip: _modoEdicion ? 'Cancelar edición' : 'Editar tarea',
                        onPressed: () => setState(() => _modoEdicion = !_modoEdicion),
                      ),
                    if (permisos.eliminarTareas)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        tooltip: 'Eliminar tarea',
                        onPressed: _confirmarEliminacion,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- TÍTULO (LECTURA O EDICIÓN) ---
            if (_modoEdicion)
              TextFormField(
                controller: _tituloController,
                decoration: InputDecoration(
                  labelText: 'Título*',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: azulCielo, width: 2),
                  ),
                ),
              )
            else
              Text(
                widget.tarea.titulo,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textoPrincipal,
                ),
              ),
            const SizedBox(height: 14),

            // --- DESCRIPCIÓN ---
            if (_modoEdicion)
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: azulCielo, width: 2),
                  ),
                ),
              )
            else
              Text(
                widget.tarea.descripcion != null && widget.tarea.descripcion!.isNotEmpty
                    ? widget.tarea.descripcion!
                    : 'Sin descripción adicional.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: widget.tarea.descripcion != null ? Colors.grey.shade700 : Colors.grey.shade400,
                  height: 1.5,
                ),
              ),
            const SizedBox(height: 20),

            const Divider(),
            const SizedBox(height: 12),

            // --- SECCIÓN: INTEGRANTE ASIGNADO EN TABLEROS DE EQUIPO ---
            if (widget.tablero != null && (widget.tablero!.esGrupal || widget.tablero!.miembrosIds.isNotEmpty)) ...[
              Text(
                'Integrante Asignado:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textoPrincipal),
              ),
              const SizedBox(height: 8),
              if (_modoEdicion)
                _cargandoMiembros
                    ? const LinearProgressIndicator()
                    : DropdownButtonFormField<String?>(
                        value: _asignadoA,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          prefixIcon: const Icon(Icons.person_outline, color: azulCielo),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Sin asignar', style: TextStyle(color: Colors.grey)),
                          ),
                          ..._miembrosEquipo.map((m) {
                            final infoRole = widget.tablero?.miembrosInfo[m.id]?.rolKanban ?? m.rol;
                            return DropdownMenuItem<String?>(
                              value: m.id,
                              child: Text('${m.nombreCompleto} ($infoRole)', style: const TextStyle(fontSize: 13)),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _asignadoA = val);
                        },
                      )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _asignadoA != null ? azulCielo : Colors.grey.shade300,
                        child: Text(
                          usuarioAsignado != null && usuarioAsignado.nombreCompleto.isNotEmpty
                              ? usuarioAsignado.nombreCompleto[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              usuarioAsignado != null ? usuarioAsignado.nombreCompleto : 'Sin asignar',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textoPrincipal),
                            ),
                            if (usuarioAsignado != null)
                              Text(
                                usuarioAsignado.email,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // --- CAMBIO RÁPIDO DE COLUMNA (ESTADO) ---
            Text(
              'Mover a columna:',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textoPrincipal),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _columnaActual,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: _columnasDisponibles.map((col) {
                return DropdownMenuItem(
                  value: col,
                  child: Text(col, style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: (_procesando || !permisos.moverTareas) ? null : _cambiarEstadoRapido,
            ),
            const SizedBox(height: 16),

            // --- FECHA Y PRIORIDAD EN MODO EDICIÓN ---
            if (_modoEdicion) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.calendar_today_rounded, size: 18, color: textoPrincipal),
                label: Text(
                  _fechaVencimiento == null
                      ? 'Asignar Fecha de Entrega'
                      : 'Entrega: ${_fechaVencimiento!.day}/${_fechaVencimiento!.month}/${_fechaVencimiento!.year}',
                  style: const TextStyle(color: textoPrincipal, fontWeight: FontWeight.w600),
                ),
                onPressed: () async {
                  final fecha = await showDatePicker(
                    context: context,
                    initialDate: _fechaVencimiento ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (fecha != null) setState(() => _fechaVencimiento = fecha);
                },
              ),
              const SizedBox(height: 16),
              Text('Nivel de Importancia (Prioridad):', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textoPrincipal)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _botonPrioridad(1, 'Baja', verdeBaja),
                  _botonPrioridad(2, 'Media', naranjaMedia),
                  _botonPrioridad(3, 'Alta', rojoAlta),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // --- BOTÓN DE GUARDADO (SOLO EN MODO EDICIÓN) ---
            if (_modoEdicion)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verdeTurquesa,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _procesando ? null : _guardarCambiosCompletos,
                  child: _procesando
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Guardar Cambios', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- WIDGET AUXILIAR DE BOTONES DE PRIORIDAD ---
  Widget _botonPrioridad(int valor, String texto, Color color) {
    final activo = _prioridadActual == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _prioridadActual = valor),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: activo ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: activo ? 2 : 1),
          ),
          alignment: Alignment.center,
          child: Text(
            texto,
            style: TextStyle(
              color: activo ? Colors.white : const Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // --- LÓGICA DE CONTROLADORES (FIRESTORE) ---

  void _cambiarEstadoRapido(String? nuevoEstado) async {
    if (nuevoEstado == null || nuevoEstado == _columnaActual) return;

    // Verificar límite de 10 tareas en la columna destino
    if (widget.tablero != null) {
      final tareasExistentes = await _firestoreService.obtenerTareasDeTablero(widget.tablero!.id);
      final enColumnaDestino = tareasExistentes.where((t) {
        return t.estadoNombre == nuevoEstado || t.estado.value == nuevoEstado;
      }).length;

      if (enColumnaDestino >= 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Límite alcanzado: La columna "$nuevoEstado" ya tiene el máximo de 10 tareas.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _columnaActual = nuevoEstado;
      _procesando = true;
    });

    try {
      await _firestoreService.actualizarEstadoTarea(widget.tarea.id, nuevoEstado);

      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tarea movida a: $nuevoEstado'), backgroundColor: const Color(0xFF52ABEB)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al mover tarea: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _guardarCambiosCompletos() async {
    if (_tituloController.text.trim().isEmpty) return;

    setState(() => _procesando = true);

    try {
      final enumEstado = EstadoTareaExtension.fromString(_columnaActual);
      final tareaActualizada = widget.tarea.copyWith(
        titulo: _tituloController.text.trim(),
        descripcion: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        estado: enumEstado,
        estadoNombre: _columnaActual,
        prioridad: _prioridadActual,
        fechaVencimiento: _fechaVencimiento,
        asignadoA: _asignadoA,
      );

      await _firestoreService.actualizarTarea(tareaActualizada);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados con éxito'), backgroundColor: Color(0xFF63D0A1)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmarEliminacion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar tarea?'),
        content: Text('¿Estás seguro de que deseas eliminar "${widget.tarea.titulo}"? Esta acción la archivará del tablero.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              nav.pop();
              setState(() => _procesando = true);
              try {
                await _firestoreService.eliminarTarea(widget.tarea.id);
                if (mounted) {
                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Tarea eliminada'), backgroundColor: Colors.redAccent),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _procesando = false);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
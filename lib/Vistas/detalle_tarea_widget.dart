import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- IMPORTS DE LOS MODELOS Y SERVICIOS DEL EQUIPO ---
import '../modelo/tarea.dart';
import '../modelo/tablero.dart';
import '../modelo/usuario.dart';
import '../modelo/borrador_nota.dart';
import '../servicios/firestore_service.dart';
import '../servicios/storage_service.dart';
import '../utilerias/formato_util.dart';
import 'pantalla_visualizador_adjunto.dart';
import '../utilerias/mensajes_error.dart';

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

  // Control de modo: false = Solo lectura desaturada, true = Editando campos
  bool _modoEdicion = false;
  bool _procesando = false;

  // Controladores y variables de estado
  late TextEditingController _tituloController;
  late TextEditingController _descController;
  late TextEditingController _comentarioController;
  late String _columnaActual;
  late int _prioridadActual;
  DateTime? _fechaVencimiento;
  List<String> _asignadosA = [];
  List<AdjuntoTarea> _adjuntosActuales = [];
  List<ComentarioTarea> _comentariosActuales = [];
  List<Usuario> _miembrosEquipo = [];
  bool _cargandoMiembros = false;
  bool _enviandoComentario = false;

  late List<String> _columnasDisponibles;

  // Límite máximo de tamaño por archivo: 10 MB
  static const int _maxTamanoBytes = 10 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.tarea.titulo);
    _descController = TextEditingController(text: widget.tarea.descripcion ?? '');
    _comentarioController = TextEditingController();

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
    _asignadosA = List.from(widget.tarea.asignadosA);
    _adjuntosActuales = List.from(widget.tarea.adjuntos);
    _comentariosActuales = List.from(widget.tarea.comentarios);

    if (widget.tablero != null && widget.tablero!.esGrupal) {
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
    _comentarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textoPrincipal = theme.colorScheme.onSurface;
    const Color azulCielo = Color(0xFF52ABEB);
    const Color verdeTurquesa = Color(0xFF63D0A1);
    const Color rojoAlta = Color(0xFFE53E3E);
    const Color naranjaMedia = Color(0xFFED8936);
    const Color verdeBaja = Color(0xFF38A169);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final permisos = widget.tablero?.obtenerPermisosDeUsuario(uid) ?? PermisosMiembro.todos;
    final colorPrioridad = FormatoUtil.obtenerColorPorPrioridad(_prioridadActual);

    final usuariosAsignados = _miembrosEquipo.where((u) => _asignadosA.contains(u.id)).toList();
    String textoAsignados = 'Sin asignar';
    if (_asignadosA.isNotEmpty) {
      if (usuariosAsignados.isNotEmpty) {
        if (usuariosAsignados.length == 1) {
          textoAsignados = usuariosAsignados.first.nombreCompleto;
        } else {
          textoAsignados = '${usuariosAsignados.length} asignados (${usuariosAsignados.map((u) => u.nombreCompleto.split(' ').first).join(', ')})';
        }
      } else {
        textoAsignados = '${_asignadosA.length} asignado${_asignadosA.length > 1 ? "s" : ""}';
      }
    }

    Widget contenidoInfo = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SECCIÓN DE MODO EDICIÓN
          if (_modoEdicion) ...[
            // BANNER INDICADOR DE MODO EDICIÓN
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: verdeTurquesa.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: verdeTurquesa.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.edit_rounded, size: 16, color: verdeTurquesa),
                  SizedBox(width: 8),
                  // Expanded: en vertical el texto se baja de renglón en lugar de desbordar.
                  Expanded(
                    child: Text(
                      'Modo Edición: Modifica los campos y guarda los cambios.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: verdeTurquesa),
                    ),
                  ),
                ],
              ),
            ),

            // ASIGNAR INTEGRANTES EN MODO EDICIÓN
            if (widget.tablero != null && widget.tablero!.esGrupal) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text('Asignar a Integrantes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _asignadosA.isEmpty
                          ? 'Sin asignar (0)'
                          : '${_asignadosA.length} persona${_asignadosA.length > 1 ? "s" : ""}',
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _asignadosA.isEmpty ? Colors.grey : azulCielo),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _cargandoMiembros
                  ? const LinearProgressIndicator()
                  : _miembrosEquipo.isEmpty
                  ? Text('No hay integrantes en este tablero.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
                  : Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _miembrosEquipo.map((m) {
                  final estaSeleccionado = _asignadosA.contains(m.id);
                  return FilterChip(
                    avatar: CircleAvatar(
                      backgroundColor: estaSeleccionado ? Colors.white : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                      child: Text(
                        m.nombreCompleto.isNotEmpty ? m.nombreCompleto[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: estaSeleccionado ? azulCielo : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                        ),
                      ),
                    ),
                    label: Text(
                      m.nombreCompleto,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: estaSeleccionado ? FontWeight.bold : FontWeight.normal,
                        color: estaSeleccionado ? Colors.white : textoPrincipal,
                      ),
                    ),
                    selected: estaSeleccionado,
                    selectedColor: azulCielo,
                    checkmarkColor: Colors.white,
                    backgroundColor: isDark ? const Color(0xFF182030) : Colors.grey.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: estaSeleccionado ? azulCielo : (isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
                      ),
                    ),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _asignadosA.add(m.id);
                        } else {
                          _asignadosA.remove(m.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // SELECTOR DE FECHA DE ENTREGA Y PRIORIDAD EN EDICIÓN
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.calendar_today_rounded, size: 15, color: textoPrincipal),
                    label: Text(
                      _fechaVencimiento == null
                          ? 'Asignar Entrega'
                          : '${_fechaVencimiento!.day}/${_fechaVencimiento!.month}/${_fechaVencimiento!.year}',
                      style: TextStyle(color: textoPrincipal, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final fecha = await showDatePicker(
                        context: context,
                        initialDate: _fechaVencimiento ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: Localizations.localeOf(context),
                      );
                      if (fecha != null) setState(() => _fechaVencimiento = fecha);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _botonPrioridad(1, 'Baja', verdeBaja),
                _botonPrioridad(2, 'Media', naranjaMedia),
                _botonPrioridad(3, 'Alta', rojoAlta),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // DESCRIPCIÓN DE LA TAREA
          Row(
            children: [
              const Icon(Icons.notes_rounded, size: 15, color: azulCielo),
              const SizedBox(width: 6),
              Text(
                'Descripción:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_modoEdicion)
            TextFormField(
              controller: _descController,
              minLines: 3,
              maxLines: 6,
              style: GoogleFonts.inter(fontSize: 13, color: textoPrincipal, height: 1.4),
              decoration: InputDecoration(
                hintText: 'Escribe la descripción de la tarea...',
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? const Color(0xFF182030) : Colors.grey.shade50,
              ),
            )
          else
            _descController.text.trim().isNotEmpty
                ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF182030) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade200),
              ),
              child: Text(
                _descController.text.trim(),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: textoPrincipal,
                  height: 1.4,
                ),
              ),
            )
                : Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Sin descripción detallada.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 14),

          // SECCIÓN: ARCHIVOS ADJUNTOS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Archivos Adjuntos (${_adjuntosActuales.length}):',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal),
              ),
              if (_modoEdicion)
                TextButton.icon(
                  onPressed: _mostrarMenuAdjuntarArchivo,
                  icon: const Icon(Icons.attach_file_rounded, size: 16, color: azulCielo),
                  label: const Text('Adjuntar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: azulCielo)),
                ),
            ],
          ),
          const SizedBox(height: 6),

          if (_adjuntosActuales.isEmpty)
            Text(
              'Esta tarea no tiene archivos adjuntos.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            )
          else
            Column(
              children: _adjuntosActuales.asMap().entries.map((entry) {
                final idx = entry.key;
                final adjunto = entry.value;

                return GestureDetector(
                  onTap: () => _abrirVisualizadorAdjunto(adjunto),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        _obtenerIconoTipoAdjunto(adjunto.tipo, adjunto.nombre),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                adjunto.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textoPrincipal),
                              ),
                              Text(
                                '${adjunto.tipo.toUpperCase()} • ${adjunto.tamanoLegible}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                        if (_modoEdicion)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            onPressed: () => setState(() => _adjuntosActuales.removeAt(idx)),
                          )
                        else
                          const Icon(Icons.remove_red_eye_outlined, size: 16, color: azulCielo),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),

          // BOTÓN GUARDAR (SOLO EN EDICIÓN)
          if (_modoEdicion)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: verdeTurquesa,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: _procesando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                label: Text(
                  _procesando ? 'Guardando...' : 'Guardar Cambios',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _procesando ? null : _guardarCambiosCompletos,
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );

    return DefaultTabController(
      length: 3,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            left: 18,
            right: 18,
            top: 14,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- BARRA SUPERIOR LIMPIA CON ACCIONES ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicador de estado rápido / Columna compacta
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: azulCielo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: azulCielo.withValues(alpha: 0.4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _columnaActual,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: azulCielo, size: 20),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: azulCielo),
                        items: _columnasDisponibles.map((col) {
                          return DropdownMenuItem(
                            value: col,
                            child: Text(col, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal)),
                          );
                        }).toList(),
                        onChanged: (_procesando || !permisos.moverTareas) ? null : _cambiarEstadoRapido,
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      if (permisos.editarTareas)
                        IconButton(
                          icon: Icon(
                            _modoEdicion ? Icons.check_circle_rounded : Icons.edit_outlined,
                            color: _modoEdicion ? verdeTurquesa : Colors.grey.shade700,
                            size: 22,
                          ),
                          tooltip: _modoEdicion ? 'Guardar / Cancelar edición' : 'Editar tarea',
                          onPressed: () => setState(() => _modoEdicion = !_modoEdicion),
                        ),
                      if (permisos.eliminarTareas)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                          tooltip: 'Eliminar tarea',
                          onPressed: _confirmarEliminacion,
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // --- TÍTULO DE LA TAREA ---
              if (_modoEdicion)
                TextFormField(
                  controller: _tituloController,
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: textoPrincipal),
                  decoration: InputDecoration(
                    labelText: 'Título de la tarea *',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF182030) : Colors.grey.shade50,
                  ),
                )
              else
                Text(
                  _tituloController.text.trim().isNotEmpty ? _tituloController.text.trim() : 'Tarea sin título',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textoPrincipal,
                  ),
                ),
              const SizedBox(height: 10),

              // --- BARRA COMPACTA DE METADATOS (INSIGNIAS / CHIPS DESATURADAS) ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // 1. Badge Prioridad
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colorPrioridad.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorPrioridad.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag_rounded, size: 13, color: colorPrioridad),
                          const SizedBox(width: 4),
                          Text(
                            FormatoUtil.obtenerTextoPrioridad(_prioridadActual),
                            style: TextStyle(color: colorPrioridad, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. Badge Integrante(s) Asignado(s)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _asignadosA.isNotEmpty ? azulCielo.withValues(alpha: 0.12) : (isDark ? const Color(0xFF182030) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _asignadosA.isNotEmpty ? azulCielo.withValues(alpha: 0.4) : (isDark ? const Color(0xFF2D3748) : Colors.grey.shade300)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: _asignadosA.isNotEmpty ? azulCielo : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                            child: Text(
                              usuariosAsignados.isNotEmpty
                                  ? usuariosAsignados.first.nombreCompleto[0].toUpperCase()
                                  : (_asignadosA.isNotEmpty ? '${_asignadosA.length}' : '?'),
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            textoAsignados,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _asignadosA.isNotEmpty ? textoPrincipal : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 3. Badge Fecha Entrega
                    if (_fechaVencimiento != null || _modoEdicion)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _fechaVencimiento != null ? Colors.amber.shade900.withValues(alpha: 0.2) : (isDark ? const Color(0xFF182030) : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _fechaVencimiento != null ? Colors.amber.shade400 : (isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: _fechaVencimiento != null ? Colors.amber.shade400 : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _fechaVencimiento != null
                                  ? '${_fechaVencimiento!.day}/${_fechaVencimiento!.month}/${_fechaVencimiento!.year}'
                                  : 'Sin fecha',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _fechaVencimiento != null ? Colors.amber.shade400 : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // --- EN MODO EDICIÓN OCULTAMOS LA BARRA DE PESTAÑAS Y LOS COMENTARIOS ---
              if (!_modoEdicion) ...[
                TabBar(
                  labelColor: azulCielo,
                  unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  indicatorColor: azulCielo,
                  indicatorWeight: 2.5,
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                  unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
                  tabs: [
                    // FittedBox(scaleDown): en teléfonos en vertical el texto de la pestaña
                    // no cabía ("RIGHT OVERFLOWED"); ahora se reduce lo justo. Si hay
                    // espacio (horizontal) se ve exactamente igual que antes.
                    const Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 15),
                            SizedBox(width: 4),
                            Text('Información'),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.forum_outlined, size: 15),
                            const SizedBox(width: 4),
                            Text('Comentarios (${_comentariosActuales.length})'),
                          ],
                        ),
                      ),
                    ),
                    const Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sticky_note_2_outlined, size: 15),
                            SizedBox(width: 4),
                            Text('Notas'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // --- CONTENIDO DE LAS PESTAÑAS / MODO EDICIÓN DIRECCIÓN ÚNICA ---
              Expanded(
                child: _modoEdicion
                    ? contenidoInfo
                    : TabBarView(
                  children: [
                    // PESTAÑA 1: INFORMACIÓN GENERAL EN MODO LECTURA
                    contenidoInfo,

                    // PESTAÑA 2: COMENTARIOS Y RETROALIMENTACIÓN
                    Column(
                      children: [
                        Expanded(
                          child: _comentariosActuales.isEmpty
                              ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.forum_outlined, size: 42, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Text(
                                  'No hay comentarios aún',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade600),
                                ),
                                Text(
                                  'Escribe observaciones o retroalimentación para tu equipo.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                              : ListView.builder(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            itemCount: _comentariosActuales.length,
                            itemBuilder: (context, index) {
                              final com = _comentariosActuales[index];
                              final esMio = com.autorId == uid;
                              final esAdmin = widget.tablero?.esAdminOCreador(uid) ?? true;
                              final fechaTexto = FormatoUtil.formatearFechaHora(com.fechaCreacion);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF182030) : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: azulCielo.withValues(alpha: 0.2),
                                          child: Text(
                                            com.autorNombre.isNotEmpty ? com.autorNombre[0].toUpperCase() : 'U',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: azulCielo),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(com.autorNombre, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textoPrincipal)),
                                              Text(fechaTexto, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                                            ],
                                          ),
                                        ),
                                        if (esMio || esAdmin)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                            onPressed: () => _eliminarComentario(index),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(com.contenido, style: TextStyle(fontSize: 12, color: textoPrincipal, height: 1.3)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        // CAJA DE ENTRADA DE COMENTARIO
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF182030) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _comentarioController,
                                  maxLines: null,
                                  decoration: const InputDecoration(
                                    hintText: 'Escribe un comentario...',
                                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                                    border: InputBorder.none,
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                icon: _enviandoComentario
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: azulCielo))
                                    : const Icon(Icons.send_rounded, color: azulCielo, size: 18),
                                onPressed: _enviandoComentario ? null : _agregarComentario,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // PESTAÑA 3: NOTAS PERSONALES VINCULADAS
                    StreamBuilder<List<BorradorNota>>(
                      stream: _firestoreService.escucharNotasDeTarea(widget.tarea.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: azulCielo));
                        }
                        final notas = snapshot.data ?? [];

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Notas Personales (${notas.length})',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textoPrincipal),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: azulCielo,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                    label: const Text('Agregar Nota', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: _crearNotaVinculadaDirecta,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: notas.isEmpty
                                  ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.sticky_note_2_outlined, size: 42, color: Colors.grey.shade300),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No hay notas vinculadas a esta tarea',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Los integrantes pueden agregar notas personales sobre el avance de esta tarea.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              )
                                  : ListView.builder(
                                padding: const EdgeInsets.only(top: 6, bottom: 8),
                                itemCount: notas.length,
                                itemBuilder: (context, index) {
                                  final nota = notas[index];
                                  final colorVal = int.tryParse(nota.colorHex) ?? 0xFF52ABEB;
                                  final colorBorder = Color(colorVal);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: colorBorder.withValues(alpha: 0.5), width: 1.2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                nota.titulo,
                                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: textoPrincipal),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  FormatoUtil.formatearFechaHora(nota.fechaCreacion),
                                                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                                                ),
                                                if (nota.usuarioId == uid)
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                                    onPressed: () => _firestoreService.eliminarBorradorNota(nota.id),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if (nota.contenido.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            nota.contenido,
                                            style: TextStyle(fontSize: 12, color: textoPrincipal, height: 1.3),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _crearNotaVinculadaDirecta() {
    final tituloCtrl = TextEditingController();
    final contenidoCtrl = TextEditingController();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 20, right: 20, top: 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📝 Crear Nota Personal Vinculada',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Vinculada a: "${widget.tarea.titulo}"',
                style: const TextStyle(fontSize: 11, color: Color(0xFF52ABEB), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tituloCtrl,
                decoration: InputDecoration(
                  labelText: 'Título de la Nota *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF182030) : Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contenidoCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Contenido / Anotaciones',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF182030) : Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF52ABEB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                  label: const Text('Guardar Nota Vinculada', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final t = tituloCtrl.text.trim();
                    if (t.isEmpty) return;
                    Navigator.pop(ctx);

                    final nuevaNota = BorradorNota(
                      id: FirebaseFirestore.instance.collection('borradores_notas').doc().id,
                      usuarioId: uid,
                      tableroId: widget.tarea.tableroId,
                      titulo: t,
                      contenido: contenidoCtrl.text.trim(),
                      fechaCreacion: DateTime.now(),
                      tareaId: widget.tarea.id,
                      tareaTitulo: widget.tarea.titulo,
                      esNotaPersonal: true,
                    );

                    await _firestoreService.crearBorradorNota(nuevaNota);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nota vinculada agregada'), backgroundColor: Color(0xFF63D0A1)),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- SELECCIÓN Y VALIDACIÓN DE ARCHIVOS EN MODO EDICIÓN CON LÍMITE DE 10MB ---
  void _mostrarMenuAdjuntarArchivo() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adjuntar Archivo a la Tarea (Máx. 10MB):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFEBF8FF), child: Icon(Icons.image_rounded, color: Color(0xFF52ABEB))),
                  title: const Text('Imagen / Foto'),
                  subtitle: const Text('PNG, JPG, WEBP'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarArchivo(FileType.image, 'imagen');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFFFF5F5), child: Icon(Icons.videocam_rounded, color: Colors.redAccent)),
                  title: const Text('Video'),
                  subtitle: const Text('MP4, MOV, AVI'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarArchivo(FileType.video, 'video');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFFFF3ED), child: Icon(Icons.slideshow_rounded, color: Color(0xFFC43E1C))),
                  title: const Text('Presentación PowerPoint'),
                  subtitle: const Text('PPT, PPTX'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarArchivo(FileType.custom, 'documento', extensiones: ['pptx', 'ppt']);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFF0FDF4), child: Icon(Icons.description_rounded, color: Color(0xFF63D0A1))),
                  title: const Text('Documento / PDF'),
                  subtitle: const Text('PDF, DOC, DOCX, XLSX, TXT'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarArchivo(FileType.custom, 'documento', extensiones: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'csv', 'pptx', 'ppt']);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _seleccionarArchivo(FileType fileType, String tipoEtiqueta, {List<String>? extensiones}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: extensiones,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          final tamano = file.size;

          if (tamano > _maxTamanoBytes) {
            final tamanoMB = (tamano / (1024 * 1024)).toStringAsFixed(1);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('El archivo "${file.name}" excede el límite permitido de 10 MB ($tamanoMB MB)'),
                  backgroundColor: Colors.redAccent,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            continue;
          }

          String tipoReal = tipoEtiqueta;
          final ext = file.extension?.toLowerCase() ?? '';
          if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
            tipoReal = 'imagen';
          } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
            tipoReal = 'video';
          }

          final adjunto = AdjuntoTarea(
            id: FirebaseFirestore.instance.collection('adjuntos').doc().id,
            nombre: file.name,
            url: file.path ?? file.name,
            tipo: tipoReal,
            tamanoBytes: tamano,
            fechaAdjunto: DateTime.now(),
          );

          setState(() {
            _adjuntosActuales.add(adjunto);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MensajesError.desde(e, accion: 'seleccionar el archivo'))),
        );
      }
    }
  }

  void _abrirVisualizadorAdjunto(AdjuntoTarea adjunto) {
    PantallaVisualizadorAdjunto.abrir(context, adjunto);
  }

  Widget _obtenerIconoTipoAdjunto(String tipo, [String? nombre]) {
    final nameLower = (nombre ?? '').toLowerCase();
    final tipoLower = tipo.toLowerCase();

    if (nameLower.endsWith('.pptx') || nameLower.endsWith('.ppt')) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: const Color(0xFFC43E1C).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.slideshow_rounded, color: Color(0xFFC43E1C), size: 18),
      );
    } else if (nameLower.endsWith('.xlsx') || nameLower.endsWith('.xls') || nameLower.endsWith('.csv')) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: const Color(0xFF107C41).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.table_chart_rounded, color: Color(0xFF107C41), size: 18),
      );
    } else if (nameLower.endsWith('.docx') || nameLower.endsWith('.doc')) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: const Color(0xFF2B579A).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.description_rounded, color: Color(0xFF2B579A), size: 18),
      );
    } else if (nameLower.endsWith('.pdf')) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: const Color(0xFFD32F2F).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFD32F2F), size: 18),
      );
    } else if (tipoLower == 'imagen' || ['.jpg', '.jpeg', '.png', '.webp', '.gif'].any((ext) => nameLower.endsWith(ext))) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: const Color(0xFF52ABEB).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.image_rounded, color: Color(0xFF52ABEB), size: 18),
      );
    } else if (tipoLower == 'video' || ['.mp4', '.mov', '.avi', '.mkv'].any((ext) => nameLower.endsWith(ext))) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.videocam_rounded, color: Colors.redAccent, size: 18),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0xFF63D0A1).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.description_rounded, color: Color(0xFF63D0A1), size: 18),
    );
  }

  Widget _botonPrioridad(int valor, String texto, Color color) {
    final activo = _prioridadActual == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _prioridadActual = valor),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: activo ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: activo ? 1.8 : 1),
          ),
          alignment: Alignment.center,
          child: Text(
            texto,
            style: TextStyle(
              color: activo ? Colors.white : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  void _cambiarEstadoRapido(String? nuevoEstado) async {
    if (nuevoEstado == null || nuevoEstado == _columnaActual) return;

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
          SnackBar(content: Text(MensajesError.desde(e, accion: 'mover la tarea')), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _guardarCambiosCompletos() async {
    if (_tituloController.text.trim().isEmpty) return;

    setState(() => _procesando = true);

    try {
      List<AdjuntoTarea> adjuntosSubidos = [];
      final storageService = StorageService();
      for (final adj in _adjuntosActuales) {
        if (adj.url.isNotEmpty && !adj.url.startsWith('http')) {
          final urlRemota = await storageService.subirAdjuntoTarea(
            filePath: adj.url,
            nombreArchivo: adj.nombre,
            tareaId: widget.tarea.id,
          );
          adjuntosSubidos.add(AdjuntoTarea(
            id: adj.id,
            nombre: adj.nombre,
            url: urlRemota,
            tipo: adj.tipo,
            tamanoBytes: adj.tamanoBytes,
            fechaAdjunto: adj.fechaAdjunto,
          ));
        } else {
          adjuntosSubidos.add(adj);
        }
      }

      final enumEstado = EstadoTareaExtension.fromString(_columnaActual);
      final tareaActualizada = widget.tarea.copyWith(
        titulo: _tituloController.text.trim(),
        descripcion: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        estado: enumEstado,
        estadoNombre: _columnaActual,
        prioridad: _prioridadActual,
        fechaVencimiento: _fechaVencimiento,
        asignadosA: _asignadosA,
        adjuntos: adjuntosSubidos,
        comentarios: _comentariosActuales,
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
          SnackBar(content: Text(MensajesError.desde(e, accion: 'guardar los cambios de la tarea')), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmarEliminacion() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Estás seguro de que deseas eliminar "${widget.tarea.titulo}"? Esta acción la archivará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final rootNav = Navigator.of(context);
              final sca = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              setState(() => _procesando = true);
              try {
                await _firestoreService.eliminarTarea(widget.tarea.id);
                if (mounted) {
                  rootNav.pop();
                  sca.showSnackBar(
                    const SnackBar(content: Text('Tarea eliminada'), backgroundColor: Colors.redAccent),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _procesando = false);
                  sca.showSnackBar(
                    SnackBar(content: Text(MensajesError.desde(e, accion: 'eliminar la tarea'))),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _agregarComentario() async {
    final texto = _comentarioController.text.trim();
    if (texto.isEmpty) return;

    setState(() => _enviandoComentario = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? 'anonimo';

      String nombreAutor = 'Integrante';
      if (user?.displayName != null && user!.displayName!.isNotEmpty) {
        nombreAutor = user.displayName!;
      } else {
        final usuarioDoc = await _firestoreService.obtenerUsuarioPorId(uid);
        if (usuarioDoc != null && usuarioDoc.nombreCompleto.isNotEmpty) {
          nombreAutor = usuarioDoc.nombreCompleto;
        } else if (user?.email != null) {
          nombreAutor = user!.email!.split('@').first;
        }
      }

      final nuevoComentario = ComentarioTarea(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        autorId: uid,
        autorNombre: nombreAutor,
        autorFotoUrl: user?.photoURL,
        contenido: texto,
        fechaCreacion: DateTime.now(),
      );

      if (widget.tarea.id.isNotEmpty) {
        await _firestoreService.agregarComentarioTarea(
          tareaId: widget.tarea.id,
          comentario: nuevoComentario,
        );
      }

      if (mounted) {
        setState(() {
          _comentariosActuales.add(nuevoComentario);
          _comentarioController.clear();
          _enviandoComentario = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enviandoComentario = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MensajesError.desde(e, accion: 'publicar el comentario'))),
        );
      }
    }
  }

  Future<void> _eliminarComentario(int index) async {
    if (index < 0 || index >= _comentariosActuales.length) return;
    final comentario = _comentariosActuales[index];

    try {
      if (widget.tarea.id.isNotEmpty) {
        await _firestoreService.eliminarComentarioTarea(
          tareaId: widget.tarea.id,
          comentario: comentario,
        );
      }

      if (mounted) {
        setState(() {
          _comentariosActuales.removeAt(index);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MensajesError.desde(e, accion: 'eliminar el comentario'))),
        );
      }
    }
  }
}
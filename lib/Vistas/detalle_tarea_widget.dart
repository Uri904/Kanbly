import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- IMPORTS DE LOS MODELOS Y SERVICIOS DEL EQUIPO ---
import '../modelo/tarea.dart';
import '../modelo/tablero.dart';
import '../modelo/usuario.dart';
import '../servicios/firestore_service.dart';
import '../utilerias/formato_util.dart';
import 'pantalla_visualizador_adjunto.dart';

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
  List<AdjuntoTarea> _adjuntosActuales = [];
  List<Usuario> _miembrosEquipo = [];
  bool _cargandoMiembros = false;

  late List<String> _columnasDisponibles;

  // Límite máximo de tamaño por archivo: 10 MB (10 * 1024 * 1024 bytes)
  static const int _maxTamanoBytes = 10 * 1024 * 1024;

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
    _adjuntosActuales = List.from(widget.tarea.adjuntos);

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

    // Obtener permisos del usuario actual en este tablero
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final permisos = widget.tablero?.obtenerPermisosDeUsuario(uid) ?? PermisosMiembro.todos;

    // Color dinámico según la prioridad de la tarea
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
        left: 24, right: 24, top: 24,
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
                    color: colorPrioridad.withOpacity(0.15),
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

            // --- TÍTULO DE LA TAREA ---
            if (_modoEdicion)
              TextFormField(
                controller: _tituloController,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textoPrincipal),
                decoration: InputDecoration(
                  labelText: 'Título de la tarea *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              )
            else
              Text(
                _tituloController.text.trim().isNotEmpty ? _tituloController.text : 'Tarea sin título',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textoPrincipal,
                ),
              ),
            const SizedBox(height: 12),

            // --- DESCRIPCIÓN ---
            if (_modoEdicion)
              TextFormField(
                controller: _descController,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 14, color: textoPrincipal),
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  _descController.text.trim().isNotEmpty
                      ? _descController.text
                      : 'Sin descripción detallada.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // --- SECCIÓN: INTEGRANTE ASIGNADO (EXCLUSIVO TABLEROS EN EQUIPO) ---
            if (widget.tablero != null && widget.tablero!.esGrupal) ...[
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
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Sin asignar', style: TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis),
                          ),
                          ..._miembrosEquipo.map((m) {
                            final infoRole = widget.tablero?.miembrosInfo[m.id]?.rolKanban ?? m.rol;
                            return DropdownMenuItem<String?>(
                              value: m.id,
                              child: Text(
                                '${m.nombreCompleto} ($infoRole)',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
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
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: _columnasDisponibles.map((col) {
                return DropdownMenuItem(
                  value: col,
                  child: Text(col, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
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

              Text(
                'Prioridad:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textoPrincipal),
              ),
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

            // --- SECCIÓN: ARCHIVOS ADJUNTOS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Archivos Adjuntos (${_adjuntosActuales.length}):',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textoPrincipal),
                ),
                if (_modoEdicion)
                  TextButton.icon(
                    onPressed: _mostrarMenuAdjuntarArchivo,
                    icon: const Icon(Icons.attach_file_rounded, size: 18, color: azulCielo),
                    label: const Text('Adjuntar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: azulCielo)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_adjuntosActuales.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'Esta tarea no tiene archivos adjuntos.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              )
            else
              Column(
                children: _adjuntosActuales.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final adjunto = entry.value;

                  return GestureDetector(
                    onTap: () => _abrirVisualizadorAdjunto(adjunto),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _obtenerIconoTipoAdjunto(adjunto.tipo),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  adjunto.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textoPrincipal),
                                ),
                                Text(
                                  '${adjunto.tipo.toUpperCase()} • ${adjunto.tamanoLegible}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          if (_modoEdicion)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                              tooltip: 'Eliminar adjunto',
                              onPressed: () {
                                setState(() {
                                  _adjuntosActuales.removeAt(idx);
                                });
                              },
                            )
                          else
                            const Icon(Icons.remove_red_eye_outlined, size: 18, color: azulCielo),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),

            // --- BOTÓN GUARDAR EDICIÓN COMPLETA ---
            if (_modoEdicion)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verdeTurquesa,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: _procesando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, color: Colors.white),
                  label: Text(
                    _procesando ? 'Guardando...' : 'Guardar Cambios',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: _procesando ? null : _guardarCambiosCompletos,
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- SELECCIÓN Y VALIDACIÓN DE ARCHIVOS EN MODO EDICIÓN CON LÍMITE DE 10MB ---
  void _mostrarMenuAdjuntarArchivo() {
    showModalBottomSheet(
      context: context,
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
                const Text(
                  'Adjuntar Archivo a la Tarea (Máx. 10MB):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
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
                  leading: const CircleAvatar(backgroundColor: Color(0xFFF0FDF4), child: Icon(Icons.description_rounded, color: Color(0xFF63D0A1))),
                  title: const Text('Documento / PDF'),
                  subtitle: const Text('PDF, DOC, DOCX, XLSX, PPTX, TXT'),
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

          // VALIDACIÓN STRICTA DEL LÍMITE DE 10 MB
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
          SnackBar(content: Text('Error al seleccionar archivo: $e')),
        );
      }
    }
  }

  void _abrirVisualizadorAdjunto(AdjuntoTarea adjunto) {
    PantallaVisualizadorAdjunto.abrir(context, adjunto);
  }

  Widget _obtenerIconoTipoAdjunto(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'imagen':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF52ABEB).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.image_rounded, color: Color(0xFF52ABEB), size: 20),
        );
      case 'video':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.videocam_rounded, color: Colors.redAccent, size: 20),
        );
      case 'documento':
      default:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF63D0A1).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.description_rounded, color: Color(0xFF63D0A1), size: 20),
        );
    }
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
            color: activo ? color : color.withOpacity(0.1),
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
        adjuntos: _adjuntosActuales,
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
          SnackBar(content: Text('Error al guardar cambios: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmarEliminacion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Estás seguro de que deseas eliminar "${widget.tarea.titulo}"? Esta acción la archivará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Cerrar diálogo
              setState(() => _procesando = true);
              try {
                await _firestoreService.eliminarTarea(widget.tarea.id);
                if (mounted) {
                  Navigator.pop(context); // Cerrar modal detalle
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tarea eliminada'), backgroundColor: Colors.redAccent),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _procesando = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e')),
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
}

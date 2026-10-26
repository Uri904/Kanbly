import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

// --- IMPORTS DE LOS MODELOS Y SERVICIOS DEL EQUIPO ---
import '../modelo/tarea.dart';
import '../modelo/tablero.dart';
import '../modelo/usuario.dart';
import '../servicios/firestore_service.dart';
import '../servicios/storage_service.dart';


class FormularioTarea extends StatefulWidget {
  final Tablero tablero;
  final EstadoTarea estadoInicial;

  const FormularioTarea({
    super.key,
    required this.tablero,
    this.estadoInicial = EstadoTarea.pendiente,
  });

  @override
  State<FormularioTarea> createState() => _FormularioTareaState();
}

class _FormularioTareaState extends State<FormularioTarea> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  late List<String> _columnasDisponibles;
  late String _columnaSeleccionada;
  int _prioridadSeleccionada = 2; // 1 = Baja, 2 = Media, 3 = Alta
  DateTime? _fechaVencimiento;
  List<String> _asignadosA = [];
  List<Usuario> _miembrosEquipo = [];
  final List<AdjuntoTarea> _adjuntosSeleccionados = [];
  bool _cargandoMiembros = false;
  bool _guardando = false;

  static const int _maxTamanoBytes = 10 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _columnasDisponibles = widget.tablero.columnas.isNotEmpty
        ? widget.tablero.columnas
        : const ['Pendiente', 'En progreso', 'Completada'];

    if (_columnasDisponibles.contains(widget.estadoInicial.value)) {
      _columnaSeleccionada = widget.estadoInicial.value;
    } else {
      _columnaSeleccionada = _columnasDisponibles.first;
    }

    if (widget.tablero.esGrupal) {
      _cargarMiembrosTablero();
    }
  }

  Future<void> _cargarMiembrosTablero() async {
    setState(() => _cargandoMiembros = true);
    List<Usuario> lista = [];
    for (String id in widget.tablero.miembrosIds) {
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
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textoPrincipal = theme.colorScheme.onSurface;
    const Color azulCielo = Color(0xFF52ABEB);
    const Color verdeTurquesa = Color(0xFF63D0A1);
    const Color rojoAlta = Color(0xFFE53E3E);
    const Color naranjaMedia = Color(0xFFED8936);
    const Color verdeBaja = Color(0xFF38A169);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 18,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ENCABEZADO LIMPIO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nueva Tarea',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textoPrincipal,
                        ),
                      ),
                      Text(
                        widget.tablero.nombre,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // CAMPO TÍTULO
              TextFormField(
                controller: _tituloController,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textoPrincipal),
                decoration: InputDecoration(
                  labelText: 'Título de la tarea *',
                  hintText: 'Ej. Diseñar prototipo...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF182030) : const Color(0xFFF8FAFC),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un título para la tarea';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // CAMPO DESCRIPCIÓN
              TextFormField(
                controller: _descController,
                minLines: 2,
                maxLines: 4,
                style: GoogleFonts.inter(fontSize: 13, color: textoPrincipal, height: 1.4),
                decoration: InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  hintText: 'Detalles o especificaciones...',
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF182030) : const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 14),

              // SELECTOR HORIZONTAL DE COLUMNA / ESTADO
              Text('Columna Destino:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _columnasDisponibles.map((col) {
                    final seleccionada = _columnaSeleccionada == col;
                    return GestureDetector(
                      onTap: () => setState(() => _columnaSeleccionada = col),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: seleccionada ? azulCielo : (isDark ? const Color(0xFF182030) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: seleccionada ? azulCielo : (isDark ? const Color(0xFF2D3748) : Colors.grey.shade300)),
                        ),
                        child: Text(
                          col,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: seleccionada ? Colors.white : textoPrincipal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // ASIGNAR INTEGRANTE(S)
              if (widget.tablero.esGrupal) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Asignar Integrantes:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal)),
                    Text(
                      _asignadosA.isEmpty
                          ? 'Sin asignar (0)'
                          : '${_asignadosA.length} persona${_asignadosA.length > 1 ? "s" : ""}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _asignadosA.isEmpty ? Colors.grey : azulCielo),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _cargandoMiembros
                    ? const LinearProgressIndicator()
                    : _miembrosEquipo.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text('No hay integrantes en este tablero.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _miembrosEquipo.map((miembro) {
                              final estaSeleccionado = _asignadosA.contains(miembro.id);
                              return FilterChip(
                                avatar: CircleAvatar(
                                  backgroundColor: estaSeleccionado ? Colors.white : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                                  child: Text(
                                    miembro.nombreCompleto.isNotEmpty ? miembro.nombreCompleto[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: estaSeleccionado ? azulCielo : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                    ),
                                  ),
                                ),
                                label: Text(
                                  miembro.nombreCompleto,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: estaSeleccionado ? FontWeight.bold : FontWeight.normal,
                                    color: estaSeleccionado ? Colors.white : textoPrincipal,
                                  ),
                                ),
                                selected: estaSeleccionado,
                                selectedColor: azulCielo,
                                checkmarkColor: Colors.white,
                                backgroundColor: isDark ? const Color(0xFF182030) : const Color(0xFFF8FAFC),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: estaSeleccionado ? azulCielo : (isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
                                  ),
                                ),
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) {
                                      _asignadosA.add(miembro.id);
                                    } else {
                                      _asignadosA.remove(miembro.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                const SizedBox(height: 14),
              ],

              // FECHA DE ENTREGA Y PRIORIDAD
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
                            ? 'Fecha Entrega'
                            : '${_fechaVencimiento!.day}/${_fechaVencimiento!.month}/${_fechaVencimiento!.year}',
                        style: TextStyle(color: textoPrincipal, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final fecha = await showDatePicker(
                          context: context,
                          initialDate: _fechaVencimiento ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                          locale: Localizations.localeOf(context),
                        );
                        if (fecha != null) {
                          setState(() => _fechaVencimiento = fecha);
                        }
                      },
                    ),
                  ),
                  if (_fechaVencimiento != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => setState(() => _fechaVencimiento = null),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // PRIORIDAD (BAJA, MEDIA, ALTA)
              Text('Prioridad:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _botonPrioridad(1, 'Baja', verdeBaja),
                  _botonPrioridad(2, 'Media', naranjaMedia),
                  _botonPrioridad(3, 'Alta', rojoAlta),
                ],
              ),
              const SizedBox(height: 14),

              // SECCIÓN ARCHIVOS ADJUNTOS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Archivos Adjuntos (${_adjuntosSeleccionados.length}):',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal),
                  ),
                  TextButton.icon(
                    onPressed: _mostrarMenuAdjuntarArchivo,
                    icon: const Icon(Icons.attach_file_rounded, size: 16, color: azulCielo),
                    label: const Text('Adjuntar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: azulCielo)),
                  ),
                ],
              ),
              if (_adjuntosSeleccionados.isNotEmpty)
                Column(
                  children: _adjuntosSeleccionados.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final adjunto = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF182030) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          _obtenerIconoTipoAdjunto(adjunto.tipo, adjunto.nombre),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              adjunto.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                            onPressed: () => setState(() => _adjuntosSeleccionados.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 18),

              // BOTÓN CREAR TAREA
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verdeTurquesa,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: _guardando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
                  label: Text(
                    _guardando ? 'Creando...' : 'Crear Tarea',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _guardando ? null : _guardarNuevaTarea,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarMenuAdjuntarArchivo() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Adjuntar Archivo (Máx. 10MB):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFEBF8FF), child: Icon(Icons.image_rounded, color: Color(0xFF52ABEB))),
                  title: const Text('Imagen'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarArchivo(FileType.image, 'imagen');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFFFF5F5), child: Icon(Icons.videocam_rounded, color: Colors.redAccent)),
                  title: const Text('Video'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarArchivo(FileType.video, 'video');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFF0FDF4), child: Icon(Icons.description_rounded, color: Color(0xFF63D0A1))),
                  title: const Text('Documento / PDF'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarArchivo(FileType.custom, 'documento', extensiones: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'pptx', 'ppt']);
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
            _adjuntosSeleccionados.add(adjunto);
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

  Widget _obtenerIconoTipoAdjunto(String tipo, [String? nombre]) {
    final nameLower = (nombre ?? '').toLowerCase();
    final tipoLower = tipo.toLowerCase();

    if (nameLower.endsWith('.pdf')) {
      return const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFD32F2F), size: 18);
    } else if (tipoLower == 'imagen' || ['.jpg', '.jpeg', '.png', '.webp'].any((ext) => nameLower.endsWith(ext))) {
      return const Icon(Icons.image_rounded, color: Color(0xFF52ABEB), size: 18);
    } else if (tipoLower == 'video' || ['.mp4', '.mov', '.avi'].any((ext) => nameLower.endsWith(ext))) {
      return const Icon(Icons.videocam_rounded, color: Colors.redAccent, size: 18);
    }
    return const Icon(Icons.description_rounded, color: Color(0xFF63D0A1), size: 18);
  }

  Widget _botonPrioridad(int valor, String texto, Color color) {
    final activo = _prioridadSeleccionada == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _prioridadSeleccionada = valor),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: activo ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
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

  void _guardarNuevaTarea() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _guardando = true);

      try {
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'usuario_anonimo';

        final tareasActuales = await _firestoreService.obtenerTareasDeTablero(widget.tablero.id);
        final tareasEnColumna = tareasActuales.where((t) {
          return t.estadoNombre == _columnaSeleccionada || t.estado.value == _columnaSeleccionada;
        }).length;

        if (tareasEnColumna >= 10) {
          if (mounted) {
            setState(() => _guardando = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Límite alcanzado: La columna "$_columnaSeleccionada" ya tiene el máximo de 10 tareas.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final tareaId = FirebaseFirestore.instance.collection('tareas').doc().id;

        List<AdjuntoTarea> adjuntosSubidos = [];
        final storageService = StorageService();
        for (final adj in _adjuntosSeleccionados) {
          if (adj.url.isNotEmpty && !adj.url.startsWith('http')) {
            final urlRemota = await storageService.subirAdjuntoTarea(
              filePath: adj.url,
              nombreArchivo: adj.nombre,
              tareaId: tareaId,
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

        final enumEstado = EstadoTareaExtension.fromString(_columnaSeleccionada);
        final nuevaTarea = Tarea(
          id: tareaId,
          titulo: _tituloController.text.trim(),
          descripcion: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          estado: enumEstado,
          estadoNombre: _columnaSeleccionada,
          orden: 0,
          tableroId: widget.tablero.id,
          asignadosA: _asignadosA,
          fechaCreacion: DateTime.now(),
          fechaVencimiento: _fechaVencimiento,
          prioridad: _prioridadSeleccionada,
          adjuntos: adjuntosSubidos,
          archivada: false,
          creadaPor: userId,
        );

        await _firestoreService.crearTareaConId(nuevaTarea);

        if (mounted) {
          Navigator.pop(context, nuevaTarea);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _guardando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al crear tarea: $e')),
          );
        }
      }
    }
  }
}

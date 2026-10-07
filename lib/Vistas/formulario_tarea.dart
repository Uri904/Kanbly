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
import 'pantalla_visualizador_adjunto.dart';

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

  // Variables de estado del formulario
  late List<String> _columnasDisponibles;
  late String _columnaSeleccionada;
  int _prioridadSeleccionada = 2; // 1 = Baja, 2 = Media, 3 = Alta
  DateTime? _fechaVencimiento;
  String? _asignadoA; // ID del integrante asignado
  List<Usuario> _miembrosEquipo = [];
  List<AdjuntoTarea> _adjuntosSeleccionados = [];
  bool _cargandoMiembros = false;
  bool _guardando = false;

  // Límite máximo de tamaño por archivo: 10 MB (10 * 1024 * 1024 bytes)
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
    const Color textoPrincipal = Color(0xFF1E293B);
    const Color azulCielo = Color(0xFF52ABEB);
    const Color verdeTurquesa = Color(0xFF63D0A1);
    const Color rojoAlta = Color(0xFFE53E3E);
    const Color naranjaMedia = Color(0xFFED8936);
    const Color verdeBaja = Color(0xFF38A169);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- TÍTULO DEL MODAL ---
              Text(
                'Nueva Tarea en:\n${widget.tablero.nombre}',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textoPrincipal,
                ),
              ),
              const SizedBox(height: 16),

              // --- CAMPO: TÍTULO DE LA TAREA ---
              TextFormField(
                controller: _tituloController,
                decoration: InputDecoration(
                  labelText: 'Título de la tarea *',
                  hintText: 'Ej. Diseñar prototipo en Figma...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un título para la tarea';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // --- CAMPO: DESCRIPCIÓN ---
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción detallada (Opcional)',
                  hintText: 'Especificaciones, requerimientos...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 14),

              // --- DROPDOWN: SELECCIÓN DE COLUMNA/ESTADO ---
              DropdownButtonFormField<String>(
                value: _columnaSeleccionada,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Columna / Estado inicial',
                  prefixIcon: const Icon(Icons.view_column_outlined, color: azulCielo),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: _columnasDisponibles.map((colNombre) {
                  return DropdownMenuItem<String>(
                    value: colNombre,
                    child: Text(
                      colNombre,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _columnaSeleccionada = val);
                },
              ),
              const SizedBox(height: 14),

              // --- ASIGNACIÓN DE INTEGRANTE EN TABLEROS DE EQUIPO ---
              if (widget.tablero.esGrupal) ...[
                if (_cargandoMiembros)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: LinearProgressIndicator(),
                  )
                else
                  DropdownButtonFormField<String?>(
                    value: _asignadoA,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Asignar a integrante del equipo',
                      prefixIcon: const Icon(Icons.person_add_outlined, color: azulCielo),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'Sin asignar',
                          style: TextStyle(color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ..._miembrosEquipo.map((miembro) {
                        final infoRole = widget.tablero.miembrosInfo[miembro.id]?.rolKanban ?? miembro.rol;
                        return DropdownMenuItem<String?>(
                          value: miembro.id,
                          child: Text(
                            '${miembro.nombreCompleto} ($infoRole)',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() => _asignadoA = val);
                    },
                  ),
                const SizedBox(height: 14),
              ],

              // --- BOTÓN: FECHA DE VENCIMIENTO ---
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Colors.grey.shade300),
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
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (fecha != null) {
                    setState(() => _fechaVencimiento = fecha);
                  }
                },
              ),
              const SizedBox(height: 16),

              // --- SECCIÓN: ARCHIVOS ADJUNTOS (MÁX. 10MB) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Archivos Adjuntos (Máx. 10MB):',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textoPrincipal),
                  ),
                  TextButton.icon(
                    onPressed: _mostrarMenuAdjuntarArchivo,
                    icon: const Icon(Icons.attach_file_rounded, size: 18, color: azulCielo),
                    label: const Text('Adjuntar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: azulCielo)),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // LISTA DE ADJUNTOS SELECCIONADOS
              if (_adjuntosSeleccionados.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: Colors.grey.shade400, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No hay archivos adjuntos aún.\nHaz clic en "Adjuntar" para subir imágenes, documentos o videos (máx. 10MB).',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: _adjuntosSeleccionados.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final adjunto = entry.value;
                    return GestureDetector(
                      onTap: () => PantallaVisualizadorAdjunto.abrir(context, adjunto),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            _obtenerIconoTipoAdjunto(adjunto.tipo),
                            const SizedBox(width: 10),
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
                                    '${adjunto.tipo.toUpperCase()} • ${adjunto.tamanoLegible} • Haz clic para ver',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                              tooltip: 'Quitar archivo',
                              onPressed: () {
                                setState(() {
                                  _adjuntosSeleccionados.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),

              // --- SELECTOR: PRIORIDAD (NIVEL DE IMPORTANCIA) ---
              Text(
                'Nivel de Importancia (Prioridad):',
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
              const SizedBox(height: 24),

              // --- BOTÓN GUARDAR ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verdeTurquesa,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _guardando ? null : _guardarNuevaTarea,
                  child: _guardando
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'Crear Tarea',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- SELECCIÓN Y VALIDACIÓN DE ARCHIVOS ADJUNTOS CON LÍMITE DE 10MB ---
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
                  'Seleccionar Tipo de Archivo (Máx. 10MB):',
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
                  subtitle: const Text('PDF, DOC, DOCX, TXT, XLS'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarArchivo(FileType.custom, 'documento', extensiones: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx']);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.folder_open_rounded, color: Colors.blueGrey)),
                  title: const Text('Cualquier Archivo'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarArchivo(FileType.any, 'documento');
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

          // Determinar tipo real
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

  // --- WIDGET AUXILIAR PARA BOTONES DE PRIORIDAD ---
  Widget _botonPrioridad(int valor, String texto, Color color) {
    final activo = _prioridadSeleccionada == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _prioridadSeleccionada = valor),
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

  // --- LÓGICA DE GUARDADO CON FIRESTORE SERVICE ---
  void _guardarNuevaTarea() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _guardando = true);

      try {
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'usuario_anonimo';

        // 1. Verificar el límite de 10 tareas por columna
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

        // 2. Instanciamos el modelo Tarea con los datos del formulario incluyendo los archivos adjuntos
        final enumEstado = EstadoTareaExtension.fromString(_columnaSeleccionada);
        final nuevaTarea = Tarea(
          id: FirebaseFirestore.instance.collection('tareas').doc().id,
          titulo: _tituloController.text.trim(),
          descripcion: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          estado: enumEstado,
          estadoNombre: _columnaSeleccionada,
          orden: 0,
          tableroId: widget.tablero.id,
          asignadoA: _asignadoA,
          fechaCreacion: DateTime.now(),
          fechaVencimiento: _fechaVencimiento,
          prioridad: _prioridadSeleccionada,
          adjuntos: _adjuntosSeleccionados,
          archivada: false,
          creadaPor: userId,
        );

        // 3. Subimos la tarea a Firestore
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

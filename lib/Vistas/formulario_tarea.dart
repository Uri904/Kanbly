import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- IMPORTS DE LOS MODELOS Y SERVICIOS DEL EQUIPO ---
import '../modelo/tarea.dart';
import '../modelo/tablero.dart';
import '../modelo/usuario.dart';
import '../servicios/firestore_service.dart';

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
  bool _cargandoMiembros = false;
  bool _guardando = false; // Para mostrar indicador de carga

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

    if (widget.tablero.esGrupal || widget.tablero.miembrosIds.isNotEmpty) {
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
              // --- ENCABEZADO DEL MODAL ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Nueva Tarea en:\n${widget.tablero.nombre}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textoPrincipal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- CAMPO: TÍTULO ---
              TextFormField(
                controller: _tituloController,
                decoration: InputDecoration(
                  labelText: 'Título de la tarea*',
                  hintText: 'Ej. Diseño de base de datos',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: azulCielo, width: 2),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'El título es requerido' : null,
              ),
              const SizedBox(height: 14),

              // --- CAMPO: DESCRIPCIÓN ---
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  hintText: 'Agrega detalles o instrucciones...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: azulCielo, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // --- SELECTOR: COLUMNA / ESTADO (PERSONALIZABLE) ---
              DropdownButtonFormField<String>(
                value: _columnaSeleccionada,
                decoration: InputDecoration(
                  labelText: 'Columna inicial',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _columnasDisponibles.map((colNombre) {
                  return DropdownMenuItem(
                    value: colNombre,
                    child: Text(colNombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _columnaSeleccionada = val);
                },
              ),
              const SizedBox(height: 14),

              // --- ASIGNACIÓN DE INTEGRANTE EN TABLEROS DE EQUIPO ---
              if (widget.tablero.esGrupal || widget.tablero.miembrosIds.isNotEmpty) ...[
                if (_cargandoMiembros)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: LinearProgressIndicator(),
                  )
                else
                  DropdownButtonFormField<String?>(
                    value: _asignadoA,
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
                        child: Text('Sin asignar', style: TextStyle(color: Colors.grey)),
                      ),
                      ..._miembrosEquipo.map((miembro) {
                        final infoRole = widget.tablero.miembrosInfo[miembro.id]?.rolKanban ?? miembro.rol;
                        return DropdownMenuItem<String?>(
                          value: miembro.id,
                          child: Text(
                            '${miembro.nombreCompleto} ($infoRole)',
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

        // 2. Instanciamos el modelo Tarea con los datos del formulario
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
            SnackBar(
              content: Text('Error al crear tarea: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- IMPORTS DE LOS MODELOS Y SERVICIOS DEL EQUIPO ---
import '../modelo/tarea.dart';
import '../modelo/tablero.dart';
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

  // Variables de estado del formulario
  late EstadoTarea _estadoSeleccionado;
  int _prioridadSeleccionada = 2; // 1 = Baja, 2 = Media, 3 = Alta
  DateTime? _fechaVencimiento;
  bool _guardando = false; // Para mostrar indicador de carga

  @override
  void initState() {
    super.initState();
    _estadoSeleccionado = widget.estadoInicial;
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Paleta de colores oficial de Kanbly
    const Color textoPrincipal = Color(0xFF1E293B);
    const Color azulCielo = Color(0xFF52ABEB);
    const Color verdeTurquesa = Color(0xFF63D0A1);
    const Color azulClaro = Color(0xFF37B5F4);
    const Color verdeAgua = Color(0xFF63B09C);

    return Padding(
      // Evita que el teclado virtual tape el formulario
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

              // --- SELECTOR: COLUMNA / ESTADO ---
              DropdownButtonFormField<EstadoTarea>(
                value: _estadoSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Columna inicial',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: EstadoTarea.values.map((estado) {
                  return DropdownMenuItem(
                    value: estado,
                    child: Text(estado.value), // Devuelve 'Pendiente', 'En progreso', etc.
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _estadoSeleccionado = val);
                },
              ),
              const SizedBox(height: 14),

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

              // --- SELECTOR: PRIORIDAD ---
              Text(
                'Prioridad:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textoPrincipal),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _botonPrioridad(1, 'Baja', verdeAgua),     // #63B09C
                  _botonPrioridad(2, 'Media', azulClaro),    // #37B5F4
                  _botonPrioridad(3, 'Alta', verdeTurquesa), // #63D0A1
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
        final firestoreService = FirestoreService();
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'usuario_anonimo';

        // 1. Instanciamos el modelo Tarea con los datos del formulario
        final nuevaTarea = Tarea(
          id: FirebaseFirestore.instance.collection('tareas').doc().id, // ID autogenerado
          titulo: _tituloController.text.trim(),
          descripcion: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          estado: _estadoSeleccionado,
          orden: 0,
          tableroId: widget.tablero.id,
          fechaCreacion: DateTime.now(),
          fechaVencimiento: _fechaVencimiento,
          prioridad: _prioridadSeleccionada,
          archivada: false,
          creadaPor: userId,
        );

        // 2. Subimos la tarea a la base de datos de Firebase
        await firestoreService.crearTareaConId(nuevaTarea);

        // 3. Cerramos el modal solo si el widget sigue activo en pantalla
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
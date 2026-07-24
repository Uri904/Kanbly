import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- IMPORTS DE LOS MODELOS Y SERVICIOS DEL EQUIPO ---
import '../modelo/tarea.dart';
import '../servicios/firestore_service.dart';
import '../utilerias/formato_util.dart';

class DetalleTareaWidget extends StatefulWidget {
  final Tarea tarea;

  const DetalleTareaWidget({super.key, required this.tarea});

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
  late EstadoTarea _estadoActual;
  late int _prioridadActual;
  DateTime? _fechaVencimiento;

  @override
  void initState() {
    super.initState();
    // Inicializamos con los datos actuales de la tarea que se abrió
    _tituloController = TextEditingController(text: widget.tarea.titulo);
    _descController = TextEditingController(text: widget.tarea.descripcion ?? '');
    _estadoActual = widget.tarea.estado;
    _prioridadActual = widget.tarea.prioridad;
    _fechaVencimiento = widget.tarea.fechaVencimiento;
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
    const Color azulClaro = Color(0xFF37B5F4);
    const Color verdeAgua = Color(0xFF63B09C);

    // Color dinámico según la prioridad de la tarea
    final colorPrioridad = FormatoUtil.obtenerColorPorPrioridad(_prioridadActual);

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
                  child: Text(
                    _obtenerTextoPrioridad(_prioridadActual),
                    style: TextStyle(
                      color: textoPrincipal,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Botones de acción superior (Editar, Eliminar, Cerrar)
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _modoEdicion ? Icons.edit_off_rounded : Icons.edit_rounded,
                        color: azulCielo,
                      ),
                      tooltip: _modoEdicion ? 'Cancelar edición' : 'Editar texto',
                      onPressed: () => setState(() => _modoEdicion = !_modoEdicion),
                    ),
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

            // --- CAMBIO RÁPIDO DE COLUMNA (ESTADO) ---
            Text(
              'Mover a columna:',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textoPrincipal),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<EstadoTarea>(
              value: _estadoActual,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: EstadoTarea.values.map((estado) {
                return DropdownMenuItem(
                  value: estado,
                  child: Text(estado.value, style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: _procesando ? null : _cambiarEstadoRapido,
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
              Text('Prioridad:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textoPrincipal)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _botonPrioridad(1, 'Baja', verdeAgua),
                  _botonPrioridad(2, 'Media', azulClaro),
                  _botonPrioridad(3, 'Alta', verdeTurquesa),
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

  // 1. Cambio rápido de columna desde el Dropdown
  void _cambiarEstadoRapido(EstadoTarea? nuevoEstado) async {
    if (nuevoEstado == null || nuevoEstado == _estadoActual) return;

    setState(() {
      _estadoActual = nuevoEstado;
      _procesando = true;
    });

    try {
      // Usamos el método oficial del equipo en FirestoreService
      await _firestoreService.actualizarEstadoTarea(widget.tarea.id, nuevoEstado.value);

      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tarea movida a: ${nuevoEstado.value}'), backgroundColor: const Color(0xFF52ABEB)),
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

  // 2. Guardar todos los cambios modificados en el formulario
  void _guardarCambiosCompletos() async {
    if (_tituloController.text.trim().isEmpty) return;

    setState(() => _procesando = true);

    try {
      // Creamos una copia actualizada de la tarea con los nuevos valores
      final tareaActualizada = widget.tarea.copyWith(
        titulo: _tituloController.text.trim(),
        descripcion: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        estado: _estadoActual,
        prioridad: _prioridadActual,
        fechaVencimiento: _fechaVencimiento,
      );

      // Usamos el método de actualizar tarea del servicio del equipo
      await _firestoreService.actualizarTarea(tareaActualizada);

      if (mounted) {
        Navigator.pop(context); // Cerramos el modal al terminar
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

  // 3. Alerta de confirmación para eliminar la tarea
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
              Navigator.pop(context); // Cierra el diálogo
              setState(() => _procesando = true);
              try {
                // Ejecutamos el método eliminarTarea (que archiva en Firestore)
                await _firestoreService.eliminarTarea(widget.tarea.id);
                if (mounted) {
                  Navigator.pop(context); // Cierra el modal de detalle
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tarea eliminada'), backgroundColor: Colors.redAccent),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _procesando = false);
                  ScaffoldMessenger.of(context).showSnackBar(
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

  String _obtenerTextoPrioridad(int prioridad) {
    switch (prioridad) {
      case 3: return 'Prioridad Alta';
      case 2: return 'Prioridad Media';
      case 1: return 'Prioridad Baja';
      default: return 'Prioridad Media';
    }
  }
}
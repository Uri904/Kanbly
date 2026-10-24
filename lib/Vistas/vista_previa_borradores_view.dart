import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controlador/asistente_ia_controller.dart';
import '../modelo/tablero.dart';
import '../modelo/tarea_borrador.dart';
import '../modelo/usuario.dart';

class VistaPreviaBorradoresView extends StatelessWidget {
  final Tablero tablero;
  final List<Usuario> miembrosEquipo;

  const VistaPreviaBorradoresView({
    super.key,
    required this.tablero,
    required this.miembrosEquipo,
  });

  void _seleccionarFecha(
      BuildContext context,
      TareaBorrador borrador,
      int index,
      AsistenteIaController controller,
      ) async {
    final now = DateTime.now();
    final initialDate = borrador.fechaLimite ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    final finalDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime?.hour ?? 12,
      pickedTime?.minute ?? 0,
    );

    controller.actualizarBorrador(
      index,
      borrador.copyWith(fechaLimite: finalDateTime),
    );
  }

  void _confirmarYGuardar(
      BuildContext context,
      AsistenteIaController controller,
      ) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final cantidadTareas = controller.borradores.length;

    final ok = await controller.guardarBorradoresEnFirestore(
      tableroId: tablero.id,
      creadorId: currentUid,
    );

    if (ok && context.mounted) {
      // Regresar al tablero Kanban y mostrar mensaje de éxito
      Navigator.of(context).popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  // Antes decía "$tablero.nombre" (sin llaves) y mostraba "Instance of 'Tablero'.nombre".
                  cantidadTareas == 1
                      ? '¡Se agregó 1 tarea al tablero "${tablero.nombre}"!'
                      : '¡Se agregaron $cantidadTareas tareas al tablero "${tablero.nombre}"!',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF63D0A1),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const Color azulCielo = Color(0xFF52ABEB);
    const Color verdeTurquesa = Color(0xFF63D0A1);

    final columnasDisponibles = tablero.columnas.isNotEmpty
        ? tablero.columnas
        : const ['Pendiente', 'En progreso', 'Completada'];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Vista Previa de Borradores'),
        elevation: 0,
      ),
      body: Consumer<AsistenteIaController>(
        builder: (context, controller, child) {
          final borradores = controller.borradores;

          if (borradores.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay tareas borradoras en la lista.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => controller
                        .agregarBorradorManual(columnasDisponibles.first),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar tarea manual'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulCielo,
                      foregroundColor: Colors.white,
                    ),
                  )
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: borradores.length + 1, // +1 para los botones al final
            itemBuilder: (context, index) {
              if (index == borradores.length) {
                // Botón al final de la lista para agregar manual
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: OutlinedButton.icon(
                    onPressed: () => controller
                        .agregarBorradorManual(columnasDisponibles.first),
                    icon: const Icon(Icons.add_rounded, color: azulCielo),
                    label: const Text(
                      'Agregar otra tarea manual',
                      style: TextStyle(
                        color: azulCielo,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: azulCielo),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              }

              final borrador = borradores[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabecera de la tarjeta con número y botón de eliminar
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: azulCielo.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Tarea ${index + 1}',
                              style: const TextStyle(
                                color: azulCielo,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Eliminar borrador',
                            onPressed: () => controller.eliminarBorrador(index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Título editable
                      TextFormField(
                        initialValue: borrador.titulo,
                        decoration: const InputDecoration(
                          labelText: 'Título de la tarea',
                          border: UnderlineInputBorder(),
                        ),
                        onChanged: (val) {
                          controller.actualizarBorrador(
                            index,
                            borrador.copyWith(titulo: val),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Descripción editable
                      TextFormField(
                        initialValue: borrador.descripcion ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Descripción (Opcional)',
                          border: UnderlineInputBorder(),
                        ),
                        maxLines: 2,
                        onChanged: (val) {
                          final textoLimpio = val.trim();
                          controller.actualizarBorrador(
                            index,
                            borrador.copyWith(
                              descripcion: textoLimpio.isNotEmpty ? textoLimpio : null,
                              limpiarDescripcion: textoLimpio.isEmpty,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Selector de Prioridad (Chips)
                      Row(
                        children: [
                          const Text(
                            'Prioridad:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildPrioridadChip(
                                label: 'Baja',
                                valor: 1,
                                seleccionado: borrador.prioridad == 1,
                                color: Colors.blue,
                                onTap: () => controller.actualizarBorrador(
                                  index,
                                  borrador.copyWith(prioridad: 1),
                                ),
                              ),
                              _buildPrioridadChip(
                                label: 'Media',
                                valor: 2,
                                seleccionado: borrador.prioridad == 2,
                                color: Colors.orange,
                                onTap: () => controller.actualizarBorrador(
                                  index,
                                  borrador.copyWith(prioridad: 2),
                                ),
                              ),
                              _buildPrioridadChip(
                                label: 'Alta',
                                valor: 3,
                                seleccionado: borrador.prioridad == 3,
                                color: Colors.red,
                                onTap: () => controller.actualizarBorrador(
                                  index,
                                  borrador.copyWith(prioridad: 3),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Columna y Asignado (Dropdowns)
                      Row(
                        children: [
                          // Dropdown de Columna
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true, // el texto se recorta con "…" en vez de desbordar
                              value:
                              columnasDisponibles.contains(borrador.columna)
                                  ? borrador.columna
                                  : columnasDisponibles.first,
                              decoration: const InputDecoration(
                                labelText: 'Columna',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                              ),
                              items: columnasDisponibles.map((col) {
                                return DropdownMenuItem<String>(
                                  value: col,
                                  child: Text(col, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  controller.actualizarBorrador(
                                    index,
                                    borrador.copyWith(columna: val),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Dropdown de Asignado
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              isExpanded: true, // nombres largos ya no desbordan la tarjeta
                              value: miembrosEquipo
                                  .any((m) => m.id == borrador.asignadoUid)
                                  ? borrador.asignadoUid
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Asignado a',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Sin asignar', style: TextStyle(fontSize: 13)),
                                ),
                                ...miembrosEquipo.map((m) {
                                  return DropdownMenuItem<String?>(
                                    value: m.id,
                                    child: Text(m.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                controller.actualizarBorrador(
                                  index,
                                  borrador.copyWith(
                                    asignadoUid: val,
                                    limpiarAsignado: val == null,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Selector de Fecha límite
                      InkWell(
                        onTap: () => _seleccionarFecha(
                          context,
                          borrador,
                          index,
                          controller,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: azulCielo,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  borrador.fechaLimite != null
                                      ? 'Fecha límite: ${DateFormat('dd/MM/yyyy HH:mm').format(borrador.fechaLimite!)}'
                                      : 'Agregar fecha límite (Opcional)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: borrador.fechaLimite != null
                                        ? theme.colorScheme.onSurface
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              if (borrador.fechaLimite != null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    controller.actualizarBorrador(
                                      index,
                                      borrador.copyWith(
                                        fechaLimite: null,
                                        limpiarFecha: true,
                                      ),
                                    );
                                  },
                                ),
                            ],
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
      ),
      bottomNavigationBar: Consumer<AsistenteIaController>(
        builder: (context, controller, child) {
          if (controller.borradores.isEmpty) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: controller.isLoading
                ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: verdeTurquesa),
                SizedBox(width: 12),
                Text(
                  'Guardando tareas en Firestore...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: verdeTurquesa,
                  ),
                ),
              ],
            )
                : ElevatedButton.icon(
              onPressed: () => _confirmarYGuardar(context, controller),
              icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
              label: Text(
                'Subir al tablero (${controller.borradores.length} ${controller.borradores.length == 1 ? 'tarea' : 'tareas'})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: verdeTurquesa,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrioridadChip({
    required String label,
    required int valor,
    required bool seleccionado,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: seleccionado ? Colors.white : color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: seleccionado,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
    );
  }
}
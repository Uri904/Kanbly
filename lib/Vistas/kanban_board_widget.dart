import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- IMPORTS DE LA ARQUITECTURA DEL EQUIPO ---
import 'encabezado.dart';
import 'menu_lateral.dart';
import 'formulario_tarea.dart';
import 'detalle_tarea_widget.dart';
import 'formulario_tablero.dart';
import '../modelo/tablero.dart';
import '../modelo/tarea.dart';
import '../servicios/firestore_service.dart';
import '../utilerias/formato_util.dart';

// ==========================================
// 1. PANTALLA PRINCIPAL: TABLERO KANBAN
// ==========================================

class KanbanBoardWidget extends StatefulWidget {
  final Tablero? tablero;

  const KanbanBoardWidget({super.key, this.tablero});

  @override
  State<KanbanBoardWidget> createState() => _KanbanBoardWidgetState();
}

class _KanbanBoardWidgetState extends State<KanbanBoardWidget> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirestoreService _firestoreService = FirestoreService();
  String _criterioOrden = 'fechaCreacion';


  @override
  Widget build(BuildContext context) {
    // Colores oficiales adaptados de la paleta institucional de Kanbly
    const Color fondoBlanco = Color(0xFFFCFDFD);
    const Color azulCielo = Color(0xFF52ABEB);
    const Color verdeTurquesa = Color(0xFF63D0A1);
    const Color textoPrincipal = Color(0xFF1E293B);

    // Datos dinámicos del tablero activo
    final nombreTablero = widget.tablero?.nombre ?? 'Tablero General';
    final bool esGrupal = widget.tablero?.esGrupal ?? false;
    final Color colorAcento = esGrupal ? azulCielo : verdeTurquesa;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: fondoBlanco,

        // 1. APPBAR OFICIAL DEL EQUIPO
        appBar: Encabezado(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),

        // 2. DRAWER LATERAL OFICIAL DEL EQUIPO
        drawer: const MenuLateral(),

        // 3. BOTÓN FLOTANTE (+) PARA CREAR TAREAS
        floatingActionButton: FloatingActionButton(
          onPressed: () => _abrirFormularioNuevaTarea(context),
          backgroundColor: colorAcento,
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),

        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // --- CABECERA DE LA VISTA DEL TABLERO ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Icon(
                    esGrupal ? Icons.groups_rounded : Icons.person_outline_rounded,
                    color: colorAcento,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nombreTablero,
                      style: const TextStyle(
                        color: textoPrincipal,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // --- BOTÓN DE EDICIÓN DEL TABLERO ---
                  if (widget.tablero != null)
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.grey, size: 24),
                      tooltip: 'Configuración del tablero',
                      onPressed: () => _abrirEdicionTablero(context),
                    ),
                  // --- BOTÓN PARA CAMBIAR ESTRATEGIA DE ORDENAMIENTO ---
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort_rounded, color: Color(0xFF1E293B), size: 26),
                    tooltip: 'Ordenar tareas por...',
                    onSelected: (nuevoCriterio) {
                      setState(() {
                        _criterioOrden = nuevoCriterio;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ordenando por: ${_obtenerTextoCriterio(nuevoCriterio)}'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: const Color(0xFF52ABEB),
                        ),
                      );
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'fechaCreacion',
                        child: Row(
                          children: [
                            Icon(Icons.access_time, size: 18, color: Colors.grey),
                            SizedBox(width: 8),
                            Text('Fecha de creación (Defecto)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'prioridad',
                        child: Row(
                          children: [
                            Icon(Icons.flag_outlined, size: 18, color: Color(0xFF63D0A1)),
                            SizedBox(width: 8),
                            Text('Mayor Prioridad primero'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'fechaVencimiento',
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF52ABEB)),
                            SizedBox(width: 8),
                            Text('Entrega más próxima'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- COLUMNAS KANBAN EN TIEMPO REAL CON FIRESTORE ---
            Expanded(
              child: StreamBuilder<List<Tarea>>(
                stream: _firestoreService.streamTareasDeTablero(widget.tablero?.id ?? ''),
                builder: (context, snapshot) {
                  // A. Estado de carga inicial
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: azulCielo));
                  }

                  // B. Manejo de errores
                  if (snapshot.hasError) {
                    return Center(child: Text('Error al cargar tareas: ${snapshot.error}'));
                  }

                  // C. Lista de tareas en vivo desde la nube
                  final todasLasTareas = snapshot.data ?? [];

                  // --- APLICACIÓN DEL PATRÓN STRATEGY EN MEMORIA ---
                  todasLasTareas.sort((a, b) {
                    switch (_criterioOrden) {
                      case 'prioridad':
                      // Orden descendente: Prioridad 3 (Alta) va antes que 1 (Baja)[cite: 6]
                        return b.prioridad.compareTo(a.prioridad);
                      case 'fechaVencimiento':
                      // Si no tienen fecha, las mandamos al final
                        if (a.fechaVencimiento == null) return 1;
                        if (b.fechaVencimiento == null) return -1;
                        return a.fechaVencimiento!.compareTo(b.fechaVencimiento!);
                      case 'fechaCreacion':
                      default:
                      // Orden descendente por creación (más recientes primero)[cite: 6]
                        return b.fechaCreacion.compareTo(a.fechaCreacion);
                    }
                  });

                  // D. Filtrado por columnas usando el Enum oficial de la clase Tarea
                  final pendientes = todasLasTareas.where((t) => t.estado == EstadoTarea.pendiente).toList();
                  final enProgreso = todasLasTareas.where((t) => t.estado == EstadoTarea.enProgreso).toList();
                  final completadas = todasLasTareas.where((t) => t.estado == EstadoTarea.completada).toList();
                  final bloqueadas = todasLasTareas.where((t) => t.estado == EstadoTarea.bloqueada).toList();

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- COLUMNA 1: POR HACER (PENDIENTE) ---
                        _construirColumna(
                          titulo: 'POR HACER',
                          tareas: pendientes,
                          colorHeader: const Color(0xFF1E293B),
                        ),
                        const SizedBox(width: 16),

                        // --- COLUMNA 2: EN PROGRESO ---
                        _construirColumna(
                          titulo: 'EN PROGRESO',
                          tareas: enProgreso,
                          colorHeader: const Color(0xFF63B09C),
                        ),
                        const SizedBox(width: 16),

                        // --- COLUMNA 3: COMPLETADA (HECHO) ---
                        _construirColumna(
                          titulo: 'COMPLETADA',
                          tareas: completadas,
                          colorHeader: const Color(0xFF63D0A1),
                        ),
                        const SizedBox(width: 16),

                        // --- COLUMNA 4: BLOQUEADA ---
                        _construirColumna(
                          titulo: 'BLOQUEADA',
                          tareas: bloqueadas,
                          colorHeader: const Color(0xFFE53E3E),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MÉTODOS AUXILIARES DE LA INTERFAZ ---

  // Constructor dinámico de columnas
  Widget _construirColumna({
    required String titulo,
    required List<Tarea> tareas,
    required Color colorHeader,
  }) {
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Encabezado con el conteo real dinámico
          ColumnHeaderWidget(
            count: '${tareas.length}',
            title: titulo,
            colorHeader: colorHeader,
          ),
          const SizedBox(height: 12),

          // Lista de tarjetas o mensaje de columna vacía
          if (tareas.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: Text(
                'Sin tareas en esta columna',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            )
          else
            ...tareas.map((tarea) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              // --- AQUÍ ENVUELVES CON GESTURE DETECTOR ---
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => DetalleTareaWidget(tarea: tarea),
                  );
                },
                child: TaskCardWidget(
                  title: tarea.titulo,
                  desc: tarea.descripcion ?? 'Sin descripción adicional',
                  date: _formatearFecha(tarea.fechaVencimiento),
                  labelColor: FormatoUtil.obtenerColorPorPrioridad(tarea.prioridad),
                  initials: 'TA',
                ),
              ),
            )),
        ],
      ),
    );
  }

  // Despliega el modal inferior para crear una nueva tarea
  void _abrirFormularioNuevaTarea(BuildContext context) {
    if (widget.tablero == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un tablero para agregar tareas')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FormularioTarea(tablero: widget.tablero!),
    );
  }

  // Despliega la interfaz del equipo para editar el tablero actual
  void _abrirEdicionTablero(BuildContext context) async {
    if (widget.tablero == null) return;

    // Navegamos al formulario pasándole las propiedades del tablero activo[cite: 2]
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormularioTablero(
          esGrupal: widget.tablero!.esGrupal, // Le decimos si es equipo o individual[cite: 2]
          tablero: widget.tablero,            // Le pasamos el objeto para que entre en modo edición[cite: 2]
        ),
      ),
    );

    // Al regresar de editar, actualizamos la pantalla por si cambió el nombre
    if (mounted) {
      setState(() {});
    }
  }

  // Formateador visual rápido para la fecha
  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    return '${fecha.day}/${fecha.month}';
  }
}



// ==========================================
// 2. COMPONENTE: ENCABEZADO DE COLUMNA
// ==========================================

class ColumnHeaderWidget extends StatelessWidget {
  final String title;
  final String count;
  final Color colorHeader;

  const ColumnHeaderWidget({
    super.key,
    required this.title,
    required this.count,
    required this.colorHeader,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorHeader,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. COMPONENTE: TARJETA DE TAREA
// ==========================================

class TaskCardWidget extends StatelessWidget {
  final String date;
  final String desc;
  final String initials;
  final Color labelColor;
  final String title;

  const TaskCardWidget({
    super.key,
    required this.date,
    required this.desc,
    required this.initials,
    required this.labelColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row superior: Prioridad y Menú
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 6,
                decoration: BoxDecoration(
                  color: labelColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Icon(Icons.more_horiz_rounded, color: Colors.grey, size: 18),
            ],
          ),
          const SizedBox(height: 10),

          // Título y Descripción
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11, height: 1.3),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          const SizedBox(height: 10),

          // Row inferior: Fecha y Avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time_rounded, color: Colors.grey.shade500, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    date,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF1E293B),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _obtenerTextoCriterio(String criterio) {
  switch (criterio) {
    case 'prioridad': return 'Prioridad';
    case 'fechaVencimiento': return 'Fecha de entrega';
    default: return 'Fecha de creación';
  }
}
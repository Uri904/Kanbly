import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
import 'calendario_tablero.dart';

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

    // Obtener permisos del usuario activo
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final permisos = widget.tablero?.obtenerPermisosDeUsuario(currentUid) ?? PermisosMiembro.todos;

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
          onPressed: () {
            if (!permisos.crearTareas) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No tienes permiso para crear tareas en este tablero')),
              );
              return;
            }
            _abrirFormularioNuevaTarea(context);
          },
          backgroundColor: permisos.crearTareas ? colorAcento : Colors.grey,
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
                  if (widget.tablero != null && (permisos.editarTablero || permisos.administrarMiembros))
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.grey, size: 24),
                      tooltip: 'Configuración del tablero',
                      onPressed: () => _abrirEdicionTablero(context),
                    ),
                  // --- BOTÓN DE MENÚ DE MÓDULOS (Calendario, Notas, Recordatorios) ---
                  if (widget.tablero != null)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.apps_rounded, color: colorAcento, size: 26),
                      tooltip: 'Módulos del tablero',
                      onSelected: (modulo) {
                        _abrirModulo(context, modulo);
                      },
                      itemBuilder: (context) => [
                        if (widget.tablero!.tieneCalendario)
                          const PopupMenuItem(
                            value: 'calendario',
                            child: Row(
                              children: [
                                Icon(Icons.calendar_month, color: Colors.blue),
                                SizedBox(width: 10),
                                Text('Calendario'),
                              ],
                            ),
                          ),
                        if (widget.tablero!.tieneNotas)
                          const PopupMenuItem(
                            value: 'notas',
                            child: Row(
                              children: [
                                Icon(Icons.note_alt_outlined, color: Colors.orange),
                                SizedBox(width: 10),
                                Text('Notas para tareas'),
                              ],
                            ),
                          ),
                        if (widget.tablero!.tieneRecordatorios)
                          const PopupMenuItem(
                            value: 'recordatorios',
                            child: Row(
                              children: [
                                Icon(Icons.notifications_active_outlined, color: Colors.red),
                                SizedBox(width: 10),
                                Text('Recordatorios'),
                              ],
                            ),
                          ),
                      ],
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

                  // D. Filtrado por columnas usando las columnas personalizadas del tablero
                  final columnasList = widget.tablero?.columnas.isNotEmpty == true
                      ? widget.tablero!.columnas
                      : const ['Pendiente', 'En progreso', 'Completada'];

                  const List<Color> paletaColoresHeaders = [
                    Color(0xFF1E293B), // Oscuro / Por Hacer
                    Color(0xFF52ABEB), // Azul / En Progreso
                    Color(0xFF63D0A1), // Verde Turquesa / Completada
                    Color(0xFFE53E3E), // Rojo / Bloqueada
                    Color(0xFF8B5CF6), // Morado
                    Color(0xFFF59E0B), // Naranja / Ámbar
                    Color(0xFF10B981), // Esmeralda
                  ];

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: columnasList.asMap().entries.map((entry) {
                        final index = entry.key;
                        final colNombre = entry.value;
                        final tareasColumna = todasLasTareas.where((t) {
                          return t.estadoNombre == colNombre || t.estado.value == colNombre;
                        }).toList();
                        final colorHeader = paletaColoresHeaders[index % paletaColoresHeaders.length];

                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _construirColumna(
                            titulo: colNombre.toUpperCase(),
                            estadoNombre: colNombre,
                            tareas: tareasColumna,
                            colorHeader: colorHeader,
                          ),
                        );
                      }).toList(),
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
    required String estadoNombre,
    required List<Tarea> tareas,
    required Color colorHeader,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final permisos = widget.tablero?.obtenerPermisosDeUsuario(uid) ?? PermisosMiembro.todos;

    return DragTarget<Tarea>(
      onAcceptWithDetails: (details) async {
        if (!permisos.moverTareas) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No tienes permiso para mover tareas en este tablero'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
        final tarea = details.data;
        if (tarea.estadoNombre != estadoNombre && tarea.estado.value != estadoNombre) {
          if (tareas.length >= 10) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Límite alcanzado: La columna "$titulo" ya tiene el máximo de 10 tareas.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
          try {
            await _firestoreService.actualizarEstadoTarea(tarea.id, estadoNombre);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tarea "${tarea.titulo}" movida a $titulo'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: colorHeader,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error al mover tarea: $e')),
              );
            }
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          width: 280,
          constraints: const BoxConstraints(minHeight: 450),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isHovered
                ? colorHeader.withValues(alpha: 0.12)
                : Colors.grey.shade100.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered ? colorHeader : Colors.grey.shade200,
              width: isHovered ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encabezado con el conteo (límite de 10)
              ColumnHeaderWidget(
                count: '${tareas.length}/10',
                title: titulo,
                colorHeader: colorHeader,
              ),
              const SizedBox(height: 12),

              // Contenedor scrollable exclusivo de la columna
              SizedBox(
                height: 500,
                child: tareas.isEmpty
                    ? Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isHovered ? colorHeader : Colors.grey.shade300,
                            style: BorderStyle.none,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isHovered ? 'Soltar aquí' : 'Sin tareas en esta columna',
                          style: TextStyle(
                            color: isHovered ? colorHeader : Colors.grey.shade400,
                            fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: tareas.map((tarea) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LongPressDraggable<Tarea>(
                              data: tarea,
                              maxSimultaneousDrags: permisos.moverTareas ? 1 : 0,
                              delay: const Duration(milliseconds: 150),
                              hapticFeedbackOnStart: true,
                              axis: null,
                              feedback: Material(
                                type: MaterialType.transparency,
                                child: Transform.scale(
                                  scale: 1.03,
                                  child: SizedBox(
                                    width: 280,
                                    child: TaskCardWidget(
                                      title: tarea.titulo,
                                      desc: tarea.descripcion ?? '',
                                      date: _formatearFecha(tarea.fechaVencimiento),
                                      labelColor: FormatoUtil.obtenerColorPorPrioridad(tarea.prioridad),
                                      prioridad: tarea.prioridad,
                                      asignadoA: tarea.asignadoA,
                                      tablero: widget.tablero,
                                    ),
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: TaskCardWidget(
                                  title: tarea.titulo,
                                  desc: tarea.descripcion ?? '',
                                  date: _formatearFecha(tarea.fechaVencimiento),
                                  labelColor: FormatoUtil.obtenerColorPorPrioridad(tarea.prioridad),
                                  prioridad: tarea.prioridad,
                                  asignadoA: tarea.asignadoA,
                                  tablero: widget.tablero,
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.white,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                    ),
                                    builder: (context) => DetalleTareaWidget(
                                      tarea: tarea,
                                      tablero: widget.tablero,
                                    ),
                                  );
                                },
                                child: TaskCardWidget(
                                  title: tarea.titulo,
                                  desc: tarea.descripcion ?? 'Sin descripción adicional',
                                  date: _formatearFecha(tarea.fechaVencimiento),
                                  labelColor: FormatoUtil.obtenerColorPorPrioridad(tarea.prioridad),
                                  prioridad: tarea.prioridad,
                                  asignadoA: tarea.asignadoA,
                                  tablero: widget.tablero,
                                ),
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
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

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final permisos = widget.tablero!.obtenerPermisosDeUsuario(uid);

    if (!permisos.editarTablero && !permisos.administrarMiembros) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permiso para editar la configuración de este tablero'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Navegamos al formulario pasándole las propiedades del tablero activo
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormularioTablero(
          esGrupal: widget.tablero!.esGrupal,
          tablero: widget.tablero,
        ),
      ),
    );

    // Al regresar de editar, actualizamos la pantalla por si cambió el nombre
    if (mounted) {
      setState(() {});
    }
  }

  // Despliega una hermosa vista modal ficticia o funcional para los módulos adicionales
  void _abrirModulo(BuildContext context, String tipoModulo) {
    if (widget.tablero != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final permisos = widget.tablero!.obtenerPermisosDeUsuario(uid);
      if (!permisos.gestionarModulos) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes permiso para acceder a los módulos de este tablero'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    // Si seleccionó Calendario
    if (tipoModulo == 'calendario') {
      if (widget.tablero == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CalendarioTablero(
            tableroId: widget.tablero!.id,
          ),
        ),
      );

      return;
    }

    String titulo = '';
    IconData icono = Icons.help;
    Color color = Colors.blue;
    String descripcion = '';

    if (tipoModulo == 'calendario') {
      titulo = 'Calendario de Kanban';
      icono = Icons.calendar_month;
      color = Colors.blue;
      descripcion = 'Aquí puedes agendar los entregables y visualizar tus tareas ordenadas por su fecha de vencimiento.';
    } else if (tipoModulo == 'notas') {
      titulo = 'Notas y Comentarios';
      icono = Icons.note_alt_outlined;
      color = Colors.orange;
      descripcion = 'Añade notas rápidas adhesivas, anotaciones del equipo y retroalimentación para complementar tus tableros.';
    } else if (tipoModulo == 'recordatorios') {
      titulo = 'Alertas y Recordatorios';
      icono = Icons.notifications_active_outlined;
      color = Colors.red;
      descripcion = 'Configura alarmas automáticas y recibe notificaciones antes de que expiren los plazos de tus tareas.';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 30,
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icono, color: color, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                descripcion,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
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
              color: Colors.white.withValues(alpha: 0.2),
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
  final int prioridad;
  final String? asignadoA;
  final Tablero? tablero;
  final Color labelColor;
  final String title;

  const TaskCardWidget({
    super.key,
    required this.date,
    required this.desc,
    this.initials = 'TA',
    this.prioridad = 2,
    this.asignadoA,
    this.tablero,
    required this.labelColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    String inicialesMostrar = initials;
    if (asignadoA != null && tablero != null && tablero!.miembrosInfo.containsKey(asignadoA)) {
      final info = tablero!.miembrosInfo[asignadoA];
      if (info != null && info.rolKanban.isNotEmpty) {
        final partes = info.rolKanban.split(' ');
        inicialesMostrar = partes.length >= 2
            ? '${partes[0][0]}${partes[1][0]}'.toUpperCase()
            : info.rolKanban.substring(0, 2).toUpperCase();
      }
    }

    final textoPrioridad = FormatoUtil.obtenerTextoPrioridad(prioridad);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: labelColor, width: 4.5),
          top: BorderSide(color: Colors.grey.shade200, width: 1.2),
          right: BorderSide(color: Colors.grey.shade200, width: 1.2),
          bottom: BorderSide(color: Colors.grey.shade200, width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: labelColor.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row superior: Chip de Prioridad (Color según importancia) e Ícono de arrastre
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: labelColor.withValues(alpha: 0.5), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_rounded, size: 11, color: labelColor),
                    const SizedBox(width: 4),
                    Text(
                      'Prioridad $textoPrioridad',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 18),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

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
          const SizedBox(height: 10),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          const SizedBox(height: 8),

          // Row inferior: Fecha y Asignado (Avatar)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time_rounded, color: Colors.grey.shade500, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    date,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
              if (tablero?.esGrupal == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: asignadoA != null ? const Color(0xFF52ABEB).withValues(alpha: 0.12) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: asignadoA != null ? const Color(0xFF52ABEB) : Colors.grey.shade400,
                        child: Text(
                          inicialesMostrar,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        asignadoA != null ? 'Asignado' : 'Sin asignar',
                        style: TextStyle(
                          color: asignadoA != null ? const Color(0xFF52ABEB) : Colors.grey.shade600,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                CircleAvatar(
                  radius: 11,
                  backgroundColor: const Color(0xFF1E293B),
                  child: Text(
                    inicialesMostrar,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
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
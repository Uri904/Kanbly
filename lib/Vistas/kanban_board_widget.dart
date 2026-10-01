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

    return StreamBuilder<Tablero?>(
      stream: widget.tablero != null
          ? _firestoreService.streamTablero(widget.tablero!.id)
          : Stream.value(widget.tablero),
      builder: (context, boardSnapshot) {
        final tableroActivo = boardSnapshot.data ?? widget.tablero;

        // Datos dinámicos del tablero activo en tiempo real
        final nombreTablero = tableroActivo?.nombre ?? 'Tablero General';
        final bool esGrupal = tableroActivo?.esGrupal ?? false;
        final Color colorAcento = esGrupal ? azulCielo : verdeTurquesa;

        // Obtener permisos del usuario activo
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final permisos = tableroActivo?.obtenerPermisosDeUsuario(currentUid) ?? PermisosMiembro.todos;

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
                _abrirFormularioNuevaTarea(context, tableroActivo);
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
                      // --- BOTÓN DE EDICIÓN Y PERSONALIZACIÓN DEL TABLERO ---
                      if (tableroActivo != null && (permisos.editarTablero || permisos.administrarMiembros))
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Colors.grey, size: 24),
                          tooltip: 'Configuración y Personalización del tablero',
                          onPressed: () => _abrirEdicionTablero(context, tableroActivo),
                        ),
                      // --- BOTÓN DE MENÚ DE MÓDULOS (Calendario, Notas, Recordatorios) ---
                      if (tableroActivo != null)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.apps_rounded, color: colorAcento, size: 26),
                          tooltip: 'Módulos del tablero',
                          onSelected: (modulo) {
                            _abrirModulo(context, modulo, tableroActivo);
                          },
                          itemBuilder: (context) => [
                            if (tableroActivo.tieneCalendario)
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
                            if (tableroActivo.tieneNotas)
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
                            if (tableroActivo.tieneRecordatorios)
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
                    stream: _firestoreService.streamTareasDeTablero(tableroActivo?.id ?? ''),
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
                            return b.prioridad.compareTo(a.prioridad);
                          case 'fechaVencimiento':
                            if (a.fechaVencimiento == null) return 1;
                            if (b.fechaVencimiento == null) return -1;
                            return a.fechaVencimiento!.compareTo(b.fechaVencimiento!);
                          case 'fechaCreacion':
                          default:
                            return b.fechaCreacion.compareTo(a.fechaCreacion);
                        }
                      });

                      // D. Filtrado por columnas usando las columnas personalizadas del tablero
                      final columnasList = tableroActivo?.columnas.isNotEmpty == true
                          ? tableroActivo!.columnas
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

                            // BÚSQUEDA ROBUSTA Y GARANTÍA CERO PÉRDIDA DE TAREAS
                            final tareasColumna = todasLasTareas.where((t) {
                              return _correspondeAColumna(t, colNombre, columnasList, index);
                            }).toList();

                            final colorHeader = paletaColoresHeaders[index % paletaColoresHeaders.length];

                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: _construirColumna(
                                titulo: colNombre.toUpperCase(),
                                estadoNombre: colNombre,
                                tareas: tareasColumna,
                                colorHeader: colorHeader,
                                tablero: tableroActivo,
                                permisos: permisos,
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
      },
    );
  }

  // --- COMPROBACIÓN FLEXIBLE DE PERTENENCIA DE TAREA A COLUMNA ---
  bool _correspondeAColumna(
    Tarea tarea,
    String colNombre,
    List<String> todasLasColumnas,
    int colIndex,
  ) {
    final colClean = colNombre.trim().toLowerCase();
    final estadoNombreClean = tarea.estadoNombre.trim().toLowerCase();
    final estadoValueClean = tarea.estado.value.trim().toLowerCase();

    // 1. Coincidencia directa ignorando mayúsculas/minúsculas y espacios
    if (estadoNombreClean == colClean || estadoValueClean == colClean) {
      return true;
    }

    // 2. Mapeo de sinónimos habituales
    final esPorHacer = (colClean == 'pendiente' || colClean == 'por hacer');
    final tareaEsPorHacer = (estadoNombreClean == 'pendiente' || estadoNombreClean == 'por hacer');
    if (esPorHacer && tareaEsPorHacer) return true;

    final esEnProgreso = (colClean == 'en progreso' || colClean == 'en proceso' || colClean == 'haciendo');
    final tareaEsEnProgreso = (estadoNombreClean == 'en progreso' || estadoNombreClean == 'en proceso' || estadoNombreClean == 'haciendo');
    if (esEnProgreso && tareaEsEnProgreso) return true;

    final esCompletada = (colClean == 'completada' || colClean == 'completado' || colClean == 'terminada' || colClean == 'hecho');
    final tareaEsCompletada = (estadoNombreClean == 'completada' || estadoNombreClean == 'completado' || estadoNombreClean == 'terminada' || estadoNombreClean == 'hecho');
    if (esCompletada && tareaEsCompletada) return true;

    // 3. Garantía Cero Pérdidas: si no coincide con NINGUNA columna existente en el tablero, la colocamos en la primera columna
    bool coincideConAlgunaOtra = false;
    for (final otraCol in todasLasColumnas) {
      final otraClean = otraCol.trim().toLowerCase();
      if (estadoNombreClean == otraClean || estadoValueClean == otraClean) {
        coincideConAlgunaOtra = true;
        break;
      }
      if ((otraClean == 'pendiente' || otraClean == 'por hacer') && tareaEsPorHacer) {
        coincideConAlgunaOtra = true;
        break;
      }
      if ((otraClean == 'en progreso' || otraClean == 'en proceso' || otraClean == 'haciendo') && tareaEsEnProgreso) {
        coincideConAlgunaOtra = true;
        break;
      }
      if ((otraClean == 'completada' || otraClean == 'completado' || otraClean == 'terminada' || otraClean == 'hecho') && tareaEsCompletada) {
        coincideConAlgunaOtra = true;
        break;
      }
    }

    if (!coincideConAlgunaOtra && colIndex == 0) {
      return true;
    }

    return false;
  }

  // --- MÉTODOS AUXILIARES DE LA INTERFAZ ---

  // Constructor dinámico de columnas
  Widget _construirColumna({
    required String titulo,
    required String estadoNombre,
    required List<Tarea> tareas,
    required Color colorHeader,
    required Tablero? tablero,
    required PermisosMiembro permisos,
  }) {
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
                ? colorHeader.withOpacity(0.12)
                : Colors.grey.shade100.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered ? colorHeader : Colors.grey.shade200,
              width: isHovered ? 2.0 : 1.0,
            ),
          ),
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
                  height: 100,
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
              else
                ...tareas.map((tarea) => Padding(
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
                            tarea: tarea,
                            tablero: tablero,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: TaskCardWidget(
                        tarea: tarea,
                        tablero: tablero,
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
                            tablero: tablero,
                          ),
                        );
                      },
                      child: TaskCardWidget(
                        tarea: tarea,
                        tablero: tablero,
                      ),
                    ),
                  ),
                )),
            ],
          ),
        );
      },
    );
  }

  // Modales y llamadas de interfaz
  void _abrirFormularioNuevaTarea(BuildContext context, Tablero? tableroActivo) {
    if (tableroActivo == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FormularioTarea(tablero: tableroActivo),
    );
  }

  // Despliega la interfaz del equipo para editar el tablero actual
  void _abrirEdicionTablero(BuildContext context, Tablero? tableroActivo) async {
    if (tableroActivo == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final permisos = tableroActivo.obtenerPermisosDeUsuario(uid);

    if (!permisos.editarTablero && !permisos.administrarMiembros) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permiso para editar la configuración de este tablero'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormularioTablero(
          esGrupal: tableroActivo.esGrupal,
          tablero: tableroActivo,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  void _abrirModulo(BuildContext context, String tipoModulo, Tablero? tableroActivo) {
    if (tableroActivo != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final permisos = tableroActivo.obtenerPermisosDeUsuario(uid);
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

    if (tipoModulo == 'calendario') {
      if (tableroActivo == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CalendarioTablero(
            tableroId: tableroActivo.id,
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
      descripcion = 'Gestiona tus entregables y fechas límite activas.';
    } else if (tipoModulo == 'notas') {
      titulo = 'Notas para Tareas';
      icono = Icons.note_alt_outlined;
      color = Colors.orange;
      descripcion = 'Añade documentación adicional a las tareas de tu equipo.';
    } else if (tipoModulo == 'recordatorios') {
      titulo = 'Recordatorios y Alertas';
      icono = Icons.notifications_active_outlined;
      color = Colors.red;
      descripcion = 'Recibe notificaciones sobre tareas pendientes de vencer.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icono, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(titulo)),
          ],
        ),
        content: Text(descripcion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  String _obtenerTextoCriterio(String criterio) {
    switch (criterio) {
      case 'prioridad':
        return 'Mayor Prioridad primero';
      case 'fechaVencimiento':
        return 'Entrega más próxima';
      case 'fechaCreacion':
      default:
        return 'Fecha de creación';
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorHeader.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorHeader.withOpacity(0.3), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorHeader,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: colorHeader,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorHeader,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. COMPONENTE RECONSTRUIDO: TARJETA DE TAREA
// ==========================================

class TaskCardWidget extends StatelessWidget {
  final Tarea tarea;
  final Tablero? tablero;

  const TaskCardWidget({
    super.key,
    required this.tarea,
    this.tablero,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Título y descripción con fallbacks seguros
    final String tituloDisplay = tarea.titulo.trim().isNotEmpty
        ? tarea.titulo.trim()
        : 'Tarea sin título';

    final String descDisplay = (tarea.descripcion != null && tarea.descripcion!.trim().isNotEmpty)
        ? tarea.descripcion!.trim()
        : 'Sin descripción adicional';

    // 2. Prioridad y color
    final int prioridadNum = tarea.prioridad;
    final Color colorPrioridad = FormatoUtil.obtenerColorPorPrioridad(prioridadNum);
    final String textoPrioridad = FormatoUtil.obtenerTextoPrioridad(prioridadNum);

    // 3. Fecha de entrega
    final String fechaDisplay = FormatoUtil.formatearFechaCorta(tarea.fechaVencimiento);

    // 4. Iniciales de asignación para tableros grupales
    String inicialesAsignado = 'TA';
    String nombreAsignado = 'Sin asignar';
    bool tieneAsignado = false;

    if (tarea.asignadoA != null && tablero != null && tablero!.miembrosInfo.containsKey(tarea.asignadoA)) {
      final info = tablero!.miembrosInfo[tarea.asignadoA];
      if (info != null && info.rolKanban.trim().isNotEmpty) {
        tieneAsignado = true;
        nombreAsignado = info.rolKanban;
        final partes = info.rolKanban.trim().split(' ').where((p) => p.isNotEmpty).toList();
        if (partes.length >= 2) {
          inicialesAsignado = '${partes[0][0]}${partes[1][0]}'.toUpperCase();
        } else if (info.rolKanban.trim().length >= 2) {
          inicialesAsignado = info.rolKanban.trim().substring(0, 2).toUpperCase();
        } else {
          inicialesAsignado = info.rolKanban.trim().substring(0, 1).toUpperCase();
        }
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indicador lateral de prioridad
              Container(
                width: 6,
                color: colorPrioridad,
              ),
              // Contenido de la tarjeta
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // FILA 1: Chip de Prioridad E Ícono
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorPrioridad.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colorPrioridad.withOpacity(0.4), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flag_rounded, size: 12, color: colorPrioridad),
                                const SizedBox(width: 4),
                                Text(
                                  'Prioridad $textoPrioridad',
                                  style: TextStyle(
                                    color: colorPrioridad,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 18),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // FILA 2: Título de la tarea
                      Text(
                        tituloDisplay,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // FILA 3: Descripción de la tarea
                      Text(
                        descDisplay,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 8),

                      // FILA 4: Fecha E Integrante Asignado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded, color: Colors.grey.shade500, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                fechaDisplay,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (tablero?.esGrupal == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: tieneAsignado ? const Color(0xFF52ABEB).withOpacity(0.12) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 9,
                                    backgroundColor: tieneAsignado ? const Color(0xFF52ABEB) : Colors.grey.shade400,
                                    child: Text(
                                      inicialesAsignado,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tieneAsignado ? nombreAsignado : 'Sin asignar',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: tieneAsignado ? const Color(0xFF52ABEB) : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

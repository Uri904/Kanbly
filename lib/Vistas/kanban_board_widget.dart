import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- IMPORTS DE LA ARQUITECTURA DEL EQUIPO ---
import 'package:provider/provider.dart';
import '../controlador/asistente_ia_controller.dart';
import '../controlador/asistente_ia_chat_controller.dart';
import 'asistente_ia_chat_view.dart';
import '../modelo/usuario.dart';
import 'captura_voz_view.dart';
import 'encabezado.dart';
import 'menu_lateral.dart';
import 'formulario_tarea.dart';
import 'detalle_tarea_widget.dart';
import 'formulario_tablero.dart';
import 'pantalla_borradores_personales.dart';
import '../modelo/tablero.dart';
import '../modelo/tarea.dart';
import '../servicios/firestore_service.dart';
import '../utilerias/formato_util.dart';
import '../utilerias/kanban_utils.dart';
import 'calendario_tablero.dart';
import 'recordatorios.dart';
import '../utilerias/mensajes_error.dart';
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
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    // RESPONSIVO: en horizontal se reducen los espacios verticales del
    // encabezado para que las columnas tengan altura útil.
    final bool horizontal =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final double ancho = MediaQuery.sizeOf(context).width;

    // Colores oficiales adaptados de la paleta institucional de Kanbly
    const Color azulCielo = Color(0xFF52ABEB);
    const Color verdeTurquesa = Color(0xFF63D0A1);

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
            backgroundColor: theme.scaffoldBackgroundColor,

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
                SizedBox(height: horizontal ? 4 : 16),

                // --- CABECERA DE LA VISTA DEL TABLERO ---
                Padding(
                  // En teléfonos de 320 dp los 5 botones de la cabecera no cabían
                  // con 24 dp de margen y desbordaban la fila.
                  padding: EdgeInsets.symmetric(horizontal: ancho < 360 ? 12.0 : 24.0),
                  child: Builder(builder: (context) {
                    // Icono y nombre del tablero (se reutilizan en ambos diseños).
                    final Widget iconoTablero = Icon(
                      esGrupal ? Icons.groups_rounded : Icons.person_outline_rounded,
                      color: colorAcento,
                      size: 28,
                    );
                    final Widget textoNombre = Text(
                      nombreTablero,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    );

                    // Botones de acción del tablero (misma lógica y permisos de siempre).
                    final List<Widget> acciones = [
                      // --- BOTÓN ASISTENTE IA POR VOZ ---
                      if (tableroActivo != null && permisos.crearTareas)
                        IconButton(
                          icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF63D0A1), size: 26),
                          tooltip: 'Asistente IA por Voz',
                          onPressed: () => _abrirAsistenteIa(context, tableroActivo),
                        ),
                      // --- BOTÓN CHATBOT IA DE CONSULTA (SOLO LECTURA) ---
                      if (tableroActivo != null && (tableroActivo.creadorId == currentUid || tableroActivo.miembrosIds.contains(currentUid)))
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF63D0A1), size: 24),
                          tooltip: 'Chatbot IA (Consulta de Tablero)',
                          onPressed: () => _abrirChatbotIa(context, tableroActivo),
                        ),
                      // --- BOTÓN DE EDICIÓN Y PERSONALIZACIÓN DEL TABLERO (SOLO DUEÑO O ADMIN) ---
                      if (tableroActivo != null && tableroActivo.esAdminOCreador(currentUid))
                        IconButton(
                          icon: Icon(Icons.settings_outlined, color: isDark ? Colors.grey.shade400 : Colors.grey, size: 24),
                          tooltip: 'Ajustes y Configuración del tablero',
                          onPressed: () => _abrirEdicionTablero(context, tableroActivo),
                        ),
                      // --- BOTÓN DE MENÚ DE MÓDULOS (SEGÚN PERMISOS) ---
                      if (tableroActivo != null && permisos.gestionarModulos)
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
                                    Text('Notas y Borradores'),
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
                        icon: Icon(Icons.sort_rounded, color: theme.colorScheme.onSurface, size: 26),
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
                    ];

                    // RESPONSIVO (vertical en teléfono): con hasta 5 botones al lado
                    // el nombre quedaba reducido a unas letras por renglón. Ahora el
                    // nombre ocupa todo el ancho arriba y los botones van debajo,
                    // alineados a la derecha. En horizontal / pantallas anchas se
                    // conserva la fila única de siempre.
                    if (ancho < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              iconoTablero,
                              const SizedBox(width: 10),
                              Expanded(child: textoNombre),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: acciones,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        iconoTablero,
                        const SizedBox(width: 10),
                        Expanded(child: textoNombre),
                        ...acciones,
                      ],
                    );
                  }),
                ),
                SizedBox(height: horizontal ? 4 : 16),

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
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              MensajesError.desde(snapshot.error, accion: 'cargar las tareas'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
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

                      final bool isDark = Theme.of(context).brightness == Brightness.dark;

                      final List<Color> paletaColoresHeaders = [
                        isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E293B), // Slate / Por Hacer (Tono claro en oscuro)
                        const Color(0xFF52ABEB), // Azul / En Progreso
                        const Color(0xFF63D0A1), // Verde Turquesa / Completada
                        const Color(0xFFE53E3E), // Rojo / Bloqueada
                        const Color(0xFF8B5CF6), // Morado
                        const Color(0xFFF59E0B), // Naranja / Ámbar
                        const Color(0xFF10B981), // Esmeralda
                      ];

                      // LayoutBuilder: la altura de las columnas se calcula con el
                      // espacio realmente disponible (antes dependía de la altura
                      // total de la pantalla y fallaba en horizontal).
                      return LayoutBuilder(
                        builder: (context, viewport) => SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: columnasList.asMap().entries.map((entry) {
                              final index = entry.key;
                              final colNombre = entry.value;

                              // BÚSQUEDA ROBUSTA Y GARANTÍA CERO PÉRDIDA DE TAREAS
                              final tareasColumna = todasLasTareas.where((t) {
                                return KanbanUtils.correspondeAColumna(t, colNombre, columnasList, index);
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
                                  alturaDisponible: viewport.maxHeight - 16,
                                ),
                              );
                            }).toList(),
                          ),
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

  // --- MÉTODOS AUXILIARES DE LA INTERFAZ ---

  // Constructor dinámico de columnas
  Widget _construirColumna({
    required String titulo,
    required String estadoNombre,
    required List<Tarea> tareas,
    required Color colorHeader,
    required Tablero? tablero,
    required PermisosMiembro permisos,
    double? alturaDisponible,
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
                SnackBar(content: Text(MensajesError.desde(e, accion: 'mover la tarea'))),
              );
            }
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        final theme = Theme.of(context);
        final bool isDark = theme.brightness == Brightness.dark;
        final isHovered = candidateData.isNotEmpty;
        final bool horizontal =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final double maxHeightOriginal = MediaQuery.of(context).size.height - 220;
        // Vertical: se conserva exactamente el cálculo original.
        // Horizontal: se usa la altura real disponible (si no, la columna de
        // 500 dp se desbordaba / quedaba cortada).
        final double alturaMax = (horizontal && alturaDisponible != null)
            ? (alturaDisponible < 120 ? 120.0 : alturaDisponible)
            : (maxHeightOriginal > 300 ? maxHeightOriginal : 500);

        return Container(
          width: 280,
          constraints: BoxConstraints(
            minHeight: alturaMax < 200 ? alturaMax : 200,
            maxHeight: alturaMax,
          ),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isHovered
                ? colorHeader.withOpacity(0.12)
                : (isDark ? const Color(0xFF182030) : Colors.grey.shade100.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered ? colorHeader : (isDark ? const Color(0xFF2D3748) : Colors.grey.shade200),
              width: isHovered ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encabezado con el conteo real dinámico (Fijo en la parte superior)
              ColumnHeaderWidget(
                count: '${tareas.length}',
                title: titulo,
                colorHeader: colorHeader,
              ),
              const SizedBox(height: 12),

              // Lista de tarjetas con scroll vertical independiente
              Expanded(
                child: tareas.isEmpty
                    ? Container(
                  height: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isHovered ? colorHeader : (isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
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
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                              backgroundColor: theme.cardColor,
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

  // Modales y llamadas de interfaz
  Future<void> _abrirAsistenteIa(BuildContext context, Tablero? tableroActivo) async {
    if (tableroActivo == null) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final permisos = tableroActivo.obtenerPermisosDeUsuario(currentUid);
    if (!permisos.crearTareas) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tienes permiso para crear tareas en este tablero')),
        );
      }
      return;
    }

    // Cargar información de integrantes del tablero (creador + miembros)
    final List<Usuario> miembros = [];
    final Set<String> uidsProcesados = {};

    final uidsACargar = {tableroActivo.creadorId, ...tableroActivo.miembrosIds};
    for (final uid in uidsACargar) {
      if (uid.isNotEmpty && !uidsProcesados.contains(uid)) {
        uidsProcesados.add(uid);
        try {
          final usuario = await _firestoreService.obtenerUsuarioPorId(uid);
          if (usuario != null) {
            miembros.add(usuario);
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => AsistenteIaController(),
          child: CapturaVozView(
            tablero: tableroActivo,
            miembrosEquipo: miembros,
          ),
        ),
      ),
    );
  }

  Future<void> _abrirChatbotIa(BuildContext context, Tablero? tableroActivo) async {
    if (tableroActivo == null) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final puedeVer = tableroActivo.creadorId == currentUid ||
        tableroActivo.miembrosIds.contains(currentUid);

    if (!puedeVer) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes permiso para ver este tablero'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // Cargar tareas del tablero activo
    List<Tarea> tareas;
    try {
      tareas = await _firestoreService.obtenerTareasDeTablero(tableroActivo.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cargar las tareas del tablero. Intenta de nuevo.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // Cargar mapa de nombres de integrantes
    final Map<String, String> miembrosNombres = {};
    final uidsACargar = {tableroActivo.creadorId, ...tableroActivo.miembrosIds};

    for (final uid in uidsACargar) {
      if (uid.isNotEmpty) {
        try {
          final usuario = await _firestoreService.obtenerUsuarioPorId(uid);
          if (usuario != null) {
            miembrosNombres[uid] = usuario.nombre;
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => AsistenteIaChatController(),
          child: AsistenteIaChatView(
            tablero: tableroActivo,
            tareasTablero: tareas,
            miembrosNombres: miembrosNombres,
          ),
        ),
      ),
    );
  }

  void _abrirFormularioNuevaTarea(BuildContext context, Tablero? tableroActivo) {
    if (tableroActivo == null) return;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
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

    if (!tableroActivo.esAdminOCreador(uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo el dueño o los administradores pueden acceder a los ajustes del tablero'),
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
            tablero: tableroActivo,
          ),
        ),
      );
      return;
    }

    if (tipoModulo == 'notas') {
      if (tableroActivo == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PantallaBorradoresPersonales(
            tablero: tableroActivo,
          ),
        ),
      );
      return;
    }

    if (tipoModulo == 'recordatorios') {
      if (tableroActivo == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Recordatorios(
            tableroId: tableroActivo.id,
            tablero: tableroActivo,
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // Si es modo oscuro y el color proporcionado es excesivamente oscuro (luminancia baja),
    // lo adaptamos a un tono slate claro visible (0xFF94A3B8).
    final Color colorEfectivo = (isDark && colorHeader.computeLuminance() < 0.25)
        ? const Color(0xFF94A3B8)
        : colorHeader;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorEfectivo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorEfectivo.withValues(alpha: 0.3), width: 1.2),
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
                  color: colorEfectivo,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: colorEfectivo,
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
              color: colorEfectivo,
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
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

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

    if (tarea.asignadoA != null && tablero != null && tablero!.esGrupal && tablero!.miembrosInfo.containsKey(tarea.asignadoA)) {
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
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade300, width: 1.2),
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
                          Icon(Icons.drag_indicator_rounded, color: isDark ? Colors.grey.shade500 : Colors.grey, size: 18),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // FILA 2: Título de la tarea
                      Text(
                        tituloDisplay,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
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
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade200),
                      const SizedBox(height: 8),

                      // FILA 4: Fecha E Integrante Asignado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                fechaDisplay,
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
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
                                color: tieneAsignado ? const Color(0xFF52ABEB).withOpacity(0.12) : (isDark ? const Color(0xFF121824) : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 9,
                                    backgroundColor: tieneAsignado ? const Color(0xFF52ABEB) : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
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
                                      color: tieneAsignado ? const Color(0xFF52ABEB) : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
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
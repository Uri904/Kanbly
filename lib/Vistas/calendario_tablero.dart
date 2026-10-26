import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../modelo/tarea.dart';
import '../modelo/tablero.dart';
import '../servicios/firestore_service.dart';
import '../controlador/calendario_controller.dart';
import 'detalle_tarea_widget.dart';

class CalendarioTablero extends StatefulWidget {
  final String tableroId;
  final Tablero? tablero;

  const CalendarioTablero({
    super.key,
    required this.tableroId,
    this.tablero,
  });

  @override
  State<CalendarioTablero> createState() => _CalendarioTableroState();
}

class _CalendarioTableroState extends State<CalendarioTablero> {
  final CalendarioController _controller = CalendarioController();
  final FirestoreService _firestoreService = FirestoreService();
  Tablero? _tableroCargado;

  @override
  void initState() {
    super.initState();
    _tableroCargado = widget.tablero;
    if (_tableroCargado == null) {
      _cargarTablero();
    }
  }

  Future<void> _cargarTablero() async {
    try {
      final t = await _firestoreService.obtenerTablero(widget.tableroId);
      if (t != null && mounted) {
        setState(() => _tableroCargado = t);
      }
    } catch (_) {}
  }

  void _irAHoy() {
    setState(() {
      _controller.seleccionarDia(DateTime.now(), DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textOnSurface = theme.colorScheme.onSurface;

    // Obtener idioma del teléfono
    final localeObj = Localizations.localeOf(context);
    final String localeStr = localeObj.toString(); // ej: 'es_ES', 'en_US', 'es'

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF37B5F4)),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [
                Color(0xFF52ABEB), // Azul
                Color(0xFF63D0A1), // Verde Turquesa
              ],
            ).createShader(bounds);
          },
          child: const Text(
            'Calendario de Tareas',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded, color: Color(0xFF52ABEB)),
            tooltip: 'Ir a Hoy',
            onPressed: _irAHoy,
          ),
        ],
      ),
      body: StreamBuilder<List<Tarea>>(
        stream: _controller.obtenerTareasDelTablero(widget.tableroId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF52ABEB)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar el calendario: ${snapshot.error}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            );
          }

          _controller.actualizarTareas(snapshot.data ?? []);

          final tareasSeleccionadas = _controller.tareasDelDia(
            _controller.diaSeleccionado,
          );

          final bool esHoy = isSameDay(_controller.diaSeleccionado, DateTime.now());

          // Formato localizado de la fecha seleccionada
          String fechaFormateada = '';
          try {
            fechaFormateada = DateFormat.yMMMMEEEEd(localeStr).format(_controller.diaSeleccionado);
            if (fechaFormateada.isNotEmpty) {
              fechaFormateada = fechaFormateada[0].toUpperCase() + fechaFormateada.substring(1);
            }
          } catch (_) {
            fechaFormateada = '${_controller.diaSeleccionado.day}/${_controller.diaSeleccionado.month}/${_controller.diaSeleccionado.year}';
          }

          return Column(
            children: [
              // CONTENEDOR DEL CALENDARIO DE MES
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
                child: TableCalendar<Tarea>(
                  locale: localeStr,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {CalendarFormat.month: ''},
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2040, 12, 31),
                  focusedDay: _controller.diaEnfocado,
                  selectedDayPredicate: (day) {
                    return isSameDay(_controller.diaSeleccionado, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _controller.seleccionarDia(selectedDay, focusedDay);
                    });
                  },
                  eventLoader: (day) {
                    return _controller.tareasDelDia(day);
                  },
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(
                      color: textOnSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF52ABEB), size: 28),
                    rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF52ABEB), size: 28),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    weekendStyle: TextStyle(
                      color: const Color(0xFF52ABEB).withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    defaultTextStyle: TextStyle(color: textOnSurface, fontWeight: FontWeight.w500),
                    weekendTextStyle: TextStyle(color: textOnSurface, fontWeight: FontWeight.w500),
                    outsideTextStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                    todayDecoration: const BoxDecoration(),
                    selectedDecoration: const BoxDecoration(),
                  ),
                  calendarBuilders: CalendarBuilders(
                    selectedBuilder: (context, date, events) {
                      return Container(
                        margin: const EdgeInsets.all(4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF52ABEB), Color(0xFF37B5F4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF52ABEB).withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${date.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                    todayBuilder: (context, date, events) {
                      final bool esSeleccionado = isSameDay(_controller.diaSeleccionado, date);
                      if (esSeleccionado) return null;

                      return Container(
                        margin: const EdgeInsets.all(4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF52ABEB), width: 2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${date.day}',
                          style: const TextStyle(
                            color: Color(0xFF52ABEB),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox();

                      final tareasEventos = events.cast<Tarea>();
                      return Positioned(
                        bottom: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: tareasEventos.take(3).map((t) {
                            final colorDot = _controller.colorPorTiempoRestante(
                              t.fechaVencimiento,
                              t.estado,
                            );
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: colorDot,
                                shape: BoxShape.circle,
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // BARRA CABECERA DEL DÍA SELECCIONADO
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fechaFormateada,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textOnSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            esHoy
                                ? 'Entregables programados para hoy'
                                : 'Entregables para este día',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF52ABEB).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${tareasSeleccionadas.length} ${tareasSeleccionadas.length == 1 ? "tarea" : "tareas"}',
                        style: const TextStyle(
                          color: Color(0xFF52ABEB),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // LISTADO DE TAREAS DEL DÍA
              Expanded(
                child: tareasSeleccionadas.isEmpty
                    ? Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF52ABEB).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.event_available_rounded,
                                  size: 40,
                                  color: Color(0xFF52ABEB),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Sin entregables programados',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textOnSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No hay tareas con fecha de vencimiento para el día seleccionado.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: tareasSeleccionadas.length,
                        itemBuilder: (context, index) {
                          final tarea = tareasSeleccionadas[index];
                          final colorEstado = _controller.colorPorEstado(tarea.estado);
                          final colorTiempo = _controller.colorPorTiempoRestante(
                            tarea.fechaVencimiento,
                            tarea.estado,
                          );
                          final textoTiempo = _controller.textoEstadoTiempo(
                            tarea.fechaVencimiento,
                            tarea.estado,
                          );

                          String prioridadTexto = 'Baja';
                          Color prioridadColor = const Color(0xFF63D0A1);
                          if (tarea.prioridad == 2) {
                            prioridadTexto = 'Media';
                            prioridadColor = const Color(0xFFF59E0B);
                          } else if (tarea.prioridad >= 3) {
                            prioridadTexto = 'Alta';
                            prioridadColor = const Color(0xFFE53E3E);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade200,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => DetalleTareaWidget(
                                    tarea: tarea,
                                    tablero: _tableroCargado ?? widget.tablero,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Row(
                                  children: [
                                    // Indicador de Estado
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colorEstado.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        tarea.estado == EstadoTarea.completada
                                            ? Icons.check_circle_rounded
                                            : tarea.estado == EstadoTarea.bloqueada
                                                ? Icons.block_rounded
                                                : Icons.access_time_filled_rounded,
                                        color: colorEstado,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Información Principal de la Tarea
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tarea.titulo,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: textOnSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (tarea.descripcion?.isNotEmpty == true) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              tarea.descripcion!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 8),

                                          // Chips de Estado, Prioridad y Tiempo
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              // Badge de Estado
                                              _chipEtiqueta(
                                                texto: tarea.estado.value,
                                                colorFondo: colorEstado.withOpacity(0.12),
                                                colorTexto: colorEstado,
                                              ),
                                              // Badge de Prioridad
                                              _chipEtiqueta(
                                                texto: 'Prioridad $prioridadTexto',
                                                colorFondo: prioridadColor.withOpacity(0.12),
                                                colorTexto: prioridadColor,
                                              ),
                                              // Badge de Tiempo Restante
                                              _chipEtiqueta(
                                                texto: textoTiempo,
                                                colorFondo: colorTiempo.withOpacity(0.12),
                                                colorTexto: colorTiempo,
                                                icono: Icons.timer_outlined,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chipEtiqueta({
    required String texto,
    required Color colorFondo,
    required Color colorTexto,
    IconData? icono,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 10, color: colorTexto),
            const SizedBox(width: 3),
          ],
          Text(
            texto,
            style: TextStyle(
              color: colorTexto,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

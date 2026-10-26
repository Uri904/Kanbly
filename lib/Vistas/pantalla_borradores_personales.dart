import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelo/tablero.dart';
import '../modelo/tarea.dart';
import '../modelo/borrador_nota.dart';
import '../modelo/usuario.dart';
import '../servicios/firestore_service.dart';
import '../servicios/storage_service.dart';
import '../utilerias/formato_util.dart';
import 'pantalla_visualizador_adjunto.dart';
import 'detalle_tarea_widget.dart';

class PantallaBorradoresPersonales extends StatefulWidget {
  final Tablero tablero;

  const PantallaBorradoresPersonales({
    super.key,
    required this.tablero,
  });

  @override
  State<PantallaBorradoresPersonales> createState() => _PantallaBorradoresPersonalesState();
}

class _PantallaBorradoresPersonalesState extends State<PantallaBorradoresPersonales> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<Usuario> _miembrosEquipo = [];
  bool _cargandoMiembros = false;

  static const int _maxTamanoBytes = 10 * 1024 * 1024; // 10 MB

  static const List<Map<String, dynamic>> _coloresEtiqueta = [
    {'nombre': 'Azul Kanbly', 'hex': '0xFF52ABEB', 'color': Color(0xFF52ABEB)},
    {'nombre': 'Verde Turquesa', 'hex': '0xFF63D0A1', 'color': Color(0xFF63D0A1)},
    {'nombre': 'Naranja', 'hex': '0xFFED8936', 'color': Color(0xFFED8936)},
    {'nombre': 'Púrpura', 'hex': '0xFF9F7AEA', 'color': Color(0xFF9F7AEA)},
    {'nombre': 'Coral', 'hex': '0xFFF56565', 'color': Color(0xFFF56565)},
  ];

  @override
  void initState() {
    super.initState();
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

  /// Verifica borradores con fecha de publicación automatizada cumplida y los publica
  void _verificarBorradoresProgramados(List<BorradorNota> borradores) async {
    final permisos = widget.tablero.obtenerPermisosDeUsuario(_currentUid);
    if (!permisos.crearTareas) return;

    final ahora = DateTime.now();
    for (final b in borradores) {
      if (!b.esPublicado &&
          b.fechaPublicacionProgramada != null &&
          b.fechaPublicacionProgramada!.isBefore(ahora)) {
        try {
          await _firestoreService.convertirBorradorATarea(
            borrador: b,
            columnaDestino: b.columnaDestino.isNotEmpty ? b.columnaDestino : 'Pendiente',
            prioridad: b.prioridad,
          );
        } catch (_) {}
      }
    }
  }

  Future<void> _abrirDetalleTareaVinculada(String tareaId) async {
    try {
      final tarea = await _firestoreService.obtenerTarea(tareaId);
      if (tarea != null && mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DetalleTareaWidget(
            tarea: tarea,
            tablero: widget.tablero,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La tarea vinculada no se encontró o fue eliminada.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar la tarea vinculada: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textoPrincipal = theme.colorScheme.onSurface;
    const Color azulCielo = Color(0xFF52ABEB);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textoPrincipal),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Espacio Personal: ${widget.tablero.nombre}',
            style: GoogleFonts.inter(
              color: textoPrincipal,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF182030) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: azulCielo,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sticky_note_2_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Notas Personales'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pending_actions_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Borradores Tareas'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: StreamBuilder<List<BorradorNota>>(
          stream: _firestoreService.escucharBorradoresNota(_currentUid, widget.tablero.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: azulCielo));
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error al cargar elementos: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              );
            }

            final todosElementos = snapshot.data ?? [];

            if (todosElementos.isNotEmpty) {
              _verificarBorradoresProgramados(todosElementos);
            }

            final notasPersonales = todosElementos.where((b) => b.esNotaPersonal).toList();
            final borradoresTareas = todosElementos.where((b) => !b.esNotaPersonal).toList();

            return TabBarView(
              children: [
                // PESTAÑA 1: SECCIÓN DE NOTAS PERSONALES
                _construirVistaNotasPersonales(notasPersonales),

                // PESTAÑA 2: SECCIÓN DE BORRADORES DE TAREAS
                _construirVistaBorradoresTareas(borradoresTareas),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- VISTA DE NOTAS PERSONALES ---
  Widget _construirVistaNotasPersonales(List<BorradorNota> notas) {
    final theme = Theme.of(context);
    final Color textoPrincipal = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // BANNER DE NOTAS
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.teal.shade50.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade300),
            ),
            child: const Row(
              children: [
                Icon(Icons.sticky_note_2_rounded, color: Colors.teal, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Notas Personales: Anotaciones privadas que puedes vincular opcionalmente a cualquier tarea del tablero.',
                    style: TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: notas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sticky_note_2_outlined, size: 68, color: Colors.grey.shade400),
                          const SizedBox(height: 14),
                          Text(
                            'No tienes notas personales aún',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: textoPrincipal),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Crea tus notas personales y conéctalas con tareas del tablero para llevar un mejor control de tus ideas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            icon: const Icon(Icons.add_rounded, color: Colors.white),
                            label: const Text('Crear mi primera nota', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () => _abrirFormularioNotaPersonal(),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notas.length,
                    itemBuilder: (context, index) {
                      final nota = notas[index];
                      return _tarjetaNotaPersonal(nota);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nueva Nota Personal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _abrirFormularioNotaPersonal(),
      ),
    );
  }

  // --- VISTA DE BORRADORES DE TAREAS ---
  Widget _construirVistaBorradoresTareas(List<BorradorNota> borradores) {
    final theme = Theme.of(context);
    final Color textoPrincipal = theme.colorScheme.onSurface;
    const Color azulCielo = Color(0xFF52ABEB);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // BANNER DE BORRADORES DE TAREAS
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: azulCielo.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: azulCielo.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.pending_actions_rounded, color: azulCielo, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Borradores de Tareas: Diseña tareas en avance, asigna integrantes y programa la publicación automatizada.',
                    style: TextStyle(fontSize: 11, color: azulCielo, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: borradores.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pending_actions_rounded, size: 68, color: Colors.grey.shade400),
                          const SizedBox(height: 14),
                          Text(
                            'No tienes borradores de tareas programadas',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: textoPrincipal),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Crea borradores de tareas previas para publicarlas oficialmente o programar su salida en el tablero.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: azulCielo,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            icon: const Icon(Icons.add_rounded, color: Colors.white),
                            label: const Text('Crear borrador de tarea', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () => _abrirFormularioBorrador(),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: borradores.length,
                    itemBuilder: (context, index) {
                      final borrador = borradores[index];
                      return _tarjetaBorradorTarea(borrador);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: azulCielo,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nuevo Borrador Tarea', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _abrirFormularioBorrador(),
      ),
    );
  }

  // --- TARJETA EXCLUSIVA PARA NOTA PERSONAL ---
  Widget _tarjetaNotaPersonal(BorradorNota nota) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textoPrincipal = theme.colorScheme.onSurface;
    final colorVal = int.tryParse(nota.colorHex) ?? 0xFF009688;
    final colorEtiqueta = Color(colorVal);

    final tieneTareaVinculada = nota.tareaId != null && nota.tareaId!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorEtiqueta.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ENCABEZADO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorEtiqueta.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.sticky_note_2_rounded, size: 16, color: colorEtiqueta),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nota.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: textoPrincipal),
                  ),
                ),
                Text(
                  FormatoUtil.formatearFechaHora(nota.fechaCreacion),
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // BADGE DE TAREA VINCULADA
          if (tieneTareaVinculada)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, top: 10),
              child: GestureDetector(
                onTap: () => _abrirDetalleTareaVinculada(nota.tareaId!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF107C41).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF107C41).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.push_pin_rounded, size: 12, color: Color(0xFF107C41)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Vinculada a: ${nota.tareaTitulo ?? "Ver Tarea"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF107C41)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF107C41)),
                    ],
                  ),
                ),
              ),
            ),

          // CONTENIDO DE LA NOTA
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              nota.contenido.isNotEmpty ? nota.contenido : 'Sin detalles anotados.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: nota.contenido.isNotEmpty ? textoPrincipal : Colors.grey.shade500,
                fontStyle: nota.contenido.isNotEmpty ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),

          // ADJUNTOS
          if (nota.adjuntos.isNotEmpty) ...[
            Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: nota.adjuntos.map((adj) {
                  return GestureDetector(
                    onTap: () => PantallaVisualizadorAdjunto.abrir(context, adj),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121824) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _obtenerIconoTipoAdjunto(adj.tipo, adj.nombre),
                          const SizedBox(width: 4),
                          Text(adj.nombre, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textoPrincipal)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade200),

          // BARRA DE ACCIONES NOTA: EDITAR Y ELIMINAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.teal),
                      tooltip: 'Editar Nota',
                      onPressed: () => _abrirFormularioNotaPersonal(nota: nota),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      tooltip: 'Eliminar Nota',
                      onPressed: () => _confirmarEliminacion(nota),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _mostrarModalPublicarTarea(nota),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 14, color: Colors.teal),
                  label: const Text('Convertir a Tarea', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TARJETA EXCLUSIVA PARA BORRADOR DE TAREA ---
  Widget _tarjetaBorradorTarea(BorradorNota borrador) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textoPrincipal = theme.colorScheme.onSurface;
    const Color azulCielo = Color(0xFF52ABEB);
    final colorVal = int.tryParse(borrador.colorHex) ?? 0xFF52ABEB;
    final colorEtiqueta = Color(colorVal);

    final colorPrioridad = FormatoUtil.obtenerColorPorPrioridad(borrador.prioridad);

    final usuariosAsignadosBorrador = _miembrosEquipo.where((m) => borrador.asignadosA.contains(m.id)).toList();
    String textoAsignacion = 'Sin asignar';
    if (borrador.asignadosA.isNotEmpty) {
      if (usuariosAsignadosBorrador.isNotEmpty) {
        if (usuariosAsignadosBorrador.length == 1) {
          textoAsignacion = 'Asignado: ${usuariosAsignadosBorrador.first.nombreCompleto}';
        } else {
          textoAsignacion = '${usuariosAsignadosBorrador.length} asignados (${usuariosAsignadosBorrador.map((m) => m.nombreCompleto.split(' ').first).join(', ')})';
        }
      } else {
        textoAsignacion = '${borrador.asignadosA.length} asignado${borrador.asignadosA.length > 1 ? "s" : ""}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorEtiqueta.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ENCABEZADO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorEtiqueta.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: colorEtiqueta, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    borrador.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: textoPrincipal),
                  ),
                ),
                Text(
                  FormatoUtil.formatearFechaHora(borrador.fechaCreacion),
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // BADGES COMPACTOS DE TAREA: PRIORIDAD, ASIGNADO Y PROGRAMADO
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // BADGE PRIORIDAD
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorPrioridad.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorPrioridad.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_rounded, size: 12, color: colorPrioridad),
                      const SizedBox(width: 4),
                      Text(
                        FormatoUtil.obtenerTextoPrioridad(borrador.prioridad),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorPrioridad),
                      ),
                    ],
                  ),
                ),

                // BADGE ASIGNADO
                if (borrador.asignadosA.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: azulCielo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: azulCielo.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_rounded, size: 12, color: azulCielo),
                        const SizedBox(width: 4),
                        Text(
                          textoAsignacion,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: azulCielo),
                        ),
                      ],
                    ),
                  ),

                // BADGE PROGRAMADO
                if (borrador.fechaPublicacionProgramada != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.alarm_rounded, size: 12, color: Colors.purple),
                        const SizedBox(width: 4),
                        Text(
                          'Programado: ${FormatoUtil.formatearFechaHora(borrador.fechaPublicacionProgramada!)}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // DESCRIPCIÓN
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              borrador.contenido.isNotEmpty ? borrador.contenido : 'Sin descripción detallada.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: borrador.contenido.isNotEmpty ? textoPrincipal : Colors.grey.shade500,
                fontStyle: borrador.contenido.isNotEmpty ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),

          // ADJUNTOS
          if (borrador.adjuntos.isNotEmpty) ...[
            Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: borrador.adjuntos.map((adj) {
                  return GestureDetector(
                    onTap: () => PantallaVisualizadorAdjunto.abrir(context, adj),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121824) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _obtenerIconoTipoAdjunto(adj.tipo, adj.nombre),
                          const SizedBox(width: 6),
                          Text(adj.nombre, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textoPrincipal)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade200),

          // BARRA DE ACCIONES BORRADOR TAREA: EDITAR, ELIMINAR Y PUBLICAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF52ABEB)),
                      tooltip: 'Editar borrador',
                      onPressed: () => _abrirFormularioBorrador(borrador: borrador),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                      tooltip: 'Eliminar borrador',
                      onPressed: () => _confirmarEliminacion(borrador),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF63D0A1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 16, color: Colors.white),
                  label: const Text('Publicar Tarea', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _mostrarModalPublicarTarea(borrador),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // FORMULARIO INDEPENDIENTE 1: FORMULARIO EXCLUSIVO PARA NOTAS PERSONALES
  // =========================================================================
  void _abrirFormularioNotaPersonal({BorradorNota? nota, Tarea? tareaPreseleccionada}) async {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textoPrincipal = theme.colorScheme.onSurface;

    final esEdicion = nota != null;
    final tituloController = TextEditingController(text: nota?.titulo ?? '');
    final contenidoController = TextEditingController(text: nota?.contenido ?? '');
    String colorHexSeleccionado = nota?.colorHex ?? '0xFF009688';

    String? tareaIdVinculada = nota?.tareaId ?? tareaPreseleccionada?.id;
    String? tareaTituloVinculada = nota?.tareaTitulo ?? tareaPreseleccionada?.titulo;

    List<AdjuntoTarea> adjuntosTemporales = List.from(nota?.adjuntos ?? []);
    bool guardandoNota = false;

    // Cargar tareas del tablero para el selector desplegable
    List<Tarea> tareasTablero = [];
    try {
      tareasTablero = await _firestoreService.obtenerTareasDeTablero(widget.tablero.id);
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 20, right: 20, top: 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ENCABEZADO FORMULARIO DE NOTA
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sticky_note_2_rounded, color: Colors.teal, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              esEdicion ? 'Editar Nota Personal' : 'Nueva Nota Personal',
                              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: textoPrincipal),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // CAMPO: TÍTULO DE LA NOTA
                    TextFormField(
                      controller: tituloController,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textoPrincipal),
                      decoration: InputDecoration(
                        labelText: 'Título de la Nota *',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121824) : const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // CAMPO: CONTENIDO / DETALLES DE LA NOTA
                    TextFormField(
                      controller: contenidoController,
                      minLines: 3,
                      maxLines: 5,
                      style: GoogleFonts.inter(fontSize: 13, color: textoPrincipal, height: 1.4),
                      decoration: InputDecoration(
                        labelText: 'Anotaciones y Detalles (Opcional)',
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121824) : const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // SELECTOR DE TAREA VINCULADA DEL TABLERO
                    Text('Vincular a una Tarea del Tablero (Opcional):', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      value: tareasTablero.any((t) => t.id == tareaIdVinculada) ? tareaIdVinculada : null,
                      isExpanded: true,
                      dropdownColor: theme.cardColor,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121824) : const Color(0xFFF8FAFC),
                      ),
                      hint: const Text('-- Ninguna (Nota Suelta) --', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('-- Ninguna (Nota Suelta) --', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                        ...tareasTablero.map((t) {
                          return DropdownMenuItem<String?>(
                            value: t.id,
                            child: Text(
                              '📌 ${t.titulo} (${t.estadoNombre})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          tareaIdVinculada = val;
                          if (val != null) {
                            final tEncontrada = tareasTablero.firstWhere((element) => element.id == val);
                            tareaTituloVinculada = tEncontrada.titulo;
                          } else {
                            tareaTituloVinculada = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // ARCHIVOS ADJUNTOS EN LA NOTA
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Archivos Adjuntos (${adjuntosTemporales.length}):',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal),
                        ),
                        TextButton.icon(
                          onPressed: () => _mostrarMenuAdjuntarEnModal(setModalState, adjuntosTemporales),
                          icon: const Icon(Icons.attach_file_rounded, size: 16, color: Colors.teal),
                          label: const Text('Adjuntar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
                        ),
                      ],
                    ),
                    if (adjuntosTemporales.isNotEmpty)
                      Column(
                        children: adjuntosTemporales.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final adj = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF182030) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                _obtenerIconoTipoAdjunto(adj.tipo, adj.nombre),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    adj.nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                                  onPressed: () => setModalState(() => adjuntosTemporales.removeAt(idx)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 14),

                    // COLOR DE LA NOTA
                    Text('Color de la Nota:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                    const SizedBox(height: 8),
                    Row(
                      children: _coloresEtiqueta.map((c) {
                        final hex = c['hex'] as String;
                        final color = c['color'] as Color;
                        final activo = colorHexSeleccionado == hex;
                        return GestureDetector(
                          onTap: () => setModalState(() => colorHexSeleccionado = hex),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: activo ? Colors.black : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: activo ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // BOTÓN GUARDAR NOTA PERSONAL
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: guardandoNota
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                        label: Text(
                          guardandoNota ? 'Guardando...' : (esEdicion ? 'Guardar Cambios' : 'Guardar Nota Personal'),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: guardandoNota
                            ? null
                            : () async {
                                final titulo = tituloController.text.trim();
                                if (titulo.isEmpty) return;

                                setModalState(() => guardandoNota = true);

                                try {
                                  final storageService = StorageService();
                                  List<AdjuntoTarea> adjuntosSubidos = [];

                                  final borradorIdFinal = esEdicion
                                      ? nota.id
                                      : FirebaseFirestore.instance.collection('borradores_notas').doc().id;

                                  for (final adj in adjuntosTemporales) {
                                    if (adj.url.isNotEmpty && !adj.url.startsWith('http')) {
                                      final urlRemota = await storageService.subirAdjuntoTarea(
                                        filePath: adj.url,
                                        nombreArchivo: adj.nombre,
                                        tareaId: 'note_$borradorIdFinal',
                                      );
                                      adjuntosSubidos.add(AdjuntoTarea(
                                        id: adj.id,
                                        nombre: adj.nombre,
                                        url: urlRemota,
                                        tipo: adj.tipo,
                                        tamanoBytes: adj.tamanoBytes,
                                        fechaAdjunto: adj.fechaAdjunto,
                                      ));
                                    } else {
                                      adjuntosSubidos.add(adj);
                                    }
                                  }

                                  if (esEdicion) {
                                    final notaActualizada = nota.copyWith(
                                      titulo: titulo,
                                      contenido: contenidoController.text.trim(),
                                      colorHex: colorHexSeleccionado,
                                      adjuntos: adjuntosSubidos,
                                      fechaActualizacion: DateTime.now(),
                                      tareaId: tareaIdVinculada,
                                      clearTareaId: tareaIdVinculada == null,
                                      tareaTitulo: tareaTituloVinculada,
                                      esNotaPersonal: true,
                                    );
                                    await _firestoreService.actualizarBorradorNota(notaActualizada);
                                  } else {
                                    final nuevaNota = BorradorNota(
                                      id: borradorIdFinal,
                                      usuarioId: _currentUid,
                                      tableroId: widget.tablero.id,
                                      titulo: titulo,
                                      contenido: contenidoController.text.trim(),
                                      fechaCreacion: DateTime.now(),
                                      colorHex: colorHexSeleccionado,
                                      adjuntos: adjuntosSubidos,
                                      tareaId: tareaIdVinculada,
                                      tareaTitulo: tareaTituloVinculada,
                                      esNotaPersonal: true,
                                    );
                                    await _firestoreService.crearBorradorNota(nuevaNota);
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                } catch (e) {
                                  setModalState(() => guardandoNota = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error al guardar nota: $e')),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // FORMULARIO INDEPENDIENTE 2: FORMULARIO EXCLUSIVO PARA BORRADORES DE TAREAS
  // =========================================================================
  void _abrirFormularioBorrador({BorradorNota? borrador}) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textoPrincipal = theme.colorScheme.onSurface;

    final esEdicion = borrador != null;
    final tituloController = TextEditingController(text: borrador?.titulo ?? '');
    final contenidoController = TextEditingController(text: borrador?.contenido ?? '');
    String colorHexSeleccionado = borrador?.colorHex ?? '0xFF52ABEB';
    List<String> asignadosA = List.from(borrador?.asignadosA ?? []);
    DateTime? fechaProgramada = borrador?.fechaPublicacionProgramada;
    String columnaDestino = borrador?.columnaDestino ?? (widget.tablero.columnas.isNotEmpty ? widget.tablero.columnas.first : 'Pendiente');
    int prioridadSeleccionada = borrador?.prioridad ?? 2;

    List<AdjuntoTarea> adjuntosTemporales = List.from(borrador?.adjuntos ?? []);
    bool guardandoBorrador = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final columnasDisponibles = widget.tablero.columnas.isNotEmpty
                ? widget.tablero.columnas
                : const ['Pendiente', 'En progreso', 'Completada'];

            return Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 20, right: 20, top: 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ENCABEZADO
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pending_actions_rounded, color: Color(0xFF52ABEB), size: 22),
                            const SizedBox(width: 8),
                            Text(
                              esEdicion ? 'Editar Borrador de Tarea' : 'Nuevo Borrador de Tarea',
                              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: textoPrincipal),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // CAMPO: TÍTULO DEL BORRADOR
                    TextFormField(
                      controller: tituloController,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textoPrincipal),
                      decoration: InputDecoration(
                        labelText: 'Título de la Tarea en Borrador *',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121824) : const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // CAMPO: DESCRIPCIÓN
                    TextFormField(
                      controller: contenidoController,
                      minLines: 3,
                      maxLines: 5,
                      style: GoogleFonts.inter(fontSize: 13, color: textoPrincipal, height: 1.4),
                      decoration: InputDecoration(
                        labelText: 'Descripción y Detalles del Borrador (Opcional)',
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121824) : const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // INTEGRANTES ASIGNADOS EN TABLEROS DE EQUIPO
                    if (widget.tablero.esGrupal) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Asignar Integrantes:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal)),
                          Text(
                            asignadosA.isEmpty
                                ? 'Sin asignar (0)'
                                : '${asignadosA.length} persona${asignadosA.length > 1 ? "s" : ""}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: asignadosA.isEmpty ? Colors.grey : const Color(0xFF52ABEB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _cargandoMiembros
                          ? const LinearProgressIndicator()
                          : _miembrosEquipo.isEmpty
                              ? Text('No hay integrantes en este tablero.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: _miembrosEquipo.map((m) {
                                    final estaSeleccionado = asignadosA.contains(m.id);
                                    return FilterChip(
                                      avatar: CircleAvatar(
                                        backgroundColor: estaSeleccionado ? Colors.white : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                        child: Text(
                                          m.nombreCompleto.isNotEmpty ? m.nombreCompleto[0].toUpperCase() : '?',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: estaSeleccionado ? const Color(0xFF52ABEB) : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                          ),
                                        ),
                                      ),
                                      label: Text(
                                        m.nombreCompleto,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: estaSeleccionado ? FontWeight.bold : FontWeight.normal,
                                          color: estaSeleccionado ? Colors.white : textoPrincipal,
                                        ),
                                      ),
                                      selected: estaSeleccionado,
                                      selectedColor: const Color(0xFF52ABEB),
                                      checkmarkColor: Colors.white,
                                      backgroundColor: isDark ? const Color(0xFF121824) : const Color(0xFFF8FAFC),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: estaSeleccionado ? const Color(0xFF52ABEB) : (isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
                                        ),
                                      ),
                                      onSelected: (bool selected) {
                                        setModalState(() {
                                          if (selected) {
                                            asignadosA.add(m.id);
                                          } else {
                                            asignadosA.remove(m.id);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                      const SizedBox(height: 14),
                    ],

                    // PRIORIDAD
                    Text('Prioridad:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _botonPrioridadForm(1, 'Baja', const Color(0xFF38A169), prioridadSeleccionada, (v) => setModalState(() => prioridadSeleccionada = v)),
                        _botonPrioridadForm(2, 'Media', const Color(0xFFED8936), prioridadSeleccionada, (v) => setModalState(() => prioridadSeleccionada = v)),
                        _botonPrioridadForm(3, 'Alta', const Color(0xFFE53E3E), prioridadSeleccionada, (v) => setModalState(() => prioridadSeleccionada = v)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // PROGRAMAR FECHA Y HORA DE PUBLICACIÓN AUTOMÁTICA
                    Text('Publicación Automatizada:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.alarm_add_rounded, size: 16, color: Color(0xFF52ABEB)),
                            label: Text(
                              fechaProgramada == null
                                  ? 'Programar Fecha y Hora'
                                  : 'Programado: ${FormatoUtil.formatearFechaHora(fechaProgramada!)}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal),
                            ),
                            onPressed: () async {
                              final fecha = await showDatePicker(
                                context: context,
                                initialDate: fechaProgramada ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030),
                                locale: Localizations.localeOf(context),
                              );
                              if (fecha != null && context.mounted) {
                                final hora = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(fechaProgramada ?? DateTime.now()),
                                );
                                if (hora != null) {
                                  setModalState(() {
                                    fechaProgramada = DateTime(
                                      fecha.year, fecha.month, fecha.day,
                                      hora.hour, hora.minute,
                                    );
                                  });
                                }
                              }
                            },
                          ),
                        ),
                        if (fechaProgramada != null)
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                            onPressed: () => setModalState(() => fechaProgramada = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // COLUMNA DESTINO
                    Text('Columna Destino al Publicar:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal)),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: columnasDisponibles.map((col) {
                          final seleccionada = columnaDestino == col;
                          return GestureDetector(
                            onTap: () => setModalState(() => columnaDestino = col),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: seleccionada ? const Color(0xFF52ABEB) : (isDark ? const Color(0xFF121824) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: seleccionada ? const Color(0xFF52ABEB) : (isDark ? const Color(0xFF2D3748) : Colors.grey.shade300)),
                              ),
                              child: Text(
                                col,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: seleccionada ? Colors.white : textoPrincipal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ARCHIVOS ADJUNTOS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Archivos Adjuntos (${adjuntosTemporales.length}):',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textoPrincipal),
                        ),
                        TextButton.icon(
                          onPressed: () => _mostrarMenuAdjuntarEnModal(setModalState, adjuntosTemporales),
                          icon: const Icon(Icons.attach_file_rounded, size: 16, color: Color(0xFF52ABEB)),
                          label: const Text('Adjuntar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF52ABEB))),
                        ),
                      ],
                    ),
                    if (adjuntosTemporales.isNotEmpty)
                      Column(
                        children: adjuntosTemporales.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final adj = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF182030) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                _obtenerIconoTipoAdjunto(adj.tipo, adj.nombre),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    adj.nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                                  onPressed: () => setModalState(() => adjuntosTemporales.removeAt(idx)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 14),

                    // COLOR ETIQUETA
                    Text('Color de Tarjeta Borrador:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                    const SizedBox(height: 8),
                    Row(
                      children: _coloresEtiqueta.map((c) {
                        final hex = c['hex'] as String;
                        final color = c['color'] as Color;
                        final activo = colorHexSeleccionado == hex;
                        return GestureDetector(
                          onTap: () => setModalState(() => colorHexSeleccionado = hex),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: activo ? Colors.black : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: activo ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // BOTÓN GUARDAR BORRADOR DE TAREA
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF52ABEB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: guardandoBorrador
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                        label: Text(
                          guardandoBorrador ? 'Guardando...' : (esEdicion ? 'Guardar Cambios' : 'Guardar Borrador de Tarea'),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: guardandoBorrador
                            ? null
                            : () async {
                                final titulo = tituloController.text.trim();
                                if (titulo.isEmpty) return;

                                setModalState(() => guardandoBorrador = true);

                                try {
                                  final storageService = StorageService();
                                  List<AdjuntoTarea> adjuntosSubidos = [];

                                  final borradorIdFinal = esEdicion
                                      ? borrador.id
                                      : FirebaseFirestore.instance.collection('borradores_notas').doc().id;

                                  for (final adj in adjuntosTemporales) {
                                    if (adj.url.isNotEmpty && !adj.url.startsWith('http')) {
                                      final urlRemota = await storageService.subirAdjuntoTarea(
                                        filePath: adj.url,
                                        nombreArchivo: adj.nombre,
                                        tareaId: 'draft_$borradorIdFinal',
                                      );
                                      adjuntosSubidos.add(AdjuntoTarea(
                                        id: adj.id,
                                        nombre: adj.nombre,
                                        url: urlRemota,
                                        tipo: adj.tipo,
                                        tamanoBytes: adj.tamanoBytes,
                                        fechaAdjunto: adj.fechaAdjunto,
                                      ));
                                    } else {
                                      adjuntosSubidos.add(adj);
                                    }
                                  }

                                  if (esEdicion) {
                                    final borradorActualizado = borrador.copyWith(
                                      titulo: titulo,
                                      contenido: contenidoController.text.trim(),
                                      colorHex: colorHexSeleccionado,
                                      adjuntos: adjuntosSubidos,
                                      fechaActualizacion: DateTime.now(),
                                      asignadosA: asignadosA,
                                      fechaPublicacionProgramada: fechaProgramada,
                                      columnaDestino: columnaDestino,
                                      prioridad: prioridadSeleccionada,
                                      esNotaPersonal: false,
                                    );
                                    await _firestoreService.actualizarBorradorNota(borradorActualizado);
                                  } else {
                                    final nuevoBorrador = BorradorNota(
                                      id: borradorIdFinal,
                                      usuarioId: _currentUid,
                                      tableroId: widget.tablero.id,
                                      titulo: titulo,
                                      contenido: contenidoController.text.trim(),
                                      fechaCreacion: DateTime.now(),
                                      colorHex: colorHexSeleccionado,
                                      adjuntos: adjuntosSubidos,
                                      asignadosA: asignadosA,
                                      fechaPublicacionProgramada: fechaProgramada,
                                      columnaDestino: columnaDestino,
                                      prioridad: prioridadSeleccionada,
                                      esNotaPersonal: false,
                                    );
                                    await _firestoreService.crearBorradorNota(nuevoBorrador);
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                } catch (e) {
                                  setModalState(() => guardandoBorrador = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error al guardar borrador: $e')),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _botonPrioridadForm(int valor, String texto, Color color, int seleccionada, Function(int) onTap) {
    final theme = Theme.of(context);
    final activo = seleccionada == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(valor),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: activo ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: activo ? 1.8 : 1),
          ),
          alignment: Alignment.center,
          child: Text(
            texto,
            style: TextStyle(
              color: activo ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ADJUNTAR ARCHIVO DENTRO DEL MODAL
  void _mostrarMenuAdjuntarEnModal(StateSetter setModalState, List<AdjuntoTarea> listaAdjuntos) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Adjuntar Archivo (Máx. 10MB)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFEBF8FF), child: Icon(Icons.image_rounded, color: Color(0xFF52ABEB))),
                  title: const Text('Imagen'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarArchivoParaBorrador(FileType.image, 'imagen', setModalState, listaAdjuntos);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFFFF5F5), child: Icon(Icons.videocam_rounded, color: Colors.redAccent)),
                  title: const Text('Video'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarArchivoParaBorrador(FileType.video, 'video', setModalState, listaAdjuntos);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFF0FDF4), child: Icon(Icons.description_rounded, color: Color(0xFF63D0A1))),
                  title: const Text('Documento / PDF'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarArchivoParaBorrador(FileType.custom, 'documento', setModalState, listaAdjuntos, extensiones: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'pptx', 'ppt']);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _seleccionarArchivoParaBorrador(
    FileType fileType,
    String tipoEtiqueta,
    StateSetter setModalState,
    List<AdjuntoTarea> listaAdjuntos, {
    List<String>? extensiones,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: extensiones,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          final tamano = file.size;

          if (tamano > _maxTamanoBytes) {
            final tamanoMB = (tamano / (1024 * 1024)).toStringAsFixed(1);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('El archivo "${file.name}" excede el límite permitido de 10 MB ($tamanoMB MB)'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
            continue;
          }

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

          setModalState(() {
            listaAdjuntos.add(adjunto);
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

  Widget _obtenerIconoTipoAdjunto(String tipo, [String? nombre]) {
    final nameLower = (nombre ?? '').toLowerCase();
    final tipoLower = tipo.toLowerCase();

    if (nameLower.endsWith('.pdf')) {
      return const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFD32F2F), size: 18);
    } else if (tipoLower == 'imagen' || ['.jpg', '.jpeg', '.png', '.webp'].any((ext) => nameLower.endsWith(ext))) {
      return const Icon(Icons.image_rounded, color: Color(0xFF52ABEB), size: 18);
    } else if (tipoLower == 'video' || ['.mp4', '.mov', '.avi'].any((ext) => nameLower.endsWith(ext))) {
      return const Icon(Icons.videocam_rounded, color: Colors.redAccent, size: 18);
    }
    return const Icon(Icons.description_rounded, color: Color(0xFF63D0A1), size: 18);
  }

  // MODAL PARA PUBLICAR
  void _mostrarModalPublicarTarea(BorradorNota borrador) {
    final permisos = widget.tablero.obtenerPermisosDeUsuario(_currentUid);
    if (!permisos.crearTareas) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para crear o publicar tareas en este tablero.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textoPrincipal = theme.colorScheme.onSurface;

    final columnas = widget.tablero.columnas.isNotEmpty
        ? widget.tablero.columnas
        : const ['Pendiente', 'En progreso', 'Completada'];

    String columnaSeleccionada = borrador.columnaDestino.isNotEmpty && columnas.contains(borrador.columnaDestino)
        ? borrador.columnaDestino
        : columnas.first;
    int prioridadSeleccionada = borrador.prioridad;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚀 Publicar como Tarea Oficial',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: textoPrincipal),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Se creará la tarea "${borrador.titulo}" en el tablero, incluyendo sus ${borrador.adjuntos.length} archivos adjuntos.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: columnaSeleccionada,
                    dropdownColor: theme.cardColor,
                    decoration: InputDecoration(
                      labelText: 'Columna Destino',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF121824) : Colors.grey.shade50,
                    ),
                    items: columnas.map((col) {
                      return DropdownMenuItem(value: col, child: Text(col, style: TextStyle(color: textoPrincipal)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => columnaSeleccionada = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  Text('Prioridad Inicial:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textoPrincipal)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _botonPrioridadModal(1, 'Baja', const Color(0xFF38A169), prioridadSeleccionada, (v) => setModalState(() => prioridadSeleccionada = v)),
                      _botonPrioridadModal(2, 'Media', const Color(0xFFED8936), prioridadSeleccionada, (v) => setModalState(() => prioridadSeleccionada = v)),
                      _botonPrioridadModal(3, 'Alta', const Color(0xFFE53E3E), prioridadSeleccionada, (v) => setModalState(() => prioridadSeleccionada = v)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF63D0A1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                      label: const Text('Publicar Tarea Ahora', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final sca = ScaffoldMessenger.of(context);
                        nav.pop();
                        try {
                          await _firestoreService.convertirBorradorATarea(
                            borrador: borrador,
                            columnaDestino: columnaSeleccionada,
                            prioridad: prioridadSeleccionada,
                          );

                          sca.showSnackBar(
                            SnackBar(
                              content: Text('¡Publicado con éxito en "$columnaSeleccionada"!'),
                              backgroundColor: const Color(0xFF63D0A1),
                            ),
                          );
                        } catch (e) {
                          sca.showSnackBar(
                            SnackBar(content: Text('Error al publicar tarea: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _botonPrioridadModal(int valor, String texto, Color color, int seleccionada, Function(int) onTap) {
    final theme = Theme.of(context);
    final activo = seleccionada == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(valor),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: activo ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: activo ? 2 : 1),
          ),
          alignment: Alignment.center,
          child: Text(
            texto,
            style: TextStyle(
              color: activo ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmarEliminacion(BorradorNota elemento) {
    final esNota = elemento.esNotaPersonal;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(esNota ? 'Eliminar Nota Personal' : 'Eliminar Borrador de Tarea'),
        content: Text('¿Deseas eliminar "${elemento.titulo}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _firestoreService.eliminarBorradorNota(elemento.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

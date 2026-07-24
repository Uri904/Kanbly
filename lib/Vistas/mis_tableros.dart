import 'package:flutter/material.dart';
import 'formulario_tablero.dart';
import 'encabezado.dart';
import 'menu_lateral.dart';
import 'kanban_board_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modelo/tablero.dart';
import '../servicios/firestore_service.dart';
import '../modelo/tarea.dart';

class MisTableros extends StatefulWidget {
  const MisTableros({super.key});

  @override
  State<MisTableros> createState() => _MisTablerosState();
}

class _MisTablerosState extends State<MisTableros> {
  // 1. DECLARACIÓN DE LA CLAVE GLOBAL:
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirestoreService _firestoreService = FirestoreService();
  List<Tablero> _tableros = [];
  bool _cargando = true;
  // Control de la pestaña activa: 0 = General, 1 = Individual, 2 = Equipo
  int _tabActiva = 0;
  Future<void> _cargarTableros() async {

    try {

      final uid = FirebaseAuth.instance.currentUser!.uid;

      final tableros =
      await _firestoreService.obtenerTablerosDeUsuario(uid);

      setState(() {
        _tableros = tableros;
        _cargando = false;
      });

    } catch (e) {

      print("ERROR REAL TABLEROS: $e");

      setState(() {
        _cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text("$e"),
        ),
      );

    }

  }
  @override
  void initState() {
    super.initState();

    _cargarTableros();
  }
  @override
  Widget build(BuildContext context) {
    // Colores oficiales basados estrictamente en tu paleta
    const Color blanco = Color(0xFFFCFDFD);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: blanco,

      // 3. BARRA SUPERIOR (APPBAR):
      appBar: Encabezado(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),

      ),
      // 4. MENÚ LATERAL (DRAWER):
      drawer: const MenuLateral(

      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // --- BARRA DE PESTAÑAS ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _crearBotonPestana(
                    index: 0,
                    titulo: 'Tableros\nen General',
                    icono: Icons.visibility_outlined,
                    colorActivo: const Color(0xFF52ABEB),
                  ),
                  const SizedBox(width: 8),
                  _crearBotonPestana(
                    index: 1,
                    titulo: 'Tableros\nIndividual',
                    icono: Icons.person_outline_rounded,
                    colorActivo: const Color(0xFF63D0A1),
                  ),
                  const SizedBox(width: 8),
                  _crearBotonPestana(
                    index: 2,
                    titulo: 'Tableros\nen Equipo',
                    icono: Icons.groups_outlined,
                    colorActivo: const Color(0xFF52ABEB),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- TÍTULO DE LA SECCIÓN ---
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Mis Tableros',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // --- ESPACIO DINÁMICO DE TABLEROS ---
          Expanded(
            child: _construirCuadriculaTableros(),
          ),
        ],
      ),

      // --- BOTÓN FLOTANTE COLOQUÉ AQUÍ EN EL SCAFFOLD ---
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarOpcionesCreacion(context),
        backgroundColor: const Color(0xFF63B09C),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  } // Cierre correcto de build

  // FUNCIÓN DEL BOTÓN ASISTENTE DE LAS PESTAÑAS
  Widget _crearBotonPestana({
    required int index,
    required String titulo,
    required IconData icono,
    required Color colorActivo,
  }) {
    final bool activa = _tabActiva == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tabActiva = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: activa ? colorActivo.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activa ? colorActivo : Colors.grey.shade300,
            width: activa ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              color: activa ? colorActivo : Colors.grey.shade600,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              titulo,
              style: TextStyle(
                color: activa ? colorActivo : Colors.grey.shade700,
                fontSize: 11,
                fontWeight: activa ? FontWeight.bold : FontWeight.w500,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Genera la cuadrícula con los 2 tableros de ejemplo
  Widget _construirCuadriculaTableros() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (_tableros.isEmpty) {
      return const Center(
        child: Text("No tienes tableros creados"),
      );
    }
    return RefreshIndicator(
        onRefresh: _cargarTableros,
        child: GridView.builder(      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _tableros.length,
      itemBuilder: (context, index) {
        return _crearTarjetaTablero(_tableros[index]);
      },
        ),
    );
  }

  // Maqueta el diseño visual de cada tarjeta individual
  Widget _crearTarjetaTablero(Tablero tablero) {
    final Color colorTipo =
    tablero.esGrupal
        ? const Color(0xFF52ABEB)
        : const Color(0xFF63D0A1);
    return GestureDetector(
      onTap: () {
        _abrirTableroCompleto(tablero);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorTipo.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [

                        Expanded(
                          child: Text(
                            tablero.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),

                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.grey,
                            size: 20,
                          ),

                          onSelected: (valor) {

                            if (valor == 'editar') {
                              _editarTablero(tablero);
                            }

                            if (valor == 'eliminar') {
                              _confirmarEliminar(tablero);
                            }

                          },

                          itemBuilder: (context) => [

                            const PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar'),
                            ),

                            const PopupMenuItem(
                              value: 'eliminar',
                              child: Text(
                                'Eliminar',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),

                          ],
                        ),

                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tablero.esGrupal? 'Equipo' : 'Individual',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const Spacer(),
                    Icon(
                      tablero.esGrupal ? Icons.groups_rounded : Icons.person_outline_rounded,
                      color: colorTipo,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            // --- PIE DE TARJETA CON CONTADORES DINÁMICOS EN TIEMPO REAL ---
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              // Conectamos al stream de tareas de este tablero específico
              child: StreamBuilder<List<Tarea>>(
                stream: _firestoreService.streamTareasDeTablero(tablero.id),
                builder: (context, snapshot) {
                  final tareas = snapshot.data ?? [];

                  // Contamos cuántas tareas hay en cada columna
                  final porHacer = tareas.where((t) => t.estado == EstadoTarea.pendiente).length;
                  final enProgreso = tareas.where((t) => t.estado == EstadoTarea.enProgreso).length;
                  final hecho = tareas.where((t) => t.estado == EstadoTarea.completada).length;

                  return Row(
                    children: [
                      _crearBloqueEstado(valor: porHacer, etiqueta: 'Por hacer', fondo: const Color(0xFF1E293B)),
                      _crearBloqueEstado(valor: enProgreso, etiqueta: 'En progreso', fondo: const Color(0xFF63B09C)),
                      _crearBloqueEstado(valor: hecho, etiqueta: 'Hecho', fondo: const Color(0xFF63D0A1), ultimo: true),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bloques numéricos del pie de la tarjeta
  Widget _crearBloqueEstado({required int valor, required String etiqueta, required Color fondo, bool ultimo = false}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: ultimo ? const BorderRadius.only(bottomRight: Radius.circular(14)) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$valor',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, height: 1.1),
            ),
            Text(
              etiqueta,
              style: const TextStyle(color: Colors.white70, fontSize: 7),
            ),
          ],
        ),
      ),
    );
  }

// Función encargada de gestionar la transición al tablero seleccionado
  void _abrirTableroCompleto(Tablero tablero) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KanbanBoardWidget(tablero: tablero),
      ),
    );
    _cargarTableros(); // Recargamos por si hubo cambios en los nombres al volver
  }
  // Muestra el menú inferior para elegir si el tablero será Individual o en Equipo
  void _mostrarOpcionesCreacion(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Crear Nuevo Tablero',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Selecciona el tipo de tablero que deseas maquetar:',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF63D0A1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: Color(0xFF63D0A1)),
                ),
                title: const Text('Tablero Individual', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Para organizar tus tareas personales de forma privada.'),
                onTap: () {
                  Navigator.pop(context);
                  _redirigirAFormulario(esGrupal: false);
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF52ABEB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.groups_outlined, color: Color(0xFF52ABEB)),
                ),
                title: const Text('Tablero en Equipo', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Colabora con otros miembros en tiempo real.'),
                onTap: () {
                  Navigator.pop(context);
                  _redirigirAFormulario(esGrupal: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Simulación de navegación hacia el formulario
  // Navegación real hacia el formulario unificado pasando el parámetro correspondiente
  void _redirigirAFormulario({required bool esGrupal}) async {

    final creado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormularioTablero(esGrupal: esGrupal),
      ),
    );

      _cargarTableros();

  }
  Future<void> _confirmarEliminar(Tablero tablero) async {

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {

        return AlertDialog(
          title: const Text("Eliminar tablero"),
          content: Text(
              "¿Seguro que deseas eliminar '${tablero.nombre}'?"
          ),

          actions: [

            TextButton(
              onPressed: (){
                Navigator.pop(context, false);
              },
              child: const Text("Cancelar"),
            ),

            TextButton(
              onPressed: (){
                Navigator.pop(context, true);
              },
              child: const Text(
                "Eliminar",
                style: TextStyle(color: Colors.red),
              ),
            ),

          ],
        );

      },
    );


    if(confirmar == true){

      await _firestoreService.eliminarTablero(tablero.id);

      _cargarTableros();

    }

  }
  void _editarTablero(Tablero tablero) async {

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormularioTablero(
          esGrupal: tablero.esGrupal,
          tablero: tablero,
        ),
      ),
    );

    _cargarTableros();

  }
  /* Si eligió Individual:
  Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => FormularioTablero(esGrupal: false)),
  );

// Si eligió En Equipo:
  Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => FormularioTablero(esGrupal: true)),
  ); */
} // Cierre final definitivo de la clase _MisTablerosState
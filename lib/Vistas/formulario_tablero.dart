import 'package:flutter/material.dart';
import '../servicios/firestore_service.dart';
import '../modelo/tablero.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modelo/usuario.dart';

class FormularioTablero extends StatefulWidget {
  final bool esGrupal;
  final Tablero? tablero;


  const FormularioTablero({super.key, required this.esGrupal, this.tablero,
  });

  @override
  State<FormularioTablero> createState() => _FormularioTableroState();
}

class _FormularioTableroState extends State<FormularioTablero> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _buscarController = TextEditingController();
  List<Usuario> _miembrosSeleccionados = [];
  String _fechaActualizacion = 'Sin actualizar';

  // Módulos del tablero
  bool _tieneCalendario = true;
  bool _tieneNotas = true;
  bool _tieneRecordatorios = true;

  // Colores (se definen sin const para permitir el uso de .withOpacity)
  Color blanco = const Color(0xFFFCFDFD);
  Color azulCielo = const Color(0xFF52ABEB);
  Color verdeTurquesa = const Color(0xFF63D0A1);
  Color verdeAgua = const Color(0xFF63B09C);
  Color grisOscuro = const Color(0xFF1E293B);

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _buscarController.dispose();
    super.dispose();
  }
  @override
  void initState() {
    super.initState();

    if (widget.tablero != null) {
      _nombreController.text = widget.tablero!.nombre;
      _descripcionController.text = widget.tablero!.descripcion ?? "";
      _tieneCalendario = widget.tablero!.tieneCalendario;
      _tieneNotas = widget.tablero!.tieneNotas;
      _tieneRecordatorios = widget.tablero!.tieneRecordatorios;

      if (widget.tablero!.fechaActualizacion != null) {
        _fechaActualizacion =
            widget.tablero!.fechaActualizacion!
                .toString()
                .substring(0, 16);
      }

      _cargarMiembros();
    }
  }
  @override
  Widget build(BuildContext context) {
    final Color colorTema = widget.esGrupal ? azulCielo : verdeTurquesa;

    return Scaffold(
      backgroundColor: blanco,
      appBar: AppBar(
        backgroundColor: blanco,
        elevation: 0,
        iconTheme: IconThemeData(color: colorTema),
        title: Text(
            widget.tablero != null
                ? 'Editar Tablero'
                : widget.esGrupal
                ? 'Nuevo Tablero Grupal'
                : 'Nuevo Tablero Individual',
          style: TextStyle(color: grisOscuro, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          children: [
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: colorTema.withOpacity(0.1),
                child: Icon(
                  widget.esGrupal ? Icons.groups_rounded : Icons.person_outline_rounded,
                  color: colorTema,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // --- NOMBRE ---
            const Text('Nombre del Tablero *', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nombreController,
              decoration: _construirDecoracionInput(pista: 'Ej. Sprint 1...', icono: Icons.dashboard_outlined, colorFoco: colorTema),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: 24),

            // --- DESCRIPCIÓN ---
            const Text('Descripción (Opcional)', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descripcionController,
              maxLines: 3,
              decoration: _construirDecoracionInput(pista: '¿De qué trata este tablero?', icono: Icons.description_outlined, colorFoco: colorTema),
            ),
            const SizedBox(height: 24),

            // --- FECHAS (SOLO LECTURA) ---
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: DateTime.now().toString().substring(0, 10),
                    readOnly: true,
                    enabled: false,
                    decoration: _construirDecoracionInput(pista: '', icono: Icons.calendar_today_rounded, colorFoco: colorTema).copyWith(labelText: 'Creado el'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue:  _fechaActualizacion,
                    readOnly: true,
                    enabled: false,
                    decoration: _construirDecoracionInput(pista: '', icono: Icons.update_rounded, colorFoco: colorTema).copyWith(labelText: 'Actualizado'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- MÓDULOS ADICIONALES ---
            const Text('Módulos Adicionales', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text('Calendario', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: const Text('Visualiza las tareas en formato mensual/semanal', style: TextStyle(fontSize: 12)),
                    secondary: Icon(Icons.calendar_month, color: colorTema),
                    value: _tieneCalendario,
                    activeColor: colorTema,
                    onChanged: (bool? value) {
                      setState(() {
                        _tieneCalendario = value ?? true;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    title: const Text('Notas para las tareas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: const Text('Añade descripciones, comentarios y anotaciones extras', style: TextStyle(fontSize: 12)),
                    secondary: Icon(Icons.note_alt_outlined, color: colorTema),
                    value: _tieneNotas,
                    activeColor: colorTema,
                    onChanged: (bool? value) {
                      setState(() {
                        _tieneNotas = value ?? true;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    title: const Text('Recordatorios', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: const Text('Recibe alertas y notificaciones de fechas de vencimiento', style: TextStyle(fontSize: 12)),
                    secondary: Icon(Icons.notifications_active_outlined, color: colorTema),
                    value: _tieneRecordatorios,
                    activeColor: colorTema,
                    onChanged: (bool? value) {
                      setState(() {
                        _tieneRecordatorios = value ?? true;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- MIEMBROS (SOLO SI ES GRUPAL) ---
            if (widget.esGrupal) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Miembros del Equipo', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 14)),
                  TextButton.icon(
                    onPressed: _agregarMiembro,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir'),
                  ),
                ],
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 60),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: _miembrosSeleccionados.isEmpty
                    ? const Center(
                  child: Text(
                    'No hay miembros añadidos aún.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _miembrosSeleccionados.length,
                  itemBuilder: (context, index) {
                    final usuario = _miembrosSeleccionados[index];

                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(usuario.nombreCompleto),
                      subtitle: Text('${usuario.email}\nRol Kanban: ${usuario.rol == "estudiante" ? "Programador / Desarrollador" : usuario.rol}'),
                      isThreeLine: true,

                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            _miembrosSeleccionados.removeWhere(
                                  (u) => u.id == usuario.id,
                            );
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],

            // --- BOTÓN GUARDAR ---
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: widget.esGrupal && _miembrosSeleccionados.isEmpty
                    ? null
                    : _guardarTablero,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorTema,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.tablero != null
                      ? 'Guardar Cambios'
                      : 'Crear Tablero',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _construirDecoracionInput({required String pista, required IconData icono, required Color colorFoco}) {
    return InputDecoration(
      hintText: pista,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: Icon(icono, color: Colors.grey.shade400, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorFoco, width: 1.8)),
    );
  }

  Future<void> _guardarTablero() async {
    if (_formKey.currentState!.validate()) {

      try {

        final uid = FirebaseAuth.instance.currentUser!.uid;

        final doc = FirebaseFirestore.instance
            .collection('tableros')
            .doc();

        final tablero = Tablero(
          id: widget.tablero?.id ?? doc.id,
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          esGrupal: widget.esGrupal,
          creadorId: widget.tablero?.creadorId ?? uid,

          miembrosIds: widget.tablero != null
              ? _miembrosSeleccionados.map((u) => u.id).toList()
              : [uid, ..._miembrosSeleccionados.map((u) => u.id)],

          fechaCreacion: widget.tablero?.fechaCreacion ?? DateTime.now(),
          tieneCalendario: _tieneCalendario,
          tieneNotas: _tieneNotas,
          tieneRecordatorios: _tieneRecordatorios,

          fechaActualizacion: widget.tablero != null
              ? DateTime.now()
              : null,
        );

        print("PASO 1: antes de guardar");

        if (widget.tablero == null) {

          await _firestoreService.crearTableroConId(tablero);

        } else {

          await _firestoreService.actualizarTablero(tablero);

        }
        print("PASO 2: después de guardar");

        if (!mounted) return;

        print("PASO 3: antes de regresar");

        Navigator.of(context).pop(true);

        print("PASO 4: después de regresar");

      } catch (e) {

        print("ERROR: $e");

      }
    }
  }
  Future<void> _agregarMiembro() async {
    final TextEditingController emailController = TextEditingController();
    final _dialogFormKey = GlobalKey<FormState>();
    String rolSeleccionado = 'Programador / Desarrollador';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Invitar Miembro por Correo"),
              content: SingleChildScrollView(
                child: Form(
                  key: _dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Correo Institucional:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          hintText: 'ejemplo@e.uttecamac.edu.mx',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa un correo';
                          }
                          if (!value.trim().endsWith('@e.uttecamac.edu.mx')) {
                            return 'Debe ser dominio @e.uttecamac.edu.mx';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Rol / Rol Kanban en el Tablero:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: rolSeleccionado,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Líder de Proyecto', child: Text('Líder de Proyecto')),
                          DropdownMenuItem(value: 'Programador / Desarrollador', child: Text('Programador / Desarrollador')),
                          DropdownMenuItem(value: 'Tester / QA', child: Text('Tester / QA')),
                          DropdownMenuItem(value: 'Diseñador UI/UX', child: Text('Diseñador UI/UX')),
                          DropdownMenuItem(value: 'Analista', child: Text('Analista')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              rolSeleccionado = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_dialogFormKey.currentState!.validate()) {
                      final email = emailController.text.trim();
                      
                      // Buscar usuario en Firestore por email
                      final usuario = await _firestoreService.obtenerUsuarioPorEmail(email);
                      
                      if (usuario == null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Usuario no encontrado en la base de datos')),
                        );
                        return;
                      }

                      // Asignar el rol seleccionado temporalmente para guardarlo o mostrarlo
                      // (Opcional, el usuario ya tiene un campo de rol por defecto)
                      final usuarioConRol = usuario.copyWith(rol: rolSeleccionado);

                      setState(() {
                        if (!_miembrosSeleccionados.any((u) => u.id == usuarioConRol.id)) {
                          _miembrosSeleccionados.add(usuarioConRol);
                        } else {
                          // Si ya existe, actualizamos su rol en la lista
                          int index = _miembrosSeleccionados.indexWhere((u) => u.id == usuarioConRol.id);
                          _miembrosSeleccionados[index] = usuarioConRol;
                        }
                      });

                      if (!context.mounted) return;
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Invitar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Future<void> _cargarMiembros() async {

    final ids = widget.tablero!.miembrosIds;

    List<Usuario> usuarios = [];

    for (String id in ids) {

      final usuario =
      await _firestoreService.obtenerUsuarioPorId(id);

      if(usuario != null){
        usuarios.add(usuario);
      }

    }

    setState(() {
      _miembrosSeleccionados = usuarios;
    });

  }
}
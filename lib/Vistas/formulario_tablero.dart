import 'package:flutter/material.dart';

class FormularioTablero extends StatefulWidget {
  final bool esGrupal;

  const FormularioTablero({super.key, required this.esGrupal});

  @override
  State<FormularioTablero> createState() => _FormularioTableroState();
}

class _FormularioTableroState extends State<FormularioTablero> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

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
    super.dispose();
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
          widget.esGrupal ? 'Nuevo Tablero Grupal' : 'Nuevo Tablero Individual',
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
                    initialValue: 'Sin actualizar',
                    readOnly: true,
                    enabled: false,
                    decoration: _construirDecoracionInput(pista: '', icono: Icons.update_rounded, colorFoco: colorTema).copyWith(labelText: 'Actualizado'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- MIEMBROS (SOLO SI ES GRUPAL) ---
            if (widget.esGrupal) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Miembros del Equipo', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 14)),
                  TextButton.icon(
                    onPressed: null, // Botón deshabilitado
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir'),
                  ),
                ],
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 60),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: const Center(child: Text('No hay miembros añadidos aún.', style: TextStyle(color: Colors.grey, fontSize: 12))),
              ),
              const SizedBox(height: 32),
            ],

            // --- BOTÓN GUARDAR ---
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _guardarTablero,
                style: ElevatedButton.styleFrom(backgroundColor: colorTema, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Crear Tablero', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _guardarTablero() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context);
    }
  }
}
import 'package:flutter/material.dart';

class Encabezado extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenuPressed;

  const Encabezado({super.key, required this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFFCFDFD),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Color(0xFF37B5F4)),
        onPressed: onMenuPressed,
      ),
// ... dentro de tu Widget build del Encabezado
      title: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            colors: [
              Color(0xFF52ABEB), // Azul (Inicio del degradado)
              Color(0xFF63D0A1), // Verde Turquesa (Fin del degradado)
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds);
        },
        child: const Text(
          'Kanbly',
          style: TextStyle(
            color: Colors.white, // El color aquí no importa, se aplica el degradado
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
      ),
      centerTitle: true,
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16.0),
          child: Center(
            child: Text(
              'Pece Pecas',
              style: TextStyle(
                color: Color(0xFF63B09C),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        )
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
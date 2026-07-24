import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mis_tableros.dart';
import 'login_view.dart';

class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos el usuario actual de Firebase para mostrar su información
    final usuarioActual = FirebaseAuth.instance.currentUser;
    final String correoUsuario = usuarioActual?.email ?? 'usuario@e.uttecamac.edu.mx';

    return Drawer(
      backgroundColor: const Color(0xFFFCFDFD),
      child: Column(
        children: [
          // --- ENCABEZADO CON DEGRADADO OFICIAL DE KANBLY ---
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF52ABEB), Color(0xFF63D0A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFF52ABEB),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kanbly',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    correoUsuario,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xDEFFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- OPCIÓN 1: MIS TABLEROS ---
          ListTile(
            leading: const Icon(Icons.dashboard_outlined, color: Color(0xFF37B5F4)),
            title: const Text(
              'Mis Tableros',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context); // Primero cerramos el menú lateral

              // Navegamos a Mis Tableros limpiando las pantallas superpuestas en memoria
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const MisTableros()),
                    (route) => false,
              );
            },
          ),

          const Divider(indent: 16, endIndent: 16),

          // --- EMPUJA LA OPCIÓN DE SALIR HASTA LA PARTE INFERIOR ---
          const Spacer(),
          const Divider(indent: 16, endIndent: 16),

          // --- OPCIÓN FINAL: CERRAR SESIÓN ---
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => _confirmarCerrarSesion(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Cuadro de diálogo para confirmar el cierre de sesión en Firebase
  void _confirmarCerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Se cerrará tu sesión actual en Kanbly.'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Cierra el diálogo de alerta
              Navigator.pop(context); // Cierra el menú lateral (Drawer)

              // 1. Cerramos la sesión activa en los servidores de Firebase
              await FirebaseAuth.instance.signOut();

              // 2. Redirigimos al Login eliminando todo el historial anterior de navegación
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginView()),
                      (route) => false,
                );
              }
            },
            child: const Text(
              'Salir',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
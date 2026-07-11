import 'package:flutter/material.dart';

class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFFCFDFD),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Aplicamos el degradado solo al DrawerHeader
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF52ABEB), Color(0xFF63D0A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Menú Kanbly',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined, color: Color(0xFF37B5F4)),
            title: const Text('Mis Tableros', style: TextStyle(color: Color(0xFF1E293B))),
            onTap: () => Navigator.pop(context),
          ),

        ],
      ),
    );
  }
}
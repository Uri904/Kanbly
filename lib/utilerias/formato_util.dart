import 'package:flutter/material.dart';
import '../modelo/usuario.dart';

class FormatoUtil {
  // 1. Convertir el entero de prioridad de la clase Tarea a los colores de Kanbly
  static Color obtenerColorPorPrioridad(int prioridad) {
    switch (prioridad) {
      case 3:
        return const Color(0xFF63D0A1); // Alta -> Verde Turquesa
      case 2:
        return const Color(0xFF37B5F4); // Media -> Azul Claro
      case 1:
        return const Color(0xFF63B09C); // Baja -> Verde Agua
      default:
        return const Color(0xFF37B5F4);
    }
  }

  // 2. Extraer iniciales de la clase Usuario para el avatar circular
  static String obtenerIniciales(Usuario? usuario) {
    if (usuario == null || usuario.nombreCompleto.isEmpty) {
      return 'NA'; // No asignado
    }
    final partes = usuario.nombreCompleto.trim().split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return usuario.nombreCompleto.substring(0, 1).toUpperCase();
  }
}
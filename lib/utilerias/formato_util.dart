import 'package:flutter/material.dart';
import '../modelo/usuario.dart';

class FormatoUtil {
  // 1. Convertir el entero de prioridad de la clase Tarea a los colores de Kanbly
  static Color obtenerColorPorPrioridad(int prioridad) {
    switch (prioridad) {
      case 3:
        return const Color(0xFFE53E3E); // Alta -> Rojo / Coral
      case 2:
        return const Color(0xFFED8936); // Media -> Naranja / Ámbar
      case 1:
        return const Color(0xFF38A169); // Baja -> Verde
      default:
        return const Color(0xFFED8936);
    }
  }

  // Texto legible para el nivel de importancia / prioridad
  static String obtenerTextoPrioridad(int prioridad) {
    switch (prioridad) {
      case 3:
        return 'Alta';
      case 2:
        return 'Media';
      case 1:
        return 'Baja';
      default:
        return 'Media';
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
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenciasController extends ChangeNotifier {
  static const String keyMostrarAnimacion = 'mostrar_animacion_inicio';

  bool _mostrarAnimacion = true;

  PreferenciasController({bool? initialMostrarAnimacion}) {
    if (initialMostrarAnimacion != null) {
      _mostrarAnimacion = initialMostrarAnimacion;
    } else {
      _cargarPreferencia();
    }
  }

  bool get mostrarAnimacion => _mostrarAnimacion;

  Future<void> _cargarPreferencia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mostrarAnimacion = prefs.getBool(keyMostrarAnimacion) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setMostrarAnimacion(bool value) async {
    _mostrarAnimacion = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyMostrarAnimacion, value);
    } catch (_) {}
  }
}

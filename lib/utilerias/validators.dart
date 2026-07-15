import 'package:email_validator/email_validator.dart';

class Validators {
  // Validar email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El correo electrónico es requerido';
    }
    if (!EmailValidator.validate(value)) {
      return 'Ingresa un correo electrónico válido';
    }
    return null;
  }

  // Validar email institucional (dominio @e.uttecamac.edu.mx)
  static String? validateInstitutionalEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El correo electrónico es requerido';
    }
    if (!EmailValidator.validate(value)) {
      return 'Ingresa un correo electrónico válido';
    }
    if (!value.endsWith('@e.uttecamac.edu.mx')) {
      return 'Solo se permiten correos institucionales @e.uttecamac.edu.mx';
    }
    return null;
  }

  // Validar contraseña
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
      return 'La contraseña debe tener letras y números';
    }
    return null;
  }

  // Validar nombre completo
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'El nombre es requerido';
    }
    if (value.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(value)) {
      return 'El nombre solo debe contener letras';
    }
    return null;
  }

  // Validar que las contraseñas coincidan
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }
    if (value != password) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  // Validar que no esté vacío
  static String? validateRequired(String? value, {String fieldName = 'Campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }
    return null;
  }

  // Validar longitud mínima
  static String? validateMinLength(String? value, int minLength, {String fieldName = 'Campo'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName es requerido';
    }
    if (value.length < minLength) {
      return '$fieldName debe tener al menos $minLength caracteres';
    }
    return null;
  }
}
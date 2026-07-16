import 'dart:convert';
import 'package:crypto/crypto.dart';

class EncryptionService {
  // Encriptar contraseña con SHA-256
  static String encryptPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Verificar contraseña encriptada
  static bool verifyPassword(String password, String encryptedHash) {
    final hashedPassword = encryptPassword(password);
    return hashedPassword == encryptedHash;
  }

  // Encriptar datos adicionales
  static String encryptData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Generar hash para verificación de integridad
  static String generateHash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Encriptar con salt para mayor seguridad
  static String encryptWithSalt(String data, String salt) {
    final saltedData = data + salt;
    final bytes = utf8.encode(saltedData);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
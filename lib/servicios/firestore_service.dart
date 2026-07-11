import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modelo/usuario.dart';
import '../modelo/tablero.dart';
import '../modelo/tarea.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== VALIDACIÓN DE DOMINIO ==========

  /// Valida que el email tenga el dominio institucional
  bool validarDominioInstitucional(String email) {
    final dominio = email.split('@').last;
    // Dominio institucional según el acta: @e.uttecamac.edu.mx
    return dominio == 'e.uttecamac.edu.mx';
  }

  // ========== USUARIOS ==========

  Future<void> crearUsuario(Usuario usuario) async {
    try {
      // Validar que el usuario tenga el dominio institucional
      if (!validarDominioInstitucional(usuario.email)) {
        throw Exception('Solo se permiten correos institucionales @e.uttecamac.edu.mx');
      }
      await _firestore.collection('usuarios').doc(usuario.id).set(usuario.toMap());
    } catch (e) {
      throw Exception('Error al crear usuario: $e');
    }
  }

  Future<Usuario?> obtenerUsuario(String userId) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(userId).get();
      if (doc.exists) {
        return Usuario.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener usuario: $e');
    }
  }

  Future<void> actualizarUsuario(Usuario usuario) async {
    try {
      await _firestore.collection('usuarios').doc(usuario.id).update(usuario.toMap());
    } catch (e) {
      throw Exception('Error al actualizar usuario: $e');
    }
  }

  // ========== TABLEROS ==========

  Future<String> crearTablero(Tablero tablero) async {
    try {
      final docRef = await _firestore.collection('tableros').add(tablero.toMap());

      // Actualizar el usuario para agregar el tablero a su lista
      final usuarioRef = _firestore.collection('usuarios').doc(tablero.creadorId);
      await usuarioRef.update({
        'tablerosIds': FieldValue.arrayUnion([docRef.id])
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear tablero: $e');
    }
  }

  Future<void> crearTableroConId(Tablero tablero) async {
    try {
      await _firestore.collection('tableros').doc(tablero.id).set(tablero.toMap());

      final usuarioRef = _firestore.collection('usuarios').doc(tablero.creadorId);
      await usuarioRef.update({
        'tablerosIds': FieldValue.arrayUnion([tablero.id])
      });
    } catch (e) {
      throw Exception('Error al crear tablero: $e');
    }
  }

  Future<List<Tablero>> obtenerTablerosDeUsuario(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('tableros')
          .where('miembrosIds', arrayContains: userId)
          .where('activo', isEqualTo: true)
          .orderBy('fechaCreacion', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Tablero.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener tableros: $e');
    }
  }

  Future<Tablero?> obtenerTablero(String tableroId) async {
    try {
      final doc = await _firestore.collection('tableros').doc(tableroId).get();
      if (doc.exists) {
        return Tablero.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener tablero: $e');
    }
  }

  Future<void> actualizarTablero(Tablero tablero) async {
    try {
      final data = tablero.toMap();
      data['fechaActualizacion'] = Timestamp.now();
      await _firestore.collection('tableros').doc(tablero.id).update(data);
    } catch (e) {
      throw Exception('Error al actualizar tablero: $e');
    }
  }

  Future<void> eliminarTablero(String tableroId) async {
    try {
      await _firestore.collection('tableros').doc(tableroId).update({
        'activo': false,
        'fechaActualizacion': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error al eliminar tablero: $e');
    }
  }

  // ========== TAREAS ==========

  Future<String> crearTarea(Tarea tarea) async {
    try {
      final docRef = await _firestore.collection('tareas').add(tarea.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear tarea: $e');
    }
  }

  Future<void> crearTareaConId(Tarea tarea) async {
    try {
      await _firestore.collection('tareas').doc(tarea.id).set(tarea.toMap());
    } catch (e) {
      throw Exception('Error al crear tarea: $e');
    }
  }

  Future<List<Tarea>> obtenerTareasDeTablero(String tableroId) async {
    try {
      final querySnapshot = await _firestore
          .collection('tareas')
          .where('tableroId', isEqualTo: tableroId)
          .where('archivada', isEqualTo: false)
          .orderBy('orden')
          .get();

      return querySnapshot.docs
          .map((doc) => Tarea.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener tareas: $e');
    }
  }

  // Obtener tareas por estado específico
  Future<List<Tarea>> obtenerTareasPorEstado(String tableroId, String estado) async {
    try {
      final querySnapshot = await _firestore
          .collection('tareas')
          .where('tableroId', isEqualTo: tableroId)
          .where('estado', isEqualTo: estado)
          .where('archivada', isEqualTo: false)
          .orderBy('orden')
          .get();

      return querySnapshot.docs
          .map((doc) => Tarea.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener tareas por estado: $e');
    }
  }

  Future<Tarea?> obtenerTarea(String tareaId) async {
    try {
      final doc = await _firestore.collection('tareas').doc(tareaId).get();
      if (doc.exists) {
        return Tarea.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener tarea: $e');
    }
  }

  Future<void> actualizarTarea(Tarea tarea) async {
    try {
      final data = tarea.toMap();
      data['fechaActualizacion'] = Timestamp.now();
      await _firestore.collection('tareas').doc(tarea.id).update(data);
    } catch (e) {
      throw Exception('Error al actualizar tarea: $e');
    }
  }

  Future<void> actualizarEstadoTarea(String tareaId, String nuevoEstado) async {
    try {
      await _firestore.collection('tareas').doc(tareaId).update({
        'estado': nuevoEstado,
        'fechaActualizacion': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error al actualizar estado de tarea: $e');
    }
  }

  // Método para reordenar tareas (para drag & drop)
  Future<void> reordenarTareas(String tableroId, List<String> tareasIds) async {
    try {
      final batch = _firestore.batch();
      for (var i = 0; i < tareasIds.length; i++) {
        final ref = _firestore.collection('tareas').doc(tareasIds[i]);
        batch.update(ref, {
          'orden': i,
          'fechaActualizacion': Timestamp.now(),
        });
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Error al reordenar tareas: $e');
    }
  }

  Future<void> eliminarTarea(String tareaId) async {
    try {
      await _firestore.collection('tareas').doc(tareaId).update({
        'archivada': true,
        'fechaActualizacion': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error al eliminar tarea: $e');
    }
  }

  // ========== STREAMS (Realtime con patrón Observer) ==========

  Stream<List<Tarea>> streamTareasDeTablero(String tableroId) {
    return _firestore
        .collection('tareas')
        .where('tableroId', isEqualTo: tableroId)
        .where('archivada', isEqualTo: false)
        .orderBy('orden')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Tarea.fromMap(doc.id, doc.data()))
        .toList());
  }

  Stream<Tablero?> streamTablero(String tableroId) {
    return _firestore
        .collection('tableros')
        .doc(tableroId)
        .snapshots()
        .map((doc) => doc.exists ? Tablero.fromMap(doc.id, doc.data()!) : null);
  }

  Stream<List<Tablero>> streamTablerosDeUsuario(String userId) {
    return _firestore
        .collection('tableros')
        .where('miembrosIds', arrayContains: userId)
        .where('activo', isEqualTo: true)
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Tablero.fromMap(doc.id, doc.data()))
        .toList());
  }

  // ========== MÉTODOS PARA EL PATRÓN COMMAND ==========

  /// Guarda un comando en el historial para poder deshacer/rehacer
  Future<void> guardarComando(Map<String, dynamic> comando) async {
    try {
      await _firestore.collection('historial_comandos').add({
        'comando': comando,
        'timestamp': Timestamp.now(),
        'usuarioId': _auth.currentUser?.uid,
      });
    } catch (e) {
      print('Error al guardar comando: $e');
    }
  }

  // lib/services/firestore_service.dart

// ========== MÉTODOS PARA EL PATRÓN STRATEGY ==========

  /// Ordena tareas según la estrategia seleccionada
  Future<List<Tarea>> obtenerTareasOrdenadas(String tableroId, String criterio) async {
    try {
      Query query = _firestore
          .collection('tareas')
          .where('tableroId', isEqualTo: tableroId)
          .where('archivada', isEqualTo: false);

      // Aplicar estrategia de ordenamiento
      switch (criterio) {
        case 'prioridad':
          query = query.orderBy('prioridad', descending: true);
          break;
        case 'fechaVencimiento':
          query = query.orderBy('fechaVencimiento');
          break;
        case 'fechaCreacion':
        default:
          query = query.orderBy('fechaCreacion', descending: true);
          break;
      }

      final querySnapshot = await query.get();
      
      return querySnapshot.docs
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Tarea.fromMap(doc.id, data);
      })
          .toList();

    } catch (e) {
      throw Exception('Error al obtener tareas ordenadas: $e');
    }
  }
}
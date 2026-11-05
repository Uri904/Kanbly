import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modelo/usuario.dart';
import '../modelo/tablero.dart';
import '../modelo/tarea.dart';
import '../modelo/invitacion.dart';
import '../modelo/borrador_nota.dart';
import 'notificacion_vencimiento_service.dart';

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
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await _firestore.collection('usuarios').doc(userId).get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        doc = await _firestore.collection('usuarios').doc(userId).get(const GetOptions(source: Source.cache));
      }
      if (doc.exists && doc.data() != null) {
        return Usuario.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        return Usuario(
          id: currentUser.uid,
          email: currentUser.email ?? '',
          nombreCompleto: currentUser.displayName ?? (currentUser.email != null ? currentUser.email!.split('@').first : 'Usuario Local'),
          fechaRegistro: DateTime.now(),
          emailVerificado: currentUser.emailVerified,
          rol: 'estudiante',
          tablerosIds: [],
          activo: true,
        );
      }
      return null;
    }
  }

  Future<void> actualizarUsuario(Usuario usuario) async {
    try {
      await _firestore.collection('usuarios').doc(usuario.id).set(usuario.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Error al actualizar usuario: $e');
    }
  }

  Future<void> eliminarUsuario(String userId) async {
    try {
      await _firestore.collection('usuarios').doc(userId).delete();
    } catch (e) {
      throw Exception('Error al eliminar usuario: $e');
    }
  }

  // ========== TABLEROS ==========
  Future<String> crearTablero(Tablero tablero) async {
    try {
      final docRef = await _firestore.collection('tableros').add(tablero.toMap());

      // Actualizar el usuario para agregar el tablero a su lista
      final usuarioRef = _firestore.collection('usuarios').doc(tablero.creadorId);
      await usuarioRef.set({
        'tablerosIds': FieldValue.arrayUnion([docRef.id])
      }, SetOptions(merge: true));

      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear tablero: $e');
    }
  }

  Future<void> crearTableroConId(Tablero tablero) async {
    try {

      // Crear tablero
      await _firestore
          .collection('tableros')
          .doc(tablero.id)
          .set(tablero.toMap());


      // Agregar tablero al usuario
      final usuarioRef =
      _firestore.collection('usuarios').doc(tablero.creadorId);

      await usuarioRef.set(
        {
          'tablerosIds': FieldValue.arrayUnion([tablero.id])
        },
        SetOptions(merge: true),
      );


    } catch (e) {
      throw Exception('Error al crear tablero: $e');
    }
  }
  Future<List<Usuario>> buscarUsuarios(String texto) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('usuarios')
            .where('email', isGreaterThanOrEqualTo: texto)
            .where('email', isLessThanOrEqualTo: '$texto\uf8ff')
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        snapshot = await _firestore
            .collection('usuarios')
            .where('email', isGreaterThanOrEqualTo: texto)
            .where('email', isLessThanOrEqualTo: '$texto\uf8ff')
            .get(const GetOptions(source: Source.cache));
      }

      return snapshot.docs
          .map((doc) => Usuario.fromMap(doc.id, doc.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }
  
  Future<Usuario?> obtenerUsuarioPorEmail(String email) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('usuarios')
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        snapshot = await _firestore
            .collection('usuarios')
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get(const GetOptions(source: Source.cache));
      }
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return Usuario.fromMap(doc.id, doc.data());
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<Usuario?> obtenerUsuarioPorId(String id) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await _firestore.collection('usuarios').doc(id).get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        doc = await _firestore.collection('usuarios').doc(id).get(const GetOptions(source: Source.cache));
      }

      if (doc.exists && doc.data() != null) {
        return Usuario.fromMap(
          doc.id,
          doc.data()!,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
  Future<List<Tablero>> obtenerTablerosDeUsuario(String userId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot;
      try {
        querySnapshot = await _firestore
            .collection('tableros')
            .where('miembrosIds', arrayContains: userId)
            .where('activo', isEqualTo: true)
            .orderBy('fechaCreacion', descending: true)
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        // Fallback a consulta en cache sin orderBy (por si falta indice local offline)
        querySnapshot = await _firestore
            .collection('tableros')
            .where('miembrosIds', arrayContains: userId)
            .where('activo', isEqualTo: true)
            .get(const GetOptions(source: Source.cache));
      }

      final docs = querySnapshot.docs
          .map((doc) => Tablero.fromMap(doc.id, doc.data()))
          .toList();
      docs.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
      return docs;
    } catch (e) {
      return [];
    }
  }

  Future<Tablero?> obtenerTablero(String tableroId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await _firestore.collection('tableros').doc(tableroId).get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        doc = await _firestore.collection('tableros').doc(tableroId).get(const GetOptions(source: Source.cache));
      }
      if (doc.exists && doc.data() != null) {
        return Tablero.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> actualizarTablero(Tablero tablero) async {
    try {
      final data = tablero.toMap();
      data['fechaActualizacion'] = Timestamp.now();
      await _firestore.collection('tableros').doc(tablero.id).set(data, SetOptions(merge: true));
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
    print('PRUEBA: ENTRE AL METODO CREAR TAREA 1');
    try {
      print('PRUEBA: entrando a crearTarea');

      final docRef = await _firestore
          .collection('tareas')
          .add(tarea.toMap());

      print('PRUEBA: tarea guardada con ID ${docRef.id}');

      final tareaConId = Tarea.fromMap(
        docRef.id,
        tarea.toMap(),
      );

      print('PRUEBA: llamando al servicio de notificaciones');

      await NotificacionVencimientoService.programar(tareaConId);

      print('PRUEBA: terminó la programación');

      return docRef.id;
    } catch (e, stackTrace) {
      print('ERROR al crear o programar la tarea: $e');
      print(stackTrace);
      rethrow;
    }
  }


  Future<void> crearTareaConId(Tarea tarea) async {
    try {
      await _firestore
          .collection('tareas')
          .doc(tarea.id)
          .set(tarea.toMap());

      try {
        await NotificacionVencimientoService.programar(tarea);
      } catch (e) {
        print('Error al programar notificación local: $e');
      }
    } catch (e, stackTrace) {
      print('ERROR al crear o programar la tarea: $e');
      print(stackTrace);
      rethrow;
    }
  }

  /// Crea un lote de tareas en Firestore de forma atómica usando WriteBatch.
  /// Programa notificaciones locales de vencimiento ÚNICAMENTE si el commit del batch fue exitoso (Ajuste 9).
  Future<void> crearTareasEnLote(List<Tarea> tareas) async {
    if (tareas.isEmpty) return;

    try {
      final batch = _firestore.batch();

      for (final tarea in tareas) {
        final docRef = _firestore.collection('tareas').doc(tarea.id);
        batch.set(docRef, tarea.toMap());
      }

      // 1. Ejecutar el commit del batch en Firestore
      await batch.commit();

      // 2. SOLO después de que el commit sea exitoso, programar notificaciones de vencimiento
      for (final tarea in tareas) {
        if (tarea.fechaVencimiento != null) {
          try {
            await NotificacionVencimientoService.programar(tarea);
          } catch (e) {
            print('Error al programar notificación para tarea ${tarea.id}: $e');
          }
        }
      }
    } catch (e) {
      throw Exception('Error al guardar las tareas en lote: $e');
    }
  }

  Future<List<Tarea>> obtenerTareasDeTablero(String tableroId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot;
      try {
        querySnapshot = await _firestore
            .collection('tareas')
            .where('tableroId', isEqualTo: tableroId)
            .where('archivada', isEqualTo: false)
            .orderBy('orden')
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        querySnapshot = await _firestore
            .collection('tareas')
            .where('tableroId', isEqualTo: tableroId)
            .where('archivada', isEqualTo: false)
            .get(const GetOptions(source: Source.cache));
      }

      final docs = querySnapshot.docs
          .map((doc) => Tarea.fromMap(doc.id, doc.data()))
          .toList();
      docs.sort((a, b) => a.orden.compareTo(b.orden));
      return docs;
    } catch (e) {
      return [];
    }
  }

  // Obtener tareas por estado específico
  Future<List<Tarea>> obtenerTareasPorEstado(String tableroId, String estado) async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot;
      try {
        querySnapshot = await _firestore
            .collection('tareas')
            .where('tableroId', isEqualTo: tableroId)
            .where('estado', isEqualTo: estado)
            .where('archivada', isEqualTo: false)
            .orderBy('orden')
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        querySnapshot = await _firestore
            .collection('tareas')
            .where('tableroId', isEqualTo: tableroId)
            .where('estado', isEqualTo: estado)
            .where('archivada', isEqualTo: false)
            .get(const GetOptions(source: Source.cache));
      }

      final docs = querySnapshot.docs
          .map((doc) => Tarea.fromMap(doc.id, doc.data()))
          .toList();
      docs.sort((a, b) => a.orden.compareTo(b.orden));
      return docs;
    } catch (e) {
      return [];
    }
  }

  Future<List<Tarea>> obtenerTareasCreadasPorUsuario(String userId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('tareas')
            .where('creadaPor', isEqualTo: userId)
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        snapshot = await _firestore
            .collection('tareas')
            .where('creadaPor', isEqualTo: userId)
            .get(const GetOptions(source: Source.cache));
      }

      return snapshot.docs
          .map((doc) => Tarea.fromMap(doc.id, doc.data()))
          .where((tarea) => !tarea.archivada)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Tarea?> obtenerTarea(String tareaId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await _firestore.collection('tareas').doc(tareaId).get(const GetOptions(source: Source.serverAndCache));
      } catch (_) {
        doc = await _firestore.collection('tareas').doc(tareaId).get(const GetOptions(source: Source.cache));
      }
      if (doc.exists && doc.data() != null) {
        return Tarea.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> actualizarTarea(Tarea tarea) async {
    try {
      final data = tarea.toMap();
      data['fechaActualizacion'] = Timestamp.now();

      await _firestore
          .collection('tareas')
          .doc(tarea.id)
          .set(data, SetOptions(merge: true));

      try {
        await NotificacionVencimientoService.programar(tarea);
      } catch (_) {}
    } catch (e) {
      throw Exception('Error al actualizar tarea: $e');
    }
  }

  Future<void> actualizarEstadoTarea(
      String tareaId,
      String nuevoEstado,
      ) async {
    try {
      await _firestore.collection('tareas').doc(tareaId).set({
        'estado': nuevoEstado,
        'fechaActualizacion': Timestamp.now(),
      }, SetOptions(merge: true));

      final tareaActualizada = await obtenerTarea(tareaId);

      if (tareaActualizada != null) {
        try {
          await NotificacionVencimientoService.programar(
            tareaActualizada,
          );
        } catch (_) {}
      }
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
      await _firestore.collection('tareas').doc(tareaId).set({
        'archivada': true,
        'fechaActualizacion': Timestamp.now(),
      }, SetOptions(merge: true));

      try {
        await NotificacionVencimientoService.cancelar(tareaId);
      } catch (_) {}
    } catch (e) {
      throw Exception('Error al eliminar tarea: $e');
    }
  }

  /// Agrega un comentario a una tarea en Firestore
  Future<void> agregarComentarioTarea({
    required String tareaId,
    required ComentarioTarea comentario,
  }) async {
    try {
      await _firestore.collection('tareas').doc(tareaId).update({
        'comentarios': FieldValue.arrayUnion([comentario.toMap()]),
        'fechaActualizacion': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error al agregar comentario: $e');
    }
  }

  /// Elimina un comentario de una tarea en Firestore
  Future<void> eliminarComentarioTarea({
    required String tareaId,
    required ComentarioTarea comentario,
  }) async {
    try {
      await _firestore.collection('tareas').doc(tareaId).update({
        'comentarios': FieldValue.arrayRemove([comentario.toMap()]),
        'fechaActualizacion': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error al eliminar comentario: $e');
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
  Future<void> crearInvitacion({
    required String tableroId,
    required String tableroNombre,
    required String invitadoId,
    required String invitadoEmail,
    required String invitadoPor,
    required String rol,
  }) async {
    await FirebaseFirestore.instance
        .collection('invitaciones')
        .add({
      'tableroId': tableroId,
      'tableroNombre': tableroNombre,
      'invitadoId': invitadoId,
      'invitadoEmail': invitadoEmail,
      'invitadoPor': invitadoPor,
      'rol': rol,
      'estado': 'pendiente',
      'fechaCreacion': FieldValue.serverTimestamp(),
    });
  }
  Stream<List<Invitacion>> obtenerMisInvitaciones(String uid) {
    return FirebaseFirestore.instance
        .collection('invitaciones')
        .where('invitadoId', isEqualTo: uid)
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Invitacion.fromMap(
          doc.id,
          doc.data(),
        );
      }).toList();
    });
  }

  Future<void> aceptarInvitacion(Invitacion invitacion) async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw Exception('Usuario no autenticado');
    }

    if (usuarioActual.uid != invitacion.invitadoId) {
      throw Exception('Esta invitación no pertenece a tu usuario');
    }

    try {
      final invitacionRef =
      _firestore.collection('invitaciones').doc(invitacion.id);

      final tableroRef =
      _firestore.collection('tableros').doc(invitacion.tableroId);

      await _firestore.runTransaction((transaction) async {
        // Leer ambos documentos antes de realizar cambios.
        final invitacionDoc = await transaction.get(invitacionRef);
        final tableroDoc = await transaction.get(tableroRef);

        if (!invitacionDoc.exists) {
          throw Exception('La invitación ya no existe');
        }

        if (!tableroDoc.exists) {
          throw Exception('El tablero ya no existe');
        }

        final datosInvitacion = invitacionDoc.data()!;

        if (datosInvitacion['invitadoId'] != usuarioActual.uid) {
          throw Exception('La invitación no corresponde a este usuario');
        }

        if (datosInvitacion['estado'] != 'pendiente') {
          throw Exception('Esta invitación ya fue respondida');
        }

        final datosTablero = tableroDoc.data()!;

        // Recuperar los roles y permisos que ya existen.
        final miembrosInfo = Map<String, dynamic>.from(
          datosTablero['miembrosInfo'] ?? {},
        );

        // Guardar el rol elegido al enviar la invitación.
        final miembro = MiembroTableroInfo(
          usuarioId: usuarioActual.uid,
          rolKanban: invitacion.rol,
          esAdmin: false,
          permisos: const PermisosMiembro(),
        );

        miembrosInfo[usuarioActual.uid] = miembro.toMap();

        // Incorporar al usuario y guardar su información.
        transaction.update(tableroRef, {
          'miembrosIds': FieldValue.arrayUnion([usuarioActual.uid]),
          'miembrosInfo': miembrosInfo,
        });

        // Marcar la invitación como aceptada.
        transaction.update(invitacionRef, {
          'estado': 'aceptada',
          'fechaRespuesta': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Error al aceptar invitación: $e');
    }
  }

  Future<void> rechazarInvitacion(String invitacionId) async {
    await FirebaseFirestore.instance
        .collection('invitaciones')
        .doc(invitacionId)
        .update({
      'estado': 'rechazada',
      'fechaRespuesta': FieldValue.serverTimestamp(),
    });
  }

  // ========== MÉTODOS PARA BORRADORES Y NOTAS PERSONALES ==========

  /// Escucha en tiempo real los borradores del usuario actual para un tablero específico
  Stream<List<BorradorNota>> escucharBorradoresNota(String usuarioId, String tableroId) {
    return _firestore
        .collection('borradores_notas')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('tableroId', isEqualTo: tableroId)
        .snapshots()
        .map((snapshot) {
      final lista = snapshot.docs.map((doc) {
        return BorradorNota.fromMap(doc.id, doc.data());
      }).toList();
      lista.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
      return lista;
    });
  }

  /// Escucha en tiempo real las notas personales vinculadas a una tarea específica
  Stream<List<BorradorNota>> escucharNotasDeTarea(String tareaId) {
    return _firestore
        .collection('borradores_notas')
        .where('tareaId', isEqualTo: tareaId)
        .snapshots()
        .map((snapshot) {
      final lista = snapshot.docs.map((doc) {
        return BorradorNota.fromMap(doc.id, doc.data());
      }).toList();
      lista.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
      return lista;
    });
  }

  /// Vincula una nota personal a una tarea del tablero
  Future<void> vincularNotaATarea({
    required String borradorId,
    required String tareaId,
    required String tareaTitulo,
  }) async {
    try {
      await _firestore.collection('borradores_notas').doc(borradorId).update({
        'tareaId': tareaId,
        'tareaTitulo': tareaTitulo,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al vincular nota a la tarea: $e');
    }
  }

  /// Desvincula una nota personal de su tarea asignada
  Future<void> desvincularNotaDeTarea(String borradorId) async {
    try {
      await _firestore.collection('borradores_notas').doc(borradorId).update({
        'tareaId': FieldValue.delete(),
        'tareaTitulo': FieldValue.delete(),
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al desvincular nota de la tarea: $e');
    }
  }

  /// Crea un nuevo borrador o nota personal
  Future<String> crearBorradorNota(BorradorNota borrador) async {
    try {
      final docRef = await _firestore.collection('borradores_notas').add(borrador.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear borrador: $e');
    }
  }

  /// Actualiza un borrador o nota personal existente
  Future<void> actualizarBorradorNota(BorradorNota borrador) async {
    try {
      final data = borrador.toMap();
      data['fechaActualizacion'] = FieldValue.serverTimestamp();
      await _firestore.collection('borradores_notas').doc(borrador.id).update(data);
    } catch (e) {
      throw Exception('Error al actualizar borrador: $e');
    }
  }

  /// Elimina un borrador o nota personal
  Future<void> eliminarBorradorNota(String borradorId) async {
    try {
      await _firestore.collection('borradores_notas').doc(borradorId).delete();
    } catch (e) {
      throw Exception('Error al eliminar borrador: $e');
    }
  }

  /// Convierte un borrador personal en una tarea oficial publicada en el tablero
  Future<Tarea> convertirBorradorATarea({
    required BorradorNota borrador,
    required String columnaDestino,
    int? prioridad,
  }) async {
    try {
      final tareaId = _firestore.collection('tareas').doc().id;
      final enumEstado = EstadoTareaExtension.fromString(columnaDestino);
      final prioridadFinal = prioridad ?? borrador.prioridad;

      final nuevaTarea = Tarea(
        id: tareaId,
        titulo: borrador.titulo,
        descripcion: borrador.contenido.isNotEmpty ? borrador.contenido : null,
        estado: enumEstado,
        estadoNombre: columnaDestino,
        orden: 0,
        tableroId: borrador.tableroId,
        asignadosA: borrador.asignadosA,
        fechaCreacion: DateTime.now(),
        prioridad: prioridadFinal,
        adjuntos: borrador.adjuntos,
        archivada: false,
        creadaPor: borrador.usuarioId,
      );

      await crearTareaConId(nuevaTarea);

      // Eliminar el borrador después de convertirlo con éxito
      await eliminarBorradorNota(borrador.id);

      return nuevaTarea;
    } catch (e) {
      throw Exception('Error al convertir borrador a tarea: $e');
    }
  }
}
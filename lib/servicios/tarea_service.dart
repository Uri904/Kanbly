import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelo/tarea.dart';

class TareaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Tarea>> obtenerTareasDelTablero(String tableroId) {
    return _firestore
        .collection('tareas')
        .where('tableroId', isEqualTo: tableroId)
        .where('archivada', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Tarea.fromMap(doc.id, doc.data());
      }).toList();
    });
  }
}
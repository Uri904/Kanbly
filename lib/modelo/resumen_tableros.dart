import 'package:flutter/foundation.dart';

import 'tablero.dart';
import 'tarea.dart';
import '../utilerias/kanban_utils.dart';

enum RolEnTablero { creador, administrador, miembro }

/// Datos de un tablero vistos desde la cuenta que consulta su perfil.
@immutable
class InfoTableroUsuario {
  const InfoTableroUsuario({
    required this.id,
    required this.nombre,
    required this.esGrupal,
    required this.rol,
    required this.rolKanban,
    required this.numeroMiembros,
    required this.fechaCreacion,
  });

  final String id;
  final String nombre;
  final bool esGrupal;
  final RolEnTablero rol;
  final String rolKanban;
  final int numeroMiembros;
  final DateTime fechaCreacion;

  String get etiquetaRol => switch (rol) {
    RolEnTablero.creador => 'Creador',
    RolEnTablero.administrador => 'Administrador',
    RolEnTablero.miembro => 'Miembro',
  };
}

/// Conteo de tareas del tablero que fueron creadas por la persona actual.
///
/// No se cuenta como categoría de estado el total de tareas: el total se
/// deriva del conjunto y las categorías muestran únicamente el avance.
@immutable
class ResumenActividadTareas {
  const ResumenActividadTareas({
    required this.total,
    required this.completadas,
    required this.abiertas,
    required this.vencidas,
    this.proximaEntrega,
  });

  final int total;
  final int completadas;
  final int abiertas;
  final int vencidas;
  final Tarea? proximaEntrega;

  double get avance => total == 0 ? 0 : completadas / total;

  factory ResumenActividadTareas.desde(
      List<Tarea> tareas, {
        List<Tablero> tableros = const [],
        DateTime? ahora,
      }) {
    final momento = ahora ?? DateTime.now();
    final columnasPorTablero = {
      for (final tablero in tableros) tablero.id: tablero.columnas,
    };
    bool estaCompletada(Tarea tarea) => KanbanUtils.esTareaCompletada(
      tarea,
      columnasPorTablero[tarea.tableroId] ?? const [],
    );

    final activas = tareas.where((tarea) => !tarea.archivada).toList();
    final completadas = activas.where(estaCompletada).length;
    final tareasConFecha =
    activas
        .where(
          (tarea) =>
      !estaCompletada(tarea) && tarea.fechaVencimiento != null,
    )
        .toList()
      ..sort((a, b) => a.fechaVencimiento!.compareTo(b.fechaVencimiento!));

    final vencidas = tareasConFecha
        .where((tarea) => tarea.fechaVencimiento!.isBefore(momento))
        .length;
    final futuras = tareasConFecha
        .where((tarea) => !tarea.fechaVencimiento!.isBefore(momento))
        .toList();
    final proxima = futuras.isEmpty ? null : futuras.first;

    return ResumenActividadTareas(
      total: activas.length,
      completadas: completadas,
      abiertas: activas.length - completadas,
      vencidas: vencidas,
      proximaEntrega: proxima,
    );
  }
}

/// Resumen global de los tableros a los que pertenece una cuenta.
@immutable
class ResumenTableros {
  const ResumenTableros({
    required this.tableros,
    required this.individuales,
    required this.equipo,
    required this.comoCreador,
    required this.comoAdministrador,
    required this.comoMiembro,
    required this.colaboradores,
  });

  final List<InfoTableroUsuario> tableros;
  final int individuales;
  final int equipo;
  final int comoCreador;
  final int comoAdministrador;
  final int comoMiembro;
  final int colaboradores;

  int get total => tableros.length;
  bool get vacio => tableros.isEmpty;

  factory ResumenTableros.desde(List<Tablero> tableros, String uid) {
    final infos = tableros.map((tablero) {
      final rol = tablero.esCreador(uid)
          ? RolEnTablero.creador
          : tablero.esAdminOCreador(uid)
          ? RolEnTablero.administrador
          : RolEnTablero.miembro;
      final idsMiembros = tablero.miembrosIds.toSet()..add(tablero.creadorId);
      final cantidadMiembros = tablero.esGrupal ? idsMiembros.length : 1;

      return InfoTableroUsuario(
        id: tablero.id,
        nombre: tablero.nombre,
        esGrupal: tablero.esGrupal,
        rol: rol,
        rolKanban: tablero.esGrupal
            ? tablero.miembrosInfo[uid]?.rolKanban ?? ''
            : '',
        numeroMiembros: cantidadMiembros,
        fechaCreacion: tablero.fechaCreacion,
      );
    }).toList()..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));

    final colaboradores = <String>{};
    for (final tablero in tableros.where((tablero) => tablero.esGrupal)) {
      colaboradores
        ..addAll(tablero.miembrosIds)
        ..add(tablero.creadorId);
    }
    colaboradores.remove(uid);

    int contarRol(RolEnTablero rol) =>
        infos.where((tablero) => tablero.rol == rol).length;

    return ResumenTableros(
      tableros: List.unmodifiable(infos),
      individuales: infos.where((tablero) => !tablero.esGrupal).length,
      equipo: infos.where((tablero) => tablero.esGrupal).length,
      comoCreador: contarRol(RolEnTablero.creador),
      comoAdministrador: contarRol(RolEnTablero.administrador),
      comoMiembro: contarRol(RolEnTablero.miembro),
      colaboradores: colaboradores.length,
    );
  }
}

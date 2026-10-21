import '../modelo/tarea.dart';

/// Utilería compartida para la lógica de columnas y estados del tablero Kanban.
abstract final class KanbanUtils {
  /// Comprueba de forma flexible si una [tarea] corresponde a la columna [colNombre]
  /// de acuerdo con la lista completa [todasLasColumnas] y su índice [colIndex].
  static bool correspondeAColumna(
    Tarea tarea,
    String colNombre,
    List<String> todasLasColumnas,
    int colIndex,
  ) {
    final colClean = colNombre.trim().toLowerCase();
    final estadoNombreClean = tarea.estadoNombre.trim().toLowerCase();
    final estadoValueClean = tarea.estado.value.trim().toLowerCase();

    // 1. Coincidencia directa ignorando mayúsculas/minúsculas y espacios
    if (estadoNombreClean == colClean || estadoValueClean == colClean) {
      return true;
    }

    // 2. Mapeo de sinónimos habituales
    final esPorHacer = (colClean == 'pendiente' || colClean == 'por hacer');
    final tareaEsPorHacer =
        (estadoNombreClean == 'pendiente' || estadoNombreClean == 'por hacer');
    if (esPorHacer && tareaEsPorHacer) return true;

    final esEnProgreso = (colClean == 'en progreso' ||
        colClean == 'en proceso' ||
        colClean == 'haciendo');
    final tareaEsEnProgreso = (estadoNombreClean == 'en progreso' ||
        estadoNombreClean == 'en proceso' ||
        estadoNombreClean == 'haciendo');
    if (esEnProgreso && tareaEsEnProgreso) return true;

    final esCompletada = (colClean == 'completada' ||
        colClean == 'completado' ||
        colClean == 'terminada' ||
        colClean == 'hecho');
    final tareaEsCompletada = (estadoNombreClean == 'completada' ||
        estadoNombreClean == 'completado' ||
        estadoNombreClean == 'terminada' ||
        estadoNombreClean == 'hecho');
    if (esCompletada && tareaEsCompletada) return true;

    // 3. Garantía Cero Pérdidas: si no coincide con NINGUNA columna existente en el tablero, la colocamos en la primera columna
    bool coincideConAlgunaOtra = false;
    for (final otraCol in todasLasColumnas) {
      final otraClean = otraCol.trim().toLowerCase();
      if (estadoNombreClean == otraClean || estadoValueClean == otraClean) {
        coincideConAlgunaOtra = true;
        break;
      }
      if ((otraClean == 'pendiente' || otraClean == 'por hacer') &&
          tareaEsPorHacer) {
        coincideConAlgunaOtra = true;
        break;
      }
      if ((otraClean == 'en progreso' ||
              otraClean == 'en proceso' ||
              otraClean == 'haciendo') &&
          tareaEsEnProgreso) {
        coincideConAlgunaOtra = true;
        break;
      }
      if ((otraClean == 'completada' ||
              otraClean == 'completado' ||
              otraClean == 'terminada' ||
              otraClean == 'hecho') &&
          tareaEsCompletada) {
        coincideConAlgunaOtra = true;
        break;
      }
    }

    if (!coincideConAlgunaOtra && colIndex == 0) {
      return true;
    }

    return false;
  }

  /// Indica si la [tarea] es considerada "completada" según el tablero y sus [columnasTablero].
  static bool esTareaCompletada(Tarea tarea, List<String> columnasTablero) {
    if (tarea.estado == EstadoTarea.completada) return true;
    if (columnasTablero.isNotEmpty) {
      for (int i = 0; i < columnasTablero.length; i++) {
        final col = columnasTablero[i];
        final colClean = col.trim().toLowerCase();
        final esColCompletada = (colClean == 'completada' ||
            colClean == 'completado' ||
            colClean == 'terminada' ||
            colClean == 'hecho');
        if (esColCompletada &&
            correspondeAColumna(tarea, col, columnasTablero, i)) {
          return true;
        }
      }
    }
    final estadoClean = tarea.estadoNombre.trim().toLowerCase();
    return (estadoClean == 'completada' ||
        estadoClean == 'completado' ||
        estadoClean == 'terminada' ||
        estadoClean == 'hecho');
  }
}

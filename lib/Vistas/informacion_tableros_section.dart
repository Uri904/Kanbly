import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../modelo/resumen_tableros.dart';

const Color _azulCielo = Color(0xFF52ABEB);
const Color _verdeTurquesa = Color(0xFF63D0A1);
const Color _verdeAgua = Color(0xFF63B09C);
const Color _grisOscuro = Color(0xFF1E293B);

Color _bordeTarjeta(bool isDark) =>
    isDark ? const Color(0xFF2D3748) : Colors.grey.shade200;

/// Resumen global. No duplica columnas, módulos ni conteos de cada tarjeta
/// individual: muestra la organización de los espacios y los roles de cuenta.
class InformacionTablerosSection extends StatelessWidget {
  const InformacionTablerosSection({super.key, required this.resumen});

  final ResumenTableros resumen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (resumen.vacio) {
      return _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(context, Icons.dashboard_outlined, 'Tus espacios'),
            const SizedBox(height: 10),
            Text(
              'Aún no participas en ningún tablero. Cuando crees uno o aceptes una invitación, aparecerá aquí.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titulo(context, Icons.dashboard_outlined, 'Tus espacios'),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricaTablero(
                etiqueta: 'Total',
                valor: resumen.total,
                color: _grisOscuro,
              ),
              const SizedBox(width: 8),
              _MetricaTablero(
                etiqueta: 'Individuales',
                valor: resumen.individuales,
                color: _verdeAgua,
              ),
              const SizedBox(width: 8),
              _MetricaTablero(
                etiqueta: 'En equipo',
                valor: resumen.equipo,
                color: _azulCielo,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Tu participación',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (resumen.comoCreador > 0)
                _ChipRol(
                  icono: Icons.star_outline_rounded,
                  texto: 'Creador en ${resumen.comoCreador}',
                  color: _verdeTurquesa,
                ),
              if (resumen.comoAdministrador > 0)
                _ChipRol(
                  icono: Icons.admin_panel_settings_outlined,
                  texto: 'Administrador en ${resumen.comoAdministrador}',
                  color: _azulCielo,
                ),
              if (resumen.comoMiembro > 0)
                _ChipRol(
                  icono: Icons.person_outline_rounded,
                  texto: 'Miembro en ${resumen.comoMiembro}',
                  color: _verdeAgua,
                ),
            ],
          ),
          if (resumen.equipo > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: _bordeTarjeta(isDark)),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.groups_outlined, size: 18, color: _azulCielo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    resumen.colaboradores == 0
                        ? 'Tus tableros de equipo todavía no tienen otros colaboradores.'
                        : 'Compartes tus tableros con ${resumen.colaboradores} ${resumen.colaboradores == 1 ? 'persona' : 'personas'} distintas.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Resumen de autoría global: evita repetir el desglose completo en cada
/// tarjeta de tablero, pero deja claro qué universo de tareas se está contando.
class ActividadTareasSection extends StatelessWidget {
  const ActividadTareasSection({super.key, required this.actividad});

  final ResumenActividadTareas actividad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final porcentaje = (actividad.avance * 100).round();
    final proxima = actividad.proximaEntrega;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titulo(context, Icons.task_alt_rounded, 'Tu actividad'),
          const SizedBox(height: 3),
          Text(
            'Tareas que creaste en tus tableros',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          if (actividad.total == 0)
            Text(
              'Todavía no has creado tareas. Cuando agregues una, verás aquí su avance.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${actividad.completadas}',
                  style: const TextStyle(
                    color: _verdeAgua,
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'de ${actividad.total} completadas',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const Spacer(),
                Text(
                  '$porcentaje%',
                  style: const TextStyle(
                    color: _verdeAgua,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: actividad.avance.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: isDark
                    ? const Color(0xFF2D3748)
                    : Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(_verdeTurquesa),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DatoActividad(
                  icono: Icons.radio_button_unchecked_rounded,
                  etiqueta: '${actividad.abiertas} abiertas',
                  color: _azulCielo,
                ),
                if (actividad.vencidas > 0)
                  _DatoActividad(
                    icono: Icons.warning_amber_rounded,
                    etiqueta: '${actividad.vencidas} vencidas',
                    color: Colors.deepOrange,
                  ),
              ],
            ),
            if (actividad.vencidas == 0 && proxima != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.event_outlined, size: 17, color: _verdeAgua),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Próxima fecha límite: ${proxima.titulo} · ${DateFormat('d MMM', 'es').format(proxima.fechaVencimiento!)}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Lista compacta. Los detalles operativos permanecen en la pantalla principal
/// de tableros, para que esta vista de perfil funcione como resumen personal.
class MisTablerosDetalle extends StatelessWidget {
  const MisTablerosDetalle({
    super.key,
    required this.resumen,
    this.onTapTablero,
  });

  final ResumenTableros resumen;
  final ValueChanged<InfoTableroUsuario>? onTapTablero;

  @override
  Widget build(BuildContext context) {
    if (resumen.vacio) {
      return _Panel(
        child: Text(
          'Tus tableros aparecerán aquí cuando crees uno o aceptes una invitación.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: resumen.tableros
          .map(
            (tablero) => _FilaTablero(
          tablero: tablero,
          onTap: onTapTablero == null ? null : () => onTapTablero!(tablero),
        ),
      )
          .toList(),
    );
  }
}

class _FilaTablero extends StatelessWidget {
  const _FilaTablero({required this.tablero, this.onTap});

  final InfoTableroUsuario tablero;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = tablero.esGrupal ? _azulCielo : _verdeTurquesa;
    final fecha = MaterialLocalizations.of(
      context,
    ).formatShortDate(tablero.fechaCreacion);

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accent.withOpacity(.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  tablero.esGrupal
                      ? Icons.groups_rounded
                      : Icons.person_outline_rounded,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tablero.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tablero.esGrupal ? 'Equipo' : 'Individual'} · ${tablero.etiquetaRol}${tablero.rolKanban.isNotEmpty ? ' · ${tablero.rolKanban}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                    if (tablero.esGrupal) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${tablero.numeroMiembros} ${tablero.numeroMiembros == 1 ? 'integrante' : 'integrantes'} · Creado $fecha',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricaTablero extends StatelessWidget {
  const _MetricaTablero({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final String etiqueta;
  final int valor;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$valor',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

class _ChipRol extends StatelessWidget {
  const _ChipRol({
    required this.icono,
    required this.texto,
    required this.color,
  });

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          texto,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _DatoActividad extends StatelessWidget {
  const _DatoActividad({
    required this.icono,
    required this.etiqueta,
    required this.color,
  });

  final IconData icono;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(.10),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          etiqueta,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _bordeTarjeta(theme.brightness == Brightness.dark),
        ),
      ),
      child: child,
    );
  }
}

Widget _titulo(BuildContext context, IconData icono, String texto) => Row(
  children: [
    Icon(icono, size: 18, color: _azulCielo),
    const SizedBox(width: 7),
    Expanded(
      child: Text(
        texto,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ],
);


import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../modelo/tarea.dart';

class NotificacionVencimientoService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static bool _inicializado = false;

  static Future<void> inicializar() async {
    if (_inicializado) return;

    tz_data.initializeTimeZones();

    final zona = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zona));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _inicializado = true;
  }

  static Future<void> programar(Tarea tarea) async {
    final fecha = tarea.fechaVencimiento;

    if (fecha == null ||
        tarea.archivada ||
        tarea.estado == EstadoTarea.completada) {
      await cancelar(tarea.id);
      return;
    }

    final ahora = tz.TZDateTime.now(tz.local);

    var recordatorio = tz.TZDateTime(
      tz.local,
      fecha.year,
      fecha.month,
      fecha.day,
      9,
    );

    // Si hoy ya pasaron las 9:00, avisar dentro de un minuto.
    if (!recordatorio.isAfter(ahora) &&
        fecha.year == ahora.year &&
        fecha.month == ahora.month &&
        fecha.day == ahora.day) {
      recordatorio = ahora.add(const Duration(minutes: 1));
    }

    // Si la fecha ya pasó, no programar un aviso atrasado.
    if (!recordatorio.isAfter(ahora)) {
      await cancelar(tarea.id);
      return;
    }
    print('ID tarea: ${tarea.id}');
    print('Fecha vencimiento: $fecha');
    print('Archivada: ${tarea.archivada}');
    print('Estado: ${tarea.estado}');
    print('Hora actual: ${tz.TZDateTime.now(tz.local)}');
    print('Recordatorio programado para: $recordatorio');
    await _plugin.zonedSchedule(
      tarea.id.hashCode,
      'Tarea por vencer hoy',
      'La tarea "${tarea.titulo}" vence hoy.',
      recordatorio,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'vencimientos_tareas',
          'Vencimientos de tareas',
          channelDescription: 'Recordatorios de tareas que vencen hoy',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

  }

  static Future<void> cancelar(String tareaId) async {
    await _plugin.cancel(tareaId.hashCode);
  }
}
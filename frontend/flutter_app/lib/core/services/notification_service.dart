import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:timezone/data/latest_all.dart" as tz;
import "package:timezone/timezone.dart" as tz;

import "../state/app_providers.dart";

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService(ref));

class ComidaPlanInfo {
  final String idPaciente;
  final String nombrePaciente;
  final int idMomento;
  final String momentoNombre;
  final String horaInicio;
  final String recetaNombre;
  final bool consumida;

  ComidaPlanInfo({
    required this.idPaciente,
    required this.nombrePaciente,
    required this.idMomento,
    required this.momentoNombre,
    required this.horaInicio,
    required this.recetaNombre,
    required this.consumida,
  });
}

class NotificationService {
  final Ref _ref;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  NotificationService(this._ref);

  static const String _channelId = "reuma_nutri_momentos_comida";
  static const String _channelName = "Recordatorios de Comida";
  static const String _channelDesc =
      "Alertas puntuales de horarios de comida para los pacientes del tutor";

  /// Inicializa el plugin de notificaciones locales y la base de datos de zonas horarias.
  Future<void> init() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint("Error inicializando zonas horarias: $e");
    }

    const androidSettings =
        AndroidInitializationSettings("@mipmap/ic_launcher");
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint("Notificación seleccionada con payload: ${response.payload}");
      },
    );

    // Crear el canal de alta prioridad para Android
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidPlugin.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  /// Solicita los permisos necesarios en Android (POST_NOTIFICATIONS y EXACT_ALARM).
  Future<bool> solicitarPermisos() async {
    if (!_initialized) await init();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return false;

    // Permiso en Android 13+ (POST_NOTIFICATIONS)
    final notifGranted =
        await androidPlugin.requestNotificationsPermission() ?? false;

    // Permiso de alarmas exactas en Android 12+
    try {
      await androidPlugin.requestExactAlarmsPermission();
    } catch (_) {}

    return notifGranted;
  }

  /// Sincroniza y programa las alertas de los momentos de comida del día de hoy.
  /// Agrupa inteligentemente las comidas si el tutor tiene a cargo múltiples pacientes
  /// que coinciden en el mismo horario de inicio.
  Future<void> sincronizarNotificacionesPlanHoy({
    List<Map<String, dynamic>>? pacientesInput,
  }) async {
    if (!_initialized) await init();

    try {
      final repo = _ref.read(supabaseCrudRepositoryProvider);

      // 1. Obtener la lista de pacientes asignados al tutor
      List<Map<String, dynamic>> pacientes = pacientesInput ?? [];
      if (pacientes.isEmpty) {
        pacientes = await repo.fetchMyPatients();
      }
      if (pacientes.isEmpty) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final List<ComidaPlanInfo> comidasDelDia = [];

      // 2. Para cada paciente, consultar su plan nutricional del día de hoy
      for (final p in pacientes) {
        final idPaciente = p["id"]?.toString();
        if (idPaciente == null) continue;

        final nombreCompleto =
            p["nombre_completo"]?.toString() ?? p["nombres"]?.toString() ?? "Paciente";
        final primerNombre = nombreCompleto.trim().split(" ").first;

        try {
          final items =
              await repo.fetchPlanItemsByPaciente(idPaciente, fecha: today);

          for (final item in items) {
            final consumida = item["consumida"] == true;
            // Si ya fue consumida, no requiere notificación
            if (consumida) continue;

            final horaInicio = item["momento_hora_inicio"]?.toString();
            final momentoNombre =
                item["momento_nombre"]?.toString() ?? "Momento de comida";
            final recetaNombre =
                item["receta_nombre"]?.toString() ?? "Comida programada";
            final idMomento = item["id_momento"] as int? ?? 1;

            if (horaInicio != null && horaInicio.isNotEmpty) {
              comidasDelDia.add(ComidaPlanInfo(
                idPaciente: idPaciente,
                nombrePaciente: primerNombre,
                idMomento: idMomento,
                momentoNombre: momentoNombre,
                horaInicio: horaInicio,
                recetaNombre: recetaNombre,
                consumida: consumida,
              ));
            }
          }
        } catch (err) {
          debugPrint("Error consultando plan para paciente $idPaciente: $err");
        }
      }

      if (comidasDelDia.isEmpty) return;

      // 3. Agrupar las comidas por (idMomento + horaInicio)
      final Map<String, List<ComidaPlanInfo>> agrupadas = {};
      for (final comida in comidasDelDia) {
        final key = "${comida.idMomento}_${comida.horaInicio}";
        agrupadas.putIfAbsent(key, () => []).add(comida);
      }

      // 4. Programar cada grupo
      for (final entry in agrupadas.entries) {
        final lista = entry.value;
        if (lista.isEmpty) continue;

        final first = lista.first;
        final horaParts = first.horaInicio.split(":");
        final hora = int.tryParse(horaParts[0]) ?? 0;
        final minuto = horaParts.length > 1 ? (int.tryParse(horaParts[1]) ?? 0) : 0;

        final scheduledDate = DateTime(
          today.year,
          today.month,
          today.day,
          hora,
          minuto,
        );

        // Si la hora ya pasó para el día de hoy, omitir
        if (scheduledDate.isBefore(now)) continue;

        // ID determinista de notificación para evitar duplicados
        // Cabe en un entero de 32 bits (< 2,147,483,647)
        final notifId = ((today.year * 1000 + today.month * 100 + today.day) %
                    100000) *
                10 +
            (first.idMomento % 10);

        String titulo;
        String cuerpo;

        if (lista.length == 1) {
          // Caso 1 paciente
          titulo = "🍽️ ¡Hora del ${first.momentoNombre}!";
          cuerpo =
              "Es momento de preparar para ${first.nombrePaciente}: ${first.recetaNombre}.";
        } else {
          // Caso múltiples pacientes en el mismo momento horario
          titulo = "🍽️ ${first.momentoNombre} familiar (${lista.length} pacientes)";
          final lineas = lista
              .map((c) => "• ${c.nombrePaciente}: ${c.recetaNombre}")
              .join("\n");
          cuerpo = "$lineas\n¡Es hora de comenzar la preparación!";
        }

        final androidDetails = AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            cuerpo,
            contentTitle: titulo,
            summaryText: lista.length > 1 ? "${lista.length} comidas" : null,
          ),
          playSound: true,
          enableVibration: true,
        );

        final notificationDetails = NotificationDetails(
          android: androidDetails,
        );

        try {
          final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);

          await _plugin.zonedSchedule(
            notifId,
            titulo,
            cuerpo,
            tzScheduled,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );

          debugPrint(
              "Notificación programada para las $hora:$minuto (ID: $notifId) - $titulo");
        } catch (e) {
          // Fallback en caso de restricciones de alarmas exactas en el dispositivo
          try {
            final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
            await _plugin.zonedSchedule(
              notifId,
              titulo,
              cuerpo,
              tzScheduled,
              notificationDetails,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
          } catch (e2) {
            debugPrint("Error programando notificación de comida: $e2");
          }
        }
      }
    } catch (e) {
      debugPrint("Error general sincronizando notificaciones de comida: $e");
    }
  }

  /// Cancela una notificación específica de un momento de comida si ya fue completada.
  Future<void> cancelarNotificacionMomento(int idMomento, DateTime fecha) async {
    final notifId = ((fecha.year * 1000 + fecha.month * 100 + fecha.day) %
                100000) *
            10 +
        (idMomento % 10);
    await _plugin.cancel(notifId);
  }

  /// Cancela todas las notificaciones pendientes (por ejemplo, al cerrar sesión).
  Future<void> cancelarTodasLasNotificaciones() async {
    await _plugin.cancelAll();
  }
}

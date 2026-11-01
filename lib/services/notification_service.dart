import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/medication.dart';
import 'storage_service.dart';

const String actionDrank = 'ACTION_DRANK';
const String actionSkip = 'ACTION_SKIP';

const String _medicationTakenAction = 'MEDICATION_TAKEN';
const String _medicationNotTakenAction = 'MEDICATION_NOT_TAKEN';

const String _channelId = 'water_reminders';
const String _medicationChannelId = 'medication_reminders';

const String _iosCategory = 'WATER_CATEGORY';
const String _medicationIosCategory = 'MEDICATION_CATEGORY';

const int glassMl = 250;
const int snoozeMinutes = 15;

const int _repeatBaseId = 100;
const int _oneOffBaseId = 200;

const int _medicationBaseId = 100000;

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  await NotificationService.handleResponse(response);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static final ValueNotifier<int> refresh = ValueNotifier<int>(0);

  static bool _tzReady = false;
  static bool _pluginReady = false;

  static const String _prefInterval = 'water_custom_interval';
  static const String _prefStart = 'water_custom_start';
  static const String _prefEnd = 'water_custom_end';
  static const String _prefSound = 'water_notification_sound';
  static const String _prefVibration = 'water_notification_vibration';
  static const String _prefPauseUntil = 'water_notification_pause_until';

  static Future<Map<String, dynamic>> getWaterSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await StorageService.loadProfile();
    return {
      'intervalMinutes':
          prefs.getInt(_prefInterval) ?? profile?.intervalMinutes ?? 60,
      'startMinutes': prefs.getInt(_prefStart) ?? profile?.wakeMinutes ?? 480,
      'endMinutes': prefs.getInt(_prefEnd) ?? profile?.sleepMinutes ?? 1320,
      'sound': prefs.getBool(_prefSound) ?? true,
      'vibration': prefs.getBool(_prefVibration) ?? true,
      'pauseUntil': prefs.getInt(_prefPauseUntil) ?? 0,
    };
  }

  static Future<void> saveWaterSettings({
    required int intervalMinutes,
    required int startMinutes,
    required int endMinutes,
    required bool sound,
    required bool vibration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefInterval, intervalMinutes);
    await prefs.setInt(_prefStart, startMinutes);
    await prefs.setInt(_prefEnd, endMinutes);
    await prefs.setBool(_prefSound, sound);
    await prefs.setBool(_prefVibration, vibration);
    await rescheduleSmart();
    refresh.value++;
  }

  static Future<void> pauseWaterReminders(Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _prefPauseUntil,
      DateTime.now().add(duration).millisecondsSinceEpoch,
    );
    await _ensurePlugin();
    await _cancelWaterNotifications();
    refresh.value++;
  }

  static Future<void> resumeWaterReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefPauseUntil, 0);
    await rescheduleSmart();
    refresh.value++;
  }

  static InitializationSettings get _initSettings => InitializationSettings(
    android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _iosCategory,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(actionDrank, "J'ai bu 💧"),
            DarwinNotificationAction.plain(actionSkip, 'Pas encore'),
          ],
        ),
        DarwinNotificationCategory(
          _medicationIosCategory,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(_medicationTakenAction, 'Pris'),
            DarwinNotificationAction.plain(
              _medicationNotTakenAction,
              'Pas encore',
            ),
          ],
        ),
      ],
    ),
  );

  // ---------------- INITIALISATION ----------------

  static Future<void> _ensureTimezone() async {
    if (_tzReady) return;

    tz_data.initializeTimeZones();

    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Casablanca'));
    }

    _tzReady = true;
  }

  static Future<void> _ensurePlugin() async {
    if (_pluginReady) return;

    await _plugin.initialize(_initSettings);

    _pluginReady = true;
  }

  static Future<void> init() async {
    if (kIsWeb) return;

    await _ensureTimezone();

    await _plugin.initialize(
      _initSettings,
      onDidReceiveNotificationResponse: handleResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _pluginReady = true;

    if (await isEnabled()) {
      await scheduleMedicationReminders();
    }
  }

  // ---------------- ACTIVATION / DESACTIVATION ----------------

  static Future<bool> isEnabled() async {
    return StorageService.areNotificationsEnabled();
  }

  static Future<void> setEnabled(bool enabled) async {
    if (kIsWeb) return;

    await StorageService.setNotificationsEnabled(enabled);

    if (!enabled) {
      await _ensurePlugin();
      await _plugin.cancelAll();

      refresh.value++;
      return;
    }

    await requestPermissions();
    await rescheduleSmart();
    await scheduleMedicationReminders();

    refresh.value++;
  }

  static Future<void> cancelAll() async {
    if (kIsWeb) return;

    await _ensurePlugin();
    await _plugin.cancelAll();

    refresh.value++;
  }

  // ---------------- ACTIONS DES NOTIFICATIONS ----------------

  static Future<void> handleResponse(NotificationResponse response) async {
    if (!await isEnabled()) return;

    final payload = response.payload ?? '';

    // Notification concernant un médicament.
    if (payload.startsWith('medication|')) {
      await _handleMedicationResponse(response, payload);
      return;
    }

    // Notification concernant l'hydratation.
    if (response.actionId == actionDrank) {
      await StorageService.addIntake(glassMl);

      final settings = await getWaterSettings();
      await rescheduleSmart(firstInMinutes: settings['intervalMinutes'] as int);
    } else if (response.actionId == actionSkip) {
      await rescheduleSmart(firstInMinutes: snoozeMinutes);
    }

    refresh.value++;
  }

  static Future<void> _handleMedicationResponse(
    NotificationResponse response,
    String payload,
  ) async {
    final parts = payload.split('|');

    if (parts.length != 3) return;

    final medicationId = parts[1];
    final scheduledMinute = int.tryParse(parts[2]);

    if (scheduledMinute == null ||
        scheduledMinute < 0 ||
        scheduledMinute >= 1440) {
      return;
    }

    String? status;

    if (response.actionId == _medicationTakenAction) {
      status = 'taken';
    } else if (response.actionId == _medicationNotTakenAction) {
      status = 'not_taken';
    }

    if (status == null) {
      // Un simple clic sur la notification ouvre l'application.
      return;
    }

    final medications = await StorageService.getMedications();

    Medication? medication;

    for (final item in medications) {
      if (item.id == medicationId) {
        medication = item;
        break;
      }
    }

    if (medication == null) return;

    final now = DateTime.now();

    final scheduledAt = DateTime(
      now.year,
      now.month,
      now.day,
      scheduledMinute ~/ 60,
      scheduledMinute % 60,
    );

    await StorageService.saveMedicationDoseLog(
      MedicationDoseLog(
        medicationId: medication.id,
        medicationName: medication.name,
        scheduledAt: scheduledAt,
        confirmedAt: now,
        status: status,
      ),
    );

    refresh.value++;
  }

  // ---------------- AUTORISATIONS ----------------

  static Future<void> requestPermissions() async {
    if (kIsWeb) return;

    await _ensurePlugin();

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // ---------------- NOTIFICATIONS EAU ----------------

  static Future<NotificationDetails> _details() async {
    final settings = await getWaterSettings();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        "Rappels d'eau",
        channelDescription: "Rappels pour vous aider à boire régulièrement",
        importance: Importance.high,
        priority: Priority.high,
        playSound: settings['sound'] as bool,
        enableVibration: settings['vibration'] as bool,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            actionDrank,
            "J'ai bu 💧",
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            actionSkip,
            'Pas encore',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(categoryIdentifier: _iosCategory),
    );
  }

  static String _fmt(int ml) {
    if (ml >= 1000) {
      return '${(ml / 1000).toStringAsFixed(2).replaceAll('.', ',')} L';
    }

    return '$ml ml';
  }

  // Annule uniquement les notifications d'eau.
  static Future<void> _cancelWaterNotifications() async {
    for (var id = _oneOffBaseId; id < _oneOffBaseId + 24; id++) {
      await _plugin.cancel(id);
    }

    for (var id = _repeatBaseId; id < _repeatBaseId + 24; id++) {
      await _plugin.cancel(id);
    }
  }

  // ---------------- RAPPELS INTELLIGENTS EAU ----------------

  static Future<void> rescheduleSmart({int? firstInMinutes}) async {
    if (kIsWeb) return;

    try {
      await _ensureTimezone();
      await _ensurePlugin();

      if (!await isEnabled()) {
        await _plugin.cancelAll();
        return;
      }

      final profile = await StorageService.loadProfile();

      if (profile == null) {
        await scheduleMedicationReminders();
        return;
      }

      final settings = await getWaterSettings();
      final pauseUntil = settings['pauseUntil'] as int;
      if (pauseUntil > DateTime.now().millisecondsSinceEpoch) {
        await _cancelWaterNotifications();
        await scheduleMedicationReminders();
        return;
      }

      final intervalSetting = settings['intervalMinutes'] as int;
      final startSetting = settings['startMinutes'] as int;
      final endSetting = settings['endMinutes'] as int;

      final intake = await StorageService.getTodayIntake();
      final remaining = profile.dailyGoalMl - intake;

      final now = tz.TZDateTime.now(tz.local);

      final todayMidnight = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
      );

      var base = todayMidnight;
      var nowMin = now.hour * 60 + now.minute;

      final wake = startSetting;
      var end = endSetting;

      if (end <= wake) {
        end += 1440;
      }

      if (end > 1440 && nowMin < end - 1440) {
        base = base.subtract(const Duration(days: 1));
        nowMin += 1440;
      }

      // Ne pas annuler les notifications des médicaments.
      await _cancelWaterNotifications();

      final times = <int>[];

      if (remaining > 0) {
        final needed = (remaining / glassMl).ceil();

        var interval = intervalSetting;
        int first;

        if (firstInMinutes != null) {
          first = nowMin + firstInMinutes;
        } else {
          first = wake;

          while (first <= nowMin + 2) {
            first += interval;
          }
        }

        if (first < wake) {
          first = wake;
        }

        final window = end - first;

        if (window >= 0) {
          if (window ~/ interval + 1 < needed) {
            interval = max(30, window ~/ needed);
          }

          for (
            var m = first;
            m <= end && times.length < needed + 2 && times.length < 24;
            m += interval
          ) {
            times.add(m);
          }
        }
      }

      var id = _oneOffBaseId;

      for (final t in times) {
        final at = base.add(Duration(minutes: t));

        if (!at.isAfter(now.add(const Duration(seconds: 30)))) {
          continue;
        }

        await _plugin.zonedSchedule(
          id++,
          'Il est temps de boire 💧',
          "Il vous reste ${_fmt(remaining)} aujourd'hui. "
              'Prenez un moment pour vous hydrater.',
          at,
          await _details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'reminder',
        );
      }

      final tomorrow = todayMidnight.add(const Duration(days: 1));

      var rid = _repeatBaseId;

      for (
        var m = wake;
        m <= end && rid < _repeatBaseId + 24;
        m += intervalSetting
      ) {
        await _plugin.zonedSchedule(
          rid++,
          'Il est temps de boire 💧',
          "Un verre d'eau maintenant ? 💧",
          tomorrow.add(Duration(minutes: m)),
          await _details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'reminder',
        );
      }

      await StorageService.setPlanDay(StorageService.dayKey(DateTime.now()));

      // Les notifications des médicaments restent actives.
      await scheduleMedicationReminders();
    } catch (e) {
      debugPrint('rescheduleSmart a échoué : $e');
    }
  }

  // ---------------- RAPPELS MEDICAMENTS ----------------

  static int _medicationNotificationId(String medicationId, int minute) {
    var hash = 0;

    for (final code in medicationId.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }

    return _medicationBaseId + ((hash + minute) % 1000000);
  }

  static NotificationDetails _medicationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _medicationChannelId,
        'Rappels de médicaments',
        channelDescription: 'Rappels aux horaires de vos médicaments',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            _medicationTakenAction,
            'Pris',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            _medicationNotTakenAction,
            'Pas encore',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        categoryIdentifier: _medicationIosCategory,
      ),
    );
  }

  static Future<void> scheduleMedicationReminders() async {
    if (kIsWeb) return;

    try {
      await _ensureTimezone();
      await _ensurePlugin();

      if (!await isEnabled()) return;

      // Annule uniquement les anciennes notifications de médicaments.
      final pending = await _plugin.pendingNotificationRequests();

      for (final notification in pending) {
        if (notification.id >= _medicationBaseId &&
            notification.id < _medicationBaseId + 1000000) {
          await _plugin.cancel(notification.id);
        }
      }

      final medications = await StorageService.getMedications();

      final now = tz.TZDateTime.now(tz.local);

      for (final medication in medications) {
        if (!medication.isActive) continue;

        for (final minute in medication.timesMinutes) {
          if (minute < 0 || minute >= 1440) continue;

          var scheduled = tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day,
            minute ~/ 60,
            minute % 60,
          );

          if (!scheduled.isAfter(now)) {
            scheduled = scheduled.add(const Duration(days: 1));
          }

          final id = _medicationNotificationId(medication.id, minute);

          await _plugin.zonedSchedule(
            id,
            'Rappel de médicament 💊',
            '${medication.name} : ${medication.prescribedDose}. '
                'C\'est l\'heure prévue.',
            scheduled,
            _medicationDetails(),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: 'medication|${medication.id}|$minute',
          );
        }
      }
    } catch (e) {
      debugPrint('scheduleMedicationReminders a échoué : $e');
    }
  }

  static Future<void> cancelMedicationReminders() async {
    if (kIsWeb) return;

    await _ensurePlugin();

    final pending = await _plugin.pendingNotificationRequests();

    for (final notification in pending) {
      if (notification.id >= _medicationBaseId &&
          notification.id < _medicationBaseId + 1000000) {
        await _plugin.cancel(notification.id);
      }
    }
  }

  // ---------------- PLANIFICATION QUOTIDIENNE ----------------

  static Future<void> ensureDailyPlan() async {
    if (kIsWeb) return;

    if (!await isEnabled()) {
      await cancelAll();
      return;
    }

    final settings = await getWaterSettings();
    final pauseUntil = settings['pauseUntil'] as int;
    if (pauseUntil > 0 && pauseUntil <= DateTime.now().millisecondsSinceEpoch) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefPauseUntil, 0);
      await rescheduleSmart();
      return;
    }

    final last = await StorageService.getPlanDay();

    if (last != StorageService.dayKey(DateTime.now())) {
      await rescheduleSmart();
    } else {
      await scheduleMedicationReminders();
    }
  }

  // ---------------- NOTIFICATION DE TEST ----------------

  static Future<void> showTest() async {
    if (kIsWeb) return;

    await _ensurePlugin();

    if (!await isEnabled()) {
      throw Exception('Activez les notifications avant de lancer le test.');
    }

    await requestPermissions();

    await _plugin.show(
      1,
      "Test : boire de l'eau 💧",
      "Votre application Water Reminder fonctionne correctement !",
      await _details(),
      payload: 'test',
    );
  }
}

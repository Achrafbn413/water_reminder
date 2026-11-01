import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'storage_service.dart';

const String actionDrank = 'ACTION_DRANK';
const String actionSkip = 'ACTION_SKIP';
const String _channelId = 'water_reminders';
const String _iosCategory = 'WATER_CATEGORY';
const int glassMl = 250;
const int snoozeMinutes = 15;
const int _repeatBaseId = 100;
const int _oneOffBaseId = 200;

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
      ],
    ),
  );

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
  }

  // --------------------------------------------------
  // ACTIVATION / DESACTIVATION
  // --------------------------------------------------

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
    refresh.value++;
  }

  static Future<void> cancelAll() async {
    if (kIsWeb) return;

    await _ensurePlugin();
    await _plugin.cancelAll();

    refresh.value++;
  }

  // --------------------------------------------------
  // ACTIONS DES NOTIFICATIONS
  // --------------------------------------------------

  static Future<void> handleResponse(NotificationResponse response) async {
    if (!await isEnabled()) return;

    if (response.actionId == actionDrank) {
      await StorageService.addIntake(glassMl);

      final profile = await StorageService.loadProfile();

      await rescheduleSmart(firstInMinutes: profile?.intervalMinutes ?? 120);
    } else if (response.actionId == actionSkip) {
      await rescheduleSmart(firstInMinutes: snoozeMinutes);
    }

    refresh.value++;
  }

  // --------------------------------------------------
  // AUTORISATIONS
  // --------------------------------------------------

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

  // --------------------------------------------------
  // CONFIGURATION VISUELLE DES NOTIFICATIONS
  // --------------------------------------------------

  static NotificationDetails _details() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        "Rappels d'eau",
        channelDescription: "Rappels pour vous aider à boire régulièrement",
        importance: Importance.high,
        priority: Priority.high,
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

  // --------------------------------------------------
  // RAPPELS INTELLIGENTS
  // --------------------------------------------------

  static Future<void> rescheduleSmart({int? firstInMinutes}) async {
    if (kIsWeb) return;

    try {
      await _ensureTimezone();
      await _ensurePlugin();

      // Si les notifications sont désactivées,
      // aucun rappel ne doit rester programmé.
      if (!await isEnabled()) {
        await _plugin.cancelAll();
        return;
      }

      final profile = await StorageService.loadProfile();

      if (profile == null) return;

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

      final wake = profile.wakeMinutes;
      var end = profile.sleepMinutes;

      if (end <= wake) {
        end += 1440;
      }

      if (end > 1440 && nowMin < end - 1440) {
        base = base.subtract(const Duration(days: 1));
        nowMin += 1440;
      }

      await _plugin.cancelAll();

      // Rappels du jour.
      final times = <int>[];

      if (remaining > 0) {
        final needed = (remaining / glassMl).ceil();

        var interval = profile.intervalMinutes;
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
          _details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'reminder',
        );
      }

      // Rappels quotidiens à partir de demain.
      final tomorrow = todayMidnight.add(const Duration(days: 1));

      var rid = _repeatBaseId;

      for (
        var m = wake;
        m <= end && rid < _repeatBaseId + 24;
        m += profile.intervalMinutes
      ) {
        await _plugin.zonedSchedule(
          rid++,
          'Il est temps de boire 💧',
          "Un verre d'eau maintenant ? 💧",
          tomorrow.add(Duration(minutes: m)),
          _details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'reminder',
        );
      }

      await StorageService.setPlanDay(StorageService.dayKey(DateTime.now()));
    } catch (e) {
      debugPrint('rescheduleSmart a échoué : $e');
    }
  }

  // --------------------------------------------------
  // PLANIFICATION QUOTIDIENNE
  // --------------------------------------------------

  static Future<void> ensureDailyPlan() async {
    if (kIsWeb) return;

    if (!await isEnabled()) {
      await cancelAll();
      return;
    }

    final last = await StorageService.getPlanDay();

    if (last != StorageService.dayKey(DateTime.now())) {
      await rescheduleSmart();
    }
  }

  // --------------------------------------------------
  // NOTIFICATION DE TEST
  // --------------------------------------------------

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
      _details(),
      payload: 'test',
    );
  }
}

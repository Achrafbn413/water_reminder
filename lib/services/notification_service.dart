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
const int _repeatBaseId = 100; // rappels quotidiens (à partir de demain)
const int _oneOffBaseId = 200; // rappels intelligents d'aujourd'hui

/// Appelée quand l'utilisateur appuie sur un bouton alors que l'app est fermée.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  await NotificationService.handleResponse(response);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Permet à l'écran d'accueil de se rafraîchir après une action.
  static final ValueNotifier<int> refresh = ValueNotifier<int>(0);

  // Ces drapeaux sont propres à chaque "isolate" (app ou arrière-plan).
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

  /// Utilisé dans l'isolate d'arrière-plan (sans les callbacks).
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

  static Future<void> handleResponse(NotificationResponse response) async {
    if (response.actionId == actionDrank) {
      await StorageService.addIntake(glassMl);
      final profile = await StorageService.loadProfile();
      await rescheduleSmart(firstInMinutes: profile?.intervalMinutes ?? 120);
    } else if (response.actionId == actionSkip) {
      await rescheduleSmart(firstInMinutes: snoozeMinutes);
    }
    refresh.value++;
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) return;
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

  static NotificationDetails _details() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        "Rappels d'eau",
        channelDescription: "Rappels pour boire de l'eau",
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

  /// Replanifie les rappels selon ce qu'il reste à boire aujourd'hui.
  /// [firstInMinutes] : délai avant le prochain rappel (après un ajout ou
  /// "Pas encore"). Sinon, on suit la grille réveil + n x intervalle.
  static Future<void> rescheduleSmart({int? firstInMinutes}) async {
    if (kIsWeb) return;
    try {
      final profile = await StorageService.loadProfile();
      if (profile == null) return;
      await _ensureTimezone();
      await _ensurePlugin();

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
      if (end <= wake) end += 1440; // coucher après minuit
      if (end > 1440 && nowMin < end - 1440) {
        // On est encore dans la nuit de la journée précédente.
        base = base.subtract(const Duration(days: 1));
        nowMin += 1440;
      }

      await _plugin.cancelAll();

      // 1) Rappels d'aujourd'hui, adaptés à ce qu'il reste à boire.
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
        if (first < wake) first = wake;

        final window = end - first;
        if (window >= 0) {
          // En retard : on resserre les rappels (minimum 30 min).
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
        if (!at.isAfter(now.add(const Duration(seconds: 30)))) continue;
        await _plugin.zonedSchedule(
          id++,
          'Il est temps de boire 💧',
          "Il vous reste ${_fmt(remaining)} aujourd'hui. Répondez directement ici.",
          at,
          _details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'reminder',
        );
      }

      // 2) Jours suivants : rappels quotidiens répétés à partir de demain.
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
          "Un verre d'eau maintenant ? Répondez directement ici.",
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

  /// Replanifie une seule fois par jour (au premier lancement de la journée).
  static Future<void> ensureDailyPlan() async {
    if (kIsWeb) return;
    final last = await StorageService.getPlanDay();
    if (last != StorageService.dayKey(DateTime.now())) {
      await rescheduleSmart();
    }
  }

  /// Notification immédiate pour tester les boutons.
  static Future<void> showTest() async {
    if (kIsWeb) return;
    await _plugin.show(
      1,
      "Test : boire de l'eau 💧",
      "Appuyez sur « J'ai bu » pour tester.",
      _details(),
      payload: 'test',
    );
  }
}

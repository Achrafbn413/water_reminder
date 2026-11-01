import 'package:shared_preferences/shared_preferences.dart';

import '../models/history.dart';
import '../models/user_profile.dart';

class StorageService {
  static const _profileKey = 'profile';
  static const _planDayKey = 'plan_day';

  static String dayKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static String _intakeKey(DateTime d) => 'intake_${dayKey(d)}';
  static String _goalKey(DateTime d) => 'goal_${dayKey(d)}';
  static String _logKey(DateTime d) => 'log_${dayKey(d)}';

  /// reload() : les valeurs peuvent avoir été modifiées par la notification.
  static Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  static Future<UserProfile?> loadProfile() async {
    final prefs = await _prefs();
    final s = prefs.getString(_profileKey);
    if (s == null) return null;
    try {
      return UserProfile.decode(s);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveProfile(UserProfile p) async {
    final prefs = await _prefs();
    await prefs.setString(_profileKey, p.encode());
    await prefs.setInt(_goalKey(DateTime.now()), p.dailyGoalMl);
  }

  static Future<int> getTodayIntake() async {
    final prefs = await _prefs();
    return prefs.getInt(_intakeKey(DateTime.now())) ?? 0;
  }

  static Future<List<IntakeEntry>> getTodayLog() async {
    final prefs = await _prefs();
    final raw =
        prefs.getStringList(_logKey(DateTime.now())) ?? const <String>[];
    return raw.map(IntakeEntry.tryDecode).whereType<IntakeEntry>().toList();
  }

  static Future<int> addIntake(int ml) async {
    final prefs = await _prefs();
    final now = DateTime.now();
    final total = (prefs.getInt(_intakeKey(now)) ?? 0) + ml;
    await prefs.setInt(_intakeKey(now), total);

    final log = List<String>.from(
      prefs.getStringList(_logKey(now)) ?? const <String>[],
    );
    log.add(IntakeEntry(now.hour * 60 + now.minute, ml).encode());
    await prefs.setStringList(_logKey(now), log);

    final profileStr = prefs.getString(_profileKey);
    if (profileStr != null) {
      try {
        await prefs.setInt(
          _goalKey(now),
          UserProfile.decode(profileStr).dailyGoalMl,
        );
      } catch (_) {}
    }
    return total;
  }

  /// Annule le dernier ajout du jour. Retourne le nouveau total.
  static Future<int> undoLast() async {
    final prefs = await _prefs();
    final now = DateTime.now();
    final log = List<String>.from(
      prefs.getStringList(_logKey(now)) ?? const <String>[],
    );
    var total = prefs.getInt(_intakeKey(now)) ?? 0;
    if (log.isNotEmpty) {
      final last = IntakeEntry.tryDecode(log.removeLast());
      if (last != null) total -= last.ml;
      if (total < 0) total = 0;
      await prefs.setStringList(_logKey(now), log);
      await prefs.setInt(_intakeKey(now), total);
    }
    return total;
  }

  /// Historique des [days] derniers jours (du plus ancien à aujourd'hui).
  static Future<List<DayStat>> getHistory(
    int days, {
    required int fallbackGoal,
  }) async {
    final prefs = await _prefs();
    final today = DateTime.now();
    final out = <DayStat>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day - i);
      out.add(
        DayStat(
          date: d,
          ml: prefs.getInt(_intakeKey(d)) ?? 0,
          goal: prefs.getInt(_goalKey(d)) ?? fallbackGoal,
        ),
      );
    }
    return out;
  }

  static Future<String?> getPlanDay() async {
    final prefs = await _prefs();
    return prefs.getString(_planDayKey);
  }

  static Future<void> setPlanDay(String value) async {
    final prefs = await _prefs();
    await prefs.setString(_planDayKey, value);
  }
}

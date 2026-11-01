import 'package:shared_preferences/shared_preferences.dart';

import '../models/history.dart';
import '../models/user_profile.dart';

class StorageService {
  static const _profileKey = 'profile';
  static const _planDayKey = 'plan_day';
  static const _notificationsEnabledKey = 'notifications_enabled';

  static String dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _intakeKey(DateTime date) => 'intake_${dayKey(date)}';
  static String _goalKey(DateTime date) => 'goal_${dayKey(date)}';
  static String _logKey(DateTime date) => 'log_${dayKey(date)}';

  static Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  static Future<bool> areNotificationsEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_notificationsEnabledKey, enabled);
  }

  static Future<UserProfile?> loadProfile() async {
    final prefs = await _prefs();
    final value = prefs.getString(_profileKey);

    if (value == null) return null;

    try {
      return UserProfile.decode(value);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await _prefs();

    await prefs.setString(_profileKey, profile.encode());
    await prefs.setInt(_goalKey(DateTime.now()), profile.dailyGoalMl);
  }

  static Future<int> getTodayIntake() async {
    final prefs = await _prefs();
    return prefs.getInt(_intakeKey(DateTime.now())) ?? 0;
  }

  static Future<List<IntakeEntry>> getTodayLog() {
    return getLogForDay(DateTime.now());
  }

  static Future<int> addIntake(int ml) async {
    if (ml <= 0 || ml > 5000) {
      throw ArgumentError('Quantité invalide');
    }

    final prefs = await _prefs();
    final now = DateTime.now();

    final total = (prefs.getInt(_intakeKey(now)) ?? 0) + ml;

    await prefs.setInt(_intakeKey(now), total);

    final log = List<String>.from(
      prefs.getStringList(_logKey(now)) ?? const <String>[],
    );

    log.add(IntakeEntry(now.hour * 60 + now.minute, ml).encode());

    await prefs.setStringList(_logKey(now), log);

    final profileString = prefs.getString(_profileKey);

    if (profileString != null) {
      try {
        final profile = UserProfile.decode(profileString);
        await prefs.setInt(_goalKey(now), profile.dailyGoalMl);
      } catch (_) {}
    }

    return total;
  }

  static Future<int> undoLast() async {
    final prefs = await _prefs();
    final now = DateTime.now();

    final log = List<String>.from(
      prefs.getStringList(_logKey(now)) ?? const <String>[],
    );

    var total = prefs.getInt(_intakeKey(now)) ?? 0;

    if (log.isNotEmpty) {
      final last = IntakeEntry.tryDecode(log.removeLast());

      if (last != null) {
        total -= last.ml;
      }

      if (total < 0) total = 0;

      await prefs.setStringList(_logKey(now), log);
      await prefs.setInt(_intakeKey(now), total);
    }

    return total;
  }

  static Future<List<DayStat>> getHistory(
    int days, {
    required int fallbackGoal,
  }) async {
    final prefs = await _prefs();
    final today = DateTime.now();

    final result = <DayStat>[];

    for (var i = days - 1; i >= 0; i--) {
      final date = DateTime(today.year, today.month, today.day - i);

      result.add(
        DayStat(
          date: date,
          ml: prefs.getInt(_intakeKey(date)) ?? 0,
          goal: prefs.getInt(_goalKey(date)) ?? fallbackGoal,
        ),
      );
    }

    return result;
  }

  static Future<int> getIntakeForDay(DateTime date) async {
    final prefs = await _prefs();
    return prefs.getInt(_intakeKey(date)) ?? 0;
  }

  static Future<List<IntakeEntry>> getLogForDay(DateTime date) async {
    final prefs = await _prefs();
    final raw = prefs.getStringList(_logKey(date)) ?? const <String>[];

    return raw.map(IntakeEntry.tryDecode).whereType<IntakeEntry>().toList();
  }

  static Future<void> _saveDayLog(DateTime date, List<IntakeEntry> log) async {
    final prefs = await _prefs();

    await prefs.setStringList(
      _logKey(date),
      log.map((entry) => entry.encode()).toList(),
    );

    final total = log.fold<int>(0, (sum, entry) => sum + entry.ml);

    await prefs.setInt(_intakeKey(date), total);
  }

  static Future<int> updateTodayEntry(int index, int ml) async {
    if (ml <= 0 || ml > 5000) {
      throw ArgumentError('Quantité invalide');
    }

    final now = DateTime.now();
    final log = await getLogForDay(now);

    if (index < 0 || index >= log.length) {
      throw RangeError.index(index, log);
    }

    log[index] = IntakeEntry(log[index].minutes, ml);

    await _saveDayLog(now, log);

    return log.fold<int>(0, (sum, entry) => sum + entry.ml);
  }

  static Future<int> deleteTodayEntry(int index) async {
    final now = DateTime.now();
    final log = await getLogForDay(now);

    if (index < 0 || index >= log.length) {
      throw RangeError.index(index, log);
    }

    log.removeAt(index);

    await _saveDayLog(now, log);

    return log.fold<int>(0, (sum, entry) => sum + entry.ml);
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

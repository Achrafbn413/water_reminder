import 'dart:convert';

enum ActivityLevel { low, moderate, high }

extension ActivityLevelX on ActivityLevel {
  String get label {
    switch (this) {
      case ActivityLevel.low:
        return 'Faible';
      case ActivityLevel.moderate:
        return 'Modérée';
      case ActivityLevel.high:
        return 'Élevée';
    }
  }

  int get bonusMl {
    switch (this) {
      case ActivityLevel.low:
        return 0;
      case ActivityLevel.moderate:
        return 350;
      case ActivityLevel.high:
        return 700;
    }
  }
}

String formatMinutes(int m) {
  final h = (m ~/ 60).toString().padLeft(2, '0');
  final min = (m % 60).toString().padLeft(2, '0');
  return '$h:$min';
}

class UserProfile {
  final double weightKg;
  final ActivityLevel activity;
  final int wakeMinutes; // minutes depuis minuit
  final int sleepMinutes;
  final int intervalMinutes;

  const UserProfile({
    required this.weightKg,
    required this.activity,
    required this.wakeMinutes,
    required this.sleepMinutes,
    required this.intervalMinutes,
  });

  /// Objectif quotidien en ml : 35 ml/kg + bonus d'activité, arrondi à 50.
  int get dailyGoalMl {
    final raw = weightKg * 35 + activity.bonusMl;
    return ((raw / 50).round()) * 50;
  }

  Map<String, dynamic> toJson() => {
    'weightKg': weightKg,
    'activity': activity.index,
    'wakeMinutes': wakeMinutes,
    'sleepMinutes': sleepMinutes,
    'intervalMinutes': intervalMinutes,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    weightKg: (j['weightKg'] as num).toDouble(),
    activity: ActivityLevel.values[j['activity'] as int],
    wakeMinutes: j['wakeMinutes'] as int,
    sleepMinutes: j['sleepMinutes'] as int,
    intervalMinutes: j['intervalMinutes'] as int,
  );

  String encode() => jsonEncode(toJson());
  factory UserProfile.decode(String s) =>
      UserProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

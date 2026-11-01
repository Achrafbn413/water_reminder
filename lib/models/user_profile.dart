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
  final String firstName;
  final String lastName;
  final int age;
  final double heightCm;

  final double weightKg;
  final ActivityLevel activity;

  final int wakeMinutes;
  final int sleepMinutes;
  final int intervalMinutes;

  const UserProfile({
    this.firstName = '',
    this.lastName = '',
    this.age = 0,
    this.heightCm = 0,
    required this.weightKg,
    required this.activity,
    required this.wakeMinutes,
    required this.sleepMinutes,
    required this.intervalMinutes,
  });

  String get fullName {
    return '$firstName $lastName'.trim();
  }

  /// Objectif quotidien estimatif en ml.
  /// Formule actuelle : 35 ml/kg + bonus d'activité.
  /// Arrondi aux 50 ml les plus proches.
  int get dailyGoalMl {
    final raw = weightKg * 35 + activity.bonusMl;
    return ((raw / 50).round()) * 50;
  }

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'age': age,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'activity': activity.index,
    'wakeMinutes': wakeMinutes,
    'sleepMinutes': sleepMinutes,
    'intervalMinutes': intervalMinutes,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    final activityIndex = (j['activity'] as num?)?.toInt() ?? 0;

    return UserProfile(
      firstName: j['firstName'] as String? ?? '',
      lastName: j['lastName'] as String? ?? '',
      age: (j['age'] as num?)?.toInt() ?? 0,
      heightCm: (j['heightCm'] as num?)?.toDouble() ?? 0,
      weightKg: (j['weightKg'] as num?)?.toDouble() ?? 60,
      activity: ActivityLevel
          .values[activityIndex.clamp(0, ActivityLevel.values.length - 1)],
      wakeMinutes: (j['wakeMinutes'] as num?)?.toInt() ?? 480,
      sleepMinutes: (j['sleepMinutes'] as num?)?.toInt() ?? 1320,
      intervalMinutes: (j['intervalMinutes'] as num?)?.toInt() ?? 120,
    );
  }

  String encode() => jsonEncode(toJson());

  factory UserProfile.decode(String s) =>
      UserProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

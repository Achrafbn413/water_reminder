import '../models/history.dart';
import '../services/storage_service.dart';

class GamificationService {
  static Future<int> getTotalXp(int goal) async {
    final history = await StorageService.getHistory(365, fallbackGoal: goal);

    int xp = 0;

    for (final day in history) {
      if (day.reached) {
        xp += 50;
      } else if (day.ml > 0) {
        xp += 10;
      }
    }

    return xp;
  }

  static Future<int> getCurrentStreak(int goal) async {
    final history = await StorageService.getHistory(365, fallbackGoal: goal);

    int streak = 0;

    for (final day in history.reversed) {
      if (day.reached) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  static int getLevel(int xp) {
    return (xp ~/ 200) + 1;
  }

  static int getXpForNextLevel(int xp) {
    return 200 - (xp % 200);
  }

  static double getLevelProgress(int xp) {
    return (xp % 200) / 200;
  }

  static Future<List<DayStat>> getHistory(int goal) {
    return StorageService.getHistory(30, fallbackGoal: goal);
  }

  static Future<bool> isTodayGoalReached(int goal) async {
    final total = await StorageService.getTodayIntake();
    return total >= goal;
  }
}

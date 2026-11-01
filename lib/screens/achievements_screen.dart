import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/gamification_service.dart';

class AchievementsScreen extends StatefulWidget {
  final UserProfile profile;

  const AchievementsScreen({super.key, required this.profile});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late Future<Map<String, dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _data = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final goal = widget.profile.dailyGoalMl;

    final xp = await GamificationService.getTotalXp(goal);
    final streak = await GamificationService.getCurrentStreak(goal);
    final reached = await GamificationService.isTodayGoalReached(goal);

    return {
      'xp': xp,
      'level': GamificationService.getLevel(xp),
      'streak': streak,
      'progress': GamificationService.getLevelProgress(xp),
      'next': GamificationService.getXpForNextLevel(xp),
      'reached': reached,
    };
  }

  void _refresh() {
    setState(_loadData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes récompenses'), centerTitle: true),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final xp = data['xp'] as int;
          final level = data['level'] as int;
          final streak = data['streak'] as int;
          final progress = data['progress'] as double;
          final next = data['next'] as int;
          final reached = data['reached'] as bool;

          final badges = [
            _Badge(
              'Premier pas',
              'Enregistrer sa première journée',
              Icons.water_drop,
              xp >= 10,
              10,
            ),
            _Badge(
              'Hydratation réussie',
              'Atteindre son objectif quotidien',
              Icons.emoji_events,
              reached || streak > 0,
              50,
            ),
            _Badge(
              'Régularité',
              'Atteindre 3 jours consécutifs',
              Icons.local_fire_department,
              streak >= 3,
              100,
            ),
            _Badge(
              'Une semaine',
              'Atteindre 7 jours consécutifs',
              Icons.calendar_month,
              streak >= 7,
              200,
            ),
            _Badge(
              'Champion',
              'Atteindre le niveau 5',
              Icons.workspace_premium,
              level >= 5,
              300,
            ),
          ];

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF26C6DA)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.stars, color: Colors.white, size: 48),
                      const SizedBox(height: 10),
                      const Text(
                        'NIVEAU',
                        style: TextStyle(
                          color: Colors.white70,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        '$level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$xp XP accumulés',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Colors.white30,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$next XP avant le prochain niveau',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        'Série actuelle',
                        '$streak jours',
                        Icons.local_fire_department,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'Objectif du jour',
                        reached ? 'Atteint !' : 'En cours',
                        Icons.water_drop,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                const Text(
                  'Mes badges',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...badges.map(
                  (badge) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: badge.unlocked
                            ? Colors.amber.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.15),
                        child: Icon(
                          badge.icon,
                          color: badge.unlocked
                              ? Colors.amber.shade800
                              : Colors.grey,
                        ),
                      ),
                      title: Text(
                        badge.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(badge.description),
                      trailing: badge.unlocked
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.lock_outline, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _Badge {
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;
  final int xp;

  const _Badge(this.title, this.description, this.icon, this.unlocked, this.xp);
}

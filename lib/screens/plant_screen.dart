import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/gamification_service.dart';

class PlantScreen extends StatefulWidget {
  final UserProfile profile;

  const PlantScreen({super.key, required this.profile});

  @override
  State<PlantScreen> createState() => _PlantScreenState();
}

class _PlantScreenState extends State<PlantScreen> {
  late Future<Map<String, dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = _getPlantData();
  }

  Future<Map<String, dynamic>> _getPlantData() async {
    final history = await GamificationService.getHistory(
      widget.profile.dailyGoalMl,
    );

    final completedDays = history.where((day) => day.reached).length;

    final stage = completedDays >= 25
        ? 5
        : completedDays >= 15
        ? 4
        : completedDays >= 8
        ? 3
        : completedDays >= 3
        ? 2
        : 1;

    return {'completedDays': completedDays, 'stage': stage};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma plante virtuelle'),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final completedDays = snapshot.data!['completedDays'] as int;
          final stage = snapshot.data!['stage'] as int;

          final plants = [
            Icons.eco,
            Icons.grass,
            Icons.local_florist,
            Icons.park,
            Icons.park,
          ];

          final titles = [
            'Petite graine',
            'Jeune pousse',
            'Petite plante',
            'Belle plante',
            'Arbre magnifique',
          ];

          final descriptions = [
            'Commence à prendre soin de ta plante.',
            'Ta plante commence à grandir !',
            'Continue à bien t’hydrater.',
            'Ta plante devient magnifique.',
            'Félicitations ! Ta plante est épanouie.',
          ];

          final progress = completedDays >= 25 ? 1.0 : completedDays / 25;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    const Text(
                      'PRENDS SOIN DE TA PLANTE',
                      style: TextStyle(
                        color: Color(0xFF006064),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Icon(
                      plants[stage - 1],
                      size: 150,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      titles[stage - 1],
                      style: const TextStyle(
                        color: Color(0xFF004D40),
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      descriptions[stage - 1],
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF00695C)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Progression de ma plante',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(20),
                        backgroundColor: Colors.grey.shade300,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$completedDays journées réussies sur 25',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(Icons.water_drop, color: Colors.blue, size: 35),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Atteins ton objectif quotidien pour aider ta plante à grandir.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: () {
                  setState(_load);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Actualiser ma plante'),
              ),
            ],
          );
        },
      ),
    );
  }
}

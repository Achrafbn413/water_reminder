import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'onboarding_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserProfile profile;
  const HomeScreen({super.key, required this.profile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _intake = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.refresh.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.refresh.removeListener(_load);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final v = await StorageService.getTodayIntake();
    if (mounted) setState(() => _intake = v);
  }

  Future<void> _add(int ml) async {
    final v = await StorageService.addIntake(ml);
    if (mounted) setState(() => _intake = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = widget.profile.dailyGoalMl;
    final progress = (_intake / goal).clamp(0.0, 1.0);
    final done = _intake >= goal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Reminder'),
        actions: [
          IconButton(
            tooltip: 'Modifier mon profil',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OnboardingScreen(initial: widget.profile),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 16,
                      strokeCap: StrokeCap.round,
                      backgroundColor: theme.colorScheme.primaryContainer,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_intake ml',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('sur $goal ml'),
                          Text('${(progress * 100).round()} %'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                done
                    ? 'Objectif atteint, bravo ! 🎉'
                    : 'Reste ${goal - _intake} ml à boire',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              Wrap(
                spacing: 12,
                children: [150, 250, 500]
                    .map(
                      (ml) => FilledButton.tonal(
                        onPressed: () => _add(ml),
                        child: Text('+$ml ml'),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Tester la notification'),
                onPressed: NotificationService.showTest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

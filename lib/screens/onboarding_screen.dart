import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final UserProfile? initial;
  const OnboardingScreen({super.key, this.initial});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late double _weight;
  late ActivityLevel _activity;
  late int _wake;
  late int _sleep;
  late int _interval;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _weight = p?.weightKg ?? 70;
    _activity = p?.activity ?? ActivityLevel.moderate;
    _wake = p?.wakeMinutes ?? 7 * 60;
    _sleep = p?.sleepMinutes ?? 22 * 60;
    _interval = p?.intervalMinutes ?? 120;
  }

  UserProfile get _profile => UserProfile(
    weightKg: _weight,
    activity: _activity,
    wakeMinutes: _wake,
    sleepMinutes: _sleep,
    intervalMinutes: _interval,
  );

  Future<void> _pickTime(bool wake) async {
    final current = wake ? _wake : _sleep;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (t == null) return;
    setState(() {
      final v = t.hour * 60 + t.minute;
      if (wake) {
        _wake = v;
      } else {
        _sleep = v;
      }
    });
  }

  Future<void> _save() async {
    final profile = _profile;
    await StorageService.saveProfile(profile);
    await NotificationService.requestPermissions();
    await NotificationService.rescheduleSmart();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(profile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Votre profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Quelques infos pour calculer votre objectif d\'eau.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'Poids : ${_weight.round()} kg',
              style: theme.textTheme.titleMedium,
            ),
            Slider(
              min: 30,
              max: 150,
              divisions: 120,
              value: _weight,
              label: '${_weight.round()} kg',
              onChanged: (v) => setState(() => _weight = v),
            ),
            const SizedBox(height: 16),
            Text('Activité physique', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<ActivityLevel>(
              segments: ActivityLevel.values
                  .map((a) => ButtonSegment(value: a, label: Text(a.label)))
                  .toList(),
              selected: {_activity},
              onSelectionChanged: (s) => setState(() => _activity = s.first),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: Text('Réveil ${formatMinutes(_wake)}'),
                    onPressed: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.bedtime_outlined),
                    label: Text('Coucher ${formatMinutes(_sleep)}'),
                    onPressed: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Rappel toutes les…', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [60, 90, 120, 180]
                  .map(
                    (m) => ChoiceChip(
                      label: Text(m % 60 == 0 ? '${m ~/ 60} h' : '1 h 30'),
                      selected: _interval == m,
                      onSelected: (_) => setState(() => _interval = m),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 32),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('Votre objectif quotidien'),
                    const SizedBox(height: 4),
                    Text(
                      '${(_profile.dailyGoalMl / 1000).toStringAsFixed(2)} L',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Commencer'),
            ),
          ],
        ),
      ),
    );
  }
}

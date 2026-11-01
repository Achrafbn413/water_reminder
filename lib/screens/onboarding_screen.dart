import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_background.dart';
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

  bool _saving = false;

  static const Color blue = Color(0xFF168FE5);
  static const Color darkBlue = Color(0xFF123B62);

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

    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );

    if (result == null) return;

    setState(() {
      final minutes = result.hour * 60 + result.minute;

      if (wake) {
        _wake = minutes;
      } else {
        _sleep = minutes;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final profile = _profile;

      await StorageService.saveProfile(profile);
      await NotificationService.requestPermissions();
      await NotificationService.rescheduleSmart();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(profile: profile)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde : $e')),
      );

      setState(() => _saving = false);
    }
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: blue, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.blueGrey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: blue.withValues(alpha: 0.06),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _activityCard(
    ActivityLevel level,
    IconData icon,
    String title,
    String description,
  ) {
    final selected = _activity == level;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activity = level),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 7),
          decoration: BoxDecoration(
            color: selected
                ? blue.withValues(alpha: 0.09)
                : const Color(0xFFF7FAFD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? blue : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? blue : Colors.blueGrey, size: 27),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? blue : darkBlue,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeCard(
    String title,
    String time,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F9FD),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: blue, size: 24),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
              const SizedBox(height: 5),
              Text(
                time,
                style: const TextStyle(
                  color: darkBlue,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Modifier',
                style: TextStyle(
                  color: blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = _profile.dailyGoalMl;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Votre profil',
            style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: darkBlue),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            const SizedBox(height: 8),

            const Text(
              'Apprenons à vous connaître.',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
                color: darkBlue,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Personnalisons votre programme d’hydratation selon votre mode de vie.',
              style: TextStyle(
                color: Colors.blueGrey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 28),

            // WEIGHT
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    'Votre poids',
                    'Utilisé pour estimer votre besoin quotidien',
                    Icons.monitor_weight_outlined,
                  ),

                  Center(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _weight.round().toString(),
                            style: const TextStyle(
                              color: darkBlue,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: ' kg',
                            style: TextStyle(
                              color: blue,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: blue,
                      inactiveTrackColor: blue.withValues(alpha: 0.12),
                      thumbColor: Colors.white,
                      overlayColor: blue.withValues(alpha: 0.12),
                      trackHeight: 7,
                    ),
                    child: Slider(
                      min: 30,
                      max: 150,
                      divisions: 120,
                      value: _weight,
                      onChanged: (v) {
                        setState(() => _weight = v);
                      },
                    ),
                  ),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('30 kg', style: TextStyle(color: Colors.grey)),
                      Text('150 kg', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ACTIVITY
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    'Votre activité',
                    'Quel est votre niveau d’activité physique ?',
                    Icons.directions_run_rounded,
                  ),

                  Row(
                    children: [
                      _activityCard(
                        ActivityLevel.low,
                        Icons.weekend_outlined,
                        'Faible',
                        'Peu actif',
                      ),
                      const SizedBox(width: 9),
                      _activityCard(
                        ActivityLevel.moderate,
                        Icons.directions_walk_rounded,
                        'Modérée',
                        'Actif',
                      ),
                      const SizedBox(width: 9),
                      _activityCard(
                        ActivityLevel.high,
                        Icons.fitness_center_rounded,
                        'Élevée',
                        'Très actif',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // SCHEDULE
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    'Votre journée',
                    'Définissez vos horaires habituels',
                    Icons.access_time_rounded,
                  ),

                  Row(
                    children: [
                      _timeCard(
                        'Réveil',
                        formatMinutes(_wake),
                        Icons.wb_sunny_outlined,
                        () => _pickTime(true),
                      ),
                      const SizedBox(width: 12),
                      _timeCard(
                        'Coucher',
                        formatMinutes(_sleep),
                        Icons.nights_stay_outlined,
                        () => _pickTime(false),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // REMINDERS
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    'Fréquence des rappels',
                    'À quelle fréquence souhaitez-vous boire ?',
                    Icons.notifications_active_outlined,
                  ),

                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [60, 90, 120, 180].map((m) {
                      final label = m == 60
                          ? '1 heure'
                          : m == 90
                          ? '1 h 30'
                          : m == 120
                          ? '2 heures'
                          : '3 heures';

                      return ChoiceChip(
                        label: Text(label),
                        selected: _interval == m,
                        onSelected: (_) {
                          setState(() => _interval = m);
                        },
                        selectedColor: blue.withValues(alpha: 0.13),
                        backgroundColor: const Color(0xFFF5F9FD),
                        side: BorderSide(
                          color: _interval == m ? blue : Colors.transparent,
                        ),
                        labelStyle: TextStyle(
                          color: _interval == m ? blue : darkBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // DAILY GOAL
            Container(
              padding: const EdgeInsets.all(23),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF168FE5), Color(0xFF35C4E8)],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: blue.withValues(alpha: 0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.water_drop_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Votre objectif quotidien estimé',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(goal / 1000).toStringAsFixed(2)} L',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 39,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Soit $goal ml par jour',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 58,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: darkBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Enregistrer mon profil',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 15),

            const Center(
              child: Text(
                'Votre bien-être commence par une bonne hydratation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

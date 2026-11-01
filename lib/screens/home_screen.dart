import 'package:flutter/material.dart';

import '../models/history.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_background.dart';
import '../widgets/water_wave.dart';
import 'onboarding_screen.dart';
import 'stats_screen.dart';
import 'calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserProfile profile;

  const HomeScreen({super.key, required this.profile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const Color blue = Color(0xFF168FE5);
  static const Color darkBlue = Color(0xFF123B62);

  int _intake = 0;
  List<IntakeEntry> _log = [];
  bool _loading = true;
  bool _busy = false;

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
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    final values = await Future.wait([
      StorageService.getTodayIntake(),
      StorageService.getTodayLog(),
    ]);

    if (!mounted) return;

    setState(() {
      _intake = values[0] as int;
      _log = values[1] as List<IntakeEntry>;
      _loading = false;
    });
  }

  Future<void> _add(int ml) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final total = await StorageService.addIntake(ml);
      final log = await StorageService.getTodayLog();

      if (!mounted) return;

      setState(() {
        _intake = total;
        _log = log;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+$ml ml ajoutés avec succès !'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: darkBlue,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showCustomIntakeDialog({int? initial, int? editIndex}) async {
    final controller = TextEditingController(text: initial?.toString() ?? '');

    String? errorMessage;

    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                editIndex == null
                    ? 'Ajouter une quantité'
                    : 'Modifier la consommation',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantité',
                  suffixText: 'ml',
                  hintText: 'Exemple : 300',
                  errorText: errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onChanged: (_) {
                  if (errorMessage != null) {
                    setDialogState(() => errorMessage = null);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = int.tryParse(controller.text.trim());

                    if (value == null || value < 1 || value > 5000) {
                      setDialogState(() {
                        errorMessage = 'Entrez une quantité entre 1 et 5000 ml';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, value);
                  },
                  child: Text(editIndex == null ? 'Ajouter' : 'Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (amount == null || !mounted) return;

    setState(() => _busy = true);

    try {
      if (editIndex == null) {
        await StorageService.addIntake(amount);
      } else {
        await StorageService.updateTodayEntry(editIndex, amount);
      }

      await _load();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteEntry(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer cette prise ?'),
          content: const Text(
            'Cette action modifiera le total de votre journée.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    await StorageService.deleteTodayEntry(index);
    await _load();
  }

  Future<void> _undo() async {
    if (_log.isEmpty || _busy) return;

    setState(() => _busy = true);

    try {
      final total = await StorageService.undoLast();
      final log = await StorageService.getTodayLog();

      if (!mounted) return;

      setState(() {
        _intake = total;
        _log = log;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Bonjour ☀️';
    if (hour < 18) return 'Bon après-midi 🌤️';

    return 'Bonsoir 🌙';
  }

  String get _date {
    final now = DateTime.now();

    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];

    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];

    return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }

  String _formatTime(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Widget _quickAddButton(int ml, IconData icon) {
    return Expanded(
      child: InkWell(
        onTap: _busy ? null : () => _add(ml),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: blue.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: blue.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: blue, size: 25),
              const SizedBox(height: 8),
              Text(
                '+$ml ml',
                style: const TextStyle(
                  color: darkBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: darkBlue,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    final start = _log.length > 4 ? _log.length - 4 : 0;

    final indexedEntries = List.generate(
      _log.length - start,
      (i) => MapEntry(start + i, _log[start + i]),
    ).reversed.toList();

    if (_log.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.water_drop_outlined, color: blue, size: 25),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aucune consommation enregistrée pour le moment.',
                style: TextStyle(color: Colors.blueGrey, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: blue.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: indexedEntries.map((item) {
          final entry = item.value;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: blue.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.water_drop_rounded, color: blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.ml} ml',
                        style: const TextStyle(
                          color: darkBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatTime(entry.minutes),
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.blueGrey),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showCustomIntakeDialog(
                        initial: entry.ml,
                        editIndex: item.key,
                      );
                    }

                    if (value == 'delete') {
                      _deleteEntry(item.key);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.profile.dailyGoalMl;

    final progress = goal <= 0 ? 0.0 : (_intake / goal).clamp(0.0, 1.0);

    final remaining = (goal - _intake).clamp(0, goal);
    final done = _intake >= goal;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Row(
            children: [
              Icon(Icons.water_drop_rounded, color: blue, size: 25),
              SizedBox(width: 8),
              Text(
                'Water Reminder',
                style: TextStyle(
                  color: darkBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Calendrier',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalendarScreen(profile: widget.profile),
                  ),
                );
              },
              icon: const Icon(Icons.calendar_month_rounded, color: darkBlue),
            ),
            IconButton(
              tooltip: 'Statistiques',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StatsScreen(profile: widget.profile),
                  ),
                );
              },
              icon: const Icon(Icons.bar_chart_rounded, color: darkBlue),
            ),
            IconButton(
              tooltip: 'Modifier mon profil',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OnboardingScreen(initial: widget.profile),
                  ),
                );
              },
              icon: const Icon(Icons.settings_outlined, color: darkBlue),
            ),
            const SizedBox(width: 5),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: blue))
            : RefreshIndicator(
                color: blue,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  children: [
                    Text(
                      _greeting,
                      style: const TextStyle(
                        color: darkBlue,
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _date,
                      style: TextStyle(
                        color: Colors.blueGrey.shade500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // PROGRESSION QUOTIDIENNE
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 25,
                        horizontal: 18,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF123B62), Color(0xFF168FE5)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: blue.withValues(alpha: 0.20),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'VOTRE HYDRATATION DU JOUR',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 230,
                            height: 230,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 225,
                                  height: 225,
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 8,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: Colors.white24,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF8CEAFF),
                                        ),
                                  ),
                                ),
                                WaterWave(progress: progress, size: 195),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.water_drop_rounded,
                                      color: Colors.white,
                                      size: 27,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${(progress * 100).round()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 38,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '$_intake ml',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'sur $goal ml',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  done
                                      ? Icons.check_circle_rounded
                                      : Icons.flag_rounded,
                                  color: const Color(0xFF8CEAFF),
                                ),
                                const SizedBox(width: 9),
                                Flexible(
                                  child: Text(
                                    done
                                        ? 'Objectif quotidien atteint !'
                                        : 'Encore $remaining ml pour atteindre votre objectif',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 27),

                    // AJOUT RAPIDE
                    _sectionTitle(
                      'Ajouter de l’eau',
                      'Enregistrez votre consommation',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _quickAddButton(150, Icons.local_drink_outlined),
                        const SizedBox(width: 10),
                        _quickAddButton(250, Icons.water_drop_outlined),
                        const SizedBox(width: 10),
                        _quickAddButton(500, Icons.sports_bar_outlined),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _showCustomIntakeDialog(),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text(
                          'Ajouter une quantité personnalisée',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: blue,
                          side: BorderSide(color: blue.withValues(alpha: 0.35)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _busy || _log.isEmpty ? null : _undo,
                        icon: const Icon(Icons.undo_rounded, size: 17),
                        label: const Text('Annuler le dernier ajout'),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // HISTORIQUE DU JOUR
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionTitle(
                          'Historique du jour',
                          'Vos dernières consommations',
                        ),
                        Text(
                          '${_log.length} prises',
                          style: const TextStyle(
                            color: blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildHistory(),

                    const SizedBox(height: 22),

                    // ACCÈS AUX AUTRES ÉCRANS
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CalendarScreen(profile: widget.profile),
                                ),
                              );
                            },
                            icon: const Icon(Icons.calendar_month_rounded),
                            label: const Text('Calendrier'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: darkBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: blue.withValues(alpha: 0.25),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StatsScreen(profile: widget.profile),
                                ),
                              );
                            },
                            icon: const Icon(Icons.bar_chart_rounded),
                            label: const Text('Statistiques'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: darkBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: blue.withValues(alpha: 0.25),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

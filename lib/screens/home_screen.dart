import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/history.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/water_wave.dart';

import 'onboarding_screen.dart';
import 'stats_screen.dart';
import 'calendar_screen.dart';
import 'achievements_screen.dart';
import 'plant_screen.dart';
import 'notifications_screen.dart';

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
  bool _darkMode = false;

  Color get _background =>
      _darkMode ? const Color(0xFF0B1420) : const Color(0xFFF3F8FC);

  Color get _surface => _darkMode ? const Color(0xFF172638) : Colors.white;

  Color get _text => _darkMode ? const Color(0xFFF1F6FC) : darkBlue;

  Color get _muted =>
      _darkMode ? const Color(0xFFA6B7C9) : Colors.blueGrey.shade500;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    NotificationService.refresh.addListener(_load);

    _loadTheme();
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

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _darkMode = prefs.getBool('water_dark_mode') ?? false;
    });
  }

  Future<void> _toggleTheme() async {
    final newValue = !_darkMode;

    setState(() => _darkMode = newValue);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('water_dark_mode', newValue);
  }

  Future<void> _load() async {
    try {
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de charger les consommations.'),
        ),
      );
    }
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
          backgroundColor: blue,
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
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                editIndex == null
                    ? 'Ajouter une quantité'
                    : 'Modifier la consommation',
                style: TextStyle(color: _text, fontWeight: FontWeight.bold),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: TextStyle(color: _text),
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
          backgroundColor: _surface,
          title: Text(
            'Supprimer cette prise ?',
            style: TextStyle(color: _text),
          ),
          content: Text(
            'Cette action modifiera le total de votre journée.',
            style: TextStyle(color: _muted),
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

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarScreen(profile: widget.profile),
      ),
    );
  }

  void _openStats() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StatsScreen(profile: widget.profile)),
    );
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

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _text,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: _muted, fontSize: 12)),
      ],
    );
  }

  Widget _quickAddButton(int ml, IconData icon) {
    return Expanded(
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _busy ? null : () => _add(ml),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: blue, size: 25),
                const SizedBox(height: 8),
                Text(
                  '+$ml ml',
                  style: TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistory() {
    final start = _log.length > 5 ? _log.length - 5 : 0;

    final entries = List.generate(
      _log.length - start,
      (i) => MapEntry(start + i, _log[start + i]),
    ).reversed.toList();

    if (_log.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.water_drop_outlined, color: blue, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aucune consommation enregistrée pour le moment.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _darkMode ? 0.10 : 0.035),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: entries.map((item) {
          final entry = item.value;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
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
                        style: TextStyle(
                          color: _text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatTime(entry.minutes),
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: _muted),
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

  Widget _featureCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: _surface,
      elevation: _darkMode ? 0 : 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        leading: CircleAvatar(
          backgroundColor: iconBackground,
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: TextStyle(color: _text, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle, style: TextStyle(color: _muted, fontSize: 12)),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: _muted,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildProgressCard(
    double progress,
    int goal,
    int remaining,
    bool done,
    double availableWidth,
  ) {
    final circleSize = (availableWidth * 0.66).clamp(175.0, 225.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123B62), Color(0xFF168FE5), Color(0xFF20B9E8)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: blue.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'VOTRE HYDRATATION DU JOUR',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1.7,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: circleSize,
            height: circleSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: circleSize,
                  height: circleSize,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF8CEAFF),
                    ),
                  ),
                ),
                WaterWave(progress: progress, size: circleSize * 0.86),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.water_drop_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_intake ml',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  done ? Icons.check_circle_rounded : Icons.flag_rounded,
                  color: const Color(0xFF8CEAFF),
                ),
                const SizedBox(width: 8),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.profile.dailyGoalMl;
    final progress = goal <= 0
        ? 0.0
        : (_intake / goal).clamp(0.0, 1.0).toDouble();

    final remaining = (goal - _intake).clamp(0, goal);
    final done = _intake >= goal;

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: _darkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: _background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: _darkMode ? Brightness.dark : Brightness.light,
          surface: _surface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _background,
          foregroundColor: _text,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: _surface,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          titleSpacing: 18,
          title: Row(
            children: [
              const Icon(Icons.water_drop_rounded, color: blue, size: 25),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Water Reminder',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: _openNotifications,
              icon: Icon(Icons.notifications_outlined, color: _text),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: _text),
              onSelected: (value) {
                if (value == 'calendar') _openCalendar();
                if (value == 'stats') _openStats();

                if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OnboardingScreen(initial: widget.profile),
                    ),
                  );
                }

                if (value == 'theme') _toggleTheme();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'calendar',
                  child: Text('Calendrier'),
                ),
                const PopupMenuItem(
                  value: 'stats',
                  child: Text('Statistiques'),
                ),
                const PopupMenuItem(
                  value: 'profile',
                  child: Text('Modifier mon profil'),
                ),
                PopupMenuItem(
                  value: 'theme',
                  child: Row(
                    children: [
                      Icon(
                        _darkMode
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                      ),
                      const SizedBox(width: 10),
                      Text(_darkMode ? 'Mode clair' : 'Mode sombre'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 5),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: blue))
            : RefreshIndicator(
                color: blue,
                onRefresh: _load,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 35),
                      children: [
                        Text(
                          _greeting,
                          style: TextStyle(
                            color: _text,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _date,
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                        const SizedBox(height: 22),

                        _buildProgressCard(
                          progress,
                          goal,
                          remaining,
                          done,
                          constraints.maxWidth,
                        ),

                        const SizedBox(height: 28),

                        _sectionTitle(
                          'Ajouter de l’eau',
                          'Enregistrez votre consommation',
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            _quickAddButton(150, Icons.local_drink_outlined),
                            const SizedBox(width: 9),
                            _quickAddButton(250, Icons.water_drop_outlined),
                            const SizedBox(width: 9),
                            _quickAddButton(500, Icons.sports_bar_outlined),
                          ],
                        ),

                        const SizedBox(height: 13),

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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: blue,
                              side: BorderSide(
                                color: blue.withValues(alpha: 0.45),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 5),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _busy || _log.isEmpty ? null : _undo,
                            icon: const Icon(Icons.undo_rounded, size: 17),
                            label: const Text('Annuler le dernier ajout'),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _sectionTitle(
                                'Historique du jour',
                                'Vos dernières consommations',
                              ),
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

                        const SizedBox(height: 25),

                        _sectionTitle(
                          'Votre espace',
                          'Retrouvez vos outils et votre progression',
                        ),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: _shortcutButton(
                                icon: Icons.calendar_month_rounded,
                                title: 'Calendrier',
                                onTap: _openCalendar,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _shortcutButton(
                                icon: Icons.bar_chart_rounded,
                                title: 'Statistiques',
                                onTap: _openStats,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        _featureCard(
                          icon: Icons.notifications_active_rounded,
                          iconColor: blue,
                          iconBackground: const Color(0xFFE3F2FD),
                          title: 'Mes notifications',
                          subtitle: 'Gérer les rappels et les alertes',
                          onTap: _openNotifications,
                        ),

                        const SizedBox(height: 11),

                        _featureCard(
                          icon: Icons.emoji_events_rounded,
                          iconColor: Colors.orange,
                          iconBackground: const Color(0xFFFFF3CD),
                          title: 'Mes récompenses',
                          subtitle: 'XP, niveaux et badges',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AchievementsScreen(profile: widget.profile),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 11),

                        _featureCard(
                          icon: Icons.eco_rounded,
                          iconColor: Colors.green,
                          iconBackground: const Color(0xFFE8F5E9),
                          title: 'Ma plante virtuelle',
                          subtitle:
                              'Fais grandir ta plante grâce à ton hydratation',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PlantScreen(profile: widget.profile),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 22),

                        Center(
                          child: Text(
                            'WATER REMINDER • PRENEZ SOIN DE VOUS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _shortcutButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _text,
        backgroundColor: _surface,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        side: BorderSide(color: blue.withValues(alpha: 0.25)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: blue, size: 19),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

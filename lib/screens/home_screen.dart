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
import 'medications_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserProfile profile;

  const HomeScreen({super.key, required this.profile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const Color blue = Color(0xFF168FE5);
  static const Color darkBlue = Color(0xFF123B62);
  static const Color cyan = Color(0xFF8CEAFF);

  late UserProfile _profile;

  int _intake = 0;
  List<IntakeEntry> _log = [];

  bool _loading = true;
  bool _busy = false;
  bool _darkMode = false;

  Color get _background =>
      _darkMode ? const Color(0xFF0B1420) : const Color(0xFFF2F7FC);

  Color get _surface => _darkMode ? const Color(0xFF162436) : Colors.white;

  Color get _text => _darkMode ? const Color(0xFFF1F6FC) : darkBlue;

  Color get _muted =>
      _darkMode ? const Color(0xFFA6B7C9) : Colors.blueGrey.shade500;

  Color get _border => _darkMode
      ? Colors.white.withValues(alpha: 0.06)
      : const Color(0xFFE6EEF6);

  BoxDecoration _cardDecoration({double radius = 22}) {
    return BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: (_darkMode ? Colors.black : blue).withValues(
            alpha: _darkMode ? 0.25 : 0.07,
          ),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    _profile = widget.profile;

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
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      color: blue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      editIndex == null
                          ? 'Ajouter une quantité'
                          : 'Modifier la consommation',
                      style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Quantité',
                  suffixText: 'ml',
                  hintText: 'Exemple : 300',
                  errorText: errorMessage,
                  filled: true,
                  fillColor: blue.withValues(alpha: _darkMode ? 0.10 : 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: blue, width: 1.6),
                  ),
                ),
                onChanged: (_) {
                  if (errorMessage != null) {
                    setDialogState(() => errorMessage = null);
                  }
                },
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
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
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text(
            'Supprimer cette prise ?',
            style: TextStyle(color: _text, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Cette action modifiera le total de votre journée.',
            style: TextStyle(color: _muted),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
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

  void _openMedications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MedicationsScreen()),
    );
  }

  void _openCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CalendarScreen(profile: _profile)),
    );
  }

  void _openStats() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StatsScreen(profile: _profile)),
    );
  }

  Future<void> _openProfile() async {
    final updatedProfile = await Navigator.push<UserProfile>(
      context,
      MaterialPageRoute(builder: (_) => OnboardingScreen(initial: _profile)),
    );

    if (!mounted || updatedProfile == null) return;

    setState(() {
      _profile = updatedProfile;
    });

    await NotificationService.rescheduleSmart();
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

  // ───────────────────────── WIDGETS ─────────────────────────

  Widget _sectionTitle(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 36,
          decoration: BoxDecoration(
            color: blue,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickAddButton(int ml, IconData icon) {
    return Expanded(
      child: Container(
        decoration: _cardDecoration(radius: 20),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: _busy ? null : () => _add(ml),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          blue.withValues(alpha: 0.22),
                          cyan.withValues(alpha: 0.22),
                        ],
                      ),
                    ),
                    child: Icon(icon, color: blue, size: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '+$ml',
                    style: TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'ml',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
        padding: const EdgeInsets.all(22),
        decoration: _cardDecoration(radius: 22),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blue.withValues(alpha: 0.10),
              ),
              child: const Icon(
                Icons.water_drop_outlined,
                color: blue,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucune consommation enregistrée pour le moment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: _cardDecoration(radius: 24),
      child: Column(
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            _historyRow(entries[i]),
            if (i != entries.length - 1)
              Divider(height: 1, thickness: 1, color: _border),
          ],
        ],
      ),
    );
  }

  Widget _historyRow(MapEntry<int, IntakeEntry> item) {
    final entry = item.value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  blue.withValues(alpha: 0.20),
                  cyan.withValues(alpha: 0.20),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
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
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 12, color: _muted),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(entry.minutes),
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded, color: _muted),
            color: _surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _showCustomIntakeDialog(initial: entry.ml, editIndex: item.key);
              }

              if (value == 'delete') {
                _deleteEntry(item.key);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_rounded, size: 18, color: blue),
                    const SizedBox(width: 10),
                    Text('Modifier', style: TextStyle(color: _text)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 10),
                    Text('Supprimer', style: TextStyle(color: _text)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: _cardDecoration(radius: 20),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: _darkMode ? 0.20 : 0.13),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 25),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _text,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _muted.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          children: [
            Icon(icon, color: cyan, size: 18),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
          ],
        ),
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
    final circleSize = (availableWidth * 0.62).clamp(170.0, 220.0).toDouble();

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123B62), Color(0xFF168FE5), Color(0xFF20B9E8)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: blue.withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -45,
            right: -35,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'VOTRE HYDRATATION DU JOUR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, animated, _) {
                    return Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: cyan.withValues(alpha: 0.22),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: circleSize,
                            height: circleSize,
                            child: CircularProgressIndicator(
                              value: animated,
                              strokeWidth: 9,
                              strokeCap: StrokeCap.round,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                cyan,
                              ),
                            ),
                          ),
                          WaterWave(
                            progress: animated,
                            size: circleSize * 0.86,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.water_drop_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(progress * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
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
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _statTile(Icons.water_drop_rounded, 'Bu', '$_intake ml'),
                    const SizedBox(width: 8),
                    _statTile(
                      Icons.hourglass_bottom_rounded,
                      'Restant',
                      '$remaining ml',
                    ),
                    const SizedBox(width: 8),
                    _statTile(
                      Icons.local_drink_rounded,
                      'Prises',
                      '${_log.length}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: done ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        done ? Icons.check_circle_rounded : Icons.flag_rounded,
                        color: cyan,
                        size: 20,
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
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileButton() {
    final name = _profile.fullName;

    return InkWell(
      onTap: _openProfile,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: blue.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: blue.withValues(alpha: _darkMode ? 0.10 : 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: blue,
              child: Icon(Icons.person_rounded, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 8),
            Text(
              name.isEmpty ? 'Mon profil' : name.split(' ').first,
              style: TextStyle(
                color: _text,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shortcutButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: _cardDecoration(radius: 20),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: blue, size: 19),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = _profile.dailyGoalMl;

    final progress = goal <= 0
        ? 0.0
        : (_intake / goal).clamp(0.0, 1.0).toDouble();

    final remaining = (goal - _intake).clamp(0, goal).toInt();
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
      ),
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          titleSpacing: 18,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [blue, Color(0xFF20B9E8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Water Reminder',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w800,
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
              color: _surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                if (value == 'calendar') _openCalendar();
                if (value == 'stats') _openStats();
                if (value == 'theme') _toggleTheme();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'calendar',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 19,
                        color: blue,
                      ),
                      const SizedBox(width: 10),
                      Text('Calendrier', style: TextStyle(color: _text)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'stats',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bar_chart_rounded,
                        size: 19,
                        color: blue,
                      ),
                      const SizedBox(width: 10),
                      Text('Statistiques', style: TextStyle(color: _text)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'theme',
                  child: Row(
                    children: [
                      Icon(
                        _darkMode
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 19,
                        color: blue,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _darkMode ? 'Mode clair' : 'Mode sombre',
                        style: TextStyle(color: _text),
                      ),
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
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 35),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _greeting,
                                    style: TextStyle(
                                      color: _text,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.event_rounded,
                                        size: 14,
                                        color: _muted,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _date,
                                        style: TextStyle(
                                          color: _muted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _profileButton(),
                          ],
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
                            const SizedBox(width: 10),
                            _quickAddButton(250, Icons.water_drop_outlined),
                            const SizedBox(width: 10),
                            _quickAddButton(500, Icons.sports_bar_outlined),
                          ],
                        ),

                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _showCustomIntakeDialog(),
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            label: const Text(
                              'Ajouter une quantité personnalisée',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: blue.withValues(
                                alpha: _darkMode ? 0.20 : 0.11,
                              ),
                              foregroundColor: blue,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(
                                  color: blue.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _busy || _log.isEmpty ? null : _undo,
                            icon: const Icon(Icons.undo_rounded, size: 17),
                            label: const Text('Annuler le dernier ajout'),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _sectionTitle(
                                'Historique du jour',
                                'Vos dernières consommations',
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_log.length} prises',
                                style: const TextStyle(
                                  color: blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),
                        _buildHistory(),

                        const SizedBox(height: 28),

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
                          icon: Icons.medication_outlined,
                          iconColor: Colors.teal,
                          title: 'Mes médicaments',
                          subtitle: 'Gérer les traitements et les rappels',
                          onTap: _openMedications,
                        ),

                        const SizedBox(height: 11),

                        _featureCard(
                          icon: Icons.notifications_active_rounded,
                          iconColor: blue,
                          title: 'Mes notifications',
                          subtitle: 'Gérer les rappels et les alertes',
                          onTap: _openNotifications,
                        ),

                        const SizedBox(height: 11),

                        _featureCard(
                          icon: Icons.emoji_events_rounded,
                          iconColor: Colors.orange,
                          title: 'Mes récompenses',
                          subtitle: 'XP, niveaux et badges',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AchievementsScreen(profile: _profile),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 11),

                        _featureCard(
                          icon: Icons.eco_rounded,
                          iconColor: Colors.green,
                          title: 'Ma plante virtuelle',
                          subtitle:
                              'Fais grandir ta plante grâce à ton hydratation',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlantScreen(profile: _profile),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 26),

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
}

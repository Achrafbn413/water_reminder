import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_background.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final UserProfile? initial;

  const OnboardingScreen({super.key, this.initial});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;

  late double _weight;
  late ActivityLevel _activity;
  late int _wake;
  late int _sleep;
  late int _interval;

  bool _saving = false;

  static const Color blue = Color(0xFF168FE5);
  static const Color cyan = Color(0xFF35C4E8);
  static const Color darkBlue = Color(0xFF123B62);
  static const Color fieldFill = Color(0xFFF3F8FD);

  @override
  void initState() {
    super.initState();

    final p = widget.initial;

    _firstNameController = TextEditingController(text: p?.firstName ?? '');
    _lastNameController = TextEditingController(text: p?.lastName ?? '');
    _ageController = TextEditingController(
      text: p != null && p.age > 0 ? '${p.age}' : '',
    );
    _heightController = TextEditingController(
      text: p != null && p.heightCm > 0 ? p.heightCm.toStringAsFixed(0) : '',
    );

    _weight = p?.weightKg ?? 70;
    _activity = p?.activity ?? ActivityLevel.moderate;
    _wake = p?.wakeMinutes ?? 7 * 60;
    _sleep = p?.sleepMinutes ?? 22 * 60;
    _interval = p?.intervalMinutes ?? 120;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  UserProfile get _profile => UserProfile(
    firstName: _firstNameController.text.trim(),
    lastName: _lastNameController.text.trim(),
    age: int.tryParse(_ageController.text) ?? 0,
    heightCm: double.tryParse(_heightController.text) ?? 0,
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

    if (result == null || !mounted) return;

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

    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final profile = _profile;

      await StorageService.saveProfile(profile);
      await NotificationService.rescheduleSmart();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Votre profil a été enregistré avec succès.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );

      if (widget.initial != null) {
        Navigator.of(context).pop(profile);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(profile: profile)),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde : $e')),
      );

      setState(() => _saving = false);
    }
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  // ───────────────────────── WIDGETS ─────────────────────────

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [blue, cyan],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: blue.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
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
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE6EEF6)),
        boxShadow: [
          BoxShadow(
            color: blue.withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _textField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int? max,
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: max,
      style: const TextStyle(
        color: darkBlue,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.blueGrey.shade500),
        hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
        floatingLabelStyle: const TextStyle(
          color: blue,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: blue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: blue, size: 20),
        ),
        counterText: '',
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.blueGrey.withValues(alpha: 0.10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: blue, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
        ),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';

        if (requiredField && text.isEmpty) {
          return 'Ce champ est obligatoire';
        }

        if (text.isNotEmpty && keyboardType == TextInputType.number) {
          final number = int.tryParse(text);
          if (number == null || number <= 0) {
            return 'Veuillez saisir un nombre valide';
          }
        }

        return null;
      },
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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      blue.withValues(alpha: 0.14),
                      cyan.withValues(alpha: 0.10),
                    ],
                  )
                : null,
            color: selected ? null : const Color(0xFFF7FAFD),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? blue : const Color(0xFFE6EEF6),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: blue.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? blue
                          : Colors.blueGrey.withValues(alpha: 0.10),
                    ),
                    child: Icon(
                      icon,
                      color: selected ? Colors.white : Colors.blueGrey,
                      size: 25,
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? blue : darkBlue,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.blueGrey.shade500,
                ),
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
      child: Material(
        color: fieldFill,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE6EEF6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: blue, size: 22),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.blueGrey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: darkBlue,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 12, color: blue),
                    SizedBox(width: 4),
                    Text(
                      'Modifier',
                      style: TextStyle(
                        color: blue,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notificationSettingsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Notifications',
            'Configurez vos rappels d’hydratation',
            Icons.notifications_active_outlined,
          ),
          Text(
            'Choisissez si vous souhaitez recevoir des rappels et tester leur fonctionnement.',
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openNotifications,
              icon: const Icon(Icons.settings_outlined),
              label: const Text(
                'Gérer mes notifications',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: blue.withValues(alpha: 0.11),
                foregroundColor: blue,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: blue.withValues(alpha: 0.35)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apprenons à vous\nconnaître.',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: darkBlue,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Complétez vos informations pour personnaliser votre programme d’hydratation.',
                style: TextStyle(
                  color: Colors.blueGrey.shade600,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [blue, cyan],
            ),
            boxShadow: [
              BoxShadow(
                color: blue.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.water_drop_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ],
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
          scrolledUnderElevation: 0,
          title: Text(
            widget.initial == null ? 'Créer mon profil' : 'Mon profil',
            style: const TextStyle(
              color: darkBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: darkBlue),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              _hero(),
              const SizedBox(height: 26),

              // INFORMATIONS PERSONNELLES
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(
                      'Informations personnelles',
                      'Complétez les détails de votre profil',
                      Icons.person_outline_rounded,
                    ),
                    _textField(
                      label: 'Prénom',
                      hint: 'Votre prénom',
                      icon: Icons.person_outline,
                      controller: _firstNameController,
                    ),
                    const SizedBox(height: 14),
                    _textField(
                      label: 'Nom',
                      hint: 'Votre nom',
                      icon: Icons.badge_outlined,
                      controller: _lastNameController,
                    ),
                    const SizedBox(height: 14),
                    _textField(
                      label: 'Âge',
                      hint: 'Votre âge en années',
                      icon: Icons.cake_outlined,
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      max: 3,
                    ),
                    const SizedBox(height: 14),
                    _textField(
                      label: 'Taille (cm)',
                      hint: 'Exemple : 175',
                      icon: Icons.height_rounded,
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      max: 5,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // POIDS
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: fieldFill,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE6EEF6)),
                        ),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: _weight.round().toString(),
                                style: const TextStyle(
                                  color: darkBlue,
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(
                                text: ' kg',
                                style: TextStyle(
                                  color: blue,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: blue,
                        inactiveTrackColor: blue.withValues(alpha: 0.12),
                        thumbColor: blue,
                        overlayColor: blue.withValues(alpha: 0.14),
                        trackHeight: 8,
                        trackShape: const RoundedRectSliderTrackShape(),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 11,
                          elevation: 3,
                        ),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '30 kg',
                            style: TextStyle(
                              color: Colors.blueGrey.shade400,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '150 kg',
                            style: TextStyle(
                              color: Colors.blueGrey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ACTIVITE
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

              // HORAIRES
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

              // FREQUENCE DES RAPPELS
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

                        final selected = _interval == m;

                        return ChoiceChip(
                          avatar: Icon(
                            Icons.schedule_rounded,
                            size: 17,
                            color: selected ? blue : Colors.blueGrey,
                          ),
                          label: Text(label),
                          selected: selected,
                          showCheckmark: false,
                          onSelected: (_) {
                            setState(() => _interval = m);
                          },
                          selectedColor: blue.withValues(alpha: 0.14),
                          backgroundColor: fieldFill,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: selected ? blue : const Color(0xFFE6EEF6),
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          labelStyle: TextStyle(
                            color: selected ? blue : darkBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _notificationSettingsCard(),

              const SizedBox(height: 20),

              // OBJECTIF QUOTIDIEN
              Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF123B62), Color(0xFF168FE5), cyan],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: blue.withValues(alpha: 0.30),
                      blurRadius: 26,
                      offset: const Offset(0, 11),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -40,
                      right: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -50,
                      left: -30,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                              child: const Icon(
                                Icons.water_drop_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Votre objectif quotidien estimé',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${(goal / 1000).toStringAsFixed(2)} L',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Soit $goal ml par jour',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ENREGISTRER
              Container(
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: darkBlue.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: darkBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Enregistrer mon profil',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.check_circle_outline),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  'Votre bien-être commence par une bonne hydratation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blueGrey.shade400,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

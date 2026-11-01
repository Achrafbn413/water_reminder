import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_background.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color blue = Color(0xFF168FE5);
  static const Color darkBlue = Color(0xFF123B62);
  static const List<int> _intervals = [15, 30, 45, 60, 90, 120, 180, 240];

  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _sound = true;
  bool _vibration = true;
  UserProfile? _profile;
  int _interval = 60;
  int _start = 480;
  int _end = 1320;
  int _pauseUntil = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final enabled = await NotificationService.isEnabled();
      final profile = await StorageService.loadProfile();
      final settings = await NotificationService.getWaterSettings();
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _profile = profile;
        _interval = settings['intervalMinutes'] as int;
        _start = settings['startMinutes'] as int;
        _end = settings['endMinutes'] as int;
        _sound = settings['sound'] as bool;
        _vibration = settings['vibration'] as bool;
        _pauseUntil = settings['pauseUntil'] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Impossible de charger les paramètres : $e');
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _saving = true);
    try {
      await NotificationService.setEnabled(value);
      if (!mounted) return;
      setState(() => _enabled = value);
      _showMessage(
        value ? 'Les rappels sont activés.' : 'Les rappels sont désactivés.',
      );
    } catch (e) {
      _showMessage('Erreur : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_end == _start) {
      _showMessage('Les heures de début et de fin doivent être différentes.');
      return;
    }
    setState(() => _saving = true);
    try {
      await NotificationService.saveWaterSettings(
        intervalMinutes: _interval,
        startMinutes: _start,
        endMinutes: _end,
        sound: _sound,
        vibration: _vibration,
      );
      if (!mounted) return;
      _showMessage('Vos paramètres ont été enregistrés.');
    } catch (e) {
      _showMessage('Impossible d’enregistrer : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseTime(bool isStart) async {
    final current = isStart ? _start : _end;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: isStart
          ? 'Heure de début des rappels'
          : 'Heure de fin des rappels',
    );
    if (selected == null || !mounted) return;
    setState(() {
      final minutes = selected.hour * 60 + selected.minute;
      if (isStart) {
        _start = minutes;
      } else {
        _end = minutes;
      }
    });
  }

  Future<void> _pause(Duration duration, String label) async {
    try {
      await NotificationService.pauseWaterReminders(duration);
      if (!mounted) return;
      setState(
        () => _pauseUntil = DateTime.now().add(duration).millisecondsSinceEpoch,
      );
      _showMessage(
        'Rappels d’eau suspendus $label. Les rappels de médicaments restent actifs.',
      );
    } catch (e) {
      _showMessage('Impossible de suspendre les rappels : $e');
    }
  }

  Future<void> _resume() async {
    try {
      await NotificationService.resumeWaterReminders();
      if (!mounted) return;
      setState(() => _pauseUntil = 0);
      _showMessage('Les rappels d’eau ont repris.');
    } catch (e) {
      _showMessage('Erreur : $e');
    }
  }

  Future<void> _sendTest() async {
    if (_testing) return;
    setState(() => _testing = true);
    try {
      await NotificationService.showTest();
      if (mounted) _showMessage('Notification de test envoyée.');
    } catch (e) {
      if (mounted) _showMessage('Impossible d’envoyer la notification : $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatTime(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  bool get _isPaused => _pauseUntil > DateTime.now().millisecondsSinceEpoch;

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: blue.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );

  Widget _sectionTitle(String title, IconData icon) => Row(
    children: [
      Icon(icon, color: blue),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: darkBlue,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );

  Widget _timeTile(
    String title,
    int minutes,
    VoidCallback onTap,
    IconData icon,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: blue),
    title: Text(
      title,
      style: const TextStyle(color: darkBlue, fontWeight: FontWeight.w600),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(minutes),
          style: const TextStyle(color: blue, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 5),
        const Icon(Icons.edit, size: 17, color: blue),
      ],
    ),
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: darkBlue),
          title: const Text(
            'Notifications',
            style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: blue))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 32),
                children: [
                  const Text(
                    'Personnalisez vos rappels',
                    style: TextStyle(
                      color: darkBlue,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choisissez quand et à quelle fréquence Water Reminder vous rappelle de boire.',
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _card(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _enabled,
                      activeThumbColor: blue,
                      onChanged: _saving ? null : _toggleNotifications,
                      title: const Text(
                        'Rappels d’hydratation',
                        style: TextStyle(
                          color: darkBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Activer ou désactiver les notifications d’eau',
                      ),
                      secondary: const Icon(
                        Icons.notifications_active_rounded,
                        color: blue,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          'Fréquence des rappels',
                          Icons.schedule_rounded,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'À quelle fréquence souhaitez-vous recevoir un rappel ?',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: _intervals.contains(_interval)
                              ? _interval
                              : 60,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          items: _intervals
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    m < 60
                                        ? 'Toutes les $m minutes'
                                        : m == 60
                                        ? 'Toutes les heures'
                                        : 'Toutes les ${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60} min'}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _interval = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Un intervalle plus court augmente le nombre de rappels.',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          'Plage horaire',
                          Icons.access_time_rounded,
                        ),
                        const SizedBox(height: 8),
                        _timeTile(
                          'Début des rappels',
                          _start,
                          () => _chooseTime(true),
                          Icons.wb_sunny_outlined,
                        ),
                        const Divider(height: 1),
                        _timeTile(
                          'Fin des rappels',
                          _end,
                          () => _chooseTime(false),
                          Icons.nightlight_outlined,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Programme du profil : réveil ${_profile == null ? '--:--' : _formatTime(_profile!.wakeMinutes)} • coucher ${_profile == null ? '--:--' : _formatTime(_profile!.sleepMinutes)}. Les horaires ci-dessus sont personnalisables.',
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          'Son et vibration',
                          Icons.volume_up_rounded,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _sound,
                          activeThumbColor: blue,
                          onChanged: (v) => setState(() => _sound = v),
                          title: const Text('Son'),
                          subtitle: const Text('Jouer un son avec le rappel'),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _vibration,
                          activeThumbColor: blue,
                          onChanged: (v) => setState(() => _vibration = v),
                          title: const Text('Vibration'),
                          subtitle: const Text('Faire vibrer le téléphone'),
                        ),
                        const Text(
                          'Remarque : Android peut conserver les réglages du canal de notification déjà créé. Vous pouvez aussi les modifier dans les paramètres du téléphone.',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          'Pause temporaire',
                          Icons.pause_circle_outline_rounded,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Suspendre uniquement les rappels d’eau. Les rappels de médicaments restent actifs.',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_isPaused) ...[
                          Text(
                            'Rappels suspendus jusqu’au ${DateTime.fromMillisecondsSinceEpoch(_pauseUntil).toLocal().toString().substring(0, 16)}',
                            style: const TextStyle(
                              color: darkBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _resume,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Reprendre les rappels'),
                          ),
                        ] else ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _pause(
                                  const Duration(hours: 1),
                                  'pendant 1 heure',
                                ),
                                child: const Text('1 heure'),
                              ),
                              OutlinedButton(
                                onPressed: () => _pause(
                                  const Duration(hours: 2),
                                  'pendant 2 heures',
                                ),
                                child: const Text('2 heures'),
                              ),
                              OutlinedButton(
                                onPressed: () => _pause(
                                  const Duration(hours: 24),
                                  'pendant 24 heures',
                                ),
                                child: const Text('24 heures'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveSettings,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _saving
                            ? 'Enregistrement...'
                            : 'Enregistrer les paramètres',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          'Tester les notifications',
                          Icons.notifications_none_rounded,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Envoyer une notification pour vérifier que votre appareil les autorise.',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _enabled && !_testing ? _sendTest : null,
                            icon: _testing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _testing
                                  ? 'Envoi en cours...'
                                  : 'Envoyer une notification de test',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pensez à autoriser les notifications de Water Reminder dans les paramètres de votre téléphone.',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

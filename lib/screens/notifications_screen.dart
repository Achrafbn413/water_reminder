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

  bool _enabled = false;
  bool _loading = true;
  bool _testing = false;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final enabled = await NotificationService.isEnabled();
      final profile = await StorageService.loadProfile();

      if (!mounted) return;

      setState(() {
        _enabled = enabled;
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showMessage('Impossible de charger les paramètres : $e');
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _loading = true);

    try {
      await NotificationService.setEnabled(value);

      if (!mounted) return;

      setState(() {
        _enabled = value;
        _loading = false;
      });

      _showMessage(
        value ? 'Les rappels sont activés.' : 'Les rappels sont désactivés.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showMessage('Erreur lors de la modification : $e');
    }
  }

  Future<void> _sendTestNotification() async {
    if (_testing) return;

    setState(() => _testing = true);

    try {
      await NotificationService.showTest();

      if (!mounted) return;

      _showMessage('Notification de test envoyée.');
    } catch (e) {
      if (!mounted) return;

      _showMessage('Impossible d’envoyer la notification : $e');
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatTime(int? minutes) {
    if (minutes == null) return '--:--';

    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Widget _buildCard({required Widget child}) {
    return Container(
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
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: darkBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: blue, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

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
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
                children: [
                  const Text(
                    'Restez hydraté !',
                    style: TextStyle(
                      color: darkBlue,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recevez des rappels pour penser à boire de l’eau pendant la journée.',
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 25),

                  _buildCard(
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: blue.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: blue,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rappels d’hydratation',
                                style: TextStyle(
                                  color: darkBlue,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Activer ou désactiver les notifications',
                                style: TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _enabled,
                          activeThumbColor: blue,
                          onChanged: _toggleNotifications,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Votre programme',
                          style: TextStyle(
                            color: darkBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          Icons.wb_sunny_outlined,
                          'Heure de réveil',
                          _formatTime(_profile?.wakeMinutes),
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          Icons.nightlight_outlined,
                          'Heure de coucher',
                          _formatTime(_profile?.sleepMinutes),
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          Icons.schedule_rounded,
                          'Intervalle des rappels',
                          _profile == null
                              ? '--'
                              : '${_profile!.intervalMinutes} min',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tester les notifications',
                          style: TextStyle(
                            color: darkBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Envoyez une notification de test pour vérifier que votre appareil les autorise.',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _enabled && !_testing
                                ? _sendTestNotification
                                : null,
                            icon: _testing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _testing
                                  ? 'Envoi en cours...'
                                  : 'Envoyer une notification de test',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.blueGrey.shade200,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                        if (!_enabled) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Activez les rappels pour pouvoir effectuer un test.',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      'Remarque : vérifiez également dans les paramètres de votre téléphone que les notifications sont autorisées pour Water Reminder.',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

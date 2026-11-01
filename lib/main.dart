import 'package:flutter/material.dart';

import 'models/user_profile.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  final profile = await StorageService.loadProfile();
  runApp(WaterReminderApp(profile: profile));
}

ThemeData _theme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1E88E5),
    brightness: brightness,
  ),
  useMaterial3: true,
);

class WaterReminderApp extends StatelessWidget {
  final UserProfile? profile;
  const WaterReminderApp({super.key, this.profile});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Reminder',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: profile == null
          ? const OnboardingScreen()
          : HomeScreen(profile: profile!),
    );
  }
}

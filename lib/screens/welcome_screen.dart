import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../widgets/water_wave.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final UserProfile? profile;

  const WelcomeScreen({super.key, this.profile});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  bool _opening = false;

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _enterApp() {
    if (_opening) return;

    setState(() => _opening = true);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, animation, secondaryAnimation) {
          return widget.profile == null
              ? const OnboardingScreen()
              : HomeScreen(profile: widget.profile!);
        },
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF36CFFF),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    return Theme(
      data: darkTheme,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF061526), Color(0xFF0A2944), Color(0xFF06111F)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(),

                  // Logo
                  const Icon(
                    Icons.water_drop_rounded,
                    color: Color(0xFF50D9FF),
                    size: 34,
                  ),

                  const SizedBox(height: 18),

                  // Welcome title
                  const Text(
                    'Bienvenue',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Prenez soin de vous,\nune gorgée à la fois.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Color(0xFFB6CDDF),
                    ),
                  ),

                  const SizedBox(height: 55),

                  // Animated water button
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1 + (_pulseController.value * 0.035);

                      return Transform.scale(scale: scale, child: child);
                    },
                    child: GestureDetector(
                      onTap: _enterApp,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF21CFFF)
                                  .withValues(alpha: 0.20),
                              blurRadius: 55,
                              spreadRadius: 12,
                            ),
                            BoxShadow(
                              color: const Color(0xFF008CFF)
                                  .withValues(alpha: 0.12),
                              blurRadius: 90,
                              spreadRadius: 25,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const WaterWave(progress: 0.58, size: 210),
                            const Icon(
                              Icons.water_drop_rounded,
                              size: 42,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Color(0xFF00CFFF),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 35),

                  const Text(
                    'TOUCHER POUR COMMENCER',
                    style: TextStyle(
                      color: Color(0xFF72DFFF),
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Votre bien-être commence ici.',
                    style: TextStyle(color: Color(0xFF829DB3), fontSize: 13),
                  ),

                  const Spacer(),

                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      'WATER REMINDER',
                      style: TextStyle(
                        color: Color(0xFF54738C),
                        fontSize: 10,
                        letterSpacing: 4,
                      ),
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
}

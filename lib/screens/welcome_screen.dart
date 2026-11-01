import 'package:flutter/material.dart';

import '../models/user_profile.dart';
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
  static const Color cyan = Color(0xFF43D9F5);

  late final AnimationController _controller;
  bool _opening = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enterApp() {
    if (_opening) return;

    setState(() => _opening = true);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
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
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF061526), Color(0xFF0B3557), Color(0xFF071B30)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(),

                // LOGO CLIQUABLE
                GestureDetector(
                  onTap: _enterApp,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final scale = 1 + (_controller.value * 0.035);

                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: 210,
                      height: 210,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.07),
                        border: Border.all(
                          color: cyan.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: cyan.withValues(alpha: 0.20),
                            blurRadius: 55,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.water_drop_rounded,
                        color: cyan,
                        size: 115,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                const Text(
                  'WATER REMINDER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'Prenez soin de vous,\nune gorgée à la fois.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFB6D8E9),
                    fontSize: 17,
                    height: 1.7,
                  ),
                ),

                const SizedBox(height: 35),

                const Text(
                  'TOUCHEZ LE LOGO POUR CONTINUER',
                  style: TextStyle(
                    color: Color(0xFF83CDE5),
                    fontSize: 10,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const Spacer(),

                const Text(
                  'HYDRATATION • BIEN-ÊTRE • HABITUDE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF829DB3),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

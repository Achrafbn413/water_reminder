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
  static const Color blue = Color(0xFF168FE5);

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

  // ───────────────────────── WIDGETS ─────────────────────────

  Widget _bubble(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            cyan.withValues(alpha: alpha),
            cyan.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }

  Widget _ring(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cyan.withValues(alpha: alpha), width: 1),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cyan),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFA9C6D8),
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo() {
    return GestureDetector(
      onTap: _enterApp,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          final scale = 1 + (t * 0.04);

          return SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: 0.92 + t * 0.12,
                  child: _ring(290, 0.10),
                ),
                Transform.scale(
                  scale: 0.95 + t * 0.07,
                  child: _ring(250, 0.18),
                ),
                Transform.scale(scale: scale, child: child),
              ],
            ),
          );
        },
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(color: cyan.withValues(alpha: 0.45), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: cyan.withValues(alpha: 0.28),
                blurRadius: 60,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFB8F5FF), cyan, blue],
              ).createShader(rect),
              child: const Icon(
                Icons.water_drop_rounded,
                color: Colors.white,
                size: 110,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF061526), Color(0xFF0B3557), Color(0xFF071B30)],
          ),
        ),
        child: Stack(
          children: [
            // Décor : bulles lumineuses
            Positioned(top: -70, right: -60, child: _bubble(260, 0.18)),
            Positioned(top: 190, left: -80, child: _bubble(200, 0.10)),
            Positioned(bottom: -90, left: -50, child: _bubble(300, 0.14)),
            Positioned(bottom: 140, right: -40, child: _bubble(130, 0.10)),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            children: [
                              const Spacer(),

                              // LOGO CLIQUABLE
                              _logo(),

                              const SizedBox(height: 18),

                              ShaderMask(
                                shaderCallback: (rect) => const LinearGradient(
                                  colors: [Colors.white, Color(0xFFBFF3FF)],
                                ).createShader(rect),
                                child: const Text(
                                  'WATER REMINDER',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3.2,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              Container(
                                width: 46,
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [blue, cyan],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),

                              const SizedBox(height: 18),

                              const Text(
                                'Prenez soin de vous,\nune gorgée à la fois.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFB6D8E9),
                                  fontSize: 17,
                                  height: 1.7,
                                ),
                              ),

                              const SizedBox(height: 32),

                              // INVITE À TOUCHER LE LOGO
                              AnimatedBuilder(
                                animation: _controller,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: 0.6 + _controller.value * 0.4,
                                    child: child,
                                  );
                                },
                                child: GestureDetector(
                                  onTap: _enterApp,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cyan.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: cyan.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.touch_app_rounded,
                                          color: cyan,
                                          size: 17,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'TOUCHEZ LE LOGO POUR CONTINUER',
                                          style: TextStyle(
                                            color: Color(0xFF9FE3F5),
                                            fontSize: 10,
                                            letterSpacing: 1.8,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const Spacer(),

                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _chip(
                                    Icons.water_drop_outlined,
                                    'HYDRATATION',
                                  ),
                                  _chip(
                                    Icons.favorite_border_rounded,
                                    'BIEN-ÊTRE',
                                  ),
                                  _chip(Icons.repeat_rounded, 'HABITUDE'),
                                ],
                              ),

                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

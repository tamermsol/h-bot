import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'auth_wrapper.dart';
import 'onboarding_screen.dart';

/// Splash screen — dark gradient with animated logo, radial glow, tagline + progress bar.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final AnimationController _taglineController;
  late final Animation<double> _taglineFade;
  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();

    // Logo: scale 0.8→1.0 + fade in over 1s ease-out, 0.2s delay
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    // Tagline: fade in 0.8s, delayed 0.9s
    _taglineController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _taglineFade = CurvedAnimation(
      parent: _taglineController,
      curve: Curves.easeOut,
    );

    // Progress bar: 0→100% over 2s, delayed 1.1s
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Start logo after 0.2s delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _logoController.forward();
    });

    // Stagger tagline at 0.9s
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _taglineController.forward();
    });

    // Stagger progress bar at 1.3s
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) _progressController.forward();
    });

    // Navigate after 3.5s — onboarding for first-time, auth for returning
    Future.delayed(const Duration(milliseconds: 3500), () async {
      if (!mounted) return;
      final onboarded = await hasCompletedOnboarding();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              onboarded ? const AuthWrapper() : const OnboardingScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: HBotDurations.slow,
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _taglineController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF010510),
        child: Column(
          children: [
            const Spacer(),

            // Logo with radial glow (300x300) + drop shadow + scale/fade animation
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Radial glow circle — 300x300, #0883FD center → transparent
                    Container(
                      width: 300,
                      height: 300,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0xFF0883FD),
                            Color(0x000883FD),
                          ],
                          stops: [0.0, 1.0],
                        ),
                      ),
                    ),
                    // Logo with drop shadow
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0883FD).withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/branding/hbot_logo_splash.png',
                        width: 260,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: Alignment(-0.5, -0.5),
                            end: Alignment(0.5, 0.5),
                            colors: [Color(0xFF0883FD), Color(0xFF3BC4FF)],
                          ).createShader(bounds),
                          child: const Text(
                            'HBot',
                            style: TextStyle(
                              fontFamily: 'Readex Pro',
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Tagline — fade in delayed
            FadeTransition(
              opacity: _taglineFade,
              child: const Text(
                'Smart Home Control',
                style: TextStyle(
                  fontFamily: 'Readex Pro',
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: HBotColors.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
            ),

            const Spacer(),

            // Progress bar — 200px wide, 3px tall, gradient fill
            AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: HBotRadius.fullRadius,
                    child: SizedBox(
                      height: 3,
                      child: Stack(
                        children: [
                          // Track
                          Container(
                            width: double.infinity,
                            height: 3,
                            color: Colors.white.withOpacity( 0.06),
                          ),
                          // Fill
                          FractionallySizedBox(
                            widthFactor: _progressController.value,
                            child: Container(
                              height: 3,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF0883FD),
                                    Color(0xFF2FB8EC),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'auth_wrapper.dart';

/// Splash screen per design spec §1
/// Logo + gradient app name + tagline, animated entrance
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _taglineController;

  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    // Logo: fade in 300ms
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);

    // App name: slide up + fade in, 300ms after 200ms delay
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _textFade = CurvedAnimation(parent: _textController, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // Tagline: fade in 200ms after 400ms delay
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _taglineFade = CurvedAnimation(parent: _taglineController, curve: Curves.easeOut);

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    _taglineController.forward();

    // Navigate after splash
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthWrapper(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HBotColors.backgroundLight,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo — 64×64, animated fade
            FadeTransition(
              opacity: _logoFade,
              child: ClipRRect(
                borderRadius: HBotRadius.mediumRadius,
                child: Image.asset(
                  'assets/images/hbot_logo.png',
                  width: 64,
                  height: 64,
                  errorBuilder: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: HBotColors.primaryGradient,
                      borderRadius: HBotRadius.mediumRadius,
                    ),
                    child: const Icon(Icons.home_rounded, color: Colors.white, size: 32),
                  ),
                ),
              ),
            ),

            const SizedBox(height: HBotSpacing.space4),

            // App name — gradient text, slide up + fade
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textFade,
                child: ShaderMask(
                  shaderCallback: (bounds) => HBotColors.primaryGradient.createShader(bounds),
                  child: const Text(
                    'H-Bot',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white, // Will be masked by gradient
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: HBotSpacing.space2),

            // Tagline
            FadeTransition(
              opacity: _taglineFade,
              child: const Text(
                'Smart Home, Simplified',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: HBotColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

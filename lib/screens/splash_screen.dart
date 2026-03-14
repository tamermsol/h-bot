import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'auth_wrapper.dart';

/// Splash / Launch screen per design spec (04-SCREEN-DESIGNS.md Section 1)
/// Background: theme-aware (dark: #010510, light: #F8F9FB)
/// Centered logo placeholder (gradient "H" in rounded square 80x80)
/// "H-Bot" gradient text ($displayLarge 32/700)
/// "Smart Home, Simplified" in $textSecondary
/// Auto-navigates after 2s to AuthWrapper
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: HBotDurations.slow,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: HBotCurves.decelerate,
    );

    _fadeController.forward();

    // Auto-navigate after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const AuthWrapper(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: HBotDurations.slow,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HBotTheme.background(context),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // H-Bot logo
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/branding/hbot_app_icon.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: HBotColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.smart_toy, color: Colors.white, size: 40),
                  ),
                ),
              ),

              const SizedBox(height: HBotSpacing.space6),

              // "H-Bot" in gradient text ($displayLarge 32/700)
              ShaderMask(
                shaderCallback: (bounds) =>
                    HBotColors.primaryGradient.createShader(bounds),
                child: const Text(
                  'H-Bot',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.25,
                  ),
                ),
              ),

              const SizedBox(height: HBotSpacing.space2),

              // "Smart Home, Simplified" in $textSecondary
              Text(
                'Smart Home, Simplified',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: HBotTheme.textSecondary(context),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

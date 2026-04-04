import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'auth_wrapper.dart';

/// Key for persisting onboarding completion state.
const _kOnboardingCompleteKey = 'onboarding_complete';

/// Check whether the user has already completed onboarding.
Future<bool> hasCompletedOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingCompleteKey) ?? false;
}

/// Multi-step onboarding flow matching the approved onboarding-b design.
///
/// Steps:
///  0 — Welcome / Your Home, Your Control
///  1 — Smart Control / Control Every Device
///  2 — Automation / Automate Your Life
///  3 — Success / You're All Set!
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Device selection state (preserved for success summary)
  final Set<String> _selectedDevices = {'Relay'};

  // Animations
  late final AnimationController _slideController;
  late final AnimationController _scanController;
  late final AnimationController _successController;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scanController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleteKey, true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthWrapper(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: HBotDurations.slow,
        ),
      );
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      if (_currentStep == 2) {
        _scanController.repeat();
      }
      if (_currentStep == 3) {
        _scanController.stop();
        _successController.forward();
      }
    } else {
      _completeOnboarding();
    }
  }

  void _skip() => _completeOnboarding();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF010510),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // Ambient glow at top center — 420x420 radial gradient
            Positioned(
              top: -MediaQuery.of(context).size.height * 0.08,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF0883FD).withOpacity(0.12),
                        const Color(0xFF0883FD).withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Top section: progress dots + content
                  Expanded(
                    child: Column(
                      children: [
                        // Progress dots — top, 28px gap below
                        Padding(
                          padding: const EdgeInsets.only(
                            top: HBotSpacing.space9,
                            bottom: 28,
                          ),
                          child: _buildProgressDots(),
                        ),
                        // Step content
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.08, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: _buildStepContent(_currentStep),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bottom buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                    child: _buildBottomButtons(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalSteps, (i) {
        final isActive = i == _currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF0883FD), Color(0xFF3BC4FF)],
                  )
                : null,
            color: isActive ? null : const Color(0x1FFFFFFF), // rgba(255,255,255,0.12)
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF0883FD).withOpacity(0.4),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return _buildWelcomeSlide();
      case 1:
        return _buildSmartControlSlide();
      case 2:
        return _buildAutomationSlide();
      case 3:
        return _buildGetStartedSlide();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Slide 0: Welcome ─────────────────────────────────────
  Widget _buildWelcomeSlide() {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration container with concentric rings — HBot logo
          _buildIllustrationContainer(
            icon: Icons.home_rounded,
            ringColor: HBotColors.primary,
          ),
          const SizedBox(height: 28),
          // Title with gradient highlight
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.34,
                height: 1.15,
              ),
              children: [
                const TextSpan(text: 'Your Home,\n'),
                WidgetSpan(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF0883FD), Color(0xFF3BC4FF)],
                    ).createShader(bounds),
                    child: const Text(
                      'Your Control',
                      style: TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.34,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: HBotSpacing.space4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: const Text(
              'H-Bot lets you control your lights, shutters,\nand appliances from anywhere.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: HBotColors.textMuted,
                height: 1.75,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Slide 1: Smart Control ─────────────────────────────────
  Widget _buildSmartControlSlide() {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration container — device icons
          _buildIllustrationContainer(
            icon: Icons.devices_rounded,
            ringColor: HBotColors.primary,
          ),
          const SizedBox(height: 28),
          // Title with gradient highlight
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.34,
                height: 1.15,
              ),
              children: [
                const TextSpan(text: 'Control '),
                WidgetSpan(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF0883FD), Color(0xFF3BC4FF)],
                    ).createShader(bounds),
                    child: const Text(
                      'Every',
                      style: TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.34,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: '\nDevice'),
              ],
            ),
          ),
          const SizedBox(height: HBotSpacing.space4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: const Text(
              'Switches, dimmers, shutters, and sensors\n— all in one app, one tap away.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: HBotColors.textMuted,
                height: 1.75,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Slide 2: Automation ─────────────────────────────────
  Widget _buildAutomationSlide() {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration container — scene/timer icons
          _buildIllustrationContainer(
            icon: Icons.auto_awesome_rounded,
            ringColor: HBotColors.primary,
          ),
          const SizedBox(height: 28),
          // Title with gradient highlight
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.34,
                height: 1.15,
              ),
              children: [
                WidgetSpan(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF0883FD), Color(0xFF3BC4FF)],
                    ).createShader(bounds),
                    child: const Text(
                      'Automate',
                      style: TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.34,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: '\nYour Life'),
              ],
            ),
          ),
          const SizedBox(height: HBotSpacing.space4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: const Text(
              'Create scenes and timers to automate\nyour home — morning to night.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: HBotColors.textMuted,
                height: 1.75,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Slide 3: Get Started ──────────────────────────────────
  Widget _buildGetStartedSlide() {
    return Padding(
      key: const ValueKey(3),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated success checkmark in illustration container
          AnimatedBuilder(
            animation: _successController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.8 + 0.2 * _successController.value,
                child: Opacity(
                  opacity: _successController.value.clamp(0.0, 1.0),
                  child: _buildIllustrationContainer(
                    icon: Icons.check_rounded,
                    ringColor: const Color(0xFF34D399),
                    useSuccessGradient: true,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          const Text(
            "You're All Set!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Readex Pro',
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.34,
              height: 1.15,
            ),
          ),
          const SizedBox(height: HBotSpacing.space4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: const Text(
              'Your smart home is ready. Sign in or create\nan account to start controlling your devices.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: HBotColors.textMuted,
                height: 1.75,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared Components ────────────────────────────────────
  Widget _buildIllustrationContainer({
    required IconData icon,
    required Color ringColor,
    bool useSuccessGradient = false,
  }) {
    final gradient = useSuccessGradient
        ? const LinearGradient(
            begin: Alignment(-0.5, -0.5),
            end: Alignment(0.5, 0.5),
            colors: [Color(0xFF059669), Color(0xFF34D399)],
          )
        : const LinearGradient(
            begin: Alignment(-0.5, -0.5),
            end: Alignment(0.5, 0.5),
            colors: [Color(0xFF0883FD), Color(0xFF3BC4FF)],
          );

    final shadowColor = useSuccessGradient
        ? const Color(0xFF34D399).withOpacity(0.3)
        : HBotColors.primary.withOpacity(0.3);

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(44),
              border: Border.all(
                color: ringColor.withOpacity(0.03),
                width: 1,
              ),
            ),
          ),
          // Middle ring
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: ringColor.withOpacity(0.06),
                width: 1,
              ),
            ),
          ),
          // Inner ring
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: ringColor.withOpacity(0.15),
                width: 1.5,
              ),
            ),
          ),
          // Center icon — 80x80 container
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    if (_currentStep == _totalSteps - 1) {
      // Last step: full-width Get Started button with green success gradient
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _completeOnboarding,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment(-0.5, -0.5),
                  end: Alignment(0.5, 0.5),
                  colors: [Color(0xFF059669), Color(0xFF34D399)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF34D399).withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'Get Started',
                style: TextStyle(
                  fontFamily: 'Readex Pro',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Continue button — full width, gradient primary->cyan
        GestureDetector(
          onTap: _nextStep,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment(-0.5, -0.5),
                end: Alignment(0.5, 0.5),
                colors: [Color(0xFF0883FD), Color(0xFF3BC4FF)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0883FD).withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'Continue',
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Skip button — transparent bg, muted color, w500
        TextButton(
          onPressed: _skip,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.all(14),
            backgroundColor: Colors.transparent,
          ),
          child: const Text(
            'Skip',
            style: TextStyle(
              fontFamily: 'Readex Pro',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: HBotColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

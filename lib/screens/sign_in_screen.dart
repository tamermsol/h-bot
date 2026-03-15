import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/smart_input_field.dart';
import '../theme/app_theme.dart';
import 'sign_up_screen.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService
          .signInWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Sign-in timed out. Please check your connection and try again.',
              );
            },
          );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Sign-in failed. Please check your credentials.';
        if (e.toString().contains('timeout')) {
          msg = 'Connection timeout. Check your internet connection.';
        } else if (e.toString().contains('network')) {
          msg = 'Network error. Check your internet connection.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithGoogle().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw Exception('Google sign-in timed out. Please try again.');
        },
      );

      if (result && mounted) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google sign-in was cancelled.')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in was cancelled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HBotColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: HBotSpacing.space9),

                // Logo
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: HBotColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.home_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),

                const SizedBox(height: HBotSpacing.space4),

                // Welcome text
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: HBotSpacing.space2),

                Text(
                  'Sign in to your smart home',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: HBotSpacing.space7),

                // Email field
                SmartInputField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'user@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space4),

                // Password field
                SmartInputField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  enabled: !_isLoading,
                  onEditingComplete: _signInWithEmail,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: HBotSpacing.space2),

                // Forgot password — right-aligned
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Forgot password?',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: HBotColors.primary,
                          ),
                    ),
                  ),
                ),

                const SizedBox(height: HBotSpacing.space6),

                // Sign In button — primary gradient
                SizedBox(
                  height: 52,
                  child: Container(
                    decoration: hbotPrimaryButtonDecoration(disabled: _isLoading),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: HBotRadius.mediumRadius,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: HBotSpacing.space5),

                // Divider
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: HBotColors.borderLight),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: HBotSpacing.space4,
                      ),
                      child: Text(
                        'or',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: HBotColors.borderLight),
                    ),
                  ],
                ),

                const SizedBox(height: HBotSpacing.space5),

                // Google Sign In
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      height: 20,
                      width: 20,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.login, size: 20);
                      },
                    ),
                    label: const Text('Continue with Google'),
                  ),
                ),

                const SizedBox(height: HBotSpacing.space6),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SignUpScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HBotColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

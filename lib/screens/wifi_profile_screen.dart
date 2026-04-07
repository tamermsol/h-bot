import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../theme/app_theme.dart';
import '../models/wifi_profile.dart';
import '../services/smart_home_service.dart';
import '../core/supabase_client.dart';
import '../l10n/app_strings.dart';

/// Screen for managing Wi-Fi profiles for device provisioning
class WiFiProfileScreen extends StatefulWidget {
  final WiFiProfile? initialProfile;
  final VoidCallback? onProfileSaved;

  const WiFiProfileScreen({
    super.key,
    this.initialProfile,
    this.onProfileSaved,
  });

  @override
  State<WiFiProfileScreen> createState() => _WiFiProfileScreenState();
}

class _WiFiProfileScreenState extends State<WiFiProfileScreen> {
  final SmartHomeService _service = SmartHomeService();
  final NetworkInfo _networkInfo = NetworkInfo();

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _saveToAccount = true;
  bool _setAsDefault = true;
  bool _obscurePassword = true;
  String _statusMessage = '';
  String? _currentSSID;
  WiFiProfile? _existingProfile;

  @override
  void initState() {
    super.initState();
    _loadCurrentNetwork();
    if (widget.initialProfile != null) {
      _loadExistingProfile();
    }
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentNetwork() async {
    try {
      final ssid = await _networkInfo.getWifiName();
      if (ssid != null && mounted) {
        setState(() {
          _currentSSID = ssid.replaceAll('"', ''); // Remove quotes on Android
          _ssidController.text = _currentSSID!;
        });

        // Check if we already have a profile for this SSID
        _checkExistingProfile(_currentSSID!);
      }
    } catch (e) {
      // Ignore errors getting current network
    }
  }

  void _loadExistingProfile() {
    final profile = widget.initialProfile!;
    setState(() {
      _ssidController.text = profile.ssid;
      _passwordController.text = profile.password;
      _setAsDefault = profile.isDefault;
      _existingProfile = profile;
    });
  }

  Future<void> _checkExistingProfile(String ssid) async {
    try {
      final profile = await _service.findWiFiProfileBySSID(ssid);
      if (profile != null && mounted) {
        setState(() {
          _existingProfile = profile;
          _passwordController.text = profile.password;
          _setAsDefault = profile.isDefault;
        });
      }
    } catch (e) {
      // Ignore errors checking existing profile
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: context.hBackground,
      appBar: AppBar(
        backgroundColor: context.hBackground,
        title: Text(
          widget.initialProfile != null ? 'Edit Wi-Fi Profile' : 'Home Wi-Fi',
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: HBotSpacing.space6,
            right: HBotSpacing.space6,
            top: HBotSpacing.space6,
            bottom:
                HBotSpacing.space6 +
                MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialProfile != null
                    ? 'Update your Wi-Fi credentials'
                    : 'Enter your home Wi-Fi credentials for device provisioning',
                style: TextStyle(
                  fontSize: 16,
                  color: context.hTextSecondary,
                ),
              ),
              const SizedBox(height: HBotSpacing.space6),

              if (_currentSSID != null) ...[
                Container(
                  padding: const EdgeInsets.all(HBotSpacing.space4),
                  decoration: BoxDecoration(
                    color: HBotColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(HBotRadius.medium),
                    border: Border.all(
                      color: HBotColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi, color: HBotColors.primary),
                      const SizedBox(width: HBotSpacing.space2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Network',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.hTextSecondary,
                              ),
                            ),
                            Text(
                              _currentSSID!,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: context.hTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_existingProfile != null)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                ),
                const SizedBox(height: HBotSpacing.space6),
              ],

              TextFormField(
                controller: _ssidController,
                decoration: InputDecoration(
                  labelText: AppStrings.get('wifi_profile_wifi_network_ssid'),
                  hintText: AppStrings.get('wifi_profile_enter_your_wifi_network_name'),
                  prefixIcon: Icon(Icons.wifi),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'SSID is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: HBotSpacing.space4),

              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: AppStrings.get('wifi_profile_wifi_password'),
                  hintText: AppStrings.get('wifi_profile_enter_your_wifi_password'),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: HBotSpacing.space6),

              if (widget.initialProfile == null) ...[
                CheckboxListTile(
                  title: Text(AppStrings.get('wifi_profile_save_to_my_account_for_future_devices')),
                  subtitle: const Text(
                    'Reuse these credentials when adding more devices',
                  ),
                  value: _saveToAccount,
                  onChanged: (value) {
                    setState(() {
                      _saveToAccount = value ?? true;
                    });
                  },
                  activeColor: HBotColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),

                if (_saveToAccount) ...[
                  CheckboxListTile(
                    title: Text(AppStrings.get('wifi_profile_set_as_default_wifi_profile')),
                    subtitle: const Text(
                      'Use this network by default for new devices',
                    ),
                    value: _setAsDefault,
                    onChanged: (value) {
                      setState(() {
                        _setAsDefault = value ?? true;
                      });
                    },
                    activeColor: HBotColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ],

              const SizedBox(height: HBotSpacing.space6),

              if (_isLoading) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: HBotSpacing.space4),
              ],

              if (_statusMessage.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(HBotSpacing.space4),
                  decoration: BoxDecoration(
                    color: HBotColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(HBotRadius.medium),
                  ),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(color: context.hTextPrimary),
                  ),
                ),
                const SizedBox(height: HBotSpacing.space4),
              ],

              const SizedBox(height: HBotSpacing.space6),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HBotColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: HBotSpacing.space4,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          widget.initialProfile != null
                              ? 'Update Profile'
                              : 'Continue',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if user is signed in
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _statusMessage = 'You must be signed in before saving Wi-Fi.';
      });
      return;
    }

    // Get trimmed values
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;

    // Additional validation
    if (ssid.isEmpty) {
      setState(() {
        _statusMessage = 'SSID is required.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _statusMessage = 'Password is required.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving Wi-Fi profile...';
    });

    try {
      if (_saveToAccount) {
        // Use the SmartHomeService instead of direct Supabase calls
        final request = WiFiProfileRequest(
          ssid: ssid,
          password: password,
          isDefault: _setAsDefault,
        );

        if (_existingProfile != null) {
          // Update existing profile
          await _service.updateWiFiProfile(_existingProfile!.id, request);
        } else {
          // Create new profile
          await _service.createWiFiProfile(request);
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Wi-Fi profile saved.';
        });

        // Notify parent and close after a short delay
        widget.onProfileSaved?.call();

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context, {'ssid': ssid, 'password': password});
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage =
              'Failed to save Wi-Fi profile: ${e.toString().split(':').last.trim()}';
        });
      }
    }
  }
}
